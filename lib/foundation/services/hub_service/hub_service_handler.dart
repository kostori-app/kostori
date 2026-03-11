part of 'package:kostori/foundation/services/services.dart';

extension HubServiceHandler on HubService {
  Future<void> handleClientMessage(
    String fromId,
    Map<String, dynamic> data,
  ) async {
    final messageType = data['messageType'] as String? ?? 'broadcast';
    final targetUserId = data['targetUserId'] as String?;
    final client = _clients[fromId];
    final roomId = client?.currentRoomId ?? _lobbyId;

    if (data['encrypted'] == true && data['segments'] is String) {
      try {
        final decrypted = HubCrypto.decrypt(data['segments'] as String);
        data['segments'] = jsonDecode(decrypted);
        data.remove('encrypted');
      } catch (_) {}
    }
    final segments = data['segments'] ?? data;

    switch (messageType) {
      case 'broadcast':
        if (client?.isMuted == true) {
          client?.send({
            'messageType': 'error',
            'message': '你已被禁言，解除时间：${client.mutedUntil!.toIso8601String()}',
          });
          return;
        }
        final message = HubMessage(
          messageType: HubMessageType.chat,
          sender: client!.toDto(),
          targetRoomIds: [roomId],
          segments: _parseSegments(segments),
          replyToMessageId: data['replyToMessageId'] as String?,
        );
        _broadcastToRoom(roomId, message);
        _checkMentions(message, fromId, client);

      case 'unicast':
        if (targetUserId == null) {
          client?.send({
            'messageType': 'error',
            'message': '单播需要指定 targetUserId 字段',
          });
          return;
        }
        _unicast(
          HubMessage(
            messageType: HubMessageType.chat,
            sender: client!.toDto(),
            targetRoomIds: [roomId],
            segments: _parseSegments(segments),
          ),
          roomId,
          targetUserId,
        );

      case 'ping':
        client?.lastHeartbeat = DateTime.now();
        client?.send({
          'messageType': 'pong',
          'time': DateTime.now().toIso8601String(),
        });

      case 'recall':
        await _handleRecall(fromId, roomId, data, client);
      case 'reaction':
        await _handleReaction(fromId, roomId, data, client);
      case 'pin':
        await _handlePin(fromId, roomId, data, client);
      case 'search':
        _handleSearch(fromId, roomId, data, client);
      case 'status':
        _handleStatus(fromId, roomId, data, client);
      case 'profile':
        _handleProfile(fromId, roomId, data, client);
      case 'mute':
        await _handleMute(fromId, roomId, data, client);
      case 'unmute':
        await _handleUnmute(fromId, roomId, data, client);
      case 'set_global_admin':
        _handleSetGlobalAdmin(fromId, roomId, data, client);
      case 'set_room_admin':
        _handleSetRoomAdmin(fromId, roomId, data, client);
      case 'create_room':
        await _handleCreateRoom(fromId, roomId, data, client);
      case 'delete_room':
        await _handleDeleteRoom(fromId, data, client);
      case 'join_room':
        await _handleJoinRoom(fromId, roomId, data, client);
      case 'leave_room':
        await _handleLeaveRoom(fromId, client);
      case 'room_ban':
        _handleRoomBan(fromId, roomId, data, client);
      case 'room_unban':
        _handleRoomUnban(fromId, roomId, data, client);
      case 'set_announcement':
        _handleSetAnnouncement(fromId, roomId, data, client);
      case 'set_welcome_message':
        _handleSetWelcomeMessage(fromId, roomId, data, client);
      case 'set_room_password':
        _handleSetRoomPassword(fromId, roomId, data, client);
      case 'announce':
        _handleAnnounce(fromId, data, client);
      case 'kick':
        await _handleKick(fromId, roomId, data, client);

      case 'server_ban':
        if (client?.isGlobalAdmin != true) {
          client?.send({'messageType': 'error', 'message': '无权限'});
          return;
        }
        final banId = data['targetUserId'] as String?;
        if (banId == null) {
          client?.send({'messageType': 'error', 'message': '需要 targetUserId'});
          return;
        }
        addToBlacklist(banId);

      case 'server_unban':
        if (client?.isGlobalAdmin != true) {
          client?.send({'messageType': 'error', 'message': '无权限'});
          return;
        }
        final unbanId = data['targetUserId'] as String?;
        if (unbanId == null) {
          client?.send({'messageType': 'error', 'message': '需要 targetUserId'});
          return;
        }
        removeFromBlacklist(unbanId);

      case 'poke':
        final targetId = data['targetId'] as String?;
        if (targetId == null) return;
        final target = _clients[targetId];
        if (target == null) return;
        target.send(
          _makeSystemMessage({
            'event': 'poked',
            'fromId': fromId,
            'fromName': client?.displayName ?? fromId,
          }).toJson(),
        );

      default:
        client?.send({
          'messageType': 'error',
          'message': '未知消息类型：$messageType',
        });
    }
  }

