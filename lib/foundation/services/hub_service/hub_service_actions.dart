part of 'package:kostori/foundation/services/services.dart';

extension HubServiceActions on HubService {
  Future<void> _handleRecall(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final messageId = data['messageId'] as String?;
    if (messageId == null) {
      client?.send({'messageType': 'error', 'message': '需要 messageId'});
      return;
    }
    final msg = _rooms[roomId]?.messageHistory.firstWhereOrNull(
      (m) => m.messageId == messageId,
    );
    if (msg == null) {
      client?.send({'messageType': 'error', 'message': '消息不存在'});
      return;
    }
    if (msg.sender.userId != fromId && !_isRoomAdmin(fromId, roomId)) {
      client?.send({'messageType': 'error', 'message': '无权限撤回'});
      return;
    }
    _rooms[roomId]!.messageHistory.removeWhere((m) => m.messageId == messageId);
    onMessageReceived?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.recall,
        sender: _serverDto,
        targetRoomIds: [roomId],
        segments: [TextSegment(messageId)],
      ),
    );
  }

  Future<void> _handleReaction(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final messageId = data['messageId'] as String?;
    final emojiId = data['emojiId'] as String?;
    if (messageId == null || emojiId == null) {
      client?.send({
        'messageType': 'error',
        'message': '需要 messageId 和 emojiId',
      });
      return;
    }
    final msg = _rooms[roomId]?.messageHistory.firstWhereOrNull(
      (m) => m.messageId == messageId,
    );
    if (msg == null) {
      client?.send({'messageType': 'error', 'message': '消息不存在'});
      return;
    }
    msg.toggleReaction(
      emojiId,
      HubReactionUser(userId: fromId, username: client?.userId ?? fromId),
    );
    onMessageReceived?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.reaction,
        sender: _serverDto,
        targetRoomIds: [roomId],
        segments: [
          ReactionSegment(
            targetMessageId: messageId,
            emojiId: emojiId,
            reactorUserId: fromId,
          ),
        ],
      ),
    );
  }

  Future<void> _handlePin(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final messageId = data['messageId'] as String?;
    if (messageId == null) {
      client?.send({'messageType': 'error', 'message': '需要 messageId'});
      return;
    }
    if (!_isRoomAdmin(fromId, roomId)) {
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    final room = _rooms[roomId];
    final msg = room?.messageHistory.firstWhereOrNull(
      (m) => m.messageId == messageId,
    );
    if (msg == null) {
      client?.send({'messageType': 'error', 'message': '消息不存在'});
      return;
    }
    room!.togglePin(msg);
    onMessageReceived?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.pin,
        sender: _serverDto,
        targetRoomIds: [roomId],
        segments: [TextSegment(messageId)],
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
      client?.send({'messageType': 'error', 'message': '需要 keyword'});
      return;
    }
    final results =
        _rooms[roomId]?.messageHistory
            .where(
              (m) => m.plainText.toLowerCase().contains(keyword.toLowerCase()),
            )
            .toList() ??
        [];
    client?.send({
      'messageType': 'search_result',
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
      (s) => s.name == (data['onlineStatus'] as String?),
    );
    if (statusVal == null) {
      client?.send({'messageType': 'error', 'message': '无效状态'});
      return;
    }
    client?.onlineStatus = statusVal;
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.system,
        sender: _serverDto,
        targetRoomIds: [roomId],
        segments: [
          TextSegment(
            jsonEncode({
              'event': 'status_changed',
              'clientId': fromId,
              'onlineStatus': statusVal.name,
            }),
          ),
        ],
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
    if (data['displayName'] != null) {
      client.displayName = data['displayName'] as String;
    }
    if (data['avatarUrl'] != null) {
      client.avatarUrl = data['avatarUrl'] as String;
    }
    if (data['biography'] != null) {
      client.biography = data['biography'] as String;
    }
    onClientsChanged?.call();

    // ← 改成广播给所有人，不限房间
    _broadcastAll(
      HubMessage(
        messageType: HubMessageType.system,
        sender: _serverDto,
        targetRoomIds: [],
        segments: [
          TextSegment(
            jsonEncode({'event': 'profile_updated', 'client': client.toJson()}),
          ),
        ],
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
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetUserId'] as String?;
    final seconds = data['seconds'] as int? ?? 300;
    if (targetId == null) {
      client?.send({'messageType': 'error', 'message': '需要 targetUserId'});
      return;
    }
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'messageType': 'error', 'message': '目标不存在'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      if (!_rooms[roomId]!.participants.containsKey(targetId)) {
        client?.send({'messageType': 'error', 'message': '目标不在当前房间'});
        return;
      }
      if (target.isGlobalAdmin) {
        client?.send({'messageType': 'error', 'message': '无法禁言全局管理员'});
        return;
      }
      if (_isRoomAdmin(targetId, roomId)) {
        client?.send({'messageType': 'error', 'message': '无法禁言房间管理员'});
        return;
      }
    }
    target.mutedUntil = DateTime.now().add(Duration(seconds: seconds));
    onClientsChanged?.call();
    _logEvent('🔇 ${_name(fromId)} muted ${_name(targetId)} for ${seconds}s');
    target.send({
      'messageType': 'system',
      'payload': {
        'event': 'you_are_muted',
        'seconds': seconds,
        'until': target.mutedUntil!.toIso8601String(),
      },
    });
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.system,
        sender: _serverDto,
        targetRoomIds: [roomId],
        segments: [
          TextSegment(
            jsonEncode({
              'event': 'user_muted',
              'clientId': targetId,
              'seconds': seconds,
              'by': fromId,
            }),
          ),
        ],
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
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetUserId'] as String?;
    if (targetId == null) {
      client?.send({'messageType': 'error', 'message': '需要 targetUserId'});
      return;
    }
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'messageType': 'error', 'message': '目标不存在'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      if (!_rooms[roomId]!.participants.containsKey(targetId)) {
        client?.send({'messageType': 'error', 'message': '目标不在当前房间'});
        return;
      }
      if (target.isGlobalAdmin) {
        client?.send({'messageType': 'error', 'message': '无法操作全局管理员'});
        return;
      }
      if (_isRoomAdmin(targetId, roomId)) {
        client?.send({'messageType': 'error', 'message': '无法操作房间管理员'});
        return;
      }
    }
    target.mutedUntil = null;
    onClientsChanged?.call();
    _logEvent('🔊 ${_name(fromId)} unmuted ${_name(targetId)}');
    target.send({
      'messageType': 'system',
      'payload': {'event': 'you_are_unmuted'},
    });
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.system,
        sender: _serverDto,
        targetRoomIds: [roomId],
        segments: [
          TextSegment(
            jsonEncode({
              'event': 'user_unmuted',
              'clientId': targetId,
              'by': fromId,
            }),
          ),
        ],
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
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetUserId'] as String?;
    final value = data['value'] as bool? ?? true;
    if (targetId == null) {
      client?.send({'messageType': 'error', 'message': '需要 targetUserId'});
      return;
    }
    _clients[targetId]?.isGlobalAdmin = value;
    if (value) {
      _adminIds.add(targetId);
      _clients[targetId]?.send({
        'messageType': 'system',
        'payload': {
          'event': 'blacklist_updated',
          'blacklist': _blacklist.toList(),
        },
      });
    } else {
      _adminIds.remove(targetId);
    }
    _saveAdmins();
    onClientsChanged?.call();
    _logEvent(
      '👑 ${_name(fromId)} ${value ? "granted" : "revoked"} global admin for ${_name(targetId)}',
    );
    _broadcastSystem('global_admin_changed', {
      'clientId': targetId,
      'isGlobalAdmin': value,
      'by': fromId,
    });
  }

  void _handleSetRoomAdmin(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) {
    final room = _rooms[roomId];
    if (room == null) return;
    if (client?.isGlobalAdmin != true && room.ownerUserId != fromId) {
      client?.send({
        'messageType': 'error',
        'message': '无权限，只有房主或全局管理员可以设置房间管理员',
      });
      return;
    }
    final targetId = data['targetUserId'] as String?;
    final value = data['value'] as bool? ?? true;
    if (targetId == null) {
      client?.send({'messageType': 'error', 'message': '需要 targetUserId'});
      return;
    }
    if (!room.participants.containsKey(targetId)) {
      client?.send({'messageType': 'error', 'message': '目标不在当前房间'});
      return;
    }
    if (value) {
      room.moderatorIds.add(targetId);
    } else {
      room.moderatorIds.remove(targetId);
    }
    onClientsChanged?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.system,
        sender: _serverDto,
        targetRoomIds: [roomId],
        segments: [
          TextSegment(
            jsonEncode({
              'event': 'room_admin_changed',
              'clientId': targetId,
              'isRoomAdmin': value,
              'roomId': roomId,
              'by': fromId,
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateRoom(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final newRoomName = (data['roomName'] as String?)?.trim();
    if (newRoomName == null || newRoomName.isEmpty) {
      client?.send({'messageType': 'error', 'message': '需要房间名称'});
      return;
    }
    if (newRoomName.toLowerCase() == 'lobby' ||
        newRoomName.toLowerCase() == 'Lobby'.tl.toLowerCase()) {
      client?.send({'messageType': 'error', 'message': '该名称已被保留，请换一个'});
      return;
    }
    final duplicate = _rooms.values.any(
      (r) =>
          r.roomId != _lobbyId &&
          r.roomName.toLowerCase() == newRoomName.toLowerCase(),
    );
    if (duplicate) {
      client?.send({'messageType': 'error', 'message': '房间名称已存在，请换一个'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      final existing = _rooms.values.firstWhereOrNull(
        (r) => r.ownerUserId == fromId,
      );
      if (existing != null) {
        client?.send({
          'messageType': 'error',
          'message': '每人只能创建一个房间，请先删除已有房间',
        });
        return;
      }
    }
    final newRoom = HubRoom(
      roomName: newRoomName,
      ownerUserId: fromId,
      announcements: data['announcement'] != null
          ? [data['announcement'] as String]
          : null,
      password: data['password'] as String?,
    );
    _rooms[newRoom.roomId] = newRoom;

    final oldRoomId = client?.currentRoomId ?? _lobbyId;
    _rooms[oldRoomId]?.participants.remove(fromId);
    _broadcastLeft(fromId, oldRoomId, client!);
    newRoom.participants[fromId] = client;
    client.currentRoomId = newRoom.roomId;
    onRoomsChanged?.call();
    onClientsChanged?.call();
    client.send({
      'messageType': 'room_joined',
      'room': newRoom.toJson(),
      'history': [],
    });
    _broadcastSystem('room_created', {'room': newRoom.toJson()});
    _broadcastJoined(fromId, newRoom.roomId, client);
  }

  Future<void> _handleDeleteRoom(
    String fromId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final targetRoomId = data['roomId'] as String?;
    if (targetRoomId == null) {
      client?.send({'messageType': 'error', 'message': '需要 roomId'});
      return;
    }
    if (targetRoomId == _lobbyId) {
      client?.send({'messageType': 'error', 'message': '无法删除大厅'});
      return;
    }
    final room = _rooms[targetRoomId];
    if (room == null) {
      client?.send({'messageType': 'error', 'message': '房间不存在'});
      return;
    }
    if (room.ownerUserId != fromId && client?.isGlobalAdmin != true) {
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    for (final member in room.participants.values.toList()) {
      _moveToLobby(member);
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
      client?.send({'messageType': 'error', 'message': '需要 roomId'});
      return;
    }
    final targetRoom = _rooms[targetRoomId];
    if (targetRoom == null) {
      client?.send({'messageType': 'error', 'message': '房间不存在'});
      return;
    }
    if (!targetRoom.validatePassword(fromId, pwd) &&
        client?.isGlobalAdmin != true) {
      client?.send({'messageType': 'error', 'message': '密码错误'});
      return;
    }
    if (targetRoom.bannedUserIds.contains(fromId)) {
      client?.send({'messageType': 'error', 'message': '你已被禁止进入该房间'});
      return;
    }
    _rooms[currentRoomId]?.participants.remove(fromId);
    _broadcastLeft(fromId, currentRoomId, client!);
    targetRoom.participants[fromId] = client;
    client.currentRoomId = targetRoomId;
    onClientsChanged?.call();
    client.send({
      'messageType': 'room_joined',
      'room': targetRoom.toJson(),
      'history': targetRoom.messageHistory.map((m) => m.toJson()).toList(),
    });
    _broadcastJoined(fromId, targetRoomId, client);
    _broadcastSystem('room_updated', {'room': targetRoom.toJson()});
    _broadcastSystem('room_updated', {'room': _rooms[currentRoomId]!.toJson()});
    _onClientJoinedRoom(client, _rooms[currentRoomId]!);
  }

  Future<void> _handleLeaveRoom(String fromId, HubClientInfo? client) async {
    final currentRoomId = client?.currentRoomId ?? _lobbyId;
    if (currentRoomId == _lobbyId) {
      client?.send({'messageType': 'error', 'message': '已在大厅'});
      return;
    }
    _rooms[currentRoomId]?.participants.remove(fromId);
    _broadcastLeft(fromId, currentRoomId, client!);
    _moveToLobby(client);
    onClientsChanged?.call();
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
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetUserId'] as String?;
    if (targetId == null) {
      client?.send({'messageType': 'error', 'message': '需要 targetUserId'});
      return;
    }
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'messageType': 'error', 'message': '目标不存在'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      if (target.isGlobalAdmin) {
        client?.send({'messageType': 'error', 'message': '无法封禁全局管理员'});
        return;
      }
      if (_isRoomAdmin(targetId, roomId)) {
        client?.send({'messageType': 'error', 'message': '无法封禁房间管理员'});
        return;
      }
    }
    banRoom.bannedUserIds.add(targetId);
    _logEvent(
      '🚫 ${_name(fromId)} banned ${_name(targetId)} from room "${banRoom.roomName}"',
    );
    if (banRoom.participants.containsKey(targetId)) {
      _moveToLobby(target);
      target.send({
        'messageType': 'system',
        'payload': {
          'event': 'you_are_room_banned',
          'roomId': roomId,
          'roomName': banRoom.roomName,
        },
      });
    }
    onClientsChanged?.call();
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.system,
        sender: _serverDto,
        targetRoomIds: [roomId],
        segments: [
          TextSegment(
            jsonEncode({
              'event': 'room_ban_updated',
              'clientId': targetId,
              'banned': true,
              'by': fromId,
            }),
          ),
        ],
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
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetUserId'] as String?;
    if (targetId == null) {
      client?.send({'messageType': 'error', 'message': '需要 targetUserId'});
      return;
    }
    unbanRoom.bannedUserIds.remove(targetId);
    onClientsChanged?.call();
    _logEvent(
      '✅ ${_name(fromId)} unbanned ${_name(targetId)} from room "${unbanRoom.roomName}"',
    );
    _clients[targetId]?.send({
      'messageType': 'system',
      'payload': {
        'event': 'you_are_room_unbanned',
        'roomId': roomId,
        'roomName': unbanRoom.roomName,
      },
    });
    _broadcastToRoom(
      roomId,
      HubMessage(
        messageType: HubMessageType.system,
        sender: _serverDto,
        targetRoomIds: [roomId],
        segments: [
          TextSegment(
            jsonEncode({
              'event': 'room_ban_updated',
              'clientId': targetId,
              'banned': false,
              'by': fromId,
            }),
          ),
        ],
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
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }

    // ── 支持单条添加 或 整列替换 ──────────────────────────────────
    if (data.containsKey('announcements')) {
      // 整列替换
      final list = List<String>.from(data['announcements'] as List? ?? []);
      room.announcements = list;
    } else {
      // 单条添加
      final announcement = data['announcement'] as String?;
      if (announcement == null || announcement.isEmpty) return;
      room.addAnnouncement(announcement);
    }

    final setByName = client?.displayName ?? fromId;

    // ── 广播 room_announcement（客户端更新公告栏）────────────────
    _broadcastToRoom(
      roomId,
      _makeSystemMessage({
        'event': 'room_announcement',
        'announcements': room.announcements,
        'setByUserId': fromId,
        'setByName': setByName,
      }),
    );

    // ── 广播 announcement_updated（通知有人修改了公告）───────────
    _broadcastToRoom(
      roomId,
      _makeSystemMessage({
        'event': 'announcement_updated',
        'by': fromId,
        'byName': setByName,
        'count': room.announcements.length,
      }),
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
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    room.password = data['password'] as String?;
    client?.send({
      'messageType': 'system',
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
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    _broadcastSystem('announcement', {
      'announcement': data['announcement'] ?? '',
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
      client?.send({'messageType': 'error', 'message': '无权限'});
      return;
    }
    final targetId = data['targetUserId'] as String?;
    if (targetId == null) {
      client?.send({'messageType': 'error', 'message': '需要 targetUserId'});
      return;
    }
    final kickTarget = _clients[targetId];
    if (kickTarget == null) {
      client?.send({'messageType': 'error', 'message': '目标不存在'});
      return;
    }

    if (client?.isGlobalAdmin != true) {
      // 房间踢出
      if (!_rooms[roomId]!.participants.containsKey(targetId)) {
        client?.send({'messageType': 'error', 'message': '目标不在当前房间'});
        return;
      }
      if (kickTarget.isGlobalAdmin) {
        client?.send({'messageType': 'error', 'message': '无法踢出全局管理员'});
        return;
      }
      if (_isRoomAdmin(targetId, roomId)) {
        client?.send({'messageType': 'error', 'message': '无法踢出房间管理员'});
        return;
      }
      _moveToLobby(kickTarget);
      kickTarget.send({
        'messageType': 'system',
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
          messageType: HubMessageType.system,
          sender: _serverDto,
          targetRoomIds: [roomId],
          segments: [
            TextSegment(
              jsonEncode({
                'event': 'client_kicked_from_room',
                'clientId': targetId,
                'by': fromId,
              }),
            ),
          ],
        ),
      );
    } else {
      // 服务器踢出
      kickTarget.send({
        'messageType': 'kicked',
        'message': '你已被管理员踢出',
        'operatorName': _name(fromId),
      });
      await Future.delayed(const Duration(milliseconds: 100));
      await kickTarget.connection.close(
        WebSocketStatus.policyViolation,
        'Kicked',
      );
      final kickRoomId = kickTarget.currentRoomId;
      _rooms[kickRoomId]?.participants.remove(targetId);
      _clients.remove(targetId);
      onClientsChanged?.call();
      _logEvent(
        '⚡ ${_name(fromId)} kicked ${kickTarget.displayName} from server',
      );
      _broadcastToRoom(
        kickRoomId,
        HubMessage(
          messageType: HubMessageType.system,
          sender: _serverDto,
          targetRoomIds: [kickRoomId],
          segments: [
            TextSegment(
              jsonEncode({
                'event': 'client_left',
                'clientId': targetId,
                'clientName': kickTarget.displayName,
              }),
            ),
          ],
        ),
      );
    }
  }

  HubMessage _makeSystemMessage(Map<String, dynamic> payload) => HubMessage(
    messageType: HubMessageType.system,
    sender: _serverDto,
    targetRoomIds: [],
    segments: [TextSegment(jsonEncode(payload))],
  );
}
