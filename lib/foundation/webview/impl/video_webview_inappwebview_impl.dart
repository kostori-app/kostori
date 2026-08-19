import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/webview/video_webview_controller.dart';
import 'package:kostori/foundation/webview/webview_scripts.dart';
import 'package:kostori/network/app_dio.dart';

/// 非 Windows 平台实现：flutter_inappwebview 的 HeadlessInAppWebView。
///
/// 复用同一个 WebView 实例（[init] 只创建一次），切换页面时仅 [unloadPage]。
class VideoWebviewInAppWebviewImpl
    extends VideoWebviewController<InAppWebViewController> {
  HeadlessInAppWebView? _headlessWebView;

  InAppWebViewController? get _controller => webviewController;

  final List<UserScript> _perCallScripts = [];

  /// 已用 Dart 层检测过的 URL，避免重复重新请求
  final Set<String> _checkedUrls = {};

  bool _disposed = false;

  @override
  Future<void> init() async {
    if (_headlessWebView != null) return;

    // 统一用桌面 UA：部分站点（如 7sefun）对移动 UA 的播放页会
    // 重定向到 App 引导页（android.php），导致无法嗅探视频地址
    final ua = desktopUA;

    _headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: ua,
        // 原生资源拦截（shouldInterceptRequest）仅 Windows 需要：
        // Windows 上 WebView2 用 WebResourceRequested 拦截 m3u8/mp4；
        // Android 上开启会导致 shouldInterceptRequest 对每个资源请求回调 +
        // Dart 层对疑似 API 重取，干扰页面加载与 JS 嗅探，故 Android 保持纯 JS 嗅探
        useShouldInterceptRequest: Platform.isWindows,
        useOnLoadResource: true,
        blockNetworkImage: true,
      ),
      // 常量脚本：桥 + 就绪探针（视频扫描脚本按 scan 参数动态注入，
      // 避免 CF 挑战页也被注入 fetch/XHR 钩子干扰）
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
      // 原生拦截：请求阶段即可看到 header，能捕获不带 .m3u8/.mp4 后缀、
      // 但带 Range 头的视频请求（借鉴 kazumi）
      shouldInterceptRequest: (controller, request) async {
        final url = request.url.toString();
        final lower = url.toLowerCase();
        if (_isAdUrl(lower)) return null;
        // 1) URL 后缀 / Range 头直接判断（快）
        if (_isM3U8Url(lower) ||
            lower.endsWith('.mp4') ||
            _isRangeVideoRequest(lower, request.headers)) {
          resultEventController.add({
            'type': WebviewResultType.hlsNative,
            'url': url,
          });
          return null;
        }
        // 2) 明显静态资源（图片/js/css/字体等）直接放行：
        //    不拦截、不检测，避免对每个资源回调日志刷屏、浪费时间
        if (_isStaticResource(lower)) return null;
        logEventController.add('拦截: $lower');
        // 3) 疑似视频 API（尤其跨域，JS 因 CORS 读不到响应体）：
        //    用 Dart 网络层重新请求，读取响应体检测 m3u8/mp4（fire-and-forget，不阻塞页面）
        if (_looksLikeVideoApi(lower, request.headers) &&
            _checkedUrls.add(url)) {
          unawaited(_detectViaDio(url, request.headers));
        }
        return null;
      },
      // 兜底：加载完成的资源 URL 含 .m3u8/.mp4，或视频元素加载的资源
      // （initiatorType: video，覆盖抖音等无后缀 fMP4 CDN 直链）
      onLoadResource: (_, resource) {
        final urlString = resource.url?.toString() ?? '';
        final lower = urlString.toLowerCase();
        if (_isAdUrl(lower)) return;
        final initiator = resource.initiatorType?.toLowerCase() ?? '';
        if (initiator == 'video' ||
            lower.contains('.m3u8') ||
            lower.contains('.mp4')) {
          resultEventController.add({
            'type': WebviewResultType.hlsNative,
            'url': urlString,
          });
        }
      },
      // 嗅探场景信任异常证书：部分播放域名（如 dp.no3acg.com）证书自签名/异常，
      // WebView 默认显示"隐私错误"拒绝加载，导致 iframe 播放器拿不到视频
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        return ServerTrustAuthResponse(
          action: ServerTrustAuthResponseAction.PROCEED,
        );
      },
      onLoadStart: (_, _) {
        debugPrint('[WebViewResolver] load start');
      },
      onTitleChanged: (_, title) {
        debugPrint('[WebViewResolver] title: $title');
      },
      onLoadStop: (_, _) {
        loadStopEventController.add(null);
      },
      onReceivedError: (_, _, _) {
        logEventController.add('webview received error');
      },
    );
    await _headlessWebView!.run();
  }

  bool _isM3U8Url(String lower) {
    final uri = Uri.tryParse(lower);
    if (uri == null) return false;
    return uri.path.endsWith('.m3u8');
  }

  bool _isRangeVideoRequest(String lower, Map<String, String>? headers) {
    if (headers == null) return false;
    final range = headers['Range'] ?? headers['range'];
    if (range == null || !range.startsWith('bytes=')) return false;
    const skip = [
      '.js', '.css', '.html', '.json', '.png', '.jpg', '.jpeg', '.gif',
      '.svg', '.woff', '.woff2', '.wasm', '.ico', '.webp',
    ];
    for (final s in skip) {
      if (lower.endsWith(s)) return false;
    }
    return true;
  }

  bool _isAdUrl(String lower) {
    return lower.contains('googleads') ||
        lower.contains('googlesyndication') ||
        lower.contains('adtrafficquality') ||
        lower.contains('doubleclick');
  }

  /// 明显静态资源：跳过拦截与检测（图片 / js / css / 字体等）
  bool _isStaticResource(String lower) {
    const skip = [
      '.js', '.css', '.png', '.jpg', '.jpeg', '.gif', '.svg',
      '.woff', '.woff2', '.wasm', '.ico', '.webp', '.html',
    ];
    for (final s in skip) {
      if (lower.endsWith(s)) return true;
    }
    return false;
  }

  /// 疑似返回视频/清单的 API 请求（用于 Dart 层重新请求检测）
  bool _looksLikeVideoApi(String lower, Map<String, String>? headers) {
    if (_isAdUrl(lower)) return false;
    // 排除明显静态资源（m3u8/mp4 已在 shouldInterceptRequest 直接上报，无需重取）
    const skip = [
      '.js', '.css', '.png', '.jpg', '.jpeg', '.gif', '.svg',
      '.woff', '.woff2', '.wasm', '.ico', '.webp', '.html', '.json',
      '.m3u8', '.mp4',
    ];
    for (final s in skip) {
      if (lower.endsWith(s)) return false;
    }
    // 视频/播放相关关键字（含常见 m3u8 接口与 maccms 播放地址）
    if (RegExp(
      '(m3u8|mpegurl|geturl|playurl|getUrl|/play/|/player/|v\\.php|'
      'tjpv|tjjs|video|media|cdn|[?&](u|url)=)',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    return false;
  }

  /// 用 Dart 网络层重新请求，读取响应体检测 m3u8/mp4（绕过页面 CORS 限制）
  ///
  /// 只取响应前 1MB（Range），既能覆盖 m3u8 清单（纯文本）与 JSON 里的直链，
  /// 又避免把整个 mp4 下载下来。
  Future<void> _detectViaDio(String url, Map<String, String>? headers) async {
    try {
      final res = await AppDio().get<String>(
        url,
        options: Options(
          method: 'GET',
          responseType: ResponseType.plain,
          headers: {
            ...?headers,
            'Range': 'bytes=0-1048575',
          },
          validateStatus: (s) => s != null && s < 400,
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final body = res.data;
      if (body == null || body.isEmpty) return;
      // 响应体本身是 m3u8 清单
      if (body.trimLeft().startsWith('#EXTM3U')) {
        _reportVideo(url);
        return;
      }
      // 从响应体提取 m3u8 / mp4 地址
      final m3u8 = RegExp(
        'https?://[^\\s"\'<>\\\\]+?\\.m3u8[^\\s"\'<>\\\\]*',
        caseSensitive: false,
      ).firstMatch(body);
      if (m3u8 != null) {
        _reportVideo(m3u8.group(0)!);
        return;
      }
      final mp4 = RegExp(
        'https?://[^\\s"\'<>\\\\]+?\\.mp4[^\\s"\'<>\\\\]*',
        caseSensitive: false,
      ).firstMatch(body);
      if (mp4 != null) {
        _reportVideo(mp4.group(0)!);
      }
    } catch (e) {
      SourceLog.error('WebViewResolver', 'Dart 层视频检测失败：$e');
    }
  }

  void _reportVideo(String url) {
    resultEventController.add({'type': WebviewResultType.video, 'url': url});
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

    // 每页脚本：内置视频扫描（scan 时）+ 自定义脚本，均在 document start 注入
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
    // 不逐个 removeUserScript：flutter_inappwebview 的 Android 实现
    // removeUserOnlyScriptAt 用索引移除，多次嗅探后索引不匹配会抛
    // IndexOutOfBoundsException（虽然不崩溃，但刷日志且可能残留）。
    // 脚本重复注入由 videoScan 的去重逻辑与 WebViewResolver.seen 兜底。
    _perCallScripts.clear();
    try {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
    } catch (_) {}
  }

  @override
  Future<String?> evaluateJavascript(String source) async {
    final controller = _controller;
    if (controller == null) return null;
    try {
      final result = await controller.evaluateJavascript(source: source);
      return result?.toString();
    } catch (_) {
      return null;
    }
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
