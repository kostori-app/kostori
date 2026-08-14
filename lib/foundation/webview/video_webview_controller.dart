import 'dart:async';
import 'dart:io';

import 'package:kostori/foundation/webview/impl/video_webview_inappwebview_impl.dart';
import 'package:kostori/foundation/webview/impl/video_webview_windows_impl.dart';

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

  /// 销毁 WebView 与事件流。
  Future<void> dispose();

  /// 关闭事件流控制器（幂等）。
  void disposeEventControllers() {
    if (!resultEventController.isClosed) {
      resultEventController.close();
    }
    if (!logEventController.isClosed) {
      logEventController.close();
    }
  }
}

/// 按平台选择实现。
class VideoWebviewControllerFactory {
  static VideoWebviewController getController() {
    if (Platform.isWindows) {
      return VideoWebviewWindowsImpl();
    }
    return VideoWebviewInAppWebviewImpl();
  }
}
