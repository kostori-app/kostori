import 'dart:async' show Future, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/image_loader/base_image_provider.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart'
    as image_provider;
import 'package:kostori/foundation/image_loader/inline_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/images.dart';
import 'package:kostori/utils/io.dart';

class CachedImageProvider
    extends BaseImageProvider<image_provider.CachedImageProvider> {
  /// Image provider for normal image.
  ///
  /// [url] is the url of the image. Local file path is also supported.
  const CachedImageProvider(this.url, {this.headers, this.sourceKey, this.aid});

  final String url;

  final Map<String, String>? headers;

  final String? sourceKey;

  final String? aid;

  static const _kMaxLoadingCount = 8;

  /// 站内 base64/inline 回源已搬到 JSPool 后台 isolate（JS 解密与桥接拷贝
  /// 不再占用 UI 线程），闸门可以大于 worker 数：多出的任务在后台排队，
  /// 主线程无感；有效并行度由 worker 数（6，与 compute 共用、按最闲调度）决定。
  static const _kMaxInlineLoadingCount = 8;

  /// 图片并发闸门（FIFO，一次只放行一个）。
  ///
  /// 之前是 `while (count > max) await Future.delayed(...)` 的轮询：一有空位
  /// 等待者会在同一段事件循环里成批进入 `load`，把同步活挤到一两个帧里集中
  /// 爆发。改成队列后释放时只唤醒队首，加载节奏被摊平。
  static final _slotGate = AsyncGate(_kMaxLoadingCount);

  static final _inlineGate = AsyncGate(_kMaxInlineLoadingCount);

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    // 转存后的短引用 / 源侧懒加载图片：一次渲染可能同时触发几十张
    // （每张都要抓图 + 解密 + 转 base64），必须和其它图片共用并发上限，
    // 否则会把 UI 线程和源请求压死。
    if (InlineImageStore.isRef(url)) {
      await _inlineGate.acquire(checkStop);
      try {
        final cached = await InlineImageStore.read(url);
        if (cached != null) return _yieldBytes(chunkEvents, cached);
        checkStop();
        final fetched = await _loadInlineRef(url);
        // 滑动滚出屏幕后：JS 回源不可取消，但至少丢弃结果、不再解码/进缓存，
        // 避免“滑走后还卡一下”。
        checkStop();
        if (fetched != null) return _yieldBytes(chunkEvents, fetched);
        throw ImageLoadException(url, 'inline image is no longer cached');
      } finally {
        _inlineGate.release();
      }
    }

    final isBase64 = InlineImageStore.looksLikeBase64(url);
    final isFile = url.startsWith('file://');
    final isHttp = url.startsWith('http://') || url.startsWith('https://');

    if (!isBase64 && !isFile && !isHttp) {
      DebugLog.error('CachedImageProvider', url);
    }

    if (isBase64) {
      // 裸 base64 同样要解码（首屏大量未转存条目），和短引用共用并发闸门，
      // 否则会一起在主线程解码把 UI 压住
      await _inlineGate.acquire(checkStop);
      try {
        // 已经转存过就直接读缓存，避免重复解码/压缩
        final ref = await InlineImageStore.refOfAsync(url);
        final cached = await InlineImageStore.read(ref);
        if (cached != null) return _yieldBytes(chunkEvents, cached);
        checkStop();
        // 首次遇到：大图在后台 isolate 解码显示，同时转存给下次用
        final bytes = await InlineImageStore.decodeAsync(url);
        checkStop();
        if (bytes == null || !InlineImageStore.looksLikeImage(bytes)) {
          throw ImageLoadException(url, 'invalid base64 image');
        }
        unawaited(InlineImageStore.storeBase64(url, ref: ref, bytes: bytes));
        return _yieldBytes(chunkEvents, bytes);
      } finally {
        _inlineGate.release();
      }
    }

    await _slotGate.acquire(checkStop);
    try {
      if (url.startsWith("file://")) {
        var file = File(url.substring(7));
        return await file.readAsBytes();
      }

      await for (var progress in ImageDownloader.loadThumbnail(
        url,
        sourceKey,
        aid,
        headers,
      )) {
        checkStop();
        // 网络失败：直接抛出，由 ImageStream 显示占位；
        // 不再报误导性的 "Empty response body"
        if (progress.error != null) {
          throw ImageLoadException(
            url,
            'Network error loading image: ${progress.error}',
          );
        }
        chunkEvents.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: progress.currentBytes,
            expectedTotalBytes: progress.totalBytes,
          ),
        );
        if (progress.imageBytes != null) {
          return progress.imageBytes!;
        }
      }
      throw ImageLoadException(url, 'Empty response body');
    } finally {
      _slotGate.release();
    }
  }

  /// 上报字节数并返回（内存里已有的字节）
  Uint8List _yieldBytes(dynamic chunkEvents, Uint8List bytes) {
    chunkEvents.add(
      ImageChunkEvent(
        cumulativeBytesLoaded: bytes.length,
        expectedTotalBytes: bytes.length,
      ),
    );
    return bytes;
  }

  /// 短引用缓存失效时回源（与收藏/历史页共用同一套解析）
  Future<Uint8List?> _loadInlineRef(String ref) =>
      resolveInlineImage(ref, sourceKey);

  @override
  Future<CachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  /// 下载磁盘键与内存键同格式（[imageCacheKey]），默认清理即够，显式声明
  /// 防止未来两边格式再分叉。
  @override
  Future<void> purgeBadCache() =>
      CacheManager().delete(imageCacheKey(url, sourceKey, aid));

  /// 图片缓存键：与下载器磁盘键/去重键共用 [imageCacheKey]（此前三处格式
  /// 各不相同：短串分支分隔符不统一、长串用进程相关的 `hashCode`）。
  /// 注意这是 Flutter ImageCache 的内存键，改格式只影响本次运行。
  @override
  String get key => imageCacheKey(url, sourceKey, aid);
}

/// 图片加载失败异常（网络不可达/域名屏蔽/连接中断等）
class ImageLoadException implements Exception {
  final String url;
  final String message;

  ImageLoadException(this.url, this.message);

  @override
  String toString() => 'ImageLoadException: $message ($url)';
}
