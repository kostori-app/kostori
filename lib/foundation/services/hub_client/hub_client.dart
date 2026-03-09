part of 'package:kostori/foundation/services/services.dart';

class HubClient {
  HubClient._internal();

  static final HubClient _instance = HubClient._internal();

  factory HubClient() => _instance;

  WebSocket? _socket;
  String? myId;
  bool isGlobalAdmin = false;
  String? _currentToken;

  // ── 回调 ──────────────────────────────────────
  Function(Map<String, dynamic>)? onMessage;
  VoidCallback? onDisconnected;
  VoidCallback? onConnected;
  VoidCallback? onRoomListChanged; // 房间列表变化
  VoidCallback? onClientsChanged; // 在线客户端变化

  // ── 状态 ──────────────────────────────────────
  final List<Map<String, dynamic>> messageHistory = [];
  List<Map<String, dynamic>> onlineClients = [];
  List<Map<String, dynamic>> roomList = [];
  String? currentRoomId;
  String? currentRoomName;
  String? lobbyRoomId;

  final Set<String> _localBlacklist = {};

  // ── Getters ───────────────────────────────────

  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  List<Map<String, dynamic>> get currentRoomClients {
    if (currentRoomId == lobbyRoomId) return onlineClients;
    final room = roomList.firstWhereOrNull((r) => r['id'] == currentRoomId);
    if (room == null) return onlineClients;
    final members = room['members'] as List?;
    if (members == null) return onlineClients;
    final memberIds = members.map((m) => m['id']).toSet();
    return onlineClients.where((c) => memberIds.contains(c['id'])).toList();
  }

  // ── 持久化 ────────────────────────────────────

  static const _addressKey = 'hub_client_address';
  static const _nameKey = 'hub_client_name';
  static const _tokenKey = 'hub_client_token';
  static const _avatarKey = 'hub_client_avatar';
  static const _bioKey = 'hub_client_bio';

  String? get savedAddress => appdata.implicitData[_addressKey] as String?;

  String? get savedName => appdata.implicitData[_nameKey] as String?;

  String? get savedToken => appdata.implicitData[_tokenKey] as String?;

  String? get savedAvatar => appdata.implicitData[_avatarKey] as String?;

  String? get savedBio => appdata.implicitData[_bioKey] as String?;

  void saveAddress(String address) {
    appdata.implicitData[_addressKey] = address;
    appdata.writeImplicitData();
  }

  void saveName(String name) {
    appdata.implicitData[_nameKey] = name;
    appdata.writeImplicitData();
  }

  void saveToken(String token) {
    appdata.implicitData[_tokenKey] = token;
    appdata.writeImplicitData();
  }

  void saveAvatar(String avatar) {
    appdata.implicitData[_avatarKey] = avatar;
    appdata.writeImplicitData();
  }

  void saveBio(String bio) {
    appdata.implicitData[_bioKey] = bio;
    appdata.writeImplicitData();
  }

  // ── 黑名单 ────────────────────────────────────

  void blockUser(String clientId) => _localBlacklist.add(clientId);

  void unblockUser(String clientId) => _localBlacklist.remove(clientId);

  bool isBlocked(String clientId) => _localBlacklist.contains(clientId);

  // ── 管理员工具 ────────────────────────────────

  bool isRoomAdminOf(String? roomId) {
    if (roomId == null) return false;
    final room = roomList.firstWhereOrNull((r) => r['id'] == roomId);
    if (room == null) return false;
    final adminIds = room['adminIds'] as List?;
    return adminIds?.contains(myId) == true || room['ownerId'] == myId;
  }

  // ── 连接 ──────────────────────────────────────

  Future<void> connect(String address, String token, {String? name}) async {
    _currentToken = token;
    final base = address.startsWith('ws://') || address.startsWith('wss://')
        ? address
        : 'ws://$address';
    final url = '$base/hub';

    Log.info('HubClient', '连接到 $url');
    _socket = await WebSocket.connect(url);
    Log.info('HubClient', '✅ 已连接，发送鉴权...');

    _socket!.add(
      jsonEncode({
        'type': 'auth',
        'token': token,
        'name': name ?? '',
        'id': await _getDeviceId(),
        'bio': savedBio ?? '',
        'avatar': savedAvatar ?? '',
      }),
    );

    _socket!.listen(
      _handleRaw,
      onDone: () {
        Log.info('HubClient', '🔴 连接断开');
        _socket = null;
        myId = null;
        onDisconnected?.call();
      },
      onError: (e) {
        Log.error('HubClient', '❌ 错误：$e');
        _socket = null;
        myId = null;
        onDisconnected?.call();
      },
    );
  }

  void _handleRaw(dynamic raw) {
    final rawData = jsonDecode(raw as String) as Map<String, dynamic>;
    final data = _decryptPayload(rawData);
    _handleMessage(data);
  }

