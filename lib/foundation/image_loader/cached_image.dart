import 'dart:async' show Future, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  /// 站内 base64/inline 图每张都要抓取 + 解密 + 压缩，单独用更小的并发闸门，
  /// 避免首屏几十张一起上把 CPU/JS 引擎压住
  static const _kMaxInlineLoadingCount = 4;

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
        final fetched = await _loadInlineRef(url);
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
        // 首次遇到：大图在后台 isolate 解码显示，同时转存给下次用
        final bytes = await InlineImageStore.decodeAsync(url);
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

  /// 图片缓存键。
  ///
  /// 普通 URL 保持原样；base64 图（data URL）动辄几百 KB，直接拼进 key 会让
  /// 每次缓存查找/去重都为这个巨串重建一次字符串并算哈希，这里换成
  /// 「哈希 + 长度」的短键。
  @override
  String get key {
    if (url.length <= 512) return url + (sourceKey ?? "") + (aid ?? "");
    return 'long:${url.hashCode}x${url.length}@${sourceKey ?? ''}@${aid ?? ''}';
  }
}

/// 图片加载失败异常（网络不可达/域名屏蔽/连接中断等）
class ImageLoadException implements Exception {
  final String url;
  final String message;

  ImageLoadException(this.url, this.message);

  @override
  String toString() => 'ImageLoadException: $message ($url)';
}
