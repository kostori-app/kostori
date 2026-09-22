import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/image_loader/base_image_provider.dart';
import 'package:kostori/foundation/image_loader/inline_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/utils/image.dart';

/// 同一张图并发只解析一次：列表重建、同一封面多处显示时很常见，
/// 否则会重复走 JS 引擎抓取/解密/压缩。
final Map<String, Future<Uint8List?>> _resolvingInlineImages = {};

/// 解析站内 base64 / `inline:<token>` 图片：
/// 先读本地缓存；短引用缓存失效时调源的 `loadInlineImage(token)` 回源一次
/// 并重新转存；裸 base64 则内存解码后转存。
Future<Uint8List?> resolveInlineImage(String url, String? sourceKey) {
  final pending = _resolvingInlineImages[url];
  if (pending != null) return pending;
  final task = _resolveInlineImage(url, sourceKey);
  _resolvingInlineImages[url] = task;
  return task.whenComplete(() {
    _resolvingInlineImages.remove(url);
  });
}

Future<Uint8List?> _resolveInlineImage(String url, String? sourceKey) async {
  if (InlineImageStore.isRef(url)) {
    final cached = await InlineImageStore.read(url);
    if (cached != null) return cached;
    final loader = sourceKey == null
        ? null
        : AnimeSource.find(sourceKey)?.loadInlineImage;
    if (loader == null) return null;
    try {
      final data = await loader(url.substring(InlineImageStore.prefix.length));
      if (data == null || data.isEmpty) return null;
      // loader 已在 parser 侧把大转换搬到后台，这里避免二次全量拷贝：
      // Uint8List 直接用；普通 List 大图才走一次 isolate 拷贝，
      // 小图同步拷贝（spawn 开销反而更大）。
      final bytes = await _asBytes(data);
      // 解密失败/被截断的内容不缓存也不显示，下次渲染自然会重试
      if (!InlineImageStore.looksLikeImage(bytes)) {
        DebugLog.warning('InlineImage', 'not an image: $url');
        return null;
      }
      unawaited(InlineImageStore.storeRef(url, bytes));
      return bytes;
    } catch (e) {
      // 只记简短原因（不带堆栈/底层长串），避免坏图刷屏
      DebugLog.warning(
        'InlineImage',
        'loadInlineImage failed: ${e.toString().split('\n').first}',
      );
      return null;
    }
  }
  if (!InlineImageStore.looksLikeBase64(url)) return null;
  final ref = await InlineImageStore.refOfAsync(url);
  final cached = await InlineImageStore.read(ref);
  if (cached != null) return cached;
  final bytes = await InlineImageStore.decodeAsync(url);
  if (bytes == null || !InlineImageStore.looksLikeImage(bytes)) return null;
  unawaited(InlineImageStore.storeBase64(url, ref: ref, bytes: bytes));
  return bytes;
}

/// 回源字节 → [Uint8List]：避免主线程大内存二次拷贝。
///
/// [Uint8List] 直接复用；普通 [List] 在较大时放到后台 isolate 做一次
/// `Uint8List.fromList`（纯内存拷贝，不碰 UI），小列表同步拷贝即可。
Future<Uint8List> _asBytes(List<int> data) {
  if (data is Uint8List) return Future.value(data);
  const kIsolateBytes = 64 * 1024;
  if (data.length < kIsolateBytes) {
    return Future.value(Uint8List.fromList(data));
  }
  try {
    return Isolate.run(() => Uint8List.fromList(data));
  } catch (_) {
    return Future.value(Uint8List.fromList(data));
  }
}

/// `cover.<id>` 占位封面：同一 (源, id) 只解析一次详情取封面，
/// 并发与重复显示都复用，避免每张封面反复跑源 JS `loadInfo`。
final Map<String, String> _coverPlaceholderCache = {};
final Map<String, Future<String?>> _coverPlaceholderTasks = {};