  // ── 断开 ──────────────────────────────────────

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    myId = null;
    isGlobalAdmin = false;
    currentRoomId = null;
    currentRoomName = null;
    lobbyRoomId = null;
    messageHistory.clear();
    roomList.clear();
    onlineClients.clear();
    HubCrypto.clear();
    onRoomListChanged = null;
    onClientsChanged = null;
  }

  // ── 解密 ──────────────────────────────────────

  Map<String, dynamic> _decryptPayload(Map<String, dynamic> data) {
    if (!HubCrypto.isInitialized) return data;
    if (data['encrypted'] != true || data['payload'] is! String) return data;
    try {
      final decrypted = HubCrypto.decrypt(data['payload'] as String);
      final result = Map<String, dynamic>.from(data);
      dynamic decoded = decrypted;
      try {
        decoded = jsonDecode(decrypted);
        if (decoded is String) decoded = jsonDecode(decoded);
      } catch (_) {}
      result['payload'] = decoded;
      result.remove('encrypted');
      return result;
    } catch (e) {
      Log.warning('HubClient', '解密失败：$e');
      return data;
    }
  }

  // ── 设备ID ────────────────────────────────────

  Future<String> _getDeviceId() async {
    var id = appdata.implicitData['hub_device_id'] as String?;
    if (id == null) {
      id =
          DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
          Random().nextInt(9999).toString();
      appdata.implicitData['hub_device_id'] = id;
      appdata.writeImplicitData();
    }
    return id;
  }

  // ── 发送指令 ──────────────────────────────────

  void broadcast(dynamic payload) {
    final s = jsonEncode(payload);
    _socket?.add(
      jsonEncode({
        'type': 'broadcast',
        'payload': HubCrypto.isInitialized ? HubCrypto.encrypt(s) : s,
        'encrypted': HubCrypto.isInitialized,
      }),
    );
  }

  void sendTo(String targetId, dynamic payload) {
    final s = jsonEncode(payload);
    _socket?.add(
      jsonEncode({
        'type': 'unicast',
        'to': targetId,
        'payload': HubCrypto.isInitialized ? HubCrypto.encrypt(s) : s,
        'encrypted': HubCrypto.isInitialized,
      }),
    );
  }

  void reply(String replyToId, dynamic payload) {
    final s = jsonEncode(payload);
    _socket?.add(
      jsonEncode({
        'type': 'broadcast',
        'replyTo': replyToId,
        'payload': HubCrypto.isInitialized ? HubCrypto.encrypt(s) : s,
        'encrypted': HubCrypto.isInitialized,
      }),
    );
  }

  void ping() => _socket?.add(jsonEncode({'type': 'ping'}));

  void recall(String msgId) =>
      _socket?.add(jsonEncode({'type': 'recall', 'msgId': msgId}));

  void leaveRoom() => _socket?.add(jsonEncode({'type': 'leave_room'}));

  void deleteRoom(String roomId) =>
      _socket?.add(jsonEncode({'type': 'delete_room', 'roomId': roomId}));

  void kickFromRoom(String id) =>
      _socket?.add(jsonEncode({'type': 'kick', 'targetId': id}));

  void roomBan(String id) =>
      _socket?.add(jsonEncode({'type': 'room_ban', 'targetId': id}));

  void roomUnban(String id) =>
      _socket?.add(jsonEncode({'type': 'room_unban', 'targetId': id}));

  void announce(String message) =>
      _socket?.add(jsonEncode({'type': 'announce', 'message': message}));

  void pin(String msgId) =>
      _socket?.add(jsonEncode({'type': 'pin', 'msgId': msgId}));

  void search(String keyword) =>
      _socket?.add(jsonEncode({'type': 'search', 'keyword': keyword}));

  void react(String msgId, String emoji) => _socket?.add(
    jsonEncode({'type': 'reaction', 'msgId': msgId, 'emoji': emoji}),
  );

  void setStatus(UserStatus status) =>
      _socket?.add(jsonEncode({'type': 'status', 'status': status.name}));

  void updateProfile({String? name, String? avatar, String? bio}) {
    _socket?.add(
      jsonEncode({
        'type': 'profile',
        if (name != null) 'name': name,
        if (avatar != null) 'avatar': avatar,
        if (bio != null) 'bio': bio,
      }),
    );
  }

  void mute(String targetId, {int seconds = 300}) => _socket?.add(
    jsonEncode({'type': 'mute', 'targetId': targetId, 'seconds': seconds}),
  );

  void unmute(String targetId) =>
      _socket?.add(jsonEncode({'type': 'unmute', 'targetId': targetId}));

  void setGlobalAdmin(String targetId, {bool value = true}) => _socket?.add(
    jsonEncode({
      'type': 'set_global_admin',
      'targetId': targetId,
      'value': value,
    }),
  );

  void setRoomAdmin(String targetId, {bool value = true}) => _socket?.add(
    jsonEncode({
      'type': 'set_room_admin',
      'targetId': targetId,
      'value': value,
    }),
  );

  void joinRoom(String roomId, {String? password}) => _socket?.add(
    jsonEncode({
      'type': 'join_room',
      'roomId': roomId,
      if (password != null) 'password': password,
    }),
  );

  void setAnnouncement(String announcement) => _socket?.add(
    jsonEncode({'type': 'set_announcement', 'announcement': announcement}),
  );

  void setRoomPassword(String? password) => _socket?.add(
    jsonEncode({'type': 'set_room_password', 'password': password}),
  );

  void createRoom(String name, {String? password, String? announcement}) =>
      _socket?.add(
        jsonEncode({
          'type': 'create_room',
          'name': name,
          if (password != null) 'password': password,
          if (announcement != null) 'announcement': announcement,
        }),
      );

  // 服务端黑名单（全局管理员）
  void serverBan(String targetId) =>
      _socket?.add(jsonEncode({'type': 'server_ban', 'targetId': targetId}));

  void serverUnban(String targetId) =>
      _socket?.add(jsonEncode({'type': 'server_unban', 'targetId': targetId}));
}
