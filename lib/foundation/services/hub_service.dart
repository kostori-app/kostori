part of 'package:kostori/foundation/services/services.dart';

// 消息类型
enum HubMessageType { broadcast, unicast, system }

// 用户状态
enum UserStatus { online, away, busy, offline }

class HubMessage {
  final String id;
  final HubMessageType type;
  final String from;
  final String? to;
  final dynamic payload;
  final DateTime time;
  final String? replyTo;
  bool isPinned;
  Map<String, List<String>> reactions;

  HubMessage({
    String? id,
    required this.type,
    required this.from,
    this.to,
    required this.payload,
    this.replyTo,
    this.isPinned = false,
    Map<String, List<String>>? reactions,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toRadixString(36),
       time = DateTime.now(),
       reactions = reactions ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'from': from,
    'to': to,
    'payload': payload,
    'time': time.toIso8601String(),
    'replyTo': replyTo,
    'isPinned': isPinned,
    'reactions': reactions,
  };
}

class HubClientInfo {
  final String id;
  String? name;
  final WebSocket socket;
  final DateTime connectedAt;
  String? avatar;
  String? bio;
  UserStatus status;
  bool isGlobalAdmin;
  DateTime? mutedUntil;
  String currentRoomId;

  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());

  HubClientInfo({
    required this.id,
    required this.socket,
    this.name,
    this.avatar,
    this.bio,
    this.status = UserStatus.online,
    this.isGlobalAdmin = false,
    this.mutedUntil,
    this.currentRoomId = 'lobby',
  }) : connectedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name ?? id,
    'connectedAt': connectedAt.toIso8601String(),
    'avatar': avatar,
    'bio': bio,
    'status': status.name,
    'isGlobalAdmin': isGlobalAdmin,
    'isMuted': isMuted,
    'mutedUntil': mutedUntil?.toIso8601String(),
    'currentRoomId': currentRoomId,
  };

  void send(Map<String, dynamic> data) {
    try {
      socket.add(jsonEncode(data));
    } catch (_) {}
  }
}

class HubRoom {
  final String id;
  String name;
  String? announcement;
  String? password;
  final String ownerId;
  final DateTime createdAt;
  final Map<String, HubClientInfo> members = {};
  final List<HubMessage> messages = [];
  final Set<String> adminIds = {};
  static const _maxHistory = 100;
  final Set<String> bannedIds = {};

