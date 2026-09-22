import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/cache.dart';
import 'package:kostori/network/cloudflare.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/network/proxy.dart';
import 'package:rhttp/rhttp.dart' as rhttp;

export 'package:dio/dio.dart';

class MyLogInterceptor extends Interceptor {
  /// 隐私脱敏：敏感请求/响应头的值打码；cookie 只保留名字（便于排查又不泄露）。
  static String _redactHeaders(Map<dynamic, dynamic> headers) {
    bool sensitive(String lower) =>
        lower == 'authorization' ||
        lower == 'proxy-authorization' ||
        lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('password') ||
        lower.contains('api-key') ||
        lower.contains('apikey') ||
        lower.contains('auth');
    final out = <String, String>{};
    headers.forEach((k, v) {
      final key = k.toString();
      final lower = key.toLowerCase();
      if (lower == 'cookie' || lower == 'set-cookie') {
        final names = v
            .toString()
            .split(';')
            .map((p) => p.split('=').first.trim())
            .where((n) => n.isNotEmpty)
            .toSet();
        out[key] = '<${names.length} cookie(s): ${names.join(', ')}>';
      } else if (sensitive(lower)) {
        out[key] = '<redacted>';
      } else {
        out[key] = v.toString();
      }
    });
    return out.toString();
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 标注 noLog 的请求（如 HLS 分片，动辄上千条）不记录，避免刷屏
    if (err.requestOptions.extra['noLog'] == true) {
      handler.next(err);
      return;
    }
    // 请求失败一律记录（错误日志不需要正文），概要模式下也只记一行；
    // 带上脱敏后的请求头，便于定位问题
    NetLog.error(
      "Network",
      NetLog.metaOnly
          ? '${err.requestOptions.method} ${err.requestOptions.uri} → ${err.response?.statusCode ?? err.type.name}'
          : "${err.requestOptions.method} ${err.requestOptions.path}\n"
                "request headers:\n${_redactHeaders(err.requestOptions.headers)}\n"
                "$err\n${err.response?.data.toString()}",
    );
    switch (err.type) {
      case DioExceptionType.badResponse:
        var statusCode = err.response?.statusCode;
        if (statusCode != null) {
          err = err.copyWith(
            message:
                "Invalid Status Code: $statusCode. "
                "${_getStatusCodeInfo(statusCode)}",
          );
        }
      case DioExceptionType.connectionTimeout:
        err = err.copyWith(message: t.connectionTimeout);
      case DioExceptionType.receiveTimeout:
        err = err.copyWith(message: t.receiveTimeout);
      case DioExceptionType.unknown:
        if (err.toString().contains("Connection terminated during handshake")) {
          err = err.copyWith(message: t.connectionTerminatedDuringHandshake);
        } else if (err.toString().contains("Connection reset by peer")) {
          err = err.copyWith(message: t.connectionResetByPeer);
        }
      default:
        {}
    }
    handler.next(err);
  }

  static const errorMessages = <int, String>{
    400: "The Request is invalid.",
    401: "The Request is unauthorized.",
    403: "No permission to access the resource. Check your account or network.",
    404: "Not found.",
    429: "Too many requests. Please try again later.",
  };

