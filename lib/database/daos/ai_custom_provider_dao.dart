import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/secret_vault.dart';

part 'ai_custom_provider_dao.g.dart';

AiCustomProvider _plainRow(AiCustomProvider r) => r.apiKey == null
    ? r
    : r.copyWith(apiKey: Value(SecretVault.decrypt(r.apiKey!)));

AiCustomProvidersCompanion _secretEntry(AiCustomProvidersCompanion c) =>
    c.copyWith(
      apiKey: (c.apiKey.present && c.apiKey.value != null)
          ? Value(SecretVault.encrypt(c.apiKey.value!))
          : const Value.absent(),
    );

@DriftAccessor(tables: [AiCustomProviders])
class AiCustomProviderDao extends DatabaseAccessor<AiDatabase>
    with _$AiCustomProviderDaoMixin {
  AiCustomProviderDao(super.db);

  // ─── 查询 ──────────────────────────────────

  Stream<List<AiCustomProvider>> watchAll() =>
      (select(aiCustomProviders)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch()
          .map((rows) => rows.map(_plainRow).toList());

  Future<List<AiCustomProvider>> getAll() async =>
      (await (select(
            aiCustomProviders,
          )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get())
          .map(_plainRow)
          .toList();

  Future<AiCustomProvider?> getByProvider(String provider) async {
    final row = await (select(
      aiCustomProviders,
    )..where((t) => t.provider.equals(provider))).getSingleOrNull();
    return row == null ? null : _plainRow(row);
  }

  Future<List<AiCustomProvider>> getEnabled() async => (await (select(
    aiCustomProviders,
  )..where((t) => t.isEnabled.equals(true))).get()).map(_plainRow).toList();

  // ─── 写入 ──────────────────────────────────

  Future<void> upsert(AiCustomProvidersCompanion entry) =>
      into(aiCustomProviders).insertOnConflictUpdate(_secretEntry(entry));

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
        apiKey: Value(SecretVault.encrypt(apiKey)),
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
