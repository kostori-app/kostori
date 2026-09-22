import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:kostori/foundation/image_loader/inline_image.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/main_isolate_runner.dart';
import 'package:kostori/foundation/pending_requests.dart';

class JSPool {
  /// 后台 worker 数：`loadInlineImage` 回源与 `compute` 共用，按最闲调度。
  ///
  /// 回源是 IO 密集（等网络）+ 偶发 CPU（解密），6 并发不会压住设备；
  /// 图片多时排队也在后台，主线程无感。
  static final int _maxInstances = 6;
  final List<IsolateJsEngine> _instances = [];
  bool _isInitializing = false;

  static final JSPool _singleton = JSPool._internal();

  factory JSPool() {
    return _singleton;
  }

  JSPool._internal();

  Future<void> init() async {
    if (_isInitializing) return;
    _isInitializing = true;
    var jsInitBuffer = await rootBundle.load("assets/init.js");
    var jsInit = jsInitBuffer.buffer.asUint8List();
    // 主 isolate 的任务通道端口，随 isolate 一起传入后台
    final mainPort = MainIsolateRunner.mainSendPort;
    for (int i = 0; i < _maxInstances; i++) {
      _instances.add(IsolateJsEngine(jsInit, mainPort));
    }
    _isInitializing = false;
  }

  Future<dynamic> execute(String jsFunction, List<dynamic> args) async {
    await init();
    var selectedInstance = _instances[0];
    for (var instance in _instances) {
      if (instance.pendingTasks < selectedInstance.pendingTasks) {
        selectedInstance = instance;
      }
    }
    return selectedInstance.execute(jsFunction, args);
  }

  /// 后台执行源的 `loadInlineImage(token)`：JS 解密/base64 编解码全在 worker
  /// isolate，主线程只等一份字节结果。
  ///
  /// 成功返回图片字节；源函数返回空/非图片时返回 null（调用方显示占位）；
  /// worker 异常时抛错，调用方回退主线程执行以保证兼容。
  Future<Uint8List?> executeInlineImage({
    required String sourceKey,
    required String sourceJs,
    required String token,
  }) async {
    await init();
    var selectedInstance = _instances[0];
    for (var instance in _instances) {
      if (instance.pendingTasks < selectedInstance.pendingTasks) {
        selectedInstance = instance;
      }
    }
    return selectedInstance.executeInlineImage(
      sourceKey: sourceKey,
      sourceJs: sourceJs,
      token: token,
    );
  }
}

class _IsolateJsEngineInitParam {
  final SendPort sendPort;

  final Uint8List jsInit;

  final SendPort? mainSendPort;

  _IsolateJsEngineInitParam(this.sendPort, this.jsInit, this.mainSendPort);
}

class IsolateJsEngine {
  Isolate? _isolate;

  SendPort? _sendPort;
  ReceivePort? _receivePort;

  /// worker 就绪信号（首个 SendPort 到达即完成），发任务前只等它。
  final Completer<void> _ready = Completer<void>();

  int get pendingTasks => _tasks.length + _inlineTasks.length;

  /// 通用 compute 任务表与 inline 回源任务表：配对逻辑收敛到
  /// [PendingRequests]（超时自删、关闭一键结算，此前手写版本漏清出过 bug）。
  final _tasks = PendingRequests<dynamic>();
  final _inlineTasks = PendingRequests<Uint8List?>();

  bool _isClosed = false;

  IsolateJsEngine(Uint8List jsInit, SendPort? mainSendPort) {
    _receivePort = ReceivePort();
    _receivePort!.listen(_onMessage);
    // 保存 isolate 句柄，close() 才能真正杀掉（此前返回值被丢弃，kill 是空操作）。
    // 若 spawn 完成时已 close，直接杀掉，避免孤儿 isolate 常驻。
    Isolate.spawn(
      _run,
      _IsolateJsEngineInitParam(_receivePort!.sendPort, jsInit, mainSendPort),
    ).then((isolate) {
      if (_isClosed) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    });
  }

