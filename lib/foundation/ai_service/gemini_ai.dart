import 'dart:convert';

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

class GeminiAi extends AiBase {
  GeminiAi({
    this.providerKey = 'gemini',
    this.sourceName = 'Gemini',
    this.defaultModel = 'gemini-2.0-flash',
    this.defaultBaseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  });

  @override
  final String providerKey;

  @override
  final String sourceName;

  final String defaultModel;
  final String defaultBaseUrl;

  /// Gemini 流式端点暂未实现增量 function calling
  @override
  bool get supportsStreamingTools => false;

  @override
  AiProviderConfig buildConfig(AiApiKey row, {String? modelOverride}) =>
      GeminiConfig(
        apiKey: row.apiKey,
        model: modelOverride ?? row.model ?? defaultModel,
        baseUrl: row.baseUrl ?? defaultBaseUrl,
      );

  /// 将消息转换为 Gemini 的 parts 列表，支持多模态图片
  List<Map<String, dynamic>> _buildParts(AiMessage m) {
    if (m is AiUserMessage && m.parts != null && m.parts!.isNotEmpty) {
      final result = <Map<String, dynamic>>[];
      if (m.content.isNotEmpty) result.add({'text': m.content});
      for (final part in m.parts!) {
        if (part is AiTextPart) {
          result.add({'text': part.text});
        } else if (part is AiImagePart) {
          final data = parseDataUrl(part.dataUrl);
          if (data != null) {
            result.add({
              'inlineData': {'mimeType': data.mime, 'data': data.data},
            });
          } else {
            result.add({'text': part.dataUrl});
          }
        }
      }
      return result;
    }
    return [
      {'text': m.content},
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
    'contents': messages
        .map(
          (m) => {
            'role': m.role == 'assistant' ? 'model' : m.role,
            'parts': _buildParts(m),
          },
        )
        .toList(),
    if (systemPrompt != null && systemPrompt.isNotEmpty)
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
    'generationConfig': {
      'temperature': params?.temperature ?? 0.9,
      'topP': params?.topP ?? 0.95,
      'topK': 40,
      if (params?.maxTokens != null) 'maxOutputTokens': params!.maxTokens,
    },
  };

  @override
  String parseContent(dynamic responseData) {
    final json = responseData as Map<String, dynamic>;
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('Gemini 返回为空');
    }
    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) {
      throw Exception('Gemini 返回格式异常');
    }
    // 非正常终止（安全拦截/内容违规等）：content 可能为空，给出友好提示
    final finishReason = candidate['finishReason'] as String?;
    if (finishReason != null && finishReason != 'STOP') {
      throw Exception('Gemini 生成被终止（$finishReason）');
    }
    final content = candidate['content'];
    if (content is! Map<String, dynamic>) {
      throw Exception('Gemini 未返回内容');
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw Exception('Gemini 未返回内容');
    }
    final text = (parts.first as Map)['text'];
    if (text is! String) {
      throw Exception('Gemini 未返回内容');
    }
    return text;
  }

  /// 解析 Gemini usageMetadata
  static AiUsage? _parseUsage(Map<String, dynamic> json, String modelName) {
    final meta = json['usageMetadata'];
    if (meta is! Map<String, dynamic>) return null;
    final prompt = (meta['promptTokenCount'] as num?)?.toInt();
    final completion = (meta['candidatesTokenCount'] as num?)?.toInt();
    if (prompt == null && completion == null) return null;
    final cached = (meta['cachedContentTokenCount'] as num?)?.toInt();
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
    // key 走 header 不进 URL，避免泄漏到访问日志/代理
    if (config.apiKey.isNotEmpty) 'x-goog-api-key': config.apiKey,
  };

  @override
  String buildUrl(AiProviderConfig config) =>
      '${config.baseUrl ?? "https://generativelanguage.googleapis.com/v1beta"}'
      '/models/${config.model}:generateContent';

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
        return Res.error(t.apiKeyNotConfigured(source: 'Gemini'));
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
      return Res.error(aiErrorMessageOf(e));
    }
  }

  @override
  Stream<AiStreamChunk> chatStream(
    List<AiMessage> messages, {
    String? systemPrompt,
    List<AiToolDefinition>? tools,
    AiGenerationParams? params,
    CancelToken? cancelToken,
    String? modelOverride,
    AiProviderConfig? configOverride,
  }) async* {
    AiUsage? usage;
    try {
      final keyRow = await getKeyRow();
      if (keyRow == null || !keyRow.isEnabled) {
        yield AiStreamChunk(errorMessage: t.apiKeyNotConfigured(source: 'Gemini'));
        return;
      }
      final config = buildConfig(keyRow, modelOverride: modelOverride);
      final response = await AppDio().request(
        '${buildUrl(config).replaceFirst(':generateContent', ':streamGenerateContent')}'
        '?alt=sse',
        data: buildRequest(
          messages,
          config: config,
          systemPrompt: systemPrompt,
          tools: tools,
          params: params,
        ),
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
      String? finishReason;

      await for (final dataLine in sseDataLines(stream)) {
        if (cancelToken?.isCancelled ?? false) return;
        if (dataLine.isEmpty) continue;
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
            errorMessage: aiErrorMessageOf(error),
          );
          return;
        }
        usage = _parseUsage(json, config.model) ?? usage;
        final candidates = json['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final candidate = candidates.first as Map<String, dynamic>;
          finishReason ??= candidate['finishReason'] as String?;
          final content = candidate['content'];
          if (content is Map<String, dynamic>) {
            final parts = content['parts'];
            if (parts is List) {
              for (final part in parts) {
                if (part is! Map<String, dynamic>) continue;
                final partText = part['text'];
                if (partText is String) {
                  if (part['thought'] == true) {
                    reasoning.write(partText);
                  } else {
                    text.write(partText);
                  }
                }
              }
            }
          }
        }
        yield AiStreamChunk(
          text: text.toString(),
          reasoning: reasoning.toString(),
          finishReason: finishReason,
        );
      }
      if (cancelToken?.isCancelled ?? false) return;
      yield AiStreamChunk(
        text: text.toString(),
        reasoning: reasoning.toString(),
        usage: usage,
        done: true,
        finishReason: finishReason ?? 'STOP',
      );
    } catch (e) {
      if (cancelToken?.isCancelled ?? false) return;
      if (e is DioException && CancelToken.isCancel(e)) return;
      yield AiStreamChunk(errorMessage: e.toString());
    }
  }
}
