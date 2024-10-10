import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

import '../anime_source/anime_source.dart';
import '../network/app_dio.dart';
import '../network/cookie_jar.dart';
import 'cache_manager.dart';
import 'def.dart';
import 'log.dart';

class BadRequestException {
  final String message;

  const BadRequestException(this.message);

  @override
  String toString() => message;
}

class ImageManager {
  static ImageManager? cache;

  ///用于标记正在加载的项目, 避免出现多个异步函数加载同一张图片
  static Map<String, DownloadProgress> loadingItems = {};

  /// Image cache manager for reader and download manager
  factory ImageManager() => cache ??= ImageManager._create();

  static bool get haveTask => loadingItems.isNotEmpty;

  static void clearTasks() {
    loadingItems.clear();
  }

  ImageManager._create();

  final dio = logDio(BaseOptions())
    ..interceptors.add(CookieManagerSql(SingleInstanceCookieJar.instance!));

  int ehgtLoading = 0;

  /// 获取图片, 适用于没有任何限制的图片链接
  Stream<DownloadProgress> getImage(final String url,
      [Map<String, String>? headers]) async* {
    await wait(url);
    loadingItems[url] = DownloadProgress(0, 1, url, "");
    CachingFile? caching;

    try {
      final key = url;
      var cache = await CacheManager().findCache(key);
      if (cache != null) {
        yield DownloadProgress(
            1, 1, url, cache, null, CacheManager().getType(key));
        loadingItems.remove(url);
        return;
      }

      final cachingFile = await CacheManager().openWrite(key);
      caching = cachingFile;
      final savePath = cachingFile.file.path;
      yield DownloadProgress(0, 100, url, savePath);
      headers = headers ?? {};
      headers["User-Agent"] ??= webUA;
      headers["Connection"] = "keep-alive";
      var realUrl = url;
      if (url.contains("s.exhentai.org")) {
        // s.exhentai.org 有严格的加载限制
        realUrl = url.replaceFirst("s.exhentai.org", "ehgt.org");
      }
      if (realUrl.contains("ehgt.org")) {
        if (ehgtLoading < 3) {
          ehgtLoading++;
          await Future.delayed(const Duration(milliseconds: 10));
        } else {
          while (ehgtLoading > 2) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          ehgtLoading++;
        }
      }
      var dioRes = await dio.get<ResponseBody>(realUrl,
          options:
              Options(responseType: ResponseType.stream, headers: headers));
      if (dioRes.data == null) {
        throw Exception("Empty Data");
      }
      List<int> imageData = [];
      int? expectedBytes;
      try {
        expectedBytes =
            int.parse(dioRes.data!.headers["Content-Length"]![0]) + 1;
      } catch (e) {
        //忽略
      }
      await for (var res in dioRes.data!.stream) {
        imageData.addAll(res);
        await cachingFile.writeBytes(res);
        var progress = DownloadProgress(imageData.length,
            (expectedBytes ?? imageData.length + 1), url, savePath);
        yield progress;
        loadingItems[url] = progress;
      }
      await cachingFile.close();
      var ext = getExt(dioRes);
      CacheManager().setType(key, ext);
      yield DownloadProgress(
        imageData.length,
        imageData.length,
        url,
        savePath,
        Uint8List.fromList(imageData),
        ext,
      );
    } catch (e, s) {
      caching?.cancel();
      log("$e\n$s", "Network", LogLevel.error);
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        var statusCode = e.response?.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          throw BadRequestException(e.message.toString());
        }
      }
      rethrow;
    } finally {
      if (url.contains("ehgt.org") || url.contains("s.exhentai.org")) {
        ehgtLoading--;
      }
      loadingItems.remove(url);
    }
  }

  String? getExt(Response res) {
    String? ext;
    var url = res.realUri.toString();
    var contentType =
        (res.headers["Content-Type"] ?? res.headers["content-type"])?[0];
    if (contentType != null) {
      ext = switch (contentType) {
        "image/jpeg" => "jpg",
        "image/png" => "png",
        "image/gif" => "gif",
        "image/webp" => "webp",
        _ => null
      };
    }
    ext ??= url.split('.').last;
    if (!["jpg", "jpeg", "png", "gif", "webp"].contains(ext)) {
      ext = "jpg";
      LogManager.addLog(
          LogLevel.warning,
          "ImageManager",
          "Unknown image extension: \n"
              "Content-Type: $contentType\n"
              "URL: $url");
    }
    return ext;
  }

  Future<void> wait(String cacheKey) {
    int timeout = 50;
    return Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      timeout--;
      if (timeout == 0) {
        loadingItems.remove(cacheKey);
        return false;
      }
      return loadingItems[cacheKey] != null;
    });
  }

  Stream<DownloadProgress> getCustomThumbnail(
      String url, String sourceKey) async* {
    var cacheKey = "$sourceKey$url";
    await wait(cacheKey);
    loadingItems[cacheKey] = DownloadProgress(0, 1, cacheKey, "");

    var cache = await CacheManager().findCache(cacheKey);
    if (cache != null) {
      yield DownloadProgress(1, 1, cacheKey, cache);
      loadingItems.remove(cacheKey);
      return;
    }

    CachingFile? caching;

    var source = AnimeSource.find(sourceKey) ??
        (throw "Unknown anime Source $sourceKey");

    try {
      Map<String, dynamic> config;

      if (source.getThumbnailLoadingConfig == null) {
        config = {};
      } else {
        config = source.getThumbnailLoadingConfig!(url);
      }

      caching = await CacheManager().openWrite(cacheKey);
      final savePath = caching.file.path;

      var res = await dio.request<ResponseBody>(config['url'] ?? url,
          data: config['data'],
          options: Options(
              method: config['method'] ?? 'GET',
              headers: config['headers'] ?? {'user-agent': webUA},
              responseType: ResponseType.stream));

      List<int> imageData = [];

      int? expectedBytes = res.data!.contentLength;
      if (expectedBytes == -1) {
        expectedBytes = null;
      }

      bool shouldModifyData = config['onResponse'] != null;

      await for (var data in res.data!.stream) {
        if (!shouldModifyData) {
          await caching.writeBytes(data);
        }
        imageData.addAll(data);
        var progress = DownloadProgress(imageData.length,
            expectedBytes ?? (imageData.length + 1), url, savePath);
        yield progress;
        loadingItems[cacheKey] = progress;
      }

      Uint8List? result;

      if (shouldModifyData) {
        var data = (config['onResponse']
            as JSInvokable)(Uint8List.fromList(imageData));
        imageData.clear();
        if (data is! Uint8List) {
          throw "Invalid Config: onImageLoad.onResponse return invalid type\n"
              "Expected: Uint8List(ArrayBuffer)\n"
              "Got: ${data.runtimeType}";
        }
        result = data;
        await caching.writeBytes(data);
      }

      await caching.close();
      yield DownloadProgress(
          1, 1, url, savePath, result ?? Uint8List.fromList(imageData));
    } catch (e, s) {
      Log.error("Network", "Failed to load a image:\nUrl:$url\nError:$e");
      caching?.cancel();
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        var statusCode = e.response?.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          throw BadRequestException(e.message.toString());
        }
      }
      rethrow;
    } finally {
      loadingItems.remove(cacheKey);
    }
  }
}

class DownloadProgress {
  final int _currentBytes;
  final int _expectedBytes;
  final String url;
  final String savePath;
  final Uint8List? data;
  final String? ext;

  int get currentBytes => _currentBytes;

  int get expectedBytes => _expectedBytes;

  bool get finished => _currentBytes == _expectedBytes;

  const DownloadProgress(
      this._currentBytes, this._expectedBytes, this.url, this.savePath,
      [this.data, this.ext]);

  File getFile() => File(savePath);
}

class ImageExceedError extends Error {
  @override
  String toString() => "Maximum image loading limit reached.";
}
