part of 'package:kostori/foundation/hub_services/services.dart';

abstract class BaseService {
  Future<void> init();

  Future<void> dispose();
}
