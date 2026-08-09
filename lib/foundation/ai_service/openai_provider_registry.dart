import 'dart:convert';

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/ai_service/balance_helper.dart';
import 'package:kostori/foundation/ai_service/claude_responses_ai.dart';
import 'package:kostori/foundation/ai_service/gemini_ai.dart';
import 'package:kostori/foundation/ai_service/openrouter_ai.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

// ─── 注册表：新增内置服务商只改这里 ───────────────────
// 自定义服务商从数据库 AiCustomProviders 动态加载，合并进 allProviders。

typedef ProviderMeta = ({
  String name,
  String defaultModel,
  String baseUrl,
  bool isCustom,
  bool supportsVision,
  bool supportsTools,
  String apiFormat,
});

class OpenAiProviderRegistry {
  static const _builtinProviders =
      <String, ({String name, String defaultModel, String baseUrl})>{
        'siliconFlow': (
          name: 'SiliconFlow',
          defaultModel: 'THUDM/GLM-4-9B-0414',
          baseUrl: 'https://api.siliconflow.cn/v1',
        ),
        'doubao': (
          name: 'Doubao',
          defaultModel: 'doubao-1-5-lite-32k-250115',
          baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
        ),
        'deepseek': (
          name: 'DeepSeek',
          defaultModel: 'deepseek-chat',
          baseUrl: 'https://api.deepseek.com',
        ),
        'qiniu': (
          name: '七牛云',
          defaultModel: 'deepseek/deepseek-v3.2-251201',
          baseUrl: 'https://api.qnaigc.com/v1',
        ),
        'ohmygpt': (
          name: 'OhMyGPT',
          defaultModel: 'gpt-4o',
          baseUrl: 'https://c-z0-api-01.hash070.com/v1',
        ),
        'gemini': (
          name: 'Gemini',
          defaultModel: 'gemini-2.0-flash',
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        ),
        'openrouter': (
          name: 'OpenRouter',
          defaultModel: 'nvidia/nemotron-3-super-120b-a12b:free',
          baseUrl: 'https://openrouter.ai/api/v1',
        ),
      };

  static Map<String, ProviderMeta> _allProviders = {
    for (final e in _builtinProviders.entries)
      e.key: (
        name: e.value.name,
        defaultModel: e.value.defaultModel,
        baseUrl: e.value.baseUrl,
        isCustom: false,
        supportsVision: true,
        supportsTools: true,
        apiFormat: 'openai',
      ),
  };

  /// 内置 + 已启用自定义服务商的合并表（创建自定义服务商后需调用 [refreshCustomProviders]）
  static Map<String, ProviderMeta> get allProviders => _allProviders;

  /// 自定义服务商的 source key：`custom_<provider>`
  static String customSourceKey(String provider) => 'custom_$provider';

  /// 从 source key 反解出自定义服务商的 provider 字段
  static String customProviderOf(String source) => source.startsWith('custom_')
      ? source.substring('custom_'.length)
      : source;

  static bool isCustomSource(String source) => source.startsWith('custom_');

  /// 从数据库加载启用的自定义服务商并合并进缓存
  static Future<void> refreshCustomProviders() async {
    final customs = await AiDatabase.instance.aiCustomProviderDao.getEnabled();
    final next = <String, ProviderMeta>{
      for (final e in _allProviders.entries)
        if (!e.value.isCustom) e.key: e.value,
    };
    for (final c in customs) {
      next[customSourceKey(c.provider)] = (
        name: c.name,
        defaultModel: c.defaultModel ?? '',
        baseUrl: c.baseUrl,
        isCustom: true,
        supportsVision: true,
        supportsTools: true,
        apiFormat: c.apiFormat ?? 'openai',
      );
    }
    _allProviders = next;
  }

  static bool contains(String source) => _allProviders.containsKey(source);

  /// 内置服务商的接口格式缓存（从 AiApiKeys 读取，启动/保存 Key 后刷新）
  static final Map<String, String> _keyApiFormats = {};

