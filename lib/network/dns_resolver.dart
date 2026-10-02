import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// DNS 上游服务器地址。
///
/// 只接受 IP 字面量：DNS 服务器域名本身就需要先解析，
/// 用系统解析器去解析 DNS 服务器域名会形成循环依赖，且在被污染的网络里并不可靠。
class DnsEndpoint {
  const DnsEndpoint(this.address, this.port);

  final InternetAddress address;
  final int port;

  bool get isV6 => address.type == InternetAddressType.IPv6;

  String get text => port == 53 ? address.address : '${address.address}:$port';

  /// 解析用户填写的地址，接受 `1.1.1.1` / `1.1.1.1:53` / `[2400:3200::1]` /
  /// `[2400:3200::1]:53` / `udp://223.5.5.5`，非法输入返回 null。
  static DnsEndpoint? tryParse(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    value = value.replaceFirst(
      RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false),
      '',
    );
    if (value.isEmpty) return null;

    String host;
    var port = 53;
    if (value.startsWith('[')) {
      final end = value.indexOf(']');
      if (end < 0) return null;
      host = value.substring(1, end);
      final rest = value.substring(end + 1);
      if (rest.isNotEmpty) {
        if (!rest.startsWith(':')) return null;
        port = int.tryParse(rest.substring(1)) ?? 0;
      }
    } else if (':'.allMatches(value).length == 1) {
      // 单个冒号按 host:port 解析；多个冒号则整体视为 IPv6 字面量
      final idx = value.lastIndexOf(':');
      host = value.substring(0, idx);
      port = int.tryParse(value.substring(idx + 1)) ?? 0;
    } else {
      host = value;
    }

    if (port <= 0 || port > 65535) return null;
    final address = InternetAddress.tryParse(host);
    if (address == null) return null;
    return DnsEndpoint(address, port);
  }

  @override
  String toString() => text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DnsEndpoint &&
          address.address == other.address.address &&
          port == other.port;

  @override
  int get hashCode => Object.hash(address.address, port);
}

/// 一次解析所需的配置快照。
class DnsPlan {
  const DnsPlan({
    this.servers = const [],
    this.cacheTtl = const Duration(seconds: 300),
    this.signature = '',
    this.timeout = const Duration(seconds: 3),
  });

  /// 并发查询的上游，取第一个成功返回的（最快的）。
  /// 为空表示交给系统解析。
  final List<DnsEndpoint> servers;

  /// 结果缓存时长，[Duration.zero] 表示不缓存。
  final Duration cacheTtl;

  /// 配置指纹：不同上游配置的缓存按它分桶，互不干扰。
  final String signature;

  /// 单次查询超时。
  final Duration timeout;

  bool get useCustom => servers.isNotEmpty;

  DnsPlan copyWith({
    List<DnsEndpoint>? servers,
    Duration? cacheTtl,
    String? signature,
  }) => DnsPlan(
    servers: servers ?? this.servers,
    cacheTtl: cacheTtl ?? this.cacheTtl,
    signature: signature ?? this.signature,
    timeout: timeout,
  );
}

/// 一次 DNS 应答的解析结果。
class DnsAnswer {
  const DnsAnswer(this.addresses, this.minTtl);

  /// 解析到的 IP（IPv4 在前）。
  final List<String> addresses;

  /// 应答自带的最小 TTL（秒），无记录时为 null。
  final int? minTtl;

  bool get isEmpty => addresses.isEmpty;
}

/// 单个 DNS 服务器的测速结果。
class DnsProbeResult {
  const DnsProbeResult({
    required this.endpoint,
    required this.latency,
    this.hits = 0,
    this.total = 0,
    this.addresses = const [],
    this.error,
  });

  final DnsEndpoint endpoint;

  /// 各测试域名往返耗时的平均值（毫秒），全部失败时为 null。
  final int? latency;

  /// 有应答的测试域名数量。
  final int hits;

  /// 测试域名总数。
  final int total;

  /// 首个成功应答给出的地址（用于展示这个 DNS 解析成什么）。
  final List<String> addresses;

  final String? error;

  bool get ok => error == null && latency != null;

  /// 是否有测试域名没解析出来（如该 DNS 屏蔽了某些域名）。
  bool get partial => ok && hits < total;
}

/// 极简 DNS over UDP 客户端：自己拼/解 DNS 报文，并向多个上游并发发问、
/// 采用第一个成功返回的应答（即「最快 DNS」），全程不经系统解析器，
/// 因此既能绕开运营商污染，也不会与自身的网络请求形成递归。
class DnsResolver {
  DnsResolver._();

