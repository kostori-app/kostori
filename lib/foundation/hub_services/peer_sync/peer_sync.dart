part of 'package:kostori/foundation/hub_services/services.dart';

/// 一起看房间的播放同步消息前缀（聊天气泡渲染时据此过滤）。
/// 定义在 services 库内，供服务端（用于直连成员跳过广播）与客户端共享。
const String hubSyncPrefix = 'KOSTORI_SYNC:';

/// 是否一条播放进度同步消息
bool isHubSyncText(String text) => text.startsWith(hubSyncPrefix);

/// 收集本机候选地址（非回环 IPv4）。
/// 用于一起看 P2P：房主把自己的直连地址告诉服务器，成员优先直连房主。
Future<List<String>> collectLanCandidates(
  int port, {
  String wsPath = '',
}) async {
  final result = <String>['ws://127.0.0.1:$port$wsPath'];
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (ip == '127.0.0.1' || result.contains('ws://$ip:$port$wsPath')) {
          continue;
        }
        result.add('ws://$ip:$port$wsPath');
      }
    }
  } catch (e) {
    HubLog.warning('PeerServer', '获取本机 IP 失败：$e');
  }
  return result;
}

/// 房主侧的直连服务器：成员直连此 WS 获取播放同步，减少服务器带宽与延迟。
/// 连接失败时成员自动回退到服务器的广播通道。
class HubPeerServer {
  HttpServer? _server;
  final Set<WebSocket> _peers = {};
  int? _port;
  bool _disposed = false;

  int get port => _port ?? 0;

  bool get isRunning => _server != null;

  /// 收集候选地址（供上报给服务器，让成员直连）
  Future<List<String>> candidates({String wsPath = '/peersync'}) =>
      collectLanCandidates(port, wsPath: wsPath);

  /// 在 [preferredPort] 附近找可用端口启动 WS 服务器。
  /// 路径统一为 /peersync。
  Future<void> start({int preferredPort = 9300}) async {
    if (isRunning || _disposed) return;
    int port = preferredPort;
    HttpServer? server;
    for (int attempt = 0; attempt < 10; attempt++) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, port);
        break;
      } catch (_) {
        port++;
      }
    }
    if (server == null) {
      throw Exception('无法启动直连服务器（端口 $preferredPort-$port 均被占用）');
    }
    _server = server;
    _port = port;
    _server!.listen(_handleRequest);
    HubLog.info('HubPeerServer', '✅ 直连服务器已启动：ws://0.0.0.0:$port/peersync');
  }

  void _handleRequest(HttpRequest request) {
    if (request.uri.path != '/peersync') {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
      return;
    }
    WebSocketTransformer.upgrade(request)
        .then((socket) {
          _peers.add(socket);
          HubLog.info('HubPeerServer', '🔗 直连成员接入，当前 ${_peers.length} 个');
          socket.listen(
            (_) {},
            onDone: () {
              _peers.remove(socket);
              HubLog.info('HubPeerServer', '🔌 直连成员断开，当前 ${_peers.length} 个');
            },
            onError: (_) {
              _peers.remove(socket);
            },
          );
        })
        .catchError((e) {
          HubLog.warning('HubPeerServer', '升级 WebSocket 失败：$e');
        });
  }

  /// 向所有直连成员广播一帧同步文本
  void broadcastSync(String frame) {
    for (final ws in _peers.toList()) {
      try {
        ws.add(frame);
      } catch (_) {
        _peers.remove(ws);
      }
    }
  }

  Future<void> stop() async {
    _disposed = false; // 允许再次 start()
    for (final ws in _peers.toList()) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _peers.clear();
    await _server?.close(force: true);
    _server = null;
    _port = null;
    HubLog.info('HubPeerServer', '🛑 直连服务器已停止');
  }
}

/// 成员侧的直连客户端：尝试直连房主，成功则返回同步帧流，失败返回 null。
class HubPeerClient {
  WebSocket? _socket;
  final _frames = StreamController<String>.broadcast();
  bool _closed = false;

  Stream<String> get frames => _frames.stream;

  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  /// 依次尝试每个候选地址，首个连通即返回；全部失败返回 null。
  static Future<HubPeerClient?> connect(
    List<String> candidates, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    for (final url in candidates) {
      final client = HubPeerClient();
      final ok = await client._tryConnect(url, timeout);
      if (ok) return client;
      client.dispose();
    }
    return null;
  }

  Future<bool> _tryConnect(String url, Duration timeout) async {
    WebSocket? socket;
    try {
      socket = await WebSocket.connect(url).timeout(timeout);
      _socket = socket;
      socket.listen(
        (data) {
          if (data is String && !_closed) {
            _frames.add(data);
          }
        },
        onDone: () => _frames.close(),
        onError: (_) => _frames.close(),
        cancelOnError: true,
      );
      return true;
    } catch (_) {
      // 超时/连接失败：清理可能已建立的 socket，避免泄漏
      try {
        await socket?.close();
      } catch (_) {}
      _socket = null;
      return false;
    }
  }

  void dispose() {
    _closed = true;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    _frames.close();
  }
}
