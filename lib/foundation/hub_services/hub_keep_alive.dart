import 'dart:io';

import 'package:flutter/services.dart';

/// Hub 连接保活：Android 连接 Hub 服务器时启动前台服务通知，
/// 防止应用退到后台被系统回收导致连接断开。
class HubKeepAlive {
  HubKeepAlive._();

  static const _channel = MethodChannel("kostori/method_channel");

  static bool _active = false;

  /// 是否已在运行
  static bool get isActive => _active;

  /// 启动前台保活（仅 Android；幂等）
  static Future<void> start() async {
    if (!Platform.isAndroid || _active) return;
    _active = true;
    try {
      await _channel.invokeMethod('startHubKeepAlive');
    } catch (_) {
      _active = false;
    }
  }

  /// 停止前台保活（仅 Android；幂等）
  static Future<void> stop() async {
    if (!Platform.isAndroid || !_active) return;
    _active = false;
    try {
      await _channel.invokeMethod('stopHubKeepAlive');
    } catch (_) {}
  }
}
