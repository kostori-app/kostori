import 'dart:async';
import 'dart:io';

import 'package:kostori/foundation/webview/video_webview_controller.dart';
import 'package:kostori/foundation/webview/webview_scripts.dart';
import 'package:webview_windows/webview_windows.dart';

/// Windows 实现：webview_windows 的 HeadlessWebview（WebView2）。
///
/// 关键优势：原生 `onM3USourceLoaded` / `onVideoSourceLoaded` 事件，不依赖
/// URL 后缀，可捕获"响应体以 #EXTM3U 开头"或带 Range 头的视频请求，成功率更高。
class VideoWebviewWindowsImpl
    extends VideoWebviewController<HeadlessWebview> {
  HeadlessWebview? get _headless => webviewController;

  final List<StreamSubscription> _subscriptions = [];

  final List<HeadlessScriptID> _perCallScriptIds = [];

  bool _disposed = false;

  @override
  Future<void> init() async {
    if (_headless != null) return;

    final headless = HeadlessWebview();
    webviewController = headless;

    await headless.run();
    await headless.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await headless.setCacheDisabled(true);

    // 原生 m3u8 / video 检测（与 JS 嗅探互补）
    _subscriptions.add(headless.onM3USourceLoaded.listen((data) {
      final url = data['url'] ?? '';
      if (url.isEmpty) return;
      resultEventController.add({
        'type': WebviewResultType.hlsNative,
        'url': url,
      });
    }));
    _subscriptions.add(headless.onVideoSourceLoaded.listen((data) {
      final url = data['url'] ?? '';
      if (url.isEmpty) return;
      resultEventController.add({
        'type': WebviewResultType.video,
        'url': url,
      });
    }));
    // 页面通过 window.chrome.webview.postMessage 上报（__kostoriReport 桥）
    _subscriptions.add(headless.webMessage.listen((message) {
      if (message is Map) {
        resultEventController.add(Map<String, dynamic>.from(message));
      }
    }));
  }

  @override
  Future<void> loadUrl(
    String url, {
    Map<String, String>? headers,
    String? script,
    bool scan = true,
  }) async {
    final headless = _headless;
    if (headless == null) return;

    final ua = headers?['User-Agent'] ??
        headers?['user-agent'] ??
        (Platform.isAndroid || Platform.isIOS ? mobileUA : desktopUA);
    await headless.setUserAgent(ua);

    // 每页脚本：桥+请求头 → 视频扫描 → 自定义脚本，按序注入
    _perCallScriptIds.clear();
    Future<void> add(String source) async {
      final id = await headless.addScriptToExecuteOnDocumentCreated(source);
      if (id != null) _perCallScriptIds.add(id);
    }

    await add(buildEarlyScript(headers, bridgeSource: bridgeWebviewWindows));
    if (scan) {
      await add(videoScanScript);
    }
    if (script != null && script.isNotEmpty) {
      await add(script);
    }

    await headless.loadUrl(url);
  }

  @override
  Future<void> unloadPage() async {
    final headless = _headless;
    if (headless == null) return;
    for (final id in _perCallScriptIds) {
      try {
        await headless.removeScriptToExecuteOnDocumentCreated(id);
      } catch (_) {}
    }
    _perCallScriptIds.clear();
    try {
      await headless.loadUrl('about:blank');
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();
    await _headless?.dispose();
    webviewController = null;
    disposeEventControllers();
  }
}
