part of 'package:kostori/foundation/services/services.dart';

class HubClient {
  HubClient(this._ref);

  final Ref _ref;

  final Map<String, String> uploadCache = {};

  // ── WebSocket ────────────────────────────────────────────────────────────

  WebSocket? _socket;
  String? _currentToken;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pongTimeoutTimer;
  Timer? _heartbeatTimer;
  Duration _heartbeatInterval = const Duration(milliseconds: 30000);

  // ── 状态读写 ──────────────────────────────────────────────────────────────

  HubState get _s => _ref.read(hubProvider);

  void _setState(HubState Function(HubState s) updater) =>
      _ref.read(hubProvider.notifier).state = updater(_s);

  // ── 状态代理 getters ──────────────────────────────────────────────────────

  String? get myId => _s.myId;

  bool get isGlobalAdmin => _s.isGlobalAdmin;

  List<HubClientDto> get onlineClients => _s.onlineClients;

  List<HubRoomDto> get roomList => _s.roomList;

  String? get currentRoomId => _s.currentRoomId;

  String? get currentRoomName => _s.currentRoomName;

  String? get lobbyRoomId => _s.lobbyRoomId;

  List<String> get serverBannedIds => _s.serverBannedIds;

  List<HubMessage> get messageHistory => _s.messageHistory;

  List<HubClientDto> get currentRoomClients =>
      _s.currentRoomClients(lobbyRoomId);

  String? get myDisplayName =>
      onlineClients.firstWhereOrNull((c) => c.userId == myId)?.displayName ??
      savedName;

  HubClientDto get serverDto => HubClientDto(
    userId: 'server',
    displayName: 'Server',
    connectedAt: DateTime.now(),
    currentRoomId: '',
  );

  bool get autoReconnect =>
      appdata.settings['hubAutoReconnect'] as bool? ?? false;

  set autoReconnect(bool v) {
    appdata.settings['hubAutoReconnect'] = v;
    appdata.saveData();
  }

  // ── 回调 ──────────────────────────────────────────────────────────────────

  Function(Map<String, dynamic>)? onMessage;
  VoidCallback? onDisconnected;
  VoidCallback? onConnected;
  VoidCallback? onRoomListChanged;
  VoidCallback? onClientsChanged;

  // ── 黑名单 ────────────────────────────────────────────────────────────

  final Set<String> _localBlacklist = {};

  List<String> get blockedUsers => _localBlacklist.toList();

  void blockUser(String id) => _localBlacklist.add(id);

  void unblockUser(String id) => _localBlacklist.remove(id);

  bool isBlocked(String id) => _localBlacklist.contains(id);

  // ── 管理员工具 ────────────────────────────────────────────────────────────

  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  bool isRoomAdminOf(String? roomId) {
    if (roomId == null) return false;
    final room = roomList.firstWhereOrNull((r) => r.roomId == roomId);
    if (room == null) return false;
    return room.moderatorIds.contains(myId) || room.ownerUserId == myId;
  }

  // ── 持久化 ────────────────────────────────────────────────────────────────

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

  bool get shouldReconnect => _shouldReconnect;

  void saveAddress(String v) {
    appdata.implicitData[_addressKey] = v;
    appdata.writeImplicitData();
  }

  void saveName(String v) {
    appdata.implicitData[_nameKey] = v;
    appdata.writeImplicitData();
  }

  void saveToken(String v) {
    appdata.implicitData[_tokenKey] = v;
    appdata.writeImplicitData();
  }

  void saveAvatar(String v) {
    appdata.implicitData[_avatarKey] = v;
    appdata.writeImplicitData();
  }

  void saveBio(String v) {
    appdata.implicitData[_bioKey] = v;
    appdata.writeImplicitData();
  }

  // ── 连接 ──────────────────────────────────────────────────────────────────

  Future<void> connect(String address, String token, {String? name}) async {
    _currentToken = token;
    final base = address.startsWith('ws://') || address.startsWith('wss://')
        ? address
        : 'ws://$address';
    final url = '$base/hub';

    final deviceId = await getDeviceId();
    final displayName = name ?? savedName ?? await getDefaultDisplayName();

    Log.info('HubClient', '连接到 $url  deviceId=$deviceId');
    _socket = await WebSocket.connect(url);
    Log.info('HubClient', '✅ 已连接，发送鉴权...');

    _socket!.add(
      jsonEncode({
        'type': 'auth',
        'token': token,
        'displayName': displayName,
        'userId': deviceId,
        'biography': savedBio ?? '',
        'avatarUrl': savedAvatar ?? '',
      }),
    );

    _socket!.listen(
      _handleRaw,
      onDone: () {
        Log.info('HubClient', '🔴 连接断开');
        _stopHeartbeat();
        _socket = null;
        _setState((s) => s.copyWith(isConnected: false, myId: null));
        onDisconnected?.call();
        if (_shouldReconnect && autoReconnect) _scheduleReconnect();
      },
      onError: (e) {
        Log.error('HubClient', '❌ 错误：$e');
        _stopHeartbeat();
        _socket = null;
        _setState((s) => s.copyWith(isConnected: false, myId: null));
        onDisconnected?.call();
        if (_shouldReconnect && autoReconnect) _scheduleReconnect();
      },
    );
    _startHeartbeat();
  }

  void _handleRaw(dynamic raw) {
    final data = _decryptPayload(
      jsonDecode(raw as String) as Map<String, dynamic>,
    );
    _handleMessage(data);
  }

  // ── 断开 ──────────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _stopHeartbeat();
    await _socket?.close();
    _socket = null;
    HubCrypto.clear();
    _ref.read(hubProvider.notifier).state = const HubState();
    onRoomListChanged = null;
    onClientsChanged = null;
    _setState(
      (s) => s.copyWith(
        // ← 加这几行
        isConnected: false,
        myId: null,
      ),
    );
  }

  // ── 解密 ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> _decryptPayload(Map<String, dynamic> data) {
    if (!HubCrypto.isInitialized) return data;
    if (data['encrypted'] != true || data['segments'] is! String) return data;
    try {
      final decrypted = HubCrypto.decrypt(data['segments'] as String);
      final result = Map<String, dynamic>.from(data);
      dynamic decoded = decrypted;
      try {
        decoded = jsonDecode(decrypted);
        if (decoded is String) decoded = jsonDecode(decoded);
      } catch (_) {}
      result['segments'] = decoded;
      result.remove('encrypted');
      return result;
    } catch (e) {
      Log.warning('HubClient', '解密失败：$e');
      return data;
    }
  }

  // ── 心跳 ──────────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_socket != null) {
        ping();
        _pongTimeoutTimer?.cancel();
        _pongTimeoutTimer = Timer(const Duration(seconds: 10), () {
          Log.warning('HubClient', '💀 pong 超时，断线重连');
          _socket?.close();
        });
      } else {
        _heartbeatTimer?.cancel();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    final address = savedAddress;
    final token = savedToken;
    if (address == null || token == null) return;
    final delay = Duration(seconds: min(30, 1 << _reconnectAttempts));
    Log.info(
      'HubClient',
      '🔄 ${delay.inSeconds}s 后重连（第${_reconnectAttempts + 1}次）',
    );
    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempts++;
      await connect(address, token, name: savedName);
    });
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final hubClientProvider = Provider<HubClient>((ref) {
  final client = HubClient(ref);
  ref.onDispose(client.disconnect);
  return client;
});