  String _getStatusCodeInfo(int? statusCode) {
    if (statusCode != null && statusCode >= 500) {
      return "This is server-side error, please try again later. "
          "Do not report this issue.";
    } else {
      return errorMessages[statusCode] ?? "";
    }
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // 标注 noLog 的请求（如 HLS 分片）不记录
    if (response.requestOptions.extra['noLog'] == true) {
      handler.next(response);
      return;
    }
    if (!NetLog.enabled) {
      handler.next(response);
      return;
    }
    // 二进制响应（图片/文件下载）成功时静默：量大且基本是缩略图，只有失败才需要日志
    if (response.data is List<int> && (response.statusCode ?? 0) < 400) {
      handler.next(response);
      return;
    }
    final startedMs = response.requestOptions.extra['__logStartMs'];
    final costMs = startedMs is int
        ? DateTime.now().millisecondsSinceEpoch - startedMs
        : null;
    if (NetLog.metaOnly) {
      // 概要模式：一行记录「状态/大小/耗时」，不含头与正文
      final len =
          response.headers.value('content-length') ??
          (response.data is List<int>
              ? '${(response.data as List<int>).length}'
              : '');
      NetLog.log(
        (response.statusCode != null && response.statusCode! < 400)
            ? LogLevel.info
            : LogLevel.error,
        '← Network',
        '${response.statusCode} ${response.realUri}'
            '${len.isNotEmpty ? ' · $len B' : ''}'
            '${costMs != null ? ' · ${costMs}ms' : ''}',
      );
      handler.next(response);
      return;
    }
    var headers = response.headers.map.map(
      (key, value) => MapEntry(
        key.toLowerCase(),
        value.length == 1 ? value.first : value.toString(),
      ),
    );
    // 日志正文限长：大响应（大 JSON/HTML、二进制）只记长度/前缀，
    // 避免构造并持有 MB 级字符串（内存与卡顿的主要来源）
    const logBodyLimit = 32768;
    String content;
    if (response.data is List<int>) {
      final bytes = response.data as List<int>;
      if (bytes.length > logBodyLimit) {
        content = "<Bytes>\nlength:${bytes.length} (body omitted)";
      } else {
        try {
          content = utf8.decode(bytes, allowMalformed: false);
        } catch (e) {
          content = "<Bytes>\nlength:${bytes.length}";
        }
      }
    } else {
      final s = response.data.toString();
      content = s.length > logBodyLimit
          ? '${s.substring(0, logBodyLimit)}…(omitted ${s.length - logBodyLimit} chars)'
          : s;
    }

    NetLog.log(
      (response.statusCode != null && response.statusCode! < 400)
          ? LogLevel.info
          : LogLevel.error,
      "Network",
      "Response ${response.realUri.toString()} ${response.statusCode}\n"
          "headers:\n${_redactHeaders(headers)}\n$content",
    );

    handler.next(response);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 计时：概要模式用
    options.extra['__logStartMs'] = DateTime.now().millisecondsSinceEpoch;
    // 标注 noLog 的请求（如 HLS 分片，动辄上千条）不记录，避免刷屏
    if (options.extra['noLog'] == true) {
      handler.next(options);
      return;
    }
    if (!NetLog.enabled) {
      handler.next(options);
      return;
    }
    if (NetLog.metaOnly) {
      // 概要模式：只记一行，不打请求头/正文。
      // 二进制请求（图片/文件）成功时会静默，这里也不打请求行（失败由 onError 记录）
      if (options.responseType != ResponseType.bytes) {
        NetLog.info("→ Network", '${options.method} ${options.uri}');
      }
      handler.next(options);
      return;
    }
    if (options.responseType == ResponseType.bytes) {
      handler.next(options);
      return;
    }
    // 请求体同样限长（base64 图片上传等可能很大）
    final rawData = options.data?.toString() ?? '';
    const reqLimit = 16384;
    final data = rawData.length > reqLimit
        ? '${rawData.substring(0, reqLimit)}…(omitted ${rawData.length - reqLimit} chars)'
        : rawData;
    NetLog.info(
      "Network",
      "${options.method} ${options.uri}\n"
          "headers:\n${_redactHeaders(options.headers)}\n"
          "data:\n$data",
    );

    // 流式请求不强制覆盖超时，避免长时间停顿（如推理思考）被误判为超时；
    // 非流式请求仅在调用方未显式指定超时时套用默认值（防止覆盖 AI 等接口的显式超时）
    if (options.extra['streaming'] != true) {
      options.connectTimeout ??= const Duration(seconds: 15);
      options.receiveTimeout ??= const Duration(seconds: 15);
      options.sendTimeout ??= const Duration(seconds: 15);
    }
    handler.next(options);
  }
}

/// 把网络异常转成给用户看的简短信息：错误类型 + 状态码 + 访问地址。
/// 不再原样输出 DioException / 底层库的长串。
String networkErrorMessage(Object? error) {
  // 保持 Cloudflare 标记原样：NetworkError 靠它识别并给出验证按钮
  if (error is CloudflareException) return error.toString();
  if (error is DioException) {
    final status = error.response?.statusCode;
    final typeText = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => t.connectionTimedOut,
      DioExceptionType.cancel => t.cancel,
      DioExceptionType.badResponse => t.requestFailed,
      DioExceptionType.badCertificate ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => t.connectionFailed,
    };
    final statusPart = status != null ? ' · HTTP $status' : '';
    return '$typeText$statusPart\n${error.requestOptions.uri}';
  }
  return error?.toString() ?? 'Unknown error';
}

class AppDio with DioMixin {
  /// 是否打印请求/响应/错误日志。静默模式用于图片缩略图、
  /// 后台轮询等失败属正常场景的请求，避免 error 日志刷屏。
  final bool verboseLog;

