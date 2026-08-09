import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/utils/image.dart';

abstract class ImageDownloader {
  /// 对同一图片的并发请求去重：多个 provider 同时加载同一 URL 时只发起一次下载。
  static Stream<ImageDownloadProgress> loadThumbnail(
    String url,
    String? sourceKey, [
    String? aid,
  ]) {
    final cacheKey = "$url@$sourceKey${aid != null ? '@$aid' : ''}";
    final existing = _loadingImages[cacheKey];
    if (existing != null) return existing.stream;
    final wrapper = _StreamWrapper<ImageDownloadProgress>(
      _loadThumbnail(url, sourceKey, aid),
      (w) {
        _loadingImages.remove(cacheKey);
      },
    );
    _loadingImages[cacheKey] = wrapper;
    return wrapper.stream;
  }

  static Stream<ImageDownloadProgress> _loadThumbnail(
    String url,
    String? sourceKey, [
    String? aid,
  ]) async* {
    final cacheKey = "$url@$sourceKey${aid != null ? '@$aid' : ''}";
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
      final sourceHeaders = animeSource?.httpHeaders ?? {};
      configs['headers'] = {
        ...sourceHeaders,
        ...(configs['headers'] as Map? ?? {}),
      };
    }
    configs['headers'] ??= {};
    if (configs['headers']['user-agent'] == null &&
        configs['headers']['User-Agent'] == null) {
      configs['headers']['user-agent'] = webUA;
    }

    if (((configs['url'] as String?) ?? url).startsWith('cover.') &&
        sourceKey != null) {
      var animeSource = AnimeSource.find(sourceKey);
      if (animeSource != null) {
        var animeInfo = await animeSource.loadAnimeInfo!(aid!);
        yield* loadThumbnail(animeInfo.data.cover, sourceKey);
        return;
      }
    }

    // 图片请求用静默 dio：失败不打 error 日志（域名屏蔽/防火墙/抖动是常见可恢复场景）
    var dio = AppDio.quiet(
      BaseOptions(
        headers: Map<String, dynamic>.from(configs['headers']),
        method: configs['method'] ?? 'GET',
        responseType: ResponseType.stream,
      ),
    );

    Response<ResponseBody> req;
    try {
      req = await dio.request<ResponseBody>(
        configs['url'] ?? url,
        data: configs['data'],
      );
    } catch (e) {
      // 网络失败（域名不可达/防火墙/连接重置等）属于可恢复错误，
      // yield 失败标记，由上层显示占位；避免每次滚动重建重复请求刷屏
      yield ImageDownloadProgress(currentBytes: 0, totalBytes: null, error: e);
      return;
    }
    var stream = req.data?.stream ?? (throw "Error: Empty response body.");
    int? expectedBytes = req.data!.contentLength;
    if (expectedBytes == -1) {
      expectedBytes = null;
    }
    var buffer = <int>[];
    try {
      await for (var data in stream) {
        buffer.addAll(data);
        if (expectedBytes != null) {
          yield ImageDownloadProgress(
            currentBytes: buffer.length,
            totalBytes: expectedBytes,
          );
        }
      }
    } catch (e) {
      // 下载中途断开，静默结束
      return;
    }

    if (configs['onResponse'] is JSInvokable) {
      final uint8List = Uint8List.fromList(buffer);
      buffer = (configs['onResponse'] as JSInvokable)([uint8List]);
      (configs['onResponse'] as JSInvokable).free();
    }

