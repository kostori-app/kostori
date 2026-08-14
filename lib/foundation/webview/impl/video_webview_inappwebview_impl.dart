import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kostori/foundation/webview/video_webview_controller.dart';
import 'package:kostori/foundation/webview/webview_scripts.dart';

/// 非 Windows 平台实现：flutter_inappwebview 的 HeadlessInAppWebView。
///
/// 复用同一个 WebView 实例（[init] 只创建一次），切换页面时仅 [unloadPage]。
class VideoWebviewInAppWebviewImpl
    extends VideoWebviewController<InAppWebViewController> {
  HeadlessInAppWebView? _headlessWebView;

  InAppWebViewController? get _controller => webviewController;

  final List<UserScript> _perCallScripts = [];

  bool _disposed = false;

  @override
  Future<void> init() async {
    if (_headlessWebView != null) return;

    final ua = (Platform.isAndroid || Platform.isIOS) ? mobileUA : desktopUA;

    _headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        blockNetworkImage: true,
        userAgent: ua,
        useOnLoadResource: true,
      ),
      // 常量脚本：桥 + 就绪探针（视频扫描脚本按 scan 参数在 loadUrl 时动态注入）
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: bridgeInAppWebview,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
        UserScript(
          source: debugProbeScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
          forMainFrameOnly: false,
        ),
      ]),
      onWebViewCreated: (controller) {
        webviewController = controller;
        controller.addJavaScriptHandler(
          handlerName: '__kostoriReport',
          callback: (args) {
            if (args.isEmpty) return null;
            final item = args[0];
            if (item is Map) {
              resultEventController.add(Map<String, dynamic>.from(item));
            }
            return null;
          },
        );
      },
      onLoadResource: (_, resource) {
        final urlString = resource.url?.toString() ?? '';
        if (urlString.contains('.m3u8') || urlString.contains('.mp4')) {
          resultEventController.add({
            'type': WebviewResultType.hlsNative,
            'url': urlString,
          });
        }
      },
      onReceivedError: (_, _, _) {
        logEventController.add('webview received error');
      },
    );
    await _headlessWebView!.run();
  }

  @override
  Future<void> loadUrl(
    String url, {
    Map<String, String>? headers,
    String? script,
    bool scan = true,
  }) async {
    final controller = _controller;
    if (controller == null) return;

    // 每页脚本：内置视频扫描 + 自定义脚本，均在 document start 注入
    _perCallScripts.clear();
    if (scan) {
      _perCallScripts.add(
        UserScript(
          source: videoScanScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      );
    }
    if (script != null && script.isNotEmpty) {
      _perCallScripts.add(
        UserScript(
          source: script,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      );
    }
    for (final s in _perCallScripts) {
      await controller.addUserScript(userScript: s);
    }

    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(url), headers: headers),
    );
  }

  @override
  Future<void> unloadPage() async {
    final controller = _controller;
    if (controller == null) return;
    for (final s in _perCallScripts) {
      try {
        await controller.removeUserScript(userScript: s);
      } catch (_) {}
    }
    _perCallScripts.clear();
    try {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final controller = _controller;
    // dispose 前解除 JS 上报，避免迟到的 __kostoriReport 在已释放的 WebView 上触发崩溃
    try {
      await controller?.evaluateJavascript(source: _disarmJs);
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _headlessWebView?.dispose();
    _headlessWebView = null;
    webviewController = null;
    disposeEventControllers();
  }

  static const String _disarmJs = r'''
(function(){
  window.__kostoriStop && window.__kostoriStop();
  try {
    document.querySelectorAll('iframe').forEach(function(f){
      try { f.contentWindow.__kostoriStop && f.contentWindow.__kostoriStop(); } catch(e){}
    });
  } catch(e){}
})();
''';
}
