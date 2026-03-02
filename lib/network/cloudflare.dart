import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/pages/webview.dart';

class CloudflareException implements DioException {
  final String url;

  CloudflareException(this.url);

  @override
  String toString() {
    return "CloudflareException: $url";
  }

  static CloudflareException? fromString(String message) {
    var match = RegExp(r"CloudflareException: (.+)").firstMatch(message);
    if (match == null) return null;
    return CloudflareException(match.group(1)!);
  }

  @override
  DioException copyWith({
    RequestOptions? requestOptions,
    Response<dynamic>? response,
    DioExceptionType? type,
    Object? error,
    StackTrace? stackTrace,
    String? message,
  }) {
    return this;
  }

  @override
  Object? get error => this;

  @override
  String? get message => toString();

  @override
  RequestOptions get requestOptions => RequestOptions();

  @override
  Response? get response => null;

  @override
  StackTrace get stackTrace => StackTrace.empty;

  @override
  DioExceptionType get type => DioExceptionType.badResponse;

  @override
  DioExceptionReadableStringBuilder? stringBuilder;
}

class CloudflareInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.headers['cookie'].toString().contains('cf_clearance')) {
      options.headers['user-agent'] = appdata.implicitData['ua'] ?? webUA;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 403) {
      handler.next(_check(err.response!) ?? err);
    } else {
      handler.next(err);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.statusCode == 403) {
      var err = _check(response);
      if (err != null) {
        handler.reject(err);
        return;
      }
    }
    handler.next(response);
  }

  CloudflareException? _check(Response response) {
    if (response.headers['cf-mitigated']?.firstOrNull == "challenge") {
      return CloudflareException(response.requestOptions.uri.toString());
    }
    return null;
  }
}

void passCloudflare(CloudflareException e, void Function() onFinished) async {
  var url = e.url;
  var uri = Uri.parse(url);

  SingleInstanceCookieJar.instance?.deleteCookieByName('cf_clearance');
  Log.info("Cloudflare", "Cleared old cf_clearance");

  if (!App.isLinux) {
    try {
      final cookieManager = CookieManager.instance(
        webViewEnvironment: AppWebview.webViewEnvironment,
      );
      await cookieManager.deleteCookies(
        url: WebUri(
          Uri(scheme: uri.scheme, host: uri.host, path: '/').toString(),
        ),
      );
      Log.addLog(
        LogLevel.info,
        "Cloudflare",
        "Cleared old cf_clearance from WebView",
      );
    } catch (e) {
      Log.addLog(
        LogLevel.warning,
        "Cloudflare",
        "Failed to clear WebView cf_clearance: $e",
      );
    }
  }

  if (App.isLinux) {
    var webview = DesktopWebview(
      initialUrl: url,
      onTitleChange: (title, controller) async {
        if (await _isChallenging(controller, url)) {
          Log.addLog(LogLevel.info, "Cloudflare", "Still challenging...");
          return;
        }

        Log.addLog(
          LogLevel.info,
          "Cloudflare",
          "Challenge passed, extracting cookies...",
        );

        final ua = controller.userAgent;
        if (ua != null) {
          appdata.implicitData['ua'] = ua;
          appdata.writeImplicitData();
        }

        final success = await _trySaveCookies(controller, url, uri);
        if (success) {
          controller.close();
          onFinished();
        }
      },
      onClose: onFinished,
    );
    webview.open();
  } else {
    bool finished = false;
    bool isChecking = false;

    Future<void> check(InAppWebViewController controller) async {
      if (finished || isChecking) return;
      isChecking = true;

      try {
        final currentUrl = (await controller.getUrl())?.toString() ?? '';

        if (currentUrl.contains("/cdn-cgi/")) {
          Log.addLog(LogLevel.info, "Cloudflare", "Still redirecting...");
          return;
        }

        final success = await _trySaveCookies(controller, url, uri);

        if (!success) {
          Log.addLog(LogLevel.info, "Cloudflare", "cf_clearance not ready");
          return;
        }
        Log.addLog(LogLevel.info, "Cloudflare", "Challenge passed");
        final ua = await controller.getUA();
        if (ua != null) {
          appdata.implicitData['ua'] = ua;
          appdata.writeImplicitData();
        }
        finished = true;
        await Future.delayed(const Duration(seconds: 2));

        App.rootPop();
        onFinished();
      } finally {
        isChecking = false;
      }
    }

    await App.rootContext.to(
      () => AppWebview(
        initialUrl: url,
        singlePage: true,
        onStarted: (controller) async {
          final ua = await controller.getUA();
          if (ua != null) {
            appdata.implicitData['ua'] = ua;
            appdata.writeImplicitData();
          }
        },
        onTitleChange: (title, controller) async {
          await check(controller);
        },
        onLoadStop: (controller) async {
          await check(controller);
        },
      ),
    );

    if (!finished) onFinished();
  }
}

