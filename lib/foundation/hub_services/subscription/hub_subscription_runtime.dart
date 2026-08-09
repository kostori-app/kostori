part of 'package:kostori/foundation/hub_services/services.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  订阅运行时（HubSubscriptionService）
//  ═══════════════════════════════════════════════════════════════════════════
//  按订阅配置启动独立监听器 / 反向连接：
//   - ws forward：HttpServer 监听并升级为 WebSocket，token 鉴权 + 心跳，事件广播
//   - ws reverse：主动连接目标 WS，握手带 token + 心跳，事件推送
//   - webhook：向目标 URL POST 事件，Bearer token 鉴权头 + 心跳
//   - http：HttpServer 监听，token 鉴权，提供 /hello /health /message
//  事件统一由 [dispatch] 分发。

class HubSubscriptionService {
  HubSubscriptionService._();

  static final HubSubscriptionService instance = HubSubscriptionService._();

  final Map<String, _SubRuntime> _runtimes = {};

  bool get isRunning => _runtimes.isNotEmpty;

  /// 订阅是否已成功加载（监听/连接建立）
  bool isSubRunning(String id) => _runtimes.containsKey(id);

  /// 订阅状态摘要（用于卡片显示）
  String statusOf(String id) {
    final rt = _runtimes[id];
    if (rt == null) return 'stopped';
    return rt.error == null ? 'running' : 'error';
  }

  Future<void> startAll() async {
    await stopAll();
    final subs = HubSubscriptionManager.instance.load();
    for (final sub in subs) {
      await start(sub);
    }
  }

  Future<void> stopAll() async {
    for (final rt in _runtimes.values.toList()) {
      await rt.stop();
    }
    _runtimes.clear();
  }

  Future<void> start(HubSubscription sub) async {
    await stop(sub.id);
    final rt = _SubRuntime(sub);
    await rt.start();
    _runtimes[sub.id] = rt;
  }

  Future<void> stop(String id) async {
    final rt = _runtimes.remove(id);
    await rt?.stop();
  }

  /// 分发事件到所有订阅（房间消息 / 系统事件）
  void dispatch(Map<String, dynamic> event) {
    for (final rt in _runtimes.values) {
      rt.dispatch(event);
    }
  }

  /// 手动保活（各订阅自行维护心跳，此方法仅供测试/触发）
  void pingAll() {
    for (final rt in _runtimes.values) {
      rt.ping();
    }
  }
}

/// 单个订阅的运行时
class _SubRuntime {
  final HubSubscription sub;

  _SubRuntime(this.sub);

  /// 心跳定时器
  Timer? _heartbeat;

  /// ws-forward：已连接的客户端
  final Set<WebSocket> _clients = {};

  /// ws-reverse：出站 socket
  WebSocket? _outSocket;

  /// http：监听服务器
  HttpServer? _httpServer;

  bool _closed = false;

  String? error;

  Future<void> start() async {
    _closed = false;
    error = null;
    try {
      switch (sub.type) {
        case HubSubscriptionType.ws:
          if (sub.wsDirection == HubWsDirection.forward) {
            await _startWsForward();
          } else {
            await _startWsReverse();
          }
        case HubSubscriptionType.webhook:
          _startWebhook();
        case HubSubscriptionType.http:
          await _startHttp();
      }
      _startHeartbeat();
    } catch (e) {
      error = e.toString();
      HubLog.warning('HubSubscription', '订阅启动失败（${sub.note}）：$e');
    }
  }

