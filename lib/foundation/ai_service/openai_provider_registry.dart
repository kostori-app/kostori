import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/ai_service/gemini_ai.dart';
import 'package:kostori/foundation/ai_service/openrouter_ai.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

// ─── 注册表：新增服务商只改这里 ───────────────────

class OpenAiProviderRegistry {
  static const allProviders =
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

  static bool contains(String source) => allProviders.containsKey(source);

  static AiBase? createAi(String source) {
    final meta = allProviders[source];
    if (meta == null) return null;
    if (source == 'gemini') return GeminiAi();
    if (source == 'openrouter') return OpenRouterAi();
    return OpenAiCompatibleAi(
      providerKey: source,
      sourceName: meta.name,
      defaultModel: meta.defaultModel,
      defaultBaseUrl: meta.baseUrl,
    );
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
  String parseContent(dynamic responseData) {
    final json = responseData as Map<String, dynamic>;
    final choices = json['choices'] as List;
    return choices.first['message']['content'] as String;
  }

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
