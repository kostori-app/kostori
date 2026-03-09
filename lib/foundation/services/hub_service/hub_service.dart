part of 'package:kostori/foundation/services/services.dart';

class HubService extends BaseHttpService {
  HubService._internal();

  static final HubService _instance = HubService._internal();

  factory HubService() => _instance;

  final Map<String, HubClientInfo> _clients = {};
  final Map<String, HubRoom> _rooms = {};
  final Set<String> _blacklist = {};
  final Set<String> _adminIds = {};
  final List<String> eventLog = [];
  static const String _lobbyIdValue = 'lobby';

  String get _lobbyId => _lobbyIdValue;

  VoidCallback? onMessageReceived;
  VoidCallback? onClientsChanged;
  VoidCallback? onRoomsChanged;

  // ── Getters ───────────────────────────────────

  List<HubClientInfo> get clients => _clients.values.toList();

  int get clientCount => _clients.length;

  List<HubRoom> get rooms => _rooms.values.toList();

  List<HubMessage> get messageHistory =>
      List.unmodifiable(_rooms[_lobbyId]?.messages ?? []);

  int get blacklistCount => _blacklist.length;

  List<String> get blacklist => _blacklist.toList();

  String get lobbyId => _lobbyId;

  // ── 管理员持久化 ──────────────────────────────

  static const _adminKey = 'hub_admin_ids';

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

  // ── 黑名单持久化 ──────────────────────────────

  static const _blacklistKey = 'hub_blacklist';

  void _loadBlacklist() {
    final raw = appdata.implicitData[_blacklistKey];
    if (raw is List) _blacklist.addAll(raw.cast<String>());
  }

  void _saveBlacklist() {
    appdata.implicitData[_blacklistKey] = _blacklist.toList();
    appdata.writeImplicitData();
  }

  // ── 工具方法 ──────────────────────────────────

  bool _isRoomAdmin(String clientId, String roomId) =>
      _clients[clientId]?.isGlobalAdmin == true ||
      _rooms[roomId]?.isAdmin(clientId) == true;

  String _generateId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  String _resolveClientName(String name) {
    final existing = _clients.values
        .where((c) => c.name == name || (c.name?.startsWith('$name#') ?? false))
        .toList();
    if (existing.isEmpty) return name;
    final usedNumbers = <int>{};
    for (final c in existing) {
      if (c.name == name) {
        usedNumbers.add(0);
      } else {
        final suffix = c.name?.substring(name.length + 1);
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

  // ── 广播 ──────────────────────────────────────

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

  // ── 公共 API ──────────────────────────────────

  void broadcast(dynamic payload, {String? roomId}) {
    final id = roomId ?? _lobbyId;
    _broadcastToRoom(
      id,
      HubMessage(
        type: HubMessageType.broadcast,
        from: 'server',
        payload: payload,
      ),
    );
  }

  Future<void> kickClient(
    String id, {
    KickReason reason = KickReason.kicked,
    String? operatorId,
    String? operatorName,
    String? customMessage,
  }) async {
    final reasonStr = switch (reason) {
      KickReason.kicked => 'kicked',
      KickReason.banned => 'room_banned',
      KickReason.serverBanned => 'server_banned',
    };

    final defaultMessage = switch (reason) {
      KickReason.kicked => 'Kicked by ${operatorName ?? "server"}',
      KickReason.banned =>
        'Banned from this room by ${operatorName ?? "server"}',
      KickReason.serverBanned =>
        'Banned from this server by ${operatorName ?? "server"}',
    };

    _clients[id]?.send({
      'type': 'kicked',
      'reason': reasonStr,
      'message': customMessage ?? defaultMessage,
      'operatorId': operatorId ?? 'server',
      'operatorName': operatorName ?? 'server',
    });

    await Future.delayed(const Duration(milliseconds: 100));
    await _clients[id]?.socket.close(
      WebSocketStatus.policyViolation,
      reasonStr,
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

  void clearHistory({String? roomId}) {
    _rooms[roomId ?? _lobbyId]?.messages.clear();
    onMessageReceived?.call();
  }

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
    final name = _clients[clientId]?.name ?? clientId;
    _logEvent('🚫 $name added to server blacklist');
    kickClient(clientId, reason: KickReason.serverBanned);
  }

  void removeFromBlacklist(String clientId) {
    _blacklist.remove(clientId);
    _saveBlacklist();
    _logEvent('✅ $clientId removed from server blacklist');
  }

  bool isBlacklisted(String clientId) => _blacklist.contains(clientId);

  void _logEvent(String msg) {
    eventLog.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
    if (eventLog.length > 200) eventLog.removeAt(0);
    onClientsChanged?.call();
  }

  // ── 生命周期 ──────────────────────────────────

  @override
  void registerRoutes() => registerHubRoutes();

  @override
  Future<void> init({int? preferredPort, BindMode? mode}) async {
    _loadAdmins();
    _loadBlacklist();
    return startServer(
      preferredPort: preferredPort ?? savedHubPort,
      mode: mode ?? savedHubBindMode,
    );
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
    onClientsChanged?.call();
    onMessageReceived?.call();
    onRoomsChanged?.call();
    await stopServer();
  }
}
