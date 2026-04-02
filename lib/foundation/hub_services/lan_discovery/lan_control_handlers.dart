part of 'package:kostori/foundation/hub_services/services.dart';

class LanControlClient {
  LanControlClient._();

  static final LanControlClient instance = LanControlClient._();

  WebSocket? _socket;
  String? _serverUrl;
  LanControlServiceState _state = LanControlServiceState.idle;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  LanDiscoveredDevice? _connectedDevice;
  final _pendingRequests = <String, Completer<Map<String, dynamic>>>{};
  final _onStateChangedListeners =
      <void Function(LanControlServiceState, String?)>[];
  final _onStatusSyncListeners = <void Function(LanStatusSyncMessage)>[];
  final _onErrorListeners = <void Function(String)>[];

  LanControlServiceState get state => _state;
  bool get isConnected => _state == LanControlServiceState.connected;
  LanDiscoveredDevice? get connectedDevice => _connectedDevice;

  Future<void> connect(LanDiscoveredDevice device) async {
    _serverUrl = 'ws://${device.ip}:${device.port}';
    _connectedDevice = device;

    try {
      _socket = await WebSocket.connect(_serverUrl!);
      _setState(LanControlServiceState.connected);

      _socket!.listen(
        _handleMessage,
        onError: (error) => _handleError('连接错误: $error'),
        onDone: _handleDisconnect,
      );

      _startPing();
      HubLog.info('LanControlClient', '已连接到: $_serverUrl (${device.name})');
    } catch (e) {
      _connectedDevice = null;
      _setState(LanControlServiceState.error, '连接失败: $e');
      rethrow;
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
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
    _pingTimer?.cancel();

    for (final c in _pendingRequests.values) {
      if (!c.isCompleted) c.completeError(Exception('连接断开'));
    }
    _pendingRequests.clear();

    _setState(LanControlServiceState.idle);

    if (_serverUrl != null) {
      _scheduleReconnect();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      final device = _connectedDevice;
      if (_serverUrl != null && !isConnected && device != null) {
        HubLog.info('LanControlClient', '尝试重新连接: ${device.name}');
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
