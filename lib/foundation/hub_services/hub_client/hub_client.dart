part of 'package:kostori/foundation/hub_services/services.dart';

class HubClient {
  HubClient(this._ref);

  final Ref _ref;

  final Map<String, String> uploadCache = {};

  // ── WebSocket ────────────────────────────────────────────────────────────

  WebSocket? _socket;
  int _socketGeneration = 0;
  String? _currentToken;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pongTimeoutTimer;
  Timer? _heartbeatTimer;
  Duration _heartbeatInterval = const Duration(milliseconds: 30000);

  // ── 状态读写 ──────────────────────────────────────────────────────────────

  HubState get _s => _ref.read(hubProvider);

  void _setState(HubState Function(HubState s) updater) {
    void apply() => _ref.read(hubProvider.notifier).state = updater(_s);

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle ||
        WidgetsBinding.instance.schedulerPhase ==
            SchedulerPhase.postFrameCallbacks) {
      apply();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    }
  }

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

  // 自定义设置走 implicitData（settings 是 freezed 固定 schema，非字段会被丢弃）
  bool get autoReconnect =>
      appdata.implicitData['hubAutoReconnect'] as bool? ?? false;

  set autoReconnect(bool v) {
    appdata.implicitData['hubAutoReconnect'] = v;
    appdata.writeImplicitData();
  }

  void addMessageListener(void Function(Map<String, dynamic>) fn) {
    _messageListeners.add(fn);
  }

  void removeMessageListener(void Function(Map<String, dynamic>) fn) {
    _messageListeners.remove(fn);
  }

  String? activeDmUserId;
  final Map<String, int> dmUnread = {};

  void clearDmUnread(String userId) {
    dmUnread.remove(userId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onClientsChanged?.call();
    });
  }

  void _incrementDmUnread(String userId) {
    dmUnread[userId] = (dmUnread[userId] ?? 0) + 1;
    onClientsChanged?.call();
  }

  // ── 回调 ──────────────────────────────────────────────────────────────────
  final List<void Function(Map<String, dynamic>)> _messageListeners = [];
  VoidCallback? onDisconnected;
  VoidCallback? onConnected;
  VoidCallback? onRoomListChanged;
  VoidCallback? onClientsChanged;
  Function(HubMessage message)? onBotMessage;

  // ── 黑名单 ────────────────────────────────────────────────────────────

  final Set<String> _localBlacklist = {};

  List<String> get blockedUsers => _localBlacklist.toList();

  void blockUser(String id) {
    _localBlacklist.add(id);
    _setState((s) => s.copyWith(blockedUserIds: {..._localBlacklist}));
  }

  void unblockUser(String id) {
    _localBlacklist.remove(id);
    _setState((s) => s.copyWith(blockedUserIds: {..._localBlacklist}));
  }

  // isBlocked 保留不变，但 UI 侧不用它了
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
  static const _allowSelfSignedKey = 'hub_client_allow_self_signed';

  String? get savedAddress => appdata.implicitData[_addressKey] as String?;

  String? get savedName => appdata.implicitData[_nameKey] as String?;

  /// 是否允许自签名证书（默认 true，方便自建 HTTPS 服务）
  bool get allowSelfSignedCert =>
      appdata.implicitData[_allowSelfSignedKey] as bool? ?? true;

  set allowSelfSignedCert(bool v) {
    appdata.implicitData[_allowSelfSignedKey] = v;
    appdata.writeImplicitData();
  }

  String? get savedToken {
    final raw = appdata.implicitData[_tokenKey] as String?;
    if (raw == null || raw.isEmpty) return null;
    final decrypted = SecretVault.decrypt(raw);
    return decrypted.isEmpty ? null : decrypted;
  }

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
    appdata.implicitData[_tokenKey] = SecretVault.encrypt(v);
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

  // ── 已保存的服务器配置（多记忆项，本地持久化，不参与 WebDAV 同步）──────────

  static const _profilesKey = 'hub_profiles';

  /// 已保存的服务器配置列表：[{name, address, token}]（token 已加密存储）。
  /// 返回的 token 已解密，仅用于展示/连接。
  List<Map<String, dynamic>> getProfiles() {
    return _rawProfiles().map((m) {
      return Map<String, dynamic>.from(m)
        ..['token'] = SecretVault.decrypt((m['token'] as String?) ?? '');
    }).toList();
  }

  /// 原始存储（token 保持加密），供内部增删改。
  List<Map<String, dynamic>> _rawProfiles() {
    final raw = appdata.implicitData[_profilesKey];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  /// 保存/更新一个服务器配置（按地址去重，token 加密存储）
  void saveProfile({
    required String name,
    required String address,
    String token = '',
  }) {
    final profiles = _rawProfiles()
      ..removeWhere((p) => p['address'] == address)
      ..add({
        'name': name,
        'address': address,
        'token': SecretVault.encrypt(token),
      });
    appdata.implicitData[_profilesKey] = profiles;
    appdata.writeImplicitData();
  }

  void deleteProfile(String address) {
    final profiles = _rawProfiles()
      ..removeWhere((p) => p['address'] == address);
    appdata.implicitData[_profilesKey] = profiles;
    appdata.writeImplicitData();
  }

  /// 激活某个已保存的配置（切换为当前地址/token）
  void activateProfile(String address) {
    final p = getProfiles().firstWhereOrNull((p) => p['address'] == address);
    if (p == null) return;
    saveAddress(address);
    saveToken((p['token'] as String?) ?? '');
  }

  // ── 连接 ──────────────────────────────────────────────────────────────────

  /// 建立 WebSocket 连接；wss 时若开启「允许自签名证书」则信任自签名。
  Future<WebSocket> _connectSocket(String url) async {
    if (!url.startsWith('wss://')) {
      return WebSocket.connect(url);
    }
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => allowSelfSignedCert;
    try {
      return await WebSocket.connect(url, customClient: client);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> connect(String address, String token, {String? name}) async {
    _currentToken = token;
    final base = address.startsWith('ws://') || address.startsWith('wss://')
        ? address
        : 'ws://$address';
    final url = '$base/hub';

    final deviceId = await getDeviceId();
    final displayName = name ?? savedName ?? await getDefaultDisplayName();

    HubLog.info('HubClient', '连接到 $url  deviceId=$deviceId');
    final socket = await _connectSocket(url);
    final gen = ++_socketGeneration;
    _socket = socket;
    HubLog.info('HubClient', '✅ 已连接，发送鉴权...');

    socket.add(
      jsonEncode({
        'type': 'auth',
        'token': token,
        'displayName': displayName,
        'userId': deviceId,
        'biography': savedBio ?? '',
        'avatarUrl': savedAvatar ?? '',
      }),
    );

    socket.listen(
      _handleRaw,
      onDone: () {
        // 只处理最新一代 socket 的断开，避免旧 socket 回调清掉新连接
        if (gen != _socketGeneration) return;
        HubLog.info('HubClient', '🔴 连接断开');
        _stopHeartbeat();
        _socket = null;
        HubKeepAlive.stop();
        _setState((s) => s.copyWith(isConnected: false, myId: null));
        onDisconnected?.call();
        if (_shouldReconnect && autoReconnect) _scheduleReconnect();
      },
      onError: (e) {
        if (gen != _socketGeneration) return;
        HubLog.error('HubClient', '❌ 错误：$e');
        _stopHeartbeat();
        _socket = null;
        HubKeepAlive.stop();
        _setState((s) => s.copyWith(isConnected: false, myId: null));
        onDisconnected?.call();
        if (_shouldReconnect && autoReconnect) _scheduleReconnect();
      },
    );
    _startHeartbeat();
  }

  void _handleRaw(dynamic raw) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(raw as String);
      data = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (e) {
      HubLog.warning('HubClient', '收到无法解析的帧，已忽略：$e');
      return;
    }
    try {
      final decrypted = _decryptPayload(data);
      _handleMessage(decrypted);
    } catch (e, st) {
      HubLog.warning('HubClient', '处理消息失败：$e\n$st');
    }
  }

  // ── 断开 ──────────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _stopHeartbeat();
    HubKeepAlive.stop();
    await _socket?.close();
    _socket = null;
    HubCrypto.clear();
    _ref.read(hubProvider.notifier).state = const HubState();
    onRoomListChanged = null;
    onClientsChanged = null;
    _setState((s) => s.copyWith(isConnected: false, myId: null));
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
      HubLog.warning('HubClient', '解密失败：$e');
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
          HubLog.warning('HubClient', '💀 pong 超时，断线重连');
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
    HubLog.info(
      'HubClient',
      '🔄 ${delay.inSeconds}s 后重连（第${_reconnectAttempts + 1}次）',
    );
    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempts++;
      try {
        await connect(address, token, name: savedName);
      } catch (e, st) {
        // 重连失败：记录并继续调度，避免未捕获异步异常导致闪退
        HubLog.error('HubClient', '重连失败：$e\n$st');
        _shouldReconnect = true;
        _scheduleReconnect();
      }
    });
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final hubClientProvider = Provider<HubClient>((ref) {
  final client = HubClient(ref);
  ref.onDispose(client.disconnect);
  return client;
});
