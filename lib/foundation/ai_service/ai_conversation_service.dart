// lib/foundation/ai_conversation_service.dart
//
// 统一的 AI 对话服务：上下文记忆 + 任务/会话统一管理

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/daos/ai_config_dao.dart';
import 'package:kostori/database/daos/ai_session_dao.dart';
import 'package:kostori/database/daos/ai_task_dao.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_factory.dart';
import 'package:kostori/foundation/res.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class AiConversationService {
  static final AiConversationService _instance =
      AiConversationService._internal();

  factory AiConversationService() => _instance;

  AiConversationService._internal();

  AiSessionDao get _sessionDao => AiDatabase.instance.aiSessionDao;

  AiTaskDao get _taskDao => AiDatabase.instance.aiTaskDao;

  AiConfigDao get _configDao => AiDatabase.instance.aiConfigDao;

  // ─── 会话管理 ──────────────────────────────

  /// 创建新会话，返回 sessionId
  Future<String> createSession({
    required String type,
    required String provider,
    String title = '新对话',
    String? configKey,
  }) async {
    final sessionId = _uuid.v4();
    await _sessionDao.upsertSession(
      AiSessionsCompanion.insert(
        sessionId: sessionId,
        type: type,
        provider: provider,
        title: Value(title),
        configKey: Value(configKey),
      ),
    );
    return sessionId;
  }

  Stream<List<AiSession>> watchSessions({String? type}) => type != null
      ? _sessionDao.watchSessionsByType(type)
      : _sessionDao.watchAllSessions();

  Stream<List<AiTask>> watchMessages(String sessionId) =>
      _sessionDao.watchMessages(sessionId);

  Future<void> deleteSession(String sessionId) =>
      _sessionDao.deleteSession(sessionId);

  Future<void> renameSession(String sessionId, String title) =>
      _sessionDao.renameSession(sessionId, title);

  // ─── 发送消息（带上下文记忆）──────────────

  /// 向会话发送一条消息，自动携带历史上下文
  Future<Res<String>> sendMessage({
    required String sessionId,
    required String userMessage,
    String taskType = 'chat',
    int maxContextMessages = 20, // 最多携带最近 N 条历史
  }) async {
    final session = await _sessionDao.getSession(sessionId);
    if (session == null) return Res.error('会话不存在: $sessionId');

    final ai = AiFactory.create(session.provider);
    if (ai == null) return Res.error('未知服务商: ${session.provider}');

    // 1. 读取 System Prompt
    String? systemPrompt;
    if (session.configKey != null) {
      final cfg = await _configDao.getByKey(session.configKey!);
      systemPrompt = cfg?.systemPrompt;
    }

    // 2. 读取历史消息构建上下文
    final history = await _sessionDao.getMessages(sessionId);
    final contextMessages = history
        .where((m) => m.role == 'user' || m.role == 'model')
        .toList();

    // 取最近 N 条（保证不超过上下文窗口）
    final trimmed = contextMessages.length > maxContextMessages
        ? contextMessages.sublist(contextMessages.length - maxContextMessages)
        : contextMessages;

    final messages = <AiMessage>[
      for (final m in trimmed)
        if (m.role == 'user')
          AiUserMessage(content: m.inputContent)
        else
          AiAssistantMessage(content: m.outputContent ?? ''),
      AiUserMessage(content: userMessage),
    ];

    // 3. 记录用户消息
    await _taskDao.insert(
      AiTasksCompanion.insert(
        sessionId: sessionId,
        taskType: taskType,
        role: const Value('user'),
        inputContent: userMessage,
        provider: session.provider,
      ),
    );

    // 4. 调用 AI
    final result = await ai.chat(messages, systemPrompt: systemPrompt);

    // 5. 记录 AI 回复
    if (result.success) {
      await _taskDao.insert(
        AiTasksCompanion.insert(
          sessionId: sessionId,
          taskType: taskType,
          role: const Value('model'),
          inputContent: userMessage,
          outputContent: Value(result.data),
          provider: session.provider,
        ),
      );
      // 更新会话时间
      await _sessionDao.touchSession(sessionId);
    }

    return result;
  }

  // ─── 单次任务（无上下文，自动创建临时会话）─

  /// 翻译、侧写等一次性任务
  Future<Res<String>> runTask({
    required String provider,
    required String taskType,
    required String prompt,
    String? configKey,
    String? sessionTitle,
  }) async {
    final sessionId = await createSession(
      type: taskType,
      provider: provider,
      title: sessionTitle ?? taskType,
      configKey: configKey,
    );
    return sendMessage(
      sessionId: sessionId,
      userMessage: prompt,
      taskType: taskType,
      maxContextMessages: 0,
    );
  }
}
