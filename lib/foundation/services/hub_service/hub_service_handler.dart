part of 'package:kostori/foundation/services/services.dart';

extension HubServiceHandler on HubService {
  Future<void> handleClientMessage(
    String fromId,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'] as String? ?? 'broadcast';
    final toId = data['to'] as String?;
    final client = _clients[fromId];
    final roomId = client?.currentRoomId ?? _lobbyId;

    if (data['encrypted'] == true && data['payload'] is String) {
      try {
        final decrypted = HubCrypto.decrypt(data['payload'] as String);
        data['payload'] = jsonDecode(decrypted);
        data.remove('encrypted');
      } catch (_) {}
    }
    final payload = data['payload'] ?? data;

    switch (type) {
      case 'broadcast':
        if (client?.isMuted == true) {
          client?.send({
            'type': 'error',
            'message': '你已被禁言，解除时间：${client.mutedUntil!.toIso8601String()}',
          });
          return;
        }
        _broadcastToRoom(
          roomId,
          HubMessage(
            type: HubMessageType.broadcast,
            from: fromId,
            payload: payload,
            replyTo: data['replyTo'] as String?,
          ),
        );

      case 'unicast':
        if (toId == null) {
          client?.send({'type': 'error', 'message': '单播需要指定 to 字段'});
          return;
        }
        _unicast(
          HubMessage(
            type: HubMessageType.unicast,
            from: fromId,
            to: toId,
            payload: payload,
          ),
          roomId,
        );

      case 'ping':
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

      case 'set_room_password':
        _handleSetRoomPassword(fromId, roomId, data, client);

      case 'announce':
        _handleAnnounce(fromId, data, client);

      case 'kick':
        await _handleKick(fromId, roomId, data, client);

      default:
        client?.send({'type': 'error', 'message': '未知消息类型：$type'});
    }
  }

  // ── 事件日志 ──────────────────────────────────
  void _logEvent(String msg) {
    final time = DateTime.now().toString().substring(11, 19);
    eventLog.add('[$time] $msg');
    if (eventLog.length > 200) eventLog.removeAt(0);
    onClientsChanged?.call();
  }

  String _name(String? id) =>
      id == null ? 'server' : (_clients[id]?.name ?? id);

  // ── 各消息处理方法 ────────────────────────────

