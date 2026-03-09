part of 'package:kostori/foundation/services/services.dart';

class AppService extends BaseHttpService {
  AppService._internal();

  static final AppService _instance = AppService._internal();

  factory AppService() => _instance;

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
