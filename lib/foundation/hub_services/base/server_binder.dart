part of 'package:kostori/foundation/hub_services/services.dart';

enum BindMode { ipv4, ipv6, both }

class ServerBinder {
  HttpServer? _serverV4;
  HttpServer? _serverV6;
  int? _port;
  bool _secure = false;

  int get port => _port ?? 9000;

  bool get isRunning => _serverV4 != null || _serverV6 != null;

  bool get isSecure => _secure;

  List<String> get boundAddresses {
    final scheme = _secure ? 'https' : 'http';
    final list = <String>[];
    if (_serverV4 != null) list.add('$scheme://0.0.0.0:$port');
    if (_serverV6 != null) list.add('$scheme://[::]:$port');
    return list;
  }

  /// WebSocket 地址（wss:// 或 ws://）
  List<String> get boundWsAddresses {
    final scheme = _secure ? 'wss' : 'ws';
    final list = <String>[];
    if (_serverV4 != null) list.add('$scheme://0.0.0.0:$port');
    if (_serverV6 != null) list.add('$scheme://[::]:$port');
    return list;
  }

  Future<bool> _isPortAvailable(int port, InternetAddressType type) async {
    try {
      final address = type == InternetAddressType.IPv4
          ? InternetAddress.anyIPv4
          : InternetAddress.anyIPv6;
      final socket = await ServerSocket.bind(address, port);
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> findAvailablePort(int startPort, BindMode mode) async {
    for (int p = startPort; p < startPort + 10; p++) {
      final v4ok = mode != BindMode.ipv6
          ? await _isPortAvailable(p, InternetAddressType.IPv4)
          : true;
      final v6ok = mode != BindMode.ipv4
          ? await _isPortAvailable(p, InternetAddressType.IPv6)
          : true;
      if (v4ok && v6ok) return p;
      HubLog.warning('ServerBinder', '端口 $p 不可用，尝试 ${p + 1}...');
    }
    throw Exception('端口 $startPort 到 ${startPort + 9} 全部被占用');
  }

  Future<void> bind(
    int preferredPort,
    BindMode mode,
    void Function(HttpRequest) onRequest,
  ) async {
    if (isRunning) return;
    _secure = false;
    _port = await findAvailablePort(preferredPort, mode);
    if (_port != preferredPort) {
      HubLog.warning('ServerBinder', '⚠️ 端口 $preferredPort 被占用，改用 $_port');
    }
    switch (mode) {
      case BindMode.ipv4:
        await _bindV4(_port!, onRequest);
      case BindMode.ipv6:
        await _bindV6(_port!, onRequest);
      case BindMode.both:
        await _bindV4(_port!, onRequest);
        await _bindV6(_port!, onRequest);
    }
    HubLog.info('ServerBinder', '✅ 已绑定：${boundAddresses.join(' | ')}');
  }

  Future<void> _bindV4(int port, void Function(HttpRequest) onRequest) async {
    _serverV4 = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _serverV4!.listen(onRequest);
  }

  Future<void> _bindV6(int port, void Function(HttpRequest) onRequest) async {
    try {
      _serverV6 = await HttpServer.bind(
        InternetAddress.anyIPv6,
        port,
        v6Only: true,
      );
      _serverV6!.listen(onRequest);
    } catch (e) {
      HubLog.warning('ServerBinder', '⚠️ IPv6 绑定失败：$e');
    }
  }

  Future<void> close() async {
    await _serverV4?.close(force: true);
    await _serverV6?.close(force: true);
    _serverV4 = null;
    _serverV6 = null;
    _port = null;
    _secure = false;
  }

  Future<void> bindSecure(
    int preferredPort,
    BindMode mode,
    void Function(HttpRequest) onRequest, {
    required String certificatePath,
    required String privateKeyPath,
    String password = '',
  }) async {
    if (isRunning) return;
    _secure = true;
    _port = await findAvailablePort(preferredPort, mode);

    _checkCertificateChain(certificatePath);

    final context = SecurityContext()
      ..useCertificateChain(certificatePath)
      ..usePrivateKey(privateKeyPath, password: password);

    switch (mode) {
      case BindMode.ipv4:
        await _bindSecureV4(_port!, onRequest, context);
      case BindMode.ipv6:
        await _bindSecureV6(_port!, onRequest, context);
      case BindMode.both:
        await _bindSecureV4(_port!, onRequest, context);
        await _bindSecureV6(_port!, onRequest, context);
    }

    HubLog.info('ServerBinder', '🔒 HTTPS 已绑定：${boundAddresses.join(' | ')}');
  }

  Future<void> _bindSecureV4(
    int port,
    void Function(HttpRequest) onRequest,
    SecurityContext context,
  ) async {
    _serverV4 = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      port,
      context,
    );
    _serverV4!.listen(onRequest);
  }

  Future<void> _bindSecureV6(
    int port,
    void Function(HttpRequest) onRequest,
    SecurityContext context,
  ) async {
    try {
      _serverV6 = await HttpServer.bindSecure(
        InternetAddress.anyIPv6,
        port,
        context,
        v6Only: true,
      );
      _serverV6!.listen(onRequest);
    } catch (e) {
      HubLog.warning('ServerBinder', '⚠️ IPv6 HTTPS 绑定失败：$e');
    }
  }

  /// 检查证书链完整性：Let's Encrypt 若只给 cert.pem（仅叶子证书），
  /// 部分客户端（Node.js 等）会因缺中间证书握手失败。
  void _checkCertificateChain(String certificatePath) {
    try {
      final content = File(certificatePath).readAsStringSync();
      final blocks = RegExp(
        r'-----BEGIN CERTIFICATE-----',
      ).allMatches(content).length;
      if (blocks <= 1) {
        HubLog.warning(
          'ServerBinder',
          '⚠️ 证书文件仅含 $blocks 个证书块，可能缺少中间证书链。'
              'Let\'s Encrypt 请使用 fullchain.pem，否则部分客户端（如 Koishi）会握手失败。',
        );
      }
    } catch (_) {
      // 读取失败交给 useCertificateChain 抛异常
    }
  }
}
