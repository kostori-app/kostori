import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/download/download_keep_alive.dart';

typedef _Call = ({
  String method,
  List<DownloadKeepAliveTask> tasks,
  int remaining,
});

class _Service {
  final calls = <_Call>[];
  int permissionRequests = 0;
  Completer<void>? permissionStarted;
  Completer<void>? permissionResult;
  Completer<void>? startStarted;
  Completer<void>? startResult;

  late final coordinator = DownloadKeepAliveCoordinator(
    requestPermission: () async {
      permissionRequests++;
      permissionStarted?.complete();
      await permissionResult?.future;
    },
    startService: (tasks, remaining) async {
      calls.add((method: 'start', tasks: tasks, remaining: remaining));
      startStarted?.complete();
      await startResult?.future;
    },
    updateService: (tasks, remaining) async {
      calls.add((method: 'update', tasks: tasks, remaining: remaining));
    },
    stopService: () async {
      calls.add((method: 'stop', tasks: [], remaining: 0));
    },
  );
}

void _expectCall(
  _Call call, {
  required String method,
  required List<DownloadKeepAliveTask> tasks,
  required int remaining,
}) {
  expect(call.method, method);
  expect(call.remaining, remaining);
  expect(call.tasks, hasLength(tasks.length));
  for (var i = 0; i < tasks.length; i++) {
    expect(call.tasks[i].title, tasks[i].title);
    expect(call.tasks[i].progress, tasks[i].progress);
  }
}

void main() {
  const torrent = (title: 'Torrent', progress: 0.25);
  const http = (title: 'HTTP video', progress: 0.5);

  test('停止 HTTP 来源不会移除仍在传输的种子通知', () async {
    final service = _Service();
    final keepAlive = service.coordinator;

    await keepAlive.attach('torrent', [torrent], remaining: 1);
    await keepAlive.attach('http', [http], remaining: 3);
    _expectCall(
      service.calls.last,
      method: 'update',
      tasks: [torrent, http],
      remaining: 4,
    );

    await keepAlive.detach('http');
    expect(keepAlive.isActive, isTrue);
    _expectCall(
      service.calls.last,
      method: 'update',
      tasks: [torrent],
      remaining: 1,
    );
    expect(service.calls.where((call) => call.method == 'stop'), isEmpty);

    await keepAlive.detach('torrent');
    expect(keepAlive.isActive, isFalse);
    expect(service.calls.last.method, 'stop');
  });

  test('相同任务快照与空闲来源不会重复发布通知', () async {
    final service = _Service();
    final keepAlive = service.coordinator;

    await keepAlive.attach('torrent', [torrent], remaining: 1);
    for (var i = 0; i < 3; i++) {
      await keepAlive.update('torrent', [torrent], remaining: 1);
      await keepAlive.detach('http');
    }
    expect(service.calls, hasLength(1));
    _expectCall(
      service.calls.single,
      method: 'start',
      tasks: [torrent],
      remaining: 1,
    );

    await keepAlive.update('torrent', [torrent], remaining: 2);
    _expectCall(
      service.calls.last,
      method: 'update',
      tasks: [torrent],
      remaining: 2,
    );
    expect(service.calls, hasLength(2));
  });

  test('权限弹窗期间取消任务不会启动过期的通知', () async {
    final service = _Service()
      ..permissionStarted = Completer<void>()
      ..permissionResult = Completer<void>();
    final keepAlive = service.coordinator;

    final attaching = keepAlive.attach('torrent', [torrent], remaining: 1);
    await service.permissionStarted!.future;
    final detaching = keepAlive.detach('torrent');
    service.permissionResult!.complete();
    await Future.wait([attaching, detaching]);

    expect(service.permissionRequests, 1);
    expect(service.calls, isEmpty);
    expect(keepAlive.isActive, isFalse);
  });

  test('权限弹窗结束只使用最新来源和进度，不重复启动服务', () async {
    final service = _Service()
      ..permissionStarted = Completer<void>()
      ..permissionResult = Completer<void>();
    final keepAlive = service.coordinator;

    final oldAttach = keepAlive.attach('torrent', [torrent], remaining: 1);
    await service.permissionStarted!.future;
    final oldDetach = keepAlive.detach('torrent');
    final newAttach = keepAlive.attach('http', [http], remaining: 2);
    const latest = (title: 'HTTP video', progress: 0.75);
    final update = keepAlive.update('http', [latest], remaining: 3);
    service.permissionResult!.complete();
    await Future.wait([oldAttach, oldDetach, newAttach, update]);

    expect(service.permissionRequests, 1);
    expect(service.calls, hasLength(1));
    _expectCall(
      service.calls.single,
      method: 'start',
      tasks: [latest],
      remaining: 3,
    );
  });

  test('平台启动尚未返回时来源切换只更新快照，不停止后重启', () async {
    final service = _Service()
      ..startStarted = Completer<void>()
      ..startResult = Completer<void>();
    final keepAlive = service.coordinator;

    final oldAttach = keepAlive.attach('torrent', [torrent], remaining: 1);
    await service.startStarted!.future;
    final oldDetach = keepAlive.detach('torrent');
    final newAttach = keepAlive.attach('http', [http], remaining: 2);
    service.startResult!.complete();
    await Future.wait([oldAttach, oldDetach, newAttach]);

    expect(service.calls, hasLength(2));
    _expectCall(
      service.calls[0],
      method: 'start',
      tasks: [torrent],
      remaining: 1,
    );
    _expectCall(
      service.calls[1],
      method: 'update',
      tasks: [http],
      remaining: 2,
    );
  });
}
