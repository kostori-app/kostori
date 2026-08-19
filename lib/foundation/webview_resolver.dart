import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/main_isolate_runner.dart';
import 'package:kostori/foundation/webview/video_webview_controller.dart';
import 'package:kostori/foundation/webview/webview_scripts.dart';

/// 通过 WebView 加载页面并提取数据（视频嗅探统一入口）。
///
/// 内部按平台选择 [VideoWebviewController] 实现：
/// - 所有平台 → flutter_inappwebview（HeadlessInAppWebView + 原生资源拦截）
///
/// WebView 实例复用（单例），切换页面仅卸载，不重复创建。
class WebViewResolver {
  WebViewResolver._();

  static VideoWebviewController? _controller;

  static Future<VideoWebviewController> _getController() async {
    if (_controller == null) {
      try {
        Log.info('WebViewResolver', '初始化 webview...');
        _controller = await VideoWebviewControllerFactory.createInitialized();
        Log.info('WebViewResolver', 'webview 初始化成功');
      } catch (e, s) {
        // 初始化失败：置空，避免下次复用坏实例（否则会报 "not running"）
        _controller = null;
        Log.error('WebViewResolver', 'webview 初始化失败：$e\n$s');
        rethrow;
      }
    }
    return _controller!;
  }

  /// 提取入口：加载 [url] 并等待脚本/原生上报，返回结果列表。
  /// [scan] 为 false 时不注入视频扫描 JS 钩子（fetch/XHR/Response.text），
  /// 仅保留桥与原生检测，避免干扰 Cloudflare 挑战页。
  /// 注意：Windows 的 WebView2 必须在主线程创建，本方法在后台 isolate
  /// 被调用时会通过 [MainIsolateRunner] 切回主 isolate 执行。
  static Future<List<dynamic>> fetchViaWebView(
    String url, {
    Map<String, String>? headers,
    String? script,
    int waitMs = 8000,
    bool scan = true,
  }) async {
    Log.info('WebViewResolver', 'fetchVideoUrl 被调用: $url scan=$scan');
    if (!MainIsolateRunner.isMainIsolate) {
      final result = await MainIsolateRunner.run('webview', {
        'url': url,
        'headers': headers,
        'script': script,
        'waitMs': waitMs,
        'scan': scan,
      });
      return (result as List?)?.cast<dynamic>() ?? [];
    }
    try {
      return await _resolve(
        url,
        headers: headers,
        script: script,
        waitMs: waitMs,
        scan: scan,
      );
    } catch (e, s) {
      SourceLog.error('WebViewResolver', '$e\n$s');
    }
    return [];
  }

