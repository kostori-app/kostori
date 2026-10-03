import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// 下载数据块落盘抽象：屏蔽「后台 isolate 写」与「直写」两种实现，
/// 下载主流程（直链 / HLS 分片）只用这一层接口。
abstract class DownloadSink {
  /// 追加一段数据。
  ///
  /// 返回非 null 表示触发背压，调用方应 await 后再继续下一块；
  /// 返回 null 表示可以立即继续（不产生额外微任务）。
  Future<void>? add(Uint8List bytes);

  Future<void> flush();

  Future<void> close();
}

/// 直接写（不落后台 isolate）：isolate 不可用时的兜底，行为与旧实现一致。
class DirectDownloadSink implements DownloadSink {
  DirectDownloadSink(this._sink);

  final IOSink _sink;

  @override
  Future<void>? add(Uint8List bytes) {
    _sink.add(bytes);
    return null;
  }

  @override
  Future<void> flush() => _sink.flush();

  @override
  Future<void> close() => _sink.close();
}

/// 后台写盘 isolate：把 IOSink 的订阅/缓冲/背压/错误处理移出 UI 线程，
/// 数据块经 [TransferableTypedData] 移交，UI 线程只负责转发。
///
/// 单例长驻；`Isolate.spawn` 失败时 [instance] 返回 null，回退 [DirectDownloadSink]。
class DownloadFileWriter {
  DownloadFileWriter._(this._responses, this._errors, this._isolate) {
    _responses.listen(_onMessage, onError: (_) => _failAll('writer crashed'));
    _errors.listen((e) => _failAll('writer error: $e'));
  }

  final ReceivePort _responses;
  final ReceivePort _errors;
  Isolate? _isolate;

  static DownloadFileWriter? _shared;
  static Future<DownloadFileWriter?>? _spawning;

  /// 未确认写入的字节上限（背压阈值）：超过则调用方的 `add` 返回 Future。
  static const int _maxInFlightBytes = 8 << 20;

  SendPort? _commands;
  final Completer<SendPort> _commandsReady = Completer<SendPort>();

  int _nextReq = 1;
  int _nextHandle = 1;
  int _inFlightBytes = 0;
  bool _closed = false;

  final List<Completer<void>> _slotWaiters = [];
  final Map<int, Completer<void>> _pending = {};

  /// 按 handle 记录的写块错误，等下一次 flush/close 抛出。
  final Map<int, String> _handleErrors = {};

  /// 获取共享写盘 isolate；不可用时返回 null。
  static Future<DownloadFileWriter?> instance() {
    final existing = _shared;
    if (existing != null && !existing._closed) return Future.value(existing);
    return _spawning ??= _spawn().whenComplete(() => _spawning = null);
  }

  static Future<DownloadFileWriter?> _spawn() async {
    final responses = ReceivePort();
    final errors = ReceivePort();
    try {
      final isolate = await Isolate.spawn<SendPort>(
        _writerMain,
        responses.sendPort,
        debugName: 'download-writer',
        errorsAreFatal: false,
      );
      // 捕获取 isolate 内未处理错误，避免拖垮进程
      isolate.addErrorListener(errors.sendPort);
      final writer = DownloadFileWriter._(responses, errors, isolate);
      _shared = writer;
      return writer;
    } catch (_) {
      errors.close();
      responses.close();
      return null;
    }
  }

  Future<DownloadSink> open(String path, {bool append = false}) async {
    final handle = _nextHandle++;
    await _request(_kOpen, handle, [path, append]);
    return _IsolateSink(this, handle);
  }

  Future<void>? _write(int handle, Uint8List bytes) {
    if (_closed) return null;
    // 先记长度再移交（fromList 后原列表不可再用）
    final length = bytes.length;
    final transferable = TransferableTypedData.fromList([bytes]);
    _inFlightBytes += length;
    _send(<Object?>[_kWrite, handle, transferable, length]);
    if (_inFlightBytes >= _maxInFlightBytes) {
      final completer = Completer<void>();
      _slotWaiters.add(completer);
      return completer.future;
    }
    return null;
  }

  Future<void> _flush(int handle) => _request(_kFlush, handle);

  Future<void> _close(int handle) => _request(_kClose, handle);

  Future<void> _request(
    String tag,
    int handle, [
    List<Object?> extra = const [],
  ]) {
    if (_closed) return Future.error(StateError('download writer closed'));
    // 之前 flush/close 之前若有写块失败，在这里抛出：
    // add() 是 fire-and-forget，没有返回值可以把错误递给调用方
    final pendingError = _handleErrors.remove(handle);
    if (pendingError != null) {
      return Future<void>.error(StateError(pendingError), StackTrace.current);
    }
    final req = _nextReq++;
    final completer = Completer<void>();
    _pending[req] = completer;
    _send(<Object?>[tag, handle, req, ...extra]);
    return completer.future;
  }

  /// 发送指令：握手未完成时先挂到命令端口 Future 上，完成后再发。
  void _send(List<Object?> msg) {
    final commands = _commands;
    if (commands != null) {
      commands.send(msg);
    } else {
      // 握手失败（isolate 崩溃）时忽略：后续 flush/close 会报错并触发重试
      unawaited(
        _commandsReady.future
            .then((port) => port.send(msg))
            .catchError((Object _) {}),
      );
    }
  }

