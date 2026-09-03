part of 'package:kostori/foundation/hub_services/services.dart';

class LanControlClient {
  LanControlClient._();

  static final LanControlClient instance = LanControlClient._();

  WebSocket? _socket;
  String? _serverUrl;
  LanControlServiceState _state = LanControlServiceState.idle;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isConnecting = false;

  LanDiscoveredDevice? _connectedDevice;
  final _pendingRequests = <String, Completer<Map<String, dynamic>>>{};
  final _onStateChangedListeners =
      <void Function(LanControlServiceState, String?)>[];
  final _onStatusSyncListeners = <void Function(LanStatusSyncMessage)>[];
  final _onErrorListeners = <void Function(String)>[];
  Completer<bool>? _helloCompleter;
  String? _lastError;

  LanControlServiceState get state => _state;
  bool get isConnected => _state == LanControlServiceState.connected;
  LanDiscoveredDevice? get connectedDevice => _connectedDevice;
  String? get lastError => _lastError;

  /// 连接设备。返回 true 表示已连接（如需 PIN 码则已通过验证）。
  Future<bool> connect(LanDiscoveredDevice device) async {
    if (_isConnecting || isConnected) return false;
    _isConnecting = true;
    _lastError = null;
    _serverUrl = 'ws://${device.ip}:${device.port}';
    _connectedDevice = device;

    try {
      _socket = await WebSocket.connect(_serverUrl!).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('连接超时'),
      );
      _socket!.pingInterval = const Duration(seconds: 30);
      _reconnectAttempts = 0;
      _helloCompleter = Completer<bool>();
      _socket!.listen(
        _handleMessage,
        onError: (error) => _handleError('连接错误: $error'),
        onDone: _handleDisconnect,
      );

      final requiresPin = await _helloCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (!requiresPin) {
        _setState(LanControlServiceState.connected);
        HubLog.info('LanControlClient', '已连接到: $_serverUrl (${device.name})');
        return true;
      }

      // 服务端要求 PIN 码验证，弹出输入框
      _setState(LanControlServiceState.pinRequired);
      HubLog.info('LanControlClient', '服务端要求 PIN 码验证: $_serverUrl');
      final pin = await _promptForPin();
      if (pin == null) {
        disconnect();
        return false;
      }
      final ok = await submitPin(pin);
      if (!ok) {
        disconnect();
        return false;
      }
      HubLog.info('LanControlClient', 'PIN 验证通过，已连接到: $device');
      return true;
    } catch (e) {
      _connectedDevice = null;
      _lastError = '连接失败: $e';
      _setState(LanControlServiceState.error, _lastError);
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  /// 提交 PIN 码进行验证。成功返回 true。
  Future<bool> submitPin(String pin) async {
    final message = LanControlMessage(
      type: LanControlMessageType.pinVerify,
      requestId: LanControlMessage.generateRequestId(),
      data: {'pin': pin.trim()},
    );
    try {
      final result = await _sendAndWait(message);
      final success = result?['data']?['success'] == true;
      if (success) {
        _lastError = null;
        _setState(LanControlServiceState.connected);
      } else {
        _lastError = result?['data']?['error'] as String? ?? 'PIN 码错误';
        _setState(LanControlServiceState.error, _lastError);
      }
      return success;
    } catch (e) {
      _lastError = 'PIN 验证失败: $e';
      _setState(LanControlServiceState.error, _lastError);
      return false;
    }
  }

  Future<String?> _promptForPin() {
    return showDialog<String>(
      context: App.rootContext,
      barrierDismissible: false,
      builder: (_) => _PinInputDialog(deviceName: _connectedDevice?.name ?? ''),
    );
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _serverUrl = null;
    _connectedDevice = null;

    for (final c in _pendingRequests.values) {
      if (!c.isCompleted) c.completeError(Exception('连接已断开'));
    }
    _pendingRequests.clear();

    if (_socket != null && _socket!.readyState == WebSocket.open) {
      final msg = LanControlMessage(
        type: LanControlMessageType.disconnect,
        requestId: LanControlMessage.generateRequestId(),
      );
      _socket!.add(msg.toJson());
    }

    _socket?.close();
    _socket = null;
    _setState(LanControlServiceState.idle);
    HubLog.info('LanControlClient', '已断开连接');
  }

  Future<Map<String, dynamic>?> sendPlayerControl(
    PlayerControlAction action, [
    dynamic value,
  ]) {
    final message = LanPlayerControlMessage(
      requestId: LanControlMessage.generateRequestId(),
      action: action,
      value: value,
    );
    return _sendAndWait(message);
  }

  Future<Map<String, dynamic>?> sendSeek(double positionSeconds) {
    final message = LanPlayerControlMessage(
      requestId: LanControlMessage.generateRequestId(),
      action: PlayerControlAction.seek,
      value: positionSeconds,
    );
    return _sendAndWait(message);
  }

  Future<Map<String, dynamic>?> sendEpisodeSelect({
    required int animeId,
    required String source,
    required int episode,
    String? episodeId,
    bool autoPlay = true,
  }) {
    final message = LanEpisodeSelectMessage(
      requestId: LanControlMessage.generateRequestId(),
      animeId: animeId,
      source: source,
      episode: episode,
      episodeId: episodeId,
      autoPlay: autoPlay,
    );
    return _sendAndWait(message);
  }

  Future<void> sendNavigate(
    NavigateTarget target, [
    Map<String, dynamic>? params,
  ]) {
    final message = LanNavigateMessage(
      requestId: LanControlMessage.generateRequestId(),
      target: target,
      params: params,
    );
    return _send(message);
  }

  Future<Map<String, dynamic>?> sendAnimeAction(
    String animeId,
    String source,
    AnimeActionType action,
  ) {
    final message = LanAnimeActionMessage(
      requestId: LanControlMessage.generateRequestId(),
      animeId: animeId,
      source: source,
      action: action,
    );
    return _sendAndWait(message);
  }

  Future<LanStatusSyncMessage?> requestStatusSync() async {
    final message = LanControlMessage(
      type: LanControlMessageType.syncStatus,
      requestId: LanControlMessage.generateRequestId(),
    );

    final result = await _sendAndWait(message);
    if (result != null && result['data'] != null) {
      return LanStatusSyncMessage.fromJson(result);
    }
    return null;
  }

  void addStateChangedListener(
    void Function(LanControlServiceState, String?) listener,
  ) => _onStateChangedListeners.add(listener);

  void removeStateChangedListener(
    void Function(LanControlServiceState, String?) listener,
  ) => _onStateChangedListeners.remove(listener);

  void addStatusSyncListener(void Function(LanStatusSyncMessage) listener) =>
      _onStatusSyncListeners.add(listener);

  void removeStatusSyncListener(void Function(LanStatusSyncMessage) listener) =>
      _onStatusSyncListeners.remove(listener);

  void addErrorListener(void Function(String) listener) =>
      _onErrorListeners.add(listener);

  void removeErrorListener(void Function(String) listener) =>
      _onErrorListeners.remove(listener);

  Future<void> _send(LanControlMessage message) async {
    if (_socket == null || _socket!.readyState != WebSocket.open) {
      throw StateError('未连接到服务器，无法发送消息');
    }
    _socket!.add(jsonEncode(message.toJson()));
  }

  Future<Map<String, dynamic>?> _sendAndWait(LanControlMessage message) async {
    await _send(message);

    final requestId = message.requestId;
    if (requestId.isEmpty) return null;

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    try {
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _pendingRequests.remove(requestId);
          HubLog.warning('LanControlClient', '请求超时: $requestId');
          return {};
        },
      );
    } catch (e) {
      _pendingRequests.remove(requestId);
      rethrow;
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = LanControlMessage.fromJson(json);

      HubLog.info('LanControlClient', '收到消息: ${message.type.name}');

      switch (message.type) {
        case LanControlMessageType.hello:
          final requiresPin = message.data?['requiresPin'] as bool? ?? false;
          if (_helloCompleter != null && !_helloCompleter!.isCompleted) {
            _helloCompleter!.complete(requiresPin);
          }

        case LanControlMessageType.controlResponse:
          final requestId = json['requestId'] as String?;
          if (requestId != null) {
            final completer = _pendingRequests.remove(requestId);
            if (completer != null && !completer.isCompleted) {
              completer.complete(json);
            }
          }

        case LanControlMessageType.statusSync:
          if (message is LanStatusSyncMessage) {
            for (final listener in _onStatusSyncListeners) {
              listener(message);
            }
          }

        case LanControlMessageType.ping:
          _send(
            LanControlMessage(
              type: LanControlMessageType.pong,
              requestId: message.requestId,
            ),
          ).ignore();

        case LanControlMessageType.pong:
          break;

        case LanControlMessageType.disconnect:
          // 被控制端主动断开，清空 serverUrl 阻止自动重连
          HubLog.info('LanControlClient', '收到服务端断开指令，不再自动重连');
          _reconnectTimer?.cancel();
          _serverUrl = null;
          _connectedDevice = null;
          _socket?.close();
          _socket = null;
          _setState(LanControlServiceState.idle);
          return;

        case LanControlMessageType.error:
          final error = message.data?['error'] as String? ?? '未知错误';
          for (final listener in _onErrorListeners) {
            listener(error);
          }

        default:
          break;
      }
    } catch (e, stack) {
      HubLog.warning('LanControlClient', '消息解析失败: $e\n$stack');
    }
  }

  void _handleError(String error) {
    _setState(LanControlServiceState.error, error);
    for (final listener in _onErrorListeners) {
      listener(error);
    }
  }

  void _handleDisconnect() {
    _socket = null;

    for (final c in _pendingRequests.values) {
      if (!c.isCompleted) c.completeError(Exception('连接断开'));
    }
    _pendingRequests.clear();

    _setState(LanControlServiceState.idle);

    if (_serverUrl != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_state == LanControlServiceState.pinRequired) return;
    _reconnectTimer?.cancel();
    final attempts = _reconnectAttempts++;
    final delaySeconds = min(5 * (1 << min(attempts, 4)), 60);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      final device = _connectedDevice;
      if (_serverUrl != null && !isConnected && device != null) {
        HubLog.info(
          'LanControlClient',
          '尝试重新连接 (第 $attempts 次): ${device.name}',
        );
        connect(device).ignore();
      }
    });
  }

  void _setState(LanControlServiceState newState, [String? error]) {
    if (_state == newState) return;
    _state = newState;
    for (final listener in _onStateChangedListeners) {
      listener(_state, error);
    }
  }

  void dispose() {
    disconnect();
    _onStateChangedListeners.clear();
    _onStatusSyncListeners.clear();
    _onErrorListeners.clear();
  }
}

class _PinInputDialog extends StatefulWidget {
  final String deviceName;

  const _PinInputDialog({required this.deviceName});

  @override
  State<_PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<_PinInputDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _controller.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = '请输入 4-6 位数字 PIN 码');
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(t.inputPinTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.connectToDevice(device: widget.deviceName),
            style: ts.s14.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: t.inputPinHint,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(t.confirm)),
      ],
    );
  }
}
