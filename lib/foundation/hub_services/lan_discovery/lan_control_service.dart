part of 'package:kostori/foundation/hub_services/services.dart';

enum LanControlServiceState { idle, listening, connected, error }

typedef LanControlCallback = void Function(LanControlMessage message);

class LanControlService {
  LanControlService._();
  static final LanControlService instance = LanControlService._();

  HttpServer? _server;
  final Map<String, WebSocket> _connections = {};
  LanControlServiceState _state = LanControlServiceState.idle;
  String? _lastError;
  Timer? _heartbeatTimer;
  int _port = 42183;

  final _onMessageListeners = <LanControlCallback>[];
  final _onConnectListeners = <void Function(String)>[];
  final _onDisconnectListeners = <void Function(String)>[];
  final _onStateChangedListeners =
      <void Function(LanControlServiceState, String?)>[];

  LanPlayerControlHandler? _playerHandler;
  LanNavigationHandler? _navigationHandler;

  LanControlServiceState get state => _state;
  String? get lastError => _lastError;
  int get port => _port;
  int get connectionCount => _connections.length;
  bool get isListening =>
      _state == LanControlServiceState.listening ||
      _state == LanControlServiceState.connected;
  Set<String> get connectedDeviceIds => _connections.keys.toSet();

  void setPlayerHandler(LanPlayerControlHandler handler) {
    _playerHandler = handler;
  }

  void setNavigationHandler(LanNavigationHandler handler) {
    _navigationHandler = handler;
  }

  void addMessageListener(LanControlCallback listener) {
    _onMessageListeners.add(listener);
  }

  void removeMessageListener(LanControlCallback listener) {
    _onMessageListeners.remove(listener);
  }

  void addConnectListener(void Function(String) listener) {
    _onConnectListeners.add(listener);
  }

  void removeConnectListener(void Function(String) listener) {
    _onConnectListeners.remove(listener);
  }

  void addDisconnectListener(void Function(String) listener) {
    _onDisconnectListeners.add(listener);
  }

  void removeDisconnectListener(void Function(String) listener) {
    _onDisconnectListeners.remove(listener);
  }

  void addStateChangedListener(
    void Function(LanControlServiceState, String?) listener,
  ) {
    _onStateChangedListeners.add(listener);
  }

  void removeStateChangedListener(
    void Function(LanControlServiceState, String?) listener,
  ) {
    _onStateChangedListeners.remove(listener);
  }

  Future<void> start(int port) async {
    if (_state == LanControlServiceState.listening ||
        _state == LanControlServiceState.connected) {
      return;
    }

    _port = port;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _setState(LanControlServiceState.listening);

      _server!.listen(
        _handleHttpRequest,
        onError: (error) {
          _lastError = '服务器错误: $error';
          _setState(LanControlServiceState.error);
        },
      );

      _startHeartbeat();

      HubLog.info('LanControlService', 'WebSocket 服务已启动，端口: $port');
    } catch (e) {
      _lastError = '启动失败: $e';
      _setState(LanControlServiceState.error);
      rethrow;
    }
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    for (final ws in _connections.values) {
      ws.close();
    }
    _connections.clear();

    _server?.close();
    _server = null;

