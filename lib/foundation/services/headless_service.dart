part of 'package:kostori/foundation/services/services.dart';

class HeadlessService extends BaseHttpService {
  HeadlessService._internal();

  static final HeadlessService _instance = HeadlessService._internal();

  factory HeadlessService() => _instance;

  @override
  void registerRoutes() {}

  @override
  Future<void> init({
    int preferredPort = 9001,
    BindMode mode = BindMode.ipv4,
  }) => startServer(preferredPort: preferredPort, mode: mode);

  @override
  Future<void> dispose() => stopServer();
}
