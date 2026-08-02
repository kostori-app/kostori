// lib/foundation/ai_service/ai_conversation_service.dart
//
// 统一的 AI 对话服务：上下文记忆 + 多模态 + 技能 + 压缩摘要 + MCP 工具

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/daos/ai_config_dao.dart';
import 'package:kostori/database/daos/ai_session_dao.dart';
import 'package:kostori/database/daos/ai_task_dao.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/ai_service/ai_factory.dart';
import 'package:kostori/foundation/ai_service/assistant_profile.dart';
import 'package:kostori/foundation/ai_service/role_management.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/skills/skill_registry.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 上下文总字符数超过该值时，自动压缩较早的历史消息
const _kAutoCompressChars = 40000;

// 辅助任务（上下文压缩 / 后续建议 / 自动标题）的模型配置 key。
// 空值表示跟随会话自身使用的服务商与模型。
const _kAuxCompressProvider = 'compressProvider';
const _kAuxCompressModel = 'compressModel';
const _kAuxFollowUpsProvider = 'followUpsProvider';
const _kAuxFollowUpsModel = 'followUpsModel';
const _kAuxTitleProvider = 'titleProvider';
const _kAuxTitleModel = 'titleModel';

/// 流式对话的进度更新（各文本字段为当前轮次累计值）
class AiChatUpdate {
  /// 当前已生成的回复文本
  final String text;

  /// 当前已生成的思考内容
  final String reasoning;

  /// 正在执行的工具名（无则 null）
  final String? toolStatus;

  /// 是否已完成（最终答案已落库）
  final bool done;

  /// 出错信息（出错时携带，流提前结束）
  final String? errorMessage;

  final AiUsage? usage;

  final String? modelName;

