part of 'package:kostori/foundation/hub_services/services.dart';

final hubServiceProvider = Provider<HubService>((ref) => HubService());

class HubService extends BaseHttpService {
  HubService();

  final Map<String, HubClientInfo> _clients = {};
  final Map<String, HubRoom> _rooms = {};
  final Map<String, String> _uploadCache = {};
  final Set<String> _blacklist = {};
  final Set<String> _adminIds = {};
  final List<String> eventLog = [];

  /// 已与房主建立直连同步的成员（一起看 P2P），广播时跳过这些成员
  final Map<String, bool> _directSyncMembers = {};
  static const String _lobbyIdValue = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  HubClientDto get _serverDto => HubClientDto(
    userId: 'server',
    displayName: 'Server',
    connectedAt: DateTime.now(),
  );

  String get _lobbyId => _lobbyIdValue;

  /// 大厅房间 ID（对外暴露）
  String get lobbyRoomId => _lobbyIdValue;

  VoidCallback? onMessageReceived;
  VoidCallback? onClientsChanged;
  VoidCallback? onRoomsChanged;

  Timer? _heartbeatTimer;

  final DateTime startedAt = DateTime.now();

  int get directSyncMemberCount =>
      _directSyncMembers.values.where((v) => v).length;

  /// 通过客户端 ID 查显示名
  String clientName(String? userId) {
    if (userId == null || userId == 'server') return 'Server';
    return _clients[userId]?.displayName ?? userId;
  }

  HubRoom? findRoom(String roomId) => _rooms[roomId];

  /// 广播一条已构造好的消息（供 Web 管理后台等注入）
  void broadcastToRoomFrom(String roomId, HubMessage msg) =>
      _broadcastToRoom(roomId, msg);

  /// 解析文本为消息 segments
  List<MessageSegment> parseSegments(String text) => _parseSegments(text);

  /// 构造一个"Server"身份的机器人发送者
  HubClientInfo serverBotClient(String roomId) => HubClientInfo(
    userId: 'server',
    displayName: 'Server',
    connection: null,
    currentRoomId: roomId,
    isBot: true,
  );

  /// 管理员删除任意房间（不可删大厅）
  bool deleteRoomByAdmin(String roomId) {
    if (roomId == _lobbyId) return false;
    final room = _rooms.remove(roomId);
    if (room == null) return false;
    for (final member in room.participants.values) {
      _moveToLobby(member);
    }
    onRoomsChanged?.call();
    _broadcastSystem(HubSystemEvent.roomDeleted, {'roomId': roomId});
    unawaited(_saveRooms());
    return true;
  }

  /// 重启服务（先停后启）
  Future<void> restart() async {
    await stopWebAdmin();
    await stopServer();
    await init();
  }

  /// 停止 Web 管理服务
  Future<void> stopWebAdmin() async {
    await _webAdmin?.dispose();
    _webAdmin = null;
  }

  /// 若启用则启动/更新 Web 管理服务
  Future<void> startWebAdmin() async {
    final wantEnabled = HubWebAdminService._enabled();
    if (!wantEnabled) {
      await stopWebAdmin();
      return;
    }
    if (_webAdmin != null && _webAdmin!.isRunning) {
      return;
    }
    final admin = HubWebAdminService(this);
    await admin.startServer(
      preferredPort: admin.webAdminPort,
      mode: admin.webAdminBindMode,
    );
    _webAdmin = admin;
  }

  HubWebAdminService? _webAdmin;

  List<HubClientInfo> get clients => _clients.values.toList();

  int get clientCount => _clients.length;

  List<HubRoom> get rooms => _rooms.values.toList();

  List<HubMessage> get messageHistory =>
      List.unmodifiable(_rooms[_lobbyId]?.messageHistory ?? []);

  int get blacklistCount => _blacklist.length;

  List<String> get blacklist => _blacklist.toList();

  String get lobbyId => _lobbyId;

  static const _adminKey = 'hub_admin_ids';

  final Map<String, DateTime> _inviteCooldowns = {};

  static const _inviteCooldown = Duration(minutes: 2);

  void addAdmin(String clientId) => _adminIds.add(clientId);

  void removeAdmin(String clientId) => _adminIds.remove(clientId);

  void _loadAdmins() {
    final raw = appdata.implicitData[_adminKey];
    if (raw is List) _adminIds.addAll(raw.cast<String>());
  }

  void _saveAdmins() {
    appdata.implicitData[_adminKey] = _adminIds.toList();
    appdata.writeImplicitData();
  }

