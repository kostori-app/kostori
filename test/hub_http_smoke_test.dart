import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:web_socket_channel/io.dart';

class _TestHttpService extends BaseHttpService {
  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  void registerRoutes() {}
}

class _TestWsService extends BaseHttpService {
  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  void registerRoutes() {
    addWs('/ws', (socket, req) async {
      socket.sink.add('hi');
      await for (final msg in socket.stream) {
        socket.sink.add('echo:$msg');
      }
    });
  }
}

void main() {
  test('shelf 承载的 BaseHttpService 能响应 /hello', () async {
    final dir = await Directory.systemTemp.createTemp('kostori_hub_smoke');
    App.dataPath = dir.path;

    final svc = _TestHttpService();
    await svc.startServer(preferredPort: 47811, mode: BindMode.ipv4);
    final port = svc.port;
    try {
      final client = HttpClient();
      try {
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/hello'),
        );
        final res = await req.close();
        final body = await res.transform(const SystemEncoding().decoder).join();
        expect(res.statusCode, 200);
        expect(body, contains('Hello World'));
      } finally {
        client.close(force: true);
      }
    } finally {
      await svc.stopServer();
      await dir.delete(recursive: true);
    }
  });

  test('WebSocket 路由经 shelf_web_socket 正常收发', () async {
    final dir = await Directory.systemTemp.createTemp('kostori_hub_ws');
    App.dataPath = dir.path;

    final svc = _TestWsService();
    await svc.startServer(preferredPort: 47821, mode: BindMode.ipv4);
    final port = svc.port;
    final channel = IOWebSocketChannel.connect('ws://127.0.0.1:$port/ws');
    try {
      final received = <String>[];
      final done = channel.stream
          .listen((data) => received.add(data as String))
          .asFuture<void>();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(received, contains('hi'));

      channel.sink.add('x');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(received, contains('echo:x'));

      await channel.sink.close();
      await done.timeout(const Duration(seconds: 2), onTimeout: () {});
    } finally {
      await channel.sink.close();
      await svc.stopServer();
      await dir.delete(recursive: true);
    }
  });
}