  HubRoom({
    String? id,
    required this.name,
    required this.ownerId,
    this.announcement,
    this.password,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toRadixString(36),
       createdAt = DateTime.now();

  bool get isLocked => password != null && password!.isNotEmpty;

  bool validatePassword(String? pwd) {
    if (!isLocked) return true;
    return pwd == password;
  }

  bool isAdmin(String clientId) =>
      ownerId == clientId || adminIds.contains(clientId);

  void addMessage(HubMessage msg) {
    messages.add(msg);
    if (messages.length > _maxHistory) messages.removeAt(0);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'announcement': announcement,
    'ownerId': ownerId,
    'adminIds': adminIds.toList(), // ← 加这行
    'memberCount': members.length,
    'members': members.values.map((m) => m.toJson()).toList(),
    'isLocked': isLocked,
    'createdAt': createdAt.toIso8601String(),
    'bannedIds': bannedIds.toList(),
  };
}

class HubService extends BaseHttpService {
  HubService._internal();

  static final HubService _instance = HubService._internal();

  factory HubService() => _instance;

  final Map<String, HubClientInfo> _clients = {};
  final Map<String, HubRoom> _rooms = {};

  final Set<String> _blacklist = {}; // 黑名单 deviceId 列表
  static const _lobbyId = 'lobby';
  int _clientCounter = 0;

  List<HubClientInfo> get clients => _clients.values.toList();

  int get clientCount => _clients.length;

  List<HubRoom> get rooms => _rooms.values.toList();

  List<HubMessage> get messageHistory =>
      List.unmodifiable(_rooms[_lobbyId]?.messages ?? []);

  // HubService 里加
  int get blacklistCount => _blacklist.length;

  List<String> get blacklist => _blacklist.toList();

  // 持久化管理员列表
  final Set<String> _adminIds = {};

  // 服务端直接指定管理员（启动时调用）
  void addAdmin(String clientId) => _adminIds.add(clientId);

  void removeAdmin(String clientId) => _adminIds.remove(clientId);

  static const _adminKey = 'hub_admin_ids';

  void _loadAdmins() {
    final raw = appdata.implicitData[_adminKey];
    if (raw is List) _adminIds.addAll(raw.cast<String>());
  }

  void _saveAdmins() {
    appdata.implicitData[_adminKey] = _adminIds.toList();
    appdata.writeImplicitData();
  }

  bool _isRoomAdmin(String clientId, String roomId) =>
      _clients[clientId]?.isGlobalAdmin == true ||
      _rooms[roomId]?.isAdmin(clientId) == true;

  String get lobbyId => _lobbyId;

  VoidCallback? onMessageReceived;
  VoidCallback? onClientsChanged;
  VoidCallback? onRoomsChanged;

  @override
  void registerRoutes() {
    // 初始化大厅
    _rooms[_lobbyId] = HubRoom(id: _lobbyId, name: 'Lobby', ownerId: 'server');

    // ── WebSocket 主连接 ──────────────────────
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
            _clientCounter++;
            final rawName = data['name'] as String?;
            clientName =
                '${rawName?.isNotEmpty == true ? rawName : clientId}#$_clientCounter';

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
              isGlobalAdmin: _adminIds.contains(clientId), // ← 只认持久化列表
            );
            if (client.isGlobalAdmin) {
              Log.info('HubService', '👑 管理员上线：$clientName');
            }
            _clients[clientId] = client;

            // 自动加入大厅
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

          await _handleClientMessage(clientId!, data);
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

    // ── HTTP 接口 ─────────────────────────────
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

  // ── 消息处理 ──────────────────────────────

  Future<void> _handleClientMessage(
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
        final msgId = data['msgId'] as String?;
        if (msgId == null) {
          client?.send({'type': 'error', 'message': '需要 msgId'});
          return;
        }
        final msg = _rooms[roomId]?.messages.firstWhereOrNull(
          (m) => m.id == msgId,
        );
        if (msg == null) {
          client?.send({'type': 'error', 'message': '消息不存在'});
          return;
        }
        // 自己的消息可以撤回，房间管理员可以撤回任何人的
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
            payload: {
              'event': 'message_recalled',
              'msgId': msgId,
              'by': fromId,
            },
          ),
        );

      case 'reaction':
        final msgId = data['msgId'] as String?;
        final emoji = data['emoji'] as String?;
        if (msgId == null || emoji == null) {
          client?.send({'type': 'error', 'message': '需要 msgId 和 emoji'});
          return;
        }
        final msg = _rooms[roomId]?.messages.firstWhereOrNull(
          (m) => m.id == msgId,
        );
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

      case 'pin':
        final msgId = data['msgId'] as String?;
        if (msgId == null) {
          client?.send({'type': 'error', 'message': '需要 msgId'});
          return;
        }
        if (!_isRoomAdmin(fromId, roomId)) {
          // ← 改成房间管理员
          client?.send({'type': 'error', 'message': '无权限'});
          return;
        }
        final msg = _rooms[roomId]?.messages.firstWhereOrNull(
          (m) => m.id == msgId,
        );
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

      case 'search':
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

      case 'status':
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

      case 'profile':
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

      case 'mute':
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
        // 房间管理员只能禁言自己房间内的成员
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

      case 'unmute':
        if (client?.isGlobalAdmin != true && !_isRoomAdmin(fromId, roomId)) {
          client?.send({'type': 'error', 'message': '无权限'});
          return;
        }
        final targetId = data['targetId'] as String?;
        if (targetId == null) {
          client?.send({'type': 'error', 'message': '需要 targetId'});
          return;
        }
        final unmuteTarget = _clients[targetId];
        if (unmuteTarget == null) {
          client?.send({'type': 'error', 'message': '目标不存在'});
          return;
        }
        // 房间管理员只能解禁自己房间内的成员
        if (client?.isGlobalAdmin != true) {
          if (!_rooms[roomId]!.members.containsKey(targetId)) {
            client?.send({'type': 'error', 'message': '目标不在当前房间'});
            return;
          }
          if (unmuteTarget.isGlobalAdmin) {
            client?.send({'type': 'error', 'message': '无法操作全局管理员'});
            return;
          }
          if (_isRoomAdmin(targetId, roomId)) {
            client?.send({'type': 'error', 'message': '无法操作房间管理员'});
            return;
          }
        }
        unmuteTarget.mutedUntil = null;
        onClientsChanged?.call();
        unmuteTarget.send({
          'type': 'system',
          'payload': {'event': 'you_are_unmuted'},
        });
        _broadcastToRoom(
          roomId,
          HubMessage(
            type: HubMessageType.system,
            from: 'server',
            payload: {
              'event': 'user_unmuted',
              'clientId': targetId,
              'by': fromId,
            },
          ),
        );

      case 'set_global_admin':
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

      case 'set_room_admin':
        // 全局管理员或房间拥有者才能设置房间管理员
        // 房间管理员（非拥有者）不能设置房间管理员
        final setAdminRoom = _rooms[roomId];
        if (setAdminRoom == null) return;
        if (client?.isGlobalAdmin != true && setAdminRoom.ownerId != fromId) {
          client?.send({'type': 'error', 'message': '无权限，只有房主或全局管理员可以设置房间管理员'});
          return;
        }
        final targetId = data['targetId'] as String?;
        final value = data['value'] as bool? ?? true;
        if (targetId == null) {
          client?.send({'type': 'error', 'message': '需要 targetId'});
          return;
        }
        if (!setAdminRoom.members.containsKey(targetId)) {
          client?.send({'type': 'error', 'message': '目标不在当前房间'});
          return;
        }
        if (value) {
          setAdminRoom.adminIds.add(targetId);
        } else {
          setAdminRoom.adminIds.remove(targetId);
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

      case 'create_room':
        final roomName = data['name'] as String?;
        if (roomName == null || roomName.isEmpty) {
          client?.send({'type': 'error', 'message': '需要房间名称'});
          return;
        }
        // 全局管理员不限制创建数量，普通用户只能创建一个
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
        onRoomsChanged?.call();
        client?.send({'type': 'room_created', 'room': newRoom.toJson()});
        _broadcastSystem('room_created', {'room': newRoom.toJson()});

      case 'delete_room': // ← 加在 create_room 后面
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
            'history': _rooms[_lobbyId]!.messages
                .map((m) => m.toJson())
                .toList(),
          });
        }
        _rooms.remove(targetRoomId);
        onRoomsChanged?.call();
        _broadcastSystem('room_deleted', {'roomId': targetRoomId});

      case 'join_room':
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
        if (!targetRoom.validatePassword(pwd) &&
            client?.isGlobalAdmin != true) {
          client?.send({'type': 'error', 'message': '密码错误'});
          return;
        }
        // ← 检查房间黑名单
        if (targetRoom.bannedIds.contains(fromId)) {
          client?.send({'type': 'error', 'message': '你已被禁止进入该房间'});
          return;
        }
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

      case 'room_ban':
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
        final banTarget = _clients[targetId];
        if (banTarget == null) {
          client?.send({'type': 'error', 'message': '目标不存在'});
          return;
        }
        // 房间管理员不能封禁全局管理员和其他房间管理员
        if (client?.isGlobalAdmin != true) {
          if (banTarget.isGlobalAdmin) {
            client?.send({'type': 'error', 'message': '无法封禁全局管理员'});
            return;
          }
          if (_isRoomAdmin(targetId, roomId)) {
            client?.send({'type': 'error', 'message': '无法封禁房间管理员'});
            return;
          }
        }
        banRoom.bannedIds.add(targetId);
        // 如果目标在房间内，踢出
        if (banRoom.members.containsKey(targetId)) {
          banRoom.members.remove(targetId);
          _rooms[_lobbyId]!.members[targetId] = banTarget;
          banTarget.currentRoomId = _lobbyId;
          banTarget.send({
            'type': 'room_joined',
            'room': _rooms[_lobbyId]!.toJson(),
            'history': _rooms[_lobbyId]!.messages
                .map((m) => m.toJson())
                .toList(),
          });
          banTarget.send({
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

      case 'room_unban':
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

      case 'leave_room':
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

      case 'set_announcement':
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

      case 'set_room_password':
        final room = _rooms[roomId];
        if (room == null) return;
        if (!_isRoomAdmin(fromId, roomId)) {
          // ← 改成房间管理员
          client?.send({'type': 'error', 'message': '无权限'});
          return;
        }
        room.password = data['password'] as String?;
        client?.send({
          'type': 'system',
          'payload': {'event': 'password_updated'},
        });
        onRoomsChanged?.call();

      // 全局公告（不限房间）
      case 'announce':
        if (client?.isGlobalAdmin != true) {
          client?.send({'type': 'error', 'message': '无权限'});
          return;
        }
        _broadcastSystem('announcement', {
          'message': data['message'] ?? '',
          'by': fromId,
        });

      case 'kick':
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
        // 房间管理员只能踢自己房间内的人，不能踢全局管理员和其他房间管理员
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
          // 房间管理员踢人只踢出房间，回到大厅
          _rooms[roomId]?.members.remove(targetId);
          _rooms[_lobbyId]!.members[targetId] = kickTarget;
          kickTarget.currentRoomId = _lobbyId;
          kickTarget.send({
            'type': 'room_joined',
            'room': _rooms[_lobbyId]!.toJson(),
            'history': _rooms[_lobbyId]!.messages
                .map((m) => m.toJson())
                .toList(),
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
          // 全局管理员踢人是断开连接
          kickTarget.send({'type': 'kicked', 'message': '你已被管理员踢出'});
          await Future.delayed(const Duration(milliseconds: 100));
          await kickTarget.socket.close(
            WebSocketStatus.policyViolation,
            'Kicked',
          );
          final kickRoomId = kickTarget.currentRoomId;
          _rooms[kickRoomId]?.members.remove(targetId);
          _clients.remove(targetId);
          onClientsChanged?.call();
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

      default:
        client?.send({'type': 'error', 'message': '未知消息类型：$type'});
    }
  }

  // ── 广播（房间内） ─────────────────────────

  void _broadcastToRoom(String roomId, HubMessage msg, {String? exclude}) {
    final room = _rooms[roomId];
    if (room == null) return;
    if (msg.type != HubMessageType.system) {
      room.addMessage(msg);
      onMessageReceived?.call();
    }
    for (final member in room.members.values) {
      if (member.id == exclude) continue;
      final json = msg.toJson();
      // 非系统消息才加密
      if (msg.type != HubMessageType.system &&
          HubCrypto.isInitialized &&
          json['payload'] != null) {
        final payloadStr = jsonEncode(json['payload']);
        json['payload'] = HubCrypto.encrypt(payloadStr);
        json['encrypted'] = true;
      }
      member.send(json);
    }
    Log.info(
      'HubService',
      '📢 广播[${room.name}] from:${msg.from} to:${room.members.length}个',
    );
  }

  void _unicast(HubMessage msg, String roomId) {
    final target = _clients[msg.to];
    if (target == null) {
      _clients[msg.from]?.send({
        'type': 'error',
        'message': '目标客户端 ${msg.to} 不存在',
      });
      return;
    }
    _rooms[roomId]?.addMessage(msg);
    onMessageReceived?.call();
    target.send(msg.toJson());
    Log.info('HubService', '📩 单播  from:${msg.from}  to:${msg.to}');
  }

  void _broadcastSystem(
    String event,
    Map<String, dynamic> data, {
    String? exclude,
  }) {
    final msg = HubMessage(
      type: HubMessageType.system,
      from: 'server',
      payload: {'event': event, ...data},
    );
    for (final client in _clients.values) {
      if (client.id != exclude) client.send(msg.toJson());
    }
  }

  void broadcast(dynamic payload, {String roomId = _lobbyId}) {
    _broadcastToRoom(
      roomId,
      HubMessage(
        type: HubMessageType.broadcast,
        from: 'server',
        payload: payload,
      ),
    );
  }

  Future<void> kickClient(String id) async {
    _clients[id]?.send({
      'type': 'kicked',
      'message': 'You have been kicked by the server',
    });
    await Future.delayed(const Duration(milliseconds: 100));
    await _clients[id]?.socket.close(
      WebSocketStatus.policyViolation,
      'Kicked by server',
    );
    final roomId = _clients[id]?.currentRoomId ?? _lobbyId;
    _rooms[roomId]?.members.remove(id);
    _clients.remove(id);
    onClientsChanged?.call();
  }

  Future<void> muteClient(String id, {int seconds = 300}) async {
    _clients[id]?.mutedUntil = DateTime.now().add(Duration(seconds: seconds));
    _clients[id]?.send({
      'type': 'system',
      'payload': {
        'event': 'you_are_muted',
        'seconds': seconds,
        'until': _clients[id]!.mutedUntil!.toIso8601String(),
      },
    });
    onClientsChanged?.call();
  }

  Future<void> unmuteClient(String id) async {
    _clients[id]?.mutedUntil = null;
    _clients[id]?.send({
      'type': 'system',
      'payload': {'event': 'you_are_unmuted'},
    });
    onClientsChanged?.call();
  }

  Future<void> setClientGlobalAdmin(String id, bool value) async {
    _clients[id]?.isGlobalAdmin = value;
    if (value) {
      _adminIds.add(id);
    } else {
      _adminIds.remove(id);
    }
    _saveAdmins();
    onClientsChanged?.call();
  }

  Future<void> setClientRoomAdmin(String id, String roomId, bool value) async {
    final room = _rooms[roomId];
    if (room == null) return;
    if (value) {
      room.adminIds.add(id);
    } else {
      room.adminIds.remove(id);
    }
    onClientsChanged?.call();
  }

  void clearHistory({String roomId = _lobbyId}) {
    _rooms[roomId]?.messages.clear();
    onMessageReceived?.call();
  }

  static const _portKey = 'hub_port';

  int get savedPort => appdata.implicitData[_portKey] as int? ?? 9100;

  void savePort(int port) {
    appdata.implicitData[_portKey] = port;
    appdata.writeImplicitData();
  }

  String _generateId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  Future<void> createRoom(
    String name, {
    String? password,
    String? announcement,
  }) async {
    final room = HubRoom(
      name: name,
      ownerId: 'server',
      password: password,
      announcement: announcement,
    );
    _rooms[room.id] = room;
    onRoomsChanged?.call();
    _broadcastSystem('room_created', {'room': room.toJson()});
  }

  Future<void> deleteRoom(String roomId) async {
    if (roomId == _lobbyId) return;
    final room = _rooms[roomId];
    if (room == null) return;
    // 把房间内成员踢回大厅
    for (final member in room.members.values) {
      member.currentRoomId = _lobbyId;
      _rooms[_lobbyId]!.members[member.id] = member;
      member.send({
        'type': 'room_joined',
        'room': _rooms[_lobbyId]!.toJson(),
        'history': _rooms[_lobbyId]!.messages.map((m) => m.toJson()).toList(),
      });
    }
    _rooms.remove(roomId);
    onRoomsChanged?.call();
    _broadcastSystem('room_deleted', {'roomId': roomId});
  }

  void addToBlacklist(String clientId) {
    _blacklist.add(clientId);
    _saveBlacklist();
    // 如果已在线，直接踢出
    kickClient(clientId);
  }

  void removeFromBlacklist(String clientId) {
    _blacklist.remove(clientId);
    _saveBlacklist();
  }

  bool isBlacklisted(String clientId) => _blacklist.contains(clientId);

  static const _blacklistKey = 'hub_blacklist';

  void _saveBlacklist() {
    appdata.implicitData[_blacklistKey] = _blacklist.toList();
    appdata.writeImplicitData();
  }

  void _loadBlacklist() {
    final raw = appdata.implicitData[_blacklistKey];
    if (raw is List) _blacklist.addAll(raw.cast<String>());
  }

  @override
  Future<void> init({
    int preferredPort = 9100,
    BindMode mode = BindMode.both,
  }) async {
    _loadAdmins();
    _loadBlacklist(); // ← 加
    return startServer(preferredPort: preferredPort, mode: mode);
  }

  @override
  Future<void> dispose() async {
    for (final client in _clients.values.toList()) {
      try {
        client.send({
          'type': 'system',
          'payload': {'event': 'server_shutdown'},
        });
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 300));
    for (final client in _clients.values.toList()) {
      try {
        await client.socket.close(WebSocketStatus.goingAway, 'Server shutdown');
      } catch (_) {}
    }
    _clients.clear();
    _rooms.clear();
    _clientCounter = 0;
    onClientsChanged?.call();
    onMessageReceived?.call();
    onRoomsChanged?.call();
    await stopServer();
  }
}
