import 'package:flutter/services.dart';
import 'package:kostori/foundation/log.dart';

/// 通过系统外部播放器打开本地视频文件。
///
/// Android 用 Intent ACTION_VIEW + FileProvider content URI + mimeType
/// 分派给默认播放器；Windows 用 ShellExecuteEx 打开本地文件（走系统默认
/// 关联）。比 url_launcher 的 file:// 更可靠。
class ExternalPlayer {
  ExternalPlayer._();

  static const _platform = MethodChannel('kostori/method_channel');

  /// 用系统默认播放器打开本地视频文件。
  static Future<bool> openLocalVideo(String path) async {
    if (path.isEmpty) return false;
    try {
      final ok = await _platform.invokeMethod<bool>(
        'openWithMime',
        <String, String>{'url': path, 'mimeType': 'video/*'},
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      NetLog.error('ExternalPlayer', 'openWithMime failed: $e');
      return false;
    }
  }
}
