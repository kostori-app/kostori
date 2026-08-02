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

  // 更新模型能力标记（null 表示保持不变）
  Future<void> updateCapabilities(
    String provider,
    String modelId, {
    bool? supportsVision,
    bool? supportsTools,
    bool? supportsReasoning,
  }) {
    return (update(aiModels)..where(
          (t) => t.provider.equals(provider) & t.modelId.equals(modelId),
        ))
        .write(
          AiModelsCompanion(
            supportsVision: supportsVision == null
                ? const Value.absent()
                : Value(supportsVision),
            supportsTools: supportsTools == null
                ? const Value.absent()
                : Value(supportsTools),
            supportsReasoning: supportsReasoning == null
                ? const Value.absent()
                : Value(supportsReasoning),
          ),
        );
  }

  // 更新模型元信息（类型 / 输入模态 / 输出模态）
  Future<void> updateMeta(
    String provider,
    String modelId, {
    String? modelType,
    String? inputModality,
    String? outputModality,
  }) {
    return (update(aiModels)..where(
          (t) => t.provider.equals(provider) & t.modelId.equals(modelId),
        ))
        .write(
          AiModelsCompanion(
            modelType: modelType == null
                ? const Value.absent()
                : Value(modelType),
            inputModality: inputModality == null
                ? const Value.absent()
                : Value(inputModality),
            outputModality: outputModality == null
                ? const Value.absent()
                : Value(outputModality),
          ),
        );
  }
}
