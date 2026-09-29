import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:web_socket_channel/io.dart';

/// 覆盖路由（精确/参数）、JSON 收发、鉴权中间件、WebSocket token 鉴权。
class _IntegrationService extends BaseHttpService {
  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  void registerRoutes() {
    addGet(
      '/protected',
      (req, params) async => sendJson(req, {'ok': true}),
      middlewares: [authMiddleware],
    );
    addGet(
      '/admin',
      (req, params) async => sendJson(req, {'ok': true}),
      middlewares: [adminAuthMiddleware],
    );
    addPost('/json', (req, params) async {
      final data = await readJson(req);
      if (data == null) {
        return sendJson(req, {'error': 'Invalid JSON body'}, status: 400);
      }
      return sendJson(req, {'x': data['x']});
    });
    addGet(
      '/item/:id',
      (req, params) async => sendJson(req, {'id': params['id']}),
    );
    addWs('/wsauth', (socket, req) async {
      if (req.requestedUri.queryParameters['token'] != 'secret') {
        closeWebSocket(socket, WebSocketStatus.policyViolation, 'Unauthorized');
        return;
      }
      socket.sink.add('ok');
      await for (final msg in socket.stream) {
        socket.sink.add('echo:$msg');
      }
    });
  }
}

Future<T> _withServer<T>(
  Future<T> Function(int port) body, {
  required int port,
}) async {
  final dir = await Directory.systemTemp.createTemp('kostori_hub_it');
  App.dataPath = dir.path;
  await ApiKeyManager().init();
  final svc = _IntegrationService();
  await svc.startServer(preferredPort: port, mode: BindMode.ipv4);
  try {
    return await body(svc.port);
  } finally {
    await svc.stopServer();
    await dir.delete(recursive: true);
  }
}

Future<(int, String)> _get(
  int port,
  String path, {
  String? token,
  String? method,
  String? bodyJson,
}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(
      method ?? 'GET',
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    if (bodyJson != null) {
      req.headers.contentType = ContentType.json;
      req.write(bodyJson);
    }
    final res = await req.close();
    final text = await res.transform(const SystemEncoding().decoder).join();
    return (res.statusCode, text);
  } finally {
    client.close(force: true);
  }
}

void main() {
  test('路由：参数、JSON POST、404', () async {
    await _withServer((port) async {
      final (code, body) = await _get(port, '/item/abc123');
      expect(code, 200);
      expect(body, contains('abc123'));

      final (jcode, jbody) = await _get(
        port,
        '/json',
        method: 'POST',
        bodyJson: '{"x":"hi"}',
      );
      expect(jcode, 200);
      expect(jbody, contains('hi'));

      final (ncode, _) = await _get(port, '/nope');
      expect(ncode, 404);
    }, port: 47831);
  });

  test('鉴权：本地免验 + 管理层 Key', () async {
    await _withServer((port) async {
      final userKey = ApiKeyManager().activeKey;
      final adminKey = ApiKeyManager().adminActiveKey;

      // 用户层鉴权对本地回环免验（localBypass）
      final (localUser, _) = await _get(port, '/protected');
      expect(localUser, 200);
      final (localUserKey, _) = await _get(port, '/protected', token: userKey);
      expect(localUserKey, 200);

      // 管理接口不免验：无 Key / 用户 Key 均拒绝，管理 Key 通过
      final (noAuth, _) = await _get(port, '/admin');
      expect(noAuth, 401);

      final (adminRejectUser, _) = await _get(port, '/admin', token: userKey);
      expect(adminRejectUser, 401);

      final (adminOk, _) = await _get(port, '/admin', token: adminKey);
      expect(adminOk, 200);
    }, port: 47832);
  });

  test('WebSocket：token 鉴权与回声', () async {
    await _withServer((port) async {
      // 无 token：连接被服务端关闭，收不到任何数据（吞掉预期内的断开错误）
      final bad = IOWebSocketChannel.connect('ws://127.0.0.1:$port/wsauth');
      final badEvents = <dynamic>[];
      final badDone = bad.stream
          .listen(badEvents.add, onError: (_) {})
          .asFuture<void>();
      await badDone.timeout(const Duration(seconds: 2), onTimeout: () {});
      expect(badEvents, isEmpty);
      await bad.sink.close();

      // 正确 token：收到 ok 且回声正常
      final good = IOWebSocketChannel.connect(
        'ws://127.0.0.1:$port/wsauth?token=secret',
      );
      final goodEvents = <String>[];
      final sub = good.stream.listen((d) => goodEvents.add(d as String));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(goodEvents, contains('ok'));
      good.sink.add('ping');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(goodEvents, contains('echo:ping'));
      await sub.cancel();
      await good.sink.close();
    }, port: 47833);
  });
}
