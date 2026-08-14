import 'dart:async';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/main_isolate_runner.dart';
import 'package:kostori/foundation/webview/video_webview_controller.dart';
import 'package:kostori/foundation/webview/webview_scripts.dart';

/// 通过 WebView 加载页面并提取数据（视频嗅探统一入口）。
///
/// 内部按平台选择 [VideoWebviewController] 实现：
/// - Windows → webview_windows（原生 m3u8/video 检测）
/// - 其它平台 → flutter_inappwebview（HeadlessInAppWebView）
///
/// WebView 实例复用（单例），切换页面仅卸载，不重复创建。
class WebViewResolver {
  WebViewResolver._();

  static VideoWebviewController? _controller;

  static Future<VideoWebviewController> _getController() async {
    if (_controller == null) {
      _controller = VideoWebviewControllerFactory.getController();
      await _controller!.init();
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
  }

  static Future<List<dynamic>> _resolve(
    String url, {
    Map<String, String>? headers,
    String? script,
    required int waitMs,
    required bool scan,
  }) async {
    final controller = await _getController();

    final results = <dynamic>[];
    final seen = <String>{};
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
        // Cloudflare 挑战：延长等待，给挑战页自动重载留时间
        arm(waitMs + 15000);
        return;
      }
      final urlValue = item['url']?.toString() ?? '';
      final key = '$type:$urlValue';
      if (seen.contains(key)) return;
      seen.add(key);
      results.add(item);
      if (type == WebviewResultType.video ||
          type == WebviewResultType.hlsNative) {
        if (!completer.isCompleted) completer.complete(results);
      }
    }

    final sub = controller.onResult.listen(onItem);

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
      return cleanWebviewResults(finalResults);
    } finally {
      timer?.cancel();
      await sub.cancel();
      // 卸载页面（保留引擎实例供下次复用）
      try {
        await controller.unloadPage();
      } catch (_) {}
    }
  }
}
