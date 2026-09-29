// lib/database/daos/ai_api_key_dao.dart

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/secret_vault.dart';

part 'ai_api_key_dao.g.dart';

/// apiKey 落库前加密、读出后解密：调用方拿到的始终是明文，
/// 磁盘/备份中始终是密文（导出场景在 ai_database 里显式解密为明文）。
AiApiKey _plainRow(AiApiKey r) =>
    r.copyWith(apiKey: SecretVault.decrypt(r.apiKey));

AiApiKeysCompanion _secretEntry(AiApiKeysCompanion c) => c.copyWith(
  apiKey: c.apiKey.present
      ? Value(SecretVault.encrypt(c.apiKey.value))
      : const Value.absent(),
);

@DriftAccessor(tables: [AiApiKeys])
class AiApiKeyDao extends DatabaseAccessor<AiDatabase> with _$AiApiKeyDaoMixin {
  AiApiKeyDao(super.db);

  // ─── 查询 ──────────────────────────────────

  /// 监听所有 Key 列表
  Stream<List<AiApiKey>> watchAll() =>
      select(aiApiKeys).watch().map((rows) => rows.map(_plainRow).toList());

  /// 获取所有 Key（一次性）
  Future<List<AiApiKey>> getAll() async =>
      (await select(aiApiKeys).get()).map(_plainRow).toList();

  /// 按服务商获取 Key
  Future<AiApiKey?> getByProvider(String provider) async {
    final row = await (select(
      aiApiKeys,
    )..where((t) => t.provider.equals(provider))).getSingleOrNull();
    return row == null ? null : _plainRow(row);
  }

  /// 仅获取已启用的 Key
  Future<List<AiApiKey>> getEnabled() async => ((await (select(
    aiApiKeys,
  )..where((t) => t.isEnabled.equals(true))).get()).map(_plainRow).toList());

  /// 监听指定服务商 Key 变化
  Stream<AiApiKey?> watchByProvider(String provider) =>
      (select(aiApiKeys)..where((t) => t.provider.equals(provider)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _plainRow(row));

  // ─── 写入 ──────────────────────────────────

  /// 插入或覆盖（upsert）
  Future<void> upsert(AiApiKeysCompanion entry) {
    return into(aiApiKeys).insertOnConflictUpdate(_secretEntry(entry));
  }

  /// 更新 Key 值
  Future<void> updateKey(String provider, String newApiKey) {
    return (update(aiApiKeys)..where((t) => t.provider.equals(provider))).write(
      AiApiKeysCompanion(
        apiKey: Value(SecretVault.encrypt(newApiKey)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 更新模型
  Future<void> updateModel(String provider, String model) {
    return (update(aiApiKeys)..where((t) => t.provider.equals(provider))).write(
      AiApiKeysCompanion(model: Value(model), updatedAt: Value(DateTime.now())),
    );
  }

  /// 更新余额查询配置（可传 null 清空）
  Future<void> updateBalance(
    String provider, {
    String? balanceUrl,
    String? balanceKey,
  }) {
    return (update(aiApiKeys)..where((t) => t.provider.equals(provider))).write(
      AiApiKeysCompanion(
        balanceUrl: Value(balanceUrl),
        balanceKey: Value(balanceKey),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 切换启用状态
  Future<void> setEnabled(String provider, {required bool enabled}) {
    return (update(aiApiKeys)..where((t) => t.provider.equals(provider))).write(
      AiApiKeysCompanion(
        isEnabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 删除指定服务商 Key
  Future<int> deleteByProvider(String provider) {
    return (delete(aiApiKeys)..where((t) => t.provider.equals(provider))).go();
  }

  /// 删除所有 Key
  Future<int> deleteAll() => delete(aiApiKeys).go();
}