  static Future<void> refreshKeyFormats() async {
    _keyApiFormats.clear();
    final keys = await AiDatabase.instance.aiApiKeyDao.getAll();
    for (final k in keys) {
      _keyApiFormats[k.provider] = k.apiFormat ?? 'openai';
    }
  }

  static AiBase? createAi(String source) {
    final meta = _allProviders[source];
    if (meta == null) return null;
    if (source == 'gemini') return GeminiAi();
    if (source == 'openrouter') return OpenRouterAi();
    if (source == 'openai_responses') {
      return ResponsesAi(
        providerKey: source,
        sourceName: meta.name,
        defaultModel: meta.defaultModel,
        defaultBaseUrl: meta.baseUrl,
      );
    }
    if (meta.isCustom) {
      return switch (meta.apiFormat) {
        'gemini' => GeminiAi(
          providerKey: source,
          sourceName: meta.name,
          defaultModel: meta.defaultModel,
          defaultBaseUrl: meta.baseUrl,
        ),
        'claude' => ClaudeAi(
          providerKey: source,
          sourceName: meta.name,
          defaultModel: meta.defaultModel,
          defaultBaseUrl: meta.baseUrl,
        ),
        'openai_responses' => ResponsesAi(
          providerKey: source,
          sourceName: meta.name,
          defaultModel: meta.defaultModel,
          defaultBaseUrl: meta.baseUrl,
        ),
        _ => CustomProviderAi(
          providerKey: source,
          sourceName: meta.name,
          defaultModel: meta.defaultModel,
          defaultBaseUrl: meta.baseUrl,
          supportsVision: meta.supportsVision,
          supportsTools: meta.supportsTools,
        ),
      };
    }
    // 内置 OpenAI 服务商也可在 Key 编辑页选择接口格式
    return switch (_keyApiFormats[source] ?? 'openai') {
      'gemini' => GeminiAi(
        providerKey: source,
        sourceName: meta.name,
        defaultModel: meta.defaultModel,
        defaultBaseUrl: meta.baseUrl,
      ),
      'claude' => ClaudeAi(
        providerKey: source,
        sourceName: meta.name,
        defaultModel: meta.defaultModel,
        defaultBaseUrl: meta.baseUrl,
      ),
      'openai_responses' => ResponsesAi(
        providerKey: source,
        sourceName: meta.name,
        defaultModel: meta.defaultModel,
        defaultBaseUrl: meta.baseUrl,
      ),
      _ => OpenAiCompatibleAi(
        providerKey: source,
        sourceName: meta.name,
        defaultModel: meta.defaultModel,
        defaultBaseUrl: meta.baseUrl,
      ),
    };
  }
}

// ─── 通用实现 ──────────────────────────────────────

class OpenAiCompatibleAi extends AiBase {
  @override
  final String providerKey;
  @override
  final String sourceName;

  final String defaultModel;
  final String defaultBaseUrl;
  final bool _supportsVision;
  final bool _supportsTools;

  OpenAiCompatibleAi({
    required this.providerKey,
    required this.sourceName,
    required this.defaultModel,
    required this.defaultBaseUrl,
    bool supportsVision = true,
    bool supportsTools = true,
  }) : _supportsVision = supportsVision,
       _supportsTools = supportsTools;

  @override
  bool get supportsVision => _supportsVision;

  @override
  bool get supportsTools => _supportsTools;

  @override
  AiProviderConfig buildConfig(AiApiKey row, {String? modelOverride}) =>
      OpenAiCompatibleConfig(
        source: providerKey,
        apiKey: row.apiKey,
        model: modelOverride ?? row.model ?? defaultModel,
        baseUrl: row.baseUrl ?? defaultBaseUrl,
      );

