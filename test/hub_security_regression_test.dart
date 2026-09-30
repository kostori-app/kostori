import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/hub_services/services.dart';

/// Hub 安全回归测试：每条用例钉住一个已修的鉴权/限额缺陷。
class _SecService extends BaseHttpService {
  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  void registerRoutes() {
    addGet(
      '/protected',
      (req, params) => sendJson(req, {'ok': true}),
      middlewares: [authMiddleware],
    );
    addPost('/json', (req, params) async {
      final data = await readJson(req);
      if (data == null) {
        return sendJson(req, {'error': 'Invalid JSON body'}, status: 400);
      }
      return sendJson(req, {'x': data['x']});
    });
    // 路径里带正则元字符：用于验证参数路由的 pattern 已正确转义
    addGet('/v1.v2/:id', (req, params) => sendJson(req, {'id': params['id']}));
  }
}

Future<T> _withServer<T>(
  Future<T> Function(int port, _SecService svc) body, {
  required int port,
}) async {
  final dir = await Directory.systemTemp.createTemp('kostori_hub_sec');
  App.dataPath = dir.path;
  await ApiKeyManager().init();
  final svc = _SecService();
  await svc.startServer(preferredPort: port, mode: BindMode.ipv4);
  try {
    return await body(svc.port, svc);
  } finally {
    await svc.stopServer();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

Future<(int, String)> _req(
  int port,
  String path, {
  String method = 'GET',
  String? token,
  Map<String, String> headers = const {},
  List<int>? bodyBytes,
  bool chunked = false,
}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    headers.forEach(req.headers.set);
    if (bodyBytes != null) {
      // 不设 contentLength → dart:io 走 Transfer-Encoding: chunked
      if (!chunked) req.contentLength = bodyBytes.length;
      req.add(bodyBytes);
    }
    final res = await req.close();
    final text = await res.transform(const SystemEncoding().decoder).join();
    return (res.statusCode, text);
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('localBypass：Origin 前缀匹配绕过', () {
    test('Origin 为 localhost.evil.com 时不得免验', () async {
      await _withServer((port, _) async {
        // 攻击者注册的域名解析到 127.0.0.1，Origin 以 http://localhost 开头
        final (code, _) = await _req(
          port,
          '/protected',
          headers: {'Origin': 'http://localhost.evil.com'},
        );
        expect(code, 401, reason: '恶意 Origin 必须要求鉴权');
      }, port: 47841);
    });

    test('Origin 为真正的 localhost 时仍然免验', () async {
      await _withServer((port, _) async {
        final (code, body) = await _req(
          port,
          '/protected',
          headers: {'Origin': 'http://localhost:$port'},
        );
        expect(code, 200);
        expect(body, contains('ok'));
      }, port: 47842);
    });

    test('无 Origin 的非浏览器请求仍然免验', () async {
      await _withServer((port, _) async {
        final (code, _) = await _req(port, '/protected');
        expect(code, 200);
      }, port: 47843);
    });
  });

  group('请求体上限：chunked 绕过', () {
    test('Transfer-Encoding: chunked 的大 body 仍应被拦成 413', () async {
      await _withServer((port, _) async {
        // chunked 请求读不到 content-length 头，只能靠流式计数拦下
        final (code, body) = await _req(
          port,
          '/json',
          method: 'POST',
          bodyBytes: List<int>.filled(8 * 1024 * 1024, 0x41),
          chunked: true,
        );
        expect(code, HttpStatus.requestEntityTooLarge);
        expect(body, contains('Request Entity Too Large'));
      }, port: 47844);
    });

    test('带 content-length 的超限请求同样被拦', () async {
      await _withServer((port, _) async {
        final (code, _) = await _req(
          port,
          '/json',
          method: 'POST',
          bodyBytes: List<int>.filled(8 * 1024 * 1024, 0x41),
        );
        expect(code, HttpStatus.requestEntityTooLarge);
      }, port: 47845);
    });

    test('限额内的正常 JSON 不受影响', () async {
      await _withServer((port, _) async {
        final (code, body) = await _req(
          port,
          '/json',
          method: 'POST',
          bodyBytes: utf8.encode('{"x":"hi"}'),
        );
        expect(code, 200);
        expect(body, contains('hi'));
      }, port: 47846);
    });
  });

  group('对外公布的鉴权方式必须真的能用', () {
    test('X-Api-Key 请求头', () async {
      await _withServer((port, _) async {
        final key = ApiKeyManager().activeKey;
        // 用恶意 Origin 关掉 localBypass，才能真正验证令牌本身
        final (code, _) = await _req(
          port,
          '/protected',
          headers: {'Origin': 'http://evil.test', 'X-Api-Key': key},
        );
        expect(code, 200, reason: '无头模式启动横幅公布的 X-Api-Key 必须有效');
      }, port: 47847);
    });

    test('?api_key= 查询参数', () async {
      await _withServer((port, _) async {
        final key = ApiKeyManager().activeKey;
        final (code, _) = await _req(
          port,
          '/protected?api_key=$key',
          headers: {'Origin': 'http://evil.test'},
        );
        expect(code, 200, reason: '?api_key= 必须与 ?token= 等价');
      }, port: 47848);
    });

    test('错误令牌仍然被拒', () async {
      await _withServer((port, _) async {
        final (code, _) = await _req(
          port,
          '/protected?api_key=wrong-key',
          headers: {'Origin': 'http://evil.test'},
        );
        expect(code, 401);
      }, port: 47849);
    });
  });

  group('参数路由的 pattern 转义', () {
    test('路径中的 . 是字面量，不是正则通配', () async {
      await _withServer((port, _) async {
        final (hit, hitBody) = await _req(port, '/v1.v2/abc');
        expect(hit, 200);
        expect(hitBody, contains('abc'));

        // `.` 未转义时会被当成任意字符
        final (miss, _) = await _req(port, '/v1Xv2/abc');
        expect(miss, 404);
      }, port: 47850);
    });
  });
}
