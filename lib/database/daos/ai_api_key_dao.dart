// lib/database/daos/ai_api_key_dao.dart

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_api_key_dao.g.dart';

@DriftAccessor(tables: [AiApiKeys])
class AiApiKeyDao extends DatabaseAccessor<AiDatabase> with _$AiApiKeyDaoMixin {
  AiApiKeyDao(super.db);

  // ─── 查询 ──────────────────────────────────

  /// 监听所有 Key 列表
  Stream<List<AiApiKey>> watchAll() => select(aiApiKeys).watch();

  /// 获取所有 Key（一次性）
  Future<List<AiApiKey>> getAll() => select(aiApiKeys).get();

  /// 按服务商获取 Key
  Future<AiApiKey?> getByProvider(String provider) {
    return (select(
      aiApiKeys,
    )..where((t) => t.provider.equals(provider))).getSingleOrNull();
  }

  /// 仅获取已启用的 Key
  Future<List<AiApiKey>> getEnabled() {
    return (select(aiApiKeys)..where((t) => t.isEnabled.equals(true))).get();
  }

  /// 监听指定服务商 Key 变化
  Stream<AiApiKey?> watchByProvider(String provider) {
    return (select(
      aiApiKeys,
    )..where((t) => t.provider.equals(provider))).watchSingleOrNull();
  }

  // ─── 写入 ──────────────────────────────────

  /// 插入或覆盖（upsert）
  Future<void> upsert(AiApiKeysCompanion entry) {
    return into(aiApiKeys).insertOnConflictUpdate(entry);
  }

  /// 更新 Key 值
  Future<void> updateKey(String provider, String newApiKey) {
    return (update(aiApiKeys)..where((t) => t.provider.equals(provider))).write(
      AiApiKeysCompanion(
        apiKey: Value(newApiKey),
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
