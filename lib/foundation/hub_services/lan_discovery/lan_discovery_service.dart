part of 'package:kostori/foundation/hub_services/services.dart';

enum LanDiscoveryServiceState { idle, discovering, broadcasting, error }

class LanDiscoveryService {
  LanDiscoveryService._();

  static final LanDiscoveryService instance = LanDiscoveryService._();

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final Set<void Function(LanDiscoveredDevice)> _onDeviceDiscovered = {};
  final Set<void Function(LanDiscoveredDevice)> _onDeviceLeft = {};
  final Set<void Function(LanDiscoveryServiceState, String?)> _onStateChanged =
      {};
  final Set<void Function(LanPairingRequest)> _onPairingRequest = {};
  final Set<void Function(LanPairingResponse)> _onPairingResponse = {};

  final Map<String, LanDiscoveredDevice> _devices = {};
  LanDiscoveryServiceState _state = LanDiscoveryServiceState.idle;
  String? _lastError;

  String? _deviceId;
  String? _deviceName;
  LanDeviceType _deviceType = LanDeviceType.unknown;
  String? _avatarUrl;
  Map<String, dynamic>? _capabilities;
  int _hubPort = 42183;

  String? _currentPairingToken;
  DateTime? _currentPairingExpiry;

  String? _cachedLocalIp;
  List<InternetAddress> _broadcastAddresses = const [];
  Timer? _networkRefreshTimer;
  bool _multicastJoined = false;
  final Set<String> _joinedMulticastInterfaces = {};
  ServerSocket? _tcpSocket;
  String _multicastGroup = kLanMulticastGroup;

  LanDiscoveryServiceState get state => _state;

  String? get lastError => _lastError;

  Map<String, LanDiscoveredDevice> get discoveredDevices =>
      Map.unmodifiable(_devices);

  List<LanDiscoveredDevice> get devicesList => _devices.values.toList();

  Future<void> init({
    required String deviceId,
    required String deviceName,
    required LanDeviceType deviceType,
    String? avatarUrl,
    Map<String, dynamic>? capabilities,
    int hubPort = 42183,
    String? multicastGroup,
  }) async {
    _deviceId = deviceId;
    _deviceName = deviceName;
    _deviceType = deviceType;
    _avatarUrl = avatarUrl;
    _capabilities = capabilities;
    _hubPort = hubPort;
    if (multicastGroup != null && multicastGroup.trim().isNotEmpty) {
      _multicastGroup = multicastGroup.trim();
    }
    await _refreshLocalIp();
  }

  /// 修改组播地址（多线程广播）。若发现已启动则重绑 socket 以加入新组播组。
  Future<void> setMulticastGroup(String group) async {
    final g = group.trim();
    if (g.isEmpty || g == _multicastGroup) return;
    _multicastGroup = g;
    _joinedMulticastInterfaces.clear();
    if (_socket != null) {
      await _bindSocket();
    }
  }

  void addDeviceDiscoveredListener(
    void Function(LanDiscoveredDevice) listener,
  ) {
    _onDeviceDiscovered.add(listener);
  }

  void removeDeviceDiscoveredListener(
    void Function(LanDiscoveredDevice) listener,
  ) {
    _onDeviceDiscovered.remove(listener);
  }

  void addDeviceLeftListener(void Function(LanDiscoveredDevice) listener) {
    _onDeviceLeft.add(listener);
  }

  void removeDeviceLeftListener(void Function(LanDiscoveredDevice) listener) {
    _onDeviceLeft.remove(listener);
  }

  void addStateChangedListener(
    void Function(LanDiscoveryServiceState, String?) listener,
  ) {
    _onStateChanged.add(listener);
  }

  void removeStateChangedListener(
    void Function(LanDiscoveryServiceState, String?) listener,
  ) {
    _onStateChanged.remove(listener);
  }

  void addPairingRequestListener(void Function(LanPairingRequest) listener) {
    _onPairingRequest.add(listener);
  }

  void removePairingRequestListener(void Function(LanPairingRequest) listener) {
    _onPairingRequest.remove(listener);
  }

