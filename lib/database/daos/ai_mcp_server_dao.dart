import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_mcp_server_dao.g.dart';

@DriftAccessor(tables: [AiMcpServers])
class AiMcpServerDao extends DatabaseAccessor<AiDatabase>
    with _$AiMcpServerDaoMixin {
  AiMcpServerDao(super.db);

  // ─── 查询 ──────────────────────────────────

  Stream<List<AiMcpServer>> watchAll() =>
      (select(aiMcpServers)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  Future<List<AiMcpServer>> getAll() =>
      (select(aiMcpServers)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<List<AiMcpServer>> getEnabled() =>
      (select(aiMcpServers)..where((t) => t.isEnabled.equals(true))).get();

  Future<AiMcpServer?> getById(int id) =>
      (select(aiMcpServers)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ─── 写入 ──────────────────────────────────

  Future<void> upsert(AiMcpServersCompanion entry) =>
      into(aiMcpServers).insertOnConflictUpdate(entry);

  Future<void> setEnabled(int id, {required bool enabled}) =>
      (update(aiMcpServers)..where((t) => t.id.equals(id))).write(
        AiMcpServersCompanion(
          isEnabled: Value(enabled),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> deleteById(int id) =>
      (delete(aiMcpServers)..where((t) => t.id.equals(id))).go();
}
