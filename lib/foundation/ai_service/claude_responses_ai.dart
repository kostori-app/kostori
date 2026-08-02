// Claude (Anthropic) 与 OpenAI Responses 两种接口格式的自定义服务商实现。
// 均为非流式（chat / chatWithTools），流式由 AiBase 默认回退到非流式一次性返回。

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

/// Anthropic Claude Messages API
class ClaudeAi extends AiBase {
  ClaudeAi({
    required this.providerKey,
    required this.sourceName,
    required this.defaultModel,
    required this.defaultBaseUrl,
  });

  @override
  final String providerKey;
  @override
  final String sourceName;
  final String defaultModel;
  final String defaultBaseUrl;

  @override
  bool get supportsStreamingTools => false;

  @override
  AiProviderConfig buildConfig(AiApiKey row, {String? modelOverride}) =>
      OpenAiCompatibleConfig(
        source: providerKey,
        apiKey: row.apiKey,
        model: modelOverride ?? row.model ?? defaultModel,
        baseUrl: row.baseUrl ?? defaultBaseUrl,
      );

  @override
  String buildUrl(AiProviderConfig config) => '${config.baseUrl}/v1/messages';

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    'Content-Type': 'application/json',
    'x-api-key': config.apiKey,
    'anthropic-version': '2023-06-01',
  };

  /// 将单条消息转为 Claude content（文本或多模态块）
  Object _contentOf(AiMessage m) {
    if (m is AiUserMessage && m.parts != null && m.parts!.isNotEmpty) {
      final blocks = <Map<String, dynamic>>[];
      if (m.content.isNotEmpty) {
        blocks.add({'type': 'text', 'text': m.content});
      }
      for (final p in m.parts!) {
        if (p is AiImagePart) {
          final d = parseDataUrl(p.dataUrl);
          if (d != null) {
            blocks.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': d.mime,
                'data': d.data,
              },
            });
          } else {
            blocks.add({'type': 'text', 'text': p.dataUrl});
          }
        } else if (p is AiTextPart) {
          blocks.add({'type': 'text', 'text': p.text});
        }
      }
      return blocks;
    }
    return m.content;
  }

  @override
  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    required AiProviderConfig config,
    String? systemPrompt,
    List<AiToolDefinition>? tools,
    AiGenerationParams? params,
  }) => {
    'model': config.model,
    'max_tokens': params?.maxTokens ?? 4096,
    if (systemPrompt != null && systemPrompt.isNotEmpty) 'system': systemPrompt,
    'messages': [
      for (final m in messages)
        if (m.role == 'user')
          {'role': 'user', 'content': _contentOf(m)}
        else if (m.role == 'assistant')
          {'role': 'assistant', 'content': m.content}
        else if (m.role == 'tool')
          {'role': 'user', 'content': '[工具结果] ${m.content}'},
    ],
    if (params?.temperature != null) 'temperature': params!.temperature,
    if (params?.topP != null) 'top_p': params!.topP,
    if (tools != null && tools.isNotEmpty)
      'tools': [
        for (final t in tools)
          {
            'name': t.name,
            'description': t.description,
            'input_schema': t.parameters.isEmpty
                ? const {'type': 'object'}
                : t.parameters,
          },
      ],
  };

  @override
  String parseContent(dynamic responseData) {
    final json = responseData as Map<String, dynamic>;
    final content = json['content'] as List? ?? const [];
    return content
        .whereType<Map>()
        .where((c) => c['type'] == 'text')
        .map((c) => c['text']?.toString() ?? '')
        .join();
  }

  static AiUsage? _parseUsage(Map<String, dynamic> json, String model) {
    final u = json['usage'];
    if (u is Map) {
      return AiUsage(
        promptTokens: u['input_tokens'] is num
            ? (u['input_tokens'] as num).toInt()
            : null,
        completionTokens: u['output_tokens'] is num
            ? (u['output_tokens'] as num).toInt()
            : null,
        modelName: model,
      );
    }
    return null;
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
        final content = json['content'] as List? ?? const [];
        final toolUses = content
            .whereType<Map>()
            .where((c) => c['type'] == 'tool_use')
            .toList();
        if (toolUses.isEmpty) {
          return Res(
            parseContent(json),
            subData: _parseUsage(json, config.model),
          );
        }
        final text = content
            .whereType<Map>()
            .where((c) => c['type'] == 'text')
            .map((c) => c['text']?.toString() ?? '')
            .join();
        history = [
          ...history,
          AiAssistantMessage(
            content: text,
            toolCalls: [
              for (final tu in toolUses)
                AiToolCall(
                  id: tu['id']?.toString() ?? '',
                  name: tu['name']?.toString() ?? '',
                  arguments: (tu['input'] is Map)
                      ? (tu['input'] as Map).cast<String, dynamic>()
                      : const {},
                ),
            ],
          ),
        ];
        for (final tu in toolUses) {
          final name = tu['name']?.toString() ?? '';
          final arguments = (tu['input'] is Map)
              ? (tu['input'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};
          String result;
          try {
            result = await onToolCall(name, arguments);
          } catch (e) {
            result = '工具执行失败: $e';
          }
          history = [
            ...history,
            AiUserMessage(content: '[工具$name 结果] $result'),
          ];
        }
      }
      return Res.error('$sourceName 工具调用轮次过多');
    } catch (e) {
      return Res.error(aiErrorMessageOf(e));
    }
  }
}