  void addPairingResponseListener(void Function(LanPairingResponse) listener) {
    _onPairingResponse.add(listener);
  }

  void removePairingResponseListener(
    void Function(LanPairingResponse) listener,
  ) {
    _onPairingResponse.remove(listener);
  }

  void _notifyStateChanged() {
    for (final listener in _onStateChanged) {
      listener(_state, _lastError);
    }
  }

  void _notifyDeviceDiscovered(LanDiscoveredDevice device) {
    for (final listener in _onDeviceDiscovered) {
      listener(device);
    }
  }

  void _notifyDeviceLeft(LanDiscoveredDevice device) {
    for (final listener in _onDeviceLeft) {
      listener(device);
    }
  }

  void _notifyPairingRequest(LanPairingRequest request) {
    for (final listener in _onPairingRequest) {
      listener(request);
    }
  }

  void _notifyPairingResponse(LanPairingResponse response) {
    for (final listener in _onPairingResponse) {
      listener(response);
    }
  }

  Future<void> startDiscovery() async {
    if (_state == LanDiscoveryServiceState.discovering ||
        _state == LanDiscoveryServiceState.broadcasting) {
      return;
    }

    try {
      await _bindSocket();
      await _bindTcpSocket();
      _setState(LanDiscoveryServiceState.discovering);
      _startBroadcasting();
      _startCleanupTimer();
      _startNetworkRefresh();
    } catch (e) {
      _lastError = '启动发现失败: $e';
      _setState(LanDiscoveryServiceState.error);
    }
  }

