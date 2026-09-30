import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/hub_services/services.dart';

/// 管理后台新增集成接口的冒烟测试。
///
/// 重点验证「此前无法通过 HTTP 达成」的能力现在可达：
/// 上传配置写入、入站 Webhook 签发、Satori 档案、Key 轮换、消息检索。
class _AdminService extends HubWebAdminService {
  _AdminService(super.hub);
}

/// 探测端口是否有服务在监听，连不上返回 null
Future<int?> _probe(int port) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/'));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<T> _withAdmin<T>(
  Future<T> Function(int port, String adminKey) body, {
  required int port,
}) async {
  final dir = await Directory.systemTemp.createTemp('kostori_hub_admin');
  App.dataPath = dir.path;
  await ApiKeyManager().init();
  final hub = HubService.instance;
  await hub.init(preferredPort: port + 1, mode: BindMode.ipv4);
  final svc = _AdminService(hub);
  await svc.startServer(preferredPort: port, mode: BindMode.ipv4);
  try {
    return await body(svc.port, ApiKeyManager().adminActiveKey);
  } finally {
    await svc.stopServer();
    await hub.dispose();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// 非回环请求需要真实令牌（localBypass 不会放行 127.0.0.1 的恶意 Origin，
/// 这里直接带 Bearer，行为与远程调用一致）
Future<(int, Map<String, dynamic>?)> _call(
  int port,
  String method,
  String path, {
  required String adminKey,
  Object? body,
}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    req.headers.set('Authorization', 'Bearer $adminKey');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    final text = await res.transform(const SystemEncoding().decoder).join();
    if (text.isEmpty) return (res.statusCode, null);
    final decoded = jsonDecode(text);
    if (decoded is! Map) return (res.statusCode, null);
    return (res.statusCode, Map<String, dynamic>.from(decoded));
  } finally {
    client.close(force: true);
  }
}

/// appdata.implicitData 是静态 Map，改 App.dataPath 不会重置它，
/// 不清就会跨用例串状态（上一个用例配的 OSS / webhook 会漏进下一个）。
const _statefulKeys = <String>[
  'hub_upload_config',
  'hub_webhooks',
  'hub_outbound_webhooks',
  'hub_ws_bot_connections',
  'satori_bot_profiles',
  'hub_subscriptions',
  'lan_pin_enabled',
  'lan_pin_code',
  'service_port',
  'service_bind_mode',
  'hub_port',
  'hub_bind_mode',
  'hub_no_auth',
  'hub_web_admin_port',
  'hub_web_admin_bind_mode',
  'hub_admin_ids',
  'hub_blacklist',
];

void main() {
  // appdata.writeImplicitData() 会读 SchedulerBinding.instance，所以需要 binding；
  // 但 flutter_test 默认会装上 HttpOverrides 把所有 HttpClient 请求换成 mock
  // （一律返回 400），所以初始化后立刻关掉，换回真实 HTTP。
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  setUp(() {
    for (final key in _statefulKeys) {
      appdata.implicitData.remove(key);
    }
  });

  test('新增集成路由全部注册成功', () async {
    await _withAdmin((port, key) async {
      final (code, body) = await _call(
        port,
        'GET',
        '/api/admin/keys',
        adminKey: key,
      );
      expect(code, 200);
      // 打码而非明文
      expect(body!['userKey'], contains('*'));
      expect(body['usingFixedKey'], isA<bool>());
    }, port: 47881);
  });

  group('上传配置：此前只有 publicBaseUrl 可写', () {
    test('可写 mode / maxSizeBytes / localStorePath / publicBaseUrl', () async {
      await _withAdmin((port, key) async {
        final (code, body) = await _call(
          port,
          'POST',
          '/api/admin/upload',
          adminKey: key,
          body: {
            'maxSizeBytes': 8 * 1024 * 1024,
            'localStorePath': r'C:\kostori-uploads',
            'publicBaseUrl': 'http://example.test:9100',
          },
        );
        expect(code, 200, reason: '${body?['error']}');
        final config = body!['config'] as Map<String, dynamic>;
        expect(config['maxSizeBytes'], 8 * 1024 * 1024);
        expect(config['localStorePath'], r'C:\kostori-uploads');
        expect(config['publicBaseUrl'], 'http://example.test:9100');
      }, port: 47882);
    });

    test('OSS 密钥不回显，但写入后可保留', () async {
      await _withAdmin((port, key) async {
        final (c1, b1) = await _call(
          port,
          'POST',
          '/api/admin/upload',
          adminKey: key,
          body: {
            'mode': 'serverOss',
            'oss': {
              'endpoint': 'https://oss.example.test',
              'bucket': 'kostori',
              'accessKeyId': 'AKIA_TEST',
              'accessKeySecret': 'super-secret-value',
            },
          },
        );
        expect(c1, 200, reason: '${b1?['error']}');
        final oss = b1!['config']['oss'] as Map<String, dynamic>;
        expect(oss['bucket'], 'kostori');
        expect(oss['secretConfigured'], isTrue);
        expect(
          jsonEncode(oss),
          isNot(contains('super-secret-value')),
          reason: '密钥绝不能出现在响应里',
        );

        // 只改 bucket，留空密钥 → 应保留原值
        final (c2, b2) = await _call(
          port,
          'POST',
          '/api/admin/upload',
          adminKey: key,
          body: {
            'oss': {
              'endpoint': 'https://oss.example.test',
              'bucket': 'kostori-2',
              'accessKeyId': 'AKIA_TEST',
              'accessKeySecret': '',
            },
          },
        );
        expect(c2, 200);
        final oss2 = b2!['config']['oss'] as Map<String, dynamic>;
        expect(oss2['bucket'], 'kostori-2');
        expect(oss2['secretConfigured'], isTrue, reason: '留空应保留原密钥');
      }, port: 47883);
    });

    test('越界的 maxSizeBytes 与非法 mode 被拒', () async {
      await _withAdmin((port, key) async {
        final (c1, _) = await _call(
          port,
          'POST',
          '/api/admin/upload',
          adminKey: key,
          body: {'maxSizeBytes': 10},
        );
        expect(c1, 400);

        final (c2, _) = await _call(
          port,
          'POST',
          '/api/admin/upload',
          adminKey: key,
          body: {'mode': 'nonsense'},
        );
        expect(c2, 400);

        // serverOss 缺配置时不能保存
        final (c3, _) = await _call(
          port,
          'POST',
          '/api/admin/upload',
          adminKey: key,
          body: {'mode': 'serverOss', 'oss': null},
        );
        expect(c3, 400);
      }, port: 47884);
    });
  });

  group('入站 Webhook：addInbound 此前无调用方，/hub/webhook/:token 不可用', () {
    test('可签发令牌，签发后该令牌可向房间发消息', () async {
      await _withAdmin((port, key) async {
        final (code, body) = await _call(
          port,
          'POST',
          '/api/admin/webhooks',
          adminKey: key,
          body: {'name': 'CI 机器人', 'roomId': hubLobbyId},
        );
        expect(code, 200, reason: '${body?['error']}');
        final token =
            (body!['webhook'] as Map<String, dynamic>)['token'] as String;
        expect(token, isNotEmpty);

        // 现在这个令牌真的能打到 Hub 主服务的入站路由
        final hubPort = HubService.instance.port;
        final client = HttpClient();
        final res = await client.postUrl(
          Uri.parse('http://127.0.0.1:$hubPort/hub/webhook/$token'),
        );
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode({'text': '来自 webhook'}));
        final resp = await res.close();
        final text = await resp
            .transform(const SystemEncoding().decoder)
            .join();
        client.close(force: true);
        expect(resp.statusCode, 200, reason: text);
        expect(text, contains('sent'));

        // 列表可读回
        final (_, list) = await _call(
          port,
          'GET',
          '/api/admin/webhooks',
          adminKey: key,
        );
        expect(list!['count'], 1);
        expect((list['items'] as List)[0]['name'], 'CI 机器人');
      }, port: 47885);
    });

    test('删除后令牌失效', () async {
      await _withAdmin((port, key) async {
        final (_, created) = await _call(
          port,
          'POST',
          '/api/admin/webhooks',
          adminKey: key,
          body: {'name': '临时', 'roomId': hubLobbyId},
        );
        final id =
            (created!['webhook'] as Map<String, dynamic>)['id'] as String;
        final (delCode, delBody) = await _call(
          port,
          'DELETE',
          '/api/admin/webhooks/$id',
          adminKey: key,
        );
        expect(delCode, 200);
        expect(delBody!['deleted'], isTrue);

        final (_, list) = await _call(
          port,
          'GET',
          '/api/admin/webhooks',
          adminKey: key,
        );
        expect(list!['count'], 0);
      }, port: 47886);
    });

    test('房间不存在时拒绝签发', () async {
      await _withAdmin((port, key) async {
        final (code, _) = await _call(
          port,
          'POST',
          '/api/admin/webhooks',
          adminKey: key,
          body: {'name': 'x', 'roomId': 'no-such-room'},
        );
        expect(code, 400);
      }, port: 47887);
    });
  });

  group('Satori 机器人档案：此前无任何 HTTP 路由', () {
    test('可创建 / 更新 / 轮换令牌 / 删除', () async {
      await _withAdmin((port, key) async {
        final (c1, b1) = await _call(
          port,
          'POST',
          '/api/admin/satori-bots',
          adminKey: key,
          body: {'name': 'Koishi'},
        );
        expect(c1, 200, reason: '${b1?['error']}');
        final bot = b1!['bot'] as Map<String, dynamic>;
        final id = bot['id'] as String;
        final token = bot['token'] as String;
        expect(token, isNotEmpty);

        final (c2, b2) = await _call(
          port,
          'PUT',
          '/api/admin/satori-bots/$id',
          adminKey: key,
          body: {'name': 'Koishi 改名', 'enabled': false},
        );
        expect(c2, 200);
        expect((b2!['bot'] as Map)['name'], 'Koishi 改名');
        expect((b2['bot'] as Map)['enabled'], isFalse);
        // 更新不改令牌
        expect((b2['bot'] as Map)['token'], token);

        final (c3, b3) = await _call(
          port,
          'POST',
          '/api/admin/satori-bots/$id/rotate-token',
          adminKey: key,
        );
        expect(c3, 200);
        expect(b3!['token'], isNot(token));

        final (c4, _) = await _call(
          port,
          'DELETE',
          '/api/admin/satori-bots/$id',
          adminKey: key,
        );
        expect(c4, 200);
      }, port: 47888);
    });

    test('操作不存在的机器人返回 404', () async {
      await _withAdmin((port, key) async {
        final (c1, _) = await _call(
          port,
          'PUT',
          '/api/admin/satori-bots/satori-missing',
          adminKey: key,
          body: {'name': 'x'},
        );
        expect(c1, 404);
        final (c2, _) = await _call(
          port,
          'POST',
          '/api/admin/satori-bots/satori-missing/rotate-token',
          adminKey: key,
        );
        expect(c2, 404);
      }, port: 47889);
    });
  });

  group('API Key 轮换', () {
    test('轮换后旧用户 Key 失效、新 Key 生效', () async {
      await _withAdmin((port, key) async {
        final before = ApiKeyManager().activeKey;
        final (code, body) = await _call(
          port,
          'POST',
          '/api/admin/keys/rotate',
          adminKey: key,
        );
        expect(code, 200, reason: '${body?['error']}');
        expect(ApiKeyManager().activeKey, isNot(before));
        // 响应只回打码值，不回明文
        expect(body!['key'], contains('*'));

        // 管理 Key 不受影响，仍可调用
        final (c2, _) = await _call(
          port,
          'GET',
          '/api/admin/keys',
          adminKey: key,
        );
        expect(c2, 200);
      }, port: 47890);
    });
  });

  group('消息检索：/hub/search 与 /hub/pinned 挂在 9100，页面够不着', () {
    test('可在管理端口直接搜索与列出置顶', () async {
      await _withAdmin((port, key) async {
        final (code, body) = await _call(
          port,
          'GET',
          '/api/admin/search?q=kostori',
          adminKey: key,
        );
        expect(code, 200);
        expect(body!['keyword'], 'kostori');
        expect(body['results'], isA<List>());

        final (pcode, pbody) = await _call(
          port,
          'GET',
          '/api/admin/pinned',
          adminKey: key,
        );
        expect(pcode, 200);
        expect(pbody!['messages'], isA<List>());
      }, port: 47891);
    });

    test('缺少 q 返回 400', () async {
      await _withAdmin((port, key) async {
        final (code, _) = await _call(
          port,
          'GET',
          '/api/admin/search',
          adminKey: key,
        );
        expect(code, 400);
      }, port: 47892);
    });
  });

  group('日志：默认剔除请求访问日志', () {
    test('不带 access=1 时不含 HTTP 访问行，access=1 时含', () async {
      await _withAdmin((port, key) async {
        // 先打一次请求，确保产生了访问日志
        await _call(port, 'GET', '/api/admin/keys', adminKey: key);

        final (code, hidden) = await _call(
          port,
          'GET',
          '/api/admin/logs?limit=500',
          adminKey: key,
        );
        expect(code, 200);
        final titles = (hidden!['logs'] as List)
            .map((e) => e['title'])
            .toList();
        expect(
          titles,
          isNot(contains(BaseHttpService.accessLogTitle)),
          reason: '默认不该返回请求访问日志，否则管理页自己的轮询会刷满窗口',
        );

        final (_, shown) = await _call(
          port,
          'GET',
          '/api/admin/logs?limit=500&access=1',
          adminKey: key,
        );
        final shownTitles = (shown!['logs'] as List)
            .map((e) => e['title'])
            .toList();
        expect(shownTitles, contains(BaseHttpService.accessLogTitle));
      }, port: 47894);
    });
  });

  group('LAN 远程控制不在管理面板里', () {
    test('相关路由不存在', () async {
      await _withAdmin((port, key) async {
        for (final entry in {
          'GET': ['/api/admin/lan'],
          'POST': ['/api/admin/lan/pin'],
        }.entries) {
          for (final path in entry.value) {
            final (code, _) = await _call(
              port,
              entry.key,
              path,
              adminKey: key,
              body: entry.key == 'POST' ? <String, dynamic>{} : null,
            );
            expect(
              code,
              404,
              reason:
                  '$entry.key $path 不该存在：'
                  'LAN 控制是独立服务，PIN 由设置页负责',
            );
          }
        }
      }, port: 47893);
    });
  });

  group('管理后台页面与静态资源', () {
    test('/ 返回构建产物并引用 app.js / app.css', () async {
      await _withAdmin((port, key) async {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/'));
        final res = await req.close();
        final html = await res.transform(const SystemEncoding().decoder).join();
        expect(res.statusCode, 200, reason: '管理后台首页应可公开访问');
        expect(html, contains('./app.js'));
        expect(html, contains('./app.css'));
        expect(html, isNot(contains('hub_admin.html')), reason: '旧的单文件页面应已下线');
        // 管理页必须禁用缓存，否则升级后浏览器仍渲染旧页面
        expect(
          res.headers.value(HttpHeaders.cacheControlHeader),
          'no-store',
          reason: '管理页必须禁用缓存，否则升级后浏览器仍渲染旧页面',
        );
        client.close(force: true);
      }, port: 47896);
    });

    test('app.js / app.css 可访问且带正确 Content-Type', () async {
      await _withAdmin((port, key) async {
        final client = HttpClient();
        for (final entry in {
          '/app.js': 'text/javascript',
          '/app.css': 'text/css',
        }.entries) {
          final req = await client.getUrl(
            Uri.parse('http://127.0.0.1:$port${entry.key}'),
          );
          final res = await req.close();
          final body = await res
              .transform(const SystemEncoding().decoder)
              .join();
          expect(res.statusCode, 200, reason: '${entry.key} 应存在');
          expect(
            res.headers.contentType?.mimeType,
            entry.value,
            reason: '${entry.key} 的 MIME 不对，浏览器会拒绝执行',
          );
          expect(body, isNotEmpty);
        }
        client.close(force: true);
      }, port: 47897);
    });

    test('静态资源无需鉴权（登录页自身要能加载）', () async {
      await _withAdmin((port, _) async {
        final client = HttpClient();
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/app.js'),
        );
        final res = await req.close();
        await res.drain<void>();
        expect(res.statusCode, 200);
        client.close(force: true);
      }, port: 47898);
    });

    test('/admin 与 / 指向同一页面', () async {
      await _withAdmin((port, key) async {
        final client = HttpClient();
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/admin'),
        );
        final res = await req.close();
        final html = await res.transform(const SystemEncoding().decoder).join();
        expect(res.statusCode, 200);
        expect(html, contains('./app.js'));
        client.close(force: true);
      }, port: 47899);
    });
  });

  group('启停与端口立即生效', () {
    test('开启后立即可用；改端口经 restartWebAdmin 直接换端口', () async {
      final dir = await Directory.systemTemp.createTemp('kostori_hub_admin');
      App.dataPath = dir.path;
      await ApiKeyManager().init();
      final hub = HubService.instance;
      const portA = 47921;
      const portB = 47922;
      appdata.implicitData['hub_web_admin_enabled'] = true;
      appdata.implicitData['hub_web_admin_port'] = portA;
      appdata.implicitData['hub_web_admin_bind_mode'] = 'ipv4';
      appdata.writeImplicitData();
      try {
        await hub.init(preferredPort: 47920, mode: BindMode.ipv4);
        await hub.startWebAdmin();
        expect(await _probe(portA), 200, reason: '开启后应立刻在配置端口上服务，不存在需要重启的中间态');

        appdata.implicitData['hub_web_admin_port'] = portB;
        appdata.writeImplicitData();
        await hub.restartWebAdmin();
        expect(await _probe(portB), 200, reason: '端口改动应重绑后立即生效');
        expect(await _probe(portA), isNull, reason: '旧端口应已释放');
      } finally {
        await hub.stopWebAdmin();
        await hub.dispose();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });

    test('关闭后端口不再服务', () async {
      final dir = await Directory.systemTemp.createTemp('kostori_hub_admin');
      App.dataPath = dir.path;
      await ApiKeyManager().init();
      final hub = HubService.instance;
      const port = 47923;
      appdata.implicitData['hub_web_admin_enabled'] = true;
      appdata.implicitData['hub_web_admin_port'] = port;
      appdata.implicitData['hub_web_admin_bind_mode'] = 'ipv4';
      appdata.writeImplicitData();
      try {
        await hub.init(preferredPort: 47924, mode: BindMode.ipv4);
        expect(await _probe(port), 200);
        appdata.implicitData['hub_web_admin_enabled'] = false;
        appdata.writeImplicitData();
        await hub.startWebAdmin(); // 关闭态下调用应收敛为停止
        expect(await _probe(port), isNull, reason: '关闭应立即停止服务');
      } finally {
        await hub.stopWebAdmin();
        await hub.dispose();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  });

  group('鉴权分层', () {
    test('新接口全部要求管理层 Key', () async {
      await _withAdmin((port, _) async {
        final userKey = ApiKeyManager().activeKey;
        for (final entry in {
          'GET': [
            '/api/admin/upload',
            '/api/admin/webhooks',
            '/api/admin/satori-bots',
            '/api/admin/keys',
            '/api/admin/search?q=a',
            '/api/admin/pinned',
          ],
          'POST': [
            '/api/admin/upload',
            '/api/admin/webhooks',
            '/api/admin/satori-bots',
          ],
        }.entries) {
          for (final path in entry.value) {
            final (code, _) = await _call(
              port,
              entry.key,
              path,
              adminKey: userKey,
              body: entry.key == 'POST' ? <String, dynamic>{} : null,
            );
            expect(code, 401, reason: '$entry.key $path 不应接受用户层 Key');
          }
        }
      }, port: 47895);
    });
  });
}

/// 大厅房间 ID（HubService.instance 初始化后才有值）
String get hubLobbyId => HubService.instance.lobbyRoomId;
