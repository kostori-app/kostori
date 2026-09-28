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
  final Set<String> _queried = {};
  final Set<String> _seenPeers = {};

  static const int _maxQueries = 2000;

  String _key(InternetAddress ip, int port) => '${ip.address}:$port';

  void _log(String message) => onLog?.call(message);

  Future<void> start() async {
    if (_infoHash.length != 20) return;
    try {
      _socketV4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _listen(_socketV4!);
    } catch (e) {
      _log('IPv4 bind failed: $e');
    }
    try {
      _socketV6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      _listen(_socketV6!);
    } catch (e) {
      _log('IPv6 bind failed: $e');
    }
    if (_socketV4 == null && _socketV6 == null) return;

    for (final uri in _bootstrap) {
      try {
        final port = uri.hasPort ? uri.port : 6881;
        final ips = await InternetAddress.lookup(uri.host);
        for (final ip in ips) {
          _known[_key(ip, port)] ??= _DhtNode(ip, port);
        }
      } catch (e) {
        _log('bootstrap ${uri.host} failed: $e');
      }
    }
    _pump();
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) => _pump());
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
  }

  /// 选择距离目标最近、尚未查询的节点发起 get_peers
  void _pump() {
    if (_stopped || _queried.length >= _maxQueries) return;
    final candidates =
        _known.values
            .where((n) => !_queried.contains(_key(n.ip, n.port)))
            .toList()
          ..sort(_compareDistance);
    for (final node in candidates.take(40)) {
      _query(node);
    }
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
      final ip = InternetAddress.fromRawAddress(
        Uint8List.sublistView(nodes, o + 20, o + 20 + addrLen),
      );
      final port = (nodes[o + 20 + addrLen] << 8) | nodes[o + 20 + addrLen + 1];
      if (port <= 0) continue;
      final key = _key(ip, port);
      _known[key] ??= _DhtNode(ip, port, Uint8List.fromList(id));
    }
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
    final ip = InternetAddress.fromRawAddress(
      Uint8List.sublistView(bytes, 0, addrLen),
    );
    final port = (bytes[addrLen] << 8) | bytes[addrLen + 1];
    if (port <= 0) return;
    if (_seenPeers.add(_key(ip, port))) onPeer(ip, port);
  }

  void _query(_DhtNode node) {
    if (_queried.length >= _maxQueries) return;
    final nodeKey = _key(node.ip, node.port);
    if (!_queried.add(nodeKey)) return;
    final tid = _nextTid();
    _pending[_str(tid)!] = node;
    final packet = {
      't': tid,
      'y': 'q',
      'q': 'get_peers',
      'a': {'id': _nodeId, 'info_hash': _infoHash},
    };
    final socket = node.ip.type == InternetAddressType.IPv6
        ? _socketV6
        : _socketV4;
    if (socket == null) return;
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
