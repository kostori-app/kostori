part of 'package:kostori/foundation/hub_services/services.dart';

typedef WsHandler =
    Future<void> Function(WebSocket socket, HttpRequest request);

abstract class BaseHttpService implements BaseService {
  final _binder = ServerBinder();
  final _router = RouteRegistry();

  bool _hubNoAuth = false;

  int get port => _binder.port;

  bool get isRunning => _binder.isRunning;

  List<String> get boundAddresses => _binder.boundAddresses;

  bool get hubNoAuth => _hubNoAuth;

  final _startTime = DateTime.now();

  static const _portKey = 'service_port';
  static const _bindModeKey = 'service_bind_mode';

  static const _hubPortKey = 'hub_port';
  static const _hubBindModeKey = 'hub_bind_mode';

  static const _pingIntervalKey = 'hub_service_ping_interval';

  static const _hubNoAuthKey = 'hub_no_auth';

  Duration get pingInterval => Duration(
    milliseconds:
        appdata.settings['hub_service_ping_interval'] as int? ?? 30000,
  );

  void setPingInterval(int milliseconds) {
    appdata.settings[_pingIntervalKey] = milliseconds;
    appdata.saveData();
  }

  int get savedPort {
    return appdata.implicitData[_portKey] as int? ?? 9000;
  }

  int get savedHubPort {
    return appdata.implicitData[_hubPortKey] as int? ?? 9100;
  }

  BindMode get savedBindMode {
    final val = appdata.implicitData[_bindModeKey] as String?;
    return switch (val) {
      'ipv6' => BindMode.ipv6,
      'both' => BindMode.both,
      _ => BindMode.ipv4,
    };
  }

  BindMode get savedHubBindMode {
    final val = appdata.implicitData[_hubBindModeKey] as String?;
    return switch (val) {
      'ipv6' => BindMode.ipv6,
      'both' => BindMode.both,
      _ => BindMode.ipv4,
    };
  }

  void savePort(int port) {
    appdata.implicitData[_portKey] = port;
    appdata.writeImplicitData();
  }

  void saveHubPort(int port) {
    appdata.implicitData[_hubPortKey] = port;
    appdata.writeImplicitData();
  }

  void saveServiceBindMode(BindMode mode) {
    appdata.implicitData[_bindModeKey] = mode.name;
    appdata.writeImplicitData();
  }

  void saveHubBindMode(BindMode mode) {
    appdata.implicitData[_hubBindModeKey] = mode.name;
    appdata.writeImplicitData();
  }

  void setHubNoAuth(bool val) {
    _hubNoAuth = val;
    appdata.implicitData[_hubNoAuthKey] = _hubNoAuth;
    appdata.writeImplicitData();
  }

  // ── 鉴权中间件快捷方式 ────────────────────────
  /// 用户层鉴权（本地免验）
  MiddlewareHandler get authMiddleware =>
      Middleware.localBypass(Middleware.auth());

  /// Hub 专用：根据开关决定是否需要鉴权
  List<MiddlewareHandler> get _hubAuthMiddleware =>
      _hubNoAuth ? [] : [authMiddleware];

  /// 管理层鉴权（不免验，任何来源都必须提供管理 Key）
  MiddlewareHandler get adminAuthMiddleware => Middleware.auth(admin: true);

  /// 管理层鉴权（本地免验版本）
  MiddlewareHandler get adminAuthLocalBypass =>
      Middleware.localBypass(Middleware.auth(admin: true));

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
      HubLog.info('$runtimeType', '🔌 连接到 $url');
      final socket = await WebSocket.connect(url);
      _wsConnections[url] = socket;

