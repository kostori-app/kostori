import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// 下载保活前台服务（Android）：存在下载任务时启动前台服务通知，
/// 防止应用退到后台被系统回收导致下载中断。
class DownloadKeepAlive {
  DownloadKeepAlive._();

  static const _channel = MethodChannel("kostori/method_channel");

  static bool _active = false;

  static bool get isActive => _active;

  static Future<void> start() async {
    if (!Platform.isAndroid || _active) return;
    // Android 13+ 通知需要运行时权限，否则前台服务通知不显示
    if (Platform.isAndroid) {
      try {
        await Permission.notification.request();
      } catch (_) {}
    }
    _active = true;
    try {
      await _channel.invokeMethod('startDownloadForeground');
    } catch (_) {
      _active = false;
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid || !_active) return;
    _active = false;
    try {
      await _channel.invokeMethod('stopDownloadForeground');
    } catch (_) {}
  }

  static Future<void> update({
    required List<({String title, double progress})> tasks,
  }) async {
    if (!Platform.isAndroid || !_active) return;
    try {
      await _channel.invokeMethod('updateDownloadForeground', {
        'tasks': tasks
            .map((t) => {'title': t.title, 'progress': t.progress})
            .toList(),
      });
    } catch (_) {}
  }
}
