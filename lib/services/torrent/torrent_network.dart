import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';

/// HTTP tracker、Web seed 和引擎异步回调统一直连，不继承应用/环境代理。
/// 系统 VPN 的路由策略由 VPN 应用控制，DIRECT 无法绕过它。
abstract final class TorrentNetwork {
  static const methodChannel = MethodChannel('kostori/method_channel');

  static T run<T>(T Function() body) => IOOverrides.runZoned(
    () => HttpOverrides.runWithHttpOverrides(body, _DirectHttpOverrides()),
    socketConnect: (host, port, {sourceAddress, sourcePort = 0, timeout}) =>
        _TorrentSocketOverrides.connect(host, port, timeout: timeout),
    socketStartConnect: (host, port, {sourceAddress, sourcePort = 0}) =>
        _TorrentSocketOverrides.startConnect(host, port),
  );

  static HttpClient createHttpClient() => run(HttpClient.new);

  /// Android VPNs intercept Dart sockets even when HttpClient requests DIRECT.
  /// The platform side opens this request on the selected physical Network.
  static Future<Uint8List?> announceHttp(Uri uri) async {
    if (!Platform.isAndroid) return null;
    try {
      final bytes = await methodChannel.invokeMethod<Uint8List>(
        'announceTorrentHttpTracker',
        {'url': uri.toString()},
      );
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isVpnActive() async {
    if (!Platform.isAndroid) return false;
    try {
      return await methodChannel.invokeMethod<bool>('isVpnActive') ?? false;
    } catch (_) {
      return false;
    }
  }
}

abstract final class _TorrentSocketOverrides {
  static const _channel = MethodChannel('kostori/method_channel');
  static int? _port;
  static Future<int>? _starting;

  static Future<int> _relayPort() => _port == null
      ? (_starting ??= _channel
            .invokeMethod<int>('startTorrentDirectRelay')
            .then((value) => _port = value ?? 0)
            .whenComplete(() => _starting = null))
      : Future.value(_port);

  static Future<Socket> connect(
    Object host,
    int port, {
    Duration? timeout,
  }) async {
    if (!Platform.isAndroid) {
      return _nativeConnect(host, port, timeout: timeout);
    }
    final endpoint = switch (host) {
      InternetAddress address => address.address,
      String name => name,
      _ => '$host',
    };
    final directPort = await _relayPort();
    if (directPort <= 0) {
      throw const SocketException('direct torrent relay unavailable');
    }
    // This loopback connection must bypass the torrent override itself.
    // Calling Socket.connect directly here re-enters this callback forever.
    final socket = await _nativeConnect(
      InternetAddress.loopbackIPv4,
      directPort,
      timeout: timeout,
    );
    try {
      final hostBytes = utf8.encode(endpoint);
      if (hostBytes.isEmpty ||
          hostBytes.length > 65535 ||
          port < 1 ||
          port > 65535) {
        throw ArgumentError('invalid torrent peer endpoint');
      }
      socket.add([
        hostBytes.length >> 8,
        hostBytes.length & 0xff,
        ...hostBytes,
        port >> 8,
        port & 0xff,
      ]);
      await socket.flush();
      return socket;
    } catch (_) {
      socket.destroy();
      rethrow;
    }
  }

  static Future<ConnectionTask<Socket>> startConnect(
    Object host,
    int port,
  ) async {
    if (!Platform.isAndroid) return _nativeStartConnect(host, port);
    Socket? socket;
    final future = connect(host, port).then((result) => socket = result);
    return ConnectionTask.fromSocket<Socket>(future, () => socket?.destroy());
  }

  static Future<Socket> _nativeConnect(
    Object host,
    int port, {
    Duration? timeout,
  }) => IOOverrides.runWithIOOverrides(
    () => Socket.connect(host, port, timeout: timeout),
    _NativeSocketOverrides.instance,
  );

  static Future<ConnectionTask<Socket>> _nativeStartConnect(
    Object host,
    int port,
  ) => IOOverrides.runWithIOOverrides(
    () => Socket.startConnect(host, port),
    _NativeSocketOverrides.instance,
  );
}

/// Empty override scope used to reach dart:io's native socket implementation
/// from inside [TorrentNetwork]'s socket override.
final class _NativeSocketOverrides extends IOOverrides {
  static final instance = _NativeSocketOverrides();
}

class _DirectHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'DIRECT';
}
