part of 'package:kostori/foundation/hub_services/services.dart';

/// ── Hub Web 管理后台 ─────────────────────────────────────────────────────────
/// 在独立端口提供网页管理页面 + JSON 管理 API。
/// 鉴权复用现有 API Key（Bearer token），管理层 Key 可读写配置，
/// 用户层 Key 可读基本信息。

class HubWebAdminService extends BaseHttpService {
  HubWebAdminService(this._hub);

  final HubService _hub;

  /// 是否启用 Web 管理（静态，供 HubService 判断）
  static bool _enabled() => appdata.implicitData[_enabledKey] as bool? ?? false;

  static const _enabledKey = 'hub_web_admin_enabled';
  static const _portKey = 'hub_web_admin_port';
  static const _bindModeKey = 'hub_web_admin_bind_mode';

  // ── 配置 ──

  bool get webAdminEnabled =>
      appdata.implicitData[_enabledKey] as bool? ?? false;

  set webAdminEnabled(bool v) {
    appdata.implicitData[_enabledKey] = v;
    appdata.writeImplicitData();
  }

  int get webAdminPort => appdata.implicitData[_portKey] as int? ?? 9200;

  set webAdminPort(int v) {
    appdata.implicitData[_portKey] = v;
    appdata.writeImplicitData();
  }

  BindMode get webAdminBindMode {
    final val = appdata.implicitData[_bindModeKey] as String?;
    return switch (val) {
      'ipv6' => BindMode.ipv6,
      'both' => BindMode.both,
      _ => BindMode.ipv4,
    };
  }

  set webAdminBindMode(BindMode v) {
    appdata.implicitData[_bindModeKey] = v.name;
    appdata.writeImplicitData();
  }

  @override
  void registerRoutes() {
    // 管理后台（Vite 构建产物，源码见 hub_admin_ui/）
    addGet('/', _serveAdminPage);
    addGet('/admin', _serveAdminPage);
    addGet(
      '/app.js',
      (req, params) =>
          _serveAsset(req, 'app.js', 'text/javascript; charset=utf-8'),
    );
    addGet(
      '/app.css',
      (req, params) => _serveAsset(req, 'app.css', 'text/css; charset=utf-8'),
    );

    // ── 状态总览（用户层可读） ──
    addGet('/api/admin/overview', _overview, middlewares: [authMiddleware]);

    // ── 统计（用户层可读） ──
    addGet('/api/admin/stats', _stats, middlewares: [authMiddleware]);

    // ── 房间 ──
    addGet('/api/admin/rooms', _rooms, middlewares: [authMiddleware]);
    addGet(
      '/api/admin/rooms/:roomId/messages',
      _roomMessages,
      middlewares: [authMiddleware],
    );
    addPost(
      '/api/admin/rooms/:roomId/message',
      _sendRoomMessage,
      middlewares: [adminAuthMiddleware],
    );
    addDelete(
      '/api/admin/rooms/:roomId',
      _deleteRoom,
      middlewares: [adminAuthMiddleware],
    );

    // ── 客户端 ──
    addGet('/api/admin/clients', _clients, middlewares: [authMiddleware]);

    // ── 客户端管理（管理层） ──
    addPost(
      '/api/admin/clients/:id/mute',
      _muteClient,
      middlewares: [adminAuthMiddleware],
    );
    addPost(
      '/api/admin/clients/:id/unmute',
      _unmuteClient,
      middlewares: [adminAuthMiddleware],
    );
    addPost(
      '/api/admin/clients/:id/kick',
      _kickClient,
      middlewares: [adminAuthMiddleware],
    );
    addPost(
      '/api/admin/clients/:id/ban',
      _banClient,
      middlewares: [adminAuthMiddleware],
    );
    addPost(
      '/api/admin/clients/:id/unban',
      _unbanClient,
      middlewares: [adminAuthMiddleware],
    );
    addPost(
      '/api/admin/clients/:id/admin',
      _setClientAdmin,
      middlewares: [adminAuthMiddleware],
    );

    // ── 日志 ──
    addGet('/api/admin/logs', _logs, middlewares: [adminAuthMiddleware]);

    // ── 配置读写 ──
    addGet('/api/admin/config', _getConfig, middlewares: [adminAuthMiddleware]);
    addPost(
      '/api/admin/config',
      _setConfig,
      middlewares: [adminAuthMiddleware],
    );

    // ── 公网 IP 探测（后端代理，避免浏览器 CORS）──
    addGet(
      '/api/admin/public-ip',
      _detectPublicIp,
      middlewares: [adminAuthMiddleware],
    );

    // ── 机器人配置 ──
    addGet('/api/admin/ai', _getAiConfig, middlewares: [adminAuthMiddleware]);
    addPost('/api/admin/ai', _setAiConfig, middlewares: [adminAuthMiddleware]);

    // ── 订阅管理 ──
    addGet(
      '/api/admin/subscriptions',
      _getSubscriptions,
      middlewares: [adminAuthMiddleware],
    );
    addPost(
      '/api/admin/subscriptions',
      _addSubscription,
      middlewares: [adminAuthMiddleware],
    );
    addDelete(
      '/api/admin/subscriptions/:id',
      _deleteSubscription,
      middlewares: [adminAuthMiddleware],
    );

    // ── 服务控制 ──
    addPost(
      '/api/admin/restart',
      _restartHub,
      middlewares: [adminAuthMiddleware],
    );

    // ── 集成能力（上传/Webhook/Satori/Key/LAN/检索）──
    registerIntegrationRoutes();
  }

