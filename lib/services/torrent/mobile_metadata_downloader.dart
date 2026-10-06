import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';

class _PeerAttempt {
  ConnectionTask<Socket>? connection;
  Socket? socket;
  Timer? deadline;

  void close() {
    deadline?.cancel();
    connection?.cancel();
    socket?.destroy();
  }
}

/// 移动端按有限并发轮换候选，连接失败或握手无响应后继续尝试后续 peer。
/// 使用可取消连接，避免依赖库只回收已连通 peer、遗留连接中的 socket。
class MobileMetadataDownloader extends MetadataDownloader {
  MobileMetadataDownloader(
    super.infoHash, {
    required List<Uri> trackers,
    this.maxConnections = 16,
    this.connectTimeout = const Duration(seconds: 8),
    this.peerTimeout = const Duration(seconds: 12),
  }) : assert(maxConnections > 0),
       super(trackers: trackers) {
    // 应用自己的 DhtClient 已负责发现；依赖库会串行做无超时 DNS，
    // 不能让它阻塞已经由 HTTP tracker 找到的 peer。
    dht.clearBootstrapNodes();
    createListener().on<MetaDataDownloadProgress>((_) {
      // 收到有效分片代表仍在传输，不能按固定总时长掐断较大的元数据。
      for (final entry in _attempts.entries) {
        if (entry.value.socket != null) _armDeadline(entry.key, entry.value);
      }
    });
  }

  final int maxConnections;
  final Duration connectTimeout;
  final Duration peerTimeout;
  static const _maxPending = 512;

  final _pending = Queue<({CompactAddress address, PeerSource source})>();
  final _seen = <String>{};
  final _attempts = <String, _PeerAttempt>{};
  bool _ready = false;
  bool _stopped = false;
  Future<void>? _starting;
  Future<void>? _stopping;
  int _attempted = 0;
  int _connected = 0;

  String get debugSummary =>
      'queued=${_pending.length} active=${_attempts.length} '
      'attempted=$_attempted connected=$_connected';

  String _key(CompactAddress address) =>
      '${address.address.address}:${address.port}';

  @override
  Future<void> startDownload() {
    if (_stopped) return Future.value();
    return _starting ??= _start();
  }

  Future<void> _start() async {
    await super.startDownload();
    if (_stopped) return;
    _ready = true;
    _pump();
  }

  @override
  void addNewPeerAddress(
    CompactAddress address,
    PeerSource source, [
    PeerType type = PeerType.tcp,
    Object? socket,
  ]) {
    if (_stopped || type != PeerType.tcp || socket != null) {
      if (socket is Socket) socket.destroy();
      return;
    }
    if (_pending.length >= _maxPending) return;
    if (!_seen.add(_key(address))) return;
    _pending.add((address: address, source: source));
    _pump();
  }

  void _pump() {
    if (!_ready || _stopped) return;
    while (_attempts.length < maxConnections && _pending.isNotEmpty) {
      final candidate = _pending.removeFirst();
      final key = _key(candidate.address);
      final attempt = _PeerAttempt();
      _attempts[key] = attempt;
      _attempted++;
      unawaited(_connect(key, candidate.address, candidate.source, attempt));
    }
  }

  Future<void> _connect(
    String key,
    CompactAddress address,
    PeerSource source,
    _PeerAttempt attempt,
  ) async {
    try {
      final connection = await Socket.startConnect(
        address.address,
        address.port,
      );
      attempt.connection = connection;
      // 即使取消发生在 startConnect 返回前，也必须消耗取消产生的错误。
      final socketFuture = connection.socket.timeout(connectTimeout);
      if (_stopped) connection.cancel();
      final socket = await socketFuture;
      attempt.socket = socket;
      if (_stopped) {
        // stop() 已移除登记项时 _release 不会再处理这个迟到的 socket。
        attempt.close();
        _release(key, attempt);
        return;
      }
      _connected++;
      _armDeadline(key, attempt);
      unawaited(
        socket.done.then(
          (_) => _release(key, attempt),
          onError: (Object _, StackTrace _) => _release(key, attempt),
        ),
      );
      // 已连接的 socket 交给依赖库进行 BEP 10 / BEP 9 协议交换。
      super.addNewPeerAddress(address, source, PeerType.tcp, socket);
    } catch (_) {
      _release(key, attempt);
    }
  }

  void _armDeadline(String key, _PeerAttempt attempt) {
    attempt.deadline?.cancel();
    attempt.deadline = Timer(peerTimeout, () => _release(key, attempt));
  }

  void _release(String key, _PeerAttempt attempt) {
    if (!identical(_attempts[key], attempt)) return;
    _attempts.remove(key);
    attempt.close();
    _pump();
  }

  @override
  void addPEXPeer(
    Peer source,
    CompactAddress address,
    Map<String, bool> options,
  ) {
    addNewPeerAddress(address, PeerSource.pex);
  }

  @override
  void holePunchConnect(CompactAddress ip) {}

  @override
  Future<void> stop() {
    return _stopping ??= _stop();
  }

  Future<void> _stop() async {
    _stopped = true;
    _ready = false;
    _pending.clear();
    for (final attempt in _attempts.values) {
      attempt.close();
    }
    _attempts.clear();
    try {
      await _starting;
    } catch (_) {}
    // startDownload 在读缓存或绑定 socket 时也可能被取消；等它退出以后
    // 再清理父类，确保取消之后不会重新开启 DHT/tracker。
    await super.stop();
  }
}