  static const _blacklistKey = 'hub_blacklist';

  void _loadBlacklist() {
    final raw = appdata.implicitData[_blacklistKey];
    if (raw is List) _blacklist.addAll(raw.cast<String>());
  }

  void _saveBlacklist() {
    appdata.implicitData[_blacklistKey] = _blacklist.toList();
    appdata.writeImplicitData();
  }

  bool _isRoomAdmin(String clientId, String roomId) =>
      _clients[clientId]?.isGlobalAdmin == true ||
      _rooms[roomId]?.isModerator(clientId) == true;

  // ── 房间持久化（本地文件，不参与 WebDAV 同步）─────────────────────────────

  Future<File> _roomsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/hub/hub_rooms.json');
  }

  /// 房间元数据。
  /// [encryptPassword] 为 true 时密码加密存储（本地磁盘）；
  /// 为 false 时明文输出（用户主动导出的可移植文件）。
  Map<String, dynamic> _roomMeta(HubRoom r, {bool encryptPassword = false}) => {
    'roomId': r.roomId,
    'roomName': r.roomName,
    'ownerUserId': r.ownerUserId,
    'password': r.password == null
        ? null
        : (encryptPassword ? SecretVault.encrypt(r.password!) : r.password),
    'announcements': r.announcements,
    'maxParticipants': r.maxParticipants,
    'moderatorIds': r.moderatorIds.toList(),
    'welcomeMessage': r.welcomeMessage,
    'allowMemberInvite': r.allowMemberInvite,
    'roomType': r.roomType.name,
    if (r.animeId != null) 'animeId': r.animeId,
    if (r.animeTitle != null) 'animeTitle': r.animeTitle,
    if (r.animeSourceKey != null) 'animeSourceKey': r.animeSourceKey,
    if (r.animeCover != null) 'animeCover': r.animeCover,
  };

  /// 导出房间配置 JSON（供导入/导出，密码明文可移植）
  String exportRoomsJson() =>
      jsonEncode(_rooms.values.map((r) => _roomMeta(r)).toList());

  /// 导入房间配置 JSON（覆盖式合并到内存，并持久化）。
  /// 兼容明文导入与加密导入。
  void importRoomsJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return;
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final room = HubRoom(
          roomId: m['roomId'] as String?,
          roomName: m['roomName'] as String? ?? '未命名房间',
          ownerUserId: m['ownerUserId'] as String? ?? 'server',
          password: _decryptRoomPassword(m['password'] as String?),
          announcements:
              (m['announcements'] as List?)?.cast<String>() ?? const [],
          maxParticipants: m['maxParticipants'] as int?,
          welcomeMessage: m['welcomeMessage'] as String?,
          allowMemberInvite: m['allowMemberInvite'] as bool? ?? false,
          roomType:
              HubRoomType.values.firstWhereOrNull(
                (e) => e.name == m['roomType'],
              ) ??
              HubRoomType.chat,
          animeId: m['animeId'] as String?,
          animeTitle: m['animeTitle'] as String?,
          animeSourceKey: m['animeSourceKey'] as String?,
          animeCover: m['animeCover'] as String?,
        );
        room.moderatorIds.addAll(
          (m['moderatorIds'] as List?)?.cast<String>() ?? const [],
        );
        _rooms[room.roomId] = room;
      }
      _ensureLobby();
      onRoomsChanged?.call();
      unawaited(_saveRooms());
    } catch (e) {
      HubLog.error('HubService', '导入房间失败: $e');
    }
  }

  String? _decryptRoomPassword(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    final decrypted = SecretVault.decrypt(stored);
    return decrypted.isEmpty ? null : decrypted;
  }

  Future<void> _saveRooms() async {
    try {
      final file = await _roomsFile();
      await file.parent.create(recursive: true);
      // 本地文件加密存储密码，导出走 exportRoomsJson() 明文
      final json = jsonEncode(
        _rooms.values.map((r) => _roomMeta(r, encryptPassword: true)).toList(),
      );
      await file.writeAsString(json);
    } catch (e) {
      HubLog.error('HubService', '保存房间失败: $e');
    }
  }

  Future<void> _loadRooms() async {
    try {
      final file = await _roomsFile();
      if (!file.existsSync()) return;
      importRoomsJson(await file.readAsString());
    } catch (e) {
      HubLog.error('HubService', '加载房间失败: $e');
    }
  }

  String _generateId() => const Uuid().v4();

  String _resolveClientName(String name) {
    final existing = _clients.values
        .where(
          (c) =>
              c.displayName == name ||
              (c.displayName?.startsWith('$name#') ?? false),
        )
        .toList();
    if (existing.isEmpty) return name;
    final usedNumbers = <int>{};
    for (final c in existing) {
      if (c.displayName == name) {
        usedNumbers.add(0);
      } else {
        final suffix = c.displayName?.substring(name.length + 1);
        final n = int.tryParse(suffix ?? '');
        if (n != null) usedNumbers.add(n);
      }
    }
    int i = 0;
    while (usedNumbers.contains(i)) {
      i++;
    }
    return i == 0 ? name : '$name#$i';
  }

  void _broadcastToRoom(String roomId, HubMessage msg, {String? exclude}) {
    final room = _rooms[roomId];
    if (room == null) return;
    room.addMessage(msg);
    onMessageReceived?.call();
    unawaited(_dispatchOutboundMessage(room, msg));
    // AI 陪聊：房间内 @提及机器人时生成回复
    maybeAiBotReply(msg, room);
    // 一起看同步消息：已直连房主的成员跳过服务器转发（避免带宽浪费）
    final isSyncMsg = msg.segments.whereType<TextSegment>().any(
      (s) => isHubSyncText(s.text),
    );
    for (final member in room.participants.values) {
      if (member.userId == exclude) continue;
      if (isSyncMsg && _directSyncMembers[member.userId] == true) continue;
      final json = msg.toJson();
      // 逐人加密：用该成员自己的 token 派生密钥，避免多客户端互相污染全局密钥
      if (json['segments'] != null) {
        final token = member.authToken;
        if (token != null && token.isNotEmpty) {
          json['segments'] = HubCrypto.encryptWith(
            token,
            jsonEncode(json['segments']),
          );
          json['encrypted'] = true;
        }
      }
      json['type'] = 'message';
      member.send(json);
    }
    HubLog.info(
      'HubService',
      '📢 广播[${room.roomName}] from:${msg.sender.userId} to:${room.participants.length}个',
    );
  }

  /// 出站 webhook：将房间消息推送到配置的 URL（带 HMAC 签名）
  Future<void> _dispatchOutboundMessage(HubRoom room, HubMessage msg) async {
    try {
      final webhooks = HubWebhookManager.instance.loadOutbound();
      final text = msg.segments
          .whereType<TextSegment>()
          .map((s) => s.text)
          .join('\n');
      if (text.isEmpty) return;
      final event = {
        'event': 'message',
        'roomId': room.roomId,
        'roomName': room.roomName,
        'senderId': msg.sender.userId,
        'senderName': msg.sender.displayName,
        'text': text,
        'sentAt': DateTime.now().toIso8601String(),
      };
      // 订阅管理分发（webhook / ws 反向推送 / ws 正向广播）
      HubSubscriptionService.instance.dispatch(event);
      final body = jsonEncode(event);
      // HTTP 出站 webhook
      for (final webhook in webhooks) {
        if (!webhook.messageEvents) continue;
        unawaited(_postWebhook(webhook, body));
      }
      // WS 正向连接：推送给机器人
      for (final bot in HubWebhookManager.instance.loadWsBots()) {
        if (!bot.messageEvents) continue;
        unawaited(_wsBotSend(bot, body));
      }
    } catch (e) {
      HubLog.warning('HubWebhook', '出站消息推送解析失败：$e');
    }
  }

  /// 出站 webhook：将系统事件推送到配置的 URL
  Future<void> _dispatchOutboundSystem(
    String event,
    Map<String, dynamic> data,
  ) async {
    try {
      final webhooks = HubWebhookManager.instance.loadOutbound();
      final eventMap = {'event': event, ...data};
      // 订阅管理分发（webhook / ws 反向推送 / ws 正向广播）
      HubSubscriptionService.instance.dispatch(eventMap);
      final body = jsonEncode(eventMap);
      for (final webhook in webhooks) {
        if (!webhook.systemEvents) continue;
        unawaited(_postWebhook(webhook, body));
      }
      // WS 正向连接：推送给机器人
      for (final bot in HubWebhookManager.instance.loadWsBots()) {
        if (!bot.systemEvents) continue;
        unawaited(_wsBotSend(bot, body));
      }
    } catch (e) {
      HubLog.warning('HubWebhook', '出站系统事件推送解析失败：$e');
    }
  }

  Future<void> _postWebhook(HubOutboundWebhook webhook, String body) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (webhook.secret.isNotEmpty) {
        headers['X-Hub-Signature'] =
            'sha256=${HubWebhookManager.sign(webhook.secret, body)}';
      }
      await AppDio().post(
        webhook.url,
        data: body,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      HubLog.warning('HubWebhook', '出站 webhook 推送失败（${webhook.name}）：$e');
    }
  }

  /// 已建立的 WS 机器人连接（url -> socket）
  final Map<String, WebSocket> _wsBotSockets = {};

  /// 通过 WS 正向连接推送给机器人。
  /// 惰性建立连接：发送前若无连接则连上并握手，发送后保留连接复用。
  Future<void> _wsBotSend(HubWsBotConnection bot, String body) async {
    try {
      var socket = _wsBotSockets[bot.url];
      if (socket == null || socket.readyState != WebSocket.open) {
        socket = await connectTo(bot.url);
        if (socket == null) return;
        _wsBotSockets[bot.url] = socket;
        // 简单握手：报告来源与可选密钥（机器人侧可校验）
        try {
          socket.add(
            jsonEncode({
              'type': 'hub_bot_handshake',
              'source': 'kostori-hub',
              if (bot.secret.isNotEmpty) 'secret': bot.secret,
              'time': DateTime.now().toIso8601String(),
            }),
          );
        } catch (_) {}
      }
      socket.add(body);
    } catch (e) {
      _wsBotSockets.remove(bot.url);
      HubLog.warning('HubWsBot', 'WS 推送失败（${bot.name}）：$e');
    }
  }

  /// 关闭所有 WS 机器人连接（dispose 时调用）
  void _closeWsBots() {
    for (final ws in _wsBotSockets.values) {
      try {
        ws.close();
      } catch (_) {}
    }
    _wsBotSockets.clear();
  }

  void _broadcastSystemToRoom(
    String roomId,
    HubSystemEvent event,
    Map<String, dynamic> data, {
    String? exclude,
  }) {
    final room = _rooms[roomId];
    if (room == null) return;
    final payload = {'type': 'system', 'event': event.value, ...data};
    unawaited(_dispatchOutboundSystem(event.value, data));
    for (final member in room.participants.values) {
      if (member.userId == exclude) continue;
      member.send(payload);
    }
  }

  void _broadcastSystem(
    HubSystemEvent event,
    Map<String, dynamic> data, {
    String? exclude,
  }) {
    final payload = {'type': 'system', 'event': event.value, ...data};
    unawaited(_dispatchOutboundSystem(event.value, data));
    for (final client in _clients.values) {
      if (client.userId != exclude) client.send(payload);
    }
  }

  void _sendSystemTo(
    HubClientInfo client,
    HubSystemEvent event,
    Map<String, dynamic> data,
  ) => client.send({'type': 'system', 'event': event.value, ...data});

  void _unicast(HubMessage msg, String roomId, String targetUserId) {
    final target = _clients[targetUserId];
    if (target == null) {
      _clients[msg.sender.userId]?.send({
        'type': 'error',
        'message': '目标客户端 $targetUserId 不存在',
      });
      return;
    }
    _rooms[roomId]?.addMessage(msg);
    onMessageReceived?.call();
    // AI 陪聊：收到私聊时机器人回复（若启用）
    final room = _rooms[roomId];
    if (room != null) maybeAiBotReply(msg, room, dmTargetUserId: targetUserId);
    Map<String, dynamic> buildJson() {
      final json = {'type': 'unicast', ...msg.toJson()};
      if (json['segments'] != null) {
        final token = target.authToken;
        if (token != null && token.isNotEmpty) {
          json['segments'] = HubCrypto.encryptWith(
            token,
            jsonEncode(json['segments']),
          );
          json['encrypted'] = true;
        }
      }
      return json;
    }

    final json = buildJson();
    target.send(json);
    _clients[msg.sender.userId]?.send(json);
    HubLog.info(
      'HubService',
      '📩 单播  from:${msg.sender.userId}  to:$targetUserId',
    );
  }

  void broadcast(dynamic payload, {String? roomId}) {
    final id = roomId ?? _lobbyId;
    final room = _rooms[id];
    if (room == null) return;
    final json = {'type': 'broadcast', 'payload': payload};
    for (final member in room.participants.values) {
      member.send(json);
    }
  }

  Future<void> kickClient(
    String id, {
    KickReason reason = KickReason.kicked,
    String? operatorId,
    String? operatorName,
    String? customMessage,
  }) async {
    if (operatorId != null && _clients[id]?.isGlobalAdmin == true) {
      _clients[operatorId]?.send({'type': 'error', 'message': '无法对全局管理员执行此操作'});
      return;
    }
    final reasonStr = switch (reason) {
      KickReason.kicked => 'kicked',
      KickReason.banned => 'room_banned',
      KickReason.serverBanned => 'server_banned',
      KickReason.timeout => 'timeout',
    };
    final defaultMessage = switch (reason) {
      KickReason.kicked => 'Kicked by ${operatorName ?? "server"}',
      KickReason.banned =>
        'Banned from this room by ${operatorName ?? "server"}',
      KickReason.serverBanned =>
        'Banned from this server by ${operatorName ?? "server"}',
      KickReason.timeout => 'Connection timed out (no heartbeat)',
    };
    _clients[id]?.send({
      'type': 'kicked',
      'reason': reasonStr,
      'message': customMessage ?? defaultMessage,
      'operatorId': operatorId ?? 'server',
      'operatorName': operatorName ?? 'server',
    });
    await Future.delayed(const Duration(milliseconds: 100));
    await _clients[id]?.connection?.close(
      WebSocketStatus.policyViolation,
      reasonStr,
    );
    final target = _clients[id];
    final targetName = target?.displayName ?? id;
    final roomId = target?.currentRoomId ?? _lobbyId;
    final targetDto = target?.toDto();
    _rooms[roomId]?.participants.remove(id);
    _clients.remove(id);
    onClientsChanged?.call();

    if (targetDto != null) {
      _broadcastSystem(HubSystemEvent.clientLeftRoom, {
        'client': targetDto.toJson(),
        'roomId': roomId,
      });
    }
    _broadcastSystem(HubSystemEvent.clientLeft, {
      'clientId': id,
      'clientName': targetName,
    });
    final op = operatorName ?? 'server';
    final reasonLabel = switch (reason) {
      KickReason.kicked => '⚡ kicked',
      KickReason.banned => '🚫 room banned',
      KickReason.serverBanned => '🚫 server banned',
      KickReason.timeout => '💀 timeout',
    };
    _logEvent('$reasonLabel: $targetName by $op');
  }

  Future<void> muteClient(String id, {int seconds = 300}) async {
    _clients[id]?.mutedUntil = DateTime.now().add(Duration(seconds: seconds));
    if (_clients[id] != null) {
      _sendSystemTo(_clients[id]!, HubSystemEvent.youAreMuted, {
        'seconds': seconds,
        'until': _clients[id]!.mutedUntil!.toIso8601String(),
      });
    }
    onClientsChanged?.call();
  }

  Future<void> unmuteClient(String id) async {
    _clients[id]?.mutedUntil = null;
    if (_clients[id] != null) {
      _sendSystemTo(_clients[id]!, HubSystemEvent.youAreUnmuted, {});
    }
    onClientsChanged?.call();
  }

  Future<void> setClientGlobalAdmin(String id, bool value) async {
    _clients[id]?.isGlobalAdmin = value;
    if (value) {
      _adminIds.add(id);
      if (_clients[id] != null) {
        _sendSystemTo(_clients[id]!, HubSystemEvent.blacklistUpdated, {
          'blacklist': _blacklist.toList(),
        });
      }
    } else {
      _adminIds.remove(id);
    }
    _saveAdmins();
    onClientsChanged?.call();
    _logEvent(
      '👑 server ${value ? "granted" : "revoked"} global admin for ${_clients[id]?.displayName ?? id}',
    );
    _broadcastSystem(HubSystemEvent.globalAdminChanged, {
      'clientId': id,
      'isGlobalAdmin': value,
      'by': 'server',
    });
  }

  Future<void> setClientRoomAdmin(String id, String roomId, bool value) async {
    final room = _rooms[roomId];
    if (room == null) return;
    if (value) {
      room.moderatorIds.add(id);
    } else {
      room.moderatorIds.remove(id);
    }
    onClientsChanged?.call();
    unawaited(_saveRooms());
  }

  void clearHistory({String? roomId}) {
    _rooms[roomId ?? _lobbyId]?.messageHistory.clear();
    onMessageReceived?.call();
  }

  Future<void> createRoom(
    String name, {
    String? password,
    String? announcement,
    String? creatorId,
    int? maxParticipants,
  }) async {
    final room = HubRoom(
      roomName: name,
      ownerUserId: creatorId ?? 'server',
      password: password,
      announcements: announcement != null ? [announcement] : const [],
      maxParticipants: maxParticipants,
    );
    _rooms[room.roomId] = room;
    onRoomsChanged?.call();
    unawaited(_saveRooms());
    _logEvent(
      '🏠 Room created: "${room.roomName}" (${room.roomId}) by ${creatorId ?? "server"}',
    );
    _broadcastSystem(HubSystemEvent.roomCreated, {'room': room.toJson()});
  }

  Future<void> deleteRoom(String roomId) async {
    if (roomId == _lobbyId) return;
    final room = _rooms[roomId];
    if (room == null) return;
    for (final member in room.participants.values) {
      member.currentRoomId = _lobbyId;
      _rooms[_lobbyId]!.participants[member.userId] = member;
      member.send({
        'type': 'room_joined',
        'room': _rooms[_lobbyId]!.toJson(),
        'history': _rooms[_lobbyId]!.messageHistory
            .map((m) => m.toJson())
            .toList(),
      });
    }
    _rooms.remove(roomId);
    onRoomsChanged?.call();
    unawaited(_saveRooms());
    _broadcastSystem(HubSystemEvent.roomDeleted, {'roomId': roomId});
  }

  void addToBlacklist(String clientId) {
    _blacklist.add(clientId);
    _saveBlacklist();
    _logEvent(
      '🚫 ${_clients[clientId]?.displayName ?? clientId} added to server blacklist',
    );
    _broadcastBlacklistToAdmins();
    kickClient(clientId, reason: KickReason.serverBanned);
  }

  void removeFromBlacklist(String clientId) {
    _blacklist.remove(clientId);
    _saveBlacklist();
    _logEvent('✅ $clientId removed from server blacklist');
    _broadcastBlacklistToAdmins();
  }

  bool isBlacklisted(String clientId) => _blacklist.contains(clientId);

  void _broadcastBlacklistToAdmins() {
    for (final c in _clients.values.where((c) => c.isGlobalAdmin)) {
      _sendSystemTo(c, HubSystemEvent.blacklistUpdated, {
        'blacklist': _blacklist.toList(),
      });
    }
  }

  void _startHeartbeatCheck() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(pingInterval, (_) {
      final now = DateTime.now();
      final timedOut = _clients.values
          .where((c) => now.difference(c.lastHeartbeat) > pingInterval)
          .map((c) => c.userId)
          .toList();
      for (final id in timedOut) {
        _logEvent('💀 心跳超时，踢出：${_clients[id]?.displayName ?? id}');
        kickClient(id, reason: KickReason.timeout);
      }
    });
  }

  void _ensureLobby() {
    if (_rooms.containsKey(_lobbyId)) return;
    _rooms[_lobbyId] = HubRoom(
      roomId: _lobbyId,
      roomName: 'Lobby',
      ownerUserId: 'server',
      password: null,
      announcements: const [],
    );
    _logEvent('🏠 Lobby created: $_lobbyId');
  }

  @override
  void registerRoutes() {
    registerHubRoutes();
    registerUploadRoutes();
  }

  @override
  Future<void> init({int? preferredPort, BindMode? mode}) async {
    _loadAdmins();
    _loadBlacklist();
    _ensureLobby();
    await _loadRooms(); // 恢复上次持久化的房间（名称/公告/密码等）
    _startHeartbeatCheck();
    await startServer(
      preferredPort: preferredPort ?? savedHubPort,
      mode: mode ?? savedHubBindMode,
    );
    await startWebAdmin(); // 独立端口的管理网页
    HubSubscriptionManager.instance.migrateLegacy();
    await HubSubscriptionService.instance.startAll();
  }

  @override
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    await stopWebAdmin();
    _closeWsBots();
    await HubSubscriptionService.instance.stopAll();
    await _saveRooms(); // 停止服务前持久化当前房间状态
    for (final client in _clients.values.toList()) {
      try {
        _sendSystemTo(client, HubSystemEvent.serverShutdown, {});
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 300));
    for (final client in _clients.values.toList()) {
      try {
        await client.connection?.close(
          WebSocketStatus.goingAway,
          'Server shutdown',
        );
      } catch (_) {}
    }
    _clients.clear();
    _rooms.clear();
    _ensureLobby();
    onClientsChanged?.call();
    onMessageReceived?.call();
    onRoomsChanged?.call();
    await stopServer();
  }
}
