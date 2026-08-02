import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_aux_settings_dao.g.dart';

@DriftAccessor(tables: [AiAuxSettings])
class AiAuxSettingsDao extends DatabaseAccessor<AiDatabase>
    with _$AiAuxSettingsDaoMixin {
  AiAuxSettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(
      aiAuxSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// 写入；[value] 为空时删除该条记录
  Future<void> set(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await (delete(aiAuxSettings)..where((t) => t.key.equals(key))).go();
      return;
    }
    await into(aiAuxSettings).insertOnConflictUpdate(
      AiAuxSettingsCompanion(key: Value(key), value: Value(value)),
    );
  }
}
