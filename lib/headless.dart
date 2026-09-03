import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/main_isolate_runner.dart';
import 'package:kostori/foundation/webview_resolver.dart';
import 'package:kostori/init.dart';
import 'package:media_kit/media_kit.dart';

/// 结构化输出，供外部脚本解析
void cliPrint(Map<String, dynamic> data) {
  print('[CLI PRINT] ${jsonEncode(data)}');
}

/// 打印启动说明（始终可见，不受日志开关影响）
void _startupLog(String message) {
  // 前缀与 cliPrint 区分，供人眼阅读
  print('[KOSTORI] $message');
}

/// 解析 `--key value` 或 `--key=value` 形式的参数
String? _stringArg(List<String> args, String key) {
  final prefix = '$key=';
  for (final a in args) {
    if (a == key) {
      final idx = args.indexOf(a);
      if (idx + 1 < args.length) return args[idx + 1];
      return null;
    }
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}

/// 解析 `--key <int>` 形式的参数
int? _intArg(List<String> args, String key) {
  final v = _stringArg(args, key);
  if (v == null) return null;
  return int.tryParse(v);
}

/// 解析 `--bind <ipv4|ipv6|both>` 参数
BindMode _bindArg(List<String> args, String key) {
  final v = _stringArg(args, key);
  return switch (v) {
    'ipv6' => BindMode.ipv6,
    'both' => BindMode.both,
    _ => BindMode.ipv4,
  };
}

/// 运行无头模式：初始化应用后按 `--service` 启动对应服务，保持进程存活。
Future<void> runHeadlessMode(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // 无头模式也注册主 isolate 通道（防御性：若源脚本触发 WebView 平台操作）
  MainIsolateRunner.register();
  WebViewResolver.registerMainIsolateHandler();
  if (args.contains('--ignore-disheadless-log')) {
    Log.isMuted = true;
  }
  if (Platform.isLinux || Platform.isMacOS) {
    Directory.current = Platform.environment['HOME']!;
  }

  final serviceName = _stringArg(args, '--service') ?? 'headless';
  final port = _intArg(args, '--port');
  final mode = _bindArg(args, '--bind');
  final noAuth = args.contains('--no-auth');
  final cert = _stringArg(args, '--cert');
  final key = _stringArg(args, '--key');

  // 可选固定令牌：服务端可用 --api-key / --admin-key 指定稳定令牌
  final apiKey = _stringArg(args, '--api-key');
  final adminKey = _stringArg(args, '--admin-key');
  if (apiKey != null && apiKey.isNotEmpty) {
    await ApiKeyManager().setFixedKey(apiKey);
    await ApiKeyManager().setUseFixed(true);
  }
  if (adminKey != null && adminKey.isNotEmpty) {
    await ApiKeyManager().setAdminFixedKey(adminKey);
    await ApiKeyManager().setUseAdminFixed(true);
  }

  await init();

  final started = <String, dynamic>{};
  try {
    switch (serviceName) {
      case 'hub':
        await _startHubService(port, mode, noAuth, cert, key, started);
      case 'lan':
        await _startLanService(port, started);
      case 'headless':
      default:
        await _startHeadlessService(port, mode, noAuth, cert, key, started);
    }
  } catch (e, s) {
    cliPrint({'status': 'error', 'service': serviceName, 'message': '$e\n$s'});
    exit(1);
  }

  _printStartupInfo(serviceName, noAuth, started);

  cliPrint({'status': 'ready', 'service': serviceName, ...started});

  // 保持进程存活，等待退出信号后优雅关闭
  await _waitForShutdown(started);
}

/// 打印启动说明与令牌获取方式（人眼可读，始终可见）
void _printStartupInfo(
  String serviceName,
  bool noAuth,
  Map<String, dynamic> started,
) {
  _startupLog('══════════════════════════════════════════════');
  _startupLog('Kostori 无头服务已启动: $serviceName');
  _startupLog('端口: ${started['port']}   绑定: ${started['bound']}');
  if (started['https'] == true) _startupLog('HTTPS: 已启用');
  if (noAuth) {
    _startupLog('鉴权: 已关闭 (--no-auth)，无需令牌');
  } else {
    final userKey = started['userKey'] as String? ?? '';
    final adminKey = started['adminKey'] as String? ?? '';
    _startupLog('用户令牌: $userKey');
    _startupLog('管理令牌: $adminKey');
    _startupLog('调用方式: 请求头  X-Api-Key: <令牌>');
    _startupLog('        或查询参数 ?api_key=<令牌>');
    _startupLog('提示: 令牌为随机生成，重启会变化；如需稳定令牌，');
    _startupLog('     启动时加 --api-key <值> / --admin-key <值> 指定。');
  }
  _startupLog('══════════════════════════════════════════════');
}

Future<void> _startHeadlessService(
  int? port,
  BindMode mode,
  bool noAuth,
  String? cert,
  String? key,
  Map<String, dynamic> started,
) async {
  final service = HeadlessService();
  service.setHubNoAuth(noAuth);
  final preferred = port ?? 9001;
  // 命令行 --cert/--key 优先；否则读应用内 TLS 配置（与 hub 服务一致）
  if (cert != null && key != null) {
    await service.startServerSecure(
      preferredPort: preferred,
      mode: mode,
      certificatePath: cert,
      privateKeyPath: key,
    );
    started['https'] = true;
  } else if (service.tlsEnabled && service.tlsConfigured) {
    await service.startServerSecure(
      preferredPort: preferred,
      mode: mode,
      certificatePath: service.tlsCertificatePath!,
      privateKeyPath: service.tlsPrivateKeyPath!,
      password: service.tlsPassword ?? '',
    );
    started['https'] = true;
  } else {
    await service.startServer(preferredPort: preferred, mode: mode);
    started['https'] = false;
  }
  started['port'] = service.port;
  started['bound'] = service.boundAddresses;
  started['userKey'] = ApiKeyManager().activeKey;
  started['adminKey'] = ApiKeyManager().adminActiveKey;
}

Future<void> _startHubService(
  int? port,
  BindMode mode,
  bool noAuth,
  String? cert,
  String? key,
  Map<String, dynamic> started,
) async {
  final service = HubService();
  service.setHubNoAuth(noAuth);
  // 命令行 --cert/--key 优先：显式指定时强制启用 HTTPS（覆盖应用内配置）
  if (cert != null && key != null) {
    service.setTlsEnabled(true);
    service.setTlsCertificatePath(cert);
    service.setTlsPrivateKeyPath(key);
  }
  await service.init(preferredPort: port, mode: mode);
  started['port'] = service.port;
  started['bound'] = service.boundAddresses;
  started['userKey'] = ApiKeyManager().activeKey;
  started['adminKey'] = ApiKeyManager().adminActiveKey;
  started['https'] = cert != null && key != null;
}

Future<void> _startLanService(int? port, Map<String, dynamic> started) async {
  await LanControlService.instance.start(port ?? 42183);
  started['port'] = LanControlService.instance.port;
  started['bound'] = ['0.0.0.0'];
}

Future<void> _waitForShutdown(Map<String, dynamic> started) async {
  final completer = Completer<void>();
  final signalSubs = <StreamSubscription<ProcessSignal>>[];
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signalSubs.add(
      signal.watch().listen((_) {
        if (!completer.isCompleted) completer.complete();
      }),
    );
  }
  await completer.future;
  for (final sub in signalSubs) {
    await sub.cancel();
  }
  cliPrint({'status': 'stopping', ...started});
  try {
    await HeadlessService().dispose();
  } catch (_) {}
  try {
    await HubService().dispose();
  } catch (_) {}
  try {
    await LanControlService.instance.stop();
  } catch (_) {}
  cliPrint({'status': 'stopped'});
  exit(0);
}
