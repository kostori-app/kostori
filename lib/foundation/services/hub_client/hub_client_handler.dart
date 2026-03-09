part of 'package:kostori/foundation/services/services.dart';

extension HubClientHandler on HubClient {
  void _handleMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'welcome':
        HubCrypto.init(_currentToken!);
        myId = data['yourId'];
        roomList = List<Map<String, dynamic>>.from(data['rooms'] ?? []);
        currentRoomId = data['room']?['id'];
        currentRoomName = data['room']?['name'];
        lobbyRoomId = data['room']?['id'];
        onlineClients = List<Map<String, dynamic>>.from(data['clients'] ?? []);
        final me = onlineClients.firstWhereOrNull((c) => c['id'] == myId);
        isGlobalAdmin = me?['isGlobalAdmin'] == true;
        Log.info('HubClient', '✅ 鉴权成功  ID：$myId  在线：${onlineClients.length}个');
        onConnected?.call();

      case 'room_joined':
        currentRoomId = data['room']?['id'];
        currentRoomName = data['room']?['name'];
        Log.info('HubClient', '🚪 加入房间：$currentRoomName');
        onMessage?.call(data);

      case 'broadcast':
        final from = data['from'] as String?;
        if (from != null && isBlocked(from)) return;
        messageHistory.add(Map<String, dynamic>.from(data));
        Log.info('HubClient', '广播  from:$from  ${data['payload']}');
        onMessage?.call(data);

      case 'unicast':
        final from = data['from'] as String?;
        if (from != null && isBlocked(from)) return;
        messageHistory.add(Map<String, dynamic>.from(data));
        Log.info('HubClient', '私信  from:$from  ${data['payload']}');
        onMessage?.call(data);

      case 'system':
        _handleSystem(data);

      case 'pong':
        Log.info('HubClient', 'pong');

      case 'kicked':
        final reason = data['reason'] as String? ?? 'kicked';
        final operator = (data['operatorName'] as String?) == 'server'
            ? "Server".tl
            : data['operatorName'] as String? ?? "Server".tl;
        final toastMsg = switch (reason) {
          'room_banned' => '${"Banned by".tl} $operator',
          'server_banned' => '${"Server banned by".tl} $operator',
          _ => '${"Kicked by".tl} $operator',
        };
        Log.warning('HubClient', '🚫 被踢出 reason:$reason by:$operator');
        App.rootContext.showMessage(
          message: toastMsg,
          level: reason.endsWith('banned') ? LogLevel.error : LogLevel.warning,
          style: ToastStyle.topRight,
        );
        onMessage?.call(data);

      case 'error':
        final msg = data['message'] as String? ?? 'Error'.tl;
        Log.warning('HubClient', '❌ 错误：$msg');
        App.rootContext.showMessage(
          message: msg,
          level: LogLevel.error,
          style: ToastStyle.topRight,
        );
        onMessage?.call(data);

