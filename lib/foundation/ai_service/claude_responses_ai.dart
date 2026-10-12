// Claude (Anthropic) 与 OpenAI Responses 两种接口格式的自定义服务商实现。
// Claude 回退非流式；Responses 支持文本增量返回。

import 'dart:convert';

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_provider_settings.dart';
import 'package:kostori/i18n/strings.g.dart';
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
  String buildUrl(AiProviderConfig config) => AiProviderApi.endpoint(
    config.baseUrl ?? defaultBaseUrl,
    'messages',
    versioned: true,
  );

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    ...AiProviderApi.headers('claude', config.apiKey),
    if (config is OpenAiCompatibleConfig) ...config.customHeaders,
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
        return Res.error(t.apiKeyNotConfigured(source: sourceName));
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
        return Res.error(t.apiKeyNotConfigured(source: sourceName));
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
            result = t.toolExecutionFailed(error: e);
          }
          history = [
            ...history,
            AiUserMessage(content: '[工具$name 结果] $result'),
          ];
        }
      }
      return Res.error(t.toolRoundsExceeded(source: sourceName));
    } catch (e) {
      return Res.error(aiErrorMessageOf(e));
    }
  }
}

/// OpenAI Responses API，支持文本流、图片输入和工具调用。
class ResponsesAi extends AiBase {
  ResponsesAi({
    required this.providerKey,
    required this.sourceName,
    required this.defaultModel,
    required this.defaultBaseUrl,
    Dio? dio,
    this.keyLoader,
  }) : _dio = dio ?? AppDio();

  @override
  final String providerKey;
  @override
  final String sourceName;
  final String defaultModel;
  final String defaultBaseUrl;
  final Dio _dio;
  final Future<AiApiKey?> Function()? keyLoader;

  @override
  bool get supportsStreamingTools => true;

  @override
  Future<AiApiKey?> getKeyRow() => keyLoader?.call() ?? super.getKeyRow();

  @override
  AiProviderConfig buildConfig(AiApiKey row, {String? modelOverride}) =>
      OpenAiCompatibleConfig(
        source: providerKey,
        apiKey: row.apiKey,
        model: modelOverride ?? row.model ?? defaultModel,
        baseUrl: row.baseUrl ?? defaultBaseUrl,
      );