/// OpenAI Responses API
class ResponsesAi extends AiBase {
  ResponsesAi({
    required this.providerKey,
    required this.sourceName,
    required this.defaultModel,
    required this.defaultBaseUrl,
  });

  @override
  final String providerKey;
  @override
  final String sourceName;
  final String defaultModel;
  final String defaultBaseUrl;

  @override
  bool get supportsStreamingTools => false;

  @override
  AiProviderConfig buildConfig(AiApiKey row, {String? modelOverride}) =>
      OpenAiCompatibleConfig(
        source: providerKey,
        apiKey: row.apiKey,
        model: modelOverride ?? row.model ?? defaultModel,
        baseUrl: row.baseUrl ?? defaultBaseUrl,
      );

  @override
  String buildUrl(AiProviderConfig config) => '${config.baseUrl}/v1/responses';

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${config.apiKey}',
  };

  /// 将 AiMessage 转为 Responses 的 input 条目
  Object _inputItem(AiMessage m) {
    if (m.role == 'user') return {'role': 'user', 'content': m.content};
    if (m.role == 'assistant') {
      return {'role': 'assistant', 'content': m.content};
    }
    if (m.role == 'tool') {
      return {
        'type': 'function_call_output',
        'call_id': m is AiToolResultMessage ? m.toolCallId : m.content,
        'output': m.content,
      };
    }
    return {'role': 'user', 'content': m.content};
  }

  @override
  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    required AiProviderConfig config,
    String? systemPrompt,
    List<AiToolDefinition>? tools,
    AiGenerationParams? params,
  }) => {
    'model': config.model,
    'input': [for (final m in messages) _inputItem(m)],
    if (systemPrompt != null && systemPrompt.isNotEmpty)
      'instructions': systemPrompt,
    if (params?.temperature != null) 'temperature': params!.temperature,
    if (params?.maxTokens != null) 'max_output_tokens': params!.maxTokens,
    if (tools != null && tools.isNotEmpty)
      'tools': [
        for (final t in tools)
          {
            'type': 'function',
            'name': t.name,
            'description': t.description,
            'parameters': t.parameters.isEmpty
                ? const {'type': 'object'}
                : t.parameters,
          },
      ],
    'store': false,
  };

  @override
  String parseContent(dynamic responseData) {
    final json = responseData as Map<String, dynamic>;
    final output = json['output'] as List? ?? const [];
    final sb = StringBuffer();
    for (final item in output.whereType<Map>()) {
      if (item['type'] == 'message') {
        final content = item['content'] as List? ?? const [];
        for (final c in content.whereType<Map>()) {
          if (c['type'] == 'output_text' || c['type'] == 'text') {
            sb.write(c['text']?.toString() ?? '');
          }
        }
      }
    }
    return sb.toString();
  }

  static AiUsage? _parseUsage(Map<String, dynamic> json, String model) {
    final u = json['usage'];
    if (u is Map) {
      return AiUsage(
        promptTokens: u['input_tokens'] is num
            ? (u['input_tokens'] as num).toInt()
            : null,
        completionTokens: u['output_tokens'] is num
            ? (u['output_tokens'] as num).toInt()
            : null,
        modelName: model,
      );
    }
    return null;
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
        final output = json['output'] as List? ?? const [];
        final calls = output
            .whereType<Map>()
            .where((o) => o['type'] == 'function_call')
            .toList();
        if (calls.isEmpty) {
          return Res(
            parseContent(json),
            subData: _parseUsage(json, config.model),
          );
        }
        history = [
          ...history,
          for (final c in calls)
            AiAssistantMessage(
              content: c['arguments']?.toString() ?? '',
              toolCalls: [
                AiToolCall(
                  id: c['call_id']?.toString() ?? '',
                  name: c['name']?.toString() ?? '',
                  arguments: parseToolArguments(
                    c['arguments']?.toString() ?? '',
                  ),
                ),
              ],
            ),
        ];
        for (final c in calls) {
          final name = c['name']?.toString() ?? '';
          final arguments = parseToolArguments(
            c['arguments']?.toString() ?? '',
          );
          String result;
          try {
            result = await onToolCall(name, arguments);
          } catch (e) {
            result = '工具执行失败: $e';
          }
          history = [
            ...history,
            AiToolResultMessage(
              toolCallId: c['call_id']?.toString() ?? '',
              toolName: name,
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
}
