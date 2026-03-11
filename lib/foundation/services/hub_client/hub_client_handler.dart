part of 'package:kostori/foundation/services/services.dart';

extension HubClientHandler on HubClient {
  void _handleMessage(Map<String, dynamic> data) {
    final event = HubEvent.fromJson(data);

    switch (event) {
      case HubEventWelcome():
        HubCrypto.init(_currentToken!);
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        _shouldReconnect = true;

        if (event.heartbeatInterval > 0) {
          _heartbeatInterval = Duration(milliseconds: event.heartbeatInterval);
          _startHeartbeat();
        }
        final rooms = event.rooms.toList();
        final idx = rooms.indexWhere(
          (r) => r.roomId == event.currentRoom.roomId,
        );
        if (idx != -1 && event.history.isNotEmpty) {
          rooms[idx].messageHistory.addAll(event.history);
        }
        final isAdmin =
            event.clients
                .firstWhereOrNull((c) => c.userId == event.yourId)
                ?.isGlobalAdmin ??
            false;
        _setState(
          (s) => s.copyWith(
            myId: event.yourId,
            isConnected: true,
            roomList: rooms,
            currentRoomId: event.currentRoom.roomId,
            currentRoomName: event.currentRoom.roomName,
            lobbyRoomId: event.currentRoom.roomId,
            onlineClients: event.clients,
            isGlobalAdmin: isAdmin,
            serverBannedIds: isAdmin ? event.blacklist : s.serverBannedIds,
            serverUploadEnabled: event.uploadEnabled,
          ),
        );
        Log.info(
          'HubClient',
          '✅ 鉴权成功  ID：${event.yourId}  在线：${event.clients.length}个',
        );
        onConnected?.call();

      case HubEventRoomJoined():
        final prevRoomId = currentRoomId;
        _upsertRoom(event.room, preserveHistory: true);
        final newRooms = [..._s.roomList];
        final rIdx = newRooms.indexWhere((r) => r.roomId == event.room.roomId);
        if (rIdx != -1) {
          newRooms[rIdx].messageHistory
            ..clear()
            ..addAll(event.history);
        }
        _setState(
          (s) => s.copyWith(
            currentRoomId: event.room.roomId,
            currentRoomName: event.room.roomName,
            roomList: newRooms,
          ),
        );
        Log.info('HubClient', '🚪 加入房间：${event.room.roomName}（离开：$prevRoomId）');
        onMessage?.call(data);

      case HubEventMessage():
        if (isBlocked(event.message.sender.userId)) return;
        _addMessageToRoom(event.message);
        Log.info(
          'HubClient',
          '${event.isUnicast ? "私信" : "广播"}  from:${event.message.sender.userId}',
        );
        onMessage?.call(data);

      case HubEventPong():
        _pongTimeoutTimer?.cancel();
        Log.info('HubClient', 'pong');

      case HubEventKicked():
        final toastMsg = switch (event.reason) {
          'room_banned' => '${"Banned by".tl} ${event.operatorName}',
          'server_banned' => '${"Server banned by".tl} ${event.operatorName}',
          'timeout' => 'Connection timed out'.tl,
          _ => '${"Kicked by".tl} ${event.operatorName}',
        };
        App.rootContext.showMessage(
          message: toastMsg,
          level: event.reason.endsWith('banned')
              ? LogLevel.error
              : LogLevel.warning,
          style: ToastStyle.topRight,
        );
        onMessage?.call(data);

      case HubEventError():
        App.rootContext.showMessage(
          message: event.message,
          level: LogLevel.error,
          style: ToastStyle.topRight,
        );
        onMessage?.call(data);

      case HubEventSystem():
        _handleSystem(event, data);

      case HubEventUnknown():
        Log.warning('HubClient', '未知消息类型：${event.type}');
    }
  }

