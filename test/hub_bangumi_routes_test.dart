import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/hub_services/services.dart';

class _TestHttpService extends BaseHttpService {
  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  void registerRoutes() {}
}

Future<(int, String)> _get(int port, String path) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
    final res = await req.close();
    final body = await res.transform(const SystemEncoding().decoder).join();
    return (res.statusCode, body);
  } finally {
    client.close(force: true);
  }
}

void main() {
  // 与 hub_http_smoke_test 保持一致：不初始化 TestWidgetsFlutterBinding，
  // 否则它装的 HttpOverrides 会拦截所有真实 HTTP 请求。
  late Directory dir;
  late _TestHttpService svc;
  late int port;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kostori_bangumi_routes');
    App.dataPath = dir.path;
    svc = _TestHttpService();
    await svc.startServer(preferredPort: 47831, mode: BindMode.ipv4);
    port = svc.port;
  });

  tearDown(() async {
    await svc.stopServer();
    await dir.delete(recursive: true);
  });

  test('番剧条目检索 / 详情截图接口已注册且标记为公开', () async {
    final (status, body) = await _get(port, '/openapi.json');
    expect(status, 200);

    final paths = (jsonDecode(body) as Map)['paths'] as Map;
    expect(paths.containsKey('/bangumi/search'), isTrue);
    expect(paths.containsKey('/bangumi/screenshot'), isTrue);

    // 公开接口的 security 为空数组（requiresAuth == false）
    for (final path in ['/bangumi/search', '/bangumi/screenshot']) {
      final op = ((paths[path] as Map)['get']) as Map;
      expect(op['security'], isEmpty, reason: '$path 应为公开接口');
    }
  });

  test('既有日历截图接口仍是需要鉴权的', () async {
    final (_, body) = await _get(port, '/openapi.json');
    final paths = (jsonDecode(body) as Map)['paths'] as Map;
    final op = ((paths['/bangumi/calendar/screenshot'] as Map)['get']) as Map;
    expect(op['security'], isNotEmpty);
  });

  test('/bangumi/search 缺少关键词返回 400 MISSING_KEYWORD', () async {
    final (status, body) = await _get(port, '/bangumi/search');
    expect(status, 400);
    expect(jsonDecode(body)['error'], 'MISSING_KEYWORD');
  });

  test('/bangumi/screenshot 两个参数都缺返回 400 MISSING_PARAM', () async {
    final (status, body) = await _get(port, '/bangumi/screenshot');
    expect(status, 400);
    expect(jsonDecode(body)['error'], 'MISSING_PARAM');
  });

  test('/bangumi/screenshot 非法 bangumiid 返回 400 INVALID_ID', () async {
    final (status, body) = await _get(
      port,
      '/bangumi/screenshot?bangumiid=abc',
    );
    expect(status, 400);
    expect(jsonDecode(body)['error'], 'INVALID_ID');

    final (zeroStatus, _) = await _get(port, '/bangumi/screenshot?bangumiid=0');
    expect(zeroStatus, 400);
  });

  test('公开接口在无 token 时不被 401 拦截', () async {
    // 不带任何 Authorization / X-Api-Key，也不经过 localBypass 的 Origin 校验：
    // 走 127.0.0.1 且无 Origin 头，若误挂鉴权中间件会拿到 401
    final (status, body) = await _get(port, '/bangumi/search');
    expect(status, isNot(401));
    // 走到了处理器内部，说明中间件确实放行
    expect(jsonDecode(body)['error'], 'MISSING_KEYWORD');
  });

  test('themeOverrideFromQuery 缺省返回 null', () {
    expect(svc.themeOverrideFromQuery(const {}), isNull);
    expect(svc.themeOverrideFromQuery(const {'mode': 'weekly'}), isNull);
  });

  test('themeOverrideFromQuery 接受明暗与主题色', () {
    expect(
      svc.themeOverrideFromQuery(const {'theme': 'dark'})?.brightness,
      Brightness.dark,
    );
    expect(
      svc.themeOverrideFromQuery(const {'theme': 'LIGHT'})?.brightness,
      Brightness.light,
    );
    expect(svc.themeOverrideFromQuery(const {'seed': '#FF0000'}), isNotNull);
    expect(svc.themeOverrideFromQuery(const {'seed': 'teal'}), isNotNull);
  });
}
