import 'dart:async';
import 'dart:isolate';

class MainIsolateTask {
  final int id;
  final String name;
  final Object? payload;
  final SendPort replyPort;

  const MainIsolateTask(this.id, this.name, this.payload, this.replyPort);
}

class MainIsolateResult {
  final int id;
  final Object? result;
  final String? error;

  const MainIsolateResult(this.id, this.result, this.error);
}

typedef MainIsolateHandler = Future<Object?> Function(Object? payload);

/// 主 isolate 任务通道。
///
/// 源脚本在 JSPool 的后台 isolate 中执行（Isolate.spawn），而 Windows 的
/// WebView2 必须在已初始化 COM 的主线程创建。通过本通道把这类平台相关的操作
/// 发回主 isolate 执行，避免 "尚未调用 CoInitialize"。
///
/// 主 isolate 在启动时 [register]，并把 [mainSendPort] 交给 JSPool 传入各后台
/// isolate（后台 isolate 在初始化时 [bindMainPort]）。
class MainIsolateRunner {
  MainIsolateRunner._();

  static bool _registered = false;
  static SendPort? _mainSendPort;
  static final Map<String, MainIsolateHandler> _handlers = {};
  static int _taskId = 0;

  /// 仅主 isolate 上的实例为 true（由 [register] 标记）
  static bool get isMainIsolate => _registered;

  /// 主 isolate 通道的 SendPort（供 JSPool 传给后台 isolate）
  static SendPort? get mainSendPort => _mainSendPort;

  /// 主 isolate 启动时调用一次
  static void register() {
    if (_registered) return;
    _registered = true;
    final port = ReceivePort();
    port.listen(_handleTask);
    _mainSendPort = port.sendPort;
  }

  /// 后台 isolate 初始化时绑定主通道端口
  static void bindMainPort(SendPort? port) {
    _mainSendPort = port;
  }

  /// 注册可在主 isolate 执行的任务处理器
  static void registerHandler(String name, MainIsolateHandler handler) {
    _handlers[name] = handler;
  }

  static void _handleTask(dynamic message) {
    if (message is! MainIsolateTask) return;
    final task = message;
    Future.sync(() => _execute(task.name, task.payload))
        .then((result) {
          task.replyPort.send(MainIsolateResult(task.id, result, null));
        })
        .catchError((Object e, StackTrace s) {
          task.replyPort.send(MainIsolateResult(task.id, null, '$e\n$s'));
        });
  }

  static Future<Object?> _execute(String name, Object? payload) async {
    final handler = _handlers[name];
    if (handler == null) {
      throw StateError('No main isolate handler registered for "$name"');
    }
    return handler(payload);
  }

  /// 从后台 isolate 发起请求：在主 isolate 上执行 [name] 并返回结果
  static Future<Object?> run(String name, Object? payload) async {
    final port = _mainSendPort;
    if (port == null) {
      throw StateError('MainIsolateRunner port not bound');
    }
    final reply = ReceivePort();
    final id = _taskId++;
    final completer = Completer<Object?>();
    reply.listen((message) {
      if (message is MainIsolateResult && message.id == id) {
        reply.close();
        if (message.error != null) {
          completer.completeError(Exception(message.error));
        } else {
          completer.complete(message.result);
        }
      }
    });
    port.send(MainIsolateTask(id, name, payload, reply.sendPort));
    return completer.future;
  }
}
