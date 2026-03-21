import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_session_dao.g.dart';

@DriftAccessor(tables: [AiSessions, AiTasks])
class AiSessionDao extends DatabaseAccessor<AiDatabase>
    with _$AiSessionDaoMixin {
  AiSessionDao(super.db);

  // ─── 会话 CRUD ─────────────────────────────

  Future<void> upsertSession(AiSessionsCompanion entry) =>
      into(aiSessions).insertOnConflictUpdate(entry);

  Future<AiSession?> getSession(String sessionId) => (select(
    aiSessions,
  )..where((t) => t.sessionId.equals(sessionId))).getSingleOrNull();

  Stream<List<AiSession>> watchAllSessions() => (select(
    aiSessions,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Stream<List<AiSession>> watchSessionsByType(String type) =>
      (select(aiSessions)
            ..where((t) => t.type.equals(type))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<void> touchSession(String sessionId) =>
      (update(aiSessions)..where((t) => t.sessionId.equals(sessionId))).write(
        AiSessionsCompanion(updatedAt: Value(DateTime.now())),
      );

  Future<void> renameSession(String sessionId, String title) =>
      (update(aiSessions)..where((t) => t.sessionId.equals(sessionId))).write(
        AiSessionsCompanion(title: Value(title)),
      );

  Future<int> deleteSession(String sessionId) async {
    await (delete(aiTasks)..where((t) => t.sessionId.equals(sessionId))).go();
    return (delete(
      aiSessions,
    )..where((t) => t.sessionId.equals(sessionId))).go();
  }

  // ─── 消息查询 ──────────────────────────────

  Future<List<AiTask>> getMessages(String sessionId) =>
      (select(aiTasks)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Stream<List<AiTask>> watchMessages(String sessionId) =>
      (select(aiTasks)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<int> insertMessage(AiTasksCompanion entry) =>
      into(aiTasks).insert(entry);
}