  @override
  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    required AiProviderConfig config,
    String? systemPrompt,
    List<AiToolDefinition>? tools,
    AiGenerationParams? params,
  }) {
    final oc = config is OpenAiCompatibleConfig ? config : null;
    return {
      'model': config.model,
      'messages': [
        if (systemPrompt != null && systemPrompt.isNotEmpty)
          AiSystemMessage(content: systemPrompt).toJson(),
        ...messages.map((m) => m.toJson()),
      ],
      if (params != null && params.temperature != null)
        'temperature': params.temperature,
      if (params != null && params.topP != null) 'top_p': params.topP,
      if (params != null && params.maxTokens != null)
        'max_tokens': params.maxTokens,
      if (oc != null && oc.stopSequences.isNotEmpty) 'stop': oc.stopSequences,
      if (tools != null && tools.isNotEmpty)
        'tools': tools.map((t) => t.toJson()).toList(),
      if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
      if (oc != null) ...oc.extraBodyFields,
    };
  }

  /// 解析 OpenAI 兼容响应的 usage 统计
  static AiUsage? _parseUsage(Map<String, dynamic> json, String modelName) {
    final usage = json['usage'];
    if (usage is! Map<String, dynamic>) return null;
    final prompt = (usage['prompt_tokens'] as num?)?.toInt();
    final completion = (usage['completion_tokens'] as num?)?.toInt();
    if (prompt == null && completion == null) return null;
    final details = usage['prompt_tokens_details'];
    final cached = details is Map<String, dynamic>
        ? (details['cached_tokens'] as num?)?.toInt()
        : null;
    return AiUsage(
      promptTokens: prompt,
      completionTokens: completion,
      cachedTokens: cached,
      modelName: modelName,
    );
  }

  /// 从 OpenAI 响应中解析带工具调用的助手消息；无工具调用时返回 null。
  AiAssistantMessage? _assistantMessage(dynamic messageJson) {
    final toolCallsJson = messageJson['tool_calls'];
    if (toolCallsJson == null || (toolCallsJson as List).isEmpty) {
      return null;
    }
    return AiAssistantMessage(
      content: messageJson['content']?.toString() ?? '',
      toolCalls: [
        for (final tc in toolCallsJson)
          AiToolCall(
            id: tc['id'] as String,
            name: tc['function']['name'] as String,
            arguments: tc['function']['arguments'] is String
                ? (jsonDecode(tc['function']['arguments'] as String)
                      as Map<String, dynamic>)
                : (tc['function']['arguments'] as Map<String, dynamic>),
          ),
      ],
    );
  }

  @override
  Future<Res<String>> chatWithTools({
    required List<AiMessage> messages,
    String? systemPrompt,
    List<AiToolDefinition>? tools,
    AiToolHandler? onToolCall,
    String? modelOverride,
    AiGenerationParams? params,
    AiProviderConfig? configOverride,
  }) async {
    if (tools == null || tools.isEmpty || onToolCall == null) {
      return chat(
        messages,
        systemPrompt: systemPrompt,
        modelOverride: modelOverride,
        params: params,
        configOverride: configOverride,
      );
    }
    try {
      final keyRow = await getKeyRow();
      if (keyRow == null || !keyRow.isEnabled) {
        return Res.error('$sourceName API Key 未配置或已禁用');
      }
      final config =
          configOverride ?? buildConfig(keyRow, modelOverride: modelOverride);
      var history = [...messages];
      for (var round = 0; round < 3; round++) {
        final response = await AppDio().request(
          buildUrl(config),
          data: buildRequest(
            history,
            config: config,
            systemPrompt: systemPrompt,
            tools: tools,
            params: params,
          ),
          options: Options(
            method: 'POST',
            headers: buildHeaders(config),
            receiveTimeout: const Duration(minutes: 3),
          ),
        );
        final json = response.data as Map<String, dynamic>;
        final choices = json['choices'] as List;
        final message = choices.first['message'] as Map<String, dynamic>;
        final assistant = _assistantMessage(message);
        if (assistant == null) {
          return Res(
            message['content']?.toString() ?? '',
            subData: _parseUsage(json, config.model),
          );
        }
        history = [...history, assistant];
        for (final tc in assistant.toolCalls!) {
          String result;
          try {
            result = await onToolCall(tc.name, tc.arguments);
          } catch (e) {
            result = '工具执行失败: $e';
          }
          history = [
            ...history,
            AiToolResultMessage(
              toolCallId: tc.id,
              toolName: tc.name,
              result: result,
            ),
          ];
        }
      }
      return Res.error('$sourceName 工具调用轮次过多');
    } catch (e) {
      return Res.error(aiErrorMessageOf(e));
    }
  }

  @override
  Stream<AiStreamChunk> chatStream(
    List<AiMessage> messages, {
    String? systemPrompt,
    List<AiToolDefinition>? tools,
    CancelToken? cancelToken,
    String? modelOverride,
    AiGenerationParams? params,
    AiProviderConfig? configOverride,
  }) async* {
    AiUsage? usage;
    try {
      final keyRow = await getKeyRow();
      if (keyRow == null || !keyRow.isEnabled) {
        yield AiStreamChunk(errorMessage: '$sourceName API Key 未配置或已禁用');
        return;
      }
      final config =
          configOverride ?? buildConfig(keyRow, modelOverride: modelOverride);
      final response = await AppDio().request(
        buildUrl(config),
        data: buildRequest(
          messages,
          config: config,
          systemPrompt: systemPrompt,
          tools: tools,
          params: params,
        )..['stream'] = true,
        cancelToken: cancelToken,
        options: Options(
          method: 'POST',
          headers: buildHeaders(config),
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 10),
          extra: const {'streaming': true},
        ),
      );
      final stream = (response.data as ResponseBody).stream;

      final text = StringBuffer();
      final reasoning = StringBuffer();
      final toolCalls = <AiToolCall>[];
      final toolBuffers =
          <int, ({StringBuffer id, StringBuffer name, StringBuffer args})>{};
      String? finishReason;

      await for (final dataLine in sseDataLines(stream)) {
        if (cancelToken?.isCancelled ?? false) return;
        if (dataLine == '[DONE]') break;
        Map<String, dynamic> json;
        try {
          json = jsonDecode(dataLine) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final error = json['error'];
        if (error != null) {
          yield AiStreamChunk(
            text: text.toString(),
            reasoning: reasoning.toString(),
            toolCalls: List.of(toolCalls),
            errorMessage: aiErrorMessageOf(error),
          );
          return;
        }
        usage = _parseUsage(json, config.model) ?? usage;
        final choices = json['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final choice = choices.first as Map<String, dynamic>;
        finishReason ??= choice['finish_reason'] as String?;
        final delta = choice['delta'] as Map<String, dynamic>?;
        if (delta == null) continue;

        final deltaText = delta['content'];
        if (deltaText is String) text.write(deltaText);
        final deltaReasoning = delta['reasoning_content'] ?? delta['reasoning'];
        if (deltaReasoning is String) reasoning.write(deltaReasoning);

        final toolCallsJson = delta['tool_calls'];
        if (toolCallsJson is List) {
          for (final tc in toolCallsJson) {
            if (tc is! Map<String, dynamic>) continue;
            final index = (tc['index'] as num?)?.toInt() ?? 0;
            final buf = toolBuffers.putIfAbsent(
              index,
              () => (
                id: StringBuffer(),
                name: StringBuffer(),
                args: StringBuffer(),
              ),
            );
            final id = tc['id'];
            if (id is String) buf.id.write(id);
            final fn = tc['function'];
            if (fn is Map<String, dynamic>) {
              final name = fn['name'];
              if (name is String) buf.name.write(name);
              final args = fn['arguments'];
              if (args is String) buf.args.write(args);
            }
          }
          toolCalls
            ..clear()
            ..addAll([
              for (final buf in toolBuffers.values)
                if (buf.id.isNotEmpty || buf.name.isNotEmpty)
                  AiToolCall(
                    id: buf.id.toString(),
                    name: buf.name.toString(),
                    arguments: parseToolArguments(buf.args.toString()),
                  ),
            ]);
        }

        yield AiStreamChunk(
          text: text.toString(),
          reasoning: reasoning.toString(),
          toolCalls: List.of(toolCalls),
          finishReason: finishReason,
        );
      }
      if (cancelToken?.isCancelled ?? false) return;
      yield AiStreamChunk(
        text: text.toString(),
        reasoning: reasoning.toString(),
        toolCalls: List.of(toolCalls),
        usage: usage,
        done: true,
        finishReason: finishReason ?? 'stop',
      );
    } catch (e) {
      if (cancelToken?.isCancelled ?? false) return;
      if (e is DioException && CancelToken.isCancel(e)) return;
      yield AiStreamChunk(errorMessage: e.toString());
    }
  }

  @override
  String parseContent(dynamic responseData) {
    final json = responseData as Map<String, dynamic>;
    final choices = json['choices'] as List;
    return choices.first['message']['content'] as String;
  }

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) {
    final oc = config is OpenAiCompatibleConfig ? config : null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.apiKey}',
      if (oc != null) ...oc.customHeaders,
    };
  }

  @override
  String buildUrl(AiProviderConfig config) =>
      '${config.baseUrl}/chat/completions';

  @override
  Future<Res<String>> queryBalance() async {
    final keyRow = await getKeyRow();
    if (keyRow == null || !keyRow.isEnabled || keyRow.apiKey.isEmpty) {
      return const Res.error(kBalanceQueryUnsupported);
    }
    final def = balanceDefaultConfig(providerKey);
    return queryBalanceByUrl(
      baseUrl: keyRow.baseUrl ?? defaultBaseUrl,
      apiKey: keyRow.apiKey,
      balanceUrl: keyRow.balanceUrl ?? def?.path,
      balanceKey: keyRow.balanceKey ?? def?.key,
    );
  }

  @override
  Future<Res<String>> chat(
    List<AiMessage> messages, {
    String? systemPrompt,
    String? modelOverride,
    AiGenerationParams? params,
    AiProviderConfig? configOverride,
  }) async {
    try {
      final keyRow = await getKeyRow();
      if (keyRow == null || !keyRow.isEnabled) {
        return Res.error('$sourceName API Key 未配置或已禁用');
      }
      final config =
          configOverride ?? buildConfig(keyRow, modelOverride: modelOverride);
      final response = await AppDio().request(
        buildUrl(config),
        data: buildRequest(
          messages,
          config: config,
          systemPrompt: systemPrompt,
          params: params,
        ),
        options: Options(
          method: 'POST',
          headers: buildHeaders(config),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final json = response.data as Map<String, dynamic>;
      return Res(parseContent(json), subData: _parseUsage(json, config.model));
    } catch (e) {
      return Res.error(aiErrorMessageOf(e));
    }
  }
}

// ─── 自定义服务商（OpenAI 兼容，Key 存于 AiCustomProviders） ──

class CustomProviderAi extends OpenAiCompatibleAi {
  CustomProviderAi({
    required super.providerKey,
    required super.sourceName,
    required super.defaultModel,
    required super.defaultBaseUrl,
    super.supportsVision,
    super.supportsTools,
  });

  @override
  Future<AiApiKey?> getKeyRow() async {
    final provider = OpenAiProviderRegistry.customProviderOf(providerKey);
    final c = await AiDatabase.instance.aiCustomProviderDao.getByProvider(
      provider,
    );
    if (c == null || !c.isEnabled) return null;
    return AiApiKey(
      provider: providerKey,
      apiKey: c.apiKey ?? '',
      model: c.defaultModel,
      baseUrl: c.baseUrl,
      balanceUrl: c.balanceUrl,
      balanceKey: c.balanceKey,
      apiFormat: c.apiFormat ?? 'openai',
      modelsUrl: c.modelsUrl,
      isEnabled: true,
      updatedAt: c.updatedAt,
    );
  }
}
