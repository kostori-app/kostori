import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/daos/ai_api_key_dao.dart';
import 'package:kostori/database/daos/ai_config_dao.dart';
import 'package:kostori/database/daos/ai_provider_stats_dao.dart';
import 'package:kostori/database/daos/ai_task_dao.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_conversation_service.dart';
import 'package:kostori/foundation/res.dart';

class AiRepository {
  final AiDatabase _db;

  AiRepository(this._db);

  AiApiKeyDao get _keyDao => _db.aiApiKeyDao;

  AiTaskDao get _taskDao => _db.aiTaskDao;

  AiConfigDao get _configDao => _db.aiConfigDao;

  AiProviderStatsDao get _statsDao => _db.aiProviderStatsDao;

  // ─── API Key ───────────────────────────────

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

  // ─── 会话管理（委托给 AiConversationService）──

  Future<String> createSession({
    required String type,
    required String provider,
    String title = '新对话',
    String? configKey,
  }) => AiConversationService().createSession(
    type: type,
    provider: provider,
    title: title,
    configKey: configKey,
  );

  Stream<List<AiSession>> watchSessions({String? type}) =>
      AiConversationService().watchSessions(type: type);

  Stream<List<AiTask>> watchMessages(String sessionId) =>
      AiConversationService().watchMessages(sessionId);

  Future<void> deleteSession(String sessionId) =>
      AiConversationService().deleteSession(sessionId);

  Future<void> renameSession(String sessionId, String title) =>
      AiConversationService().renameSession(sessionId, title);

  // ─── AI 调用 ───────────────────────────────

  /// 带上下文记忆的多轮对话（推荐）
  Future<Res<String>> sendMessage({
    required String sessionId,
    required String userMessage,
    String taskType = 'chat',
    int maxContextMessages = 20,
  }) => AiConversationService().sendMessage(
    sessionId: sessionId,
    userMessage: userMessage,
    taskType: taskType,
    maxContextMessages: maxContextMessages,
  );

  /// 一次性任务（无上下文）
  Future<Res<String>> runTask({
    required String provider,
    required String taskType,
    required String prompt,
    String? configKey,
    String? sessionTitle,
  }) => AiConversationService().runTask(
    provider: provider,
    taskType: taskType,
    prompt: prompt,
    configKey: configKey,
    sessionTitle: sessionTitle,
  );

  /// 兼容旧调用：直接 chat（自动创建临时会话）
  Future<Res<String>> chat({
    required String provider,
    required List<AiMessage> messages,
    String? configKey,
    String? taskType,
  }) async {
    final sessionId = await createSession(
      type: taskType ?? 'chat',
      provider: provider,
      configKey: configKey,
    );
    // 把消息列表转成单次调用（取最后一条 user 消息）
    final lastUser = messages.lastWhere(
      (m) => m.role == 'user',
      orElse: () => messages.last,
    );
    return sendMessage(
      sessionId: sessionId,
      userMessage: lastUser.content,
      taskType: taskType ?? 'chat',
      maxContextMessages: 0,
    );
  }

  Future<Res<String>> generate({
    required String provider,
    required String prompt,
    String? configKey,
    String? taskType,
  }) => runTask(
    provider: provider,
    taskType: taskType ?? 'generate',
    prompt: prompt,
    configKey: configKey,
  );

  // ─── AiConfigs ─────────────────────────────

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

  Future<void> updateSystemPrompt(String key, String prompt) =>
      _configDao.upsert(
        AiConfigsCompanion(configKey: Value(key), systemPrompt: Value(prompt)),
      );

  Future<void> deleteConfig(String key) => _configDao.deleteByKey(key);

  // ─── AiTasks ───────────────────────────────

  Stream<List<AiTask>> watchAllTasks() => _taskDao.watchAll();

  Stream<List<AiTask>> watchTasksByType(String taskType) =>
      _taskDao.watchByType(taskType);

  Future<void> deleteTask(int id) => _taskDao.deleteById(id);

  Future<void> clearTasksByType(String taskType) =>
      _taskDao.deleteByType(taskType);

  // ─── AiProviderStats ───────────────────────

  Stream<List<AiProviderStat>> watchAllStats() => _statsDao.watchAll();

  Future<AiProviderStat?> getStats(String provider) =>
      _statsDao.getByProvider(provider);

  Future<bool> validateKey(String provider) async {
    final result = await generate(provider: provider, prompt: 'Hello');
    await _statsDao.updateValidity(provider, isValid: result.success);
    return result.success;
  }

  Future<void> resetCallCount(String provider) =>
      _statsDao.resetCalls(provider);
}

// ─── Riverpod ──────────────────────────────

final aiDatabaseProvider = Provider<AiDatabase>((ref) => AiDatabase.instance);

final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => AiRepository(ref.watch(aiDatabaseProvider)),
);

// 会话流 Providers
final aiSessionsProvider = StreamProvider.family<List<AiSession>, String?>(
  (ref, type) => ref.watch(aiRepositoryProvider).watchSessions(type: type),
);

final aiMessagesProvider = StreamProvider.family<List<AiTask>, String>(
  (ref, sessionId) => ref.watch(aiRepositoryProvider).watchMessages(sessionId),
);
