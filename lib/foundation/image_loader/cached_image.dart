import 'dart:async' show Future, StreamController;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kostori/network/images.dart';
import 'package:kostori/foundation/image_loader/base_image_provider.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart'
    as image_provider;

class CachedImageProvider
    extends BaseImageProvider<image_provider.CachedImageProvider> {
  /// Image provider for normal image.
  const CachedImageProvider(this.url, {this.headers, this.sourceKey, this.aid});

  final String url;

  final Map<String, String>? headers;

  final String? sourceKey;

  final String? aid;

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    await for (var progress in ImageDownloader.loadThumbnail(url, sourceKey)) {
      chunkEvents.add(ImageChunkEvent(
        cumulativeBytesLoaded: progress.currentBytes,
        expectedTotalBytes: progress.totalBytes,
      ));
      if (progress.imageBytes != null) {
        return progress.imageBytes!;
      }
    }
    throw "Error: Empty response body.";
  }

  @override
  Future<CachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => url + (sourceKey ?? "") + (aid ?? "");
}
