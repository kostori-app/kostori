part of 'package:kostori/foundation/services/services.dart';

extension HubServiceRoutes on HubService {
  void registerHubRoutes() {
    _rooms[_lobbyId] = HubRoom(id: _lobbyId, name: 'Lobby', ownerId: 'server');

    // ── WebSocket ─────────────────────────────────
    addWs('/hub', (socket, req) async {
      bool authed = false;
      String? clientId;
      String? clientName;

      await for (final raw in socket) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;

          if (!authed) {
            final token = data['token'] as String?;
            Log.info('HubService', '收到鉴权  token=$token');
            Log.info('HubService', 'activeKey=${ApiKeyManager().activeKey}');

            if (token == null || !ApiKeyManager().validate(token)) {
              Log.warning('HubService', '❌ 鉴权失败');
              await socket.close(
                WebSocketStatus.policyViolation,
                'Unauthorized',
              );
              return;
            }

            authed = true;
            clientId = data['id'] as String? ?? _generateId();
            clientName = _resolveClientName(data['name'] as String? ?? 'User');

            if (_blacklist.contains(clientId)) {
              Log.warning('HubService', '🚫 黑名单用户尝试连接：$clientName ($clientId)');
              await socket.close(WebSocketStatus.policyViolation, 'Banned');
              return;
            }

            if (_clients.containsKey(clientId)) {
              await _clients[clientId]?.socket.close(
                WebSocketStatus.policyViolation,
                'Replaced by new connection',
              );
            }

            final client = HubClientInfo(
              id: clientId,
              name: clientName,
              socket: socket,
              avatar: data['avatar'] as String?,
              bio: data['bio'] as String?,
              isGlobalAdmin: _adminIds.contains(clientId),
            );
            if (client.isGlobalAdmin) {
              Log.info('HubService', '👑 管理员上线：$clientName');
            }
            _clients[clientId] = client;

            _rooms[_lobbyId]!.members[clientId] = client;
            client.currentRoomId = _lobbyId;
            onClientsChanged?.call();

            Log.info(
              'HubService',
              '🟢 $clientName ($clientId)  共${_clients.length}个',
            );

            client.send({
              'type': 'welcome',
              'yourId': clientId,
              'clients': _clients.values.map((c) => c.toJson()).toList(),
              'room': _rooms[_lobbyId]!.toJson(),
              'history': _rooms[_lobbyId]!.messages
                  .map((m) => m.toJson())
                  .toList(),
              'rooms': _rooms.values.map((r) => r.toJson()).toList(),
            });

            _broadcastToRoom(
              _lobbyId,
              HubMessage(
                type: HubMessageType.system,
                from: 'server',
                payload: {'event': 'client_joined', 'client': client.toJson()},
              ),
              exclude: clientId,
            );

            continue;
          }

          await handleClientMessage(clientId!, data);
        } catch (e) {
          _clients[clientId]?.send({'type': 'error', 'message': '消息格式错误：$e'});
        }
      }

      if (clientId != null) {
        final client = _clients[clientId];
        final roomId = client?.currentRoomId ?? _lobbyId;
        _rooms[roomId]?.members.remove(clientId);
        _clients.remove(clientId);
        onClientsChanged?.call();

        Log.info(
          'HubService',
          '🔴 $clientName ($clientId)  剩${_clients.length}个',
        );

        _broadcastToRoom(
          roomId,
          HubMessage(
            type: HubMessageType.system,
            from: 'server',
            payload: {
              'event': 'client_left',
              'clientId': clientId,
              'clientName': clientName,
            },
          ),
        );
      }
    });

    // ── HTTP ──────────────────────────────────────
    addGet('/hub/clients', (req) async {
      await sendJson(req, {
        'count': _clients.length,
        'clients': _clients.values.map((c) => c.toJson()).toList(),
      });
    }, middlewares: [authMiddleware]);

    addGet('/hub/rooms', (req) async {
      await sendJson(req, {
        'count': _rooms.length,
        'rooms': _rooms.values.map((r) => r.toJson()).toList(),
      });
    }, middlewares: [authMiddleware]);

    addGet('/hub/history', (req) async {
      final roomId = req.uri.queryParameters['room'] ?? _lobbyId;
      final room = _rooms[roomId];
      if (room == null) {
        await sendJson(req, {
          'error': 'Room not found',
        }, status: HttpStatus.notFound);
        return;
      }
      await sendJson(req, {
        'count': room.messages.length,
        'messages': room.messages.map((m) => m.toJson()).toList(),
      });
    }, middlewares: [authMiddleware]);

    addPost('/hub/broadcast', (req) async {
      final body = await readJson(req);
      if (body == null) return;
      final roomId = body['room'] as String? ?? _lobbyId;
      final payload = body['payload'] ?? body;
      _broadcastToRoom(
        roomId,
        HubMessage(
          type: HubMessageType.broadcast,
          from: 'server',
          payload: payload,
        ),
      );
      await sendJson(req, {
        'sent': true,
        'to': _rooms[roomId]?.members.length ?? 0,
      });
    }, middlewares: [authMiddleware]);

    addGet('/hub/pinned', (req) async {
      final roomId = req.uri.queryParameters['room'] ?? _lobbyId;
      final pinned =
          _rooms[roomId]?.messages.where((m) => m.isPinned).toList() ?? [];
      await sendJson(req, {
        'count': pinned.length,
        'messages': pinned.map((m) => m.toJson()).toList(),
      });
    }, middlewares: [authMiddleware]);

    addGet('/hub/search', (req) async {
      final keyword = req.uri.queryParameters['q'] ?? '';
      final roomId = req.uri.queryParameters['room'] ?? _lobbyId;
      if (keyword.isEmpty) {
        await sendJson(req, {
          'error': 'keyword required',
        }, status: HttpStatus.badRequest);
        return;
      }
      final results =
          _rooms[roomId]?.messages
              .where(
                (m) => m.payload.toString().toLowerCase().contains(
                  keyword.toLowerCase(),
                ),
              )
              .toList() ??
          [];
      await sendJson(req, {
        'keyword': keyword,
        'count': results.length,
        'results': results.map((m) => m.toJson()).toList(),
      });
    }, middlewares: [authMiddleware]);
  }
}
