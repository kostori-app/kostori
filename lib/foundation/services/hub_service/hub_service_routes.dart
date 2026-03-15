part of 'package:kostori/foundation/services/services.dart';

extension HubServiceRoutes on HubService {
  void registerHubRoutes() {
    _rooms[_lobbyId] = HubRoom(
      roomId: _lobbyId,
      roomName: 'Lobby',
      ownerUserId: 'server',
    );

    addWs('/hub', (socket, req) async {
      socket.pingInterval = pingInterval;

      bool authed = false;
      String? clientId;
      String? clientName;

      // ── 速率限制状态（每个连接独立）──────────────────────────────────────
      int msgCount = 0;
      DateTime windowStart = DateTime.now();

      await for (final raw in socket) {
        try {
          // ── 消息大小限制：64KB ────────────────────────────────────────────
          if ((raw as String).length > 64 * 1024) {
            _clients[clientId]?.send({
              'type': 'error',
              'message': '消息过大，最大允许 64KB',
            });
            continue;
          }

          // ── 速率限制：每秒最多 20 条 ──────────────────────────────────────
          final now = DateTime.now();
          if (now.difference(windowStart).inSeconds >= 1) {
            msgCount = 0;
            windowStart = now;
          }
          msgCount++;
          if (msgCount > 20) {
            // 静默丢弃，不断开（防止误伤正常用户）
            HubLog.warning(
              'HubService',
              '⚠️ 速率限制触发：${clientName ?? clientId ?? "unknown"}',
            );
            continue;
          }

          final data = jsonDecode(raw) as Map<String, dynamic>;

          if (!authed) {
            final token = data['token'] as String?;
            HubLog.info('HubService', '收到鉴权  token=$token');
            HubLog.info('HubService', 'activeKey=${ApiKeyManager().activeKey}');

            if (!_hubNoAuth) {
              if (token == null || !ApiKeyManager().validate(token)) {
                HubLog.warning('HubService', '❌ 鉴权失败');
                await socket.close(
                  WebSocketStatus.policyViolation,
                  'Unauthorized',
                );
                return;
              }
            } else {
              HubLog.info('HubService', '🔓 免密模式，跳过鉴权');
            }

            authed = true;
            final deviceId = data['userId'] as String? ?? _generateId();

            // ── 防止伪装已在线的管理员 ──────────────────────────────────────
            final existingClient = _clients[deviceId];
            if (existingClient != null && existingClient.isGlobalAdmin) {
              // 已有管理员在线，新连接必须也持有 admin token 才能替换
              if (!_hubNoAuth &&
                  (token == null || !ApiKeyManager().validateAdmin(token))) {
                HubLog.warning('HubService', '🚫 尝试伪装管理员账号：$deviceId');
                await socket.close(
                  WebSocketStatus.policyViolation,
                  'Forbidden',
                );
                return;
              }
            }

            clientId = deviceId;
            clientName = _resolveClientName(
              data['displayName'] as String? ?? 'User',
            );

            if (_blacklist.contains(clientId)) {
              HubLog.warning(
                'HubService',
                '🚫 黑名单用户尝试连接：$clientName ($clientId)',
              );
              _logEvent('🚫 Blocked blacklisted user: $clientName');
              await socket.close(WebSocketStatus.policyViolation, 'Banned');
              return;
            }

            if (_clients.containsKey(clientId)) {
              await _clients[clientId]?.connection.close(
                WebSocketStatus.policyViolation,
                'Replaced by new connection',
              );
            }

            final bool isAdmin =
                _adminIds.contains(clientId) ||
                (!_hubNoAuth &&
                    token != null &&
                    ApiKeyManager().validateAdmin(token));

            final client = HubClientInfo(
              userId: clientId,
              displayName: clientName,
              connection: socket,
              avatarUrl: data['avatarUrl'] as String?,
              biography: data['biography'] as String?,
              isGlobalAdmin: isAdmin,
            );

            if (client.isGlobalAdmin) {
              HubLog.info('HubService', '👑 管理员上线：$clientName');
            }
            _clients[clientId] = client;
            _rooms[_lobbyId]!.participants[clientId] = client;
            client.currentRoomId = _lobbyId;
            onClientsChanged?.call();
            _logEvent(
              '🟢 $clientName${client.isGlobalAdmin ? " 👑" : ""} joined (${_clients.length} online)',
            );
            HubLog.info(
              'HubService',
              '🟢 $clientName ($clientId)  共${_clients.length}个',
            );

            client.send({
              'type': 'welcome',
              'yourId': clientId,
              'clients': _clients.values.map((c) => c.toJson()).toList(),
              'room': _rooms[_lobbyId]!.toJson(),
              'history': _rooms[_lobbyId]!.messageHistory
                  .map((m) => m.toJson())
                  .toList(),
              'rooms': _rooms.values.map((r) => r.toJson()).toList(),
              if (isAdmin) 'blacklist': _blacklist.toList(),
              'heartbeatInterval': pingInterval.inMilliseconds,
              'uploadEnabled': uploadConfig.mode != HubUploadMode.clientOss,
            });

            _broadcastSystem(HubSystemEvent.clientJoined, {
              'client': client.toJson(),
            }, exclude: clientId);

            continue;
          }

          await handleClientMessage(clientId!, data);
        } catch (e) {
          _clients[clientId]?.send({'type': 'error', 'message': '消息格式错误：$e'});
        }
      }

      if (clientId != null && _clients.containsKey(clientId)) {
        final client = _clients[clientId];
        final roomId = client?.currentRoomId ?? _lobbyId;
        _rooms[roomId]?.participants.remove(clientId);
        _clients.remove(clientId);
        onClientsChanged?.call();
        _logEvent('🔴 $clientName left (${_clients.length} online)');
        HubLog.info(
          'HubService',
          '🔴 $clientName ($clientId)  剩${_clients.length}个',
        );

        _broadcastSystemToRoom(roomId, HubSystemEvent.clientLeftRoom, {
          'clientId': clientId,
          'clientName': clientName,
          'client': {'userId': clientId, 'displayName': clientName ?? clientId},
          'roomId': roomId,
        });

        _broadcastSystem(HubSystemEvent.clientLeft, {
          'clientId': clientId,
          'clientName': clientName,
        });
      }
    });

    addGet(
      '/hub/clients',
      (req) async {
        await sendJson(req, {
          'count': _clients.length,
          'clients': _clients.values.map((c) => c.toJson()).toList(),
        });
      },
      middlewares: _hubAuthMiddleware,
      doc: RouteDoc(
        summary: '在线客户端列表',
        description: '返回当前所有在线客户端信息',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'token',
            type: 'query',
            description: 'API Key',
            required: true,
          ),
        ],
        response: 'JSON: count, clients[]',
      ),
    );

    addGet(
      '/hub/rooms',
      (req) async {
        await sendJson(req, {
          'count': _rooms.length,
          'rooms': _rooms.values.map((r) => r.toJson()).toList(),
        });
      },
      middlewares: _hubAuthMiddleware,
      doc: RouteDoc(
        summary: '房间列表',
        description: '返回当前所有房间信息',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'token',
            type: 'query',
            description: 'API Key',
            required: true,
          ),
        ],
        response: 'JSON: count, rooms[]',
      ),
    );

    addGet(
      '/hub/history',
      (req) async {
        final roomId = req.uri.queryParameters['room'] ?? _lobbyId;
        final room = _rooms[roomId];
        if (room == null) {
          await sendJson(req, {
            'error': 'Room not found',
          }, status: HttpStatus.notFound);
          return;
        }
        await sendJson(req, {
          'count': room.messageHistory.length,
          'messages': room.messageHistory.map((m) => m.toJson()).toList(),
        });
      },
      middlewares: _hubAuthMiddleware,
      doc: RouteDoc(
        summary: '消息历史',
        description: '返回指定房间的消息历史，默认为大厅',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'token',
            type: 'query',
            description: 'API Key',
            required: true,
          ),
          DocParam(
            name: 'room',
            type: 'query',
            description: '房间ID，默认为大厅',
            required: false,
          ),
        ],
        response: 'JSON: count, messages[]',
      ),
    );

    addPost(
      '/hub/broadcast',
      (req) async {
        final body = await readJson(req);
        if (body == null) return;
        final roomId = body['room'] as String? ?? _lobbyId;
        final payload = body['payload'] ?? body;
        broadcast(payload, roomId: roomId);
        await sendJson(req, {
          'sent': true,
          'to': _rooms[roomId]?.participants.length ?? 0,
        });
      },
      middlewares: _hubAuthMiddleware,
      doc: RouteDoc(
        summary: '广播消息',
        description: '向指定房间广播消息，默认为大厅',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'token',
            type: 'query',
            description: 'API Key',
            required: true,
          ),
          DocParam(
            name: 'room',
            type: 'body',
            description: '房间ID，默认为大厅',
            required: false,
          ),
          DocParam(
            name: 'payload',
            type: 'body',
            description: '消息内容',
            required: true,
          ),
        ],
        response: 'JSON: sent, to',
      ),
    );

    addGet(
      '/hub/pinned',
      (req) async {
        final roomId = req.uri.queryParameters['room'] ?? _lobbyId;
        final pinned =
            _rooms[roomId]?.messageHistory
                .where((m) => m.messageType == HubMessageType.pin)
                .toList() ??
            [];
        await sendJson(req, {
          'count': pinned.length,
          'messages': pinned.map((m) => m.toJson()).toList(),
        });
      },
      middlewares: _hubAuthMiddleware,
      doc: RouteDoc(
        summary: '置顶消息',
        description: '返回指定房间的所有置顶消息',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'token',
            type: 'query',
            description: 'API Key',
            required: true,
          ),
          DocParam(
            name: 'room',
            type: 'query',
            description: '房间ID，默认为大厅',
            required: false,
          ),
        ],
        response: 'JSON: count, messages[]',
      ),
    );

    addGet(
      '/hub/search',
      (req) async {
        final keyword = req.uri.queryParameters['q'] ?? '';
        final roomId = req.uri.queryParameters['room'] ?? _lobbyId;
        if (keyword.isEmpty) {
          await sendJson(req, {
            'error': 'keyword required',
          }, status: HttpStatus.badRequest);
          return;
        }
        final results =
            _rooms[roomId]?.messageHistory
                .where(
                  (m) =>
                      m.plainText.toLowerCase().contains(keyword.toLowerCase()),
                )
                .toList() ??
            [];
        await sendJson(req, {
          'keyword': keyword,
          'count': results.length,
          'results': results.map((m) => m.toJson()).toList(),
        });
      },
      middlewares: _hubAuthMiddleware,
      doc: RouteDoc(
        summary: '搜索消息',
        description: '在指定房间内按关键词搜索消息',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'token',
            type: 'query',
            description: 'API Key',
            required: true,
          ),
          DocParam(
            name: 'q',
            type: 'query',
            description: '搜索关键词',
            required: true,
          ),
          DocParam(
            name: 'room',
            type: 'query',
            description: '房间ID，默认为大厅',
            required: false,
          ),
        ],
        response: 'JSON: keyword, count, results[]',
      ),
    );
  }
}
