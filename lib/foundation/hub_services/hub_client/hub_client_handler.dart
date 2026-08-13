part of 'package:kostori/foundation/hub_services/services.dart';

extension HubClientHandler on HubClient {
  void _handleMessage(Map<String, dynamic> data) {
    HubLog.info('handle', '客户端接收: ${jsonEncode(data)}');
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
        HubLog.info(
          'HubClient',
          '✅ 鉴权成功  ID：${event.yourId}  在线：${event.clients.length}个',
        );
        onConnected?.call();
        // Android：连接 Hub 时启动前台服务通知保活
        HubKeepAlive.start();

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
        HubLog.info(
          'HubClient',
          '🚪 加入房间：${event.room.roomName}（离开：$prevRoomId）',
        );
        for (final fn in List.of(_messageListeners)) {
          fn(data);
        }

      case HubEventMessage():
        if (isBlocked(event.message.sender.userId)) return;
        if (event.isUnicast) {
          final otherId = event.message.sender.userId == myId
              ? null
              : event.message.sender.userId;
          if (otherId != null) {
            _addDmMessage(otherId, event.message);
            if (_s.activeDmUserId != otherId) {
              _incrementDmUnread(otherId);
              App.rootContext.showMessage(
                message:
                    '${event.message.sender.displayName}: ${event.message.plainText}',
                level: LogLevel.info,
                style: ToastStyle.topRight,
                icon: const Icon(Icons.message_outlined, size: 16),
              );
            }
          }
        } else {
          // 同步消息（KOSTORI_SYNC）每秒广播，不加入消息历史，
          // 否则聊天列表每秒重建导致图片闪烁
          if (!event.message.plainText.startsWith('KOSTORI_SYNC')) {
            _addMessageToRoom(event.message);
          }
        }
        for (final fn in List.of(_messageListeners)) {
          fn(data);
        }

      case HubEventPong():
        _pongTimeoutTimer?.cancel();
        HubLog.info('HubClient', 'pong');

      case HubEventError():
        App.rootContext.showMessage(
          message: event.message,
          level: LogLevel.error,
          style: ToastStyle.topRight,
        );
        for (final fn in List.of(_messageListeners)) {
          fn(data);
        }

      case HubEventSystem():
        _handleSystem(event, data);

      case HubEventUnknown():
        HubLog.warning('HubClient', '未知消息类型：${event.type}');
    }
  }

  void _handleSystem(HubEventSystem event, Map<String, dynamic> data) {
    switch (event) {
      case HubSystemServerShutdown():
        _shouldReconnect = false;
        _setState((s) => s.copyWith(isConnected: false, myId: null));
        App.rootContext.showMessage(
          message: t.serverShutdown,
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
                ? t.youAreNowAGlobalAdmin
                : t.yourGlobalAdminHasBeenRevoked,
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
                ? t.youAreNowARoomAdmin
                : t.yourRoomAdminHasBeenRevoked,
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
          message: '${t.youAreMutedFor} ${event.seconds} ${t.secondsUnit}',
          level: LogLevel.warning,
          style: ToastStyle.topRight,
        );

      case HubSystemYouAreUnmuted():
        App.rootContext.showMessage(
          message: t.youHaveBeenUnmuted,
          style: ToastStyle.topRight,
        );

      case HubSystemUserMuted():
        _patchClient(event.clientId, isMuted: event.isMuted);
        onClientsChanged?.call();

      case HubSystemYouAreRoomBanned():
        App.rootContext.showMessage(
          message: event.isBanned
              ? '${t.youAreBannedFromRoom}: ${event.roomName}'
              : '${t.youCanNowRejoinRoom}: ${event.roomName}',
          level: event.isBanned ? LogLevel.error : LogLevel.info,
          style: ToastStyle.topRight,
        );

      case HubSystemRoomBanUpdated():
        onClientsChanged?.call();

      case HubSystemKickedFromRoom():
        if (event.permanent) {
          App.rootContext.showMessage(
            message: 'Kicked from server by ${event.byName}',
            level: LogLevel.error,
            style: ToastStyle.topRight,
          );
        } else {
          App.rootContext.showMessage(
            message: 'Kicked from room by ${event.byName}',
            level: LogLevel.warning,
            style: ToastStyle.topRight,
          );
          for (final fn in List.of(_messageListeners)) {
            fn(data);
          }
        }

      case HubSystemClientKickedFromRoom():
        final rIdx = _s.roomList.indexWhere((r) => r.roomId == currentRoomId);
        if (rIdx != -1) {
          final updated = _s.roomList[rIdx].copyWith(
            participants: _s.roomList[rIdx].participants
                .where((p) => p.userId != event.clientId)
                .toList(),
          );
          final newRooms = [..._s.roomList];
          newRooms[rIdx] = updated;
          _setState((s) => s.copyWith(roomList: newRooms));
        }
        onClientsChanged?.call();

      case HubSystemMessageRecalled():
        for (final room in _s.roomList) {
          room.messageHistory.removeWhere(
            (m) => m.messageId == event.messageId,
          );
        }
        _setState((s) => s.copyWith(roomList: [...s.roomList]));

      case HubSystemRoomCreated():
        _upsertRoom(event.room);
        App.rootContext.showMessage(
          message: '${t.newRoom}: ${event.room.roomName}',
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
          message: t.roomDeletedMovedToLobby,
          level: LogLevel.warning,
        );
        onRoomListChanged?.call();

      case HubSystemRoomUpdated():
        _upsertRoom(event.room, preserveHistory: true);
        onRoomListChanged?.call();

      case HubSystemClientJoined():
        final newRooms = [..._s.roomList];
        // 机器人不加入任何房间（大厅/房间参与者列表均不含 bot），
        // 但加入 onlineClients 使其在 @ 列表可见
        final isBot = event.client.isBot;
        if (!isBot) {
          final lobbyIdx = newRooms.indexWhere(
            (r) => r.roomId == _s.lobbyRoomId,
          );
          if (lobbyIdx != -1) {
            final lobby = newRooms[lobbyIdx];
            final already = lobby.participants.any(
              (p) => p.userId == event.client.userId,
            );
            if (!already) {
              newRooms[lobbyIdx] = lobby.copyWith(
                participants: [...lobby.participants, event.client],
              );
            }
          }
        }
        _setState(
          (s) => s.copyWith(
            onlineClients: [
              ...s.onlineClients.where((c) => c.userId != event.client.userId),
              event.client,
            ],
            roomList: newRooms,
          ),
        );
        if (!isBot) {
          App.rootContext.showMessage(
            message: '${event.client.displayName} ${t.joinedTheServer}',
            level: LogLevel.info,
            style: ToastStyle.topLeft,
            icon: const Icon(Icons.login_outlined, size: 16),
          );
        }
        onClientsChanged?.call();
        onRoomListChanged?.call();

      case HubSystemClientLeft():
        final updatedClients = _s.onlineClients
            .where((c) => c.userId != event.clientId)
            .toList();

        final updatedRooms = _s.roomList.map((room) {
          final hadUser = room.participants.any(
            (p) => p.userId == event.clientId,
          );
          if (hadUser) {
            return room.copyWith(
              participants: room.participants
                  .where((p) => p.userId != event.clientId)
                  .toList(),
            );
          }
          return room;
        }).toList();

        _setState(
          (s) =>
              s.copyWith(onlineClients: updatedClients, roomList: updatedRooms),
        );
        App.rootContext.showMessage(
          message: '${event.clientName ?? ''} ${t.leftTheServer}',
          level: LogLevel.info,
          style: ToastStyle.topLeft,
          icon: const Icon(Icons.logout_outlined, size: 16),
        );
        onClientsChanged?.call();
        onRoomListChanged?.call();

      case HubSystemClientRoomChanged():
        final newRooms = [..._s.roomList];

        if (event.joined) {
          final rIdx = newRooms.indexWhere((r) => r.roomId == event.roomId);
          if (rIdx != -1) {
            final room = newRooms[rIdx];
            final already = room.participants.any(
              (p) => p.userId == event.client.userId,
            );
            if (!already) {
              newRooms[rIdx] = room.copyWith(
                participants: [...room.participants, event.client],
              );
            }
          }
        } else {
          final rIdx = newRooms.indexWhere((r) => r.roomId == event.roomId);
          if (rIdx != -1) {
            final room = newRooms[rIdx];
            newRooms[rIdx] = room.copyWith(
              participants: room.participants
                  .where((p) => p.userId != event.client.userId)
                  .toList(),
            );
          }
        }

        final updatedClients = _s.onlineClients
            .where((c) => c.userId != event.client.userId)
            .toList();
        updatedClients.add(event.client);

        _setState(
          (s) => s.copyWith(roomList: newRooms, onlineClients: updatedClients),
        );
        if (event.roomId == currentRoomId && event.client.userId != myId) {
          // 完整断连时（离开服务器）只提示"离开服务器"，抑制重复的"离开房间"
          if (event.joined && !event.leavingServer) {
            App.rootContext.showMessage(
              message: '${event.client.displayName} ${t.joinedTheRoom}',
              level: LogLevel.info,
              style: ToastStyle.topLeft,
              icon: const Icon(Icons.meeting_room_outlined, size: 16),
            );
          } else if (!event.joined && !event.leavingServer) {
            App.rootContext.showMessage(
              message: '${event.client.displayName} ${t.leftTheRoom}',
              level: LogLevel.info,
              style: ToastStyle.topLeft,
              icon: const Icon(Icons.exit_to_app_outlined, size: 16),
            );
          }
        }
        onRoomListChanged?.call();
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
            if (r.roomId != event.roomId) return r;
            return r.copyWith(announcements: event.announcements);
          }).toList();
          return s.copyWith(roomList: updatedRooms);
        });

      case HubSystemRoomWelcome():
        App.rootContext.showMessage(
          message: event.message,
          level: LogLevel.info,
          style: ToastStyle.top,
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
          message: '${event.fromName} ${t.pokedYou} 👉',
          level: LogLevel.info,
          style: ToastStyle.topRight,
          icon: const Icon(Icons.touch_app_outlined, size: 16),
        );

      case HubSystemAnnouncement():
        App.rootContext.showMessage(
          message: event.text,
          level: LogLevel.info,
          style: ToastStyle.topRight,
          icon: const Icon(Icons.campaign_outlined, size: 16),
        );

      case HubSystemUserReacted():
        break;

      case HubSystemRoomInvite():
        showDialog(
          context: App.rootContext,
          barrierDismissible: false,
          builder: (_) => ContentDialog(
            title: t.roomInvite,
            content: Text(
              '${event.fromName} ${t.invitedYouTo} ${event.roomName}',
            ),
            cancel: () {
              Navigator.pop(App.rootContext);
              respondToInvite(event.roomId, event.fromId, false);
            },
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(App.rootContext);
                  respondToInvite(
                    event.roomId,
                    event.fromId,
                    false,
                    block: true,
                  );
                  _setState(
                    (s) => s.copyWith(
                      blockedInviteUserIds: [
                        ...s.blockedInviteUserIds,
                        event.fromId,
                      ],
                    ),
                  );
                },
                child: Text(
                  t.declineAndBlock,
                  style: TextStyle(color: Colors.red),
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(App.rootContext);
                  respondToInvite(event.roomId, event.fromId, true);
                },
                child: Text(t.acceptInvite),
              ),
            ],
          ),
        );

      case HubSystemInviteResponse():
        App.rootContext.showMessage(
          message: event.accepted
              ? '${event.userName} ${t.acceptedYourInvite}'
              : event.blocked
              ? '${event.userName} ${t.blockedYourInvites}'
              : '${event.userName} ${t.declinedYourInvite}',
          level: event.accepted ? LogLevel.info : LogLevel.warning,
          style: ToastStyle.topRight,
        );

      case HubSystemUnknown():
        HubLog.warning('HubClient', '未知系统事件：${event.event}\n $data');
    }
    for (final fn in List.of(_messageListeners)) {
      fn(data);
    }
  }
}
