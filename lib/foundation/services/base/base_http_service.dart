part of 'package:kostori/foundation/services/services.dart';

typedef WsHandler =
    Future<void> Function(WebSocket socket, HttpRequest request);

abstract class BaseHttpService implements BaseService {
  final _binder = ServerBinder();
  final _router = RouteRegistry();

  int get port => _binder.port;

  bool get isRunning => _binder.isRunning;

  List<String> get boundAddresses => _binder.boundAddresses;

  final _startTime = DateTime.now();

  // ── 鉴权中间件快捷方式 ────────────────────────
  MiddlewareHandler get authMiddleware =>
      Middleware.localBypass(Middleware.apiKey());

  // ── WebSocket ─────────────────────────────────
  final Map<String, WsHandler> _wsRoutes = {};
  final Map<String, Set<WebSocket>> _wsClients = {};
  final Map<HttpRequest, Map<String, String>> _paramsStore = {};

  void addWs(String path, WsHandler handler) {
    _wsRoutes[path] = handler;
  }

  void _addWsClient(String path, WebSocket socket) {
    _wsClients.putIfAbsent(path, () => {}).add(socket);
    socket.done.then((_) => _wsClients[path]?.remove(socket));
  }

  void broadcastWs(String path, dynamic data) {
    final clients = _wsClients[path] ?? {};
    final message = data is String ? data : jsonEncode(data);
    for (final client in clients.toList()) {
      try {
        client.add(message);
      } catch (_) {
        _wsClients[path]?.remove(client);
      }
    }
  }

  // 对外连接的 WebSocket 客户端
  final Map<String, WebSocket> _wsConnections = {};

  /// 主动连接另一个 WebSocket 服务
  Future<WebSocket?> connectTo(
    String url, {
    void Function(dynamic data)? onMessage,
    void Function()? onDone,
    void Function(dynamic error)? onError,
    Duration reconnectDelay = const Duration(seconds: 5),
    bool autoReconnect = true,
  }) async {
    try {
      Log.info('$runtimeType', '🔌 连接到 $url');
      final socket = await WebSocket.connect(url);
      _wsConnections[url] = socket;

      socket.listen(
        (data) => onMessage?.call(data),
        onDone: () async {
          Log.info('$runtimeType', '🔌 断开连接：$url');
          _wsConnections.remove(url);
          onDone?.call();

          // 自动重连
          if (autoReconnect) {
            Log.info('$runtimeType', '🔄 ${reconnectDelay.inSeconds}s 后重连...');
            await Future.delayed(reconnectDelay);
            await connectTo(
              url,
              onMessage: onMessage,
              onDone: onDone,
              onError: onError,
              reconnectDelay: reconnectDelay,
              autoReconnect: autoReconnect,
            );
          }
        },
        onError: (e) {
          Log.error('$runtimeType', '连接错误：$e');
          onError?.call(e);
        },
      );

      Log.info('$runtimeType', '✅ 已连接到 $url');
      return socket;
    } catch (e) {
      Log.error('$runtimeType', '连接失败：$url  $e');
      if (autoReconnect) {
        await Future.delayed(reconnectDelay);
        return connectTo(
          url,
          onMessage: onMessage,
          autoReconnect: autoReconnect,
        );
      }
      return null;
    }
  }

  /// 向已连接的服务发送数据
  void sendTo(String url, dynamic data) {
    final socket = _wsConnections[url];
    if (socket == null) {
      Log.warning('$runtimeType', '⚠️ 未连接到 $url');
      return;
    }
    socket.add(data is String ? data : jsonEncode(data));
  }

  /// 断开指定连接
  Future<void> disconnectFrom(String url) async {
    await _wsConnections[url]?.close();
    _wsConnections.remove(url);
  }

  // ── 路由参数 ──────────────────────────────────
  void _injectParams(HttpRequest request, Map<String, String> params) {
    if (params.isNotEmpty) _paramsStore[request] = params;
  }

  Map<String, String> pathParams(HttpRequest request) {
    return _paramsStore.remove(request) ?? {};
  }

  // ── 子类实现 ──────────────────────────────────
  void registerRoutes();

