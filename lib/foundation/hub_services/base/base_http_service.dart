part of 'package:kostori/foundation/hub_services/services.dart';

/// WebSocket 处理器：shelf_web_socket 升级后回调
typedef WsHandler = Future<void> Function(
  WebSocketChannel socket,
  shelf.Request request,
);

/// 把 dart:io 风格的 close code 映射到 web_socket_channel 允许的区间
/// （只接受 1000 或 3000-4999，否则底层会抛异常）。
void closeWebSocket(WebSocketChannel socket, [int? code, String? reason]) {
  final safe = (code == null || code == 1000 || (code >= 3000 && code <= 4999))
      ? code
      : code + 3000;
  try {
    socket.sink.close(safe, reason);
  } catch (_) {}
}

abstract class BaseHttpService implements BaseService {
  final _binder = ServerBinder();
  final _router = RouteRegistry();

  bool _hubNoAuth = false;

  int get port => _binder.port;

  bool get isRunning => _binder.isRunning;

  bool get isSecure => _binder.isSecure;

  List<String> get boundAddresses => _binder.boundAddresses;

  List<String> get boundWsAddresses => _binder.boundWsAddresses;

  bool get hubNoAuth => _hubNoAuth;

  final _startTime = DateTime.now();

  static const _portKey = 'service_port';
  static const _bindModeKey = 'service_bind_mode';

  static const _hubPortKey = 'hub_port';
  static const _hubBindModeKey = 'hub_bind_mode';

  static const _hubNoAuthKey = 'hub_no_auth';

  // ── TLS 配置键（Hub 服务端）───────────────────────────────
  static const _tlsEnabledKey = 'hub_tls_enabled';
  static const _tlsCertKey = 'hub_tls_cert_path';
  static const _tlsKeyKey = 'hub_tls_key_path';
  static const _tlsPasswordKey = 'hub_tls_password';

  /// Hub 是否启用 HTTPS/WSS
  bool get tlsEnabled => appdata.implicitData[_tlsEnabledKey] as bool? ?? false;

  String? get tlsCertificatePath =>
      appdata.implicitData[_tlsCertKey] as String?;

  String? get tlsPrivateKeyPath => appdata.implicitData[_tlsKeyKey] as String?;

  String? get tlsPassword => appdata.implicitData[_tlsPasswordKey] as String?;

  void setTlsEnabled(bool v) {
    appdata.implicitData[_tlsEnabledKey] = v;
    appdata.writeImplicitData();
  }

  void setTlsCertificatePath(String? p) {
    if (p == null || p.isEmpty) {
      appdata.implicitData.remove(_tlsCertKey);
    } else {
      appdata.implicitData[_tlsCertKey] = p;
    }
    appdata.writeImplicitData();
  }

  void setTlsPrivateKeyPath(String? p) {
    if (p == null || p.isEmpty) {
      appdata.implicitData.remove(_tlsKeyKey);
    } else {
      appdata.implicitData[_tlsKeyKey] = p;
    }
    appdata.writeImplicitData();
  }

  void setTlsPassword(String? p) {
    if (p == null || p.isEmpty) {
      appdata.implicitData.remove(_tlsPasswordKey);
    } else {
      appdata.implicitData[_tlsPasswordKey] = p;
    }
    appdata.writeImplicitData();
  }

  /// 当前 TLS 配置是否完整（证书+私钥已填）
  bool get tlsConfigured =>
      (tlsCertificatePath?.isNotEmpty ?? false) &&
      (tlsPrivateKeyPath?.isNotEmpty ?? false);

  Duration get pingInterval => Duration(
    milliseconds:
        appdata.implicitData['hub_service_ping_interval'] as int? ?? 30000,
  );