  void _onMessage(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
      if (!_ready.isCompleted) _ready.complete();
    } else if (message is TaskResult) {
      if (message.error != null) {
        _tasks.completeError(message.id, message.error!);
      } else {
        _tasks.complete(message.id, message.result);
      }
    } else if (message is InlineImageResult) {
      if (message.error != null) {
        _inlineTasks.completeError(message.id, Exception(message.error));
      } else {
        _inlineTasks.complete(message.id, message.result);
      }
    } else if (message is Exception) {
      SourceLog.error("IsolateJsEngine", message.toString());
      // 两类在途任务都要结算，否则调用方永久挂起且 close() 死等
      _tasks.settleAllError(message);
      _inlineTasks.settleAllError(message);
      close();
    }
  }

  static void _run(_IsolateJsEngineInitParam params) async {
    // 绑定主 isolate 通道端口，供 WebView 等平台操作切回主线程
    MainIsolateRunner.bindMainPort(params.mainSendPort);
    var sendPort = params.sendPort;
    final port = ReceivePort();
    sendPort.send(port.sendPort);
    final engine = JsEngine();
    try {
      JsEngine.cacheJsInit(params.jsInit);
      await engine.init();
    } catch (e, s) {
      sendPort.send(Exception("Failed to initialize JS engine: $e\n$s"));
      return;
    }
    // 本 worker 已加载的源文本版本（key → 版本戳），见 [_runInlineImage]。
    final inlineSources = <String, String>{};
    await for (final message in port) {
      if (message is Task) {
        try {
          final jsFunc = engine.runCode(message.jsFunction);
          if (jsFunc is! JSInvokable) {
            throw Exception(
              "The provided code does not evaluate to a function.",
            );
          }
          final result = jsFunc.invoke(message.args);
          jsFunc.free();
          sendPort.send(TaskResult(message.id, result, null));
        } catch (e) {
          sendPort.send(TaskResult(message.id, null, e.toString()));
        }
      } else if (message is InlineImageTask) {
        try {
          final bytes = await _runInlineImage(engine, inlineSources, message);
          sendPort.send(InlineImageResult(message.id, bytes, null));
        } catch (e) {
          sendPort.send(InlineImageResult(message.id, null, e.toString()));
        }
      }
    }
  }

  /// worker 内已加载源：key → 已加载文本的版本戳（长度 + hashCode）。
  ///
  /// 源升级后主线程会传来新文本，版本变化时重新求值，保证与主线程一致。
  static final _inlineSourceKeyExp = RegExp(r'^[a-zA-Z0-9_]+$');

  static Future<Uint8List?> _runInlineImage(
    JsEngine engine,
    Map<String, String> loaded,
    InlineImageTask task,
  ) async {
    final key = task.sourceKey;
    if (!_inlineSourceKeyExp.hasMatch(key)) {
      throw Exception('invalid source key: $key');
    }
    final hash = '${task.sourceJs.length}:${task.sourceJs.hashCode}';
    if (loaded[key] != hash) {
      final className = _extractSourceClassName(task.sourceJs);
      if (className == null || className.isEmpty) {
        throw Exception('invalid source: no AnimeSource subclass');
      }
      engine.runCode(
        'AnimeSource.sources.$key = '
            '(() => { ${task.sourceJs} return new $className(); })()',
        'inline:$key',
      );
      loaded[key] = hash;
    }
    if (engine.runCode(
          '(() => { try { return typeof AnimeSource.sources.$key.anime'
          '.loadInlineImage === "function"; } catch (e) { return false; } })()',
        ) !=
        true) {
      throw Exception('loadInlineImage not found: $key');
    }
    // 与主线程原路径语义一致：方法调用（this 为 anime 实例），await Promise。
    // 同步段与桥接拷贝全在本 isolate，主线程只等结果。
    final dynamic res = await engine.runCode(
      'AnimeSource.sources.$key.anime'
          '.loadInlineImage(${jsonEncode(task.token)})',
      'inline:$key',
    );
    return _normalizeInlineResult(res);
  }

  /// 源文本首行 `class X extends AnimeSource` 提取类名（与 parser 一致）。
  static String? _extractSourceClassName(String js) {
    for (final line in js.replaceAll('\r\n', '\n').split('\n')) {
      final t = line.trim();
      if (t.startsWith('class ') && t.contains('extends AnimeSource')) {
        return t.split('class')[1].split('extends AnimeSource').first.trim();
      }
    }
    return null;
  }

  /// worker 内归一化：base64/字节数组 → 字节；空/未知 → null。
  ///
  /// 已在后台线程，同步解码即可（主线程的 decodeAsync/isloate 搬运在此无意义）。
  static Uint8List? _normalizeInlineResult(dynamic res) {
    if (res == null) return null;
    if (res is String) {
      if (res.isEmpty) return null;
      return InlineImageStore.decode(res);
    }
    if (res is Uint8List) return res;
    if (res is List || res is Map) return jsBytesOf(res);
    return null;
  }

  Future<dynamic> execute(String jsFunction, List<dynamic> args) async {
    if (_isClosed) {
      throw Exception("IsolateJsEngine is closed.");
    }
    await _ready.future;
    final rec = _tasks.register();
    _sendPort?.send(Task(rec.id, jsFunction, args));
    return rec.future;
  }

  /// 见 [JSPool.executeInlineImage]。
  ///
  /// 超时（45s）由 [PendingRequests.registerWithTimeout] 处理：先删表项再抛，
  /// worker 晚回的结果因找不到表项被直接丢弃。
  Future<Uint8List?> executeInlineImage({
    required String sourceKey,
    required String sourceJs,
    required String token,
  }) async {
    if (_isClosed) {
      throw Exception("IsolateJsEngine is closed.");
    }
    await _ready.future;
    final rec = _inlineTasks.registerWithTimeout(
      const Duration(seconds: 45),
      () => TimeoutException(
        'inline image worker timed out',
        const Duration(seconds: 45),
      ),
    );
    _sendPort?.send(InlineImageTask(rec.id, sourceKey, sourceJs, token));
    return rec.future;
  }

  void close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    // 最多等 5s 让在途任务收尾，超时则强制结算，避免调用方永久挂起
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while ((_tasks.isNotEmpty || _inlineTasks.isNotEmpty) &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (_tasks.isNotEmpty || _inlineTasks.isNotEmpty) {
      final err = StateError('IsolateJsEngine closed with pending tasks');
      _tasks.settleAllError(err);
      _inlineTasks.settleAllError(err);
    }
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

class Task {
  final int id;
  final String jsFunction;
  final List<dynamic> args;

  const Task(this.id, this.jsFunction, this.args);
}

class TaskResult {
  final int id;
  final Object? result;
  final String? error;

  const TaskResult(this.id, this.result, this.error);
}

/// 后台回源任务：只传纯数据（SendPort 安全），源文本由 worker 按需求值缓存。
class InlineImageTask {
  final int id;
  final String sourceKey;
  final String sourceJs;
  final String token;

  const InlineImageTask(this.id, this.sourceKey, this.sourceJs, this.token);
}

/// 后台回源结果：`result` 为图片字节（`Uint8List` 可跨 isolate 传递）或 null；
/// `error` 非空表示 worker 失败，调用方回退主线程。
class InlineImageResult {
  final int id;
  final Uint8List? result;
  final String? error;

  const InlineImageResult(this.id, this.result, this.error);
}
