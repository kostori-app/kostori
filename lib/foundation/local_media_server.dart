import 'dart:async';
import 'dart:io';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:mime/mime.dart';

/// 把本地视频「透出去」给 DLNA 电视投屏。
///
/// DLNA 设备只能拉 HTTP(S) 地址，本地文件路径 / `127.0.0.1` 回环地址电视都
/// 访问不到，所以在局域网临时起一个带 Range 支持的 HTTP 流：
/// - [serveFile]：直接把本地文件按字节范围读出；
/// - [serveLoopback]：把已有的回环流（如 BT 边下边播服务）原样代理出去；
/// - [serveRemote]：远程地址经本机网络（走代理/科学上网）转发，电视本身
///   不需要能访问源站；
/// 空闲 [idleTimeout] 后自动关闭，避免长期暴露端口。
class LocalMediaServer {
  LocalMediaServer._();

  static final LocalMediaServer instance = LocalMediaServer._();

  static const Duration idleTimeout = Duration(minutes: 10);

  HttpServer? _server;
  File? _file;
  String? _upstream;
  String? _remoteUrl;
  Map<String, String>? _remoteHeaders;
  Timer? _idleTimer;

  AppDio? _client;
  AppDio get _dio => _client ??= AppDio.quiet();

  bool get running => _server != null;

  /// 本地文件路径 → 局域网可访问的播放地址
  Future<String> serveFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('file not found: $path');
    }
    await _ensureServer();
    _file = file;
    _upstream = null;
    _remoteUrl = null;
    _remoteHeaders = null;
    _touch();
    final name = file.uri.pathSegments.isEmpty
        ? 'media'
        : file.uri.pathSegments.last;
    return 'http://${await _localIpv4()}:${_server!.port}/file/'
        '${Uri.encodeComponent(name)}';
  }

  /// 回环 HTTP 流（如 BT）→ 局域网可访问的代理地址
  Future<String> serveLoopback(String loopbackUrl) async {
    await _ensureServer();
    _file = null;
    _upstream = loopbackUrl;
    _remoteUrl = null;
    _remoteHeaders = null;
    _touch();
    return 'http://${await _localIpv4()}:${_server!.port}/proxy';
  }

  /// 远程 HTTP(S) 地址 → 局域网转发地址。
  /// 由本机（可走代理/VPN）取流后再喂给电视，解决源站需要科学上网的问题。
  Future<String> serveRemote(String url, {Map<String, String>? headers}) async {
    await _ensureServer();
    _file = null;
    _upstream = null;
    _remoteUrl = url;
    _remoteHeaders = headers;
    _touch();
    return 'http://${await _localIpv4()}:${_server!.port}/remote';
  }

  Future<void> stop() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    final server = _server;
    _server = null;
    _file = null;
    _upstream = null;
    _remoteUrl = null;
    _remoteHeaders = null;
    try {
      await server?.close(force: true);
    } catch (_) {}
  }

  Future<void> _ensureServer() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (_) {});
  }

  void _touch() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, stop);
  }

  Future<void> _handle(HttpRequest req) async {
    _touch();
    final res = req.response;
    try {
      if (_remoteUrl != null) {
        await _proxyRemote(req, _remoteUrl!, _remoteHeaders);
        return;
      }
      final upstream = _upstream;
      if (upstream != null) {
        await _proxy(req, upstream);
        return;
      }
      final file = _file;
      if (file == null || !await file.exists()) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      await _serveFile(req, file);
    } catch (e) {
      Log.error('LocalMediaServer', 'serve failed: $e');
      try {
        res.statusCode = HttpStatus.internalServerError;
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _serveFile(HttpRequest req, File file) async {
    final res = req.response;
    final total = await file.length();
    if (total <= 0) {
      res.statusCode = HttpStatus.serviceUnavailable;
      await res.close();
      return;
    }

    var start = 0;
    var end = total - 1;
    var partial = false;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    if (range != null && range.startsWith('bytes=')) {
      partial = true;
      final spec = range.substring(6).split(',').first.trim();
      final dash = spec.indexOf('-');
      final s = dash > 0 ? int.tryParse(spec.substring(0, dash)) : null;
      final e = dash >= 0 && dash < spec.length - 1
          ? int.tryParse(spec.substring(dash + 1))
          : null;
      if (s == null && e != null) {
        start = (total - e).clamp(0, total - 1);
        end = total - 1;
      } else {
        start = (s ?? 0).clamp(0, total - 1);
        if (e != null) end = e.clamp(start, total - 1);
      }
    }
    if (start > end) {
      res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await res.close();
      return;
    }

    final length = end - start + 1;
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    res.headers.set(
      HttpHeaders.contentTypeHeader,
      lookupMimeType(file.path) ?? 'application/octet-stream',
    );
    if (partial) {
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$total',
      );
    }
    res.headers.set(HttpHeaders.contentLengthHeader, '$length');
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }
    await res.addStream(file.openRead(start, end + 1));
    await res.close();
  }

  /// 把请求原样转发到回环上游，保留 Range / 响应头，实现边下边播的投屏。
  Future<void> _proxy(HttpRequest req, String upstream) async {
    final res = req.response;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final ureq = await client.openUrl(req.method, Uri.parse(upstream));
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        ureq.headers.set(HttpHeaders.rangeHeader, range);
      }
      final ures = await ureq.close();
      res.statusCode = ures.statusCode;
      ures.headers.forEach((name, values) {
        if (name.toLowerCase() == 'transfer-encoding') return;
        if (name.toLowerCase() == 'content-length') return;
        try {
          res.headers.set(name, values);
        } catch (_) {}
      });
      if (req.method == 'HEAD') {
        await res.close();
        return;
      }
      await res.addStream(ures);
      await res.close();
    } finally {
      client.close(force: true);
    }
  }

  /// 远程地址：经本机网络栈（自动走代理/VPN）取流并转发给电视。
  Future<void> _proxyRemote(
    HttpRequest req,
    String url,
    Map<String, String>? headers,
  ) async {
    final res = req.response;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final resp = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: {
          ...?headers,
          if (range != null) HttpHeaders.rangeHeader: range,
        },
        validateStatus: (_) => true,
      ),
    );
    final body = resp.data;
    if (body == null) {
      res.statusCode = HttpStatus.badGateway;
      await res.close();
      return;
    }
    res.statusCode = resp.statusCode ?? HttpStatus.badGateway;
    resp.headers.map.forEach((name, values) {
      final lower = name.toLowerCase();
      if (lower == 'transfer-encoding' || lower == 'content-length') return;
      try {
        res.headers.set(name, values);
      } catch (_) {}
    });
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }
    try {
      await res.addStream(body.stream);
    } finally {
      await res.close();
    }
  }

  /// 取本机非回环 IPv4（电视靠它访问手机/电脑）
  Future<String> _localIpv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final itf in interfaces) {
        for (final addr in itf.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }
}
