import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/network/hosts_probe.dart';

void main() {
  group('HostsProbe', () {
    test('可连通的 IP 拿到耗时', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());

      final result = await HostsProbe.probe(
        '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 2),
      );
      expect(result.ok, isTrue);
      expect(result.latency, isNotNull);
    });

    test('非法 IP 直接判失败，不发起连接', () async {
      final result = await HostsProbe.probe('not-an-ip');
      expect(result.ok, isFalse);
      expect(result.error, 'invalid');
    });

    test('连不上的端口判为不可达', () async {
      // 借一个随即关闭的端口，保证没人监听
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();

      final result = await HostsProbe.probe(
        '127.0.0.1',
        port: port,
        timeout: const Duration(milliseconds: 500),
      );
      expect(result.ok, isFalse);
    });

    test('probeAll 并发探测全部 IP', () async {
      final results = await HostsProbe.probeAll(
        ['127.0.0.1', 'not-an-ip'],
        port: 1,
        timeout: const Duration(milliseconds: 300),
      );
      expect(results.length, 2);
      expect(results.last.ok, isFalse);
    });

    test('firstReachable 返回第一个连上的 IP', () async {
      // 127.0.0.1 有监听、127.0.0.2 同端口没人监听：确定性地只取前者
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());

      final winner = await HostsProbe.firstReachable(
        ['127.0.0.2', '127.0.0.1'],
        port: server.port,
        timeout: const Duration(seconds: 2),
      );
      expect(winner, '127.0.0.1');
    });

    test('firstReachable 全部失败返回 null', () async {
      final winner = await HostsProbe.firstReachable([
        'not-an-ip',
      ], timeout: const Duration(milliseconds: 200));
      expect(winner, isNull);
    });
  });

  group('HostsProbe.sortBySpeed', () {
    HostsProbeResult ok(String ip, int ms) =>
        HostsProbeResult(ip: ip, latency: ms);

    HostsProbeResult bad(String ip) =>
        HostsProbeResult(ip: ip, latency: null, error: 'timeout');

    test('可达的按耗时升序，不可达的沉到最后', () {
      final sorted = HostsProbe.sortBySpeed(
        ['1.1.1.1', '2.2.2.2', '3.3.3.3'],
        {
          '1.1.1.1': ok('1.1.1.1', 120),
          '2.2.2.2': ok('2.2.2.2', 30),
          '3.3.3.3': bad('3.3.3.3'),
        },
      );
      expect(sorted, ['2.2.2.2', '1.1.1.1', '3.3.3.3']);
    });

    test('同样不可达时保持原有先后', () {
      final sorted = HostsProbe.sortBySpeed(
        ['1.1.1.1', '2.2.2.2'],
        {'1.1.1.1': bad('1.1.1.1'), '2.2.2.2': bad('2.2.2.2')},
      );
      expect(sorted, ['1.1.1.1', '2.2.2.2']);
    });

    test('没有探测结果的 IP 排到最后', () {
      final sorted = HostsProbe.sortBySpeed(
        ['1.1.1.1', '2.2.2.2'],
        {'2.2.2.2': ok('2.2.2.2', 5)},
      );
      expect(sorted, ['2.2.2.2', '1.1.1.1']);
    });
  });
}
