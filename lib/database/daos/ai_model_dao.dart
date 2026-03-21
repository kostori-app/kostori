import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';

part 'ai_model_dao.g.dart';

@DriftAccessor(tables: [AiModels])
class AiModelDao extends DatabaseAccessor<AiDatabase> with _$AiModelDaoMixin {
  AiModelDao(super.db);

  // 监听所有已启用的模型
  Stream<List<AiModel>> watchActiveModels() {
    return (select(aiModels)..where((t) => t.isActive.equals(true))).watch();
  }

  // 获取所有模型（用于管理界面）
  Stream<List<AiModel>> watchAll() {
    return select(aiModels).watch();
  }

  // 根据复合主键获取特定模型
  Future<AiModel?> getModel(String provider, String modelId) {
    return (select(aiModels)..where(
          (t) => t.provider.equals(provider) & t.modelId.equals(modelId),
        ))
        .getSingleOrNull();
  }

  // 批量保存模型（重复则覆盖）
  Future<void> upsertModels(List<AiModelsCompanion> companions) async {
    await batch((batch) {
      batch.insertAll(aiModels, companions, mode: InsertMode.insertOrReplace);
    });
  }

  // 删除特定模型
  Future<int> deleteModel(String provider, String modelId) {
    return (delete(aiModels)..where(
          (t) => t.provider.equals(provider) & t.modelId.equals(modelId),
        ))
        .go();
  }
}