  // ── ws forward：Hub 作为 WS 服务端监听 ────────────────────────────────────
  Future<void> _startWsForward() async {
    final port = sub.listenPort ?? 0;
    final host = sub.listenHost?.trim().isNotEmpty == true
        ? sub.listenHost!.trim()
        : InternetAddress.anyIPv4.address;
    final server = await HttpServer.bind(host, port);
    _httpServer = server;
    server.listen((request) async {
      try {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          await _sendJson(request, {
            'code': HttpStatus.badRequest,
            'error': 'WS_ONLY',
            'message': '仅支持 WebSocket 连接',
          });
          return;
        }
        // token 校验：优先 ?token= 查询参数
        final queryToken = request.uri.queryParameters['token'];
        if (sub.token?.isNotEmpty == true && queryToken != sub.token) {
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        _clients.add(socket);
        socket.done.whenComplete(() => _clients.remove(socket));
        // 监听认证消息（若未在 query 传 token）
        if (sub.token?.isNotEmpty == true && queryToken != null) {
          return;
        }
        socket.listen(
          (data) {
            try {
              final map = data is String ? jsonDecode(data) : data;
              if (map is Map && map['type'] == 'auth') {
                final t = map['token']?.toString();
                if (sub.token?.isNotEmpty == true && t != sub.token) {
                  socket.add(
                    jsonEncode({'type': 'error', 'message': 'Unauthorized'}),
                  );
                  socket.close(WebSocketStatus.policyViolation, 'Unauthorized');
                } else {
                  socket.add(jsonEncode({'type': 'auth_ok'}));
                }
              }
            } catch (_) {}
          },
          onDone: () => _clients.remove(socket),
          onError: (_) => _clients.remove(socket),
        );
      } catch (_) {}
    });
    HubLog.info(
      'HubSubscription',
      '✅ WS 正向订阅监听：ws://${sub.summary} （${sub.note}）',
    );
  }

  // ── ws reverse：Hub 作为客户端连接目标 ────────────────────────────────────
  Future<void> _startWsReverse() async {
    final url = sub.url;
    if (url == null || url.isEmpty) {
      error = 'URL 为空';
      return;
    }
    final socket = await WebSocket.connect(url);
    _outSocket = socket;
    // 握手携带 token
    if (sub.token?.isNotEmpty == true) {
      socket.add(
        jsonEncode({
          'type': 'hub_subscription_handshake',
          'source': 'kostori-hub',
          'token': sub.token,
          'time': DateTime.now().toIso8601String(),
        }),
      );
    }
    socket.listen((_) {}, onDone: () => _outSocket = null, onError: (_) {});
    HubLog.info('HubSubscription', '✅ WS 反向订阅已连接：$url （${sub.note}）');
  }

  // ── webhook：向目标 URL POST 事件 ─────────────────────────────────────────
  void _startWebhook() {
    HubLog.info(
      'HubSubscription',
      '✅ Webhook 订阅就绪：${sub.summary} （${sub.note}）',
    );
  }

