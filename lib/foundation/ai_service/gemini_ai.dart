import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

class GeminiAi extends AiBase {
  @override
  String get sourceName => 'Gemini';

  @override
  String get providerKey => 'gemini';

  @override
  AiProviderConfig buildConfig(AiApiKey row) => GeminiConfig(
    apiKey: row.apiKey,
    model: row.model ?? 'gemini-2.0-flash',
    baseUrl: row.baseUrl,
  );

  @override
  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    required AiProviderConfig config,
    String? systemPrompt,
  }) => {
    'contents': messages
        .map(
          (m) => {
            'role': m.role == 'assistant' ? 'model' : m.role,
            'parts': [
              {'text': m.content},
            ],
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
      'temperature': 0.9,
      'topP': 0.95,
      'topK': 40,
      'maxOutputTokens': 2048,
    },
  };

  @override
  String parseContent(dynamic responseData) {
    final json = responseData as Map<String, dynamic>;
    final candidates = json['candidates'] as List;
    final parts = candidates.first['content']['parts'] as List;
    return parts.first['text'] as String;
  }

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    'Content-Type': 'application/json',
  };

  @override
  String buildUrl(AiProviderConfig config) =>
      '${config.baseUrl ?? "https://generativelanguage.googleapis.com/v1beta"}'
      '/models/${config.model}:generateContent';

  @override
  Future<Res<String>> chat(
    List<AiMessage> messages, {
    String? systemPrompt,
  }) async {
    try {
      final keyRow = await getKeyRow();
      if (keyRow == null || !keyRow.isEnabled) {
        return Res.error('Gemini API Key 未配置或已禁用');
      }
      final config = buildConfig(keyRow);
      final response = await AppDio().request(
        '${buildUrl(config)}?key=${config.apiKey}',
        data: buildRequest(
          messages,
          config: config,
          systemPrompt: systemPrompt,
        ),
        options: Options(
          method: 'POST',
          headers: buildHeaders(config),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return Res(parseContent(response.data));
    } catch (e) {
      return Res.error(e.toString());
    }
  }
}
