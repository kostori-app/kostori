part of 'package:kostori/foundation/hub_services/services.dart';

enum LanControlServiceState { idle, listening, connected, error, pinRequired }

const int _kMaxPinAttempts = 3;

typedef LanControlCallback = void Function(LanControlMessage message);

class LanControlService {
  LanControlService._();

  static final LanControlService instance = LanControlService._();

  HttpServer? _server;
  final Map<String, WebSocket> _connections = {};
  LanControlServiceState _state = LanControlServiceState.idle;
  String? _lastError;
  Timer? _statusBroadcastTimer;
  String? _lastAnimeSignature;
  int _port = 42183;
  final _commandQueues = <String, Future<void>>{};

  bool _pinEnabled = false;
  String _pinCode = '';
  final _pendingPinConnections = <String, WebSocket>{};
  final _pinAttempts = <String, int>{};
  final _pinTimeouts = <String, Timer>{};

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

  bool get pinEnabled => _pinEnabled;

  void setPinRequirement({required bool enabled, required String pin}) {
    _pinEnabled = enabled;
    _pinCode = pin.trim();
    HubLog.info(
      'LanControlService',
      '连接 PIN 码验证已${enabled ? '开启' : '关闭'}${enabled ? '（${_pinCode.length} 位）' : ''}',
    );
  }

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

    if (_server != null) {
      await stop();
    }

    _port = port;

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _setState(LanControlServiceState.listening);

      _server!.listen(
        _handleHttpRequest,
        onError: (error) {
          _lastError = '服务器错误: $error';
          _setState(LanControlServiceState.error);
        },
      );