  // ── http：Hub 作为 HTTP 服务端监听 ────────────────────────────────────────
  Future<void> _startHttp() async {
    final port = sub.listenPort ?? 0;
    final host = sub.listenHost?.trim().isNotEmpty == true
        ? sub.listenHost!.trim()
        : InternetAddress.anyIPv4.address;
    final server = await HttpServer.bind(host, port);
    _httpServer = server;
    server.listen((request) async {
      try {
        if (!_authOk(request)) {
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'error': 'Unauthorized'}));
          await request.response.close();
          return;
        }
        final path = request.uri.path;
        if (path == '/hello') {
          await _sendJson(request, {
            'message': 'Hello from Kostori Hub',
            'note': sub.note,
            'timestamp': DateTime.now().toIso8601String(),
          });
        } else if (path == '/health') {
          await _sendJson(request, {
            'status': 'ok',
            'note': sub.note,
            'timestamp': DateTime.now().toIso8601String(),
          });
        } else if (path == '/message' && request.method == 'POST') {
          final body = await utf8.decoder.bind(request).join();
          HubLog.info('HubSubscription', '📨 HTTP 收到消息（${sub.note}）：$body');
          await _sendJson(request, {
            'ok': true,
            'received': body,
            'timestamp': DateTime.now().toIso8601String(),
          });
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'error': 'Not Found'}));
          await request.response.close();
        }
      } catch (_) {}
    });
    HubLog.info(
      'HubSubscription',
      '✅ HTTP 订阅监听：http://${sub.summary} （${sub.note}）',
    );
  }

  bool _authOk(HttpRequest request) {
    if (sub.token?.isEmpty != false) return true;
    final header = request.headers.value('authorization');
    if (header != null) {
      return header == 'Bearer ${sub.token}' || header == sub.token;
    }
    final query = request.uri.queryParameters['token'];
    return query != null && query == sub.token;
  }

  Future<void> _sendJson(HttpRequest request, Map<String, dynamic> data) async {
    final bytes = utf8.encode(jsonEncode(data));
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..headers.set('Content-Length', bytes.length.toString())
      ..add(bytes);
    await request.response.close();
  }

  // ── 心跳 ──────────────────────────────────────────────────────────────────
  void _startHeartbeat() {
    final ms = sub.heartbeatMs;
    if (ms == null || ms <= 0) return;
    _heartbeat = Timer.periodic(Duration(milliseconds: ms), (_) => ping());
  }

  /// 发送一次心跳 / 保活
  void ping() {
    if (_closed) return;
    try {
      switch (sub.type) {
        case HubSubscriptionType.ws:
          final pingMsg = jsonEncode({
            'type': 'ping',
            'time': DateTime.now().toIso8601String(),
          });
          for (final c in _clients.toList()) {
            try {
              c.add(pingMsg);
            } catch (_) {
              _clients.remove(c);
            }
          }
          _outSocket?.add(pingMsg);
        case HubSubscriptionType.webhook:
          final url = sub.url;
          if (url != null && url.isNotEmpty) {
            unawaited(
              AppDio().post(
                url,
                data: jsonEncode({
                  'type': 'ping',
                  'time': DateTime.now().toIso8601String(),
                }),
                options: Options(
                  headers: _webhookHeaders(),
                  sendTimeout: const Duration(seconds: 5),
                  receiveTimeout: const Duration(seconds: 5),
                ),
              ),
            );
          }
        case HubSubscriptionType.http:
          break;
      }
    } catch (e) {
      HubLog.warning('HubSubscription', '心跳发送失败（${sub.note}）：$e');
    }
  }

  Map<String, String> _webhookHeaders() => {
    'Content-Type': 'application/json',
    if (sub.token?.isNotEmpty == true) 'Authorization': 'Bearer ${sub.token}',
  };

  // ── 事件分发 ──────────────────────────────────────────────────────────────
  void dispatch(Map<String, dynamic> event) {
    if (_closed) return;
    try {
      final body = jsonEncode(event);
      switch (sub.type) {
        case HubSubscriptionType.ws:
          // forward：广播给已连接客户端；reverse：推送给目标
          if (sub.wsDirection == HubWsDirection.forward) {
            for (final c in _clients.toList()) {
              try {
                c.add(body);
              } catch (_) {
                _clients.remove(c);
              }
            }
          } else {
            _outSocket?.add(body);
          }
        case HubSubscriptionType.webhook:
          final url = sub.url;
          if (url != null && url.isNotEmpty) {
            unawaited(
              AppDio().post(
                url,
                data: body,
                options: Options(
                  headers: _webhookHeaders(),
                  sendTimeout: const Duration(seconds: 5),
                  receiveTimeout: const Duration(seconds: 5),
                ),
              ),
            );
          }
        case HubSubscriptionType.http:
          // HTTP 订阅为入站服务，无需出站推送
          break;
      }
    } catch (e) {
      HubLog.warning('HubSubscription', '事件推送失败（${sub.note}）：$e');
    }
  }

  Future<void> stop() async {
    _closed = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    for (final c in _clients.toList()) {
      try {
        await c.close(WebSocketStatus.goingAway, 'Closed');
      } catch (_) {}
    }
    _clients.clear();
    try {
      await _outSocket?.close();
    } catch (_) {}
    _outSocket = null;
    try {
      await _httpServer?.close(force: true);
    } catch (_) {}
    _httpServer = null;
    error = null;
  }
}