      default:
        Log.warning('HubClient', '未知消息类型：${data['type']}');
    }
  }

  void _handleSystem(Map<String, dynamic> data) {
    final event = data['payload']?['event'] as String?;
    Log.info('HubClient', '系统：$event');

    final from = data['from'] as String?;
    if (from != null && from != 'server' && isBlocked(from)) return;

    switch (event) {
      // ── 服务端 ──────────────────────────────────────────────────────────

      case 'server_shutdown':
        Log.info('HubClient', '🛑 服务端关闭');
        App.rootContext.showMessage(
          message: 'Server shutdown'.tl,
          level: LogLevel.warning,
          style: ToastStyle.topRight,
        );

      // ── 管理员 ──────────────────────────────────────────────────────────

      case 'global_admin_changed':
        final targetId = data['payload']['clientId'] as String?;
        final isAdmin = data['payload']['isGlobalAdmin'] == true;
        if (targetId == myId) {
          isGlobalAdmin = isAdmin;
          Log.info('HubClient', '👑 全局管理员状态变更：$isGlobalAdmin');
          App.rootContext.showMessage(
            message: isAdmin
                ? 'You are now a global admin'.tl
                : 'Your global admin has been revoked'.tl,
            style: ToastStyle.topRight,
          );
        }
        if (targetId != null) {
          final idx = onlineClients.indexWhere((c) => c['id'] == targetId);
          if (idx != -1) onlineClients[idx]['isGlobalAdmin'] = isAdmin;
        }
        onClientsChanged?.call();

      case 'room_admin_changed':
        final rId = data['payload']['roomId'] as String?;
        final targetId = data['payload']['clientId'] as String?;
        final isAdmin = data['payload']['isRoomAdmin'] == true;
        if (targetId == myId) {
          App.rootContext.showMessage(
            message: isAdmin
                ? 'You are now a room admin'.tl
                : 'Your room admin has been revoked'.tl,
            style: ToastStyle.topRight,
          );
        }
        if (rId != null && targetId != null) {
          final rIdx = roomList.indexWhere((r) => r['id'] == rId);
          if (rIdx != -1) {
            final adminIds = List<String>.from(
              roomList[rIdx]['adminIds'] as List? ?? [],
            );
            if (isAdmin) {
              if (!adminIds.contains(targetId)) adminIds.add(targetId);
            } else {
              adminIds.remove(targetId);
            }
            roomList[rIdx]['adminIds'] = adminIds;
          }
        }
        onClientsChanged?.call();

      // ── 禁言 ────────────────────────────────────────────────────────────

      case 'you_are_muted':
        final seconds = data['payload']['seconds'];
        Log.warning('HubClient', '🔇 已被禁言 $seconds 秒');
        App.rootContext.showMessage(
          message: '${"You are muted for".tl} $seconds ${"seconds".tl}',
          level: LogLevel.warning,
          style: ToastStyle.topRight,
        );

      case 'you_are_unmuted':
        Log.info('HubClient', '🔊 已解除禁言');
        App.rootContext.showMessage(
          message: 'You have been unmuted'.tl,
          style: ToastStyle.topRight,
        );

      case 'user_muted':
      case 'user_unmuted':
        final targetId = data['payload']['clientId'] as String?;
        if (targetId != null) {
          final idx = onlineClients.indexWhere((c) => c['id'] == targetId);
          if (idx != -1) {
            onlineClients[idx]['isMuted'] = event == 'user_muted';
          }
        }
        onClientsChanged?.call();

      // ── 房间封禁 ─────────────────────────────────────────────────────────

      case 'you_are_room_banned':
        final roomName = data['payload']['roomName'] ?? '';
        Log.warning('HubClient', '🚫 已被禁止进入房间：$roomName');
        App.rootContext.showMessage(
          message: '${"You are banned from room".tl}: $roomName',
          level: LogLevel.error,
          style: ToastStyle.topRight,
        );

      case 'you_are_room_unbanned':
        final roomName = data['payload']['roomName'] ?? '';
        Log.info('HubClient', '✅ 已解除房间封禁：$roomName');
        App.rootContext.showMessage(
          message: '${"You can now rejoin room".tl}: $roomName',
          style: ToastStyle.topRight,
        );

      case 'kicked_from_room':
        Log.warning('HubClient', '👢 已被踢出房间');
        App.rootContext.showMessage(
          message: 'You have been kicked from the room'.tl,
          level: LogLevel.warning,
          style: ToastStyle.topRight,
        );

      // ── 消息 ────────────────────────────────────────────────────────────

      case 'message_recalled':
        final msgId = data['payload']['msgId'];
        Log.info('HubClient', '↩️ 消息已撤回：$msgId');

      case 'announcement_updated':
        final msg = data['payload']['announcement'] as String? ?? '';
        if (msg.isNotEmpty) {
          App.rootContext.showMessage(
            message: '📢 $msg',
            style: ToastStyle.topRight,
          );
        }

      // ── 房间 ────────────────────────────────────────────────────────────

      case 'room_created':
        final room = data['payload']['room'] as Map<String, dynamic>;
        roomList.removeWhere((r) => r['id'] == room['id']);
        roomList.add(room);
        Log.info('HubClient', '🏠 新房间：${room['name']}');
        App.rootContext.showMessage(
          message: '${"New room".tl}: ${room['name']}',
        );
        onRoomListChanged?.call();

      case 'room_deleted':
        final roomId = data['payload']['roomId'];
        roomList.removeWhere((r) => r['id'] == roomId);
        Log.info('HubClient', '🗑️ 房间已删除：$roomId');
        App.rootContext.showMessage(
          message: 'Room deleted, moved to lobby'.tl,
          level: LogLevel.warning,
        );
        onRoomListChanged?.call();

      case 'room_updated':
        final room = data['payload']['room'] as Map<String, dynamic>;
        final idx = roomList.indexWhere((r) => r['id'] == room['id']);
        if (idx != -1) {
          roomList[idx] = room;
        } else {
          roomList.add(room);
        }
        onRoomListChanged?.call();

      // ── 客户端上下线 ──────────────────────────────────────────────────────

      case 'client_joined':
        final client = data['payload']['client'] as Map<String, dynamic>;
        onlineClients.removeWhere((c) => c['id'] == client['id']);
        onlineClients.add(client);
        App.rootContext.showMessage(
          message: '${client['name'] ?? client['id']} ${"joined".tl}',
        );
        onClientsChanged?.call();

      case 'client_left':
        onlineClients.removeWhere(
          (c) => c['id'] == data['payload']['clientId'],
        );
        App.rootContext.showMessage(
          message: '${data['payload']['clientName'] ?? ''} ${"left".tl}',
        );
        onClientsChanged?.call();

      case 'client_joined_room':
      case 'client_left_room':
        final rId = data['payload']['roomId'] as String?;
        if (rId != null) {
          final rIdx = roomList.indexWhere((r) => r['id'] == rId);
          if (rIdx != -1) onRoomListChanged?.call();
        }
        onClientsChanged?.call();

      // ── 资料 / 状态 ───────────────────────────────────────────────────────

      case 'profile_updated':
        final client = data['payload']['client'] as Map<String, dynamic>;
        final idx = onlineClients.indexWhere((c) => c['id'] == client['id']);
        if (idx != -1) onlineClients[idx] = client;
        onClientsChanged?.call();

      case 'status_changed':
        final idx = onlineClients.indexWhere(
          (c) => c['id'] == data['payload']['clientId'],
        );
        if (idx != -1) {
          onlineClients[idx]['status'] = data['payload']['status'];
        }
        onClientsChanged?.call();

      // ── 其他无需特殊处理的事件 ─────────────────────────────────────────────
      case 'client_kicked_from_room':
      case 'room_ban_updated':
      case 'message_pinned':
      case 'reaction_updated':
        onClientsChanged?.call();
    }

    onMessage?.call(data);
  }
}
