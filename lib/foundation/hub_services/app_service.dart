part of 'package:kostori/foundation/hub_services/services.dart';

class AppService extends BaseHttpService {
  AppService._internal();

  static final AppService _instance = AppService._internal();

  factory AppService() => _instance;

  @override
  void registerRoutes() {}

  @override
  Future<void> init({int? preferredPort, BindMode? mode}) async {
    final port = preferredPort ?? savedPort;
    final bind = mode ?? savedBindMode;
    if (tlsEnabled && tlsConfigured) {
      await startServerSecure(
        preferredPort: port,
        mode: bind,
        certificatePath: tlsCertificatePath!,
        privateKeyPath: tlsPrivateKeyPath!,
        password: tlsPassword ?? '',
      );
    } else {
      await startServer(preferredPort: port, mode: bind);
    }
  }

  @override
  Future<void> dispose() => stopServer();
}
