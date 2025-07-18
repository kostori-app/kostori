import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/cache.dart';
import 'package:kostori/network/cloudflare.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/network/proxy.dart';
import 'package:rhttp/rhttp.dart' as rhttp;

export 'package:dio/dio.dart';

class MyLogInterceptor implements Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (appdata.settings['debugInfo']) {
      Log.error(
        "Network",
        "${err.requestOptions.method} ${err.requestOptions.path}\n$err\n${err.response?.data.toString()}",
      );
    }
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
        err = err.copyWith(message: "Connection Timeout");
      case DioExceptionType.receiveTimeout:
        err = err.copyWith(
          message:
              "Receive Timeout: "
              "This indicates that the server is too busy to respond",
        );
      case DioExceptionType.unknown:
        if (err.toString().contains("Connection terminated during handshake")) {
          err = err.copyWith(
            message:
                "Connection terminated during handshake: "
                "This may be caused by the firewall blocking the connection "
                "or your requests are too frequent.",
          );
        } else if (err.toString().contains("Connection reset by peer")) {
          err = err.copyWith(
            message:
                "Connection reset by peer: "
                "The error is unrelated to app, please check your network.",
          );
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
    var headers = response.headers.map.map(
      (key, value) => MapEntry(
        key.toLowerCase(),
        value.length == 1 ? value.first : value.toString(),
      ),
    );
    headers.remove("cookie");
    String content;
    if (response.data is List<int>) {
      try {
        content = utf8.decode(response.data, allowMalformed: false);
      } catch (e) {
        content = "<Bytes>\nlength:${response.data.length}";
      }
    } else {
      content = response.data.toString();
    }

    if (appdata.settings['debugInfo']) {
      Log.addLog(
        (response.statusCode != null && response.statusCode! < 400)
            ? LogLevel.info
            : LogLevel.error,
        "Network",
        "Response ${response.realUri.toString()} ${response.statusCode}\n"
            "headers:\n$headers\n$content",
      );
    }

    handler.next(response);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (appdata.settings['debugInfo']) {
      Log.info(
        "Network",
        "${options.method} ${options.uri}\n"
            "headers:\n${options.headers}\n"
            "data:\n${options.data}",
      );
    }

    options.connectTimeout = const Duration(seconds: 15);
    options.receiveTimeout = const Duration(seconds: 15);
    options.sendTimeout = const Duration(seconds: 15);
    handler.next(options);
  }
}

class AppDio with DioMixin {
  AppDio([BaseOptions? options]) {
    this.options = options ?? BaseOptions();
    httpClientAdapter = RHttpAdapter();
    interceptors.add(CookieManagerSql(SingleInstanceCookieJar.instance!));
    interceptors.add(NetworkCacheManager());
    interceptors.add(CloudflareInterceptor());
    interceptors.add(MyLogInterceptor());
    interceptors.add(RetryInterceptor(dio: this));
  }

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
      return super.request<T>(
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
  // Future<rhttp.ClientSettings> get settings async {
  //   var proxy = await getProxy();
  //
  //   return rhttp.ClientSettings(
  //     proxySettings: proxy == null
  //         ? const rhttp.ProxySettings.noProxy()
  //         : rhttp.ProxySettings.proxy(proxy),
  //     redirectSettings: const rhttp.RedirectSettings.limited(5),
  //     timeoutSettings: const rhttp.TimeoutSettings(
  //       connectTimeout: Duration(seconds: 15),
  //       keepAliveTimeout: Duration(seconds: 60),
  //       keepAlivePing: Duration(seconds: 30),
  //     ),
  //     throwOnStatusCode: false,
  //     dnsSettings: rhttp.DnsSettings.static(overrides: _getOverrides()),
  //     tlsSettings: rhttp.TlsSettings(sni: appdata.settings['sni'] != false),
  //   );
  // }

  Future<rhttp.ClientSettings> settings(Uri uri) async {
    final proxy = await getProxy();

    // 判断 host 是否以 bgm 或 bangumi 开头，决定是否绕过代理
    final isNoProxy =
        uri.host.startsWith('bgm') || uri.host.startsWith('bangumi');

    return rhttp.ClientSettings(
      proxySettings: isNoProxy
          ? const rhttp.ProxySettings.noProxy()
          : (proxy == null
                ? const rhttp.ProxySettings.noProxy()
                : rhttp.ProxySettings.proxy(proxy)),
      redirectSettings: const rhttp.RedirectSettings.limited(5),
      timeoutSettings: const rhttp.TimeoutSettings(
        connectTimeout: Duration(seconds: 15),
        keepAliveTimeout: Duration(seconds: 60),
        keepAlivePing: Duration(seconds: 30),
      ),
      throwOnStatusCode: false,
      dnsSettings: rhttp.DnsSettings.static(overrides: _getOverrides()),
      tlsSettings: rhttp.TlsSettings(sni: appdata.settings['sni'] != false),
    );
  }

  static Map<String, List<String>> _getOverrides() {
    if (!appdata.settings['enableDnsOverrides'] == true) {
      return {};
    }
    var config = appdata.settings["dnsOverrides"];
    var result = <String, List<String>>{};
    if (config is Map) {
      for (var entry in config.entries) {
        if (entry.key is String && entry.value is String) {
          result[entry.key] = [entry.value];
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

    var res = await rhttp.Rhttp.request(
      method: rhttp.HttpMethod(options.method),
      url: options.uri.toString(),
      settings: await settings(options.uri),
      expectBody: rhttp.HttpExpectBody.stream,
      body: requestStream == null ? null : rhttp.HttpBody.stream(requestStream),
      headers: rhttp.HttpHeaders.rawMap(
        Map.fromEntries(
          options.headers.entries.map(
            (e) => MapEntry(e.key, e.value.toString().trim()),
          ),
        ),
      ),
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
      res.body,
      res.statusCode,
      statusMessage: _getStatusMessage(res.statusCode),
      isRedirect: false,
      headers: headers,
    );
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
      403 =>
        "Invalid Status Code 403: No permission to access the resource. Check your account or network.",
      404 => "Invalid Status Code 404: Not found.",
      429 =>
        "Invalid Status Code 429: Too many requests. Please try again later.",
      _ => "Invalid Status Code $statusCode",
    };
  }
}

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 1,
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
