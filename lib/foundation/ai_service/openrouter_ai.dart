import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';

class OpenRouterAi extends AiBase {
  @override
  String get sourceName => 'OpenRouter';

  @override
  String get providerKey => 'openrouter';

  @override
  AiProviderConfig buildConfig(AiApiKey row) => OpenAiCompatibleConfig(
    source: providerKey,
    apiKey: row.apiKey,
    model: row.model ?? 'anthropic/claude-sonnet-4-5',
    baseUrl: row.baseUrl ?? 'https://openrouter.ai/api/v1',
  );

  @override
  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    required AiProviderConfig config,
    String? systemPrompt,
  }) => {
    'model': config.model,
    'input': [
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'type': 'message', 'role': 'system', 'content': systemPrompt},
      ...messages.map(
        (m) => {'type': 'message', 'role': m.role, 'content': m.content},
      ),
    ],
    'temperature': 0.7,
    'top_p': 0.9,
  };

  @override
  String parseContent(dynamic responseData) {
    final json = responseData as Map<String, dynamic>;
    final output = json['output'] as List;
    final content = output.first['content'] as List;
    return content.first['text'] as String;
  }

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${config.apiKey}',
  };

  @override
  String buildUrl(AiProviderConfig config) => '${config.baseUrl}/responses';

  @override
  Future<Res<String>> chat(
    List<AiMessage> messages, {
    String? systemPrompt,
  }) async {
    try {
      final keyRow = await getKeyRow();
      if (keyRow == null || !keyRow.isEnabled) {
        return Res.error('$sourceName API Key 未配置或已禁用');
      }
      final config = buildConfig(keyRow);
      final response = await AppDio().request(
        buildUrl(config),
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