  static const _typeA = 1;
  static const _typeAaaa = 28;
  static const _classIn = 1;
  static const _maxCacheSize = 512;

  static final Map<String, List<String>> _cache = {};
  static final Map<String, DateTime> _cacheExpire = {};
  static final Map<String, Future<List<String>>> _inflight = {};

  static int _lastId = Random().nextInt(0x7fff);

  /// 按 [plan] 解析 [host]：优先自定义上游（最快返回者胜出），
  /// 自定义上游全部失败时回落系统解析。
  static Future<List<String>> resolve(String host, DnsPlan plan) async {
    final literal = InternetAddress.tryParse(host);
    if (literal != null) return [literal.address];
    if (host.isEmpty) throw SocketException('empty host');

    // 不同规则可以配不同的上游：缓存按配置指纹分桶，
    // 避免多条规则交替解析时互相清空缓存。
    final key = plan.signature.isEmpty ? host : '${plan.signature}|$host';

    final cached = plan.cacheTtl > Duration.zero ? _cache[key] : null;
    if (cached != null &&
        (_cacheExpire[key]?.isAfter(DateTime.now()) ?? false)) {
      return cached;
    }

    final pending = _inflight[key];
    if (pending != null) return pending;

    final future = _resolveUncached(host, key, plan);
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  static Future<List<String>> _resolveUncached(
    String host,
    String key,
    DnsPlan plan,
  ) async {
    if (plan.useCustom) {
      final answer = await queryFastest(
        plan.servers,
        host,
        timeout: plan.timeout,
      );
      if (answer != null && !answer.isEmpty) {
        _cacheResult(key, answer, plan.cacheTtl);
        return answer.addresses;
      }
      // 自定义上游全挂（或只回了空记录）时仍兜底系统解析，
      // 否则一次配错就会让整个应用断网
    }
    final system = await lookupSystem(host);
    _cacheResult(key, DnsAnswer(system, null), plan.cacheTtl);
    return system;
  }

  static void _cacheResult(String key, DnsAnswer answer, Duration ttl) {
    if (ttl <= Duration.zero || answer.isEmpty) return;
    var seconds = ttl.inSeconds;
    final responseTtl = answer.minTtl;
    // 应答自带的 TTL 更短时以它为准，避免节点切换后仍指向旧 IP
    if (responseTtl != null && responseTtl < seconds) seconds = responseTtl;
    if (seconds <= 0) return;
    if (_cache.length >= _maxCacheSize) {
      // 顺手清掉已过期的，仍超量就不再缓存
      _cacheExpire.removeWhere((_, expire) => !expire.isAfter(DateTime.now()));
      _cache.removeWhere((_, _) => true);
      if (_cache.length >= _maxCacheSize) return;
    }
    _cache[key] = answer.addresses;
    _cacheExpire[key] = DateTime.now().add(Duration(seconds: seconds));
  }

  /// 系统解析（走系统的 getaddrinfo，不经过本类）。
  static Future<List<String>> lookupSystem(String host) async {
    try {
      final result = await InternetAddress.lookup(host);
      return result.map((e) => e.address).toList();
    } catch (e) {
      throw SocketException('Failed to resolve $host: $e');
    }
  }

  /// 清空解析缓存（设置变更后调用）。
  static void clearCache() {
    _cache.clear();
    _cacheExpire.clear();
    _inflight.clear();
  }

  /// 并发向 [servers] 查询 [host]，第一个返回可用记录的应答即为结果。
  ///
  /// 先问 A 记录；只有当所有上游都没给出 A 记录时才补问 AAAA，
  /// 这样能优先拿到 IPv4（IPv6-only 网络本来就是少数），又不会漏掉纯 IPv6 域名。
  ///
  /// 返回 null 表示所有上游都没能给出可用记录（调用方应回落系统解析）。
  static Future<DnsAnswer?> queryFastest(
    List<DnsEndpoint> servers,
    String host, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (servers.isEmpty) return null;
    final v4 = await _race(servers, host, _typeA, timeout);
    if (v4 == null || !v4.isEmpty) return v4;
    final v6 = await _race(servers, host, _typeAaaa, timeout);
    if (v6 != null && !v6.isEmpty) return v6;
    return v4;
  }

  /// 单个类型的一次「最快返回」竞速。
  ///
  /// 每个上游单独开一个 socket 发一次查询：Windows 上同一个 UDP socket
  /// 连续 send 第二次会直接返回 0（数据报被丢弃），复用 socket 会让
  /// 「并发查询多个 DNS」退化成只问第一个。
  static Future<DnsAnswer?> _race(
    List<DnsEndpoint> servers,
    String host,
    int type,
    Duration timeout,
  ) async {
    final completer = Completer<DnsAnswer?>();
    final sockets = <RawDatagramSocket>[];
    Timer? timer;
    var emptyAnswered = false;

    void finish(DnsAnswer? result) {
      if (completer.isCompleted) return;
      completer.complete(result);
      timer?.cancel();
      for (final socket in sockets) {
        socket.close();
      }
    }

    final id = _nextId();
    final query = _buildQuery(id, host, type);

    Future<void> ask(DnsEndpoint server) async {
      RawDatagramSocket? socket;
      try {
        socket = await RawDatagramSocket.bind(
          server.isV6 ? InternetAddress.anyIPv6 : InternetAddress.anyIPv4,
          0,
        );
      } catch (_) {
        // 该协议族不可用（如设备没有 IPv6）
        return;
      }
      // 竞速可能已经结束
      if (completer.isCompleted) {
        socket.close();
        return;
      }
      sockets.add(socket);
      final sent = socket.send(query, server.address, server.port);
      if (sent == 0) {
        socket.close();
        return;
      }
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;
        final answer = _parseAnswer(datagram.data, id);
        if (answer == null) return;
        if (answer.isEmpty) {
          emptyAnswered = true;
        } else {
          finish(answer);
        }
      });
    }