  @override
  String buildUrl(AiProviderConfig config) => AiProviderApi.endpoint(
    config.baseUrl ?? defaultBaseUrl,
    'responses',
    versioned: true,
  );

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    ...AiProviderApi.headers('openai_responses', config.apiKey),
    if (config is OpenAiCompatibleConfig) ...config.customHeaders,
  };

  Iterable<Map<String, dynamic>> _inputItems(AiMessage message) sync* {
    if (message is AiAssistantMessage && message.responseItems != null) {
      yield* message.responseItems!;
      return;
    }
    if (message is AiToolResultMessage) {
      yield {
        'type': 'function_call_output',
        'call_id': message.toolCallId,
        'output': message.content,
      };
      return;
    }
    if (message is AiAssistantMessage &&
        message.toolCalls?.isNotEmpty == true) {
      if (message.content.isNotEmpty) {
        yield {'role': 'assistant', 'content': message.content};
      }
      for (final call in message.toolCalls!) {
        yield {
          'type': 'function_call',
          'call_id': call.id,
          'name': call.name,
          'arguments': jsonEncode(call.arguments),
        };
      }
      return;
    }
    if (message is AiUserMessage && message.parts?.isNotEmpty == true) {
      yield {
        'role': 'user',
        'content': [
          if (message.content.isNotEmpty)
            {'type': 'input_text', 'text': message.content},
          for (final part in message.parts!)
            if (part is AiImagePart)
              {'type': 'input_image', 'image_url': part.dataUrl}
            else if (part is AiTextPart)
              {'type': 'input_text', 'text': part.text},
        ],
      };
      return;
    }
    yield {'role': message.role, 'content': message.content};
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
    'input': [for (final message in messages) ..._inputItems(message)],
    if (systemPrompt?.isNotEmpty == true) 'instructions': systemPrompt,
    if (params?.temperature != null) 'temperature': params!.temperature,
    if (params?.topP != null) 'top_p': params!.topP,
    if (params?.maxTokens != null) 'max_output_tokens': params!.maxTokens,
    if (tools?.isNotEmpty == true)
      'tools': [
        for (final tool in tools!)
          {
            'type': 'function',
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.parameters.isEmpty
                ? const {'type': 'object', 'properties': <String, dynamic>{}}
                : tool.parameters,
            'strict': false,
          },
      ],
    if (tools?.isNotEmpty == true) 'include': ['reasoning.encrypted_content'],
    'store': false,
    if (config is OpenAiCompatibleConfig) ...config.extraBodyFields,
  };

  @override
  String parseContent(dynamic responseData) {
    final json = responseData as Map;
    final output = json['output'] as List? ?? const [];
    final text = StringBuffer();
    for (final item in output.whereType<Map>()) {
      if (item['type'] != 'message') continue;
      for (final part
          in (item['content'] as List? ?? const []).whereType<Map>()) {
        if (part['type'] == 'output_text' || part['type'] == 'text') {
          text.write(part['text']?.toString() ?? '');
        } else if (part['type'] == 'refusal') {
          text.write(part['refusal']?.toString() ?? '');
        }
      }
    }
    return text.toString();
  }

  static AiUsage? _parseUsage(Map json, String model) {
    final usage = json['usage'];
    if (usage is! Map) return null;
    final details = usage['input_tokens_details'];
    return AiUsage(
      promptTokens: (usage['input_tokens'] as num?)?.toInt(),
      completionTokens: (usage['output_tokens'] as num?)?.toInt(),
      cachedTokens: details is Map
          ? (details['cached_tokens'] as num?)?.toInt()
          : null,
      modelName: model,
    );
  }

  String? _responseError(Map json) {
    if (json['error'] != null) return aiErrorMessageOf(json['error']);
    if (json['status'] == 'failed') return aiErrorMessageOf(json);
    return null;
  }

  Res<String> _textResult(Map json, String model) {
    final error = _responseError(json);
    if (error != null) return Res.error(error);
    final text = parseContent(json);
    if (text.trim().isEmpty) return Res.error(t.aiProviderEmptyResponse);
    return Res(text, subData: _parseUsage(json, model));
  }

  Future<Response<dynamic>> _post(
    AiProviderConfig config,
    Map<String, dynamic> body,
  ) => _dio.post<dynamic>(
    buildUrl(config),
    data: body,
    options: Options(
      headers: buildHeaders(config),
      receiveTimeout: const Duration(minutes: 3),
    ),
  );

  @override
  Future<Res<String>> chat(
    List<AiMessage> messages, {
    String? systemPrompt,
    String? modelOverride,
    AiGenerationParams? params,
    AiProviderConfig? configOverride,
  }) async {
    try {
      final key = await getKeyRow();
      if (key == null || !key.isEnabled) {
        return Res.error(t.apiKeyNotConfigured(source: sourceName));
      }
      final config =
          configOverride ?? buildConfig(key, modelOverride: modelOverride);
      final response = await _post(
        config,
        buildRequest(
          messages,
          config: config,
          systemPrompt: systemPrompt,
          params: params,
        ),
      );
      return _textResult(response.data as Map, config.model);
    } catch (error) {
      return Res.error(aiErrorMessageOf(error));
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
      final key = await getKeyRow();
      if (key == null || !key.isEnabled) {
        return Res.error(t.apiKeyNotConfigured(source: sourceName));
      }
      final config =
          configOverride ?? buildConfig(key, modelOverride: modelOverride);
      var input = <dynamic>[
        for (final message in messages) ..._inputItems(message),
      ];
      for (var round = 0; round < 3; round++) {
        final body = buildRequest(
          messages,
          config: config,
          systemPrompt: systemPrompt,
          tools: tools,
          params: params,
        );
        body['input'] = input;
        final response = await _post(config, body);
        final json = response.data as Map;
        final error = _responseError(json);
        if (error != null) return Res.error(error);
        final output = json['output'] as List? ?? const [];
        final calls = output
            .whereType<Map>()
            .where((item) => item['type'] == 'function_call')
            .toList();
        if (calls.isEmpty) {
          return _textResult(json, config.model);
        }
        // 原样回传 output，保留推理项、调用 ID 和并行工具调用。
        input = [...input, ...output];
        for (final call in calls) {
          String result;
          try {
            result = await onToolCall(
              call['name']?.toString() ?? '',
              parseToolArguments(call['arguments']?.toString() ?? ''),
            );
          } catch (error) {
            result = t.toolExecutionFailed(error: error);
          }
          input.add({
            'type': 'function_call_output',
            'call_id': call['call_id'],
            'output': result,
          });
        }
      }
      return Res.error(t.toolRoundsExceeded(source: sourceName));
    } catch (error) {
      return Res.error(aiErrorMessageOf(error));
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
    try {
      final key = await getKeyRow();
      if (key == null || !key.isEnabled) {
        yield AiStreamChunk(
          errorMessage: t.apiKeyNotConfigured(source: sourceName),
        );
        return;
      }
      final config =
          configOverride ?? buildConfig(key, modelOverride: modelOverride);
      final response = await _dio.post<ResponseBody>(
        buildUrl(config),
        data: {
          ...buildRequest(
            messages,
            config: config,
            systemPrompt: systemPrompt,
            tools: tools,
            params: params,
          ),
          'stream': true,
        },
        options: Options(
          headers: buildHeaders(config),
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 3),
          extra: const {'streaming': true},
        ),
        cancelToken: cancelToken,
      );
      final text = StringBuffer();
      final reasoning = StringBuffer();
      await for (final data in sseDataLines(response.data!.stream)) {
        if (cancelToken?.isCancelled == true) return;
        if (data == '[DONE]') break;
        final event = jsonDecode(data);
        if (event is! Map) continue;
        switch (event['type']) {
          case 'response.output_text.delta':
            text.write(event['delta']?.toString() ?? '');
            yield AiStreamChunk(
              text: text.toString(),
              reasoning: reasoning.toString(),
            );
          case 'response.reasoning_summary_text.delta':
            reasoning.write(event['delta']?.toString() ?? '');
            yield AiStreamChunk(
              text: text.toString(),
              reasoning: reasoning.toString(),
            );
          case 'response.completed':
          case 'response.incomplete':
            final result = event['response'] as Map? ?? const {};
            final error = _responseError(result);
            if (error != null) {
              yield AiStreamChunk(errorMessage: error);
              return;
            }
            final items = (result['output'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            final calls = [
              for (final item in items)
                if (item['type'] == 'function_call')
                  AiToolCall(
                    id: item['call_id']?.toString() ?? '',
                    name: item['name']?.toString() ?? '',
                    arguments: parseToolArguments(
                      item['arguments']?.toString() ?? '',
                    ),
                  ),
            ];
            if (text.isEmpty) text.write(parseContent(result));
            if (text.toString().trim().isEmpty && calls.isEmpty) {
              yield AiStreamChunk(errorMessage: t.aiProviderEmptyResponse);
              return;
            }
            yield AiStreamChunk(
              text: text.toString(),
              reasoning: reasoning.toString(),
              usage: _parseUsage(result, config.model),
              done: true,
              toolCalls: calls,
              responseItems: items,
              finishReason: event['type'] == 'response.incomplete'
                  ? 'length'
                  : calls.isEmpty
                  ? 'stop'
                  : 'tool_calls',
            );
            return;
          case 'response.failed':
          case 'error':
            final error =
                event['error'] ??
                (event['response'] as Map?)?['error'] ??
                event;
            yield AiStreamChunk(errorMessage: aiErrorMessageOf(error));
            return;
        }
      }
      yield text.isEmpty
          ? AiStreamChunk(errorMessage: t.aiProviderEmptyResponse)
          : AiStreamChunk(
              text: text.toString(),
              reasoning: reasoning.toString(),
              done: true,
              finishReason: 'stop',
            );
    } catch (error) {
      if (cancelToken?.isCancelled == true ||
          (error is DioException && CancelToken.isCancel(error))) {
        return;
      }
      yield AiStreamChunk(errorMessage: aiErrorMessageOf(error));
    }
  }
}
