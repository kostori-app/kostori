// lib/repositories/ai_repository.dart
//
// 统一入口：将 Drift 数据库与 AiBase 提供者对接。
// 所有 AI 调用请走这里，Key 从数据库读取，调用结果自动入库。

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/daos/ai_api_key_dao.dart';
import 'package:kostori/database/daos/ai_config_dao.dart';
import 'package:kostori/database/daos/ai_provider_stats_dao.dart';
import 'package:kostori/database/daos/ai_task_dao.dart';
import 'package:kostori/foundation/ai_base.dart';
import 'package:kostori/foundation/res.dart';

class AiRepository {
  final AiDatabase _db;

  AiRepository(this._db);

  // 快捷访问 DAO
  AiApiKeyDao get _keyDao => _db.aiApiKeyDao;

  AiTaskDao get _taskDao => _db.aiTaskDao;

  AiConfigDao get _configDao => _db.aiConfigDao;

  AiProviderStatsDao get _statsDao => _db.aiProviderStatsDao;

  // ═══════════════════════════════════════════════════════
  // API Key 管理
  // ═══════════════════════════════════════════════════════

  /// 保存/更新某服务商的 Key 配置
  Future<void> saveApiKey({
    required String provider,
    required String apiKey,
    String? baseUrl,
    String? model,
  }) async {
    await _keyDao.upsert(
      AiApiKeysCompanion.insert(
        provider: provider,
        apiKey: apiKey,
        baseUrl: Value(baseUrl),
        model: Value(model),
      ),
    );
    // 确保 stats 行存在
    await _statsDao.upsert(AiProviderStatsCompanion.insert(provider: provider));
  }

  Future<AiApiKey?> getApiKey(String provider) =>
      _keyDao.getByProvider(provider);

  Stream<AiApiKey?> watchApiKey(String provider) =>
      _keyDao.watchByProvider(provider);

  Stream<List<AiApiKey>> watchAllApiKeys() => _keyDao.watchAll();

  Future<void> setKeyEnabled(String provider, {required bool enabled}) =>
      _keyDao.setEnabled(provider, enabled: enabled);

  Future<void> deleteApiKey(String provider) =>
      _keyDao.deleteByProvider(provider);

  // ═══════════════════════════════════════════════════════
  // AI 调用（自动读取 Key、自动入库、自动统计）
  // ═══════════════════════════════════════════════════════

  /// 通用发送：内部读取 DB 中的 Key，覆盖 AiBase.getConfig()
  Future<Res<String>> chat({
    required String provider,
    required List<AiMessage> messages,
    String? configKey, // 对应 AiConfigs.configKey，用于读取 systemPrompt
    String? taskType, // 填写后自动将结果写入 AiTasks
  }) async {
    // 1. 读取 Key
    final keyRow = await _keyDao.getByProvider(provider);
    if (keyRow == null || !keyRow.isEnabled) {
      return Res.error('[$provider] API Key 未配置或已禁用');
    }

    // 2. 读取 System Prompt（可选）
    String? systemPrompt;
    if (configKey != null) {
      final cfg = await _configDao.getByKey(configKey);
      systemPrompt = cfg?.systemPrompt;
    }

    // 3. 构建 AiConfig 并调用
    final config = _buildConfig(provider, keyRow);
    final ai = AiFactory.createFromConfig(config);
    if (ai == null) return Res.error('未知服务商: $provider');

    final result = await ai.chat(messages, systemPrompt: systemPrompt);

    // 4. 统计与入库
    await _statsDao.incrementCalls(provider);
    if (result.success && taskType != null) {
      await _taskDao.insert(
        AiTasksCompanion.insert(
          taskType: taskType,
          provider: provider,
          inputContent: messages.last.content,
          outputContent: result.data,
          modelName: Value(keyRow.model),
          // token 信息由调用方传入（如需精确统计，可扩展 Res）
        ),
      );
    }

    return result;
  }

