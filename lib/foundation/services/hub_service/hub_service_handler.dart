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
            'type': 'error',
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
          client?.send({'type': 'error', 'message': '单播需要指定 targetUserId 字段'});
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
          'type': 'pong',
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
      case 'remove_announcement':
        _handleRemoveAnnouncement(fromId, roomId, data, client);
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
          client?.send({'type': 'error', 'message': '无权限'});
          return;
        }
        final banId = data['targetUserId'] as String?;
        if (banId == null) {
          client?.send({'type': 'error', 'message': '需要 targetUserId'});
          return;
        }
        addToBlacklist(banId);

      case 'server_unban':
        if (client?.isGlobalAdmin != true) {
          client?.send({'type': 'error', 'message': '无权限'});
          return;
        }
        final unbanId = data['targetUserId'] as String?;
        if (unbanId == null) {
          client?.send({'type': 'error', 'message': '需要 targetUserId'});
          return;
        }
        removeFromBlacklist(unbanId);

      case 'poke':
        final targetId = data['targetId'] as String?;
        if (targetId == null) return;
        final target = _clients[targetId];
        if (target == null) return;
        _sendSystemTo(target, HubSystemEvent.poked, {
          'fromId': fromId,
          'fromName': client?.displayName ?? fromId,
        });

      default:
        client?.send({'type': 'error', 'message': '未知消息类型：$messageType'});
    }
  }

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

  void _moveToLobby(HubClientInfo target) {
    final fromRoomId = target.currentRoomId;
    _rooms[fromRoomId]?.participants.remove(target.userId);
    _rooms[_lobbyId]!.participants[target.userId] = target;
    target.currentRoomId = _lobbyId;
    target.send({
      'type': 'room_joined',
      'room': _rooms[_lobbyId]!.toJson(),
      'history': _rooms[_lobbyId]!.messageHistory
          .map((m) => m.toJson())
          .toList(),
    });
  }

  void _broadcastLeft(String fromId, String roomId, HubClientInfo client) {
    _broadcastSystemToRoom(roomId, HubSystemEvent.clientLeftRoom, {
      'clientId': fromId,
      'clientName': client.displayName,
      'client': client.toJson(),
      'roomId': roomId,
    });
  }

  void _broadcastJoined(String fromId, String roomId, HubClientInfo client) {
    _broadcastSystemToRoom(roomId, HubSystemEvent.clientJoinedRoom, {
      'client': client.toJson(),
      'roomId': roomId,
    }, exclude: fromId);
  }

  void _onClientJoinedRoom(HubClientInfo client, HubRoom room) {
    if (room.announcements.isNotEmpty) {
      _broadcastSystemToRoom(room.roomId, HubSystemEvent.roomAnnouncement, {
        'announcements': room.announcements,
        'setByUserId': room.ownerUserId,
        'setByName': _clients[room.ownerUserId]?.displayName ?? '',
      });
    }
    final welcome = room.welcomeMessage;
    if (welcome != null && welcome.isNotEmpty) {
      _sendSystemTo(client, HubSystemEvent.roomWelcome, {'message': welcome});
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
      _sendSystemTo(target, HubSystemEvent.mentioned, {
        'fromId': fromId,
        'fromName': sender?.displayName ?? fromId,
        'messageId': message.messageId,
        'previewText': message.plainText,
      });
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
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    room.welcomeMessage = data['welcomeMessage'] as String?;
    _broadcastSystem(HubSystemEvent.roomUpdated, {'room': room.toJson()});
  }
}
