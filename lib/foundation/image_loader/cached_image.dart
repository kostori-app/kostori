import 'dart:async' show Future, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
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

  static int loadingCount = 0;

  static const _kMaxLoadingCount = 8;

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    // 转存后的短引用 / 源侧懒加载图片：一次渲染可能同时触发几十张
    // （每张都要抓图 + 解密 + 转 base64），必须和其它图片共用并发上限，
    // 否则会把 UI 线程和源请求压死。
    if (InlineImageStore.isRef(url)) {
      await _waitForSlot(checkStop);
      loadingCount++;
      try {
        final cached = await InlineImageStore.read(url);
        if (cached != null) return _yieldBytes(chunkEvents, cached);
        final fetched = await _loadInlineRef(url);
        if (fetched != null) return _yieldBytes(chunkEvents, fetched);
        throw ImageLoadException(url, 'inline image is no longer cached');
      } finally {
        loadingCount--;
      }
    }

    final isBase64 = InlineImageStore.looksLikeBase64(url);
    final isFile = url.startsWith('file://');
    final isHttp = url.startsWith('http://') || url.startsWith('https://');

    if (!isBase64 && !isFile && !isHttp) {
      DebugLog.error('CachedImageProvider', url);
    }

    if (isBase64) {
      // 已经转存过就直接读缓存，避免重复解码/压缩
      final cached = await InlineImageStore.read(InlineImageStore.refOf(url));
      if (cached != null) return _yieldBytes(chunkEvents, cached);
      // 首次遇到：内存解码显示，同时转存给下次用
      unawaited(InlineImageStore.storeBase64(url));
      final bytes = InlineImageStore.decode(url);
      if (bytes == null) throw ImageLoadException(url, 'invalid base64 image');
      return _yieldBytes(chunkEvents, bytes);
    }

    await _waitForSlot(checkStop);
    loadingCount++;
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
      loadingCount--;
    }
  }

  /// 等待并发位（同一时刻最多 [_kMaxLoadingCount] 张图在加载）
  Future<void> _waitForSlot(dynamic checkStop) async {
    while (loadingCount > _kMaxLoadingCount) {
      await Future.delayed(const Duration(milliseconds: 100));
      checkStop();
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

  /// 短引用缓存失效时回源：交给该源实现的 `loadInlineImage(token)`（可选）
  Future<Uint8List?> _loadInlineRef(String ref) async {
    final key = sourceKey;
    if (key == null) return null;
    final loader = AnimeSource.find(key)?.loadInlineImage;
    if (loader == null) return null;
    try {
      final data = await loader(
        ref.substring(InlineImageStore.prefix.length),
      );
      if (data == null || data.isEmpty) return null;
      final bytes = Uint8List.fromList(data);
      // 回源拿到后重新转存，避免每次都回源
      unawaited(
        CacheManager().writeCache(InlineImageStore.cacheKeyOfRef(ref), bytes),
      );
      return bytes;
    } catch (e) {
      DebugLog.error('CachedImageProvider', 'loadInlineImage failed: $e');
      return null;
    }
  }

  @override
  Future<CachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => url + (sourceKey ?? "") + (aid ?? "");
}

/// 图片加载失败异常（网络不可达/域名屏蔽/连接中断等）
class ImageLoadException implements Exception {
  final String url;
  final String message;

  ImageLoadException(this.url, this.message);

  @override
  String toString() => 'ImageLoadException: $message ($url)';
}
