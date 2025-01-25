import 'dart:async' show Future, StreamController;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kostori/network/images.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/image_loader/base_image_provider.dart';
import 'package:kostori/foundation/image_loader/local_favorite_image.dart'
    as image_provider;

class LocalFavoriteImageProvider
    extends BaseImageProvider<image_provider.LocalFavoriteImageProvider> {
  /// Image provider for normal image.
  const LocalFavoriteImageProvider(this.url, this.id, this.intKey);

  final String url;

  final String id;

  final int intKey;

  static void delete(String id, int intKey) {
    var fileName = (id + intKey.toString()).hashCode.toString();
    var file = File(FilePath.join(App.dataPath, 'favorite_cover', fileName));
    if (file.existsSync()) {
      file.delete();
    }
  }

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    var sourceKey = AnimeSource.fromIntKey(intKey)?.key;
    var fileName = key.hashCode.toString();
    var file = File(FilePath.join(App.dataPath, 'favorite_cover', fileName));
    if (await file.exists()) {
      return await file.readAsBytes();
    } else {
      await file.create(recursive: true);
    }
    await for (var progress in ImageDownloader.loadThumbnail(url, sourceKey)) {
      chunkEvents.add(ImageChunkEvent(
        cumulativeBytesLoaded: progress.currentBytes,
        expectedTotalBytes: progress.totalBytes,
      ));
      if (progress.imageBytes != null) {
        var data = progress.imageBytes!;
        await file.writeAsBytes(data);
        return data;
      }
    }
    throw "Error: Empty response body.";
  }

  @override
  Future<LocalFavoriteImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => id + intKey.toString();
}
