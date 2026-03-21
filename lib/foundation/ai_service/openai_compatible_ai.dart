import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

class OpenAiCompatibleAi extends AiBase {
  @override
  final String providerKey;
  @override
  final String sourceName;

  final String defaultModel;
  final String defaultBaseUrl;

  OpenAiCompatibleAi({
    required this.providerKey,
    required this.sourceName,
    required this.defaultModel,
    required this.defaultBaseUrl,
  });

  @override
  AiProviderConfig buildConfig(AiApiKey row) => OpenAiCompatibleConfig(
    source: providerKey,
    apiKey: row.apiKey,
    model: row.model ?? defaultModel,
    baseUrl: row.baseUrl ?? defaultBaseUrl,
  );

  @override
  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    required AiProviderConfig config,
    String? systemPrompt,
  }) => {
    'model': config.model,
    'messages': [
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        AiSystemMessage(content: systemPrompt).toJson(),
      ...messages.map((m) => m.toJson()),
    ],
  };

  @override
  String parseContent(dynamic responseData) =>
      (responseData['choices'] as List).first['message']['content'] as String;

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${config.apiKey}',
  };

  @override
  String buildUrl(AiProviderConfig config) =>
      '${config.baseUrl}/chat/completions';

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
