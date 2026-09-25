import 'dart:async';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
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
  /// 请求上带 `extra['noCloudflare'] == true` 时跳过本拦截器（调用方自行判断）。
  static const noCloudflareExtra = 'noCloudflare';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[noCloudflareExtra] == true) {
      handler.next(options);
      return;
    }
    if (options.headers['cookie'].toString().contains('cf_clearance')) {
      options.headers['user-agent'] = appdata.implicitData['ua'] ?? webUA;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.requestOptions.extra[noCloudflareExtra] == true) {
      handler.next(err);
      return;
    }
    final res = err.response;
    if (res != null && _isChallenge(res)) {
      // 判定为挑战就直接换成 CloudflareException，交给上层弹「验证」按钮；
      // 若此处再回落到普通 err，用户只会看到 403，反复重试仍被拦截
      handler.next(CloudflareException(res.requestOptions.uri.toString()));
    } else {
      handler.next(err);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.extra[noCloudflareExtra] == true) {
      handler.next(response);
      return;
    }
    if (_isChallenge(response)) {
      handler.reject(
        CloudflareException(response.requestOptions.uri.toString()),
      );
      return;
    }
    handler.next(response);
  }

  /// Cloudflare「硬拦截」页（Error 1020 / Attention Required!）无法通过人工
  /// 验证解决，不能当作可验证的挑战，否则只会弹一个永远过不去的验证页。
  static bool looksLikeBlocked(String? body) {
    if (body == null) return false;
    return body.contains('Sorry, you have been blocked') ||
        body.contains('You are unable to access') ||
        body.contains('Attention Required!') ||
        body.contains('Error 1020') ||
        body.contains('error code: 1020');
  }

  /// 挑战页正文强特征：CF interstitial 专用脚本/表单。
  /// 正常页面（含挂 Turnstile 挂件的登录页）不含，故可安全用于识别
  /// 「状态码为 200 的挑战页」。
  static bool _hasChallengeMarkers(String body) =>
      body.contains('window._cf_chl_opt') || body.contains('cf-chl-widget');

  /// 判断响应是否可能是 CF 挑战页，任一条件成立即可：
  /// - `cf-mitigated: challenge` 头（最可靠）
  /// - 状态码 403/429/503 且 `server: cloudflare`（很多挑战页不带 cf-mitigated）
  /// - 正文带挑战页强特征（部分 managed challenge 返回 200，状态码不可靠）
  /// 明显的硬拦截页（Error 1020）优先判为非挑战。
  static bool looksLikeChallenge(
    int? statusCode,
    Headers headers, {
    String? body,
  }) {
    if (headers['cf-mitigated']?.firstOrNull == 'challenge') return true;
    if (looksLikeBlocked(body)) return false;
    // 有正文时只认挑战页强特征：避免把普通 403 / 错误 HTML 误判为挑战
    if (body != null) return _hasChallengeMarkers(body);
    final server = headers['server']?.firstOrNull?.toLowerCase();
    final serverCf = server == 'cloudflare' || server == 'cloudflare-nginx';
    return serverCf &&
        (statusCode == 403 || statusCode == 429 || statusCode == 503);
  }

  /// 从响应判定挑战：正文只在「较小且为 HTML」时扫描，
  /// 非 HTML 响应（JSON / 视频等）直接排除，避免误判。
  bool _isChallenge(Response response) {
    final headers = response.headers;
    final cfMitigated = headers['cf-mitigated']?.firstOrNull == 'challenge';
    final contentType = headers.value('content-type')?.toLowerCase() ?? '';
    final data = response.data;
    String? body;
    if (data is String &&
        data.length <= 64 * 1024 &&
        contentType.contains('html')) {
      body = data;
    }
    if (!cfMitigated &&
        contentType.isNotEmpty &&
        !contentType.contains('html')) {
      return false;
    }
    return looksLikeChallenge(response.statusCode, headers, body: body);
  }
}