Future<bool> _isChallenging(dynamic controller, String url) async {
  String head = '';
  String body = '';

  try {
    if (App.isLinux) {
      head =
          await (controller as DesktopWebview).evaluateJavascript(
            "document.head ? document.head.innerHTML : ''",
          ) ??
          '';
      body =
          await (controller).evaluateJavascript(
            "document.body ? document.body.innerHTML : ''",
          ) ??
          '';
    } else {
      head =
          await (controller as InAppWebViewController).evaluateJavascript(
                source: "document.head ? document.head.innerHTML : ''",
              )
              as String? ??
          '';
      body =
          await (controller).evaluateJavascript(
                source: "document.body ? document.body.innerHTML : ''",
              )
              as String? ??
          '';
    }
  } catch (e) {
    Log.addLog(LogLevel.info, "Cloudflare", "evaluateJavascript error: $e");
    return true;
  }

  // 检测安全警告页面（SmartScreen / 举报页面）
  var isSecurityBlock =
      head.contains('interstitial') ||
      body.contains('reported-unsafe') ||
      body.contains('ERR_BLOCKED') ||
      body.isEmpty; // 页面内容为空也视为未就绪

  if (isSecurityBlock) {
    Log.addLog(
      LogLevel.info,
      "Cloudflare",
      "Security block page detected, treating as challenging",
    );
    return true;
  }

  return head.contains('#challenge-success-text') ||
      head.contains('#challenge-error-text') ||
      head.contains('#challenge-form') ||
      body.contains('challenge-platform') ||
      body.contains('window._cf_chl_opt');
}

Future<bool> _trySaveCookies(dynamic controller, String url, Uri uri) async {
  for (int i = 0; i < 3; i++) {
    if (i > 0) await Future.delayed(const Duration(milliseconds: 500));

    Map<String, String> cookiesMap = {};
    try {
      if (App.isLinux) {
        cookiesMap = await (controller as DesktopWebview).getCookies(url);
      } else {
        final cookies =
            await (controller as InAppWebViewController).getCookies(url) ?? [];
        cookiesMap = {for (var c in cookies) c.name: c.value.toString()};
      }
    } catch (e) {
      Log.addLog(LogLevel.info, "Cloudflare", "getCookies error: $e");
      continue;
    }

    Log.addLog(LogLevel.info, "Cloudflare", "Attempt $i cookies: $cookiesMap");

    if (cookiesMap.containsKey('cf_clearance')) {
      _saveCookies(uri, cookiesMap);
      Log.addLog(
        LogLevel.info,
        "Cloudflare",
        "cf_clearance saved successfully!",
      );
      return true;
    }
  }

  Log.addLog(
    LogLevel.warning,
    "Cloudflare",
    "Failed to get cf_clearance after 3 attempts",
  );
  return false;
}

void _saveCookies(Uri uri, Map<String, String> cookies) {
  var host = uri.host;
  var splits = host.split('.');
  String domain = splits.length >= 3
      ? ".${splits.sublist(splits.length - 2).join('.')}"
      : ".$host";

  Log.addLog(
    LogLevel.info,
    "Cloudflare",
    "Saving cookies with domain: $domain",
  );

  final rootUri = Uri(scheme: uri.scheme, host: uri.host, path: '/');

  SingleInstanceCookieJar.instance!.delete(
    Uri.parse("https://$host/"),
    'cf_clearance',
  );

  SingleInstanceCookieJar.instance!.saveFromResponse(
    rootUri,
    List<io.Cookie>.generate(cookies.length, (index) {
      var cookie = io.Cookie(
        cookies.keys.elementAt(index),
        cookies.values.elementAt(index),
      );
      cookie.domain = domain;
      cookie.path = '/';
      return cookie;
    }),
  );
}
