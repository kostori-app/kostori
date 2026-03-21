// lib/database/daos/ai_config_dao.dart

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_config_dao.g.dart';

@DriftAccessor(tables: [AiConfigs])
class AiConfigDao extends DatabaseAccessor<AiDatabase> with _$AiConfigDaoMixin {
  AiConfigDao(super.db);

  // ─── 查询 ──────────────────────────────────

  /// 监听所有配置，按 ID 升序排列（确保 1-10 的官方预设排在最前）
  Stream<List<AiConfig>> watchAll() {
    return (select(
      aiConfigs,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  }

  /// 获取所有配置（一次性）
  Future<List<AiConfig>> getAll() {
    return (select(aiConfigs)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  /// 按自增 id 获取（UI 编辑时推荐使用）
  Future<AiConfig?> getById(int id) {
    return (select(aiConfigs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 按 configKey 获取（代码逻辑调用模板时使用）
  Future<AiConfig?> getByKey(String configKey) {
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
  /// 如果 companion 中包含 id，则按 id 更新；如果不包含 id 但 configKey 重复，则按 unique 约束更新
  Future<void> upsert(AiConfigsCompanion entry) {
    return into(aiConfigs).insertOnConflictUpdate(entry);
  }

  /// 根据 ID 更新内容
  Future<void> updateConfig(int id, AiConfigsCompanion entry) {
    return (update(aiConfigs)..where((t) => t.id.equals(id))).write(entry);
  }

  // ─── 删除 ──────────────────────────────────

  /// 按 ID 删除指定配置
  Future<int> deleteById(int id) {
    return (delete(aiConfigs)..where((t) => t.id.equals(id))).go();
  }

  /// 按 configKey 删除（可选）
  Future<int> deleteByKey(String configKey) {
    return (delete(
      aiConfigs,
    )..where((t) => t.configKey.equals(configKey))).go();
  }
}