  void _onMessage(dynamic msg) {
    // 握手消息：isolate 回传的命令 SendPort
    if (_commands == null) {
      if (msg is SendPort) {
        _commands = msg;
        if (!_commandsReady.isCompleted) _commandsReady.complete(msg);
      }
      return;
    }
    if (msg is! List || msg.isEmpty) return;
    switch (msg[0]) {
      case _kAck:
        _inFlightBytes -= msg[1] as int;
        if (_inFlightBytes < 0) _inFlightBytes = 0;
        _drainSlots();
      case _kDone:
        _pending.remove(msg[1] as int)?.complete();
      case _kError:
        final req = msg[1] as int;
        final error = msg.length > 2 ? msg[2] : 'write failed';
        if (req > 0) {
          _pending.remove(req)?.completeError(StateError('$error'));
        } else {
          // 无 req 的写块错误：记到 handle 上，下一次 flush/close 时抛出
          final handle = msg.length > 3 && msg[3] is int ? msg[3] as int : -1;
          if (handle > 0) _handleErrors[handle] = '$error';
        }
    }
  }

  void _drainSlots() {
    while (_slotWaiters.isNotEmpty && _inFlightBytes < _maxInFlightBytes) {
      _slotWaiters.removeAt(0).complete();
    }
  }

  void _failAll(Object error) {
    if (_closed) return;
    _closed = true;
    if (!_commandsReady.isCompleted) _commandsReady.completeError(error);
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(error);
    }
    _pending.clear();
    for (final c in _slotWaiters) {
      if (!c.isCompleted) c.complete();
    }
    _slotWaiters.clear();
    _handleErrors.clear();
    // 关掉端口并杀掉 isolate：否则每次写盘失败都会留下一个
    // 永远收不到消息的 ReceivePort 和一个空转的 isolate
    final isolate = _isolate;
    _isolate = null;
    if (isolate != null) {
      isolate.kill(priority: Isolate.immediate);
    }
    _responses.close();
    _errors.close();
    if (identical(_shared, this)) _shared = null;
  }
}

class _IsolateSink implements DownloadSink {
  _IsolateSink(this._writer, this._handle);

  final DownloadFileWriter _writer;
  final int _handle;

  @override
  Future<void>? add(Uint8List bytes) => _writer._write(_handle, bytes);

  @override
  Future<void> flush() => _writer._flush(_handle);

  @override
  Future<void> close() => _writer._close(_handle);
}

// ── isolate 协议 ────────────────────────────────────────────────────────────
const String _kOpen = 'open';
const String _kWrite = 'write';
const String _kFlush = 'flush';
const String _kClose = 'close';
const String _kAck = 'ack';
const String _kDone = 'done';
const String _kError = 'error';

/// 后台写盘 isolate 入口：持有多个 handle → IOSink，串行处理主 isolate 的
/// 打开/写入/刷新/关闭指令。写入用 ack 回传已接收字节数作为背压依据。
Future<void> _writerMain(SendPort main) async {
  final port = ReceivePort();
  main.send(port.sendPort);
  final sinks = <int, IOSink>{};
  await for (final msg in port) {
    if (msg is! List || msg.isEmpty) continue;
    final tag = msg[0];
    if (tag == _kWrite) {
      // 协议：[tag, handle, transferable, length]
      final handle = msg[1] as int;
      final length = msg[3] as int;
      try {
        final bytes = (msg[2] as TransferableTypedData)
            .materialize()
            .asUint8List();
        sinks[handle]?.add(bytes);
      } catch (e) {
        // 写数据块没有 req（add 是 fire-and-forget），错误挂到 handle 上，
        // 由随后的 flush/close 抛出。之前固定回 0 且主 isolate 直接丢弃，
        // 写盘失败会被当成成功 —— 截断文件也算下载完成。
        main.send([_kError, 0, e.toString(), handle]);
      } finally {
        // 无论成败都要 ack，否则主 isolate 的背压计数永不回落
        main.send([_kAck, length]);
      }
      continue;
    }
    try {
      switch (tag) {
        case _kOpen:
          final handle = msg[1] as int;
          final req = msg[2] as int;
          final path = msg[3] as String;
          final append = msg[4] as bool;
          final prev = sinks.remove(handle);
          if (prev != null) {
            try {
              await prev.close();
            } catch (_) {}
          }
          sinks[handle] = File(path)
              .openWrite(mode: append ? FileMode.append : FileMode.write);
          main.send([_kDone, req]);
        case _kFlush:
          final handle = msg[1] as int;
          final req = msg[2] as int;
          await sinks[handle]?.flush();
          main.send([_kDone, req]);
        case _kClose:
          final handle = msg[1] as int;
          final req = msg[2] as int;
          final sink = sinks.remove(handle);
          if (sink != null) await sink.close();
          main.send([_kDone, req]);
      }
    } catch (e) {
      final req = (msg.length > 2 && msg[2] is int) ? msg[2] as int : 0;
      main.send([_kError, req, e.toString()]);
    }
  }
}
