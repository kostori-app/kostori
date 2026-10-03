import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// 后台传输保活前台服务（Android）：有任务在下载 / 做种时启动前台服务通知，
/// 防止应用退到后台被系统回收导致传输中断。
///
/// **按来源分别登记**（普通下载、BT 种子各自一组），只有所有来源都空闲时才停服务。
/// 早期版本只有一个全局开关，BT 做种会被普通下载的 `stop()` 误关，
/// 结果是种子在后台被系统杀掉。
class DownloadKeepAlive {
  DownloadKeepAlive._();

  static const _channel = MethodChannel("kostori/method_channel");

  /// 来源标识
  static const String ownerHttp = 'http';
  static const String ownerTorrent = 'torrent';

  static final Map<String, List<({String title, double progress})>> _byOwner =
      {};
  static final Map<String, int> _remainingByOwner = {};

  static bool _serviceOn = false;

  /// 是否有任何来源在传输
  static bool get isActive => _byOwner.isNotEmpty;

  /// 登记某来源的传输任务；传空列表表示该来源已空闲。
  static Future<void> attach(
    String owner,
    List<({String title, double progress})> tasks, {
    required int remaining,
  }) async {
    if (!Platform.isAndroid) return;
    if (tasks.isEmpty) return detach(owner);
    if (_byOwner.isEmpty) await _startService();
    if (!_serviceOn) return;
    _byOwner[owner] = tasks;
    _remainingByOwner[owner] = remaining;
    await _push();
  }

  /// 注销某来源；全部来源都注销后才停服务。
  static Future<void> detach(String owner) async {
    if (!Platform.isAndroid) return;
    final had = _byOwner.remove(owner) != null;
    _remainingByOwner.remove(owner);
    if (!had) return;
    if (_byOwner.isEmpty) {
      await _stopService();
      return;
    }
    await _push();
  }

  /// 更新某来源的任务快照（不改变登记状态）。
  static Future<void> update(
    String owner,
    List<({String title, double progress})> tasks, {
    required int remaining,
  }) async {
    if (!Platform.isAndroid || !_serviceOn) return;
    if (tasks.isEmpty) return detach(owner);
    _byOwner[owner] = tasks;
    _remainingByOwner[owner] = remaining;
    await _push();
  }

  /// 兼容旧调用：无来源概念的整表替换（保留给既有调用点，逐步迁移到 attach）
  static Future<void> updateLegacy({
    required List<({String title, double progress})> tasks,
    required int remaining,
  }) => update(ownerHttp, tasks, remaining: remaining);

  static Future<void> _push() async {
    final tasks = <({String title, double progress})>[];
    for (final list in _byOwner.values) {
      tasks.addAll(list);
    }
    final remaining = _remainingByOwner.values.fold<int>(0, (a, b) => a + b);
    try {
      await _channel.invokeMethod('updateDownloadForeground', {
        'tasks': tasks
            .map((t) => {'title': t.title, 'progress': t.progress})
            .toList(),
        'remaining': remaining,
      });
    } catch (_) {}
  }

  static Future<void> _startService() async {
    if (_serviceOn) return;
    // Android 13+ 通知需要运行时权限，否则前台服务通知不显示
    try {
      await Permission.notification.request();
    } catch (_) {}
    try {
      await _channel.invokeMethod('startDownloadForeground');
      _serviceOn = true;
    } catch (_) {}
  }

  static Future<void> _stopService() async {
    if (!_serviceOn) return;
    _serviceOn = false;
    try {
      await _channel.invokeMethod('stopDownloadForeground');
    } catch (_) {}
  }
}
