part of 'package:kostori/foundation/services/services.dart';

abstract class BaseService {
  Future<void> init();

  Future<void> dispose();
}
