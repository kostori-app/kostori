part of 'package:kostori/foundation/services/services.dart';

final hubServiceProvider = Provider<HubService>((ref) => HubService());

class HubService extends BaseHttpService {
  HubService();

  final Map<String, HubClientInfo> _clients = {};
  final Map<String, HubRoom> _rooms = {};
  final Map<String, String> _uploadCache = {};
  final Set<String> _blacklist = {};
  final Set<String> _adminIds = {};
  final List<String> eventLog = [];
  static const String _lobbyIdValue = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  HubClientDto get _serverDto => HubClientDto(
    userId: 'server',
    displayName: 'Server',
    connectedAt: DateTime.now(),
  );

  String get _lobbyId => _lobbyIdValue;

  VoidCallback? onMessageReceived;
  VoidCallback? onClientsChanged;
  VoidCallback? onRoomsChanged;

  Timer? _heartbeatTimer;

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
    for (final member in room.participants.values) {
      if (member.userId == exclude) continue;
      final json = msg.toJson();
      if (HubCrypto.isInitialized && json['segments'] != null) {
        json['segments'] = HubCrypto.encrypt(jsonEncode(json['segments']));
        json['encrypted'] = true;
      }
      json['type'] = 'message';
      member.send(json);
    }
    HubLog.info(
      'HubService',
      '📢 广播[${room.roomName}] from:${msg.sender.userId} to:${room.participants.length}个',
    );
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
    Map<String, dynamic> buildJson() {
      final json = {'type': 'unicast', ...msg.toJson()};
      if (HubCrypto.isInitialized && json['segments'] != null) {
        json['segments'] = HubCrypto.encrypt(jsonEncode(json['segments']));
        json['encrypted'] = true;
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
    await _clients[id]?.connection.close(
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
    _startHeartbeatCheck();
    return startServer(
      preferredPort: preferredPort ?? savedHubPort,
      mode: mode ?? savedHubBindMode,
    );
  }

  @override
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    for (final client in _clients.values.toList()) {
      try {
        _sendSystemTo(client, HubSystemEvent.serverShutdown, {});
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 300));
    for (final client in _clients.values.toList()) {
      try {
        await client.connection.close(
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