  AppDio([
    // ignore: prefer_initializing_formals
    BaseOptions? options,
    bool verboseLog = true,
  ]) : verboseLog = verboseLog {
    this.options = options ?? BaseOptions();
    httpClientAdapter = RHttpAdapter();
    if (App.isInitialized) {
      interceptors.add(CookieManagerSql());
      interceptors.add(NetworkCacheManager());
      interceptors.add(CloudflareInterceptor());
      // 图片缩略图等高频、可恢复的请求不打 error 日志，避免刷屏
      if (verboseLog) {
        interceptors.add(MyLogInterceptor());
      }
    }
  }

  /// 静默模式：不打印请求/响应/错误日志。
  AppDio.quiet([BaseOptions? options]) : this(options, false);

  static final Map<String, bool> _requests = {};

  @override
  Future<Response<T>> request<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (options?.headers?['prevent-parallel'] == 'true') {
      while (_requests.containsKey(path)) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      _requests[path] = true;
      options!.headers!.remove('prevent-parallel');
    }
    try {
      return await super.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } finally {
      if (_requests.containsKey(path)) {
        _requests.remove(path);
      }
    }
  }
}

class RHttpAdapter implements HttpClientAdapter {
  Future<rhttp.ClientSettings> settings(RequestOptions options) async {
    final proxy = await getProxy();

    final noProxyOverrides =
        appdata.settings['noProxyOverrides'] as List? ?? [];

    final enableNoProxyOverrides =
        appdata.settings['enableNoProxyOverrides'] as bool? ?? true;

    final isNoProxy = enableNoProxyOverrides
        ? noProxyOverrides.any((entry) {
            if (entry is Map) {
              final domain = entry['domain']?.toString() ?? '';
              final enabled = entry['enabled'] as bool? ?? true;
              return enabled && options.uri.host.startsWith(domain);
            }
            // 兼容旧版仅存域名字符串的格式
            return options.uri.host.startsWith(entry.toString());
          })
        : false;

    // 尊重 dio 的重定向设置：maxRedirects:0 / followRedirects:false 时不跟随，
    // 便于登录/授权等流程拦截 302（chii_auth、location 等关键信息在 302 响应里）
    final redirectSettings =
        options.followRedirects == false || options.maxRedirects <= 0
        ? const rhttp.RedirectSettings.none()
        : rhttp.RedirectSettings.limited(options.maxRedirects);

    // 下载等场景强制 HTTP/1.1：部分 CDN（moedet/CCDN 等）对
    // reqwest 默认协商出的 HTTP/2 请求返回 400，而 curl/浏览器（HTTP/1.1）正常
    final httpVersionPref = options.extra['httpVersion11'] == true
        ? rhttp.HttpVersionPref.http1_1
        : rhttp.HttpVersionPref.all;

    return rhttp.ClientSettings(
      httpVersionPref: httpVersionPref,
      proxySettings: isNoProxy
          ? const rhttp.ProxySettings.noProxy()
          : (proxy == null
                ? const rhttp.ProxySettings.noProxy()
                : rhttp.ProxySettings.proxy(proxy)),
      redirectSettings: redirectSettings,
      timeoutSettings: const rhttp.TimeoutSettings(
        connectTimeout: Duration(seconds: 15),
        keepAliveTimeout: Duration(seconds: 60),
        keepAlivePing: Duration(seconds: 30),
      ),
      throwOnStatusCode: false,
      dnsSettings: rhttp.DnsSettings.static(overrides: _getOverrides()),
      tlsSettings: rhttp.TlsSettings(
        sni: appdata.settings['sni'] != false,
        verifyCertificates: appdata.settings['ignoreBadCertificate'] != true,
      ),
    );
  }

  static Map<String, List<String>> _getOverrides() {
    if (appdata.settings['enableDnsOverrides'] != true) {
      return {};
    }

    final config = appdata.settings["dnsOverrides"];
    final result = <String, List<String>>{};

    if (config is Map) {
      for (var entry in config.entries) {
        if (entry.key is String && entry.value is Map) {
          final valueMap = entry.value as Map;
          final ip = valueMap['ip']?.toString();
          final enabled = valueMap['enabled'] as bool? ?? true;

          if (enabled && ip != null && ip.isNotEmpty) {
            result[entry.key] = [ip];
          }
        } else if (entry.key is String && entry.value is String) {
          // 兼容旧版仅存 ip 字符串的格式
          final ip = entry.value as String;
          if (ip.isNotEmpty) {
            result[entry.key as String] = [ip];
          }
        }
      }
    }

    return result;
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.headers['User-Agent'] == null &&
        options.headers['user-agent'] == null) {
      options.headers['User-Agent'] =
          "kostori/v${App.version} (Android) (https://github.com/kostori-app/kostori)";
    }

