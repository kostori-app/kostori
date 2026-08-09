import 'dart:async' show Future;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/image_loader/base_image_provider.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart'
    as image_provider;
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
    final isBase64 =
        url.startsWith('data:') ||
        (!url.contains('://') && !url.startsWith('/') && url.length > 100);
    final isFile = url.startsWith('file://');
    final isHttp = url.startsWith('http://') || url.startsWith('https://');

    if (!isBase64 && !isFile && !isHttp) {
      DebugLog.error('CachedImageProvider', url);
    }

    if (isBase64) {
      var raw = url;
      if (raw.contains(',')) {
        raw = raw.split(',').last;
      }
      final bytes = base64Decode(raw);
      chunkEvents.add(
        ImageChunkEvent(
          cumulativeBytesLoaded: bytes.length,
          expectedTotalBytes: bytes.length,
        ),
      );
      return bytes;
    }

    while (loadingCount > _kMaxLoadingCount) {
      await Future.delayed(const Duration(milliseconds: 100));
      checkStop();
    }
    loadingCount++;
    try {
      if (url.startsWith("file://")) {
        var file = File(url.substring(7));
        return file.readAsBytes();
      }

      await for (var progress in ImageDownloader.loadThumbnail(
        url,
        sourceKey,
        aid,
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