  void _handleSystem(HubEventSystem event, Map<String, dynamic> data) {
    switch (event) {
      case HubSystemServerShutdown():
        _shouldReconnect = false;
        _setState((s) => s.copyWith(isConnected: false, myId: null)); // ← 加这行
        App.rootContext.showMessage(
          message: 'Server shutdown'.tl,
          level: LogLevel.warning,
          style: ToastStyle.topRight,
        );

      case HubSystemGlobalAdminChanged():
        if (event.clientId == myId) {
          _setState(
            (s) => s.copyWith(
              isGlobalAdmin: event.isGlobalAdmin,
              serverBannedIds: event.isGlobalAdmin ? s.serverBannedIds : [],
            ),
          );
          App.rootContext.showMessage(
            message: event.isGlobalAdmin
                ? 'You are now a global admin'.tl
                : 'Your global admin has been revoked'.tl,
            style: ToastStyle.topRight,
          );
        }
        _patchClient(event.clientId, isGlobalAdmin: event.isGlobalAdmin);
        onClientsChanged?.call();

      case HubSystemBlacklistUpdated():
        _setState((s) => s.copyWith(serverBannedIds: event.blacklist));
        onClientsChanged?.call();

      case HubSystemRoomAdminChanged():
        if (event.clientId == myId) {
          App.rootContext.showMessage(
            message: event.isRoomAdmin
                ? 'You are now a room admin'.tl
                : 'Your room admin has been revoked'.tl,
            style: ToastStyle.topRight,
          );
        }
        final rIdx = _s.roomList.indexWhere((r) => r.roomId == event.roomId);
        if (rIdx != -1) {
          final room = _s.roomList[rIdx];
          if (event.isRoomAdmin) {
            room.moderatorIds.add(event.clientId);
          } else {
            room.moderatorIds.remove(event.clientId);
          }
          _setState((s) => s.copyWith(roomList: [...s.roomList]));
        }
        onClientsChanged?.call();

      case HubSystemYouAreMuted():
        App.rootContext.showMessage(
          message: '${"You are muted for".tl} ${event.seconds} ${"seconds".tl}',
          level: LogLevel.warning,
          style: ToastStyle.topRight,
        );

      case HubSystemYouAreUnmuted():
        App.rootContext.showMessage(
          message: 'You have been unmuted'.tl,
          style: ToastStyle.topRight,
        );

      case HubSystemUserMuted():
        _patchClient(event.clientId, isMuted: event.isMuted);
        onClientsChanged?.call();

      case HubSystemRoomBanned():
        App.rootContext.showMessage(
          message: event.isBanned
              ? '${"You are banned from room".tl}: ${event.roomName}'
              : '${"You can now rejoin room".tl}: ${event.roomName}',
          level: event.isBanned ? LogLevel.error : LogLevel.info,
          style: ToastStyle.topRight,
        );

      case HubSystemKickedFromRoom():
        _setState((s) => s.copyWith(isConnected: false, myId: null)); // ← 加这行
        App.rootContext.showMessage(
          message: 'You have been kicked from the room'.tl,
          level: LogLevel.warning,
          style: ToastStyle.topRight,
        );

      case HubSystemMessageRecalled():
        for (final room in _s.roomList) {
          room.messageHistory.removeWhere(
            (m) => m.messageId == event.messageId,
          );
        }
        _setState((s) => s.copyWith(roomList: [...s.roomList]));

      case HubSystemAnnouncementUpdated():
        if (event.announcement.isNotEmpty) {
          App.rootContext.showMessage(
            message: '📢 ${event.announcement}',
            style: ToastStyle.topRight,
          );
        }

      case HubSystemRoomCreated():
        _upsertRoom(event.room);
        App.rootContext.showMessage(
          message: '${"New room".tl}: ${event.room.roomName}',
        );
        onRoomListChanged?.call();

      case HubSystemRoomDeleted():
        _setState(
          (s) => s.copyWith(
            roomList: s.roomList
                .where((r) => r.roomId != event.roomId)
                .toList(),
            currentRoomId: s.currentRoomId == event.roomId
                ? s.lobbyRoomId
                : s.currentRoomId,
            currentRoomName: s.currentRoomId == event.roomId
                ? 'Lobby'
                : s.currentRoomName,
          ),
        );
        App.rootContext.showMessage(
          message: 'Room deleted, moved to lobby'.tl,
          level: LogLevel.warning,
        );
        onRoomListChanged?.call();

      case HubSystemRoomUpdated():
        _upsertRoom(event.room, preserveHistory: true);
        onRoomListChanged?.call();

      case HubSystemClientJoined():
        _setState(
          (s) => s.copyWith(
            onlineClients: [
              ...s.onlineClients.where((c) => c.userId != event.client.userId),
              event.client,
            ],
          ),
        );
        final name = event.client.displayName;
        App.rootContext.showMessage(
          message: '$name ${"joined".tl}',
          level: LogLevel.info,
          style: ToastStyle.topLeft,
        );
        onClientsChanged?.call();

      case HubSystemClientLeft():
        _setState(
          (s) => s.copyWith(
            onlineClients: s.onlineClients
                .where((c) => c.userId != event.clientId)
                .toList(),
          ),
        );
        App.rootContext.showMessage(
          message: '${event.clientName ?? ''} ${"left".tl}',
          level: LogLevel.info,
          style: ToastStyle.topLeft,
        );
        onClientsChanged?.call();

      case HubSystemClientRoomChanged():
        final rIdx = _s.roomList.indexWhere((r) => r.roomId == event.roomId);
        if (rIdx != -1) onRoomListChanged?.call();
        onClientsChanged?.call();

      case HubSystemProfileUpdated():
        _setState(
          (s) => s.copyWith(
            onlineClients: s.onlineClients
                .map((c) => c.userId == event.client.userId ? event.client : c)
                .toList(),
          ),
        );
        onClientsChanged?.call();

      case HubSystemStatusChanged():
        _patchClient(event.clientId, onlineStatus: event.onlineStatus);
        onClientsChanged?.call();

      case HubSystemRoomAnnouncement():
        _setState((s) {
          final updatedRooms = s.roomList.map((r) {
            if (r.roomId != s.currentRoomId) return r;
            return r.copyWith(announcements: event.announcements);
          }).toList();
          return s.copyWith(roomList: updatedRooms);
        });

      case HubSystemRoomWelcome():
        // 欢迎语弹 toast
        App.rootContext.showMessage(
          message: event.message,
          level: LogLevel.info,
          style: ToastStyle.topLeft,
          icon: const Icon(Icons.waving_hand_outlined, size: 16),
        );
      case HubSystemMentioned():
        App.rootContext.showMessage(
          message: '@${event.fromName}: ${event.previewText}',
          level: LogLevel.info,
          style: ToastStyle.topRight,
          icon: const Icon(Icons.alternate_email, size: 16),
        );

      case HubSystemPoked():
        App.rootContext.showMessage(
          message: '${event.fromName} ${"poked you".tl} 👉',
          level: LogLevel.info,
          style: ToastStyle.topRight,
          icon: const Icon(Icons.touch_app_outlined, size: 16),
        );

      case HubSystemUnknown():
        Log.warning('HubClient', '未知系统事件：${event.event}');
    }
    onMessage?.call(data);
  }
}
