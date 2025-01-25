import 'dart:typed_data';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/utils/image.dart';
import 'package:kostori/network/app_dio.dart';

class ImageDownloader {
  static Stream<ImageDownloadProgress> loadThumbnail(
      String url, String? sourceKey) async* {
    final cacheKey = "$url@$sourceKey";
    final cache = await CacheManager().findCache(cacheKey);

    if (cache != null) {
      var data = await cache.readAsBytes();
      yield ImageDownloadProgress(
        currentBytes: data.length,
        totalBytes: data.length,
        imageBytes: data,
      );
    }

    var configs = <String, dynamic>{};
    if (sourceKey != null) {
      var animeSource = AnimeSource.find(sourceKey);
      configs = animeSource?.getThumbnailLoadingConfig?.call(url) ?? {};
    }
    configs['headers'] ??= {};
    if (configs['headers']['user-agent'] == null &&
        configs['headers']['User-Agent'] == null) {
      configs['headers']['user-agent'] = webUA;
    }

    var dio = AppDio(BaseOptions(
      headers: Map<String, dynamic>.from(configs['headers']),
      method: configs['method'] ?? 'GET',
      responseType: ResponseType.stream,
    ));

    var req = await dio.request<ResponseBody>(configs['url'] ?? url,
        data: configs['data']);
    var stream = req.data?.stream ?? (throw "Error: Empty response body.");
    int? expectedBytes = req.data!.contentLength;
    if (expectedBytes == -1) {
      expectedBytes = null;
    }
    var buffer = <int>[];
    await for (var data in stream) {
      buffer.addAll(data);
      if (expectedBytes != null) {
        yield ImageDownloadProgress(
          currentBytes: buffer.length,
          totalBytes: expectedBytes,
        );
      }
    }

    if (configs['onResponse'] is JSInvokable) {
      buffer = (configs['onResponse'] as JSInvokable)([buffer]);
      (configs['onResponse'] as JSInvokable).free();
    }

    await CacheManager().writeCache(cacheKey, buffer);
    yield ImageDownloadProgress(
      currentBytes: buffer.length,
      totalBytes: buffer.length,
      imageBytes: Uint8List.fromList(buffer),
    );
  }

  static Stream<ImageDownloadProgress> loadAnimeImage(
      String imageKey, String? sourceKey, String cid, String eid) async* {
    final cacheKey = "$imageKey@$sourceKey@$cid@$eid";
    final cache = await CacheManager().findCache(cacheKey);

    if (cache != null) {
      var data = await cache.readAsBytes();
      yield ImageDownloadProgress(
        currentBytes: data.length,
        totalBytes: data.length,
        imageBytes: data,
      );
    }

    Future<Map<String, dynamic>?> Function()? onLoadFailed;

    var configs = <String, dynamic>{};
    if (sourceKey != null) {
      var animeSource = AnimeSource.find(sourceKey);
      configs = (await animeSource!.getImageLoadingConfig
              ?.call(imageKey, cid, eid)) ??
          {};
    }
    var retryLimit = 5;
    while (true) {
      try {
        configs['headers'] ??= {
          'user-agent': webUA,
        };

        if (configs['onLoadFailed'] is JSInvokable) {
          onLoadFailed = () async {
            dynamic result = (configs['onLoadFailed'] as JSInvokable)([]);
            if (result is Future) {
              result = await result;
            }
            if (result is! Map<String, dynamic>) return null;
            return result;
          };
        }

        var dio = AppDio(BaseOptions(
          headers: configs['headers'],
          method: configs['method'] ?? 'GET',
          responseType: ResponseType.stream,
        ));

        var req = await dio.request<ResponseBody>(configs['url'] ?? imageKey,
            data: configs['data']);
        var stream = req.data?.stream ?? (throw "Error: Empty response body.");
        int? expectedBytes = req.data!.contentLength;
        if (expectedBytes == -1) {
          expectedBytes = null;
        }
        var buffer = <int>[];
        await for (var data in stream) {
          buffer.addAll(data);
          if (expectedBytes != null) {
            yield ImageDownloadProgress(
              currentBytes: buffer.length,
              totalBytes: expectedBytes,
            );
          }
        }

        if (configs['onResponse'] is JSInvokable) {
          buffer = (configs['onResponse'] as JSInvokable)([buffer]);
          (configs['onResponse'] as JSInvokable).free();
        }

        var data = Uint8List.fromList(buffer);
        buffer.clear();

        if (configs['modifyImage'] != null) {
          var newData = await modifyImageWithScript(
            data,
            configs['modifyImage'],
          );
          data = newData;
        }

        await CacheManager().writeCache(cacheKey, data);
        yield ImageDownloadProgress(
          currentBytes: data.length,
          totalBytes: data.length,
          imageBytes: data,
        );
        return;
      } catch (e) {
        if (retryLimit < 0 || onLoadFailed == null) {
          rethrow;
        }
        var newConfig = await onLoadFailed();
        (configs['onLoadFailed'] as JSInvokable).free();
        onLoadFailed = null;
        if (newConfig == null) {
          rethrow;
        }
        configs = newConfig;
        retryLimit--;
      } finally {
        if (onLoadFailed != null) {
          (configs['onLoadFailed'] as JSInvokable).free();
        }
      }
    }
  }
}

class ImageDownloadProgress {
  final int currentBytes;

  final int totalBytes;

  final Uint8List? imageBytes;

  const ImageDownloadProgress({
    required this.currentBytes,
    required this.totalBytes,
    this.imageBytes,
  });
}