      HubLog.info('LanControlService', 'WebSocket 服务已启动，端口: $port');
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 10048) {
        HubLog.error(
          'LanControlService',
          '端口 $port 被占用 (TIME_WAIT)，正在尝试随机端口...',
        );
        try {
          _server = await HttpServer.bind(
            InternetAddress.anyIPv4,
            0,
            shared: true,
          );
          _port = _server!.port;
          _setState(LanControlServiceState.listening);

          _server!.listen(_handleHttpRequest);
          HubLog.info('LanControlService', 'WebSocket 服务已在动态端口启动，端口: $_port');
          return;
        } catch (innerEx) {
          _lastError = '动态端口绑定失败: $innerEx';
        }
      } else {
        _lastError = '网络绑定失败: ${e.message}';
      }
      _setState(LanControlServiceState.error);
      rethrow;
    } catch (e) {
      _lastError = '启动失败: $e';
      _setState(LanControlServiceState.error);
      rethrow;
    }
  }

  Future<void> stop() async {
    _statusBroadcastTimer?.cancel();
    _statusBroadcastTimer = null;

    for (final t in _pinTimeouts.values) {
      t.cancel();
    }
    _pinTimeouts.clear();
    _pinAttempts.clear();

    final connections = List<WebSocket>.of(_connections.values);
    _connections.clear();
    for (final ws in connections) {
      try {
        await ws.close();
      } catch (_) {
        // 忽略已断开的连接
      }
    }

    final pendingPin = List<WebSocket>.of(_pendingPinConnections.values);
    _pendingPinConnections.clear();
    for (final ws in pendingPin) {
      try {
        await ws.close();
      } catch (_) {
        // 忽略未验证的连接
      }
    }

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

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
    ws.pingInterval = const Duration(seconds: 30);
    _lastAnimeSignature = null;

    final deviceId = _generateDeviceId();
    final requiresPin = _pinEnabled && _pinCode.isNotEmpty;

    _sendToSocket(ws, _buildHelloMessage(requiresPin));

    if (requiresPin) {
      _pendingPinConnections[deviceId] = ws;
      _pinTimeouts[deviceId] = Timer(const Duration(seconds: 30), () {
        if (_pendingPinConnections.remove(deviceId) != null) {
          _pinAttempts.remove(deviceId);
          _pinTimeouts.remove(deviceId);
          ws.close();
          HubLog.info('LanControlService', 'PIN 验证超时，已关闭连接: $deviceId');
        }
      });
    } else {
      _registerConnection(deviceId, ws);
    }

    ws.listen(
      (data) => _pendingPinConnections.containsKey(deviceId)
          ? _handlePendingPinMessage(deviceId, ws, data)
          : _handleMessage(deviceId, data),
      onError: (error) => _handleError(deviceId, error),
      onDone: () => _handleDisconnect(deviceId),
    );
  }

  void _registerConnection(String deviceId, WebSocket ws) {
    for (final existingWs in _connections.values) {
      existingWs.close();
    }
    _connections.clear();

    // Stop any existing status broadcast timer
    _statusBroadcastTimer?.cancel();

    _connections[deviceId] = ws;

    if (_state == LanControlServiceState.listening) {
      _setState(LanControlServiceState.connected);
    }

    HubLog.info('LanControlService', '客户端连接: $deviceId');
    _notifyConnect(deviceId);

    // Start periodic status broadcast (every 1 second)
    _startStatusBroadcast();
  }

  LanControlMessage _buildHelloMessage(bool requiresPin) => LanControlMessage(
    type: LanControlMessageType.hello,
    requestId: LanControlMessage.generateRequestId(),
    data: {
      'requiresPin': requiresPin,
      if (requiresPin) 'pinLength': _pinCode.length,
    },
  );

  void _sendToSocket(WebSocket ws, LanControlMessage message) {
    try {
      ws.add(jsonEncode(message.toJson()));
    } catch (e) {
      HubLog.warning('LanControlService', '发送消息失败: $e');
    }
  }

  void _handlePendingPinMessage(String deviceId, WebSocket ws, dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = LanControlMessage.fromJson(json);

      if (message.type != LanControlMessageType.pinVerify) {
        _sendToSocket(
          ws,
          LanControlMessage(
            type: LanControlMessageType.error,
            requestId: message.requestId,
            data: {'error': '连接需要 PIN 码验证'},
          ),
        );
        return;
      }

      final submitted = (message.data?['pin'] as String?)?.trim() ?? '';
      if (submitted == _pinCode) {
        _pinTimeouts[deviceId]?.cancel();
        _pinTimeouts.remove(deviceId);
        _pinAttempts.remove(deviceId);
        _pendingPinConnections.remove(deviceId);
        _registerConnection(deviceId, ws);
        _sendToSocket(ws, LanControlResponseMessage.success(message.requestId));
        HubLog.info('LanControlService', 'PIN 码验证通过: $deviceId');
        return;
      }

      final attempts = (_pinAttempts[deviceId] ?? 0) + 1;
      _pinAttempts[deviceId] = attempts;
      final remaining = _kMaxPinAttempts - attempts;
      _sendToSocket(
        ws,
        LanControlResponseMessage.failure(
          message.requestId,
          remaining > 0 ? 'PIN 码错误，还可尝试 $remaining 次' : 'PIN 码错误次数过多，连接已关闭',
        ),
      );
      if (remaining <= 0) {
        _pinTimeouts[deviceId]?.cancel();
        _pinTimeouts.remove(deviceId);
        _pinAttempts.remove(deviceId);
        _pendingPinConnections.remove(deviceId);
        ws.close();
      }
    } catch (e, stack) {
      HubLog.warning('LanControlService', 'PIN 验证消息解析失败: $e\n$stack');
      _sendToSocket(
        ws,
        LanControlMessage(
          type: LanControlMessageType.error,
          requestId: '',
          data: {'error': '消息格式错误: $e'},
        ),
      );
    }
  }

  void _startStatusBroadcast() {
    _statusBroadcastTimer?.cancel();
    _statusBroadcastTimer = null;
    // Delay broadcast to allow anime data to fully load
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_connections.isNotEmpty) {
        _statusBroadcastTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          _broadcastStatus();
        });
      }
    });
  }

  void _broadcastStatus() {
    if (_connections.isEmpty) {
      _statusBroadcastTimer?.cancel();
      return;
    }

    // Skip broadcast if no anime is playing
    final playerHandler = _playerHandler;
    if (playerHandler == null || playerHandler.getCurrentAnime() == null) {
      return;
    }

    final currentAnime = playerHandler.getCurrentAnime();

    // Skip if anime hasn't loaded episode data yet
    if (currentAnime?.episodes == null || currentAnime!.episodes!.isEmpty) {
      return;
    }

    final playerStatus = playerHandler.getCurrentStatus();
    final syncStatus = _getSyncStatus();

    // 只在 anime 身份信息变化时推送完整数据（含 episodes 大对象），
    // 其余每秒 tick 仅推送轻量的播放状态
    final signature = _animeSignature(currentAnime);
    final animeChanged = signature != _lastAnimeSignature;
    _lastAnimeSignature = signature;

    final statusSync = LanStatusSyncMessage(
      playerStatus: playerStatus,
      currentAnime: animeChanged ? currentAnime : null,
      syncStatus: syncStatus,
    );

    // Broadcast to all connected clients
    broadcast(statusSync);
  }

  String _animeSignature(CurrentAnime anime) =>
      '${anime.animeId}|${anime.source}|${anime.title}|${anime.currentEpisode}';

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

      _enqueueCommand(deviceId, message);
    } catch (e, stack) {
      HubLog.warning('LanControlService', '消息解析失败: $e\n$stack');
      _sendError(deviceId, '消息格式错误: $e');
    }
  }

  void _enqueueCommand(String deviceId, LanControlMessage message) {
    final previous = _commandQueues[deviceId] ?? Future<void>.value();
    final tail = previous.then((_) => _processCommand(deviceId, message));
    _commandQueues[deviceId] = tail.catchError((Object e) {
      HubLog.warning('LanControlService', '处理命令失败 [$deviceId]: $e');
    });
  }

  void _handleError(String deviceId, Object error) {
    HubLog.warning('LanControlService', 'WebSocket 错误 [$deviceId]: $error');
    final ws = _connections[deviceId];
    if (ws != null) {
      _connections.remove(deviceId);
      _commandQueues.remove(deviceId);
      ws.close();
      _cleanupDisconnect(deviceId);
    } else if (_pendingPinConnections.remove(deviceId) != null) {
      _pinTimeouts[deviceId]?.cancel();
      _pinTimeouts.remove(deviceId);
      _pinAttempts.remove(deviceId);
    }
  }

  void _handleDisconnect(String deviceId) {
    if (_connections.remove(deviceId) == null) {
      if (_pendingPinConnections.remove(deviceId) != null) {
        _pinTimeouts[deviceId]?.cancel();
        _pinTimeouts.remove(deviceId);
        _pinAttempts.remove(deviceId);
        HubLog.info('LanControlService', '未通过验证的连接断开: $deviceId');
      }
      return;
    }
    _commandQueues.remove(deviceId);
    _cleanupDisconnect(deviceId);
  }

  void _cleanupDisconnect(String deviceId) {
    HubLog.info('LanControlService', '客户端断开: $deviceId');
    _notifyDisconnect(deviceId);

    // Stop status broadcast when no clients connected
    if (_connections.isEmpty) {
      _statusBroadcastTimer?.cancel();
      _statusBroadcastTimer = null;
      _lastAnimeSignature = null;
    }

    if (_connections.isEmpty && _state == LanControlServiceState.connected) {
      _setState(LanControlServiceState.listening);
    }
  }

  Future<void> _processCommand(
    String deviceId,
    LanControlMessage message,
  ) async {
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

        case LanControlMessageType.pong:
        case LanControlMessageType.controlResponse:
        case LanControlMessageType.statusSync:
        case LanControlMessageType.hello:
        case LanControlMessageType.pinVerify:
          // 服务端不应收到这些类型，直接忽略
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
