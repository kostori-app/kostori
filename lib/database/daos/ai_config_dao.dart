// lib/database/daos/ai_config_dao.dart

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_config_dao.g.dart';

@DriftAccessor(tables: [AiConfigs])
class AiConfigDao extends DatabaseAccessor<AiDatabase> with _$AiConfigDaoMixin {
  AiConfigDao(super.db);

  // ─── 查询 ──────────────────────────────────

  /// 监听所有配置
  Stream<List<AiConfig>> watchAll() => select(aiConfigs).watch();

  /// 获取所有配置（一次性）
  Future<List<AiConfig>> getAll() => select(aiConfigs).get();

  /// 按 configKey 获取
  Future<AiConfig?> getByKey(String configKey) async {
    return (select(
      aiConfigs,
    )..where((t) => t.configKey.equals(configKey))).getSingleOrNull();
  }

  /// 监听某个配置
  Stream<AiConfig?> watchByKey(String configKey) {
    return (select(
      aiConfigs,
    )..where((t) => t.configKey.equals(configKey))).watchSingleOrNull();
  }

  // ─── 写入 ──────────────────────────────────

  /// 插入或覆盖（upsert）
  Future<void> upsert(AiConfigsCompanion entry) =>
      into(aiConfigs).insertOnConflictUpdate(entry);

  /// 更新 System Prompt
  Future<void> updateSystemPrompt(String configKey, String systemPrompt) {
    return (update(aiConfigs)..where((t) => t.configKey.equals(configKey)))
        .write(AiConfigsCompanion(systemPrompt: Value(systemPrompt)));
  }

  /// 更新 temperature
  Future<void> updateTemperature(String configKey, double temperature) {
    return (update(aiConfigs)..where((t) => t.configKey.equals(configKey)))
        .write(AiConfigsCompanion(temperature: Value(temperature)));
  }

  /// 删除指定配置
  Future<int> deleteByKey(String configKey) =>
      (delete(aiConfigs)..where((t) => t.configKey.equals(configKey))).go();
}
