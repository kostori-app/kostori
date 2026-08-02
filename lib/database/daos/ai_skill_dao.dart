import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_skill_dao.g.dart';

@DriftAccessor(tables: [AiSkills])
class AiSkillDao extends DatabaseAccessor<AiDatabase> with _$AiSkillDaoMixin {
  AiSkillDao(super.db);

  // ─── 查询 ──────────────────────────────────

  Stream<List<AiSkill>> watchAll() =>
      (select(aiSkills)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  Future<List<AiSkill>> getAll() =>
      (select(aiSkills)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<List<AiSkill>> getEnabled() =>
      (select(aiSkills)..where((t) => t.isEnabled.equals(true))).get();

  Future<AiSkill?> getByKey(String key) =>
      (select(aiSkills)..where((t) => t.key.equals(key))).getSingleOrNull();

  // ─── 写入 ──────────────────────────────────

  Future<void> upsert(AiSkillsCompanion entry) =>
      into(aiSkills).insertOnConflictUpdate(entry);

  Future<void> upsertAll(List<AiSkillsCompanion> entries) async {
    await batch((batch) {
      batch.insertAll(aiSkills, entries, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> setEnabled(int id, {required bool enabled}) =>
      (update(aiSkills)..where((t) => t.id.equals(id))).write(
        AiSkillsCompanion(isEnabled: Value(enabled)),
      );

  Future<int> deleteById(int id) =>
      (delete(aiSkills)..where((t) => t.id.equals(id))).go();
}