const int _kCoverPlaceholderCacheLimit = 128;

Future<String?> _resolveCoverPlaceholder(String sourceKey, String aid) {
  final key = '$sourceKey@$aid';
  final cached = _coverPlaceholderCache[key];
  if (cached != null) return Future.value(cached);
  final pending = _coverPlaceholderTasks[key];
  if (pending != null) return pending;
  final task = _loadCoverPlaceholder(sourceKey, aid, key);
  _coverPlaceholderTasks[key] = task;
  return task.whenComplete(() => _coverPlaceholderTasks.remove(key));
}

Future<String?> _loadCoverPlaceholder(
  String sourceKey,
  String aid,
  String key,
) async {
  try {
    final loader = AnimeSource.find(sourceKey)?.loadAnimeInfo;
    if (loader == null) return null;
    final info = await loader(aid);
    final cover = info.data.cover;
    if (cover.isEmpty) return null;
    _coverPlaceholderCache.remove(key);
    _coverPlaceholderCache[key] = cover;
    if (_coverPlaceholderCache.length > _kCoverPlaceholderCacheLimit) {
      _coverPlaceholderCache.remove(_coverPlaceholderCache.keys.first);
    }
    return cover;
  } catch (e) {
    DebugLog.warning('InlineImage', 'cover placeholder failed: $e');
    return null;
  }
}

/// JS `onResponse` 返回归一化：ArrayBuffer → 直接用，普通数组 → 拷贝，
/// 其它（源返回了非字节）→ null（调用方用原字节）。
Uint8List? _coerceBytes(dynamic value) {
  if (value == null) return null;
  if (value is Uint8List) return value;
  if (value is List<int>) return Uint8List.fromList(value);
  if (value is List) {
    try {
      return Uint8List.fromList(value.cast<int>());
    } catch (_) {
      return null;
    }
  }
  return null;
}