  /// 单次 generate 快捷方法
  Future<Res<String>> generate({
    required String provider,
    required String prompt,
    String? configKey,
    String? taskType,
  }) => chat(
    provider: provider,
    messages: [AiUserMessage(content: prompt)],
    configKey: configKey,
    taskType: taskType,
  );

  // ═══════════════════════════════════════════════════════
  // AiConfigs (System Prompt 管理)
  // ═══════════════════════════════════════════════════════

  Future<void> saveConfig({
    required String configKey,
    required String systemPrompt,
    double temperature = 0.7,
    String? memo,
  }) => _configDao.upsert(
    AiConfigsCompanion.insert(
      configKey: configKey,
      systemPrompt: systemPrompt,
      temperature: Value(temperature),
      memo: Value(memo),
    ),
  );

  Future<AiConfig?> getConfig(String configKey) =>
      _configDao.getByKey(configKey);

  Stream<List<AiConfig>> watchAllConfigs() => _configDao.watchAll();

  Future<void> updateSystemPrompt(String configKey, String prompt) =>
      _configDao.updateSystemPrompt(configKey, prompt);

  Future<void> deleteConfig(String configKey) =>
      _configDao.deleteByKey(configKey);

  // ═══════════════════════════════════════════════════════
  // AiTasks (历史记录)
  // ═══════════════════════════════════════════════════════

  Stream<List<AiTask>> watchAllTasks() => _taskDao.watchAll();

  Stream<List<AiTask>> watchTasksByType(String taskType) =>
      _taskDao.watchByType(taskType);

  Future<List<AiTask>> getTasksByProvider(String provider) =>
      _taskDao.getByProvider(provider);

  Future<int> totalTokensConsumed() => _taskDao.totalTokensConsumed();

  Future<void> deleteTask(int id) => _taskDao.deleteById(id);

  Future<void> clearTasksByType(String taskType) =>
      _taskDao.deleteByType(taskType);

  // ═══════════════════════════════════════════════════════
  // AiProviderStats (状态 / 健康检查)
  // ═══════════════════════════════════════════════════════

  Stream<List<AiProviderStat>> watchAllStats() => _statsDao.watchAll();

  Future<AiProviderStat?> getStats(String provider) =>
      _statsDao.getByProvider(provider);

  /// 校验 Key 可用性并更新 stats
  Future<bool> validateKey(String provider) async {
    final result = await generate(provider: provider, prompt: 'Hello');
    final valid = result.success;
    await _statsDao.updateValidity(provider, isValid: valid);
    return valid;
  }

  Future<void> resetCallCount(String provider) =>
      _statsDao.resetCalls(provider);

  // ═══════════════════════════════════════════════════════
  // 内部工具
  // ═══════════════════════════════════════════════════════

  AiProviderConfig _buildConfig(String provider, AiApiKey row) {
    final key = row.apiKey;
    final model = row.model;
    final baseUrl = row.baseUrl;

    switch (provider) {
      case 'siliconFlow':
        return SiliconFlowConfig(
          apiKey: key,
          model: model ?? 'THUDM/GLM-4-9B-0414',
          baseUrl: baseUrl ?? 'https://api.siliconflow.cn/v1',
        );
      case 'doubao':
        return DoubaoConfig(
          apiKey: key,
          model: model ?? 'doubao-1-5-lite-32k-250115',
          baseUrl: baseUrl ?? 'https://ark.cn-beijing.volces.com/api/v3',
        );
      case 'gemini':
        return GeminiConfig(
          apiKey: key,
          model: model ?? 'gemini-2.0-flash',
          baseUrl: baseUrl,
        );
      default:
        throw UnsupportedError('未知服务商: $provider');
    }
  }
}

final aiDatabaseProvider = Provider<AiDatabase>((ref) {
  return AiDatabase.instance;
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(aiDatabaseProvider));
});
