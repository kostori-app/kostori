import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_custom_provider_dao.g.dart';

@DriftAccessor(tables: [AiCustomProviders])
class AiCustomProviderDao extends DatabaseAccessor<AiDatabase>
    with _$AiCustomProviderDaoMixin {
  AiCustomProviderDao(super.db);

  // ─── 查询 ──────────────────────────────────

  Stream<List<AiCustomProvider>> watchAll() => (select(
    aiCustomProviders,
  )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Future<List<AiCustomProvider>> getAll() => (select(
    aiCustomProviders,
  )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  Future<AiCustomProvider?> getByProvider(String provider) => (select(
    aiCustomProviders,
  )..where((t) => t.provider.equals(provider))).getSingleOrNull();

  Future<List<AiCustomProvider>> getEnabled() =>
      (select(aiCustomProviders)..where((t) => t.isEnabled.equals(true))).get();

  // ─── 写入 ──────────────────────────────────

  Future<void> upsert(AiCustomProvidersCompanion entry) =>
      into(aiCustomProviders).insertOnConflictUpdate(entry);

  Future<void> setEnabled(String provider, {required bool enabled}) {
    return (update(
      aiCustomProviders,
    )..where((t) => t.provider.equals(provider))).write(
      AiCustomProvidersCompanion(
        isEnabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateKey(String provider, String apiKey) {
    return (update(
      aiCustomProviders,
    )..where((t) => t.provider.equals(provider))).write(
      AiCustomProvidersCompanion(
        apiKey: Value(apiKey),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 更新余额查询配置（可传 null 清空）
  Future<void> updateBalance(
    String provider, {
    String? balanceUrl,
    String? balanceKey,
  }) {
    return (update(
      aiCustomProviders,
    )..where((t) => t.provider.equals(provider))).write(
      AiCustomProvidersCompanion(
        balanceUrl: Value(balanceUrl),
        balanceKey: Value(balanceKey),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteByProvider(String provider) {
    return (delete(
      aiCustomProviders,
    )..where((t) => t.provider.equals(provider))).go();
  }
}
