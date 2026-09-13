import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_task_dao.g.dart';

@DriftAccessor(tables: [AiTasks])
class AiTaskDao extends DatabaseAccessor<AiDatabase> with _$AiTaskDaoMixin {
  AiTaskDao(super.db);

  Stream<List<AiTask>> watchAll() => (select(
    aiTasks,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Stream<List<AiTask>> watchByType(String taskType) =>
      (select(aiTasks)
            ..where((t) => t.taskType.equals(taskType))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<List<AiTask>> getBySession(String sessionId) =>
      (select(aiTasks)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> insert(AiTasksCompanion entry) => into(aiTasks).insert(entry);

  Future<AiTask?> getById(int id) =>
      (select(aiTasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 编辑消息正文（用户消息改输入，模型消息改输出）
  Future<void> updateMessageInput(int id, String inputContent) =>
      (update(aiTasks)..where((t) => t.id.equals(id))).write(
        AiTasksCompanion(inputContent: Value(inputContent)),
      );

  /// 写入多候选回复并选中指定下标（同时同步 outputContent）
  Future<void> setVariants(int id, List<String> variants, int index) {
    final safeIndex = index.clamp(0, variants.isEmpty ? 0 : variants.length - 1);
    return (update(aiTasks)..where((t) => t.id.equals(id))).write(
      AiTasksCompanion(
        outputVariants: Value(jsonEncode(variants)),
        variantIndex: Value(safeIndex),
        outputContent: Value(variants.isEmpty ? null : variants[safeIndex]),
      ),
    );
  }

  Future<int> deleteById(int id) =>
      (delete(aiTasks)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByType(String taskType) =>
      (delete(aiTasks)..where((t) => t.taskType.equals(taskType))).go();

  Future<int> deleteBySession(String sessionId) =>
      (delete(aiTasks)..where((t) => t.sessionId.equals(sessionId))).go();

  Future<void> deleteMessagesFrom(String sessionId, int fromTaskId) =>
      (delete(aiTasks)..where(
            (t) =>
                t.sessionId.equals(sessionId) &
                t.id.isBiggerOrEqualValue(fromTaskId),
          ))
          .go();

  Future<void> deleteMessagesTo(String sessionId, int toTaskId) =>
      (delete(aiTasks)..where(
            (t) =>
                t.sessionId.equals(sessionId) &
                t.id.isSmallerOrEqualValue(toTaskId),
          ))
          .go();
}
