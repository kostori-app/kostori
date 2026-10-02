import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/network/dns_resolver.dart';

/// 本地假 DNS 服务器：按配置回 A / AAAA 记录，用来验证拼包、解包与竞速逻辑
/// （CI 与本地都不依赖真实的 53 端口）。
class FakeDnsServer {
  FakeDnsServer._(this.socket);

  final RawDatagramSocket socket;

  int delayMs = 0;
  List<String> ipv4 = const [];
  List<String> ipv6 = const [];
  bool nxdomain = false;
  bool compressName = false;

  /// 只对这些查询域名回 NXDOMAIN（测「部分域名查不到」的场景）
  Set<String> nxdomainFor = const {};

  int queryCount = 0;

  /// 被查询的域名（用于 nxdomainFor 判断）
  String? lastQuestion;

  static Future<FakeDnsServer> start() async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final server = FakeDnsServer._(socket);
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      server.queryCount++;
      Future.delayed(
        Duration(milliseconds: server.delayMs),
        () => server._reply(datagram),
      );
    });
    return server;
  }

  DnsEndpoint get endpoint =>
      DnsEndpoint(InternetAddress.loopbackIPv4, socket.port);

  int _typeOf(Uint8List data) {
    var offset = 12;
    while (offset < data.length && data[offset] != 0) {
      offset += data[offset] + 1;
    }
    // QTYPE 在根标签之后的两个字节
    offset += 1;
    return offset + 1 < data.length
        ? (data[offset] << 8) | data[offset + 1]
        : 0;
  }

  /// 取出被查询的域名（长度字节 + 标签）
  String _questionOf(Uint8List data) {
    final labels = <String>[];
    var offset = 12;
    while (offset < data.length && data[offset] != 0) {
      final length = data[offset];
      labels.add(
        String.fromCharCodes(data.sublist(offset + 1, offset + 1 + length)),
      );
      offset += length + 1;
    }
    return labels.join('.');
  }

  void _reply(Datagram datagram) {
    final data = datagram.data;
    final id = (data[0] << 8) | data[1];
    final question = Uint8List.sublistView(data, 12);
    final type = _typeOf(data);
    final asked = _questionOf(data);
    lastQuestion = asked;
    final notFound = nxdomain || nxdomainFor.contains(asked);

    final answers = <Uint8List>[];
    void addA(String ip) {
      answers.add(
        _record(1, Uint8List.fromList(ip.split('.').map(int.parse).toList())),
      );
    }

    void addAaaa(String ip) {
      final rd = Uint8List(16);
      // 只处理完整写法（测试里都用完整八段），压缩写法在别处测
      final parts = ip.split(':');
      for (var i = 0; i < 8; i++) {
        final value = int.parse(parts[i], radix: 16);
        rd[i * 2] = (value >> 8) & 0xff;
        rd[i * 2 + 1] = value & 0xff;
      }
      answers.add(_record(28, rd));
    }

    if (!notFound) {
      if (type == 1) {
        for (final ip in ipv4) {
          addA(ip);
        }
      } else {
        for (final ip in ipv6) {
          addAaaa(ip);
        }
      }
    }

    final header = Uint8List.fromList([
      id >> 8,
      id & 0xff,
      0x81,
      notFound ? 0x83 : 0x80,
      0,
      1, // QDCOUNT
      answers.length >> 8,
      answers.length & 0xff,
      0,
      0,
      0,
      0,
    ]);
    final out = Uint8List.fromList([
      ...header,
      ...question,
      for (final answer in answers) ...answer,
    ]);
    socket.send(out, datagram.address, datagram.port);
  }

  Uint8List _record(int type, Uint8List rdata) {
    const ttl = 120;
    final out = <int>[];
    if (compressName) {
      out.addAll([0xc0, 12]);
    } else {
      for (final label in ['www', 'bgm', 'tv']) {
        out.add(label.length);
        out.addAll(label.codeUnits);
      }
      out.add(0);
    }
    out.addAll([
      type >> 8,
      type & 0xff,
      0,
      1, // CLASS IN
      (ttl >> 24) & 0xff,
      (ttl >> 16) & 0xff,
      (ttl >> 8) & 0xff,
      ttl & 0xff,
      rdata.length >> 8,
      rdata.length & 0xff,
    ]);
    out.addAll(rdata);
    return Uint8List.fromList(out);
  }
}