  @override
  Future<void> init({int? preferredPort, BindMode? mode}) => startServer(
    preferredPort: preferredPort ?? webAdminPort,
    mode: mode ?? webAdminBindMode,
  );

  @override
  Future<void> dispose() => stopServer();

  // ═══════════════════════════════════════════════════════════════
  //  页面
  // ═══════════════════════════════════════════════════════════════

  static const _assetDir = 'assets/hub_admin';

  Future<shelf.Response> _serveAdminPage(
    shelf.Request request,
    Map<String, String> params,
  ) async {
    try {
      final html = await rootBundle.loadString('$_assetDir/index.html');
      return sendHtml(request, html);
    } catch (e) {
      HubLog.error('$runtimeType', '管理后台页面资源缺失: $e');
      return sendHtml(
        request,
        '<!DOCTYPE html><html><head><meta charset="utf-8">'
        '<title>Kostori Hub</title></head><body style="font:14px system-ui;'
        'padding:40px;color:#e8ecf6;background:#0b0f1a">'
        '<h1>管理后台资源缺失</h1>'
        '<p>未找到 $_assetDir/index.html。请确认已执行 '
        '<code>cd hub_admin_ui &amp;&amp; npm run build</code>。</p>'
        '</body></html>',
        status: HttpStatus.internalServerError,
      );
    }
  }

