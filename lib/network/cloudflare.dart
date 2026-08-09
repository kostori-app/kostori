import 'dart:async';
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
    if (err.response != null &&
        _looksLikeChallenge(err.response!.statusCode, err.response!.headers)) {
      handler.next(_check(err.response!) ?? err);
    } else {
      handler.next(err);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_looksLikeChallenge(response.statusCode, response.headers)) {
      var err = _check(response);
      if (err != null) {
        handler.reject(err);
        return;
      }
    }
    handler.next(response);
  }

  /// 判断响应是否可能是 CF 挑战页：
  /// - `cf-mitigated: challenge` 头（403/429/503 常见）
  /// - `server: cloudflare` 且状态码为 403/503（很多挑战页不带 cf-mitigated 头）
  bool _looksLikeChallenge(int? statusCode, Headers headers) {
    if (statusCode != 403 && statusCode != 503 && statusCode != 429) {
      return false;
    }
    final mitigated = headers['cf-mitigated']?.firstOrNull;
    if (mitigated == 'challenge') return true;
    final server = headers['server']?.firstOrNull?.toLowerCase();
    return server == 'cloudflare' || server == 'cloudflare-nginx';
  }

  CloudflareException? _check(Response response) {
    final mitigated = response.headers['cf-mitigated']?.firstOrNull;
    if (mitigated == "challenge") {
      return CloudflareException(response.requestOptions.uri.toString());
    }
    // 无 cf-mitigated 头时，尝试从响应体识别 challenge 特征
    if (response.data is String) {
      final body = response.data as String;
      if (body.contains('challenge-platform') ||
          body.contains('window._cf_chl_opt') ||
          body.contains('cf-chl-widget')) {
        return CloudflareException(response.requestOptions.uri.toString());
      }
    }
    return null;
  }
}

void passCloudflare(CloudflareException e, void Function() onFinished) async {
  var url = e.url;
  var uri = Uri.parse(url);

  // 保证 onFinished 只回调一次（Linux 分支 close 与 onClose 可能重复触发）
  var finished = false;
  void finishOnce() {
    if (finished) return;
    finished = true;
    onFinished();
  }

  SingleInstanceCookieJar.instance?.deleteCookieByName('cf_clearance');
  NetLog.info("Cloudflare", "Cleared old cf_clearance");

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
      NetLog.info("Cloudflare", "Cleared old cf_clearance from WebView");
    } catch (e) {
      NetLog.warning("Cloudflare", "Failed to clear WebView cf_clearance: $e");
    }
  }

  if (App.isLinux) {
    var webview = DesktopWebview(
      initialUrl: url,
      onTitleChange: (title, controller) async {
        if (await _isChallenging(controller, url)) {
          NetLog.info("Cloudflare", "Still challenging...");
          return;
        }

        NetLog.info("Cloudflare", "Challenge passed, extracting cookies...");

        final ua = controller.userAgent;
        if (ua != null) {
          appdata.implicitData['ua'] = ua;
          appdata.writeImplicitData();
        }

        final success = await _trySaveCookies(controller, url, uri);
        if (success) {
          controller.close();
          // onClose 会回调 onFinished，这里不重复调用
        }
      },
      onClose: finishOnce,
    );
    webview.open();
    // 兜底超时：轮询检查是否仍处于挑战态，若已通过则提取 cookie；
    // 仅当确实结束（通过/超时）才 finish，避免 challenge 未通过就退出
    var waited = 0;
    Timer.periodic(const Duration(seconds: 20), (_) async {
      if (finished) return;
      waited += 20;
      if (await _isChallenging(webview, url)) {
        NetLog.info(
          "Cloudflare",
          "Still challenging after ${waited}s, keep waiting",
        );
        return;
      }
      final success = await _trySaveCookies(webview, url, uri);
      if (success) {
        finishOnce();
        return;
      }
      if (waited >= 180) {
        NetLog.warning("Cloudflare", "Challenge not resolved after 3 minutes");
        finishOnce();
      }
    });
  } else {
    bool isChecking = false;
    Timer? poller;
    InAppWebViewController? lastController;

    void stopPoller() {
      poller?.cancel();
      poller = null;
    }

    /// 检查 cf_clearance：拿到且页面已离开挑战态才算通过
    Future<void> check(InAppWebViewController controller) async {
      if (finished || isChecking) return;
      isChecking = true;
      try {
        final success = await _trySaveCookies(controller, url, uri);
        if (!success) {
          NetLog.info("Cloudflare", "cf_clearance not ready");
          return;
        }
        // 即使拿到了 cookie，若页面仍处于挑战态则继续等待，
        // 避免旧 cookie 导致"还没通过就退出"
        if (await _isChallenging(controller, url)) {
          NetLog.info(
            "Cloudflare",
            "cf_clearance present but still challenging, waiting...",
          );
          return;
        }
        NetLog.info("Cloudflare", "Challenge passed");
        final ua = await controller.getUA();
        if (ua != null) {
          appdata.implicitData['ua'] = ua;
          appdata.writeImplicitData();
        }
        await Future.delayed(const Duration(seconds: 1));
        if (!finished) {
          App.rootPop();
          stopPoller();
          finishOnce();
        }
      } catch (e) {
        NetLog.warning("Cloudflare", "check error: $e");
      } finally {
        isChecking = false;
      }
    }

    await App.rootContext.to(
      () => AppWebview(
        initialUrl: url,
        singlePage: true,
        onStarted: (controller) async {
          lastController = controller;
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
          // challenge 可能通过 JS 完成而不触发新的导航事件，
          // 故启动轮询兜底检测 cf_clearance
          poller ??= Timer.periodic(const Duration(milliseconds: 700), (_) {
            final c = lastController;
            if (c != null) check(c);
          });
        },
      ),
    );

    // 路由被弹出（成功通过 或 用户手动关闭）后结束，绝不在 challenge
    // 通过前自动退出
    stopPoller();
    if (!finished) finishOnce();
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
    NetLog.info("Cloudflare", "evaluateJavascript error: $e");
    return true;
  }

  // 检测安全警告页面（SmartScreen / 举报页面）
  var isSecurityBlock =
      head.contains('interstitial') ||
      body.contains('reported-unsafe') ||
      body.contains('ERR_BLOCKED') ||
      body.isEmpty;

  if (isSecurityBlock) {
    NetLog.info(
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
        // Linux 版可能只返回匹配当前 url 的 cookie；兜底尝试根域
        if (!cookiesMap.containsKey('cf_clearance')) {
          cookiesMap.addAll(await controller.getAllCookies());
        }
      } else {
        final cookies =
            await (controller as InAppWebViewController).getCookies(url) ?? [];
        cookiesMap = {for (var c in cookies) c.name: c.value.toString()};
      }
    } catch (e) {
      NetLog.info("Cloudflare", "getCookies error: $e");
      continue;
    }

    NetLog.info("Cloudflare", "Attempt $i cookies: $cookiesMap");

    if (cookiesMap.containsKey('cf_clearance')) {
      _saveCookies(uri, cookiesMap);
      NetLog.info("Cloudflare", "cf_clearance saved successfully!");
      return true;
    }
  }

  NetLog.warning("Cloudflare", "Failed to get cf_clearance after 3 attempts");
  return false;
}

void _saveCookies(Uri uri, Map<String, String> cookies) {
  var host = uri.host;
  var splits = host.split('.');
  String domain = splits.length >= 3
      ? ".${splits.sublist(splits.length - 2).join('.')}"
      : ".$host";

  NetLog.info("Cloudflare", "Saving cookies with domain: $domain");

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
