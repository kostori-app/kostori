import 'dart:convert';

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/ai_service/balance_helper.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

class OpenRouterAi extends AiBase {
  @override
  String get sourceName => 'OpenRouter';

  @override
  String get providerKey => 'openrouter';

  @override
  AiProviderConfig buildConfig(AiApiKey row, {String? modelOverride}) =>
      OpenAiCompatibleConfig(
        source: providerKey,
        apiKey: row.apiKey,
        model: modelOverride ?? row.model ?? 'anthropic/claude-sonnet-4-5',
        baseUrl: row.baseUrl ?? 'https://openrouter.ai/api/v1',
      );

  /// Responses API 的 content 数组，支持多模态图片
  List<Map<String, dynamic>> _buildContent(AiMessage m) {
    if (m is AiUserMessage && m.parts != null && m.parts!.isNotEmpty) {
      return [
        if (m.content.isNotEmpty) {'type': 'input_text', 'text': m.content},
        for (final part in m.parts!)
          if (part is AiTextPart)
            {'type': 'input_text', 'text': part.text}
          else if (part is AiImagePart)
            {'type': 'input_image', 'image_url': part.dataUrl},
      ];
    }
    return [
      {'type': 'input_text', 'text': m.content},
    ];
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
    'input': [
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'type': 'message', 'role': 'system', 'content': systemPrompt},
      ...messages.map(
        (m) => {'type': 'message', 'role': m.role, 'content': _buildContent(m)},
      ),
    ],
    'temperature': params?.temperature ?? 0.7,
    'top_p': params?.topP ?? 0.9,
    if (params?.maxTokens != null) 'max_output_tokens': params!.maxTokens,
    if (tools != null && tools.isNotEmpty)
      'tools': [
        for (final t in tools)
          {
            'type': 'function',
            'name': t.name,
            'description': t.description,
            if (t.parameters.isNotEmpty) 'parameters': t.parameters,
          },
      ],
  };

  @override
  String parseContent(dynamic responseData) {
    final json = responseData as Map<String, dynamic>;
    final output = json['output'] as List;
    final messageBlock = output.firstWhere(
      (o) => o['type'] == 'message',
      orElse: () => output.last,
    );

    final content = messageBlock['content'] as List;
    final outputText = content.firstWhere(
      (c) => c['type'] == 'output_text',
      orElse: () => content.first,
    );

    return outputText['text'] as String;
  }

  /// 解析 OpenRouter Responses API 的 usage（input_tokens / output_tokens）
  static AiUsage? _parseUsage(Map<String, dynamic> json, String modelName) {
    final usage = json['usage'];
    if (usage is! Map<String, dynamic>) return null;
    final prompt = ((usage['input_tokens'] ?? usage['prompt_tokens']) as num?)
        ?.toInt();
    final completion =
        ((usage['output_tokens'] ?? usage['completion_tokens']) as num?)
            ?.toInt();
    if (prompt == null && completion == null) return null;
    final inputDetails = usage['input_tokens_details'];
    final cached = inputDetails is Map<String, dynamic>
        ? (inputDetails['cached_tokens'] as num?)?.toInt()
        : (usage['prompt_cache_hit_tokens'] as num?)?.toInt();
    return AiUsage(
      promptTokens: prompt,
      completionTokens: completion,
      cachedTokens: cached,
      modelName: modelName,
    );
  }

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${config.apiKey}',
  };

  @override
  String buildUrl(AiProviderConfig config) => '${config.baseUrl}/responses';

  @override
  Future<Res<String>> queryBalance() async {
    final keyRow = await getKeyRow();
    if (keyRow == null || !keyRow.isEnabled || keyRow.apiKey.isEmpty) {
      return const Res.error(kBalanceQueryUnsupported);
    }
    final def = balanceDefaultConfig(providerKey);
    return queryBalanceByUrl(
      baseUrl: keyRow.baseUrl ?? 'https://openrouter.ai/api/v1',
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
      final config = buildConfig(keyRow, modelOverride: modelOverride);
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
      return Res.error(e.toString());
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
      final config = buildConfig(keyRow, modelOverride: modelOverride);
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
      final toolBuffers = <String, ({StringBuffer name, StringBuffer args})>{};

      await for (final dataLine in sseDataLines(stream)) {
        if (cancelToken?.isCancelled ?? false) return;
        if (dataLine == '[DONE]') break;
        if (dataLine.isEmpty) continue;
        Map<String, dynamic> json;
        try {
          json = jsonDecode(dataLine) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final type = json['type'] as String?;
        switch (type) {
          case 'response.output_text.delta':
            final delta = json['delta'];
            if (delta is String) text.write(delta);
          case 'response.reasoning_text.delta':
          case 'response.reasoning_summary_text.delta':
            final delta = json['delta'];
            if (delta is String) reasoning.write(delta);
          case 'response.output_item.added':
            final item = json['item'];
            if (item is Map<String, dynamic> &&
                item['type'] == 'function_call') {
              final id = item['call_id'] as String? ?? '';
              final name = item['name'] as String? ?? '';
              if (id.isNotEmpty) {
                toolBuffers[id] = (
                  name: StringBuffer(name),
                  args: StringBuffer(),
                );
              }
            }
          case 'response.function_call_arguments.delta':
            final id = json['item_id'] as String?;
            final delta = json['delta'];
            if (id != null && delta is String && toolBuffers[id] != null) {
              toolBuffers[id]!.args.write(delta);
            }
          case 'response.function_call_arguments.done':
            final id = json['item_id'] as String?;
            final args = json['arguments'];
            if (id != null && args is String && toolBuffers[id] != null) {
              toolBuffers[id] = (
                name: toolBuffers[id]!.name,
                args: StringBuffer(args),
              );
            }
          case 'response.completed':
            final resp = json['response'];
            if (resp is Map<String, dynamic>) {
              usage = _parseUsage(resp, config.model) ?? usage;
            }
          case 'error':
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
          default:
            break;
        }
        if (toolBuffers.isNotEmpty) {
          toolCalls
            ..clear()
            ..addAll([
              for (final entry in toolBuffers.entries)
                AiToolCall(
                  id: entry.key,
                  name: entry.value.name.toString(),
                  arguments: parseToolArguments(entry.value.args.toString()),
                ),
            ]);
        }
        yield AiStreamChunk(
          text: text.toString(),
          reasoning: reasoning.toString(),
          toolCalls: List.of(toolCalls),
        );
      }
      if (cancelToken?.isCancelled ?? false) return;
      yield AiStreamChunk(
        text: text.toString(),
        reasoning: reasoning.toString(),
        toolCalls: List.of(toolCalls),
        usage: usage,
        done: true,
        finishReason: 'stop',
      );
    } catch (e) {
      if (cancelToken?.isCancelled ?? false) return;
      if (e is DioException && CancelToken.isCancel(e)) return;
      yield AiStreamChunk(errorMessage: e.toString());
    }
  }
}
