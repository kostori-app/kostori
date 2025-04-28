import 'dart:async' show Future, StreamController;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kostori/network/images.dart';
import 'package:kostori/foundation/image_loader/base_image_provider.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart'
    as image_provider;
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
      await for (var progress
          in ImageDownloader.loadThumbnail(url, sourceKey, aid)) {
        checkStop();
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: progress.currentBytes,
          expectedTotalBytes: progress.totalBytes,
        ));
        if (progress.imageBytes != null) {
          return progress.imageBytes!;
        }
      }
      throw "Error: Empty response body.";
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