  /// 文件名由路由表写死，不来自请求，因此没有路径穿越面。
  Future<shelf.Response> _serveAsset(
    shelf.Request request,
    String name,
    String mime,
  ) async {
    try {
      final data = await rootBundle.load('$_assetDir/$name');
      return shelf.Response(
        HttpStatus.ok,
        body: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        headers: {
          'content-type': mime,
          // 名字固定（无 hash），改完刷新即可生效，不要缓存
          'cache-control': 'no-cache',
        },
      );
    } catch (e) {
      HubLog.error('$runtimeType', '管理后台资源 $_assetDir/$name 缺失: $e');
      return sendError(
        request,
        HttpStatus.notFound,
        'ASSET_MISSING',
        'Asset not found: $name',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  API 实现
  // ═══════════════════════════════════════════════════════════════

  Future<shelf.Response> _overview(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    return sendJson(req, {
      'app': 'Kostori',
      'version': App.version,
      'uptime': DateTime.now().difference(_hub.startedAt).inSeconds,
      'port': port,
      'clients': _hub.clientCount,
      'rooms': _hub.rooms.length,
      'blacklist': _hub.blacklistCount,
      'lobbyId': _hub.lobbyRoomId,
      'directSyncMembers': _hub.directSyncMemberCount,
    });
  }

  Future<shelf.Response> _stats(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final rooms = _hub.rooms;
    final clients = _hub.clients;
    final now = DateTime.now();
    var totalMessages = 0;
    var botMessages = 0;
    var userMessages = 0;
    var watchSyncMessages = 0;
    var lastHour = 0;
    var today = 0;
    final perRoom =
        <String, ({String name, int count, int participants, String type})>{};
    final perClient = <String, int>{};
    final perClientNames = <String, String>{};
    final hourly = List<int>.filled(24, 0);
    // 近 7 日消息量（0=最早一天 … 6=今天）
    final daily = List<int>.filled(7, 0);
    // 7×24 热力图（0=最早一天）
    final heatmap = List<List<int>>.generate(7, (_) => List<int>.filled(24, 0));

    for (final r in rooms) {
      var roomCount = 0;
      for (final m in r.messageHistory) {
        totalMessages++;
        roomCount++;
        if (m.sender.isBot) {
          botMessages++;
        } else {
          userMessages++;
        }
        if (m.segments.whereType<TextSegment>().any(
          (s) => isHubSyncText(s.text),
        )) {
          watchSyncMessages++;
        }
        final age = now.difference(m.sentAt);
        if (age.inHours < 1) lastHour++;
        if (age.inDays < 1) today++;
        if (age.inHours < 24) hourly[m.sentAt.hour]++;
        if (age.inDays < 7) {
          final d = 6 - age.inDays;
          daily[d]++;
          heatmap[d][m.sentAt.hour]++;
        }
        perClient[m.sender.userId] = (perClient[m.sender.userId] ?? 0) + 1;
        perClientNames[m.sender.userId] = m.sender.displayName;
      }
      perRoom[r.roomId] = (
        name: r.roomName,
        count: roomCount,
        participants: r.participants.length,
        type: r.roomType.name,
      );
    }

    final topClients =
        perClient.entries
            .map(
              (e) => {
                'userId': e.key,
                'name': perClientNames[e.key] ?? e.key,
                'count': e.value,
              },
            )
            .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final topRooms =
        perRoom.values
            .map(
              (v) => {
                'name': v.name,
                'count': v.count,
                'participants': v.participants,
                'type': v.type,
              },
            )
            .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return sendJson(req, {
      'summary': {
        'totalMessages': totalMessages,
        'userMessages': userMessages,
        'botMessages': botMessages,
        'watchSyncMessages': watchSyncMessages,
        'lastHour': lastHour,
        'today': today,
        'rooms': rooms.length,
        'clients': clients.length,
        'blacklist': _hub.blacklistCount,
        'directSyncMembers': _hub.directSyncMemberCount,
        'uptime': now.difference(_hub.startedAt).inSeconds,
        'port': port,
        'version': App.version,
      },
      'topClients': topClients.take(10).toList(),
      'rooms': topRooms,
      'hourly': hourly,
      'daily': daily,
      'heatmap': heatmap,
    });
  }

  Future<shelf.Response> _rooms(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final list = _hub.rooms
        .map(
          (r) => {
            'roomId': r.roomId,
            'roomName': r.roomName,
            'ownerUserId': r.ownerUserId,
            'ownerName': _hub.clientName(r.ownerUserId),
            'participantCount': r.participants.length,
            'participants': r.participants.values
                .map(
                  (c) => {
                    'userId': c.userId,
                    'name': c.displayName,
                    'isBot': c.isBot,
                  },
                )
                .toList(),
            'isLocked': r.isLocked,
            'isFull': r.isFull,
            'maxParticipants': r.maxParticipants,
            'roomType': r.roomType.name,
            'animeTitle': r.animeTitle,
            'announcements': r.announcements,
            'welcomeMessage': r.welcomeMessage,
            'messageCount': r.messageHistory.length,
            'createdAt': r.createdAt.toIso8601String(),
          },
        )
        .toList();
    return sendJson(req, {'count': list.length, 'items': list});
  }

  Future<shelf.Response> _roomMessages(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final roomId = params['roomId'] ?? '';
    // 必须 clamp：?limit=-1 会让 sublist(hist.length + 1) 抛 RangeError
    final limit =
        (int.tryParse(req.requestedUri.queryParameters['limit'] ?? '') ?? 50)
            .clamp(1, 500);
    final room = _hub.findRoom(roomId);
    if (room == null) {
      return sendJson(req, {'error': 'Room not found'}, status: 404);
    }
    final hist = room.messageHistory;
    final recent = hist.length > limit
        ? hist.sublist(hist.length - limit)
        : hist;
    final list = recent
        .map(
          (m) => {
            'sender': m.sender.displayName,
            'isBot': m.sender.isBot,
            'time': m.sentAt.toIso8601String(),
            'text': m.plainText,
          },
        )
        .toList();
    return sendJson(req, {'count': list.length, 'messages': list});
  }

  Future<shelf.Response> _sendRoomMessage(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final roomId = params['roomId'] ?? '';
    final body = await readJson(req);
    if (body == null) {
      return sendJson(req, {'error': 'Invalid body'}, status: 400);
    }
    final text = body['text'] as String?;
    final asBot = body['asBot'] as bool? ?? false;
    if (text == null || text.isEmpty) {
      return sendJson(req, {'error': 'text required'}, status: 400);
    }
    final room = _hub.findRoom(roomId);
    if (room == null) {
      return sendJson(req, {'error': 'Room not found'}, status: 404);
    }
    if (asBot) {
      final bot = HubClientInfo(
        userId: 'admin-web',
        displayName: 'Web 管理',
        connection: null,
        currentRoomId: roomId,
        isBot: true,
      );
      _hub.broadcastToRoomFrom(
        roomId,
        HubMessage(
          messageType: HubMessageType.chat,
          sender: bot.toDto(),
          targetRoomIds: [roomId],
          segments: _hub.parseSegments(text),
        ),
      );
    } else {
      final server = _hub.serverBotClient(roomId);
      _hub.broadcastToRoomFrom(
        roomId,
        HubMessage(
          messageType: HubMessageType.chat,
          sender: server.toDto(),
          targetRoomIds: [roomId],
          segments: _hub.parseSegments(text),
        ),
      );
    }
    return sendJson(req, {'sent': true});
  }

  Future<shelf.Response> _deleteRoom(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final roomId = params['roomId'] ?? '';
    final ok = _hub.deleteRoomByAdmin(roomId);
    return sendJson(req, {'deleted': ok});
  }

  Future<shelf.Response> _clients(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final list = _hub.clients
        .map(
          (c) => {
            'userId': c.userId,
            'name': c.displayName,
            'avatarUrl': c.avatarUrl,
            'biography': c.biography,
            'isBot': c.isBot,
            'isGlobalAdmin': c.isGlobalAdmin,
            'onlineStatus': c.onlineStatus.name,
            'currentRoomId': c.currentRoomId,
            'currentRoomName':
                _hub.rooms
                    .firstWhereOrNull((r) => r.roomId == c.currentRoomId)
                    ?.roomName ??
                c.currentRoomId,
            'isMuted': c.isMuted,
            'mutedUntil': c.mutedUntil?.toIso8601String(),
            'isBlacklisted': _hub.isBlacklisted(c.userId),
            'peerCandidates': c.peerCandidates,
            'connectedAt': c.connectedAt.toIso8601String(),
            'lastHeartbeat': c.lastHeartbeat.toIso8601String(),
          },
        )
        .toList();
    return sendJson(req, {'count': list.length, 'items': list});
  }

  Future<shelf.Response> _muteClient(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final id = params['id'] ?? '';
    final body = await readJson(req);
    final seconds = (body?['seconds'] as num?)?.toInt() ?? 300;
    await _hub.muteClient(id, seconds: seconds);
    return sendJson(req, {'ok': true});
  }

  Future<shelf.Response> _unmuteClient(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final id = params['id'] ?? '';
    await _hub.unmuteClient(id);
    return sendJson(req, {'ok': true});
  }

  Future<shelf.Response> _kickClient(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final id = params['id'] ?? '';
    await _hub.kickClient(id, operatorName: 'Web 管理');
    return sendJson(req, {'ok': true});
  }

  Future<shelf.Response> _banClient(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final id = params['id'] ?? '';
    _hub.addToBlacklist(id);
    return sendJson(req, {'ok': true});
  }

  Future<shelf.Response> _unbanClient(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final id = params['id'] ?? '';
    _hub.removeFromBlacklist(id);
    return sendJson(req, {'ok': true});
  }

  Future<shelf.Response> _setClientAdmin(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final id = params['id'] ?? '';
    final body = await readJson(req);
    await _hub.setClientGlobalAdmin(id, body?['value'] as bool? ?? true);
    return sendJson(req, {'ok': true});
  }

  Future<shelf.Response> _logs(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final limit =
        int.tryParse(req.requestedUri.queryParameters['limit'] ?? '') ?? 100;
    final level = req.requestedUri.queryParameters['level'];
    var logs = Log.logs;
    if (level != null && level.isNotEmpty) {
      logs = logs.where((l) => l.level.name == level).toList();
    }
    final recent = logs.length > limit.clamp(1, 500)
        ? logs.sublist(logs.length - limit.clamp(1, 500))
        : logs;
    final list = recent
        .map(
          (l) => {
            'level': l.level.name,
            'title': l.title,
            'content': l.content,
            'time': l.time.toIso8601String(),
          },
        )
        .toList();
    return sendJson(req, {'count': recent.length, 'logs': list});
  }

  Future<shelf.Response> _getConfig(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    return sendJson(req, {
      'hubPort': savedHubPort,
      'hubBindMode': savedHubBindMode.name,
      'hubNoAuth': hubNoAuth,
      'pingIntervalMs': pingInterval.inMilliseconds,
      'apiKeyConfigured': ApiKeyManager().activeKey.isNotEmpty,
      'adminKeyConfigured': ApiKeyManager().adminActiveKey.isNotEmpty,
      'webAdminPort': webAdminPort,
      'webAdminBindMode': webAdminBindMode.name,
      'upload': {
        'mode': _hub.uploadConfig.mode.name,
        'maxSizeBytes': _hub.uploadConfig.maxSizeBytes,
        'localStorePath': _hub.uploadConfig.localStorePath,
        'publicBaseUrl': _hub.uploadConfig.publicBaseUrl,
      },
      'tls': {
        'enabled': tlsEnabled,
        'certificatePath': tlsCertificatePath,
        'privateKeyPath': tlsPrivateKeyPath,
      },
    });
  }

  Future<shelf.Response> _setConfig(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final body = await readJson(req);
    if (body == null) {
      return sendJson(req, {'error': 'Invalid body'}, status: 400);
    }
    final changed = <String>[];
    if (body['pingIntervalMs'] != null) {
      setPingInterval(
        (body['pingIntervalMs'] as num).toInt().clamp(10000, 120000),
      );
      changed.add('pingIntervalMs');
    }
    if (body['hubNoAuth'] is bool) {
      setHubNoAuth(body['hubNoAuth'] as bool);
      changed.add('hubNoAuth');
    }
    if (body['hubPort'] is num) {
      saveHubPort((body['hubPort'] as num).toInt());
      changed.add('hubPort');
    }
    if (body['hubBindMode'] is String) {
      saveHubBindMode(
        BindMode.values.firstWhereOrNull(
              (m) => m.name == body['hubBindMode'],
            ) ??
            BindMode.ipv4,
      );
      changed.add('hubBindMode');
    }
    if (body['webAdminPort'] is num) {
      webAdminPort = (body['webAdminPort'] as num).toInt();
      changed.add('webAdminPort');
    }
    if (body['webAdminBindMode'] is String) {
      webAdminBindMode =
          BindMode.values.firstWhereOrNull(
            (m) => m.name == body['webAdminBindMode'],
          ) ??
          BindMode.ipv4;
      changed.add('webAdminBindMode');
    }
    // 上传配置：公网基础地址
    if (body['publicBaseUrl'] != null) {
      final pb = body['publicBaseUrl'].toString().trim();
      _hub.uploadConfig = _hub.uploadConfig.copyWith(
        publicBaseUrl: pb.isEmpty ? null : pb,
        clearPublicBaseUrl: pb.isEmpty,
      );
      changed.add('publicBaseUrl');
    }
    // TLS 配置
    if (body['tlsEnabled'] is bool) {
      setTlsEnabled(body['tlsEnabled'] as bool);
      changed.add('tlsEnabled');
    }
    if (body['tlsCertificatePath'] != null) {
      setTlsCertificatePath(body['tlsCertificatePath'].toString().trim());
      changed.add('tlsCertificatePath');
    }
    if (body['tlsPrivateKeyPath'] != null) {
      setTlsPrivateKeyPath(body['tlsPrivateKeyPath'].toString().trim());
      changed.add('tlsPrivateKeyPath');
    }
    if (body['tlsPassword'] != null) {
      setTlsPassword(body['tlsPassword'].toString());
      changed.add('tlsPassword');
    }
    return sendJson(req, {'saved': true, 'changed': changed});
  }

  Future<shelf.Response> _getAiConfig(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final c = _hub.aiBotConfig;
    return sendJson(req, {
      'enabled': c.enabled,
      'provider': c.provider,
      'model': c.model,
      'name': c.name,
      'triggerMode': c.triggerMode,
      'triggerPattern': c.triggerPattern,
      'minIntervalSec': c.minIntervalSec,
      'replyDm': c.replyDm,
      // 人设内容不返回（避免暴露过长文本），仅返回开关与标识
      'systemPromptPreview': c.systemPrompt.length > 80
          ? '${c.systemPrompt.substring(0, 80)}...'
          : c.systemPrompt,
    });
  }

  Future<shelf.Response> _setAiConfig(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final body = await readJson(req);
    if (body == null) {
      return sendJson(req, {'error': 'Invalid body'}, status: 400);
    }
    final c = _hub.aiBotConfig;
    final updated = c.copyWith(
      enabled: body['enabled'] is bool ? body['enabled'] as bool : c.enabled,
      provider: body['provider'] is String
          ? body['provider'] as String
          : c.provider,
      model: body['model'] is String ? body['model'] as String : c.model,
      name: body['name'] is String ? body['name'] as String : c.name,
      triggerMode: body['triggerMode'] is String
          ? body['triggerMode'] as String
          : c.triggerMode,
      triggerPattern: body['triggerPattern'] is String
          ? body['triggerPattern'] as String
          : c.triggerPattern,
      minIntervalSec: body['minIntervalSec'] is num
          ? (body['minIntervalSec'] as num).toInt()
          : c.minIntervalSec,
      replyDm: body['replyDm'] is bool ? body['replyDm'] as bool : c.replyDm,
    );
    updated.save();
    return sendJson(req, {'saved': true});
  }

  Future<shelf.Response> _getSubscriptions(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final m = HubSubscriptionManager.instance;
    final list = m
        .load()
        .map(
          (s) => {
            'id': s.id,
            'type': s.type.name,
            'wsDirection': s.wsDirection?.name,
            'listenHost': s.listenHost,
            'listenPort': s.listenPort,
            'url': s.url,
            'heartbeatMs': s.heartbeatMs,
            'token': s.token,
            'note': s.note,
            'summary': s.summary,
            'status': HubSubscriptionService.instance.statusOf(s.id),
          },
        )
        .toList();
    return sendJson(req, {'count': list.length, 'items': list});
  }

  Future<shelf.Response> _addSubscription(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final body = await readJson(req);
    if (body == null) {
      return sendJson(req, {'error': 'Invalid body'}, status: 400);
    }
    final type =
        HubSubscriptionType.values.asNameMap()[body['type']] ??
        HubSubscriptionType.webhook;
    final wsDirection = type == HubSubscriptionType.ws
        ? (HubWsDirection.values.asNameMap()[body['wsDirection']] ??
              HubWsDirection.reverse)
        : null;
    final sub = HubSubscription(
      id: const Uuid().v4(),
      type: type,
      wsDirection: wsDirection,
      listenHost: body['listenHost'] as String?,
      listenPort: (body['listenPort'] as num?)?.toInt(),
      url: body['url'] as String?,
      heartbeatMs: (body['heartbeatMs'] as num?)?.toInt(),
      token: body['token'] as String?,
      note: body['note'] as String? ?? '',
      createdAt: DateTime.now().toIso8601String(),
    );
    HubSubscriptionManager.instance.add(sub);
    await HubSubscriptionService.instance.start(sub);
    return sendJson(req, {'created': true, 'id': sub.id});
  }

  Future<shelf.Response> _deleteSubscription(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    final id = params['id'] ?? '';
    HubSubscriptionManager.instance.delete(id);
    await HubSubscriptionService.instance.stop(id);
    return sendJson(req, {'deleted': true});
  }

  Future<shelf.Response> _restartHub(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    // restart() 会 force-close 掉自己所在的监听器，响应写不出去，
    // 所以先返回再延迟重启。
    final response = sendJson(req, {'restarting': true});
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 300)).then((_) {
        return _hub.restart();
      }),
    );
    return response;
  }