    _setState(LanControlServiceState.idle);
    HubLog.info('LanControlService', 'WebSocket 服务已停止');
  }

  Future<void> broadcast(LanControlMessage message) async {
    final json = jsonEncode(message.toJson());
    for (final ws in _connections.values) {
      try {
        ws.add(json);
      } catch (e) {
        HubLog.warning('LanControlService', '发送消息失败: $e');
      }
    }
  }

  Future<void> sendTo(String deviceId, LanControlMessage message) async {
    final ws = _connections[deviceId];
    if (ws != null) {
      try {
        ws.add(jsonEncode(message.toJson()));
      } catch (e) {
        HubLog.warning('LanControlService', '发送消息失败: $e');
      }
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final ws = await WebSocketTransformer.upgrade(request);
        _handleWebSocket(ws, request);
      } catch (e) {
        HubLog.warning('LanControlService', 'WebSocket 升级失败: $e');
      }
    } else {
      request.response.statusCode = 404;
      request.response.close();
    }
  }

  void _handleWebSocket(WebSocket ws, HttpRequest request) {
    for (final existingWs in _connections.values) {
      existingWs.close();
    }
    _connections.clear();

    final deviceId = _generateDeviceId();
    _connections[deviceId] = ws;

    if (_state == LanControlServiceState.listening) {
      _setState(LanControlServiceState.connected);
    }

    HubLog.info('LanControlService', '客户端连接: $deviceId');
    _notifyConnect(deviceId);

    ws.listen(
      (data) => _handleMessage(deviceId, data),
      onError: (error) => _handleError(deviceId, error),
      onDone: () => _handleDisconnect(deviceId),
    );
  }

  void _handleMessage(String deviceId, dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = LanControlMessage.fromJson(json);

      HubLog.info(
        'LanControlService',
        '收到消息: ${message.type.name} from $deviceId',
      );

      for (final listener in _onMessageListeners) {
        try {
          listener(message);
        } catch (e) {
          HubLog.warning('LanControlService', '消息处理回调错误: $e');
        }
      }

      _processCommand(deviceId, message);
    } catch (e, stack) {
      HubLog.warning('LanControlService', '消息解析失败: $e\n$stack');
      _sendError(deviceId, '消息格式错误: $e');
    }
  }

  void _handleError(String deviceId, Object error) {
    HubLog.warning('LanControlService', 'WebSocket 错误 [$deviceId]: $error');
  }

  void _handleDisconnect(String deviceId) {
    _connections.remove(deviceId);
    HubLog.info('LanControlService', '客户端断开: $deviceId');
    _notifyDisconnect(deviceId);

    if (_connections.isEmpty && _state == LanControlServiceState.connected) {
      _setState(LanControlServiceState.listening);
    }
  }

  void _processCommand(String deviceId, LanControlMessage message) async {
    LanControlResponseMessage? response;

    try {
      switch (message.type) {
        case LanControlMessageType.playerControl:
          response = await _handlePlayerControl(
            message as LanPlayerControlMessage,
          );
          break;

        case LanControlMessageType.episodeSelect:
          response = await _handleEpisodeSelect(
            message as LanEpisodeSelectMessage,
          );
          break;

        case LanControlMessageType.navigate:
          response = await _handleNavigate(message as LanNavigateMessage);
          break;

        case LanControlMessageType.animeAction:
          response = await _handleAnimeAction(message as LanAnimeActionMessage);
          break;

        case LanControlMessageType.syncStatus:
          response = _handleSyncStatusRequest(message);
          break;

        case LanControlMessageType.ping:
          response = LanControlResponseMessage.success(
            message.requestId,
            result: {'pong': true},
          );
          break;

        case LanControlMessageType.disconnect:
          HubLog.info('LanControlService', '收到 disconnect 消息，执行 pop');
          App.pop();
          _connections[deviceId]?.close();
          return;

        default:
          response = LanControlResponseMessage.failure(
            message.requestId,
            '未知命令类型: ${message.type.name}',
          );
      }
    } catch (e) {
      HubLog.warning('LanControlService', '处理命令失败: $e');
      response = LanControlResponseMessage.failure(
        message.requestId,
        '处理失败: $e',
      );
    }

    await sendTo(deviceId, response);
  }

  Future<LanControlResponseMessage> _handleAnimeAction(
    LanAnimeActionMessage message,
  ) async {
    HubLog.info(
      'LanControlService',
      '处理 anime_action: ${message.action.name}, animeId=${message.animeId}, source=${message.source}',
    );
    try {
      if (_navigationHandler == null) {
        HubLog.warning('LanControlService', '_navigationHandler 为 null，忽略导航请求');
      }
      switch (message.action) {
        case AnimeActionType.play:
          if (_navigationHandler != null) {
            final params = {
              'id': message.animeId,
              'source': message.source,
              'autoPlay': true,
            };
            HubLog.info('LanControlService', 'play params: $params');
            await _navigationHandler!(NavigateTarget.animeDetail, params);
          }
          return LanControlResponseMessage.success(
            message.requestId,
            result: {'action': 'play', 'animeId': message.animeId},
          );

        case AnimeActionType.openDetail:
          if (_navigationHandler != null) {
            final params = {'id': message.animeId, 'source': message.source};
            HubLog.info('LanControlService', 'openDetail params: $params');
            await _navigationHandler!(NavigateTarget.animeDetail, params);
          }
          return LanControlResponseMessage.success(
            message.requestId,
            result: {'action': 'open_detail', 'animeId': message.animeId},
          );

        case AnimeActionType.syncProgress:
          final playerStatus = _playerHandler?.getCurrentStatus();
          final currentAnime = _playerHandler?.getCurrentAnime();
          return LanControlResponseMessage.success(
            message.requestId,
            result: {
              'action': 'sync_progress',
              'playerStatus': playerStatus?.toJson(),
              'currentAnime': currentAnime?.toJson(),
            },
          );
      }
    } catch (e) {
      return LanControlResponseMessage.failure(message.requestId, '执行失败: $e');
    }
  }

  Future<LanControlResponseMessage> _handlePlayerControl(
    LanPlayerControlMessage message,
  ) async {
    if (_playerHandler == null) {
      return LanControlResponseMessage.failure(
        message.requestId,
        '播放器控制处理器未设置',
      );
    }

    try {
      final result = await _playerHandler!.handle(
        message.action,
        message.value,
      );
      return LanControlResponseMessage.success(
        message.requestId,
        result: result,
      );
    } catch (e) {
      return LanControlResponseMessage.failure(message.requestId, '执行失败: $e');
    }
  }

  Future<LanControlResponseMessage> _handleEpisodeSelect(
    LanEpisodeSelectMessage message,
  ) async {
    if (_playerHandler == null) {
      return LanControlResponseMessage.failure(
        message.requestId,
        '播放器控制处理器未设置',
      );
    }

    try {
      final result = await _playerHandler!.selectEpisode(
        message.animeId,
        message.source,
        message.episode,
        message.episodeId,
        message.autoPlay,
      );
      return LanControlResponseMessage.success(
        message.requestId,
        result: result,
      );
    } catch (e) {
      return LanControlResponseMessage.failure(message.requestId, '选集失败: $e');
    }
  }

  Future<LanControlResponseMessage> _handleNavigate(
    LanNavigateMessage message,
  ) async {
    if (_navigationHandler == null) {
      return LanControlResponseMessage.failure(message.requestId, '导航处理器未设置');
    }

    try {
      await _navigationHandler!(message.target, message.params);
      return LanControlResponseMessage.success(message.requestId);
    } catch (e) {
      return LanControlResponseMessage.failure(message.requestId, '导航失败: $e');
    }
  }

  LanControlResponseMessage _handleSyncStatusRequest(
    LanControlMessage message,
  ) {
    final playerStatus = _playerHandler?.getCurrentStatus();
    final currentAnime = _playerHandler?.getCurrentAnime();
    final syncStatus = _getSyncStatus();

    final statusSync = LanStatusSyncMessage(
      playerStatus: playerStatus,
      currentAnime: currentAnime,
      syncStatus: syncStatus,
    );

    return LanControlResponseMessage.success(
      message.requestId,
      result: statusSync.toJson(),
    );
  }

  SyncStatus _getSyncStatus() {
    return SyncStatus(isSyncing: false, lastSyncTime: null, pendingChanges: 0);
  }

  void _sendError(String deviceId, String error) {
    sendTo(
      deviceId,
      LanControlMessage(
        type: LanControlMessageType.error,
        requestId: '',
        data: {'error': error},
      ),
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      broadcast(
        LanControlMessage(type: LanControlMessageType.ping, requestId: ''),
      );
    });
  }

  void _setState(LanControlServiceState newState) {
    if (_state != newState) {
      _state = newState;
      for (final listener in _onStateChangedListeners) {
        listener(_state, _lastError);
      }
    }
  }

  void _notifyConnect(String deviceId) {
    for (final listener in _onConnectListeners) {
      listener(deviceId);
    }
  }

  void _notifyDisconnect(String deviceId) {
    for (final listener in _onDisconnectListeners) {
      listener(deviceId);
    }
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void dispose() {
    stop();
    _onMessageListeners.clear();
    _onConnectListeners.clear();
    _onDisconnectListeners.clear();
    _onStateChangedListeners.clear();
  }
}

abstract class LanPlayerControlHandler {
  Future<Map<String, dynamic>?> handle(
    PlayerControlAction action,
    dynamic value,
  );

  Future<Map<String, dynamic>?> selectEpisode(
    int animeId,
    String source,
    int episode,
    String? episodeId,
    bool autoPlay,
  );

  PlayerStatus? getCurrentStatus();
  CurrentAnime? getCurrentAnime();
}

typedef LanNavigationHandler =
    Future<void> Function(NavigateTarget target, Map<String, dynamic>? params);
