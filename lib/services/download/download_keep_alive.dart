import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

typedef DownloadKeepAliveTask = ({String title, double progress});
typedef DownloadKeepAliveSnapshotCallback = Future<void> Function(
  List<DownloadKeepAliveTask> tasks,
  int remaining,
);

/// 串行合并多个来源的前台服务更新。
///
/// 单独抽出后可以在非 Android 测试环境覆盖「权限请求期间任务被取消」
/// 和「一个来源停止不应关闭另一个来源」这两个竞态。
class DownloadKeepAliveCoordinator {
  DownloadKeepAliveCoordinator({
    required this.startService,
    required this.updateService,
    required this.stopService,
    required this.requestPermission,
  });

  final DownloadKeepAliveSnapshotCallback startService;
  final DownloadKeepAliveSnapshotCallback updateService;
  final Future<void> Function() stopService;
  final Future<void> Function() requestPermission;

  final Map<String, List<DownloadKeepAliveTask>> _byOwner = {};
  final Map<String, int> _remainingByOwner = {};

  Future<void> _operation = Future<void>.value();
  bool _syncQueued = false;
  bool _serviceOn = false;
  int _revision = 0;
  List<DownloadKeepAliveTask>? _lastTasks;
  int? _lastRemaining;

  bool get isActive => _byOwner.isNotEmpty;

  Future<void> attach(
    String owner,
    List<DownloadKeepAliveTask> tasks, {
    required int remaining,
  }) {
    _setOwner(owner, tasks, remaining);
    return _scheduleSync();
  }

  Future<void> detach(String owner) {
    _byOwner.remove(owner);
    _remainingByOwner.remove(owner);
    _revision++;
    return _scheduleSync();
  }

  Future<void> update(
    String owner,
    List<DownloadKeepAliveTask> tasks, {
    required int remaining,
  }) => attach(owner, tasks, remaining: remaining);

  void _setOwner(
    String owner,
    List<DownloadKeepAliveTask> tasks,
    int remaining,
  ) {
    if (tasks.isEmpty) {
      _byOwner.remove(owner);
      _remainingByOwner.remove(owner);
    } else {
      _byOwner[owner] = List<DownloadKeepAliveTask>.of(tasks);
      _remainingByOwner[owner] = remaining;
    }
    _revision++;
  }

  List<DownloadKeepAliveTask> get _allTasks => [
    for (final list in _byOwner.values) ...list,
  ];

  int get _allRemaining =>
      _remainingByOwner.values.fold<int>(0, (a, b) => a + b);

  Future<void> _start() async {
    if (_serviceOn) return;
    try {
      await requestPermission();
    } catch (_) {}
    // 权限弹窗可能比任务活得更久，等待结束后重新取快照，
    // 避免已取消的任务重新启动通知。
    if (_byOwner.isEmpty) return;
    final tasks = _allTasks;
    final remaining = _allRemaining;
    try {
      await startService(tasks, remaining);
      _serviceOn = true;
      _lastTasks = tasks;
      _lastRemaining = remaining;
    } catch (_) {}
  }

  Future<void> _push() async {
    final tasks = _allTasks;
    final remaining = _allRemaining;
    if (remaining == _lastRemaining && listEquals(tasks, _lastTasks)) return;
    try {
      await updateService(tasks, remaining);
      _lastTasks = tasks;
      _lastRemaining = remaining;
    } catch (_) {}
  }

  Future<void> _stop() async {
    if (!_serviceOn) return;
    try {
      await stopService();
      _serviceOn = false;
      _lastTasks = null;
      _lastRemaining = null;
    } catch (_) {}
  }

  Future<void> _syncOnce() async {
    if (_byOwner.isEmpty) {
      await _stop();
    } else if (!_serviceOn) {
      await _start();
    } else {
      await _push();
    }
  }

  /// 合并更新，并在异步平台调用期间再次检查是否有新快照。
  Future<void> _scheduleSync() {
    if (_syncQueued) return _operation;
    _syncQueued = true;
    final next = _operation.then((_) async {
      try {
        while (true) {
          final revision = _revision;
          await _syncOnce();
          if (revision == _revision) return;
        }
      } finally {
        _syncQueued = false;
      }
    });
    _operation = next.catchError((_) {
      _syncQueued = false;
    });
    return next;
  }
}

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

  static final DownloadKeepAliveCoordinator _coordinator =
      DownloadKeepAliveCoordinator(
        requestPermission: () async {
          // Android 13+ 通知需要运行时权限，否则前台服务通知不显示。
          try {
            await Permission.notification.request();
          } catch (_) {}
        },
        startService: (tasks, remaining) =>
            _channel.invokeMethod('startDownloadForeground', {
              'tasks': tasks
                  .map((t) => {'title': t.title, 'progress': t.progress})
                  .toList(),
              'remaining': remaining,
            }),
        updateService: (tasks, remaining) =>
            _channel.invokeMethod('updateDownloadForeground', {
              'tasks': tasks
                  .map((t) => {'title': t.title, 'progress': t.progress})
                  .toList(),
              'remaining': remaining,
            }),
        stopService: () => _channel.invokeMethod('stopDownloadForeground'),
      );

  /// 是否有任何来源在传输
  static bool get isActive => _coordinator.isActive;

  /// 登记某来源的传输任务；传空列表表示该来源已空闲。
  static Future<void> attach(
    String owner,
    List<({String title, double progress})> tasks, {
    required int remaining,
  }) {
    if (!Platform.isAndroid) return Future<void>.value();
    return _coordinator.attach(owner, tasks, remaining: remaining);
  }

  /// 注销某来源；全部来源都注销后才停服务。
  static Future<void> detach(String owner) {
    if (!Platform.isAndroid) return Future<void>.value();
    return _coordinator.detach(owner);
  }

  /// 更新某来源的任务快照；空列表注销该来源。
  static Future<void> update(
    String owner,
    List<({String title, double progress})> tasks, {
    required int remaining,
  }) {
    if (!Platform.isAndroid) return Future<void>.value();
    return _coordinator.update(owner, tasks, remaining: remaining);
  }

  /// 兼容旧调用：无来源概念的整表替换（保留给既有调用点，逐步迁移到 attach）
  static Future<void> updateLegacy({
    required List<({String title, double progress})> tasks,
    required int remaining,
  }) => update(ownerHttp, tasks, remaining: remaining);
}