  // ── 工具 ──────────────────────────────────────────────────────────────────

  List<MessageSegment> _parseSegments(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MessageSegment.fromJson)
          .toList();
    }
    return [TextSegment(raw.toString())];
  }

  void _logEvent(String msg) {
    final time = DateTime.now().toString().substring(11, 19);
    eventLog.add('[$time] $msg');
    if (eventLog.length > 200) eventLog.removeAt(0);
    onClientsChanged?.call();
  }

  String _name(String? id) =>
      id == null ? 'server' : (_clients[id]?.displayName ?? id);

  /// 将客户端移入大厅并通知
  void _moveToLobby(HubClientInfo target) {
    final fromRoomId = target.currentRoomId;
    _rooms[fromRoomId]?.participants.remove(target.userId);
    _rooms[_lobbyId]!.participants[target.userId] = target;
    target.currentRoomId = _lobbyId;
    target.send({
      'messageType': 'room_joined',
      'room': _rooms[_lobbyId]!.toJson(),
      'history': _rooms[_lobbyId]!.messageHistory
          .map((m) => m.toJson())
          .toList(),
    });
  }

  /// 广播「某人离开房间」system 消息
  void _broadcastLeft(String fromId, String roomId, HubClientInfo client) {
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.system,
        sender: client.toDto(),
        targetRoomIds: [roomId],
        segments: [
          TextSegment(
            jsonEncode({
              'event': 'client_left_room',
              'clientId': fromId,
              'clientName': client.displayName,
              'roomId': roomId,
            }),
          ),
        ],
      ),
    );
  }

  /// 广播「某人加入房间」system 消息
  void _broadcastJoined(String fromId, String roomId, HubClientInfo client) {
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.system,
        sender: client.toDto(),
        targetRoomIds: [roomId],
        segments: [
          TextSegment(
            jsonEncode({
              'event': 'client_joined_room',
              'client': client.toJson(),
              'roomId': roomId,
            }),
          ),
        ],
      ),
      exclude: fromId,
    );
  }

  void _onClientJoinedRoom(HubClientInfo client, HubRoom room) {
    // ── 公告（发给所有人，更新公告栏）─────────────────────────────
    if (room.announcements.isNotEmpty) {
      _broadcastToRoom(
        room.roomId,
        _makeSystemMessage({
          'event': 'room_announcement',
          'announcements': room.announcements,
          'setByUserId': room.ownerUserId,
          'setByName': _clients[room.ownerUserId]?.displayName ?? '',
        }),
      );
    }

    // ── 欢迎语（只发给刚加入的人）────────────────────────────────
    final welcome = room.welcomeMessage;
    if (welcome != null && welcome.isNotEmpty) {
      client.send(
        _makeSystemMessage({
          'event': 'room_welcome',
          'message': welcome,
        }).toJson(),
      );
    }
  }

  void _checkMentions(
    HubMessage message,
    String fromId,
    HubClientInfo? sender,
  ) {
    for (final seg in message.segments) {
      if (seg is! MentionSegment) continue;
      final target = _clients[seg.userId];
      if (target == null || seg.userId == fromId) continue;
      target.send(
        _makeSystemMessage({
          'event': 'mentioned',
          'fromId': fromId,
          'fromName': sender?.displayName ?? fromId,
          'messageId': message.messageId,
          'previewText': message.plainText,
        }).toJson(),
      );
    }
  }

  void _handleSetWelcomeMessage(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    final room = _rooms[roomId];
    if (room == null) return;
    if (!_isRoomAdmin(fromId, roomId)) {
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    room.welcomeMessage = data['welcomeMessage'] as String?;
    // 通知房间内所有人房间信息已更新
    _broadcastToRoom(
      roomId,
      _makeSystemMessage({
        'event': 'room_updated',
        'roomId': roomId,
        'changes': {'welcomeMessage': room.welcomeMessage},
      }),
    );
  }
}