  void stopDiscovery() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _networkRefreshTimer?.cancel();
    _networkRefreshTimer = null;
    _tcpSocket?.close();
    _tcpSocket = null;
    _socket?.close();
    _socket = null;
    _setState(LanDiscoveryServiceState.idle);
  }

  Future<void> refresh() async {
    if (_state != LanDiscoveryServiceState.discovering) {
      await startDiscovery();
      return;
    }
    _devices.clear();
    _broadcastRequest();
  }

  String generatePairingQrContent() {
    final token = _generateToken();
    _currentPairingToken = token;
    _currentPairingExpiry = DateTime.now().add(const Duration(seconds: 10));

    final payload = [
      _deviceId ?? '',
      _deviceName ?? 'Unknown',
      token,
      _effectiveHubPort.toString(),
      _cachedLocalIp ?? '',
    ].join('|');

    final encoded = ProtocolParser.encodeWithBase64Payload(
      KostoriRouteType.remote,
      payload,
    );

    return encoded;
  }

  String? get currentPairingToken => _currentPairingToken;

  int get pairingTokenRemainingSeconds {
    if (_currentPairingExpiry == null) return 0;
    final diff = _currentPairingExpiry!.difference(DateTime.now());
    return diff.inSeconds.clamp(0, 10);
  }

  bool isPairingTokenValid(String token) {
    if (_currentPairingToken == null || _currentPairingExpiry == null) {
      return false;
    }
    return _currentPairingToken == token &&
        !_currentPairingExpiry!.isBefore(DateTime.now());
  }

  Future<void> handlePairingRequest(
    LanPairingRequest request,
    int senderPort,
  ) async {
    if (!isPairingTokenValid(request.token)) {
      _notifyPairingResponse(
        LanPairingResponse(
          targetId: _deviceId ?? '',
          accepted: false,
          errorMessage: t.tokenInvalidOrExpired,
        ),
      );
      return;
    }

    _notifyPairingRequest(request);
    _sendPairingResponse(
      targetId: request.requesterId,
      accepted: true,
      targetPort: senderPort,
    );
  }

  void _sendPairingResponse({
    required String targetId,
    required bool accepted,
    String? errorMessage,
    int? targetPort,
  }) {
    if (_socket == null) return;

    final response = LanPairingResponse(
      targetId: targetId,
      accepted: accepted,
      wsUrl: accepted ? 'ws://${_getLocalIp()}:$_effectiveHubPort/hub' : null,
      errorMessage: errorMessage,
    );

    if (targetPort != null) {
      final device = _devices[targetId];
      if (device != null) {
        try {
          _socket!.send(
            utf8.encode(jsonEncode(response.toJson())),
            InternetAddress(device.ip),
            targetPort,
          );
          return;
        } catch (e) {
          HubLog.warning('LanDiscovery', '直接发送配对响应失败: $e');
        }
      }
    }

    _broadcast(response.toJson(), toSpecificDevice: targetId);
  }

  String _generateToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(999999);
    return '${timestamp}_$random';
  }

  Future<void> _bindSocket() async {
    _socket?.close();

    try {
      final isWindows = Platform.isWindows;
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        kLanDiscoveryPort,
        reuseAddress: true,
        reusePort: !isWindows,
      );

      _socket!.broadcastEnabled = true;
      HubLog.info('LanDiscovery', 'UDP 绑定成功，端口: ${_socket!.port}');

      await _joinMulticastGroups();
      _refreshNetworkInfo();

      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_socket == null) {
          timer.cancel();
          return;
        }
        try {
          final dg = _socket!.receive();
          if (dg != null) {
            _handleDatagram(dg);
          }
        } catch (_) {}
      });
    } catch (e) {
      HubLog.warning('LanDiscovery', 'UDP 绑定失败: $e，尝试随机端口');
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;
      HubLog.info('LanDiscovery', 'UDP 绑定成功（随机端口），端口: ${_socket!.port}');
      await _joinMulticastGroups();
      _refreshNetworkInfo();
    }
  }

  InternetAddress get _multicastGroupAddress =>
      InternetAddress(_multicastGroup);

  Future<void> _joinMulticastGroups() async {
    final socket = _socket;
    if (socket == null) return;
    try {
      final group = InternetAddress(kLanMulticastGroup);
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      final currentNames = interfaces.map((i) => i.name).toSet();
      _joinedMulticastInterfaces.removeWhere((n) => !currentNames.contains(n));
      var joined = _joinedMulticastInterfaces.length;
      for (final interface in interfaces) {
        if (_joinedMulticastInterfaces.contains(interface.name)) continue;
        // 跳过 Clash/Tailscale 等代理虚拟网卡，组播只在真实局域网接口上收发
        final addr = interface.addresses
            .where((a) => !a.isLoopback && a.type == InternetAddressType.IPv4)
            .toList();
        final lanAddr = addr
            .where((a) => !_isProxyTunIp(a.address))
            .firstOrNull;
        if (lanAddr == null) continue;
        try {
          socket.joinMulticast(group, interface);
          _joinedMulticastInterfaces.add(interface.name);
          joined++;
          HubLog.info(
            'LanDiscovery',
            '加入组播 $kLanMulticastGroup (${interface.name} / ${lanAddr.address})',
          );
        } catch (e) {
          HubLog.warning('LanDiscovery', '加入组播失败 ${interface.name}: $e');
        }
      }
      _multicastJoined = joined > 0;
      HubLog.info('LanDiscovery', '组播加入完成: $joined 个接口');
    } catch (e) {
      HubLog.warning('LanDiscovery', '组播初始化失败: $e');
    }
  }

  Future<void> _bindTcpSocket() async {
    _tcpSocket?.close();
    _tcpSocket = null;
    try {
      // 与 UDP 发现同端口提供 TCP 通道：UDP 入站被网络环境拦截时仍可被发现
      _tcpSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        kLanDiscoveryPort,
        shared: true,
      );
      _tcpSocket!.listen(
        _handleTcpConnection,
        onError: (Object e) => HubLog.warning('LanDiscovery', 'TCP 发现连接异常: $e'),
      );
      HubLog.info('LanDiscovery', 'TCP 发现监听成功，端口: ${_tcpSocket!.port}');
    } catch (e) {
      _tcpSocket = null;
      HubLog.warning('LanDiscovery', 'TCP 发现监听失败: $e');
    }
  }

  void _startNetworkRefresh() {
    _networkRefreshTimer?.cancel();
    // 网络变化时刷新本机 IP 与广播地址，保证 wsUrl / 广播可达
    _networkRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshNetworkInfo(),
    );
  }

  void _refreshNetworkInfo() {
    _refreshLocalIp();
    _refreshBroadcastAddresses();
    _joinMulticastGroups();
  }

  Future<void> _refreshBroadcastAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      final addresses = <InternetAddress>[];
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.isLoopback) continue;
          // 只向 192.168 局域网广播，排除 VPN / 虚拟网卡等其他网段
          if (!_isLanIp(addr.address)) continue;
          final broadcast = _broadcastAddressFor(addr.address);
          if (broadcast != null) {
            addresses.add(InternetAddress(broadcast));
          }
        }
      }

      final unique = <String>{};
      final result = <InternetAddress>[];
      for (final addr in addresses) {
        if (unique.add(addr.address)) {
          result.add(addr);
        }
      }

      _broadcastAddresses = result;
    } catch (_) {
      _broadcastAddresses = const [];
    }
  }

  bool _isLanIp(String ip) => ip.startsWith('192.168.');

  bool _isProxyTunIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]) ?? -1;
    final b = int.tryParse(parts[1]) ?? -1;
    // Clash 等代理 TUN 默认使用 198.18.0.0/15；Tailscale/CGNAT 使用 100.64.0.0/10
    if (a == 198 && (b == 18 || b == 19)) return true;
    if (a == 100 && b >= 64 && b <= 127) return true;
    return false;
  }

  String? _broadcastAddressFor(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    final subnet = parts[3];
    if (subnet == '0' || subnet == '255') return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }

  void _startBroadcasting() {
    if (_deviceId == null) {
      HubLog.warning('LanDiscovery', '设备ID未设置，延迟广播启动');
      return;
    }

    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(
      Duration(seconds: kLanBroadcastInterval),
      (_) => _broadcastRequest(),
    );
    _broadcastRequest();
  }

  int get _effectiveHubPort {
    final server = LanControlService.instance;
    if (server.isListening) {
      return server.port;
    }
    return _hubPort;
  }

  void _broadcastRequest() {
    if (_socket == null || _deviceId == null) return;

    final request = LanDiscoveryRequest(
      senderId: _deviceId!,
      senderName: _deviceName ?? 'Unknown',
      deviceType: _deviceType,
      port: _effectiveHubPort,
      avatarUrl: _avatarUrl,
      capabilities: _capabilities,
    );

    _broadcast(request.toJson());
  }

  void _broadcast(Map<String, dynamic> data, {String? toSpecificDevice}) {
    if (_socket == null) {
      HubLog.warning('LanDiscovery', 'Socket 未初始化，无法广播');
      return;
    }

    try {
      final jsonStr = jsonEncode(data);
      final bytes = utf8.encode(jsonStr);

      if (toSpecificDevice != null) {
        final device = _devices[toSpecificDevice];
        if (device != null) {
          final addr = InternetAddress(device.ip);
          _socket!.send(bytes, addr, kLanDiscoveryPort);
        }
        return;
      }

      if (_broadcastAddresses.isEmpty) {
        _broadcastAddresses = [InternetAddress('255.255.255.255')];
      }
      for (final addr in _broadcastAddresses) {
        try {
          _socket!.send(bytes, addr, kLanDiscoveryPort);
        } catch (e) {
          HubLog.warning('LanDiscovery', '广播到 ${addr.address} 失败: $e');
        }
      }
      // 多线程广播：向组播地址广播，路由器/AP 对组播的转发通常比子网广播更可靠
      try {
        _socket!.send(bytes, _multicastGroupAddress, kLanDiscoveryPort);
      } catch (e) {
        HubLog.warning('LanDiscovery', '组播发送失败: $e');
      }
    } catch (e) {
      HubLog.warning('LanDiscovery', '广播失败: $e');
    }
  }

  void _handleDatagram(Datagram dg) {
    try {
      final data = utf8.decode(dg.data);
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final senderIp = dg.address.address;

      HubLog.info('LanDiscovery', '收到 UDP 数据: type=$type, from=$senderIp');

      if (_isOwnMessage(json)) return;

      switch (type) {
        case 'discovery_request':
          _handleDiscoveryRequest(json, senderIp, dg.port);
          break;
        case 'discovery_response':
          _handleDiscoveryResponse(json);
          break;
        case 'pairing_request':
          _handlePairingRequestJson(json, dg.port);
          break;
        case 'pairing_response':
          _handlePairingResponseJson(json);
          break;
        default:
          HubLog.warning('LanDiscovery', '未知消息类型: $type');
      }
    } catch (e) {
      HubLog.warning('LanDiscovery', '处理数据报失败: $e');
    }
  }

  void _handleTcpConnection(Socket socket) {
    final remoteIp = socket.remoteAddress.address;
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    final buffer = BytesBuilder();
    StreamSubscription<List<int>>? sub;
    final timeout = Timer(const Duration(seconds: 3), () {
      sub?.cancel();
      socket.destroy();
    });

    void finish() {
      timeout.cancel();
      sub?.cancel();
      socket.destroy();
    }

    sub = socket.listen(
      (chunk) {
        buffer.add(chunk);
        final json = _tryDecodeJson(buffer);
        if (json == null) return;
        final type = json['type'] as String?;
        switch (type) {
          case 'discovery_request':
            _handleTcpDiscoveryRequest(json, remoteIp, socket);
            break;
          case 'discovery_response':
            _handleDiscoveryResponse(json);
            break;
          default:
            HubLog.warning('LanDiscovery', 'TCP 收到未知消息类型: $type');
        }
        timeout.cancel();
        sub?.cancel();
        socket.flush().then(
          (_) => socket.destroy(),
          onError: (_) => socket.destroy(),
        );
      },
      onError: (_) => finish(),
      onDone: finish,
    );
  }

  void _handleTcpDiscoveryRequest(
    Map<String, dynamic> json,
    String remoteIp,
    Socket socket,
  ) {
    if (!_isLanIp(remoteIp) || remoteIp == _getLocalIp()) return;
    if (_isOwnMessage(json)) return;
    final request = LanDiscoveryRequest.fromJson(json);
    HubLog.info(
      'LanDiscovery',
      'TCP 收到设备发现请求: ${request.senderName} ($remoteIp)',
    );

    _sendTcpResponse(socket, remoteIp);

    _addOrUpdateDevice(
      LanDiscoveredDevice(
        id: request.senderId,
        name: request.senderName,
        ip: remoteIp,
        port: request.port,
        deviceType: request.deviceType,
        avatarUrl: request.avatarUrl,
        discoveredAt: DateTime.now(),
        lastSeen: DateTime.now(),
        capabilities: request.capabilities,
      ),
    );
  }

  Map<String, dynamic>? _tryDecodeJson(BytesBuilder buffer) {
    try {
      final decoded = jsonDecode(utf8.decode(buffer.toBytes()));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  LanDiscoveryResponse _buildResponse() => LanDiscoveryResponse(
    senderId: _deviceId ?? '',
    senderName: _deviceName ?? 'Unknown',
    deviceType: _deviceType,
    ip: _getLocalIp(),
    port: _effectiveHubPort,
    avatarUrl: _avatarUrl,
    capabilities: _capabilities,
  );

  void _sendTcpResponse(Socket socket, String remoteIp) {
    try {
      socket.add(utf8.encode(jsonEncode(_buildResponse().toJson())));
    } catch (e) {
      HubLog.warning('LanDiscovery', 'TCP 发送响应失败: $e');
    }
  }

  /// 通过 TCP 主动连接对方并回发本机信息，绕过被拦截的 UDP 回包通道。
  Future<void> _tryTcpResponseTo(String senderIp) async {
    if (!_isLanIp(senderIp) || senderIp == _getLocalIp()) return;
    try {
      final socket = await Socket.connect(
        senderIp,
        kLanDiscoveryPort,
        timeout: const Duration(seconds: 2),
      );
      try {
        _sendTcpResponse(socket, senderIp);
        await socket.flush();
      } finally {
        socket.destroy();
      }
    } catch (_) {
      // 对方未开启 TCP 发现通道（旧版本/非本应用），静默忽略
    }
  }

  bool _isOwnMessage(Map<String, dynamic> json) {
    final senderId = json['senderId'] as String?;
    return senderId == _deviceId;
  }

  void _handleDiscoveryRequest(
    Map<String, dynamic> json,
    String senderIp,
    int senderPort,
  ) {
    final request = LanDiscoveryRequest.fromJson(json);

    if (!_isLanIp(senderIp)) {
      HubLog.warning('LanDiscovery', '忽略非局域网广播: $senderIp（仅支持 192.168 网段）');
      return;
    }

    final localIp = _getLocalIp();
    if (senderIp == localIp) {
      HubLog.info('LanDiscovery', '忽略自己的广播');
      return;
    }

    if (_isOwnMessage(json)) {
      HubLog.info('LanDiscovery', '忽略自己的消息（senderId匹配）');
      return;
    }

    HubLog.info('LanDiscovery', '收到设备广播: ${request.senderName} ($senderIp)');

    _sendResponseToSender(_buildResponse(), senderIp, senderPort);

    // UDP 回包可能被网络环境拦截，额外尝试通过 TCP 把本机信息回给对方
    unawaited(_tryTcpResponseTo(senderIp));

    _addOrUpdateDevice(
      LanDiscoveredDevice(
        id: request.senderId,
        name: request.senderName,
        ip: senderIp,
        port: request.port,
        deviceType: request.deviceType,
        avatarUrl: request.avatarUrl,
        discoveredAt: DateTime.now(),
        lastSeen: DateTime.now(),
        capabilities: request.capabilities,
      ),
    );
  }

  void _handleDiscoveryResponse(Map<String, dynamic> json) {
    try {
      final response = LanDiscoveryResponse.fromJson(json);
      if (!_isLanIp(response.ip)) {
        HubLog.warning('LanDiscovery', '忽略非局域网响应: ${response.ip}');
        return;
      }
      HubLog.info(
        'LanDiscovery',
        '收到设备响应: ${response.senderName} (${response.senderId})',
      );

      final device = response.toDevice();
      final updatedDevice = device.copyWith(
        ip: response.ip,
        port: response.port,
        lastSeen: DateTime.now(),
      );

      _addOrUpdateDevice(updatedDevice);
      HubLog.info(
        'LanDiscovery',
        '设备已添加: ${updatedDevice.name} (${updatedDevice.ip})',
      );
    } catch (e) {
      HubLog.warning('LanDiscovery', '解析发现响应失败: $e');
    }
  }

  void _handlePairingRequestJson(Map<String, dynamic> json, int senderPort) {
    try {
      final request = LanPairingRequest.fromJson(json);
      handlePairingRequest(request, senderPort);
    } catch (e) {
      HubLog.warning('LanDiscovery', '解析配对请求失败: $e');
    }
  }

  void _handlePairingResponseJson(Map<String, dynamic> json) {
    try {
      final response = LanPairingResponse.fromJson(json);
      _notifyPairingResponse(response);
    } catch (e) {
      HubLog.warning('LanDiscovery', '解析配对响应失败: $e');
    }
  }

  void _sendResponseToSender(
    LanDiscoveryResponse response,
    String senderIp,
    int senderPort,
  ) {
    if (_socket == null) return;

    try {
      final jsonStr = jsonEncode(response.toJson());
      final bytes = utf8.encode(jsonStr);
      final addr = InternetAddress(senderIp);
      // 响应发送到请求方的实际来源端口（固定端口或随机端口均可收到）
      _socket!.send(bytes, addr, senderPort);
    } catch (e) {
      HubLog.warning('LanDiscovery', '发送响应失败: $e');
    }
  }

  void _addOrUpdateDevice(LanDiscoveredDevice device) {
    final existing = _devices[device.id];
    if (existing != null) {
      final updated = existing.copyWith(lastSeen: DateTime.now());
      _devices[device.id] = updated;
      if (existing.ip != device.ip || existing.port != device.port) {
        _notifyDeviceDiscovered(updated);
      }
    } else {
      _devices[device.id] = device;
      _notifyDeviceDiscovered(device);
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _cleanupStaleDevices();
    });
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final staleThreshold = Duration(seconds: kLanBroadcastInterval * 3 + 2);
    final stale = _devices.entries
        .where((e) => now.difference(e.value.lastSeen) > staleThreshold)
        .map((e) => e.key)
        .toList();

    for (final id in stale) {
      final device = _devices.remove(id);
      if (device != null) {
        _notifyDeviceLeft(device);
      }
    }
  }

  /// 网络自检：收集本机 IP / 广播地址 / UDP / TCP 状态并做回环收发测试。
  /// 返回结构化结果供 UI 展示，同时写入 HubLog。
  Future<Map<String, dynamic>> runSelfCheck() async {
    await _refreshLocalIp();
    await _refreshBroadcastAddresses();

    final checks = <Map<String, dynamic>>[];
    void addCheck(String name, bool pass, String detail) {
      checks.add({'name': name, 'pass': pass, 'detail': detail});
    }

    final interfaces = await _collectInterfaces();
    final ipv4 = <String>[];
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          ipv4.add('${addr.address} (${interface.name})');
        }
      }
    }
    final bareIps = ipv4.map((s) => s.split(' (')[0]).toList();

    if (ipv4.isEmpty) {
      addCheck('本机 IPv4 地址', false, '未找到非回环 IPv4 地址，请确认已连接局域网（Wi-Fi/网线）');
    } else {
      addCheck('本机 IPv4 地址', true, ipv4.join('\n'));
    }

    final broadcastIps = _broadcastAddresses.map((a) => a.address).toList();
    if (broadcastIps.isEmpty) {
      addCheck('UDP 广播地址', false, '未计算到任何广播地址');
    } else {
      addCheck(
        'UDP 广播地址',
        true,
        '${broadcastIps.join(', ')}（组播: $_multicastGroup）',
      );
    }

    if (_socket == null) {
      addCheck('UDP 监听', false, '发现 Socket 未绑定，请先点击"开始扫描"');
    } else {
      final port = _socket!.port;
      final detail = port == kLanDiscoveryPort
          ? '已绑定固定端口 $port，正常'
          : '已绑定随机端口 $port（$kLanDiscoveryPort 被占用或处于 TIME_WAIT；旧版本此情况下会扫不到，请确保两端均为最新代码）';
      addCheck('UDP 监听', true, detail);
    }

    addCheck(
      'TCP 发现监听',
      _tcpSocket != null,
      _tcpSocket != null
          ? '正在监听端口 $kLanDiscoveryPort，可接收其他设备的 TCP 发现消息'
          : '未监听 TCP（端口被占用或系统不支持），仅靠 UDP 发现',
    );

    final loopbackOk = await _runLoopbackTest();
    addCheck(
      'UDP 收发测试',
      loopbackOk,
      loopbackOk ? '本机 UDP 发送/接收链路正常' : '本机 UDP 回环收发失败，系统可能阻止 UDP 通信',
    );

    if (_socket != null && _broadcastAddresses.isNotEmpty) {
      final sendError = _tryBroadcastSend();
      addCheck(
        '广播发送调用',
        sendError == null,
        sendError == null
            ? '已向 ${_broadcastAddresses.length} 个广播地址 + 组播 $_multicastGroup 发起发送（是否可达取决于路由器/AP）'
            : '广播发送异常: $sendError',
      );
    }

    final tcpListening = LanControlService.instance.isListening;
    addCheck(
      '被控服务 (WebSocket)',
      tcpListening,
      tcpListening
          ? '正在监听端口 ${LanControlService.instance.port}，可被远程控制'
          : '未启动，即使被发现也无法被控制',
    );

    final server = LanControlService.instance;
    if (server.isListening && server.port != _hubPort) {
      addCheck(
        'Hub 端口一致性',
        false,
        '配置端口 $_hubPort 被占用，实际监听 ${server.port}；已自动广播实际端口，对方按此端口连接',
      );
    } else {
      addCheck('Hub 端口一致性', true, '配置端口 $_hubPort 与实际监听端口一致');
    }

    if (bareIps.isNotEmpty && bareIps.every((ip) => !_isLanIp(ip))) {
      addCheck(
        '局域网 (192.168)',
        false,
        '本机 IPv4 均不在 192.168 网段（${bareIps.join(', ')}），局域网发现可能无法工作',
      );
    } else if (broadcastIps.isNotEmpty &&
        broadcastIps.every((ip) => !_isLanIp(ip))) {
      addCheck(
        '局域网 (192.168)',
        false,
        '未计算到 192.168 网段的广播地址（当前为 ${broadcastIps.join(', ')}）',
      );
    } else {
      addCheck(
        '局域网 (192.168)',
        true,
        '发现限定在 192.168 网段，当前广播地址: ${broadcastIps.join(', ')}',
      );
    }

    final groupJoined = _multicastJoined;
    addCheck(
      '多线程广播（组播）',
      groupJoined,
      groupJoined
          ? '已加入组播组 $_multicastGroup，通过组播+子网广播双通道发现'
          : '未能加入组播组 $_multicastGroup（可能不受当前系统/网络支持），仅靠子网广播发现',
    );

    final summary = {
      'platform': Platform.operatingSystem,
      'udpPort': _socket?.port,
      'localIps': bareIps,
      'broadcastAddresses': broadcastIps,
      'multicastGroup': _multicastGroup,
      'state': _state.name,
      'hubPort': _effectiveHubPort,
      'configuredHubPort': _hubPort,
      'tcpServerListening': tcpListening,
      'checks': checks,
    };

    HubLog.info('LanDiscovery', '网络自检结果: ${jsonEncode(summary)}');
    return summary;
  }

  Future<List<NetworkInterface>> _collectInterfaces() async {
    try {
      return await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: true,
      );
    } catch (_) {
      return [];
    }
  }

  Future<bool> _runLoopbackTest() async {
    RawDatagramSocket? probe;
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      probe = socket;
      final port = socket.port;
      final payload = utf8.encode('kostori_self_check_$_deviceId');
      final received = Completer<bool>();
      socket.listen((event) {
        final dg = socket.receive();
        if (dg == null) return;
        final text = utf8.decode(dg.data, allowMalformed: true);
        if (text.startsWith('kostori_self_check')) {
          if (!received.isCompleted) received.complete(true);
        }
      });
      socket.send(payload, InternetAddress.loopbackIPv4, port);
      return await received.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    } finally {
      probe?.close();
    }
  }

  String? _tryBroadcastSend() {
    try {
      final bytes = utf8.encode('kostori_self_check');
      for (final addr in _broadcastAddresses) {
        _socket!.send(bytes, addr, kLanDiscoveryPort);
      }
      _socket!.send(bytes, _multicastGroupAddress, kLanDiscoveryPort);
      return null;
    } catch (e) {
      return '$e';
    }
  }

  String _getLocalIp() {
    if (_cachedLocalIp != null) return _cachedLocalIp!;
    return InternetAddress.loopbackIPv4.address;
  }

  Future<void> _refreshLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      String? fallback;
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.isLoopback || addr.type != InternetAddressType.IPv4) {
            continue;
          }
          if (_isLanIp(addr.address)) {
            _cachedLocalIp = addr.address;
            return;
          }
          fallback ??= addr.address;
        }
      }

      _cachedLocalIp = fallback ?? InternetAddress.loopbackIPv4.address;
    } catch (e) {
      _cachedLocalIp = InternetAddress.loopbackIPv4.address;
    }
  }

  void _setState(LanDiscoveryServiceState newState) {
    if (_state != newState) {
      _state = newState;
      _notifyStateChanged();
    }
  }

  void dispose() {
    stopDiscovery();
    _onDeviceDiscovered.clear();
    _onDeviceLeft.clear();
    _onStateChanged.clear();
    _onPairingRequest.clear();
    _onPairingResponse.clear();
  }
}
