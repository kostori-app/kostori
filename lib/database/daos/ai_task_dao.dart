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
}
