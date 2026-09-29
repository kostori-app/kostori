part of 'package:kostori/foundation/hub_services/services.dart';

/// HTTP/WS 适配层：底层由 shelf + web_socket_channel 承载，
/// 对外保留 `HttpRequest`/`HttpResponse` 风格的少量 API，
/// 让既有路由/中间件/WS 处理逻辑无需改写。

class HubRequest extends Stream<List<int>> {
  HubRequest(this._raw);

  final shelf.Request _raw;
  final HubResponse response = HubResponse();

  /// 路由参数（由路由器解析后注入）
  Map<String, String> params = const {};

  String get method => _raw.method;

  Uri get uri => _raw.requestedUri;

  Uri get requestedUri => _raw.requestedUri;

  List<String> get pathSegments => _raw.requestedUri.pathSegments;

  HubRequestHeaders get headers => HubRequestHeaders(_raw.headers);

  int get contentLength {
    final v = _raw.headers['content-length'];
    return v == null ? -1 : (int.tryParse(v) ?? -1);
  }

  HttpConnectionInfo? get connectionInfo =>
      _raw.context['shelf.io.connection_info'] as HttpConnectionInfo?;

  String get remoteAddress => connectionInfo?.remoteAddress.address ?? '';

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _raw.read().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

class HubRequestHeaders {
  HubRequestHeaders(this._headers);

  final Map<String, String> _headers;

  String? value(String name) => _headers[name.toLowerCase()];

  ContentType? get contentType {
    final v = _headers['content-type'];
    return v == null ? null : ContentType.parse(v);
  }
}

class HubResponseHeaders {
  ContentType? contentType;

  final Map<String, String> _raw = {};

  void set(String name, Object value) =>
      _raw[name.toLowerCase()] = value.toString();
}

class HubResponse {
  int statusCode = HttpStatus.ok;

  final HubResponseHeaders headers = HubResponseHeaders();

  final BytesBuilder _body = BytesBuilder(copy: false);

  void write(Object? obj) => _body.add(utf8.encode(obj?.toString() ?? ''));

  void add(List<int> bytes) => _body.add(bytes);

  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.add(chunk);
    }
  }

  /// handler 内 `await response.close()` 只是语义收尾；
  /// 实际响应在 handler 返回后由 [toResponse] 构建。
  Future<void> close() async {}

  shelf.Response toResponse() {
    final h = <String, String>{...headers._raw};
    final ct = headers.contentType;
    if (ct != null) h['content-type'] = ct.toString();
    return shelf.Response(statusCode, body: _body.takeBytes(), headers: h);
  }
}

/// dart:io `WebSocket` 的最小替身：字段/方法名保持一致
class HubSocket extends Stream<dynamic> {
  HubSocket(this._channel);

  final WebSocketChannel _channel;
  bool _closed = false;

  /// 与 dart:io `WebSocket.open` 对齐，供 `readyState != WebSocket.open` 使用
  static const int open = 1;

  static const int closed = 3;

  Stream get stream => _channel.stream;

  int? get closeCode => _channel.closeCode;

  int get readyState => (_closed || _channel.closeCode != null) ? closed : open;

  void add(dynamic data) {
    if (_closed) return;
    _channel.sink.add(data);
  }

  Future<void> close([int? code, String? reason]) async {
    if (_closed) return;
    _closed = true;
    // package:web_socket 只接受 1000 或 3000-4999 的 close code，
    // dart:io 允许的 1001/1008 等需映射到应用区间，否则会抛异常
    final safeCode =
        (code == null || code == 1000 || (code >= 3000 && code <= 4999))
        ? code
        : code + 3000;
    try {
      await _channel.sink.close(safeCode, reason);
    } catch (_) {}
  }

  Future<void> get done => _channel.sink.done;

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _channel.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  /// 服务端 ping 由 webSocketHandler 统一管理；客户端在 connect 时设置。
  set pingInterval(Duration? _) {}
}
