import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_session_dao.g.dart';

@DriftAccessor(tables: [AiSessions])
class AiSessionDao extends DatabaseAccessor<AiDatabase>
    with _$AiSessionDaoMixin {
  AiSessionDao(super.db);

  // ─── 会话 CRUD ─────────────────────────────

  Future<void> upsertSession(AiSessionsCompanion entry) =>
      into(aiSessions).insertOnConflictUpdate(entry);

  Future<int> updateOnlyProvider(String sessionId, String provider) {
    return (update(
      aiSessions,
    )..where((t) => t.sessionId.equals(sessionId))).write(
      AiSessionsCompanion(
        provider: Value(provider),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

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

  Future<void> setCompressedContent(String sessionId, String content) =>
      (update(aiSessions)..where((t) => t.sessionId.equals(sessionId))).write(
        AiSessionsCompanion(
          compressedContent: Value(content),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setSkillKeys(String sessionId, List<String> keys) =>
      (update(aiSessions)..where((t) => t.sessionId.equals(sessionId))).write(
        AiSessionsCompanion(
          skillKeys: Value(jsonEncode(keys)),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setProfileId(String sessionId, String? profileId) =>
      (update(aiSessions)..where((t) => t.sessionId.equals(sessionId))).write(
        AiSessionsCompanion(
          profileId: Value(profileId),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setFollowUps(String sessionId, List<String> items) =>
      (update(aiSessions)..where((t) => t.sessionId.equals(sessionId))).write(
        AiSessionsCompanion(
          followUps: Value(items.isEmpty ? null : jsonEncode(items)),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// 仅删除会话本身；消息在 AiTaskDao.deleteBySession 中删除
  Future<int> deleteSession(String sessionId) =>
      (delete(aiSessions)..where((t) => t.sessionId.equals(sessionId))).go();
}
