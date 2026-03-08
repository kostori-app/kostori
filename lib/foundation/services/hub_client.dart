part of 'package:kostori/foundation/services/services.dart';

class HubClient {
  HubClient._internal();

  static final HubClient _instance = HubClient._internal();

  factory HubClient() => _instance;

  WebSocket? _socket;
  String? myId;

  bool isGlobalAdmin = false; // ← 加字段

  String? _currentToken;

  Function(Map<String, dynamic>)? onMessage;
  VoidCallback? onDisconnected; // ← 补上
  VoidCallback? onConnected;
  final List<Map<String, dynamic>> messageHistory = [];

  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  // 当前房间内的成员（大厅显示全部）
  List<Map<String, dynamic>> get currentRoomClients {
    if (currentRoomId == lobbyRoomId) return onlineClients;
    final room = roomList.firstWhereOrNull((r) => r['id'] == currentRoomId);
    if (room == null) return onlineClients;
    final members = room['members'] as List?;
    if (members == null) return onlineClients;
    final memberIds = members.map((m) => m['id']).toSet();
    return onlineClients.where((c) => memberIds.contains(c['id'])).toList();
  }

  static const _addressKey = 'hub_client_address';
  static const _nameKey = 'hub_client_name';
  static const _tokenKey = 'hub_client_token';
  List<Map<String, dynamic>> roomList = []; // 服务端推来的房间列表
  String? currentRoomId; // 当前所在房间ID
  String? currentRoomName; // 当前房间名称
  String? lobbyRoomId; // 大厅ID

  String? get savedAddress => appdata.implicitData[_addressKey] as String?;

  String? get savedName => appdata.implicitData[_nameKey] as String?;

  String? get savedToken => appdata.implicitData[_tokenKey] as String?;

  static const _avatarKey = 'hub_client_avatar';

  String? get savedAvatar => appdata.implicitData[_avatarKey] as String?;

  final Set<String> _localBlacklist = {};

  void blockUser(String clientId) {
    _localBlacklist.add(clientId);
  }

  void unblockUser(String clientId) {
    _localBlacklist.remove(clientId);
  }

  bool isBlocked(String clientId) => _localBlacklist.contains(clientId);

  void saveAvatar(String avatar) {
    appdata.implicitData[_avatarKey] = avatar;
    appdata.writeImplicitData();
  }

  // 在线客户端列表
  List<Map<String, dynamic>> onlineClients = [];

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