void main() {
  group('DnsEndpoint.tryParse', () {
    test('接受 IPv4 / IPv6 与端口', () {
      expect(DnsEndpoint.tryParse('1.1.1.1')?.text, '1.1.1.1');
      expect(DnsEndpoint.tryParse(' 8.8.8.8:53 ')?.text, '8.8.8.8');
      expect(DnsEndpoint.tryParse('223.5.5.5:5353')?.text, '223.5.5.5:5353');
      expect(DnsEndpoint.tryParse('udp://119.29.29.29')?.text, '119.29.29.29');
      expect(
        DnsEndpoint.tryParse('[2400:3200::1]:5353')?.address.address,
        '2400:3200::1',
      );
      expect(DnsEndpoint.tryParse('[2400:3200::1]:5353')?.port, 5353);
      expect(DnsEndpoint.tryParse('2400:3200::1')?.isV6, isTrue);
      expect(DnsEndpoint.tryParse('2400:3200::1')?.text, '2400:3200::1');
    });

    test('拒绝域名与非法端口', () {
      expect(DnsEndpoint.tryParse('dns.google'), isNull);
      expect(DnsEndpoint.tryParse('1.1.1.1:0'), isNull);
      expect(DnsEndpoint.tryParse('1.1.1.1:70000'), isNull);
      expect(DnsEndpoint.tryParse('1.1.1.1:x'), isNull);
      expect(DnsEndpoint.tryParse(''), isNull);
      expect(DnsEndpoint.tryParse('  '), isNull);
    });
  });

  group('DnsResolver.queryFastest', () {
    late FakeDnsServer server;

    setUp(() async {
      DnsResolver.clearCache();
      server = await FakeDnsServer.start();
    });

    tearDown(() => server.socket.close());

    test('解析多个 A 记录并带回 TTL', () async {
      server.ipv4 = ['1.2.3.4', '5.6.7.8'];
      final answer = await DnsResolver.queryFastest(
        [server.endpoint],
        'www.bgm.tv',
        timeout: const Duration(seconds: 5),
      );
      expect(answer?.addresses, ['1.2.3.4', '5.6.7.8']);
      expect(answer?.minTtl, 120);
    });

    test('支持应答里的压缩指针', () async {
      server
        ..ipv4 = ['9.8.7.6']
        ..compressName = true;
      final answer = await DnsResolver.queryFastest(
        [server.endpoint],
        'www.bgm.tv',
        timeout: const Duration(seconds: 5),
      );
      expect(answer?.addresses, ['9.8.7.6']);
    });

    test('没有 A 记录时补问 AAAA', () async {
      server.ipv6 = ['2400:3200:0000:0000:0000:0000:0000:0001'];
      final answer = await DnsResolver.queryFastest(
        [server.endpoint],
        'ipv6.bgm.tv',
        timeout: const Duration(seconds: 5),
      );
      expect(answer?.addresses, ['2400:3200:0:0:0:0:0:1']);
      // A 一次 + AAAA 一次
      expect(server.queryCount, 2);
    });

    test('NXDOMAIN 返回空记录而非失败', () async {
      server.nxdomain = true;
      final answer = await DnsResolver.queryFastest(
        [server.endpoint],
        'nx.bgm.tv',
        timeout: const Duration(seconds: 5),
      );
      expect(answer, isNotNull);
      expect(answer!.addresses, isEmpty);
    });

    test('并发查询取最先返回的那个', () async {
      final slow = await FakeDnsServer.start()
        ..ipv4 = ['8.8.4.4']
        ..delayMs = 400;
      final fast = await FakeDnsServer.start()
        ..ipv4 = ['9.9.9.9']
        ..delayMs = 5;
      addTearDown(slow.socket.close);
      addTearDown(fast.socket.close);

      final answer = await DnsResolver.queryFastest(
        [slow.endpoint, fast.endpoint],
        'race.bgm.tv',
        timeout: const Duration(seconds: 5),
      );
      expect(answer?.addresses, ['9.9.9.9']);
    });

    test('最快的返回空记录时继续等有记录的那个', () async {
      final empty = await FakeDnsServer.start()
        ..delayMs = 5;
      final real = await FakeDnsServer.start()
        ..ipv4 = ['7.7.7.7']
        ..delayMs = 150;
      addTearDown(empty.socket.close);
      addTearDown(real.socket.close);

      final answer = await DnsResolver.queryFastest(
        [empty.endpoint, real.endpoint],
        'race2.bgm.tv',
        timeout: const Duration(seconds: 5),
      );
      expect(answer?.addresses, ['7.7.7.7']);
    });

    test('全部失联时返回 null（交给上层回落系统解析）', () async {
      final dead = DnsEndpoint.tryParse('127.0.0.1:1')!;
      final answer = await DnsResolver.queryFastest(
        [dead],
        'dead.bgm.tv',
        timeout: const Duration(milliseconds: 300),
      );
      expect(answer, isNull);
    });
  });

  group('DnsResolver.resolve', () {
    late FakeDnsServer server;

    setUp(() async {
      DnsResolver.clearCache();
      server = await FakeDnsServer.start()
        ..ipv4 = ['4.4.4.4'];
    });

    tearDown(() => server.socket.close());

    test('缓存命中时不再发查询', () async {
      final plan = DnsPlan(
        servers: [server.endpoint],
        cacheTtl: const Duration(minutes: 5),
        signature: 'test',
      );
      expect(await DnsResolver.resolve('cache.bgm.tv', plan), ['4.4.4.4']);
      expect(server.queryCount, 1);
      expect(await DnsResolver.resolve('cache.bgm.tv', plan), ['4.4.4.4']);
      expect(server.queryCount, 1);
    });

    test('不缓存时每次都重新查询', () async {
      final plan = DnsPlan(
        servers: [server.endpoint],
        cacheTtl: Duration.zero,
        signature: 'test',
      );
      await DnsResolver.resolve('nocache.bgm.tv', plan);
      await DnsResolver.resolve('nocache.bgm.tv', plan);
      expect(server.queryCount, 2);
    });

    test('配置指纹变化会让缓存失效', () async {
      await DnsResolver.resolve(
        'sign.bgm.tv',
        DnsPlan(
          servers: [server.endpoint],
          cacheTtl: const Duration(minutes: 5),
          signature: 'a',
        ),
      );
      await DnsResolver.resolve(
        'sign.bgm.tv',
        DnsPlan(
          servers: [server.endpoint],
          cacheTtl: const Duration(minutes: 5),
          signature: 'b',
        ),
      );
      expect(server.queryCount, 2);
    });

    test('自定义上游全挂时回落系统解析', () async {
      final dead = DnsEndpoint.tryParse('127.0.0.1:1')!;
      final addresses = await DnsResolver.resolve(
        'localhost',
        DnsPlan(
          servers: [dead],
          cacheTtl: Duration.zero,
          signature: 'test',
          timeout: const Duration(milliseconds: 300),
        ),
      );
      expect(addresses, isNotEmpty);
    });

    test('IP 字面量直接返回', () async {
      expect(await DnsResolver.resolve('1.2.3.4', const DnsPlan()), [
        '1.2.3.4',
      ]);
      expect(server.queryCount, 0);
    });
  });

  group('DnsResolver.probe', () {
    test('按平均延迟升序返回，失败排在最后', () async {
      final slow = await FakeDnsServer.start()
        ..ipv4 = ['1.1.1.1']
        ..delayMs = 200;
      final fast = await FakeDnsServer.start()
        ..ipv4 = ['2.2.2.2']
        ..delayMs = 5;
      final dead = DnsEndpoint.tryParse('127.0.0.1:1')!;
      addTearDown(slow.socket.close);
      addTearDown(fast.socket.close);

      final results = await DnsResolver.probe(
        [slow.endpoint, dead, fast.endpoint],
        ['www.bgm.tv'],
        timeout: const Duration(seconds: 2),
      );
      expect(results.map((e) => e.endpoint), [
        fast.endpoint,
        slow.endpoint,
        dead,
      ]);
      expect(results[0].latency, lessThan(results[1].latency!));
      expect(results[2].latency, isNull);
      expect(results[0].addresses, ['2.2.2.2']);
      expect(results[0].hits, 1);
      expect(results[0].total, 1);
      expect(results[0].partial, isFalse);
    });

    test('多个测试域名并发查询，耗时取平均并记录命中数', () async {
      final server = await FakeDnsServer.start()
        ..ipv4 = ['3.3.3.3']
        ..delayMs = 20;
      addTearDown(server.socket.close);

      final results = await DnsResolver.probe(
        [server.endpoint],
        ['www.bgm.tv', 'github.com'],
        timeout: const Duration(seconds: 2),
      );
      expect(results.single.hits, 2);
      expect(results.single.total, 2);
      expect(results.single.latency, isNotNull);
      // 两个域名同时发出，不是串行等待
      expect(server.queryCount, 2);
    });

    test('部分域名查不到时标记为 partial', () async {
      final server = await FakeDnsServer.start()
        ..ipv4 = ['4.4.4.4']
        ..nxdomainFor = {'blocked.bgm.tv'};
      addTearDown(server.socket.close);

      final results = await DnsResolver.probe(
        [server.endpoint],
        ['ok.bgm.tv', 'blocked.bgm.tv'],
        timeout: const Duration(seconds: 2),
      );
      expect(results.single.ok, isTrue);
      expect(results.single.hits, 1);
      expect(results.single.total, 2);
      expect(results.single.partial, isTrue);
    });
  });
}