    // 将 dio 的取消信号转发给 rhttp，真正中断正在进行的（流式）请求
    final rhttpCancelToken = cancelFuture == null ? null : rhttp.CancelToken();
    if (rhttpCancelToken != null) {
      unawaited(cancelFuture!.then((_) => rhttpCancelToken.cancel()));
    }

    var res = await rhttp.Rhttp.request(
      method: rhttp.HttpMethod(options.method),
      url: options.uri.toString(),
      settings: await settings(options),
      expectBody: rhttp.HttpExpectBody.stream,
      body: requestStream == null ? null : rhttp.HttpBody.stream(requestStream),
      headers: rhttp.HttpHeaders.rawMap(
        Map.fromEntries(
          options.headers.entries.map(
            (e) => MapEntry(e.key, e.value.toString().trim()),
          ),
        ),
      ),
      cancelToken: rhttpCancelToken,
    );
    if (res is! rhttp.HttpStreamResponse) {
      throw Exception("Invalid response type: ${res.runtimeType}");
    }
    var headers = <String, List<String>>{};
    for (var entry in res.headers) {
      var key = entry.$1.toLowerCase();
      headers[key] ??= [];
      headers[key]!.add(entry.$2);
    }
    return ResponseBody(
      _guardBody(options, res.body),
      res.statusCode,
      statusMessage: _getStatusMessage(res.statusCode),
      isRedirect: false,
      headers: headers,
    );
  }

  /// 把响应体流的错误统一转成 [DioException]。
  ///
  /// rhttp/reqwest 在响应体解码失败时（压缩编码不支持、连接中途断开等）会抛出
  /// `AnyhowException("error decoding response body")`；它既不是 [DioException]、
  /// 也可能没有正常挂到 dio 的错误管线里，表现为裸露的 flutter_rust_bridge 异常。
  /// 这里包一层，交给统一的错误处理/重试逻辑，并记录请求地址便于排查。
  Stream<Uint8List> _guardBody(
    RequestOptions options,
    Stream<Uint8List> body,
  ) async* {
    try {
      yield* body;
    } catch (e, s) {
      NetLog.error('Network', '${options.method} ${options.uri} 响应体读取失败: $e');
      Error.throwWithStackTrace(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          error: e,
          message: t.networkRequestFailed,
        ),
        s,
      );
    }
  }

  static String _getStatusMessage(int statusCode) {
    return switch (statusCode) {
      200 => "OK",
      201 => "Created",
      202 => "Accepted",
      204 => "No Content",
      206 => "Partial Content",
      301 => "Moved Permanently",
      302 => "Found",
      400 => "Invalid Status Code 400: The Request is invalid.",
      401 => "Invalid Status Code 401: The Request is unauthorized.",
      403 => "Invalid Status Code 403: No permission to access the resource. Check your account or network.",
      404 => "Invalid Status Code 404: Not found.",
      429 =>
        "Invalid Status Code 429: Too many requests. Please try again later.",
      _ => "Invalid Status Code $statusCode",
    };
  }
}

/// WebDAV 专用适配器：在 [RHttpAdapter] 基础上强制 HTTP/1.1 且声明不接受压缩响应，
/// 规避部分 WebDAV 服务器 / 反代返回无法解码的响应体
/// （reqwest 报 "error decoding response body"）。
class WebdavRHttpAdapter extends RHttpAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    options.headers['Accept-Encoding'] = 'identity';
    options.extra['httpVersion11'] = true;
    return super.fetch(options, requestStream, cancelFuture);
  }
}

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 0,
    this.retryDelay = const Duration(seconds: 2),
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    var shouldRetry = _shouldRetryOn(err);
    var extra = err.requestOptions.extra;
    var retryCount = (extra["__retry_count__"] as int?) ?? 0;

    if (shouldRetry && retryCount < maxRetries) {
      await Future.delayed(retryDelay);
      final newOptions = err.requestOptions;
      newOptions.extra = Map.from(newOptions.extra)
        ..["__retry_count__"] = retryCount + 1;
      try {
        final response = await dio.fetch(newOptions);
        return handler.resolve(response);
      } catch (e) {
        return handler.reject(e as DioException);
      }
    }

    return handler.next(err);
  }

  bool _shouldRetryOn(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.unknown;
  }
}