  /// 主 isolate 上注册 webview 任务处理器（应用启动时调用）
  static void registerMainIsolateHandler() {
    MainIsolateRunner.registerHandler('webview', (payload) async {
      final args = payload as Map;
      return fetchViaWebView(
        args['url'] as String,
        headers: (args['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
        script: args['script'] as String?,
        waitMs: args['waitMs'] as int? ?? 8000,
        scan: args['scan'] as bool? ?? true,
      );
    });
    MainIsolateRunner.registerHandler('webviewHtml', (payload) async {
      final args = payload as Map;
      return fetchHtml(
        args['url'] as String,
        headers: (args['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
        waitMs: args['waitMs'] as int? ?? 8000,
      );
    });
  }

  /// 用 WebView 渲染 [url] 并返回渲染后的页面 HTML。
  ///
  /// 供普通 HTTP 客户端被拦截（Cloudflare 522 等）的站点抓取内容使用：
  /// 由 WebView 真实渲染页面后读取 `document.documentElement.outerHTML`。
  /// 失败返回 null。页面在 finally 中卸载，避免 WebView 实例残留/内存泄漏。
  static Future<String?> fetchHtml(
    String url, {
    Map<String, String>? headers,
    int waitMs = 8000,
  }) async {
    Log.info('WebViewResolver', 'fetchHtml: $url');
    if (!MainIsolateRunner.isMainIsolate) {
      final result = await MainIsolateRunner.run('webviewHtml', {
        'url': url,
        'headers': headers,
        'waitMs': waitMs,
      });
      return result?.toString();
    }
    try {
      return await _resolveHtml(url, headers: headers, waitMs: waitMs);
    } catch (e, s) {
      SourceLog.error('WebViewResolver', '$e\n$s');
    }
    return null;
  }

  static Future<String?> _resolveHtml(
    String url, {
    Map<String, String>? headers,
    required int waitMs,
  }) async {
    debugPrint('[WebViewResolver] fetchHtml 开始: $url');
    final controller = await _getController();
    final completer = Completer<void>();
    Timer? timer;

    void finish() {
      if (!completer.isCompleted) completer.complete(null);
    }

    final loadStopSub = controller.onLoadStop.listen((_) {
      // 首次加载完成后稍等页面内 JS 渲染，再读取 HTML
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 600), finish);
    });

    try {
      await controller.loadUrl(url, headers: headers, scan: false);
      timer ??= Timer(Duration(milliseconds: waitMs), finish);
      await completer.future.timeout(
        Duration(milliseconds: waitMs + 3000),
        onTimeout: finish,
      );
      final html = await controller.evaluateJavascript(
        'document.documentElement.outerHTML',
      );
      return (html == null || html.isEmpty) ? null : html;
    } finally {
      timer?.cancel();
      await loadStopSub.cancel();
      // 卸载页面（保留引擎实例供下次复用）
      try {
        await controller.unloadPage();
      } catch (_) {}
    }
  }

  static Future<List<dynamic>> _resolve(
    String url, {
    Map<String, String>? headers,
    String? script,
    required int waitMs,
    required bool scan,
  }) async {
    debugPrint('[WebViewResolver] 开始嗅探: $url');
    Log.info('WebViewResolver', '嗅探: $url');
    final controller = await _getController();
    final results = <dynamic>[];
    final seen = <String>{};
    var sawCf = false;
    final completer = Completer<List<dynamic>>();
    Timer? timer;

    void arm([int? ms]) {
      timer?.cancel();
      timer = Timer(Duration(milliseconds: ms ?? waitMs), () {
        if (!completer.isCompleted) completer.complete(results);
      });
    }

    void onItem(Map<String, dynamic> item) {
      final type = item['type'];
      if (type == WebviewResultType.cf) {
        sawCf = true;
        // Cloudflare 挑战：延长等待，给挑战页自动重载留时间
        arm(waitMs + 15000);
        return;
      }
      final urlValue = item['url']?.toString() ?? '';
      final key = '$type:$urlValue';
      if (seen.contains(key)) return;
      seen.add(key);
      results.add(item);
      debugPrint('[WebViewResolver] 上报 $type: $urlValue');
      if (type == WebviewResultType.video ||
          type == WebviewResultType.hlsNative) {
        if (!completer.isCompleted) completer.complete(results);
      }
    }

    final sub = controller.onResult.listen(onItem);
    final logSub = controller.onLog.listen((msg) {
      debugPrint('[WebViewResolver] $msg');
    });
    final loadStopSub = controller.onLoadStop.listen((_) {
      // 每次导航/重载完成都重置等待计时，避免慢页面/重定向提前返回空；
      // 若已识别 CF 挑战则保持延长
      arm(sawCf ? waitMs + 15000 : waitMs);
    });

    try {
      await controller.loadUrl(
        url,
        headers: headers,
        script: script,
        scan: scan,
      );
      arm();

      final finalResults = await completer.future.timeout(
        Duration(milliseconds: waitMs + 15000),
        onTimeout: () => results,
      );
      debugPrint('[WebViewResolver] 嗅探结束，结果: $finalResults');
      Log.info('WebViewResolver', '嗅探结束: $finalResults');
      return cleanWebviewResults(finalResults);
    } finally {
      timer?.cancel();
      await sub.cancel();
      await logSub.cancel();
      await loadStopSub.cancel();
      // 卸载页面（保留引擎实例供下次复用）
      try {
        await controller.unloadPage();
      } catch (_) {}
    }
  }
}