  void setPingInterval(int milliseconds) {
    appdata.implicitData['hub_service_ping_interval'] = milliseconds;
    appdata.writeImplicitData();
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
  final Map<String, Set<WebSocketChannel>> _wsClients = {};

  void addWs(String path, WsHandler handler) {
    _wsRoutes[path] = handler;
  }

  void _addWsClient(String path, WebSocketChannel socket) {
    _wsClients.putIfAbsent(path, () => {}).add(socket);
    socket.sink.done.then((_) => _wsClients[path]?.remove(socket));
  }

  void broadcastWs(String path, dynamic data) {
    final clients = _wsClients[path] ?? {};
    final message = data is String ? data : jsonEncode(data);
    for (final client in clients.toList()) {
      try {
        client.sink.add(message);
      } catch (_) {
        _wsClients[path]?.remove(client);
      }
    }
  }

  /// 为某个 WS 路径构建 shelf 处理器（升级时回调 [WsHandler]）
  shelf.Handler _wsShelfHandler(String path, shelf.Request raw) {
    final handler = _wsRoutes[path]!;
    return webSocketHandler((WebSocketChannel channel, String? protocol) {
      unawaited(handler(channel, raw));
    }, pingInterval: pingInterval);
  }

  // 对外连接的 WebSocket 客户端
  final Map<String, WebSocketChannel> _wsConnections = {};

  /// 主动连接另一个 WebSocket 服务
  Future<WebSocketChannel?> connectTo(
    String url, {
    void Function(dynamic data)? onMessage,
    void Function()? onDone,
    void Function(dynamic error)? onError,
    Duration reconnectDelay = const Duration(seconds: 5),
    bool autoReconnect = true,
    Map<String, dynamic>? headers,
  }) async {
    // 日志中的 URL 去掉 token 等敏感参数
    String safeUrl() {
      try {
        final uri = Uri.parse(url);
        final params = Map<String, String>.from(uri.queryParameters);
        if (params.isNotEmpty) {
          for (final k in params.keys) {
            params[k] = '***';
          }
          return uri.replace(queryParameters: params).toString();
        }
      } catch (_) {}
      return url;
    }

    try {
      HubLog.info('$runtimeType', '🔌 连接到 ${safeUrl()}');
      final channel = IOWebSocketChannel.connect(
        url,
        headers: headers,
        connectTimeout: const Duration(seconds: 10),
      );
      await channel.ready;
      _wsConnections[url] = channel;

      channel.stream.listen(
        (data) => onMessage?.call(data),
        onDone: () async {
          HubLog.info('$runtimeType', '🔌 断开连接：${safeUrl()}');
          _wsConnections.remove(url);
          onDone?.call();

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
              headers: headers,
            );
          }
        },
        onError: (e) {
          HubLog.error('$runtimeType', '连接错误：$e');
          onError?.call(e);
        },
      );

      HubLog.info('$runtimeType', '✅ 已连接到 ${safeUrl()}');
      return channel;
    } catch (e) {
      HubLog.error('$runtimeType', '连接失败：${safeUrl()}  $e');
      if (autoReconnect) {
        await Future.delayed(reconnectDelay);
        return connectTo(
          url,
          onMessage: onMessage,
          autoReconnect: autoReconnect,
          headers: headers,
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
    socket.sink.add(data is String ? data : jsonEncode(data));
  }

  /// 断开指定连接
  Future<void> disconnectFrom(String url) async {
    await _wsConnections[url]?.sink.close();
    _wsConnections.remove(url);
  }

  // ── 子类实现 ──────────────────────────────────
  void registerRoutes();

  // ── WebSocket 鉴权工具 ────────────────────────
  /// 从 WebSocket 请求中提取 token 并校验
  bool _validateWsToken(shelf.Request req, {bool admin = false}) {
    final token = req.requestedUri.queryParameters['token'];
    if (token == null) return false;
    return admin
        ? ApiKeyManager().validateAdmin(token)
        : ApiKeyManager().validate(token);
  }

  // ── 公共路由 ──────────────────────────────────
  void _registerCommonRoutes() {
    addGet(
      '/hello',
      (req, params) => sendAuto(req, {
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
      (req, params) async {
        final bytes = await rootBundle.load('images/app_icon.png');
        return sendImage(req, bytes.buffer.asUint8List());
      },
      doc: RouteDoc(summary: '应用图标', description: '返回应用图标', response: '图片 PNG'),
    );

    addGet(
      '/bangumi/calendar/screenshot',
      (req, params) async {
        final String mode;
        try {
          mode = req.requestedUri.queryParameters['mode'] ?? 'weekly';
        } on FormatException catch (e) {
          return sendError(
            req,
            HttpStatus.badRequest,
            'INVALID_QUERY',
            'Invalid query string: ${e.message}',
          );
        }
        final showWeekly = mode != 'today';

        try {
          final calendar = await loadBangumiCalendar();
          // 需要一个 BuildContext 来渲染截图，这里复用应用的 navigator 上下文
          final context = App.mainNavigatorKey?.currentContext;
          if (context == null) {
            return sendError(
              req,
              HttpStatus.serviceUnavailable,
              'NO_CONTEXT',
              'Flutter context not available',
            );
          }
          if (!context.mounted) {
            return sendError(
              req,
              HttpStatus.serviceUnavailable,
              'NO_CONTEXT',
              'Flutter context not available',
            );
          }
          final bytes = await generateBangumiCalendarPng(
            context: context,
            bangumiCalendar: calendar,
            captureTime: DateTime.now(),
            showWeekly: showWeekly,
          );

          if (bytes == null) {
            return sendError(
              req,
              HttpStatus.internalServerError,
              'CAPTURE_FAILED',
              'Failed to generate screenshot',
            );
          }

          return sendImage(req, bytes);
        } catch (e, s) {
          HubLog.error('$runtimeType', '生成番剧时间表截图失败: $e\n$s');
          return sendError(
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
      (req, params) {
        final uptime = DateTime.now().difference(_startTime);
        return sendJson(req, {
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
      (req, params) => sendAuto(req, {
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
      (req, params) => sendJson(req, {'routes': _router.registeredRoutes()}),
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
      (req, params) {
        final host = req.headers['host'] ?? 'localhost:$port';
        final scheme = req.headers['x-forwarded-proto'] ?? 'http';
        return sendJson(req, _buildOpenApi(baseUrl: '$scheme://$host'));
      },
      doc: RouteDoc(
        summary: 'OpenAPI 文档',
        description: '返回标准 OpenAPI 3.0 格式的接口文档',
        response: 'JSON: OpenAPI 3.0',
      ),
    );

    addGet(
      '/docs',
      (req, params) => sendHtml(req, _buildDocsHtml()),
      doc: RouteDoc(
        summary: 'Swagger UI',
        description: '在浏览器中查看接口文档',
        response: 'HTML',
      ),
    );

    // ── WebSocket：日志推送（管理层鉴权） ──────
    addWs('/logs/ws', (socket, req) async {
      if (!_validateWsToken(req, admin: true)) {
        closeWebSocket(socket, WebSocketStatus.policyViolation, 'Unauthorized');
        return;
      }

      _addWsClient('/logs/ws', socket);

      for (final entry in Log.logs) {
        try {
          socket.sink.add(
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
          socket.sink.add(
            jsonEncode({
              'level': entry.level.name,
              'title': entry.title,
              'message': entry.content,
              'time': entry.time.toIso8601String(),
            }),
          );
        } catch (_) {}
      });

      await socket.sink.done;
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
    HubLog.info(
      '$runtimeType',
      '🔑 用户层 Key：${SecretVault.mask(ApiKeyManager().activeKey)}',
    );
    HubLog.info(
      '$runtimeType',
      '🔐 管理层 Key：${SecretVault.mask(ApiKeyManager().adminActiveKey)}',
    );
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
    HubLog.info(
      '$runtimeType',
      '🔑 用户层 Key：${SecretVault.mask(ApiKeyManager().activeKey)}',
    );
    HubLog.info(
      '$runtimeType',
      '🔐 管理层 Key：${SecretVault.mask(ApiKeyManager().adminActiveKey)}',
    );
  }

  Future<void> stopServer() async {
    for (final socket in _wsConnections.values) {
      try {
        await socket.sink.close();
      } catch (_) {}
    }
    _wsConnections.clear();

    for (final clients in _wsClients.values) {
      for (final client in clients.toList()) {
        closeWebSocket(client);
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
  shelf.Handler? _corsPipeline;

  Future<shelf.Response> _handleRequest(shelf.Request request) {
    _corsPipeline ??= Middleware.cors()(_dispatch);
    return Future.sync(() => _corsPipeline!(request));
  }

  String _remoteAddressOf(shelf.Request request) =>
      (request.context['shelf.io.connection_info'] as HttpConnectionInfo?)
          ?.remoteAddress
          .address ??
      '?';

  Future<shelf.Response> _dispatch(shelf.Request request) async {
    final path = request.requestedUri.path;

    // WebSocket 路由优先（webSocketHandler 内部会校验升级头）
    if (_wsRoutes.containsKey(path)) {
      return await _wsShelfHandler(path, request)(request);
    }

    try {
      final limit = await Middleware.bodySizeLimit()(request);
      if (limit != null) return limit;

      final method = request.method;
      final from = _remoteAddressOf(request);
      final watch = Stopwatch()..start();

      if (method == 'PROPFIND') {
        return sendJson(request, {
          'error': 'Method Not Allowed',
          'message': 'WebDAV is not supported',
        }, status: HttpStatus.methodNotAllowed);
      }

      HubLog.info('$runtimeType', '→ $method $path  (from $from)');
      final match = _router.resolve(method, path);

      if (match == null) {
        return sendError(
          request,
          HttpStatus.notFound,
          'NOT_FOUND',
          'path $path not found',
        );
      }

      for (final middleware in match.entry.middlewares) {
        final response = await middleware(request);
        if (response != null) return response;
      }

      final response = await match.entry.handler(request, match.params);

      watch.stop();
      HubLog.info(
        '$runtimeType',
        '← $method $path  ${watch.elapsedMilliseconds}ms',
      );
      return response;
    } catch (e, stack) {
      HubLog.error('$runtimeType', '❌ $e\n$stack');
      return sendError(
        request,
        HttpStatus.internalServerError,
        'SERVER_ERROR',
        e.toString(),
      );
    }
  }

  // ── 响应工具 ──────────────────────────────────
  shelf.Response sendJson(
    shelf.Request req,
    Object? data, {
    int status = HttpStatus.ok,
  }) => shelf.Response(
    status,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json'},
  );

  /// 发送 HTML 页面
  shelf.Response sendHtml(
    shelf.Request req,
    String html, {
    int status = HttpStatus.ok,
  }) => shelf.Response(
    status,
    body: html,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );

  shelf.Response sendBytes(
    shelf.Request req,
    List<int> bytes,
    ContentType contentType,
  ) => shelf.Response(
    HttpStatus.ok,
    body: bytes,
    headers: {'content-type': contentType.toString()},
  );

  shelf.Response sendImage(
    shelf.Request req,
    Uint8List bytes, {
    String format = 'png',
  }) => sendBytes(req, bytes, ContentType('image', format));

  shelf.Response sendFile(
    shelf.Request req,
    List<int> bytes,
    String filename, {
    String mimeType = 'application/octet-stream',
  }) => shelf.Response(
    HttpStatus.ok,
    body: bytes,
    headers: {
      'content-type': mimeType,
      'content-disposition': 'attachment; filename="$filename"',
    },
  );

  shelf.Response sendAuto(
    shelf.Request req,
    Map<String, dynamic> data, {
    int status = HttpStatus.ok,
    String? htmlBody,
  }) {
    final accept = req.headers['accept'] ?? '';
    if (accept.contains('text/html') && htmlBody != null) {
      return sendHtml(req, htmlBody, status: status);
    }
    return sendJson(req, data, status: status);
  }

  shelf.Response sendError(
    shelf.Request req,
    int status,
    String error,
    String message,
  ) => sendJson(req, {
    'code': status,
    'error': error,
    'message': message,
    'path': req.requestedUri.path,
    'timestamp': DateTime.now().toIso8601String(),
  }, status: status);

  // ── 请求体解析 ────────────────────────────────
  Future<Map<String, dynamic>?> readJson(shelf.Request req) async {
    try {
      final body = await req.readAsString();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String> readBody(shelf.Request req) => req.readAsString();

  // ── 静态文件 ──────────────────────────────────
  void serveStatic(String urlPrefix, String dirPath) {
    addGet('$urlPrefix/:filename', (req, params) async {
      final filename = params['filename'] ?? '';
      // 防目录穿越：拒绝路径分隔符、空名与绝对路径
      if (filename.isEmpty ||
          filename.contains('..') ||
          filename.contains('/') ||
          filename.contains('\\') ||
          filename.startsWith('.')) {
        return sendError(
          req,
          HttpStatus.badRequest,
          'INVALID_FILENAME',
          'Invalid filename',
        );
      }
      final file = File(p.join(dirPath, filename));

      if (!await file.exists()) {
        return sendError(
          req,
          HttpStatus.notFound,
          'NOT_FOUND',
          'File not found',
        );
      }

      final bytes = await file.readAsBytes();
      return sendBytes(req, bytes, ContentType.parse(_getMimeType(filename)));
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