    await CacheManager().writeCache(cacheKey, buffer);
    yield ImageDownloadProgress(
      currentBytes: buffer.length,
      totalBytes: buffer.length,
      imageBytes: Uint8List.fromList(buffer),
    );
  }

  static final _loadingImages =
      <String, _StreamWrapper<ImageDownloadProgress>>{};

  /// Cancel all loading images.
  static void cancelAllLoadingImages() {
    for (var wrapper in _loadingImages.values) {
      wrapper.cancel();
    }
    _loadingImages.clear();
  }

  /// Load a anime image from the network or cache.
  /// The function will prevent multiple requests for the same image.
  static Stream<ImageDownloadProgress> loadAnimeImage(
    String imageKey,
    String? sourceKey,
    String cid,
    String eid,
  ) {
    final cacheKey = "$imageKey@$sourceKey@$cid@$eid";
    if (_loadingImages.containsKey(cacheKey)) {
      return _loadingImages[cacheKey]!.stream;
    }
    final stream = _StreamWrapper<ImageDownloadProgress>(
      _loadAnimeImage(imageKey, sourceKey, cid, eid),
      (wrapper) {
        _loadingImages.remove(cacheKey);
      },
    );
    _loadingImages[cacheKey] = stream;
    return stream.stream;
  }

  static Stream<ImageDownloadProgress> _loadAnimeImage(
    String imageKey,
    String? sourceKey,
    String cid,
    String eid,
  ) async* {
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
      configs =
          (await animeSource!.getImageLoadingConfig?.call(
            imageKey,
            cid,
            eid,
          )) ??
          {};
      final sourceHeaders = animeSource.httpHeaders ?? {};
      configs['headers'] = {
        ...sourceHeaders,
        ...(configs['headers'] as Map? ?? {}),
      };
    }
    var retryLimit = 5;
    while (true) {
      try {
        configs['headers'] ??= {'user-agent': webUA};

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

        var dio = AppDio.quiet(
          BaseOptions(
            headers: configs['headers'],
            method: configs['method'] ?? 'GET',
            responseType: ResponseType.stream,
          ),
        );

        var req = await dio.request<ResponseBody>(
          configs['url'] ?? imageKey,
          data: configs['data'],
        );
        var stream = req.data?.stream ?? (throw "Error: Empty response body.");
        int? expectedBytes = req.data!.contentLength;
        if (expectedBytes == -1) {
          expectedBytes = null;
        }
        var buffer = <int>[];
        await for (var data in stream) {
          buffer.addAll(data);
          yield ImageDownloadProgress(
            currentBytes: buffer.length,
            totalBytes: expectedBytes,
          );
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

/// A wrapper class for a stream that
/// allows multiple listeners to listen to the same stream.
class _StreamWrapper<T> {
  final Stream<T> _stream;

  final List<StreamController> controllers = [];

  final void Function(_StreamWrapper<T> wrapper) onClosed;

  bool isClosed = false;

  /// 当没有剩余订阅者时设为 true，停止底层下载（省带宽）
  bool _cancelled = false;

  _StreamWrapper(this._stream, this.onClosed) {
    _listen();
  }

  void _listen() async {
    await for (var data in _stream) {
      if (isClosed || _cancelled) {
        break;
      }
      for (var controller in controllers) {
        if (!controller.isClosed) {
          controller.add(data);
        }
      }
    }
    for (var controller in controllers) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    controllers.clear();
    isClosed = true;
    onClosed(this);
  }

  Stream<T> get stream {
    if (isClosed) {
      throw Exception('Stream is closed');
    }
    var controller = StreamController<T>();
    controllers.add(controller);
    controller.onCancel = () {
      controllers.remove(controller);
      // 所有订阅者都取消时，终止底层下载
      if (controllers.isEmpty) {
        _cancelled = true;
      }
    };
    return controller.stream;
  }

  void cancel() {
    for (var controller in controllers) {
      controller.close();
    }
    controllers.clear();
    isClosed = true;
    _cancelled = true;
  }
}

class ImageDownloadProgress {
  final int currentBytes;

  final int? totalBytes;

  final Uint8List? imageBytes;

  /// 网络失败标记：非 null 表示加载失败（便于上层显示占位而非误导性报错）
  final Object? error;

  const ImageDownloadProgress({
    required this.currentBytes,
    required this.totalBytes,
    this.imageBytes,
    this.error,
  });
}
