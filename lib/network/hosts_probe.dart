import 'dart:async';
import 'dart:io';

/// 单个 IP 的连通性 / 速度探测结果。
class HostsProbeResult {
  const HostsProbeResult({required this.ip, required this.latency, this.error});

  final String ip;

  /// TCP 连接耗时（毫秒）；不可达时为 null。
  final int? latency;

  final String? error;

  bool get ok => error == null && latency != null;
}

/// hosts 条目里多个 IP 的测速择优：测一遍每个 IP 的 TCP 建连耗时，
/// 供界面把更快的排到前面，也能看出哪些 IP 已不可用（多半是 CDN 换节点了）。
class HostsProbe {
  HostsProbe._();

  /// 默认按 HTTPS 端口探测：hosts 场景基本都是网页请求。
  static const defaultPort = 443;

  static Future<HostsProbeResult> probe(
    String ip, {
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final address = InternetAddress.tryParse(ip.trim());
    if (address == null) {
      return HostsProbeResult(ip: ip, latency: null, error: 'invalid');
    }
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(address, port, timeout: timeout);
      stopwatch.stop();
      socket.destroy();
      return HostsProbeResult(ip: ip, latency: stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      return HostsProbeResult(ip: ip, latency: null, error: '$e');
    }
  }

  /// 并发探测多个 IP。
  static Future<List<HostsProbeResult>> probeAll(
    List<String> ips, {
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 3),
  }) => Future.wait(ips.map((ip) => probe(ip, port: port, timeout: timeout)));

  /// 并发连接多个 IP，返回第一个连上的 IP；全部失败返回 null。
  static Future<String?> firstReachable(
    List<String> ips, {
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 3),
  }) {
    if (ips.isEmpty) return Future.value();
    final completer = Completer<String?>();
    var remaining = ips.length;
    for (final ip in ips) {
      probe(ip, port: port, timeout: timeout).then(
        (result) {
          if (result.ok && !completer.isCompleted) {
            completer.complete(ip);
          }
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        },
        onError: (_) {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        },
      );
    }
    return completer.future;
  }

  /// 按探测结果重排：可达的按耗时升序在前，不可达的沉到最后（保持相对顺序）。
  static List<String> sortBySpeed(
    List<String> ips,
    Map<String, HostsProbeResult> results,
  ) {
    int rank(String ip) {
      final result = results[ip];
      if (result == null) return 1 << 30;
      if (!result.ok) return 1 << 30;
      return result.latency!;
    }

    final indexed = [for (var i = 0; i < ips.length; i++) (i, ips[i])];
    indexed.sort((a, b) {
      final ra = rank(a.$2);
      final rb = rank(b.$2);
      if (ra != rb) return ra.compareTo(rb);
      // 同样不可达（或同样快）时保持原来的先后
      return a.$1.compareTo(b.$1);
    });
    return [for (final item in indexed) item.$2];
  }
}