  // ── 公网 IP 探测 ─────────────────────────────────────────────────────────

  Future<shelf.Response> _detectPublicIp(
    shelf.Request req,
    Map<String, String> params,
  ) async {
    String? ip;
    // IPv4 优先
    for (final api in const [
      'https://api.ipify.org',
      'https://ipv4.icanhazip.com',
      'https://v4.ident.me',
    ]) {
      try {
        final r = await AppDio().request(
          api,
          options: Options(
            method: 'GET',
            responseType: ResponseType.plain,
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );
        final s = (r.data ?? '').toString().trim();
        if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(s)) {
          ip = s;
          break;
        }
      } catch (_) {}
    }
    // IPv6 回退
    if (ip == null) {
      for (final api in const [
        'https://api64.ipify.org',
        'https://ipv6.icanhazip.com',
      ]) {
        try {
          final r = await AppDio().request(
            api,
            options: Options(
              method: 'GET',
              responseType: ResponseType.plain,
              sendTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
            ),
          );
          final s = (r.data ?? '').toString().trim();
          if (RegExp(r'^[0-9a-fA-F:]+$').hasMatch(s) && s.contains(':')) {
            ip = s;
            break;
          }
        } catch (_) {}
      }
    }

    if (ip == null) {
      return sendJson(req, {
        'error': 'Failed to detect public IP',
      }, status: 502);
    }

    final isV6 = ip.contains(':');
    final url = isV6 ? 'http://[$ip]:${_hub.port}' : 'http://$ip:${_hub.port}';
    return sendJson(req, {'ip': ip, 'url': url});
  }
}
