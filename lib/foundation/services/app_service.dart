part of 'package:kostori/foundation/services/services.dart';

class AppService extends BaseHttpService {
  AppService._internal();

  static final AppService _instance = AppService._internal();

  factory AppService() => _instance;

  static const _portKey = 'service_port';
  static const _bindModeKey = 'service_bind_mode';

  // 从持久化读取设置
  int get savedPort {
    return appdata.implicitData[_portKey] as int? ?? 9000;
  }

  BindMode get savedBindMode {
    final val = appdata.implicitData[_bindModeKey] as String?;
    return switch (val) {
      'ipv6' => BindMode.ipv6,
      'both' => BindMode.both,
      _ => BindMode.ipv4,
    };
  }

  // 保存设置
  void savePort(int port) {
    appdata.implicitData[_portKey] = port;
    appdata.writeImplicitData();
  }

  void saveBindMode(BindMode mode) {
    appdata.implicitData[_bindModeKey] = mode.name; // 'ipv4' / 'ipv6' / 'both'
    appdata.writeImplicitData();
  }

  @override
  void registerRoutes() {}

  @override
  Future<void> init({int? preferredPort, BindMode? mode}) => startServer(
    preferredPort: preferredPort ?? savedPort,
    mode: mode ?? savedBindMode,
  );

  @override
  Future<void> dispose() => stopServer();
}
