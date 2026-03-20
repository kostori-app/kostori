// lib/database/daos/ai_provider_stats_dao.dart

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_provider_stats_dao.g.dart';

@DriftAccessor(tables: [AiProviderStats])
class AiProviderStatsDao extends DatabaseAccessor<AiDatabase>
    with _$AiProviderStatsDaoMixin {
  AiProviderStatsDao(super.db);

  // ─── 查询 ──────────────────────────────────

  Stream<List<AiProviderStat>> watchAll() => select(aiProviderStats).watch();

  Future<List<AiProviderStat>> getAll() => select(aiProviderStats).get();

  Future<AiProviderStat?> getByProvider(String provider) {
    return (select(
      aiProviderStats,
    )..where((t) => t.provider.equals(provider))).getSingleOrNull();
  }

  Stream<AiProviderStat?> watchByProvider(String provider) {
    return (select(
      aiProviderStats,
    )..where((t) => t.provider.equals(provider))).watchSingleOrNull();
  }

  // ─── 写入 ──────────────────────────────────

  /// 插入或覆盖
  Future<void> upsert(AiProviderStatsCompanion entry) =>
      into(aiProviderStats).insertOnConflictUpdate(entry);

  /// 标记 Key 有效性并记录检查时间
  Future<void> updateValidity(String provider, {required bool isValid}) {
    return (update(
      aiProviderStats,
    )..where((t) => t.provider.equals(provider))).write(
      AiProviderStatsCompanion(
        isValid: Value(isValid),
        lastCheckAt: Value(DateTime.now()),
      ),
    );
  }

  /// 调用次数 +1（原子操作）
  Future<void> incrementCalls(String provider) async {
    final stat = await getByProvider(provider);
    if (stat == null) {
      await upsert(
        AiProviderStatsCompanion.insert(
          provider: provider,
          totalCalls: const Value(1),
        ),
      );
    } else {
      await (update(
        aiProviderStats,
      )..where((t) => t.provider.equals(provider))).write(
        AiProviderStatsCompanion(totalCalls: Value(stat.totalCalls + 1)),
      );
    }
  }

  /// 重置调用计数
  Future<void> resetCalls(String provider) {
    return (update(aiProviderStats)..where((t) => t.provider.equals(provider)))
        .write(const AiProviderStatsCompanion(totalCalls: Value(0)));
  }

  Future<int> deleteByProvider(String provider) =>
      (delete(aiProviderStats)..where((t) => t.provider.equals(provider))).go();
}