    for (final server in servers) {
      unawaited(ask(server));
    }
    timer = Timer(timeout, () {
      finish(emptyAnswered ? const DnsAnswer([], null) : null);
    });
    return completer.future;
  }

  /// 并发测速：对每个上游并发查询 [hosts] 里的全部测试域名，
  /// 耗时取各域名平均值（只测一个域名容易被单点缓存或某条线路带偏），
  /// 返回结果按平均延迟升序（失败的排在最后）。
  static Future<List<DnsProbeResult>> probe(
    List<DnsEndpoint> servers,
    List<String> hosts, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final results = await Future.wait(
      servers.map((server) => _probeOne(server, hosts, timeout)),
    );
    results.sort((a, b) {
      final la = a.latency;
      final lb = b.latency;
      if (la == null && lb == null) return 0;
      if (la == null) return 1;
      if (lb == null) return -1;
      return la.compareTo(lb);
    });
    return results;
  }

  static Future<DnsProbeResult> _probeOne(
    DnsEndpoint server,
    List<String> hosts,
    Duration timeout,
  ) async {
    final timed = await Future.wait(
      hosts.map((host) => _timedQuery(server, host, timeout)),
    );
    final answered = timed.where(
      (e) => e.answer?.addresses.isNotEmpty ?? false,
    );
    final hits = answered.length;
    if (hits == 0) {
      final failure = timed.where((e) => e.error != null).firstOrNull;
      return DnsProbeResult(
        endpoint: server,
        latency: null,
        hits: 0,
        total: hosts.length,
        error: failure?.error ?? 'timeout',
      );
    }
    var total = 0;
    List<String> addresses = const [];
    for (final entry in answered) {
      total += entry.elapsed;
      if (addresses.isEmpty) addresses = entry.answer!.addresses;
    }
    return DnsProbeResult(
      endpoint: server,
      latency: (total / hits).round(),
      hits: hits,
      total: hosts.length,
      addresses: addresses,
    );
  }

  /// 单个域名的单次查询（只问 A，测速不需要 AAAA），返回耗时与应答。
  static Future<_TimedAnswer> _timedQuery(
    DnsEndpoint server,
    String host,
    Duration timeout,
  ) async {
    final stopwatch = Stopwatch()..start();
    RawDatagramSocket? socket;
    Timer? timer;
    DnsAnswer? answer;
    String? error;
    try {
      final id = _nextId();
      final query = _buildQuery(id, host, _typeA);
      final completer = Completer<DnsAnswer?>();
      socket = await RawDatagramSocket.bind(
        server.isV6 ? InternetAddress.anyIPv6 : InternetAddress.anyIPv4,
        0,
      );
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;
        final parsed = _parseAnswer(datagram.data, id);
        if (parsed == null) return;
        if (!completer.isCompleted) completer.complete(parsed);
      });
      final sent = socket.send(query, server.address, server.port);
      if (sent == 0) {
        error = 'send failed';
      } else {
        timer = Timer(timeout, () {
          if (!completer.isCompleted) completer.complete(null);
        });
        answer = await completer.future;
      }
    } catch (e) {
      error = '$e';
    } finally {
      timer?.cancel();
      socket?.close();
    }
    stopwatch.stop();
    return _TimedAnswer(host, stopwatch.elapsedMilliseconds, answer, error);
  }

  static int _nextId() => (_lastId = (_lastId + 1) & 0xffff);

  static Uint8List _buildQuery(int id, String host, int type) {
    final builder = BytesBuilder(copy: false);
    void u8(int v) => builder.addByte(v & 0xff);
    void u16(int v) {
      u8(v >> 8);
      u8(v);
    }

    // 标准查询 + 递归期望；QDCOUNT = 1
    u16(id);
    u16(0x0100);
    u16(1);
    u16(0);
    u16(0);
    u16(0);
    for (final label in host.split('.')) {
      final bytes = utf8.encode(label);
      if (bytes.isEmpty || bytes.length > 63) continue;
      u8(bytes.length);
      builder.add(bytes);
    }
    u8(0);
    u16(type);
    u16(_classIn);
    return builder.toBytes();
  }

  /// 解析应答：只取 A / AAAA 记录，同时收集最小 TTL 供缓存使用。
  /// 返回 null 表示这不是本次查询的应答（ID 不符或报文截断）。
  static DnsAnswer? _parseAnswer(Uint8List data, int expectedId) {
    if (data.length < 12) return null;
    final id = (data[0] << 8) | data[1];
    if (id != expectedId) return null;
    // RCODE 是整个 flags 字段的低 4 位（不是低字节）
    final flags = (data[2] << 8) | data[3];
    final rcode = flags & 0x000f;
    final questions = (data[4] << 8) | data[5];
    final answers = (data[6] << 8) | data[7];
    // NXDOMAIN 视为「无可用记录」；SERVFAIL 等视为该上游失败
    if (rcode == 3) return const DnsAnswer([], null);
    if (rcode != 0) return null;

    var offset = 12;
    bool skipName() {
      while (offset < data.length) {
        final length = data[offset];
        if (length == 0) {
          offset++;
          return true;
        }
        if (length & 0xc0 == 0xc0) {
          offset += 2;
          return true;
        }
        offset += length + 1;
      }
      return false;
    }

    for (var i = 0; i < questions; i++) {
      if (!skipName()) return null;
      offset += 4; // QTYPE + QCLASS
      if (offset > data.length) return null;
    }

    final ips = <String>[];
    int? minTtl;
    for (var i = 0; i < answers; i++) {
      if (!skipName()) break;
      if (offset + 10 > data.length) break;
      final type = (data[offset] << 8) | data[offset + 1];
      final ttl = _readUint32(data, offset + 4);
      final rdLength = (data[offset + 8] << 8) | data[offset + 9];
      offset += 10;
      if (offset + rdLength > data.length) break;
      minTtl = minTtl == null ? ttl : (ttl < minTtl ? ttl : minTtl);
      if (type == _typeA && rdLength == 4) {
        ips.add(
          '${data[offset]}.${data[offset + 1]}.'
          '${data[offset + 2]}.${data[offset + 3]}',
        );
      } else if (type == _typeAaaa && rdLength == 16) {
        final address = InternetAddress.tryParse(
          _formatIPv6(data.sublist(offset, offset + 16)),
        );
        if (address != null) ips.add(address.address);
      }
      offset += rdLength;
    }
    return DnsAnswer(ips, minTtl);
  }

  static int _readUint32(Uint8List data, int offset) =>
      (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];

  static String _formatIPv6(Uint8List raw) {
    final groups = <String>[];
    for (var i = 0; i < 16; i += 2) {
      groups.add(((raw[i] << 8) | raw[i + 1]).toRadixString(16));
    }
    return groups.join(':');
  }
}

/// 测速用的一次域名查询结果。
class _TimedAnswer {
  const _TimedAnswer(this.host, this.elapsed, this.answer, this.error);

  final String host;

  /// 往返耗时（毫秒）
  final int elapsed;

  /// 应答内容，超时或失败时为 null
  final DnsAnswer? answer;

  final String? error;
}
