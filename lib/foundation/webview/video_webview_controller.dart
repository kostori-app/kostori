import 'dart:async';

import 'package:kostori/foundation/webview/impl/video_webview_inappwebview_impl.dart';

/// 单次嗅探请求的上报结果（与源脚本契约一致，见 [WebviewResultType]）。
typedef WebviewResult = Map<String, dynamic>;

/// 视频源嗅探控制器抽象。
///
/// 统一各平台 WebView 引擎的「加载 → 注入脚本 → 上报结果」流程，
/// 上层通过 [onResult] 订阅网页上报的数据，与底层引擎解耦。
abstract class VideoWebviewController<T> {
  /// 平台各自的 WebView 控制器实例。
  T? webviewController;

  /// 结果上报事件流。
  final StreamController<WebviewResult> resultEventController =
      StreamController<WebviewResult>.broadcast();

  Stream<WebviewResult> get onResult => resultEventController.stream;

  /// 页面加载完成事件（每次导航/重载完成触发，供上层重置等待定时器）。
  final StreamController<void> loadStopEventController =
      StreamController<void>.broadcast();

  Stream<void> get onLoadStop => loadStopEventController.stream;

  /// 日志事件流（供排查）。
  final StreamController<String> logEventController =
      StreamController<String>.broadcast();

  Stream<String> get onLog => logEventController.stream;

  /// 初始化底层 WebView 引擎（幂等）。
  Future<void> init();

  /// 加载 [url] 并开始嗅探。
  ///
  /// [headers] 附加请求头；[script] 自定义注入脚本（源脚本提供）；
  /// [scan] 是否启用内置视频扫描 JS 钩子（Cloudflare 挑战页建议 false）。
  Future<void> loadUrl(
    String url, {
    Map<String, String>? headers,
    String? script,
    bool scan = true,
  });

  /// 卸载当前页面（切到空白页释放页面资源，但不销毁引擎）。
  Future<void> unloadPage();

  /// 在主框架执行 JavaScript 并返回结果字符串
  /// （用于抓取页面内容 / 读取渲染后的 HTML，见 [WebViewResolver.fetchHtml]）。
  Future<String?> evaluateJavascript(String source);

  /// 销毁 WebView 与事件流。
  Future<void> dispose();

  /// 关闭事件流控制器（幂等）。
  void disposeEventControllers() {
    if (!resultEventController.isClosed) {
      resultEventController.close();
    }
    if (!loadStopEventController.isClosed) {
      loadStopEventController.close();
    }
    if (!logEventController.isClosed) {
      logEventController.close();
    }
  }
}

/// 按平台选择实现。
class VideoWebviewControllerFactory {
  static VideoWebviewController getController() {
    // 统一用 flutter_inappwebview：其 Windows 原生层对 * 注册了
    // WebResourceRequested（CONTEXT_ALL），能拦截到跨域 iframe（QQ 播放器等）
    // 里的 m3u8/mp4 资源请求——这是 desktop_webview_window 可见窗口做不到的
    // （它只有导航事件，无资源拦截；JS 又受 CORS 限制读不到跨域 iframe 内容）。
    return VideoWebviewInAppWebviewImpl();
  }

  /// 创建并初始化。
  static Future<VideoWebviewController> createInitialized() async {
    final c = VideoWebviewInAppWebviewImpl();
    await c.init();
    return c;
  }
}
