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
      client?.send({'type': 'error', 'message': '需要 messageId'});
      return;
    }
    final msg = _rooms[roomId]?.messageHistory.firstWhereOrNull(
      (m) => m.messageId == messageId,
    );
    if (msg == null) {
      client?.send({'type': 'error', 'message': '消息不存在'});
      return;
    }
    if (msg.sender.userId != fromId && !_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限撤回'});
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
    _broadcastSystemToRoom(roomId, HubSystemEvent.messageRecalled, {
      'messageId': messageId,
      'recalledBy': client?.displayName ?? fromId,
    });
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
      client?.send({'type': 'error', 'message': '需要 messageId 和 emojiId'});
      return;
    }
    final msg = _rooms[roomId]?.messageHistory.firstWhereOrNull(
      (m) => m.messageId == messageId,
    );
    if (msg == null) {
      client?.send({'type': 'error', 'message': '消息不存在'});
      return;
    }
    final added = msg.toggleReaction(
      emojiId,
      HubReactionUser(userId: fromId, username: client?.displayName ?? fromId),
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
      exclude: fromId,
    );
    _broadcastSystemToRoom(roomId, HubSystemEvent.userReacted, {
      'messageId': messageId,
      'emojiId': emojiId,
      'fromId': fromId,
      'fromName': client?.displayName ?? fromId,
      'added': added,
    });
  }

  Future<void> _handlePin(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final messageId = data['messageId'] as String?;
    if (messageId == null) {
      client?.send({'type': 'error', 'message': '需要 messageId'});
      return;
    }
    if (!_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    final room = _rooms[roomId];
    final msg = room?.messageHistory.firstWhereOrNull(
      (m) => m.messageId == messageId,
    );
    if (msg == null) {
      client?.send({'type': 'error', 'message': '消息不存在'});
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
      client?.send({'type': 'error', 'message': '需要 keyword'});
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
      (s) => s.name == (data['onlineStatus'] as String?),
    );
    if (statusVal == null) {
      client?.send({'type': 'error', 'message': '无效状态'});
      return;
    }
    client?.onlineStatus = statusVal;
    _broadcastSystemToRoom(roomId, HubSystemEvent.statusChanged, {
      'clientId': fromId,
      'onlineStatus': statusVal.name,
    });
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
    _broadcastSystem(HubSystemEvent.profileUpdated, {
      'client': client.toJson(),
    });
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
    final targetId = data['targetUserId'] as String?;
    final seconds = data['seconds'] as int? ?? 300;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetUserId'});
      return;
    }
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'type': 'error', 'message': '目标不存在'});
      return;
    }
    if (!_canOperateOn(fromId, targetId)) return;
    if (client?.isGlobalAdmin != true) {
      if (!_rooms[roomId]!.participants.containsKey(targetId)) {
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
    _sendSystemTo(target, HubSystemEvent.youAreMuted, {
      'seconds': seconds,
      'until': target.mutedUntil!.toIso8601String(),
    });
    _broadcastSystemToRoom(roomId, HubSystemEvent.userMuted, {
      'clientId': targetId,
      'seconds': seconds,
      'by': fromId,
    });
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
    final targetId = data['targetUserId'] as String?;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetUserId'});
      return;
    }
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'type': 'error', 'message': '目标不存在'});
      return;
    }
    if (!_canOperateOn(fromId, targetId)) return;
    if (client?.isGlobalAdmin != true) {
      if (!_rooms[roomId]!.participants.containsKey(targetId)) {
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
    _sendSystemTo(target, HubSystemEvent.youAreUnmuted, {});
    _broadcastSystemToRoom(roomId, HubSystemEvent.userUnmuted, {
      'clientId': targetId,
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
      client?.send({'type': 'error', 'message': '无权限，只有房主或全局管理员可以设置房间管理员'});
      return;
    }
    final targetId = data['targetUserId'] as String?;
    final value = data['value'] as bool? ?? true;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetUserId'});
      return;
    }
    if (!room.participants.containsKey(targetId)) {
      client?.send({'type': 'error', 'message': '目标不在当前房间'});
      return;
    }
    if (value) {
      room.moderatorIds.add(targetId);
    } else {
      room.moderatorIds.remove(targetId);
    }
    onClientsChanged?.call();
    _broadcastSystemToRoom(roomId, HubSystemEvent.roomAdminChanged, {
      'clientId': targetId,
      'isRoomAdmin': value,
      'roomId': roomId,
      'by': fromId,
    });
  }

  Future<void> _handleCreateRoom(
    String fromId,
    String roomId,
    Map<String, dynamic> data,
    HubClientInfo? client,
  ) async {
    final newRoomName = (data['roomName'] as String?)?.trim();
    if (newRoomName == null || newRoomName.isEmpty) {
      client?.send({'type': 'error', 'message': '需要房间名称'});
      return;
    }
    if (newRoomName.toLowerCase() == 'lobby' ||
        newRoomName.toLowerCase() == 'Lobby'.tl.toLowerCase()) {
      client?.send({'type': 'error', 'message': '该名称已被保留，请换一个'});
      return;
    }
    final duplicate = _rooms.values.any(
      (r) =>
          r.roomId != _lobbyId &&
          r.roomName.toLowerCase() == newRoomName.toLowerCase(),
    );
    if (duplicate) {
      client?.send({'type': 'error', 'message': '房间名称已存在，请换一个'});
      return;
    }
    if (client?.isGlobalAdmin != true) {
      final existing = _rooms.values.firstWhereOrNull(
        (r) => r.ownerUserId == fromId,
      );
      if (existing != null) {
        client?.send({'type': 'error', 'message': '每人只能创建一个房间，请先删除已有房间'});
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
      'type': 'room_joined',
      'room': newRoom.toJson(),
      'history': [],
    });
    _broadcastSystem(HubSystemEvent.roomCreated, {'room': newRoom.toJson()});
    _broadcastJoined(fromId, newRoom.roomId, client);
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
    if (room.ownerUserId != fromId && client?.isGlobalAdmin != true) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }
    for (final member in room.participants.values.toList()) {
      _moveToLobby(member);
    }
    _rooms.remove(targetRoomId);
    onRoomsChanged?.call();
    _broadcastSystem(HubSystemEvent.roomDeleted, {'roomId': targetRoomId});
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
    if (!targetRoom.validatePassword(fromId, pwd) &&
        client?.isGlobalAdmin != true) {
      client?.send({'type': 'error', 'message': '密码错误'});
      return;
    }
    if (targetRoom.bannedUserIds.contains(fromId)) {
      client?.send({'type': 'error', 'message': '你已被禁止进入该房间'});
      return;
    }
    _rooms[currentRoomId]?.participants.remove(fromId);
    _broadcastLeft(fromId, currentRoomId, client!);
    targetRoom.participants[fromId] = client;
    client.currentRoomId = targetRoomId;
    onClientsChanged?.call();
    client.send({
      'type': 'room_joined',
      'room': targetRoom.toJson(),
      'history': targetRoom.messageHistory.map((m) => m.toJson()).toList(),
    });
    _broadcastJoined(fromId, targetRoomId, client);
    _onClientJoinedRoom(client, _rooms[targetRoomId]!);
  }

  Future<void> _handleLeaveRoom(String fromId, HubClientInfo? client) async {
    final currentRoomId = client?.currentRoomId ?? _lobbyId;
    if (currentRoomId == _lobbyId) {
      client?.send({'type': 'error', 'message': '已在大厅'});
      return;
    }
    _rooms[currentRoomId]?.participants.remove(fromId);
    _broadcastLeft(fromId, currentRoomId, client!);
    _moveToLobby(client);
    onClientsChanged?.call();
    _broadcastSystem(HubSystemEvent.roomUpdated, {
      'room': _rooms[_lobbyId]!.toJson(),
    });
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
    final targetId = data['targetUserId'] as String?;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetUserId'});
      return;
    }
    final target = _clients[targetId];
    if (target == null) {
      client?.send({'type': 'error', 'message': '目标不存在'});
      return;
    }
    if (!_canOperateOn(fromId, targetId)) return;
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
    banRoom.bannedUserIds.add(targetId);
    _logEvent(
      '🚫 ${_name(fromId)} banned ${_name(targetId)} from room "${banRoom.roomName}"',
    );
    if (banRoom.participants.containsKey(targetId)) {
      _moveToLobby(target);
      _sendSystemTo(target, HubSystemEvent.youAreRoomBanned, {
        'roomId': roomId,
        'roomName': banRoom.roomName,
      });
    }
    onClientsChanged?.call();
    _broadcastSystemToRoom(roomId, HubSystemEvent.roomBanUpdated, {
      'clientId': targetId,
      'banned': true,
      'by': fromId,
    });
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
    final targetId = data['targetUserId'] as String?;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetUserId'});
      return;
    }
    unbanRoom.bannedUserIds.remove(targetId);
    onClientsChanged?.call();
    _logEvent(
      '✅ ${_name(fromId)} unbanned ${_name(targetId)} from room "${unbanRoom.roomName}"',
    );
    if (_clients[targetId] != null) {
      _sendSystemTo(_clients[targetId]!, HubSystemEvent.youAreRoomUnbanned, {
        'roomId': roomId,
        'roomName': unbanRoom.roomName,
      });
    }
    _broadcastSystemToRoom(roomId, HubSystemEvent.roomBanUpdated, {
      'clientId': targetId,
      'banned': false,
      'by': fromId,
    });
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
    if (data.containsKey('announcements')) {
      room.announcements = List<String>.from(
        data['announcements'] as List? ?? [],
      );
    } else {
      final announcement = data['announcement'] as String?;
      if (announcement == null || announcement.isEmpty) return;
      room.addAnnouncement(announcement);
    }
    _broadcastSystemToRoom(roomId, HubSystemEvent.roomAnnouncement, {
      'announcements': room.announcements,
      'setByUserId': fromId,
      'setByName': client?.displayName ?? fromId,
      'roomId': roomId,
    });
  }

  void _handleRemoveAnnouncement(
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
    final index = data['index'] as int?;
    if (index == null) {
      client?.send({'type': 'error', 'message': '需要 index 字段'});
      return;
    }
    if (index == -1) {
      // -1：清空全部公告
      room.announcements.clear();
    } else {
      if (index < 0 || index >= room.announcements.length) {
        client?.send({'type': 'error', 'message': '公告索引越界'});
        return;
      }
      room.removeAnnouncement(index);
    }
    _logEvent(
      '📢 ${_name(fromId)} removed announcement[index=$index] in "${room.roomName}"',
    );
    _broadcastSystemToRoom(roomId, HubSystemEvent.roomAnnouncement, {
      'announcements': room.announcements,
      'setByUserId': fromId,
      'setByName': client?.displayName ?? fromId,
      'roomId': roomId,
    });
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
    onRoomsChanged?.call();
    _broadcastSystem(HubSystemEvent.roomUpdated, {'room': room.toJson()});
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
    _broadcastSystem(HubSystemEvent.announcement, {
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
    final isGlobalAdmin = client?.isGlobalAdmin == true;
    if (!isGlobalAdmin && !_isRoomAdmin(fromId, roomId)) {
      client?.send({'type': 'error', 'message': '无权限'});
      return;
    }

    final targetId = data['targetUserId'] as String?;
    if (targetId == null) {
      client?.send({'type': 'error', 'message': '需要 targetUserId'});
      return;
    }
    if (!_canOperateOn(fromId, targetId)) return;
    final kickTarget = _clients[targetId];
    if (kickTarget == null) {
      client?.send({'type': 'error', 'message': '目标不存在'});
      return;
    }

    if (!isGlobalAdmin) {
      if (!_rooms[roomId]!.participants.containsKey(targetId)) {
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
    }

    final targetRoomId = kickTarget.currentRoomId;
    final targetName = kickTarget.displayName;

    // 先通知被踢者，再由服务端处理状态变更
    _sendSystemTo(kickTarget, HubSystemEvent.kickedFromRoom, {
      'roomId': targetRoomId,
      'by': fromId,
      'byName': _name(fromId),
      'permanent': isGlobalAdmin,
    });
    final targetDto = kickTarget.toDto();
    if (isGlobalAdmin) {
      // 全局管理员：给客户端一帧时间收到事件后关闭连接
      await Future.delayed(const Duration(milliseconds: 120));
      await kickTarget.connection.close(
        WebSocketStatus.policyViolation,
        'Kicked',
      );
      _rooms[targetRoomId]?.participants.remove(targetId);
      _clients.remove(targetId);
      _logEvent('⚡ ${_name(fromId)} kicked $targetName from server');
      _broadcastSystem(HubSystemEvent.clientLeftRoom, {
        'client': targetDto.toJson(),
        'roomId': roomId,
      });
      _broadcastSystem(HubSystemEvent.clientLeft, {
        'clientId': targetId,
        'clientName': targetName,
      });
    } else {
      // 房间管理员：移回大厅
      _moveToLobby(kickTarget);
      _logEvent('👢 ${_name(fromId)} kicked ${_name(targetId)} from room');
      _broadcastSystem(HubSystemEvent.clientKickedFromRoom, {
        'clientId': targetId,
        'clientName': targetName,
        'by': fromId,
      });
    }
    onClientsChanged?.call();
  }

  bool _canOperateOn(String operatorId, String targetId) {
    // 目标是全局管理员，任何人都不能操作
    if (_clients[targetId]?.isGlobalAdmin == true) {
      _clients[operatorId]?.send({'type': 'error', 'message': '无法对全局管理员执行此操作'});
      return false;
    }
    return true;
  }
}