  Future<void> _handleRecall(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final msgId = data['msgId'] as String?;
    if (msgId == null) {
      client?.send({'type': 'error', 'message': '需要 msgId'});
      return;
    }
    final msg = _rooms[roomId]?.messages.firstWhereOrNull((m) => m.id == msgId);
    if (msg == null) {
      client?.send({'type': 'error', 'message': '消息不存在'});
      return;
    }
    if (msg.from != fromId && !_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限撤回'});
      return;
    }
    _rooms[roomId]!.messages.removeWhere((m) => m.id == msgId);
    onMessageReceived?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {'event': 'message_recalled', 'msgId': msgId, 'by': fromId},
      ),
    );
  }

  Future<void> _handleReaction(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final msgId = data['msgId'] as String?;
    final emoji = data['emoji'] as String?;
    if (msgId == null || emoji == null) {
      client?.send({'type': 'error', 'message': '需要 msgId 和 emoji'});
      return;
    }
    final msg = _rooms[roomId]?.messages.firstWhereOrNull((m) => m.id == msgId);
    if (msg == null) {
      client?.send({'type': 'error', 'message': '消息不存在'});
      return;
    }
    final users = msg.reactions.putIfAbsent(emoji, () => []);
    if (users.contains(fromId)) {
      users.remove(fromId);
      if (users.isEmpty) msg.reactions.remove(emoji);
    } else {
      users.add(fromId);
    }
    onMessageReceived?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'reaction_updated',
          'msgId': msgId,
          'emoji': emoji,
          'by': fromId,
          'reactions': msg.reactions,
        },
      ),
    );
  }

  Future<void> _handlePin(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final msgId = data['msgId'] as String?;
    if (msgId == null) {
      client?.send({'type': 'error', 'message': '需要 msgId'});
      return;
    }
    if (!_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    final msg = _rooms[roomId]?.messages.firstWhereOrNull((m) => m.id == msgId);
    if (msg == null) {
      client?.send({'type': 'error', 'message': '消息不存在'});
      return;
    }
    msg.isPinned = !msg.isPinned;
    onMessageReceived?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'message_pinned',
          'msgId': msgId,
          'isPinned': msg.isPinned,
          'by': fromId,
        },
      ),
    );
  }

  void _handleSearch(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    final keyword = data['keyword'] as String?;
    if (keyword == null || keyword.isEmpty) {
      client?.send({'type': 'error', 'message': '需要 keyword'});
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
    client?.send({
      'type': 'search_result',
      'keyword': keyword,
      'count': results.length,
      'results': results.map((m) => m.toJson()).toList(),
    });
  }

  void _handleStatus(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    final statusVal = UserStatus.values.firstWhereOrNull(
      (s) => s.name == (data['status'] as String?),
    );
    if (statusVal == null) {
      client?.send({'type': 'error', 'message': '无效状态'});
      return;
    }
    client?.status = statusVal;
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'status_changed',
          'clientId': fromId,
          'status': statusVal.name,
        },
      ),
    );
  }

  void _handleProfile(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    if (client == null) return;
    if (data['name'] != null) client.name = data['name'] as String;
    if (data['avatar'] != null) client.avatar = data['avatar'] as String;
    if (data['bio'] != null) client.bio = data['bio'] as String;
    onClientsChanged?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {'event': 'profile_updated', 'client': client.toJson()},
      ),
    );
  }

  Future<void> _handleMute(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    if (client?.isGlobalAdmin != true && !_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetId'] as String?;
    final seconds = data['seconds'] as int? ?? 300;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetId'});
      return;
    }
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'type': 'error', 'message': '目标不存在'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      if (!_rooms[roomId]!.members.containsKey(targetId)) {
        client?.send({'type': 'error', 'message': '目标不在当前房间'});
        return;
      }
      if (target.isGlobalAdmin) {
        client?.send({'type': 'error', 'message': '无法禁言全局管理员'});
        return;
      }
      if (_isRoomAdmin(targetId, roomId)) {
        client?.send({'type': 'error', 'message': '无法禁言房间管理员'});
        return;
      }
    }
    target.mutedUntil = DateTime.now().add(Duration(seconds: seconds));
    onClientsChanged?.call();
    _logEvent('🔇 ${_name(fromId)} muted ${_name(targetId)} for ${seconds}s');
    target.send({
      'type': 'system',
      'payload': {
        'event': 'you_are_muted',
        'seconds': seconds,
        'until': target.mutedUntil!.toIso8601String(),
      },
    });
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'user_muted',
          'clientId': targetId,
          'seconds': seconds,
          'by': fromId,
        },
      ),
    );
  }

  Future<void> _handleUnmute(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    if (client?.isGlobalAdmin != true && !_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetId'] as String?;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetId'});
      return;
    }
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'type': 'error', 'message': '目标不存在'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      if (!_rooms[roomId]!.members.containsKey(targetId)) {
        client?.send({'type': 'error', 'message': '目标不在当前房间'});
        return;
      }
      if (target.isGlobalAdmin) {
        client?.send({'type': 'error', 'message': '无法操作全局管理员'});
        return;
      }
      if (_isRoomAdmin(targetId, roomId)) {
        client?.send({'type': 'error', 'message': '无法操作房间管理员'});
        return;
      }
    }
    target.mutedUntil = null;
    onClientsChanged?.call();
    _logEvent('🔊 ${_name(fromId)} unmuted ${_name(targetId)}');
    target.send({
      'type': 'system',
      'payload': {'event': 'you_are_unmuted'},
    });
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {'event': 'user_unmuted', 'clientId': targetId, 'by': fromId},
      ),
    );
  }

  void _handleSetGlobalAdmin(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    if (client?.isGlobalAdmin != true) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetId'] as String?;
    final value = data['value'] as bool? ?? true;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetId'});
      return;
    }
    _clients[targetId]?.isGlobalAdmin = value;
    if (value) {
      _adminIds.add(targetId);
    } else {
      _adminIds.remove(targetId);
    }
    _saveAdmins();
    onClientsChanged?.call();
    _logEvent(
      '👑 ${_name(fromId)} ${value ? "granted" : "revoked"} global admin for ${_name(targetId)}',
    );
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'global_admin_changed',
          'clientId': targetId,
          'isGlobalAdmin': value,
          'by': fromId,
        },
      ),
    );
  }

  void _handleSetRoomAdmin(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    final room = _rooms[roomId];
    if (room == null) return;
    if (client?.isGlobalAdmin != true && room.ownerId != fromId) {
      client?.send({'type': 'error', 'message': '无权限，只有房主或全局管理员可以设置房间管理员'});
      return;
    }
    final targetId = data['targetId'] as String?;
    final value = data['value'] as bool? ?? true;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetId'});
      return;
    }
    if (!room.members.containsKey(targetId)) {
      client?.send({'type': 'error', 'message': '目标不在当前房间'});
      return;
    }
    if (value) {
      room.adminIds.add(targetId);
    } else {
      room.adminIds.remove(targetId);
    }
    onClientsChanged?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'room_admin_changed',
          'clientId': targetId,
          'isRoomAdmin': value,
          'roomId': roomId,
          'by': fromId,
        },
      ),
    );
  }

  Future<void> _handleCreateRoom(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final roomName = (data['name'] as String?)?.trim();
    if (roomName == null || roomName.isEmpty) {
      client?.send({'type': 'error', 'message': '需要房间名称'});
      return;
    }
    // ← 重名校验
    final duplicate = _rooms.values.any(
      (r) => r.id != _lobbyId && r.name.toLowerCase() == roomName.toLowerCase(),
    );
    if (duplicate) {
      client?.send({'type': 'error', 'message': '房间名称已存在，请换一个'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      final existing = _rooms.values.firstWhereOrNull(
        (r) => r.ownerId == fromId,
      );
      if (existing != null) {
        client?.send({'type': 'error', 'message': '每人只能创建一个房间，请先删除已有房间'});
        return;
      }
    }
    final newRoom = HubRoom(
      name: roomName,
      ownerId: fromId,
      announcement: data['announcement'] as String?,
      password: data['password'] as String?,
    );
    _rooms[newRoom.id] = newRoom;

    final oldRoomId = client?.currentRoomId ?? _lobbyId;
    _rooms[oldRoomId]?.members.remove(fromId);
    _broadcastToRoom(
      oldRoomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'client_left_room',
          'clientId': fromId,
          'roomId': oldRoomId,
        },
      ),
    );
    newRoom.members[fromId] = client!;
    client.currentRoomId = newRoom.id;
    onRoomsChanged?.call();
    onClientsChanged?.call();

    client.send({
      'type': 'room_joined',
      'room': newRoom.toJson(),
      'history': [],
    });
    _broadcastSystem('room_created', {'room': newRoom.toJson()});
    _broadcastToRoom(
      newRoom.id,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'client_joined_room',
          'client': client.toJson(),
          'roomId': newRoom.id,
        },
      ),
      exclude: fromId,
    );
  }

  Future<void> _handleDeleteRoom(
    String fromId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final targetRoomId = data['roomId'] as String?;
    if (targetRoomId == null) {
      client?.send({'type': 'error', 'message': '需要 roomId'});
      return;
    }
    if (targetRoomId == _lobbyId) {
      client?.send({'type': 'error', 'message': '无法删除大厅'});
      return;
    }
    final room = _rooms[targetRoomId];
    if (room == null) {
      client?.send({'type': 'error', 'message': '房间不存在'});
      return;
    }
    if (room.ownerId != fromId && client?.isGlobalAdmin != true) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    for (final member in room.members.values.toList()) {
      member.currentRoomId = _lobbyId;
      _rooms[_lobbyId]!.members[member.id] = member;
      member.send({
        'type': 'room_joined',
        'room': _rooms[_lobbyId]!.toJson(),
        'history': _rooms[_lobbyId]!.messages.map((m) => m.toJson()).toList(),
      });
    }
    _rooms.remove(targetRoomId);
    onRoomsChanged?.call();
    _broadcastSystem('room_deleted', {'roomId': targetRoomId});
  }

  Future<void> _handleJoinRoom(
    String fromId,
    String currentRoomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final targetRoomId = data['roomId'] as String?;
    final pwd = data['password'] as String?;
    if (targetRoomId == null) {
      client?.send({'type': 'error', 'message': '需要 roomId'});
      return;
    }
    final targetRoom = _rooms[targetRoomId];
    if (targetRoom == null) {
      client?.send({'type': 'error', 'message': '房间不存在'});
      return;
    }
    if (!targetRoom.validatePassword(pwd) && client?.isGlobalAdmin != true) {
      client?.send({'type': 'error', 'message': '密码错误'});
      return;
    }
    if (targetRoom.bannedIds.contains(fromId)) {
      client?.send({'type': 'error', 'message': '你已被禁止进入该房间'});
      return;
    }
    _rooms[currentRoomId]?.members.remove(fromId);
    _broadcastToRoom(
      currentRoomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'client_left_room',
          'clientId': fromId,
          'roomId': currentRoomId,
        },
      ),
    );
    targetRoom.members[fromId] = client!;
    client.currentRoomId = targetRoomId;
    onClientsChanged?.call();
    client.send({
      'type': 'room_joined',
      'room': targetRoom.toJson(),
      'history': targetRoom.messages.map((m) => m.toJson()).toList(),
    });
    _broadcastToRoom(
      targetRoomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'client_joined_room',
          'client': client.toJson(),
          'roomId': targetRoomId,
        },
      ),
      exclude: fromId,
    );
    _broadcastSystem('room_updated', {'room': targetRoom.toJson()});
    _broadcastSystem('room_updated', {'room': _rooms[currentRoomId]!.toJson()});
  }

  Future<void> _handleLeaveRoom(String fromId, HubClientInfo? client) async {
    final currentRoomId = client?.currentRoomId ?? _lobbyId;
    if (currentRoomId == _lobbyId) {
      client?.send({'type': 'error', 'message': '已在大厅'});
      return;
    }
    _rooms[currentRoomId]?.members.remove(fromId);
    _broadcastToRoom(
      currentRoomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'client_left_room',
          'clientId': fromId,
          'roomId': currentRoomId,
        },
      ),
    );
    _rooms[_lobbyId]!.members[fromId] = client!;
    client.currentRoomId = _lobbyId;
    onClientsChanged?.call();
    client.send({
      'type': 'room_joined',
      'room': _rooms[_lobbyId]!.toJson(),
      'history': _rooms[_lobbyId]!.messages.map((m) => m.toJson()).toList(),
    });
    _broadcastSystem('room_updated', {'room': _rooms[currentRoomId]!.toJson()});
    _broadcastSystem('room_updated', {'room': _rooms[_lobbyId]!.toJson()});
  }

  void _handleRoomBan(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    final banRoom = _rooms[roomId];
    if (banRoom == null) return;
    if (client?.isGlobalAdmin != true && !_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetId'] as String?;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetId'});
      return;
    }
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'type': 'error', 'message': '目标不存在'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      if (target.isGlobalAdmin) {
        client?.send({'type': 'error', 'message': '无法封禁全局管理员'});
        return;
      }
      if (_isRoomAdmin(targetId, roomId)) {
        client?.send({'type': 'error', 'message': '无法封禁房间管理员'});
        return;
      }
    }
    banRoom.bannedIds.add(targetId);
    _logEvent(
      '🚫 ${_name(fromId)} banned ${_name(targetId)} from room "${banRoom.name}"',
    );
    if (banRoom.members.containsKey(targetId)) {
      banRoom.members.remove(targetId);
      _rooms[_lobbyId]!.members[targetId] = target;
      target.currentRoomId = _lobbyId;
      target.send({
        'type': 'room_joined',
        'room': _rooms[_lobbyId]!.toJson(),
        'history': _rooms[_lobbyId]!.messages.map((m) => m.toJson()).toList(),
      });
      target.send({
        'type': 'system',
        'payload': {
          'event': 'you_are_room_banned',
          'roomId': roomId,
          'roomName': banRoom.name,
        },
      });
    }
    onClientsChanged?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'room_ban_updated',
          'clientId': targetId,
          'banned': true,
          'by': fromId,
        },
      ),
    );
  }

  void _handleRoomUnban(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    final unbanRoom = _rooms[roomId];
    if (unbanRoom == null) return;
    if (client?.isGlobalAdmin != true && !_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetId'] as String?;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetId'});
      return;
    }
    unbanRoom.bannedIds.remove(targetId);
    onClientsChanged?.call();
    _logEvent(
      '✅ ${_name(fromId)} unbanned ${_name(targetId)} from room "${unbanRoom.name}"',
    );
    _clients[targetId]?.send({
      'type': 'system',
      'payload': {
        'event': 'you_are_room_unbanned',
        'roomId': roomId,
        'roomName': unbanRoom.name,
      },
    });
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'room_ban_updated',
          'clientId': targetId,
          'banned': false,
          'by': fromId,
        },
      ),
    );
  }

  void _handleSetAnnouncement(
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
    room.announcement = data['announcement'] as String?;
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.system,
        from: 'server',
        payload: {
          'event': 'announcement_updated',
          'announcement': room.announcement,
          'by': fromId,
        },
      ),
    );
  }

  void _handleSetRoomPassword(
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
    room.password = data['password'] as String?;
    client?.send({
      'type': 'system',
      'payload': {'event': 'password_updated'},
    });
    onRoomsChanged?.call();
  }

  void _handleAnnounce(
    String fromId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    if (client?.isGlobalAdmin != true) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    _broadcastSystem('announcement', {
      'message': data['message'] ?? '',
      'by': fromId,
    });
  }

  Future<void> _handleKick(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    if (client?.isGlobalAdmin != true && !_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetId'] as String?;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetId'});
      return;
    }
    final kickTarget = _clients[targetId];
    if (kickTarget == null) {
      client?.send({'type': 'error', 'message': '目标不存在'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      if (!_rooms[roomId]!.members.containsKey(targetId)) {
        client?.send({'type': 'error', 'message': '目标不在当前房间'});
        return;
      }
      if (kickTarget.isGlobalAdmin) {
        client?.send({'type': 'error', 'message': '无法踢出全局管理员'});
        return;
      }
      if (_isRoomAdmin(targetId, roomId)) {
        client?.send({'type': 'error', 'message': '无法踢出房间管理员'});
        return;
      }
      _rooms[roomId]?.members.remove(targetId);
      _rooms[_lobbyId]!.members[targetId] = kickTarget;
      kickTarget.currentRoomId = _lobbyId;
      kickTarget.send({
        'type': 'room_joined',
        'room': _rooms[_lobbyId]!.toJson(),
        'history': _rooms[_lobbyId]!.messages.map((m) => m.toJson()).toList(),
      });
      kickTarget.send({
        'type': 'system',
        'payload': {
          'event': 'kicked_from_room',
          'roomId': roomId,
          'by': fromId,
        },
      });
      onClientsChanged?.call();
      _logEvent('👢 ${_name(fromId)} kicked ${_name(targetId)} from room');
      _broadcastToRoom(
        roomId,
        HubMessage(
          type: HubMessageType.system,
          from: 'server',
          payload: {
            'event': 'client_kicked_from_room',
            'clientId': targetId,
            'by': fromId,
          },
        ),
      );
    } else {
      kickTarget.send({
        'type': 'kicked',
        'message': '你已被管理员踢出',
        'operatorName': _name(fromId),
      });
      await Future.delayed(const Duration(milliseconds: 100));
      await kickTarget.socket.close(WebSocketStatus.policyViolation, 'Kicked');
      final kickRoomId = kickTarget.currentRoomId;
      _rooms[kickRoomId]?.members.remove(targetId);
      _clients.remove(targetId);
      onClientsChanged?.call();
      _logEvent('⚡ ${_name(fromId)} kicked ${kickTarget.name} from server');
      _broadcastToRoom(
        kickRoomId,
        HubMessage(
          type: HubMessageType.system,
          from: 'server',
          payload: {
            'event': 'client_left',
            'clientId': targetId,
            'clientName': kickTarget.name,
          },
        ),
      );
    }
  }
}