  // ── 公共路由 ──────────────────────────────────
  void _registerCommonRoutes() {
    addGet(
      '/hello',
      (req) => sendAuto(req, {
        'message': 'Hello World',
        'port': port,
        'bound': boundAddresses,
        'timestamp': DateTime.now().toIso8601String(),
      }),
      doc: RouteDoc(
        summary: '连通性测试',
        description: '测试服务是否正常运行',
        response: 'JSON: message, port, bound, timestamp',
      ),
    );

    addGet(
      '/icon',
      (req) async {
        final bytes = await rootBundle.load('images/app_icon.png');
        await sendImage(req, bytes.buffer.asUint8List());
      },
      doc: RouteDoc(summary: '应用图标', description: '返回应用图标', response: '图片 PNG'),
    );

    addGet(
      '/health',
      (req) async {
        final uptime = DateTime.now().difference(_startTime);
        await sendJson(req, {
          'status': 'ok',
          'uptime':
              '${uptime.inHours}h '
              '${uptime.inMinutes.remainder(60)}m '
              '${uptime.inSeconds.remainder(60)}s',
          'uptimeSeconds': uptime.inSeconds,
          'port': port,
          'bound': boundAddresses,
          'timestamp': DateTime.now().toIso8601String(),
        });
      },
      doc: RouteDoc(
        summary: '健康检查',
        description: '返回服务运行时长和状态',
        response: 'JSON: status, uptime, uptimeSeconds, port, bound, timestamp',
      ),
    );

    addGet(
      '/status',
      (req) => sendAuto(req, {
        'running': isRunning,
        'port': port,
        'mode': runtimeType.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      }),
      middlewares: [authMiddleware],
      doc: RouteDoc(
        summary: '服务状态',
        description: '返回当前服务运行状态',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'token',
            type: 'query',
            description: 'API Key',
            required: true,
          ),
        ],
        response: 'JSON: running, port, mode, timestamp',
      ),
    );

    addGet(
      '/routes',
      (req) async {
        await sendJson(req, {'routes': _router.registeredRoutes()});
      },
      middlewares: [authMiddleware],
      doc: RouteDoc(
        summary: '路由列表',
        description: '返回所有已注册的路由',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'token',
            type: 'query',
            description: 'API Key',
            required: true,
          ),
        ],
        response: 'JSON: routes[]',
      ),
    );

    addGet(
      '/openapi.json',
      (req) async {
        await sendJson(req, _buildOpenApi());
      },
      doc: RouteDoc(
        summary: 'OpenAPI 文档',
        description: '返回标准 OpenAPI 3.0 格式的接口文档',
        response: 'JSON: OpenAPI 3.0',
      ),
    );

    addGet(
      '/docs',
      (req) async {
        await sendAuto(req, {}, htmlBody: _buildDocsHtml());
      },
      doc: RouteDoc(
        summary: 'Swagger UI',
        description: '在浏览器中查看接口文档',
        response: 'HTML',
      ),
    );

    addWs('/logs/ws', (socket, req) async {
      final token = req.uri.queryParameters['token'];
      if (token == null || !ApiKeyManager().validate(token)) {
        await socket.close(WebSocketStatus.policyViolation, 'Unauthorized');
        return;
      }
      _addWsClient('/logs/ws', socket);

      for (final entry in Log.logs) {
        try {
          socket.add(
            jsonEncode({
              'level': entry.level.name,
              'title': entry.title,
              'message': entry.content,
              'time': entry.time.toIso8601String(),
            }),
          );
        } catch (_) {}
      }

      final sub = Log.stream.listen((entries) {
        final entry = entries.last;
        try {
          socket.add(
            jsonEncode({
              'level': entry.level.name,
              'title': entry.title,
              'message': entry.content,
              'time': entry.time.toIso8601String(),
            }),
          );
        } catch (_) {}
      });

      await socket.done;
      await sub.cancel();
      _wsClients['/logs/ws']?.remove(socket);
    });
  }

  Map<String, dynamic> _buildOpenApi() {
    final routes = _router.registeredRoutes();
    final paths = <String, dynamic>{};

    for (final route in routes) {
      final path = (route['path'] as String).replaceAllMapped(
        RegExp(r':(\w+)'),
        (m) => '{${m.group(1)}}',
      );
      final method = (route['method'] as String).toLowerCase();
      final doc = route['doc'] as Map<String, dynamic>?;

      paths.putIfAbsent(path, () => {})[method] = {
        'summary': doc?['summary'] ?? path,
        'description': doc?['description'] ?? '',
        'parameters': doc?['params'] ?? [],
        'security': doc?['requiresAuth'] == true
            ? [
                {'ApiKeyAuth': []},
              ]
            : [],
        'responses': {
          '200': {'description': doc?['response'] ?? 'Success'},
          '401': {'description': 'Unauthorized'},
          '404': {'description': 'Not Found'},
        },
      };
    }

    // 加上 WebSocket 路由
    for (final wsPath in _wsRoutes.keys) {
      final path = wsPath;
      paths.putIfAbsent(path, () => {})['get'] = {
        'summary': 'WebSocket: $wsPath',
        'description': 'WebSocket connection endpoint',
        'parameters': [
          {
            'name': 'token',
            'in': 'query',
            'description': 'API Key',
            'required': true,
          },
        ],
        'responses': {
          '101': {'description': 'WebSocket Upgrade'},
          '401': {'description': 'Unauthorized'},
        },
      };
    }

    return {
      'openapi': '3.0.0',
      'info': {
        'title': 'Kostori API',
        'version': App.version,
        'description': 'Kostori 本地服务 API.',
      },
      'servers': [
        {'url': 'http://localhost:$port'},
      ],
      'components': {
        'securitySchemes': {
          'ApiKeyAuth': {'type': 'apiKey', 'in': 'query', 'name': 'token'},
        },
      },
      'paths': paths,
    };
  }

  String _buildDocsHtml() {
    return '''<!DOCTYPE html>
<html>
<head>
  <title>Kostori API</title>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="icon" href="/icon" type="image/png">
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist/swagger-ui.css">
</head>
<body>
<div id="swagger-ui"></div>
<script src="https://unpkg.com/swagger-ui-dist/swagger-ui-bundle.js"></script>
<script>
  SwaggerUIBundle({
    url: '/openapi.json',
    dom_id: '#swagger-ui',
    presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
    layout: 'BaseLayout',
    deepLinking: true,
  });
</script>
</body>
</html>''';
  }

  // ── 启动 / 停止 ───────────────────────────────
  Future<void> startServer({
    int preferredPort = 9000,
    BindMode mode = BindMode.both,
  }) async {
    if (isRunning) return;
    _registerCommonRoutes();
    registerRoutes();
    await _binder.bind(preferredPort, mode, _handleRequest);
    Log.info('$runtimeType', '✅ 启动完成：${boundAddresses.join(' | ')}');
    Log.info('$runtimeType', '🔑 API Key：${ApiKeyManager().activeKey}');
  }

  Future<void> startServerSecure({
    int preferredPort = 9443,
    BindMode mode = BindMode.ipv4,
    required String certificatePath,
    required String privateKeyPath,
    String password = '',
  }) async {
    if (isRunning) return;
    _registerCommonRoutes();
    registerRoutes();
    await _binder.bindSecure(
      preferredPort,
      mode,
      _handleRequest,
      certificatePath: certificatePath,
      privateKeyPath: privateKeyPath,
      password: password,
    );
    Log.info('$runtimeType', '🔒 HTTPS 启动完成：${boundAddresses.join(' | ')}');
  }

  Future<void> stopServer() async {
    // 断开所有对外连接
    for (final socket in _wsConnections.values) {
      await socket.close();
    }
    _wsConnections.clear();

    // 关闭所有接入连接
    for (final clients in _wsClients.values) {
      for (final client in clients.toList()) {
        // ← 加 .toList()
        await client.close();
      }
    }
    _wsClients.clear();

    await _binder.close();
    Log.info('$runtimeType', '🛑 已停止');
  }

  // ── 路由注册 ──────────────────────────────────
  void addGet(
    String path,
    RouteHandler handler, {
    List<MiddlewareHandler> middlewares = const [],
    RouteDoc? doc,
  }) => _router.addGet(path, handler, middlewares: middlewares, doc: doc);

  void addPost(
    String path,
    RouteHandler handler, {
    List<MiddlewareHandler> middlewares = const [],
    RouteDoc? doc,
  }) => _router.addPost(path, handler, middlewares: middlewares, doc: doc);

  void addPut(
    String path,
    RouteHandler handler, {
    List<MiddlewareHandler> middlewares = const [],
    RouteDoc? doc,
  }) => _router.addPut(path, handler, middlewares: middlewares, doc: doc);

  void addDelete(
    String path,
    RouteHandler handler, {
    List<MiddlewareHandler> middlewares = const [],
    RouteDoc? doc,
  }) => _router.addDelete(path, handler, middlewares: middlewares, doc: doc);

  // ── 请求处理 ──────────────────────────────────
  void _handleRequest(HttpRequest request) async {
    try {
      // CORS
      if (!await Middleware.cors()(request)) return;
      // 请求体大小限制
      if (!await Middleware.bodySizeLimit()(request)) return;

      final method = request.method;
      final path = request.uri.path;
      final from = request.connectionInfo?.remoteAddress.address ?? '?';
      final watch = Stopwatch()..start();

      Log.info(
        '$runtimeType',
        'isUpgrade=${WebSocketTransformer.isUpgradeRequest(request)}  path=$path',
      );

      // WebSocket 升级
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final wsHandler = _wsRoutes[path];
        if (wsHandler == null) {
          await sendJson(request, {
            'error': 'WebSocket path not found',
          }, status: HttpStatus.notFound);
          return;
        }
        Log.info('$runtimeType', '⚡ WS $path  (from $from)');
        final socket = await WebSocketTransformer.upgrade(request);
        await wsHandler(socket, request);
        return;
      }

      Log.info('$runtimeType', '→ $method $path  (from $from)');
      final match = _router.resolve(method, path);

      if (match == null) {
        await sendJson(request, {
          'error': 'Not Found',
          'path': path,
        }, status: HttpStatus.notFound);
        return;
      }

      for (final middleware in match.entry.middlewares) {
        if (!await middleware(request)) return;
      }

      _injectParams(request, match.params);
      await match.entry.handler(request);

      watch.stop();
      Log.info(
        '$runtimeType',
        '← $method $path  ${watch.elapsedMilliseconds}ms',
      );
    } catch (e, stack) {
      Log.error('$runtimeType', '❌ $e\n$stack');
      try {
        await sendJson(request, {
          'error': 'Internal Server Error',
          'message': e.toString(),
        }, status: HttpStatus.internalServerError);
      } catch (_) {}
    }
  }

  // ── 响应工具 ──────────────────────────────────
  Future<void> sendJson(
    HttpRequest req,
    Map<String, dynamic> data, {
    int status = HttpStatus.ok,
  }) async {
    final bytes = utf8.encode(jsonEncode(data));
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.set('Content-Length', bytes.length.toString())
      ..add(bytes);
    await req.response.close();
  }

  Future<void> sendBytes(
    HttpRequest req,
    List<int> bytes,
    ContentType contentType,
  ) async {
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = contentType
      ..headers.set('Content-Length', bytes.length.toString())
      ..add(bytes);
    await req.response.close();
  }

  Future<void> sendImage(
    HttpRequest req,
    Uint8List bytes, {
    String format = 'png',
  }) => sendBytes(req, bytes, ContentType('image', format));

  Future<void> sendFile(
    HttpRequest req,
    List<int> bytes,
    String filename, {
    String mimeType = 'application/octet-stream',
  }) async {
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.parse(mimeType)
      ..headers.set('Content-Disposition', 'attachment; filename="$filename"')
      ..headers.set('Content-Length', bytes.length.toString())
      ..add(bytes);
    await req.response.close();
  }

  Future<void> sendAuto(
    HttpRequest req,
    Map<String, dynamic> data, {
    int status = HttpStatus.ok,
    String? htmlBody,
  }) async {
    final accept = req.headers.value('accept') ?? '';
    if (accept.contains('text/html') && htmlBody != null) {
      final bytes = utf8.encode(htmlBody);
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.html
        ..headers.set('Content-Length', bytes.length.toString())
        ..add(bytes);
      await req.response.close();
    } else {
      await sendJson(req, data, status: status);
    }
  }

  // ── 请求体解析 ────────────────────────────────
  Future<Map<String, dynamic>?> readJson(HttpRequest req) async {
    try {
      final body = await utf8.decoder.bind(req).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      await sendJson(req, {
        'error': 'Invalid JSON body',
      }, status: HttpStatus.badRequest);
      return null;
    }
  }

  Future<String> readBody(HttpRequest req) => utf8.decoder.bind(req).join();

  // ── 静态文件 ──────────────────────────────────
  void serveStatic(String urlPrefix, String dirPath) {
    addGet('$urlPrefix/:filename', (req) async {
      final filename = pathParams(req)['filename'] ?? '';
      final file = File('$dirPath/$filename');

      if (!await file.exists()) {
        await sendJson(req, {
          'error': 'File not found',
        }, status: HttpStatus.notFound);
        return;
      }

      final bytes = await file.readAsBytes();
      await sendBytes(req, bytes, ContentType.parse(_getMimeType(filename)));
    });
  }

  String _getMimeType(String filename) {
    return switch (filename.split('.').last.toLowerCase()) {
      'html' => 'text/html',
      'css' => 'text/css',
      'js' => 'application/javascript',
      'json' => 'application/json',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'svg' => 'image/svg+xml',
      'ico' => 'image/x-icon',
      _ => 'application/octet-stream',
    };
  }
}