  const AiChatUpdate({
    this.text = '',
    this.reasoning = '',
    this.toolStatus,
    this.done = false,
    this.errorMessage,
    this.usage,
    this.modelName,
  });
}

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
    List<String> skillKeys = const [],
  }) async {
    final sessionId = _uuid.v4();
    await _sessionDao.upsertSession(
      AiSessionsCompanion.insert(
        sessionId: sessionId,
        type: type,
        provider: provider,
        title: Value(title),
        configKey: Value(configKey),
        skillKeys: Value(skillKeys.isEmpty ? null : jsonEncode(skillKeys)),
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

  Future<void> setSessionSkills(String sessionId, List<String> keys) =>
      _sessionDao.setSkillKeys(sessionId, keys);

  /// 持久化该会话的后续追问建议
  Future<void> setSessionFollowUps(String sessionId, List<String> items) =>
      _sessionDao.setFollowUps(sessionId, items);

  /// 启用中的技能
  Future<List<AiSkill>> getEnabledSkills() =>
      AiDatabase.instance.aiSkillDao.getEnabled();

  /// 会话已选技能 keys
  static List<String> parseSkillKeys(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      //
    }
    return const [];
  }

  /// 会话已生成的后续追问建议
  static List<String> parseFollowUps(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      //
    }
    return const [];
  }

  // ─── 发送消息（带上下文记忆）──────────────

  /// 向会话发送一条消息，自动携带历史上下文
  Future<Res<String>> sendMessage({
    required String sessionId,
    required String userMessage,
    List<AiImagePart>? images,
    String taskType = 'chat',
    int maxContextMessages = 20,
    String? providerOverride,
    bool useTools = true,
    void Function(String toolName)? onToolCall,
    void Function()? onAutoCompressed,
    String? systemPromptOverride,
  }) async {
    var session = await _sessionDao.getSession(sessionId);
    if (session == null) return Res.error('会话不存在: $sessionId');

    final provider = providerOverride ?? session.provider;
    final ai = AiFactory.create(provider);
    if (ai == null) return Res.error('未知服务商: $provider');

    // 1. 读取历史消息构建上下文
    var history = await _sessionDao.getMessages(sessionId);
    var contextMessages = history
        .where((m) => m.role == 'user' || m.role == 'model')
        .toList();
    final wasFirstMessage = contextMessages.isEmpty;

    // 1.5 上下文过长时自动压缩较早的消息
    final totalChars = contextMessages.fold<int>(
      0,
      (sum, m) =>
          sum +
          (m.role == 'user'
              ? m.inputContent.length
              : (m.outputContent?.length ?? 0)),
    );
    if (totalChars > _kAutoCompressChars) {
      final compressRes = await compressSession(
        sessionId,
        keepRecent: (maxContextMessages ~/ 2).clamp(4, 20),
      );
      if (compressRes.success) {
        onAutoCompressed?.call();
        final freshSession = await _sessionDao.getSession(sessionId);
        if (freshSession != null) session = freshSession;
        history = await _sessionDao.getMessages(sessionId);
        contextMessages = history
            .where((m) => m.role == 'user' || m.role == 'model')
            .toList();
      }
    }

    // 2. 组装 System Prompt（配置 + 技能 + 压缩摘要；关联助手档案时优先档案）
    final profile = await _resolveProfile(session);
    final systemPrompt =
        systemPromptOverride ??
        await _buildSystemPrompt(
          session,
          profile: profile,
          userMessage: userMessage,
        );

    // 3. 取最近 N 条（保证不超过上下文窗口）
    final trimmed = contextMessages.length > maxContextMessages
        ? contextMessages.sublist(contextMessages.length - maxContextMessages)
        : contextMessages;

    final messages = <AiMessage>[
      for (final m in trimmed)
        if (m.role == 'user')
          AiUserMessage(content: m.inputContent)
        else
          AiAssistantMessage(content: m.outputContent ?? ''),
      AiUserMessage(content: userMessage, parts: images),
    ];

    // 4. 记录用户消息
    await _taskDao.insert(
      AiTasksCompanion.insert(
        sessionId: sessionId,
        taskType: taskType,
        role: const Value('user'),
        inputContent: userMessage,
        provider: provider,
      ),
    );

    // 5. 调用 AI（支持 SkillRegistry 工具）
    if (useTools && profile != null && profile.enabledSkillIds.isNotEmpty) {
      SkillRegistry.instance.setEnabled(profile.enabledSkillIds);
    }
    final result = await _chat(
      ai,
      messages,
      systemPrompt: systemPrompt,
      session: session,
      useTools: useTools,
      onToolCall: onToolCall,
      params: _profileParams(profile),
      configOverride: await _configOverrideFor(ai, provider, profile),
    );

    // 6. 记录 AI 回复
    if (result.success) {
      final usage = result.subData is AiUsage
          ? result.subData as AiUsage
          : null;
      await _taskDao.insert(
        AiTasksCompanion.insert(
          sessionId: sessionId,
          taskType: taskType,
          role: const Value('model'),
          inputContent: userMessage,
          outputContent: Value(result.data),
          provider: provider,
          modelName: Value(usage?.modelName),
          tokenConsumed: Value(usage?.total ?? 0),
          thought: Value(usage == null ? null : jsonEncode(usage.toJson())),
        ),
      );
      // 更新会话时间
      await _sessionDao.touchSession(sessionId);
      // 首条消息时自动生成会话标题
      if (taskType == 'chat' && wasFirstMessage) {
        unawaited(_autoTitle(sessionId, provider, userMessage));
      }
    }

    return result;
  }

  /// 流式发送消息：逐段产出 [AiChatUpdate]，结束时落库并产出 [AiChatUpdate.done]。
  /// 通过 [cancelToken] 取消时静默结束（不落库、不视为错误）。
  Stream<AiChatUpdate> sendMessageStream({
    required String sessionId,
    required String userMessage,
    List<AiImagePart>? images,
    String taskType = 'chat',
    int maxContextMessages = 20,
    String? providerOverride,
    bool useTools = true,
    CancelToken? cancelToken,
    void Function()? onAutoCompressed,
    AiGenerationParams? paramsOverride,
  }) async* {
    var session = await _sessionDao.getSession(sessionId);
    if (session == null) {
      yield AiChatUpdate(errorMessage: '会话不存在: $sessionId');
      return;
    }

    final provider = providerOverride ?? session.provider;
    final ai = AiFactory.create(provider);
    if (ai == null) {
      yield AiChatUpdate(errorMessage: '未知服务商: $provider');
      return;
    }

    // 1. 读取历史消息构建上下文
    var history = await _sessionDao.getMessages(sessionId);
    var contextMessages = history
        .where((m) => m.role == 'user' || m.role == 'model')
        .toList();
    final wasFirstMessage = contextMessages.isEmpty;

    // 1.5 上下文过长时自动压缩较早的消息
    final totalChars = contextMessages.fold<int>(
      0,
      (sum, m) =>
          sum +
          (m.role == 'user'
              ? m.inputContent.length
              : (m.outputContent?.length ?? 0)),
    );
    if (totalChars > _kAutoCompressChars) {
      final compressRes = await compressSession(
        sessionId,
        keepRecent: (maxContextMessages ~/ 2).clamp(4, 20),
      );
      if (compressRes.success) {
        onAutoCompressed?.call();
        final freshSession = await _sessionDao.getSession(sessionId);
        if (freshSession != null) session = freshSession;
        history = await _sessionDao.getMessages(sessionId);
        contextMessages = history
            .where((m) => m.role == 'user' || m.role == 'model')
            .toList();
      }
    }

    // 2. 组装 System Prompt（配置 + 技能 + 压缩摘要；关联助手档案时优先档案）
    final profile = await _resolveProfile(session);
    final systemPrompt = await _buildSystemPrompt(
      session,
      profile: profile,
      userMessage: userMessage,
    );

    // 3. 取最近 N 条（保证不超过上下文窗口）
    final trimmed = contextMessages.length > maxContextMessages
        ? contextMessages.sublist(contextMessages.length - maxContextMessages)
        : contextMessages;

    var aiMessages = <AiMessage>[
      for (final m in trimmed)
        if (m.role == 'user')
          AiUserMessage(content: m.inputContent)
        else
          AiAssistantMessage(content: m.outputContent ?? ''),
      AiUserMessage(content: userMessage, parts: images),
    ];

    // 4. 记录用户消息
    await _taskDao.insert(
      AiTasksCompanion.insert(
        sessionId: sessionId,
        taskType: taskType,
        role: const Value('user'),
        inputContent: userMessage,
        provider: provider,
      ),
    );

    // 5. 工具能力（SkillRegistry 统一产出：内置技能 + MCP 适配器；
    //    会话关联助手档案时按其 enabledSkillIds 限定启用集合）
    var tools = <AiToolDefinition>[];
    AiToolHandler? toolHandler;
    if (useTools && ai.supportsStreamingTools) {
      final keyRow = await ai.getKeyRow();
      if (await ai.modelSupportsTools(keyRow?.model)) {
        if (profile != null && profile.enabledSkillIds.isNotEmpty) {
          SkillRegistry.instance.setEnabled(profile.enabledSkillIds);
        }
        final built = SkillRegistry.instance.buildTools();
        tools = built.tools;
        toolHandler = built.handler;
      }
    }
    final genParams = paramsOverride ?? _profileParams(profile);

    // 6. 多轮（工具调用）流式生成
    AiUsage? usage;
    final allText = StringBuffer();
    final allReasoning = StringBuffer();
    var finished = false;
    final startedAt = DateTime.now();
    final executedTools = <String>[];
    // 思考阶段计时：以首个推理分片为起点、推理内容停止增长为终点
    DateTime? thinkingStartedAt;
    DateTime? thinkingLastSeenAt;
    var prevReasoningLen = 0;

    for (var round = 0; round < 3 && !finished; round++) {
      var currentText = '';
      var currentReasoning = '';
      var roundToolCalls = <AiToolCall>[];
      var roundDone = false;

      try {
        await for (final chunk in ai.chatStream(
          aiMessages,
          systemPrompt: systemPrompt,
          tools: tools.isEmpty ? null : tools,
          params: genParams,
          cancelToken: cancelToken,
          configOverride: await _configOverrideFor(ai, provider, profile),
        )) {
          if (chunk.errorMessage != null) {
            yield AiChatUpdate(
              text: currentText,
              reasoning: currentReasoning,
              errorMessage: chunk.errorMessage,
            );
            return;
          }
          currentText = chunk.text;
          currentReasoning = chunk.reasoning;
          roundToolCalls = chunk.toolCalls;
          if (chunk.usage != null) usage = chunk.usage;
          roundDone = chunk.done;
          if (chunk.reasoning.length > prevReasoningLen) {
            prevReasoningLen = chunk.reasoning.length;
            thinkingStartedAt ??= DateTime.now();
            thinkingLastSeenAt = DateTime.now();
          }
          yield AiChatUpdate(
            text: currentText,
            reasoning: currentReasoning,
            toolStatus: roundToolCalls.isEmpty
                ? null
                : roundToolCalls.last.name,
          );
          if (chunk.done) break;
        }
      } catch (e) {
        // 用户主动停止：静默结束
        if (cancelToken?.isCancelled ?? false) return;
        yield AiChatUpdate(
          text: currentText,
          reasoning: currentReasoning,
          errorMessage: e.toString(),
        );
        return;
      }

      if (cancelToken?.isCancelled ?? false) return;

      if (!roundDone) {
        yield AiChatUpdate(
          text: currentText,
          reasoning: currentReasoning,
          errorMessage: '对话流意外中断',
        );
        return;
      }

      // 本轮的助手消息
      aiMessages = [
        ...aiMessages,
        AiAssistantMessage(
          content: currentText,
          toolCalls: roundToolCalls.isEmpty ? null : roundToolCalls,
        ),
      ];
      allText.write(currentText);
      allReasoning.write(currentReasoning);

      // 有工具调用：并行执行并继续下一轮
      if (roundToolCalls.isNotEmpty && toolHandler != null) {
        final handler = toolHandler;
        for (final tc in roundToolCalls) {
          executedTools.add(tc.name);
        }
        yield AiChatUpdate(
          text: currentText,
          reasoning: currentReasoning,
          toolStatus: roundToolCalls.length == 1
              ? roundToolCalls.first.name
              : '${roundToolCalls.length} 个工具',
        );
        final results = await Future.wait([
          for (final tc in roundToolCalls)
            () async {
              try {
                return await handler(tc.name, tc.arguments);
              } catch (e) {
                return '工具执行失败: $e';
              }
            }(),
        ]);
        for (var i = 0; i < roundToolCalls.length; i++) {
          aiMessages = [
            ...aiMessages,
            AiToolResultMessage(
              toolCallId: roundToolCalls[i].id,
              toolName: roundToolCalls[i].name,
              result: results[i],
            ),
          ];
        }
        continue;
      }

      finished = true;
    }

    if (cancelToken?.isCancelled ?? false) return;

    final modelName = usage?.modelName;
    final thought = <String, dynamic>{};
    if (allReasoning.isNotEmpty) thought['reasoning'] = allReasoning.toString();
    if (usage != null) thought['usage'] = usage.toJson();
    if (executedTools.isNotEmpty) thought['toolCalls'] = executedTools;
    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    if (durationMs > 0) thought['durationMs'] = durationMs;
    final thinkingStarted = thinkingStartedAt;
    final thinkingSeen = thinkingLastSeenAt;
    if (thinkingStarted != null && thinkingSeen != null) {
      final thinkingMs = thinkingSeen
          .difference(thinkingStarted)
          .inMilliseconds;
      if (thinkingMs > 0) thought['thinkingMs'] = thinkingMs;
    }

    // 7. 记录 AI 回复
    await _taskDao.insert(
      AiTasksCompanion.insert(
        sessionId: sessionId,
        taskType: taskType,
        role: const Value('model'),
        inputContent: userMessage,
        outputContent: Value(allText.toString()),
        provider: provider,
        modelName: Value(modelName),
        tokenConsumed: Value(usage?.total ?? 0),
        thought: Value(thought.isEmpty ? null : jsonEncode(thought)),
      ),
    );
    await _sessionDao.touchSession(sessionId);
    if (taskType == 'chat' && wasFirstMessage) {
      unawaited(_autoTitle(sessionId, provider, userMessage));
    }

    yield AiChatUpdate(
      text: allText.toString(),
      reasoning: allReasoning.toString(),
      done: true,
      usage: usage,
      modelName: modelName,
    );
  }

  Future<void> updateSessionProvider(String sessionId, String provider) async {
    await _sessionDao.updateOnlyProvider(sessionId, provider);
  }

  /// 关联/解绑会话的助手档案
  Future<void> updateSessionProfile(String sessionId, String? profileId) =>
      _sessionDao.setProfileId(sessionId, profileId);

  /// 删除 taskId 及其之后的所有消息，用于回滚到某个节点重新发送
  Future<void> rollbackToMessage(String sessionId, int taskId) =>
      _taskDao.deleteMessagesFrom(sessionId, taskId);

  // ─── 压缩 ─────────────────────────────────

  /// 将较早的历史消息压缩为摘要并写入会话，保留最近 [keepRecent] 条
  Future<Res<String>> compressSession(
    String sessionId, {
    int keepRecent = 10,
  }) async {
    final session = await _sessionDao.getSession(sessionId);
    if (session == null) return Res.error('会话不存在: $sessionId');
    final aux = await _loadAuxConfig('compress');
    final provider = aux.provider.isEmpty ? session.provider : aux.provider;
    final ai = AiFactory.create(provider);
    if (ai == null) return Res.error('未知服务商: $provider');

    final history = await _sessionDao.getMessages(sessionId);
    final contextMessages = history
        .where((m) => m.role == 'user' || m.role == 'model')
        .toList();
    final keep = contextMessages.length > keepRecent
        ? contextMessages.length - keepRecent
        : 0;
    if (keep <= 0) return Res.error('历史消息太少，无需压缩');

    final older = contextMessages.take(keep).toList();
    final conversationText = older
        .map(
          (m) =>
              '${m.role == 'user' ? '用户' : '助手'}：'
              '${m.role == 'user' ? m.inputContent : (m.outputContent ?? '')}',
        )
        .join('\n\n');

    final prompt =
        '请将下面这段多轮对话压缩成一段简明中文摘要，'
        '保留重要信息、事实与结论，方便后续继续对话时引用：\n\n$conversationText';
    final result = await ai.generate(
      prompt,
      systemPrompt: '你是高效的对话压缩助手，只输出摘要本身。',
      modelOverride: aux.model,
      params: _auxParams(aux.temperature),
    );
    if (!result.success) return result;

    await _sessionDao.setCompressedContent(sessionId, result.data);
    // 删除已压缩的旧消息（保留最近 keepRecent 条）
    if (older.isNotEmpty) {
      await _taskDao.deleteMessagesTo(sessionId, older.last.id);
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
    String? systemPrompt,
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
      systemPromptOverride: systemPrompt,
    );
  }

  // ─── 后续建议 ──────────────────────────────

  /// 根据最近对话生成若干条后续追问建议（失败时返回空列表）
  ///
  /// 若最后一次助手回复发生了工具调用，则直接返回空列表（不打扰用户）。
  Future<List<String>> suggestFollowUps(
    String sessionId, {
    int count = 5,
  }) async {
    final session = await _sessionDao.getSession(sessionId);
    if (session == null) return const [];
    final history = await _sessionDao.getMessages(sessionId);

    // 最后一次助手回复若包含工具调用，则不生成追问建议
    AiTask? lastModel;
    for (final m in history.reversed) {
      if (m.role == 'model') {
        lastModel = m;
        break;
      }
    }
    if (lastModel == null) return const [];
    // 修订 1.3：仅当本轮回复为工具调用结果 / 非自然语言（无文本内容）时隐藏建议；
    // 正常自然语言回复（即使过程使用了工具）一律展示。
    final content = lastModel.outputContent?.trim() ?? '';
    if (content.isEmpty) return const [];

    final aux = await _loadAuxConfig('followUps');
    final provider = aux.provider.isEmpty ? session.provider : aux.provider;
    final ai = AiFactory.create(provider);
    if (ai == null) return const [];

    final contextMessages = history
        .where((m) => m.role == 'user' || m.role == 'model')
        .toList();
    if (contextMessages.length < 2) return const [];

    final start = contextMessages.length - 6;
    final recent = start <= 0
        ? contextMessages
        : contextMessages.sublist(start);
    final text = recent
        .map(
          (m) =>
              '${m.role == 'user' ? '用户' : '助手'}：'
              '${m.role == 'user' ? m.inputContent : (m.outputContent ?? '')}',
        )
        .join('\n\n');
    final prompt =
        '根据下面这段对话，为用户生成 $count 条简短自然的后续追问'
        '或引导继续对话的建议（每条不超过15个字，不要编号和引号）。'
        '只输出 JSON 字符串数组，例如：["建议一","建议二","建议三"]。\n\n$text';
    final result = await ai.generate(
      prompt,
      systemPrompt: '你是对话引导助手，只输出 JSON 数组。',
      modelOverride: aux.model,
      params: _auxParams(aux.temperature),
    );
    if (!result.success) return const [];
    try {
      final decoded = jsonDecode(result.data);
      if (decoded is List) {
        return decoded
            .take(count)
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => s.length > 15 ? s.substring(0, 15) : s)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  // ─── 私有 ─────────────────────────────────

  /// 读取辅助任务的模型配置；未配置时返回空 provider（表示跟随会话）
  Future<({String provider, String? model, double? temperature})>
  _loadAuxConfig(String taskKey) async {
    final (providerKey, modelKey, tempKey) = switch (taskKey) {
      'compress' => (
        _kAuxCompressProvider,
        _kAuxCompressModel,
        'compressTemperature',
      ),
      'followUps' => (
        _kAuxFollowUpsProvider,
        _kAuxFollowUpsModel,
        'followUpsTemperature',
      ),
      'title' => (_kAuxTitleProvider, _kAuxTitleModel, 'titleTemperature'),
      _ => ('${taskKey}Provider', '${taskKey}Model', '${taskKey}Temperature'),
    };
    final dao = AiDatabase.instance.aiAuxSettingsDao;
    final provider = await dao.get(providerKey);
    final model = await dao.get(modelKey);
    final temp = await dao.get(tempKey);
    return (
      provider: (provider == null || provider.isEmpty) ? '' : provider,
      model: (model == null || model.isEmpty) ? null : model,
      temperature: temp == null ? null : double.tryParse(temp),
    );
  }

  /// 用 AI 根据首条用户消息生成会话标题
  Future<void> _autoTitle(
    String sessionId,
    String provider,
    String userMessage,
  ) async {
    final aux = await _loadAuxConfig('title');
    final p = aux.provider.isEmpty ? provider : aux.provider;
    final ai = AiFactory.create(p);
    if (ai == null) return;
    final prompt =
        '根据下面这条用户消息，为这段对话生成一个简短标题，'
        '不超过15个字，直接输出标题本身，不要加引号、冒号或编号：\n$userMessage';
    final result = await ai.generate(
      prompt,
      systemPrompt: '你是标题生成助手，只输出标题本身。',
      modelOverride: aux.model,
      params: _auxParams(aux.temperature),
    );
    if (!result.success) return;
    final title = result.data
        .trim()
        .replaceAll(RegExp(r'["“”\n\t]'), '')
        .trim();
    if (title.isEmpty || title.length > 40) return;
    await _sessionDao.renameSession(sessionId, title);
  }

  /// 解析会话关联的助手档案；未关联或档案不存在时返回 null
  Future<AssistantProfile?> _resolveProfile(AiSession session) async {
    final profileId = session.profileId;
    if (profileId == null || profileId.isEmpty) return null;
    final store = AssistantProfileStore.instance;
    if (!store.isInitialized) await store.init();
    return store.find(profileId);
  }

  /// 按技能 key 列表解析名称（改造点 7 扩展技能库）
  Future<List<String>> _skillNamesFor(List<String> keys) async {
    if (keys.isEmpty) return const [];
    final skills = await AiDatabase.instance.aiSkillDao.getAll();
    final byKey = {for (final s in skills) s.key: s};
    return [
      for (final key in keys)
        if (byKey[key] != null) byKey[key]!.name,
    ];
  }

  /// 辅助任务的温度参数（未配置时返回 null 跟随默认）
  static AiGenerationParams? _auxParams(double? temperature) =>
      temperature == null ? null : AiGenerationParams(temperature: temperature);

  /// 按助手档案的自定义请求设定（⑤）构建配置覆盖；
  /// 无覆盖或非 OpenAI 兼容服务商时返回 null。
  Future<AiProviderConfig?> _configOverrideFor(
    AiBase ai,
    String provider,
    AssistantProfile? profile,
  ) async {
    final req = profile?.request;
    if (req == null ||
        (req.baseUrlOverride == null &&
            req.apiKeyOverride == null &&
            req.customHeaders.isEmpty &&
            req.extraBodyFields.isEmpty &&
            req.stopSequences.isEmpty)) {
      return null;
    }
    final keyRow = await AiDatabase.instance.aiApiKeyDao.getByProvider(
      provider,
    );
    if (keyRow == null || !keyRow.isEnabled) return null;
    final cfg = ai.buildConfig(keyRow);
    if (cfg is OpenAiCompatibleConfig) {
      return cfg.withRequestOverrides(
        baseUrlOverride: req.baseUrlOverride,
        apiKeyOverride: req.apiKeyOverride,
        customHeaders: req.customHeaders,
        extraBodyFields: req.extraBodyFields,
        stopSequences: req.stopSequences,
      );
    }
    return null;
  }

  /// 将档案的生成参数转换为 [AiGenerationParams]（全空时返回 null 跟随默认）
  static AiGenerationParams? _profileParams(AssistantProfile? profile) {
    final p = profile?.params;
    if (p == null) return null;
    if (p.temperature == null && p.topP == null && p.maxTokens == null) {
      return null;
    }
    return AiGenerationParams(
      temperature: p.temperature,
      topP: p.topP,
      maxTokens: p.maxTokens,
    );
  }

  Future<String?> _buildSystemPrompt(
    AiSession session, {
    AssistantProfile? profile,
    String? userMessage,
  }) async {
    final injections = await PromptInjectionStore.instance.enabledSorted();
    final worldHits = (userMessage == null || userMessage.trim().isEmpty)
        ? const <WorldBookEntry>[]
        : await WorldBookStore.instance.hits(userMessage);
    final memoryEntries = profile == null
        ? const <String>[]
        : await AssistantMemoryStore.instance.entriesFor(profile.id);
    final parts = <String>[];
    if (profile != null) {
      // 绑定的扩展技能（改造点 7）名称并入工具清单
      final boundSkillNames = profile.skillIds.isEmpty
          ? const <String>[]
          : await _skillNamesFor(profile.skillIds);
      parts.add(
        buildSystemPrompt(
          profile: profile,
          userMessage: userMessage,
          availableSkills: [
            ...SkillRegistry.instance.enabled.map((s) => s.name),
            ...boundSkillNames,
          ],
          injections: injections,
          worldBookHits: worldHits,
          memoryEntries: memoryEntries,
        ),
      );
    } else {
      if (session.configKey != null) {
        final cfg = await _configDao.getByKey(session.configKey!);
        if (cfg != null && cfg.systemPrompt.isNotEmpty) {
          parts.add(cfg.systemPrompt);
        }
      }
      final skillKeys = parseSkillKeys(session.skillKeys);
      if (skillKeys.isNotEmpty) {
        final skills = await AiDatabase.instance.aiSkillDao.getEnabled();
        final byKey = {for (final s in skills) s.key: s};
        for (final key in skillKeys) {
          final skill = byKey[key];
          if (skill != null && skill.systemPrompt.isNotEmpty) {
            parts.add('【技能：${skill.name}】\n${skill.systemPrompt}');
          }
        }
      }
      // 全局角色注入（提示词注入 + 世界书）同样作用于无档案会话
      for (final inj in injections) {
        if (inj.content.trim().isNotEmpty) {
          parts.add('【提示词注入 · ${inj.name.trim()}】\n${inj.content.trim()}');
        }
      }
      if (worldHits.isNotEmpty) {
        final buf = StringBuffer('【世界书】');
        var seq = 0;
        for (final e in worldHits) {
          if (e.content.trim().isEmpty) continue;
          seq++;
          buf.write('\n$seq. ${e.content.trim()}');
        }
        if (seq > 0) parts.add(buf.toString());
      }
    }
    if (session.compressedContent != null &&
        session.compressedContent!.isNotEmpty) {
      parts.add('【历史对话摘要】\n${session.compressedContent}');
    }
    return parts.isEmpty ? null : parts.join('\n\n');
  }

  Future<Res<String>> _chat(
    AiBase ai,
    List<AiMessage> messages, {
    String? systemPrompt,
    required AiSession session,
    required bool useTools,
    void Function(String toolName)? onToolCall,
    AiGenerationParams? params,
    AiProviderConfig? configOverride,
  }) async {
    if (!useTools) {
      return ai.chat(
        messages,
        systemPrompt: systemPrompt,
        params: params,
        configOverride: configOverride,
      );
    }
    final keyRow = await ai.getKeyRow();
    if (!await ai.modelSupportsTools(keyRow?.model)) {
      return ai.chat(
        messages,
        systemPrompt: systemPrompt,
        params: params,
        configOverride: configOverride,
      );
    }
    final built = SkillRegistry.instance.buildTools();
    if (built.tools.isEmpty) {
      return ai.chat(
        messages,
        systemPrompt: systemPrompt,
        params: params,
        configOverride: configOverride,
      );
    }
    return ai.chatWithTools(
      messages: messages,
      systemPrompt: systemPrompt,
      tools: built.tools,
      onToolCall: (name, arguments) {
        onToolCall?.call(name);
        return built.handler(name, arguments);
      },
      params: params,
      configOverride: configOverride,
    );
  }
}