  Future<void> connect(String address, String token, {String? name}) async {
    _currentToken = token;
    final base = address.startsWith('ws://') || address.startsWith('wss://')
        ? address
        : 'ws://$address';

    final url = '$base/hub';

    Log.info('HubClient', '连接到 $url');
    _socket = await WebSocket.connect(url);
    Log.info('HubClient', '✅ 已连接，发送鉴权...');

    // 连上后第一条消息发鉴权
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
      (raw) {
        final rawData = jsonDecode(raw as String) as Map<String, dynamic>;
        // ← 用新变量接收解密结果
        final data = _decryptPayload(rawData);
        switch (data['type']) {
          case 'welcome':
            HubCrypto.init(_currentToken!);
            myId = data['yourId'];
            roomList = List<Map<String, dynamic>>.from(data['rooms'] ?? []);
            currentRoomId = data['room']?['id'];
            currentRoomName = data['room']?['name'];
            lobbyRoomId = data['room']?['id'];
            onlineClients = List<Map<String, dynamic>>.from(
              data['clients'] ?? [],
            ); // ← 加
            final me = onlineClients.firstWhereOrNull((c) => c['id'] == myId);
            isGlobalAdmin = me?['isGlobalAdmin'] == true;
            Log.info(
              'HubClient',
              '✅ 鉴权成功  ID：$myId  在线：${onlineClients.length}个',
            );
            onConnected?.call();

          case 'room_joined':
            currentRoomId = data['room']?['id'];
            currentRoomName = data['room']?['name'];
            Log.info('HubClient', '🚪 加入房间：$currentRoomName');
            onMessage?.call(data);

          case 'broadcast':
            final from = data['from'] as String?;
            if (from != null && _localBlacklist.contains(from)) return;

            messageHistory.add(Map<String, dynamic>.from(data));
            Log.info('HubClient', '广播  from:$from  ${data['payload']}');
            onMessage?.call(data);

          case 'unicast':
            final from = data['from'] as String?;
            if (from != null && _localBlacklist.contains(from)) return;
            messageHistory.add(Map<String, dynamic>.from(data));
            Log.info('HubClient', '私信  from:$from  ${data['payload']}');
            onMessage?.call(data);

          case 'system':
            final event = data['payload']?['event'];
            Log.info('HubClient', '系统：$event');
            final from = data['from'] as String?;
            if (from != null &&
                from != 'server' &&
                _localBlacklist.contains(from)) {
              return;
            }
            if (event == 'server_shutdown') {
              Log.info('HubClient', '🛑 服务端关闭');
            } else if (event == 'message_recalled') {
              final msgId = data['payload']['msgId'];
              Log.info('HubClient', '↩️ 消息已撤回：$msgId');
            } else if (event == 'global_admin_changed') {
              if (data['payload']['clientId'] == myId) {
                isGlobalAdmin = data['payload']['isGlobalAdmin'] == true;
                Log.info('HubClient', '👑 全局管理员状态变更：$isGlobalAdmin');
              }
            } else if (event == 'room_created') {
              final room = data['payload']['room'] as Map<String, dynamic>;
              roomList.removeWhere((r) => r['id'] == room['id']);
              roomList.add(room);
              Log.info('HubClient', '🏠 新房间：${room['name']}');
            } else if (event == 'room_deleted') {
              final roomId = data['payload']['roomId'];
              roomList.removeWhere((r) => r['id'] == roomId);
              Log.info('HubClient', '🗑️ 房间已删除：$roomId');
            } else if (event == 'client_joined') {
              final client = data['payload']['client'] as Map<String, dynamic>;
              onlineClients.removeWhere((c) => c['id'] == client['id']);
              onlineClients.add(client);
            } else if (event == 'client_left') {
              onlineClients.removeWhere(
                (c) => c['id'] == data['payload']['clientId'],
              );
            } else if (event == 'profile_updated') {
              final client = data['payload']['client'] as Map<String, dynamic>;
              final idx = onlineClients.indexWhere(
                (c) => c['id'] == client['id'],
              );
              if (idx != -1) onlineClients[idx] = client;
            } else if (event == 'status_changed') {
              final idx = onlineClients.indexWhere(
                (c) => c['id'] == data['payload']['clientId'],
              );
              if (idx != -1) {
                onlineClients[idx]['status'] = data['payload']['status'];
              }
            } else if (event == 'you_are_room_banned') {
              final roomName = data['payload']['roomName'] ?? '';
              Log.warning('HubClient', '🚫 已被禁止进入房间：$roomName');
            } else if (event == 'you_are_room_unbanned') {
              final roomName = data['payload']['roomName'] ?? '';
              Log.info('HubClient', '✅ 已解除房间封禁：$roomName');
            } else if (event == 'kicked_from_room') {
              Log.warning('HubClient', '👢 已被踢出房间');
            }
            onMessage?.call(data);

          case 'pong':
            Log.info('HubClient', 'pong');

          case 'kicked':
            Log.warning('HubClient', '🚫 被踢出：${data['message']}');
            onMessage?.call(data);

          case 'error':
            Log.warning('HubClient', '❌ 错误：${data['message']}');
            onMessage?.call(data);

          default:
            Log.warning('HubClient', '未知消息类型：${data['type']}');
        }
      },
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

  static const _bioKey = 'hub_client_bio';

  String? get savedBio => appdata.implicitData[_bioKey] as String?;

  void saveBio(String bio) {
    appdata.implicitData[_bioKey] = bio;
    appdata.writeImplicitData();
  }

  void broadcast(dynamic payload) {
    final payloadStr = jsonEncode(payload);
    _socket?.add(
      jsonEncode({
        'type': 'broadcast',
        'payload': HubCrypto.isInitialized
            ? HubCrypto.encrypt(payloadStr)
            : payloadStr,
        'encrypted': HubCrypto.isInitialized,
      }),
    );
  }

  void sendTo(String targetId, dynamic payload) {
    final payloadStr = jsonEncode(payload);
    _socket?.add(
      jsonEncode({
        'type': 'unicast',
        'to': targetId,
        'payload': HubCrypto.isInitialized
            ? HubCrypto.encrypt(payloadStr)
            : payloadStr,
        'encrypted': HubCrypto.isInitialized,
      }),
    );
  }

  void ping() {
    _socket?.add(jsonEncode({'type': 'ping'}));
  }

  // HubClient 里加
  void recall(String msgId) {
    _socket?.add(jsonEncode({'type': 'recall', 'msgId': msgId}));
  }

  // 回复消息
  void reply(String replyToId, dynamic payload) {
    final payloadStr = jsonEncode(payload);
    _socket?.add(
      jsonEncode({
        'type': 'broadcast',
        'replyTo': replyToId,
        'payload': HubCrypto.isInitialized
            ? HubCrypto.encrypt(payloadStr)
            : payloadStr,
        'encrypted': HubCrypto.isInitialized,
      }),
    );
  }

  // 消息反应
  void react(String msgId, String emoji) {
    _socket?.add(
      jsonEncode({'type': 'reaction', 'msgId': msgId, 'emoji': emoji}),
    );
  }

  // 置顶消息
  void pin(String msgId) {
    _socket?.add(jsonEncode({'type': 'pin', 'msgId': msgId}));
  }

  // 搜索消息
  void search(String keyword) {
    _socket?.add(jsonEncode({'type': 'search', 'keyword': keyword}));
  }

  // 更新状态
  void setStatus(UserStatus status) {
    _socket?.add(jsonEncode({'type': 'status', 'status': status.name}));
  }

  // 更新资料
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

  // 禁言
  void mute(String targetId, {int seconds = 300}) {
    _socket?.add(
      jsonEncode({'type': 'mute', 'targetId': targetId, 'seconds': seconds}),
    );
  }

  // 解除禁言
  void unmute(String targetId) {
    _socket?.add(jsonEncode({'type': 'unmute', 'targetId': targetId}));
  }

  // 设置全局管理员
  void setGlobalAdmin(String targetId, {bool value = true}) {
    _socket?.add(
      jsonEncode({
        'type': 'set_global_admin',
        'targetId': targetId,
        'value': value,
      }),
    );
  }

  // 设置房间管理员
  void setRoomAdmin(String targetId, {bool value = true}) {
    _socket?.add(
      jsonEncode({
        'type': 'set_room_admin',
        'targetId': targetId,
        'value': value,
      }),
    );
  }

  // 加入房间
  void joinRoom(String roomId, {String? password}) {
    _socket?.add(
      jsonEncode({
        'type': 'join_room',
        'roomId': roomId,
        if (password != null) 'password': password,
      }),
    );
  }

  // 离开房间（回到大厅）
  void leaveRoom() {
    _socket?.add(jsonEncode({'type': 'leave_room'}));
  }

  // 设置公告
  void setAnnouncement(String announcement) {
    _socket?.add(
      jsonEncode({'type': 'set_announcement', 'announcement': announcement}),
    );
  }

  // 设置房间密码
  void setRoomPassword(String? password) {
    _socket?.add(
      jsonEncode({'type': 'set_room_password', 'password': password}),
    );
  }

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

  // 创建房间
  void createRoom(String name, {String? password, String? announcement}) {
    _socket?.add(
      jsonEncode({
        'type': 'create_room',
        'name': name,
        if (password != null) 'password': password,
        if (announcement != null) 'announcement': announcement,
      }),
    );
  }

  void deleteRoom(String roomId) {
    _socket?.add(jsonEncode({'type': 'delete_room', 'roomId': roomId}));
  }

  // 是否是指定房间的管理员
  bool isRoomAdminOf(String? roomId) {
    if (roomId == null) return false;
    final room = roomList.firstWhereOrNull((r) => r['id'] == roomId);
    if (room == null) return false;
    final adminIds = room['adminIds'] as List?;
    return adminIds?.contains(myId) == true || room['ownerId'] == myId;
  }

  // 全局公告
  void announce(String message) {
    _socket?.add(jsonEncode({'type': 'announce', 'message': message}));
  }

  // 踢出房间
  void kickFromRoom(String targetId) {
    _socket?.add(jsonEncode({'type': 'kick', 'targetId': targetId}));
  }

  // 房间封禁
  void roomBan(String targetId) {
    _socket?.add(jsonEncode({'type': 'room_ban', 'targetId': targetId}));
  }

  // 解除房间封禁
  void roomUnban(String targetId) {
    _socket?.add(jsonEncode({'type': 'room_unban', 'targetId': targetId}));
  }

  Map<String, dynamic> _decryptPayload(Map<String, dynamic> data) {
    if (!HubCrypto.isInitialized) return data;
    if (data['encrypted'] != true || data['payload'] is! String) return data;
    try {
      final decrypted = HubCrypto.decrypt(data['payload'] as String);
      final result = Map<String, dynamic>.from(data);
      // 解密后可能是 JSON 字符串，再解一次
      dynamic decoded = decrypted;
      try {
        decoded = jsonDecode(decrypted);
        // 如果还是字符串（说明加密前 jsonEncode 了两次），再解一次
        if (decoded is String) {
          decoded = jsonDecode(decoded);
        }
      } catch (_) {}
      result['payload'] = decoded;
      result.remove('encrypted');
      return result;
    } catch (e) {
      Log.warning('HubClient', '解密失败：$e');
      return data;
    }
  }

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
    HubCrypto.clear(); // ← 清除加密密钥
  }
}
