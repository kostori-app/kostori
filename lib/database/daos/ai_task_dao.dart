// lib/database/daos/ai_task_dao.dart

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_task_dao.g.dart';

@DriftAccessor(tables: [AiTasks])
class AiTaskDao extends DatabaseAccessor<AiDatabase> with _$AiTaskDaoMixin {
  AiTaskDao(super.db);

  // ─── 查询 ──────────────────────────────────

  /// 监听所有任务（最新在前）
  Stream<List<AiTask>> watchAll() {
    return (select(
      aiTasks,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  /// 按任务类型查询
  Future<List<AiTask>> getByType(String taskType) {
    return (select(aiTasks)
          ..where((t) => t.taskType.equals(taskType))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 监听某类型任务
  Stream<List<AiTask>> watchByType(String taskType) {
    return (select(aiTasks)
          ..where((t) => t.taskType.equals(taskType))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// 按服务商查询
  Future<List<AiTask>> getByProvider(String provider) {
    return (select(aiTasks)
          ..where((t) => t.provider.equals(provider))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 获取单条任务
  Future<AiTask?> getById(int id) {
    return (select(aiTasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 按日期范围查询
  Future<List<AiTask>> getByDateRange(DateTime from, DateTime to) {
    return (select(aiTasks)
          ..where((t) => t.createdAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 统计某类型任务数量
  Future<int> countByType(String taskType) async {
    final count = aiTasks.id.count();
    final query = selectOnly(aiTasks)
      ..addColumns([count])
      ..where(aiTasks.taskType.equals(taskType));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// 统计总 Token 消耗
  Future<int> totalTokensConsumed() async {
    final sum = aiTasks.tokenConsumed.sum();
    final query = selectOnly(aiTasks)..addColumns([sum]);
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  // ─── 写入 ──────────────────────────────────

  /// 插入任务记录，返回新 ID
  Future<int> insert(AiTasksCompanion entry) => into(aiTasks).insert(entry);

  /// 删除单条记录
  Future<int> deleteById(int id) =>
      (delete(aiTasks)..where((t) => t.id.equals(id))).go();

  /// 清空指定类型的历史
  Future<int> deleteByType(String taskType) =>
      (delete(aiTasks)..where((t) => t.taskType.equals(taskType))).go();

  /// 清空所有记录
  Future<int> deleteAll() => delete(aiTasks).go();
}
