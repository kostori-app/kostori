part of 'package:kostori/foundation/hub_services/services.dart';

extension HubServiceHandler on HubService {
  // ── 允许客户端发送的消息类型白名单 ────────────────────────────────────────
  static const _allowedMessageTypes = {
    'broadcast',
    'unicast',
    'ping',
    'recall',
    'reaction',
    'pin',
    'search',
    'status',
    'profile',
    'mute',
    'unmute',
    'set_room_admin',
    'create_room',
    'delete_room',
    'join_room',
    'leave_room',
    'room_ban',
    'room_unban',
    'set_announcement',
    'remove_announcement',
    'set_welcome_message',
    'set_room_password',
    'announce',
    'kick',
    'server_ban',
    'server_unban',
    'poke',
    'invite_to_room',
    'invite_response',
    'unblock_invite',
    'set_allow_member_invite',
  };

  Future<void> handleClientMessage(
    String fromId,
    Map<String, dynamic> data,
  ) async {
    HubLog.info('send', '服务端接收: ${jsonEncode(data)}');
    final messageType = data['messageType'] as String? ?? 'broadcast';

    // ── 白名单校验：拒绝所有未知类型 ────────────────────────────────────────
    if (!_allowedMessageTypes.contains(messageType)) {
      _clients[fromId]?.send({
        'type': 'error',
        'message': '非法消息类型：$messageType',
      });
      HubLog.warning('HubService', '⚠️ 非法消息类型 "$messageType" from $fromId');
      return;
    }

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
        if (!_canOperateOn(fromId, banId)) return;
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
      case 'invite_to_room':
        await _handleInviteToRoom(fromId, roomId, data, client);
      case 'invite_response':
        await _handleInviteResponse(fromId, data, client);
      case 'set_allow_member_invite':
        if (!_isRoomAdmin(fromId, roomId)) {
          client?.send({'type': 'error', 'message': '无权限'});
          return;
        }
        _rooms[roomId]?.allowMemberInvite = data['value'] as bool? ?? false;
        _broadcastSystem(HubSystemEvent.roomUpdated, {
          'room': _rooms[roomId]!.toJson(),
        });
      case 'unblock_invite':
        final targetId = data['targetUserId'] as String?;
        if (targetId == null) return;
        _inviteCooldowns.remove('$targetId:$fromId');
        client?.send({
          'type': 'system',
          'event': 'invite_unblocked',
          'userId': targetId,
        });
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
    _broadcastSystem(HubSystemEvent.clientLeftRoom, {
      'clientId': fromId,
      'clientName': client.displayName,
      'client': client.toJson(),
      'roomId': roomId,
    });
  }

  void _broadcastJoined(String fromId, String roomId, HubClientInfo client) {
    _broadcastSystem(HubSystemEvent.clientJoinedRoom, {
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

  Future<void> _handleInviteToRoom(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final room = _rooms[roomId];
    if (room == null) return;

    // 权限：房管/全局管理员 或 房间开启了 allowMemberInvite
    final canInvite = _isRoomAdmin(fromId, roomId) || room.allowMemberInvite;
    if (!canInvite) {
      client?.send({'type': 'error', 'message': '该房间不允许普通成员邀请'});
      return;
    }

    final targetId = data['targetUserId'] as String?;
    if (targetId == null) return;
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'type': 'error', 'message': '用户不在线'});
      return;
    }

    final cooldownKey = '$fromId:$targetId';
    final lastInvite = _inviteCooldowns[cooldownKey];
    if (lastInvite != null &&
        DateTime.now().difference(lastInvite) < HubService._inviteCooldown) {
      final remaining =
          HubService._inviteCooldown - DateTime.now().difference(lastInvite);
      client?.send({
        'type': 'error',
        'message': '邀请太频繁，请等待 ${remaining.inSeconds} 秒',
      });
      return;
    }
    _inviteCooldowns[cooldownKey] = DateTime.now();

    // 只发邀请通知给目标用户
    _sendSystemTo(target, HubSystemEvent.roomInvite, {
      'fromId': fromId,
      'fromName': client?.displayName ?? fromId,
      'roomId': roomId,
      'roomName': room.roomName,
    });
  }

  Future<void> _handleInviteResponse(
    String fromId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final roomId = data['roomId'] as String?;
    final accepted = data['accepted'] as bool? ?? false;
    final inviterId = data['inviterId'] as String?;
    final block = data['block'] as bool? ?? false;
    if (roomId == null) return;

    // block：永久冷却，让对方无法再邀请你
    if (block && inviterId != null) {
      _inviteCooldowns['$inviterId:$fromId'] = DateTime.now().add(
        const Duration(days: 365),
      );
    }

    // 通知邀请者结果
    if (inviterId != null && _clients[inviterId] != null) {
      _sendSystemTo(
        _clients[inviterId]!,
        accepted
            ? HubSystemEvent.inviteAccepted
            : HubSystemEvent.inviteDeclined,
        {
          'userId': fromId,
          'userName': client?.displayName ?? fromId,
          'roomId': roomId,
          'blocked': block,
        },
      );
    }

    if (!accepted) return;

    // 同意则移入房间
    final room = _rooms[roomId];
    if (room == null || client == null) return;
    final fromRoomId = client.currentRoomId;
    _rooms[fromRoomId]?.participants.remove(fromId);
    _rooms[roomId]!.participants[fromId] = client;
    client.currentRoomId = roomId;
    client.send({
      'type': 'room_joined',
      'room': room.toJson(),
      'history': room.messageHistory.map((m) => m.toJson()).toList(),
    });
    _broadcastLeft(fromId, fromRoomId, client);
    _broadcastJoined(fromId, roomId, client);
    _onClientJoinedRoom(client, room);
  }
}
