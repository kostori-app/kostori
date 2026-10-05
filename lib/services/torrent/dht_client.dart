import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

typedef DhtPeerCallback = void Function(InternetAddress ip, int port);

class _DhtNode {
  _DhtNode(this.ip, this.port, [this.id]);
  final InternetAddress ip;
  final int port;
  Uint8List? id;
}

/// 极简 Mainline DHT 客户端（BEP 5）：Kademlia 就近 `get_peers`，只做「找 peer」。
///
/// 内置 dtorrent_task_v2 的 DHT 存在解码缺陷（比较 `y == 'r'` 时拿到的是
/// 字节而非字符串），所有响应都会被丢弃，导致 trackerless 磁力永远找不到
/// peer。这里补一个可用的双栈（IPv4/IPv6）实现，找到的 peer 通过
/// `MetadataDownloader` 的 `addNewPeerAddress` 注入。
class DhtClient {
  DhtClient({
    required List<int> infoHash,
    required List<Uri> bootstrapNodes,
    required this.onPeer,
    this.onLog,
  }) : _infoHash = Uint8List.fromList(infoHash),
       _bootstrap = bootstrapNodes;

  final Uint8List _infoHash;
  final List<Uri> _bootstrap;
  final DhtPeerCallback onPeer;
  final void Function(String message)? onLog;

  final _rand = Random.secure();
  late final Uint8List _nodeId = Uint8List.fromList(
    List<int>.generate(20, (_) => _rand.nextInt(256)),
  );
  int _tid = 0;

  RawDatagramSocket? _socketV4;
  RawDatagramSocket? _socketV6;
  Timer? _ticker;
  bool _stopped = false;

  final Map<String, _DhtNode> _known = {};
  final Map<String, _DhtNode> _pending = {};
  final Map<String, int> _queriedAt = {};
  final Set<String> _seenPeers = {};

  static const int _maxQueries = 2000;

  /// 未收到响应的查询上限；超过后丢弃最早的条目，避免无响应节点堆积。
  static const int _maxPending = 512;

  /// 查询超时：超过该时长未应答的节点重新纳入候选，避免节点表枯竭。
  static const int _retryAfterMs = 15000;

  static const int _queriesPerRound = 40;

  int _peerCount = 0;

  String _key(InternetAddress ip, int port) => '${ip.address}:$port';

  void _log(String message) => onLog?.call(message);

