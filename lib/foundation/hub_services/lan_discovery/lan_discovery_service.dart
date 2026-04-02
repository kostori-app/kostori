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
  }) async {
    _deviceId = deviceId;
    _deviceName = deviceName;
    _deviceType = deviceType;
    _avatarUrl = avatarUrl;
    _capabilities = capabilities;
    _hubPort = hubPort;
    await _refreshLocalIp();
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
      _setState(LanDiscoveryServiceState.discovering);
      _startBroadcasting();
      _startCleanupTimer();
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
      _hubPort.toString(),
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

  Future<void> handlePairingRequest(LanPairingRequest request) async {
    if (!isPairingTokenValid(request.token)) {
      _notifyPairingResponse(
        LanPairingResponse(
          targetId: _deviceId ?? '',
          accepted: false,
          errorMessage: 'Token 无效或已过期',
        ),
      );
      return;
    }

    _notifyPairingRequest(request);
    _sendPairingResponse(targetId: request.requesterId, accepted: true);
  }

  void _sendPairingResponse({
    required String targetId,
    required bool accepted,
    String? errorMessage,
  }) {
    if (_socket == null) return;

    final response = LanPairingResponse(
      targetId: targetId,
      accepted: accepted,
      wsUrl: accepted ? 'ws://${_getLocalIp()}:$_hubPort/hub' : null,
      errorMessage: errorMessage,
    );

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
    }
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

  void _broadcastRequest() {
    if (_socket == null || _deviceId == null) return;

    final request = LanDiscoveryRequest(
      senderId: _deviceId!,
      senderName: _deviceName ?? 'Unknown',
      deviceType: _deviceType,
      avatarUrl: _avatarUrl,
      capabilities: _capabilities,
    );

    _broadcast(request.toJson());
    HubLog.info('LanDiscovery', '发送广播请求: $_deviceName ($_deviceId)');
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
      } else {
        final broadcastAddr = InternetAddress('255.255.255.255');
        _socket!.send(bytes, broadcastAddr, kLanDiscoveryPort);
        HubLog.info('LanDiscovery', 'UDP 广播已发送');
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

      if (_isOwnMessage(json, senderIp)) return;

      switch (type) {
        case 'discovery_request':
          _handleDiscoveryRequest(json, senderIp);
          break;
        case 'discovery_response':
          _handleDiscoveryResponse(json);
          break;
        case 'pairing_request':
          _handlePairingRequestJson(json);
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

  bool _isOwnMessage(Map<String, dynamic> json, String senderIp) {
    final senderId = json['senderId'] as String?;
    return senderId == _deviceId;
  }

  void _handleDiscoveryRequest(Map<String, dynamic> json, String senderIp) {
    final request = LanDiscoveryRequest.fromJson(json);

    final localIp = _getLocalIp();
    if (senderIp == localIp) {
      HubLog.info('LanDiscovery', '忽略自己的广播');
      return;
    }

    if (_isOwnMessage(json, senderIp)) {
      HubLog.info('LanDiscovery', '忽略自己的消息（senderId匹配）');
      return;
    }

    HubLog.info('LanDiscovery', '收到设备广播: ${request.senderName} ($senderIp)');

    _sendResponseToSender(
      LanDiscoveryResponse(
        senderId: _deviceId ?? '',
        senderName: _deviceName ?? 'Unknown',
        deviceType: _deviceType,
        ip: _getLocalIp(),
        port: _hubPort,
        avatarUrl: _avatarUrl,
        capabilities: _capabilities,
      ),
      senderIp,
    );

    _addOrUpdateDevice(
      LanDiscoveredDevice(
        id: request.senderId,
        name: request.senderName,
        ip: senderIp,
        port: _hubPort,
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

  void _handlePairingRequestJson(Map<String, dynamic> json) {
    try {
      final request = LanPairingRequest.fromJson(json);
      handlePairingRequest(request);
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

  void _sendResponseToSender(LanDiscoveryResponse response, String senderIp) {
    if (_socket == null) return;

    try {
      final jsonStr = jsonEncode(response.toJson());
      final bytes = utf8.encode(jsonStr);
      final addr = InternetAddress(senderIp);
      _socket!.send(bytes, addr, kLanDiscoveryPort);
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

  String _getLocalIp() {
    if (_cachedLocalIp != null) return _cachedLocalIp!;
    return InternetAddress.loopbackIPv4.address;
  }

  Future<void> _refreshLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            _cachedLocalIp = addr.address;
            return;
          }
        }
      }

      _cachedLocalIp = InternetAddress.loopbackIPv4.address;
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