      socket.listen(
        (data) => onMessage?.call(data),
        onDone: () async {
          HubLog.info('$runtimeType', '🔌 断开连接：$url');
          _wsConnections.remove(url);
          onDone?.call();

          // 自动重连
          if (autoReconnect) {
            HubLog.info(
              '$runtimeType',
              '🔄 ${reconnectDelay.inSeconds}s 后重连...',
            );
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
          HubLog.error('$runtimeType', '连接错误：$e');
          onError?.call(e);
        },
      );

      HubLog.info('$runtimeType', '✅ 已连接到 $url');
      return socket;
    } catch (e) {
      HubLog.error('$runtimeType', '连接失败：$url  $e');
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
      HubLog.warning('$runtimeType', '⚠️ 未连接到 $url');
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

  // ── WebSocket 鉴权工具 ────────────────────────
  /// 从 WebSocket 请求中提取 token 并校验
  bool _validateWsToken(HttpRequest req, {bool admin = false}) {
    final token = req.uri.queryParameters['token'];
    if (token == null) return false;
    return admin
        ? ApiKeyManager().validateAdmin(token)
        : ApiKeyManager().validate(token);
  }

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
      '/bangumi/calendar/screenshot',
      (req) async {
        String mode = 'weekly';
        try {
          mode = req.uri.queryParameters['mode'] ?? 'weekly';
        } on FormatException catch (e) {
          await sendError(
            req,
            HttpStatus.badRequest,
            'INVALID_QUERY',
            'Invalid query string: ${e.message}',
          );
          return;
        }
        final showWeekly = mode != 'today';

        // 需要一个 BuildContext 来渲染截图，这里复用应用的 navigator 上下文
        final context = App.mainNavigatorKey?.currentContext;
        if (context == null) {
          await sendError(
            req,
            HttpStatus.serviceUnavailable,
            'NO_CONTEXT',
            'Flutter context not available',
          );
          return;
        }

        try {
          final calendar = await loadBangumiCalendar();
          final bytes = await generateBangumiCalendarPng(
            context: context,
            bangumiCalendar: calendar,
            captureTime: DateTime.now(),
            showWeekly: showWeekly,
          );

          if (bytes == null) {
            await sendError(
              req,
              HttpStatus.internalServerError,
              'CAPTURE_FAILED',
              'Failed to generate screenshot',
            );
            return;
          }

          await sendImage(req, bytes);
        } catch (e, s) {
          HubLog.error('$runtimeType', '生成番剧时间表截图失败: $e\n$s');
          await sendError(
            req,
            HttpStatus.internalServerError,
            'SERVER_ERROR',
            e.toString(),
          );
        }
      },
      middlewares: [authMiddleware],
      doc: RouteDoc(
        summary: '番剧时间表截图',
        description: '返回番剧时间表截图，默认本周，可通过 ?mode=today 仅返回今天',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'Authorization',
            type: 'header',
            description: 'Bearer <user-key>',
            required: true,
          ),
          DocParam(
            name: 'mode',
            type: 'query',
            description: '截图模式：weekly（默认，整周）或 today（仅今天）',
            required: false,
          ),
        ],
        response: '图片 PNG',
      ),
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
        'authMode': ApiKeyManager().isUsingFixed ? 'fixed' : 'random',
        'adminAuthMode': ApiKeyManager().isUsingAdminFixed ? 'fixed' : 'random',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      middlewares: [authMiddleware],
      doc: RouteDoc(
        summary: '服务状态',
        description: '返回当前服务运行状态（需要用户层鉴权）',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'Authorization',
            type: 'header',
            description: 'Bearer <user-key>',
            required: true,
          ),
        ],
        response:
            'JSON: running, port, mode, authMode, adminAuthMode, timestamp',
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
        description: '返回所有已注册的路由（需要用户层鉴权）',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'Authorization',
            type: 'header',
            description: 'Bearer <user-key>',
            required: true,
          ),
        ],
        response: 'JSON: routes[]',
      ),
    );

    addGet(
      '/openapi.json',
      (req) async {
        final host = req.headers.value('host') ?? 'localhost:$port';
        final scheme = req.headers.value('x-forwarded-proto') ?? 'http';
        await sendJson(req, _buildOpenApi(baseUrl: '$scheme://$host'));
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
        final bytes = utf8.encode(_buildDocsHtml());
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..headers.set('Content-Length', bytes.length.toString())
          ..add(bytes);
        await req.response.close();
      },
      doc: RouteDoc(
        summary: 'Swagger UI',
        description: '在浏览器中查看接口文档',
        response: 'HTML',
      ),
    );

    // ── WebSocket：日志推送（管理层鉴权） ──────
    addWs('/logs/ws', (socket, req) async {
      if (!_validateWsToken(req, admin: true)) {
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

  Map<String, dynamic> _buildOpenApi({String? baseUrl}) {
    final routes = _router.registeredRoutes();
    final paths = <String, dynamic>{};

    for (final route in routes) {
      final path = (route['path'] as String).replaceAllMapped(
        RegExp(r':(\w+)'),
        (m) => '{${m.group(1)}}',
      );
      final method = (route['method'] as String).toLowerCase();
      final doc = route['doc'] as Map<String, dynamic>?;

      final requiresAuth = doc?['requiresAuth'] == true;
      final security = <Map<String, dynamic>>[];
      if (requiresAuth) {
        security.add({'BearerAuth': []});
      }

      paths.putIfAbsent(path, () => {})[method] = {
        'summary': doc?['summary'] ?? path,
        'description': doc?['description'] ?? '',
        'parameters': doc?['params'] ?? [],
        'security': security,
        'responses': {
          '200': {'description': doc?['response'] ?? 'Success'},
          '401': {'description': 'Unauthorized'},
          '404': {'description': 'Not Found'},
        },
      };
    }

    for (final wsPath in _wsRoutes.keys) {
      paths.putIfAbsent(wsPath, () => {})['get'] = {
        'summary': 'WebSocket: $wsPath',
        'description': 'WebSocket endpoint（通过 ?token= 传递 Key）',
        'parameters': [
          {
            'name': 'token',
            'in': 'query',
            'description': 'API Key（用户层或管理层）',
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
        'description':
            'Kostori 本地服务 API\n\n'
            '鉴权方式：\n'
            '- HTTP 接口：`Authorization: Bearer <key>`\n'
            '- WebSocket：`?token=<key>`\n\n'
            '权限分层：\n'
            '- 用户层 Key：访问一般接口\n'
            '- 管理层 Key：访问管理接口（日志、配置等）',
      },
      'servers': [
        {
          'url': baseUrl ?? 'http://localhost:$port',
          'description': 'Kostori Local Service',
        },
      ],
      'components': {
        'securitySchemes': {
          'BearerAuth': {
            'type': 'http',
            'scheme': 'bearer',
            'description': '用户层或管理层 API Key',
          },
        },
      },
      'paths': paths,
    };
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
    HubLog.info('$runtimeType', '✅ 启动完成：${boundAddresses.join(' | ')}');
    HubLog.info('$runtimeType', '🔑 用户层 Key：${ApiKeyManager().activeKey}');
    HubLog.info('$runtimeType', '🔐 管理层 Key：${ApiKeyManager().adminActiveKey}');
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
    HubLog.info('$runtimeType', '🔒 HTTPS 启动完成：${boundAddresses.join(' | ')}');
    HubLog.info('$runtimeType', '🔑 用户层 Key：${ApiKeyManager().activeKey}');
    HubLog.info('$runtimeType', '🔐 管理层 Key：${ApiKeyManager().adminActiveKey}');
  }

  Future<void> stopServer() async {
    for (final socket in _wsConnections.values) {
      await socket.close();
    }
    _wsConnections.clear();

    for (final clients in _wsClients.values) {
      for (final client in clients.toList()) {
        await client.close();
      }
    }
    _wsClients.clear();

    await _binder.close();
    HubLog.info('$runtimeType', '🛑 已停止');
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
      if (!await Middleware.cors()(request)) return;
      if (!await Middleware.bodySizeLimit()(request)) return;

      final method = request.method;
      final path = request.uri.path;
      final from = request.connectionInfo?.remoteAddress.address ?? '?';
      final watch = Stopwatch()..start();

      if (method == 'PROPFIND') {
        request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..headers.set('Allow', 'GET, POST, PUT, DELETE, OPTIONS')
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': 'Method Not Allowed',
              'message': 'WebDAV is not supported',
            }),
          );
        await request.response.close();
        return;
      }

      HubLog.info(
        '$runtimeType',
        'isUpgrade=${WebSocketTransformer.isUpgradeRequest(request)}  path=$path',
      );

      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final wsHandler = _wsRoutes[path];
        if (wsHandler == null) {
          await sendError(
            request,
            HttpStatus.notFound,
            'WS_NOT_FOUND',
            'WebSocket path $path not found',
          );
          return;
        }
        HubLog.info('$runtimeType', '⚡ WS $path  (from $from)');
        final socket = await WebSocketTransformer.upgrade(request);
        await wsHandler(socket, request);
        return;
      }

      HubLog.info('$runtimeType', '→ $method $path  (from $from)');
      final match = _router.resolve(method, path);

      if (match == null) {
        await sendError(
          request,
          HttpStatus.notFound,
          'NOT_FOUND',
          'path $path not found',
        );
        return;
      }

      for (final middleware in match.entry.middlewares) {
        if (!await middleware(request)) return;
      }

      _injectParams(request, match.params);
      await match.entry.handler(request);

      watch.stop();
      HubLog.info(
        '$runtimeType',
        '← $method $path  ${watch.elapsedMilliseconds}ms',
      );
    } catch (e, stack) {
      HubLog.error('$runtimeType', '❌ $e\n$stack');
      try {
        await sendError(
          request,
          HttpStatus.internalServerError,
          'SERVER_ERROR',
          e.toString(),
        );
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

  Future<void> sendError(
    HttpRequest req,
    int status,
    String error,
    String message,
  ) => sendJson(req, {
    'code': status,
    'error': error,
    'message': message,
    'path': req.uri.path,
    'timestamp': DateTime.now().toIso8601String(),
  }, status: status);

  // ── 请求体解析 ────────────────────────────────
  Future<Map<String, dynamic>?> readJson(HttpRequest req) async {
    try {
      final body = await utf8.decoder.bind(req).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      await sendError(
        req,
        HttpStatus.badRequest,
        'INVALID_JSON',
        'Invalid JSON body',
      );
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
        await sendError(
          req,
          HttpStatus.notFound,
          'NOT_FOUND',
          'File not found',
        );
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
