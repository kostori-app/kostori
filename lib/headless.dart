import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/init.dart';
import 'package:media_kit/media_kit.dart';

/// 结构化输出，供外部脚本解析
void cliPrint(Map<String, dynamic> data) {
  print('[CLI PRINT] ${jsonEncode(data)}');
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

  await init();

  final started = <String, dynamic>{};
  try {
    switch (serviceName) {
      case 'hub':
        await _startHubService(port, mode, noAuth, started);
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

  cliPrint({'status': 'ready', 'service': serviceName, ...started});

  // 保持进程存活，等待退出信号后优雅关闭
  await _waitForShutdown(started);
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
  if (cert != null && key != null) {
    await service.startServerSecure(
      preferredPort: preferred,
      mode: mode,
      certificatePath: cert,
      privateKeyPath: key,
    );
  } else {
    await service.startServer(preferredPort: preferred, mode: mode);
  }
  started['port'] = service.port;
  started['bound'] = service.boundAddresses;
  started['userKey'] = ApiKeyManager().activeKey;
  started['adminKey'] = ApiKeyManager().adminActiveKey;
  started['https'] = cert != null && key != null;
}

Future<void> _startHubService(
  int? port,
  BindMode mode,
  bool noAuth,
  Map<String, dynamic> started,
) async {
  final service = HubService();
  service.setHubNoAuth(noAuth);
  await service.init(preferredPort: port, mode: mode);
  started['port'] = service.port;
  started['bound'] = service.boundAddresses;
  started['userKey'] = ApiKeyManager().activeKey;
  started['adminKey'] = ApiKeyManager().adminActiveKey;
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