  Future<void> start() async {
    if (_infoHash.length != 20) return;
    if (_stopped) return;
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      // bind 期间可能已被 stop()（例如元数据超时先到）：立刻关掉，别泄漏
      if (_stopped) {
        socket.close();
        return;
      }
      _socketV4 = socket;
      _listen(socket);
    } catch (e) {
      _log('IPv4 bind failed: $e');
    }
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      if (_stopped) {
        socket.close();
        return;
      }
      _socketV6 = socket;
      _listen(socket);
    } catch (e) {
      _log('IPv6 bind failed: $e');
    }
    if (_stopped) return;
    if (_socketV4 == null && _socketV6 == null) return;

    // 并发解析引导节点：串行时一个慢节点就能吃掉十几秒元数据抓取预算
    await Future.wait([for (final uri in _bootstrap) _addBootstrapNode(uri)]);
    if (_stopped) return;
    if (_known.isEmpty) {
      _log('引导节点全部不可用');
      return;
    }
    _pump();
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) => _pump());
  }

  Future<void> _addBootstrapNode(Uri uri) async {
    final port = uri.hasPort ? uri.port : 6881;
    try {
      final ips = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 5));
      for (final ip in ips) {
        if (_stopped) return;
        _known[_key(ip, port)] ??= _DhtNode(ip, port);
      }
    } catch (e) {
      _log('bootstrap ${uri.host} failed: $e');
    }
  }

  void _listen(RawDatagramSocket socket) {
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      while (!_stopped) {
        final datagram = socket.receive();
        if (datagram == null) break;
        try {
          _handle(datagram);
        } catch (_) {}
      }
    }, onError: (Object e) => _log('socket error: $e'));
  }

  Future<void> stop() async {
    _stopped = true;
    _ticker?.cancel();
    _ticker = null;
    _socketV4?.close();
    _socketV6?.close();
    _socketV4 = null;
    _socketV6 = null;
    _pending.clear();
    _known.clear();
    _queriedAt.clear();
    _seenPeers.clear();
  }

  /// 选择距离目标最近、尚未查询的节点发起 get_peers
  void _pump() {
    if (_stopped) return;
    _expireQueries();
    if (_queriedAt.length >= _maxQueries) return;
    final candidates =
        _known.values
            .where((n) => !_queriedAt.containsKey(_key(n.ip, n.port)))
            .toList()
          ..sort(_compareDistance);
    for (final node in candidates.take(_queriesPerRound)) {
      _query(node);
    }
    _log(
      'known=${_known.length} queried=${_queriedAt.length} '
      'pending=${_pending.length} peers=$_peerCount',
    );
  }

  /// 把超时未响应的节点重新放回候选集合。
  void _expireQueries() {
    if (_queriedAt.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final before = _queriedAt.length;
    _queriedAt.removeWhere((_, at) => now - at >= _retryAfterMs);
    if (_queriedAt.length == before) return;
    // 重新纳入候选的节点必须同步清掉，否则同一地址会在待回列表里堆多条
    _pending.removeWhere((_, node) {
      return !_queriedAt.containsKey(_key(node.ip, node.port));
    });
  }

  int _compareDistance(_DhtNode a, _DhtNode b) {
    final da = _distance(a);
    final db = _distance(b);
    for (var i = 0; i < 20; i++) {
      final c = da[i].compareTo(db[i]);
      if (c != 0) return c;
    }
    return 0;
  }

  Uint8List _distance(_DhtNode node) {
    final id = node.id;
    if (id == null) return Uint8List(20); // 未知 id 的引导节点优先查询
    final d = Uint8List(20);
    for (var i = 0; i < 20; i++) {
      d[i] = id[i] ^ _infoHash[i];
    }
    return d;
  }

  void _handle(Datagram datagram) {
    final message = _decode(datagram.data, [0]);
    if (message is! Map) return;
    if (_str(message['y']) != 'r') return;
    final r = message['r'];
    if (r is! Map) return;

    final tid = _str(message['t']);
    if (tid != null) {
      final responder = _pending.remove(tid);
      final responderId = _bytes(r['id']);
      if (responder != null && responderId != null) {
        responder.id = responderId;
      }
    }

    final values = r['values'];
    if (values is List) {
      for (final value in values) {
        _emitPeer(_bytes(value));
      }
    } else if (values != null) {
      _emitPeer(_bytes(values));
    }

    _addNodes(_bytes(r['nodes']), 26, 4);
    _addNodes(_bytes(r['nodes6']), 38, 16);
  }

  void _addNodes(Uint8List? nodes, int stride, int addrLen) {
    if (nodes == null) return;
    for (var o = 0; o + stride <= nodes.length; o += stride) {
      final id = Uint8List.sublistView(nodes, o, o + 20);
      final ip = _addr(Uint8List.sublistView(nodes, o + 20, o + 20 + addrLen));
      if (ip == null) continue;
      final port = (nodes[o + 20 + addrLen] << 8) | nodes[o + 20 + addrLen + 1];
      if (port <= 0) continue;
      final key = _key(ip, port);
      _known[key] ??= _DhtNode(ip, port, Uint8List.fromList(id));
    }
  }

  /// 按字节长度还原地址。必须显式指定地址族：16 字节的 IPv6 地址按 IPv4
  /// 解析会抛异常，进而丢弃同一数据报中的其余 peer 与节点。
  static InternetAddress? _addr(Uint8List raw) {
    try {
      if (raw.length == 4) {
        return InternetAddress.fromRawAddress(
          raw,
          type: InternetAddressType.IPv4,
        );
      }
      if (raw.length == 16) {
        return InternetAddress.fromRawAddress(
          raw,
          type: InternetAddressType.IPv6,
        );
      }
    } catch (_) {}
    return null;
  }

  void _emitPeer(Uint8List? bytes) {
    if (bytes == null) return;
    final int addrLen;
    if (bytes.length == 6) {
      addrLen = 4;
    } else if (bytes.length == 18) {
      addrLen = 16;
    } else {
      return;
    }
    final ip = _addr(Uint8List.sublistView(bytes, 0, addrLen));
    if (ip == null) return;
    final port = (bytes[addrLen] << 8) | bytes[addrLen + 1];
    if (port <= 0) return;
    if (_seenPeers.add(_key(ip, port))) {
      _peerCount++;
      onPeer(ip, port);
    }
  }

  void _query(_DhtNode node) {
    if (_stopped) return;
    if (_queriedAt.length >= _maxQueries) return;
    final nodeKey = _key(node.ip, node.port);
    _queriedAt[nodeKey] = DateTime.now().millisecondsSinceEpoch;
    final socket = node.ip.type == InternetAddressType.IPv6
        ? _socketV6
        : _socketV4;
    // 目标地址族没有可用 socket 就直接放弃：先登记 _pending 再 return
    // 会让无响应的查询永远留在表里（最多堆到 _maxQueries 条）
    if (socket == null) return;
    // 有响应才会移除 _pending，这里主动封顶，防止无响应的节点堆积
    if (_pending.length >= _maxPending) {
      _pending.remove(_pending.keys.first);
    }
    final tid = _nextTid();
    _pending[_str(tid)!] = node;
    final packet = {
      't': tid,
      'y': 'q',
      'q': 'get_peers',
      'a': {'id': _nodeId, 'info_hash': _infoHash},
    };
    try {
      socket.send(_encode(packet), node.ip, node.port);
    } catch (e) {
      _log('send failed $nodeKey: $e');
    }
  }

  List<int> _nextTid() {
    _tid = (_tid + 1) & 0xffff;
    return [_tid >> 8, _tid & 0xff];
  }

  // ---- bencode ----

  static List<int> _encode(Object? value) {
    final out = BytesBuilder();
    void enc(Object? v) {
      if (v is int) {
        out.add(ascii.encode('${v}e'));
      } else if (v is String) {
        final bytes = utf8.encode(v);
        out
          ..add(ascii.encode('${bytes.length}:'))
          ..add(bytes);
      } else if (v is List<int>) {
        out
          ..add(ascii.encode('${v.length}:'))
          ..add(v);
      } else if (v is List) {
        out.addByte(0x6c);
        for (final e in v) {
          enc(e);
        }
        out.addByte(0x65);
      } else if (v is Map) {
        out.addByte(0x64);
        final keys = v.keys.map((k) => k.toString()).toList()..sort();
        for (final k in keys) {
          enc(k);
          enc(v[k]);
        }
        out.addByte(0x65);
      }
    }

    enc(value);
    return out.toBytes();
  }

  static Object? _decode(Uint8List data, List<int> pos) {
    if (pos[0] >= data.length) return null;
    final c = data[pos[0]];
    if (c == 0x69) {
      final end = data.indexOf(0x65, pos[0]);
      if (end < 0) return null;
      final value = int.tryParse(
        ascii.decode(data.sublist(pos[0] + 1, end), allowInvalid: true),
      );
      pos[0] = end + 1;
      return value;
    }
    if (c == 0x6c) {
      pos[0]++;
      final list = <Object?>[];
      while (pos[0] < data.length && data[pos[0]] != 0x65) {
        list.add(_decode(data, pos));
      }
      pos[0]++;
      return list;
    }
    if (c == 0x64) {
      pos[0]++;
      final map = <String, Object?>{};
      while (pos[0] < data.length && data[pos[0]] != 0x65) {
        final key = _str(_decode(data, pos));
        if (key == null) return null;
        map[key] = _decode(data, pos);
      }
      pos[0]++;
      return map;
    }
    final colon = data.indexOf(0x3a, pos[0]);
    if (colon < 0) return null;
    final len = int.tryParse(
      ascii.decode(data.sublist(pos[0], colon), allowInvalid: true),
    );
    if (len == null || len < 0 || colon + 1 + len > data.length) return null;
    final start = colon + 1;
    pos[0] = start + len;
    return Uint8List.sublistView(data, start, start + len);
  }

  static Uint8List? _bytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }

  static String? _str(Object? value) {
    if (value is String) return value;
    if (value is List<int>) return String.fromCharCodes(value);
    return null;
  }
}