void passCloudflare(CloudflareException e, void Function() onFinished) async {
  final uri = Uri.parse(e.url);
  // cf_clearance 是「域级」的：直接打开具体 API/媒体地址往往只是内容
  // （不会出现挑战、也拿不到 clearance）。导航到站点根，触发并完成该域
  // 的 CF 挑战后再把 cookie（含 cf_clearance）整份保存下来。
  final rootUri = Uri(scheme: uri.scheme, host: uri.host);
  var url = rootUri.toString();

  // 保证 onFinished 只回调一次（Linux 分支 close 与 onClose 可能重复触发）
  var finished = false;
  void finishOnce() {
    if (finished) return;
    finished = true;
    onFinished();
  }

  // 不清空已有的 cf_clearance / 该域 cookie：很多站点正是靠既有会话和
  // clearance 才能过；清掉反而可能拿不回来，导致“验证页里能播、播放器
  // 却因为没有 cf_clearance 播不了”。

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

        // 不再要求必须有 cf_clearance：非 CF 内容页也要保存会话 cookie
        await _trySaveCookies(controller, url, uri);
        controller.close();
        // onClose 会回调 onFinished，这里不重复调用
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
      await _trySaveCookies(webview, url, uri);
      finishOnce();
      return;
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
        final hasClearance = await _trySaveCookies(controller, url, uri);
        // 仍处于挑战态才继续等；否则（挑战已过，或页面本就是内容/视频）
        // 保存会话 cookie 后直接结束
        if (await _isChallenging(controller, url)) {
          NetLog.info(
            "Cloudflare",
            hasClearance
                ? "cf_clearance present but still challenging, waiting..."
                : "cf_clearance not ready",
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
        // 自动检测偶发不退出（已过 CF 但 cookie/标题判断没跟上），
        // 右上角手动确认强制提取一次并关闭
        confirmLabel: t.confirm,
        onConfirm: (controller) async {
          if (finished) return true;
          final hasClearance = await _trySaveCookies(controller, url, uri);
          if (!hasClearance && await _isChallenging(controller, url)) {
            NetLog.info(
              "Cloudflare",
              "manual confirm: still challenging, no cf_clearance",
            );
            return false;
          }
          final ua = await controller.getUA();
          if (ua != null) {
            appdata.implicitData['ua'] = ua;
            appdata.writeImplicitData();
          }
          NetLog.info("Cloudflare", "manual confirm: cookies saved");
          stopPoller();
          finishOnce();
          return true;
        },
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

/// 执行可能触发 Cloudflare 挑战的异步操作：命中挑战时弹出验证页，
/// 通过后自动重试（默认一次）。供下载等非播放器流程复用。
Future<T> runWithCloudflare<T>(
  Future<T> Function() action, {
  int retries = 1,
}) async {
  var left = retries;
  while (true) {
    try {
      return await action();
    } catch (e) {
      final cfe = e is CloudflareException
          ? e
          : CloudflareException.fromString(e.toString());
      if (cfe == null || left <= 0) rethrow;
      left--;
      final done = Completer<void>();
      passCloudflare(cfe, () {
        if (!done.isCompleted) done.complete();
      });
      await done.future;
    }
  }
}

Future<bool> _isChallenging(dynamic controller, String url) async {
  Future<String> eval(String js) async {
    if (App.isLinux) {
      return await (controller as DesktopWebview).evaluateJavascript(js) ?? '';
    }
    return await (controller as InAppWebViewController).evaluateJavascript(
          source: js,
        ) as String? ??
        '';
  }

  String head;
  String body;
  String contentType;
  try {
    head = await eval("document.head ? document.head.innerHTML : ''");
    body = await eval("document.body ? document.body.innerHTML : ''");
    contentType = (await eval("document.contentType || ''")).toLowerCase();
  } catch (e) {
    NetLog.info("Cloudflare", "evaluateJavascript error: $e");
    return true;
  }

  // 直接跳转成媒体/非 HTML 文档（如视频直链本身就是内容）→ 不是挑战页
  if (contentType.isNotEmpty && !contentType.contains('html')) {
    return false;
  }

  // 检测安全警告页面（SmartScreen / 举报页面）
  if (head.contains('interstitial') ||
      body.contains('reported-unsafe') ||
      body.contains('ERR_BLOCKED')) {
    NetLog.info(
      "Cloudflare",
      "Security block page detected, treating as challenging",
    );
    return true;
  }

  // 空正文不算挑战（媒体文档/极简页），避免一直干等 cf_clearance
  if (body.isEmpty) return false;

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

    // 不管有没有 cf_clearance 都保存：非 CF 页面（如直接是内容）的会话
    // cookie 同样需要，否则验证页能播、播放器却缺少会话播不了。
    if (cookiesMap.isNotEmpty) {
      _saveCookies(uri, cookiesMap);
    }
    if (cookiesMap.containsKey('cf_clearance')) {
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