abstract class ImageDownloader {
  /// 对同一图片的并发请求去重：多个 provider 同时加载同一 URL 时只发起一次下载。
  static Stream<ImageDownloadProgress> loadThumbnail(
    String url,
    String? sourceKey, [
    String? aid,
    Map<String, String>? headers,
  ]) {
    // 去重键与磁盘键/内存键共用同一格式（长串用稳定 sha1，不再用 hashCode）
    final cacheKey = imageCacheKey(url, sourceKey, aid);
    final existing = _loadingImages[cacheKey];
    if (existing != null) return existing.stream;
    final wrapper = _StreamWrapper<ImageDownloadProgress>(
      _loadThumbnail(url, sourceKey, aid, headers),
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
    Map<String, String>? headers,
  ]) async* {
    // 站内 base64 / 转存短引用：没有 URL 可请求，直接用 inline 缓存/回源，
    // 不必再拿几百 KB 的 data URL 去 CacheManager 里算 md5 + 查库
    if (InlineImageStore.looksLikeBase64(url) || InlineImageStore.isRef(url)) {
      final bytes = await resolveInlineImage(url, sourceKey);
      if (bytes == null) {
        yield ImageDownloadProgress(
          currentBytes: 0,
          totalBytes: 0,
          error: 'inline image unavailable',
        );
        return;
      }
      yield ImageDownloadProgress(
        currentBytes: bytes.length,
        totalBytes: bytes.length,
        imageBytes: bytes,
      );
      return;
    }

    final cacheKey = imageCacheKey(url, sourceKey, aid);
    final cache = await CacheManager().findCache(cacheKey);

    if (cache != null) {
      // 缓存命中直接返回：此前命中后仍继续全量下载（静默刷新），导致每次
      // 滚动重建都重复费流量；封面/缩略图基本不可变，7 天过期足以保鲜。
      var data = await cache.readAsBytes();
      yield ImageDownloadProgress(
        currentBytes: data.length,
        totalBytes: data.length,
        imageBytes: data,
      );
      return;
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
    // 调用方显式传入的请求头（如 me-plugin 的 referer / cookie）优先
    if (headers != null && headers.isNotEmpty) {
      configs['headers'] = {...(configs['headers'] as Map? ?? {}), ...headers};
    }
    configs['headers'] ??= {};
    if (configs['headers']['user-agent'] == null &&
        configs['headers']['User-Agent'] == null) {
      configs['headers']['user-agent'] = webUA;
    }

    final resolvedUrl = (configs['url'] as String?) ?? url;
    if (resolvedUrl.startsWith('cover.') && sourceKey != null && aid != null) {
      final cover = await _resolveCoverPlaceholder(sourceKey, aid);
      if (cover != null) {
        yield* loadThumbnail(cover, sourceKey);
        return;
      }
    }

    // 图片请求用静默 dio：失败不打 error 日志（域名屏蔽/防火墙/抖动是常见可恢复场景）
    var dio = AppDio.quiet(
      BaseOptions(
        headers: Map<String, dynamic>.from(configs['headers']),
        method: configs['method'] ?? 'GET',
        responseType: ResponseType.stream,
        // 图片加载用更短的连接超时：无法访问的域名尽早失败，
        // 避免占用并发加载槽位拖慢其他图片
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
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
    // BytesBuilder 累积：List.addAll 逐 chunk 搬运是 O(n²)，大图分片多时
    // 主线程 CPU 与内存峰值翻倍；toBytes() 零拷贝交付
    final builder = BytesBuilder();
    try {
      await for (var data in stream) {
        builder.add(data);
        if (expectedBytes != null) {
          yield ImageDownloadProgress(
            currentBytes: builder.length,
            totalBytes: expectedBytes,
          );
        }
      }
    } catch (e) {
      // 下载中途断开，静默结束
      return;
    }

    Uint8List bytes;
    if (configs['onResponse'] is JSInvokable) {
      // JS 回调抛错也必须 free，否则 QuickJS 句柄永久泄漏
      final cb = configs['onResponse'] as JSInvokable;
      try {
        bytes = _coerceBytes(cb([builder.toBytes()])) ?? builder.toBytes();
      } finally {
        cb.free();
      }
    } else {
      bytes = builder.toBytes();
    }

    await CacheManager().writeCache(cacheKey, bytes);
    yield ImageDownloadProgress(
      currentBytes: bytes.length,
      totalBytes: bytes.length,
      imageBytes: bytes,
    );
  }

  static final _loadingImages =
      <String, _StreamWrapper<ImageDownloadProgress>>{};

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
      // 同上：命中直接返回，避免每看一次就重下一遍漫画页（页图不可变）。
      var data = await cache.readAsBytes();
      yield ImageDownloadProgress(
        currentBytes: data.length,
        totalBytes: data.length,
        imageBytes: data,
      );
      return;
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
        final builder = BytesBuilder();
        await for (var data in stream) {
          builder.add(data);
          yield ImageDownloadProgress(
            currentBytes: builder.length,
            totalBytes: expectedBytes,
          );
        }

        Uint8List data;
        if (configs['onResponse'] is JSInvokable) {
          final cb = configs['onResponse'] as JSInvokable;
          try {
            data = _coerceBytes(cb([builder.toBytes()])) ?? builder.toBytes();
          } finally {
            cb.free();
          }
        } else {
          data = builder.toBytes();
        }

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
        // onLoadFailed 回调的 free 必须走 finally：拿到新配置前任何抛错
        //（含回调自身抛错）都不能泄漏句柄
        final pending = onLoadFailed;
        if (retryLimit < 0 || pending == null) {
          rethrow;
        }
        onLoadFailed = null;
        final cb = configs['onLoadFailed'] as JSInvokable;
        try {
          var newConfig = await pending();
          if (newConfig == null) {
            rethrow;
          }
          configs = newConfig;
          retryLimit--;
        } finally {
          cb.free();
        }
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
