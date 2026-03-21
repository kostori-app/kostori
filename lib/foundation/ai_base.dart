import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/models/ai/doubao_chat_models.dart';
import 'package:kostori/foundation/models/ai/gemini_chat_models.dart';
import 'package:kostori/foundation/models/ai/sf_chat_models.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

abstract class AiMessage {
  final String role;
  final String content;

  const AiMessage({required this.role, required this.content});

  Map<String, dynamic> toJson();
}

class AiUserMessage extends AiMessage {
  const AiUserMessage({required super.content}) : super(role: 'user');

  @override
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiSystemMessage extends AiMessage {
  const AiSystemMessage({required super.content}) : super(role: 'system');

  @override
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiAssistantMessage extends AiMessage {
  const AiAssistantMessage({required super.content}) : super(role: 'assistant');

  @override
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

abstract class AiResponse {
  final String content;

  const AiResponse({required this.content});
}

abstract class AiUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const AiUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
}

abstract class AiProviderConfig {
  final String apiKey;
  final String model;
  final String? baseUrl;

  const AiProviderConfig({
    required this.apiKey,
    required this.model,
    this.baseUrl,
  });

  Map<String, dynamic> toJson();

  static AiProviderConfig? fromJson(Map<String, dynamic> json) {
    final source = json['source'] as String?;
    switch (source) {
      case 'siliconFlow':
        return SiliconFlowConfig.fromJson(json);
      case 'doubao':
        return DoubaoConfig.fromJson(json);
      case 'gemini':
        return GeminiConfig.fromJson(json);
      default:
        return null;
    }
  }
}

class SiliconFlowConfig extends AiProviderConfig {
  const SiliconFlowConfig({
    required super.apiKey,
    super.model = 'THUDM/GLM-4-9B-0414',
    super.baseUrl = 'https://api.siliconflow.cn/v1',
  });

  factory SiliconFlowConfig.fromJson(Map<String, dynamic> json) {
    return SiliconFlowConfig(
      apiKey: json['apiKey'] ?? '',
      model: json['model'] ?? 'THUDM/GLM-4-9B-0414',
      baseUrl: json['baseUrl'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'source': 'siliconFlow',
    'apiKey': apiKey,
    'model': model,
    'baseUrl': baseUrl,
  };
}

class DoubaoConfig extends AiProviderConfig {
  const DoubaoConfig({
    required super.apiKey,
    super.model = 'doubao-1-5-lite-32k-250115',
    super.baseUrl = 'https://ark.cn-beijing.volces.com/api/v3',
  });

  factory DoubaoConfig.fromJson(Map<String, dynamic> json) {
    return DoubaoConfig(
      apiKey: json['apiKey'] ?? '',
      model: json['model'] ?? 'doubao-1-5-lite-32k-250115',
      baseUrl: json['baseUrl'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'source': 'doubao',
    'apiKey': apiKey,
    'model': model,
    'baseUrl': baseUrl,
  };
}

class GeminiConfig extends AiProviderConfig {
  final String? _apiKey;

  const GeminiConfig({
    String? apiKey,
    super.model = 'gemini-2.0-flash',
    super.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _apiKey = apiKey,
       super(apiKey: '');

  factory GeminiConfig.fromJson(Map<String, dynamic> json) {
    return GeminiConfig(
      apiKey: json['apiKey'],
      model: json['model'] ?? 'gemini-2.0-flash',
      baseUrl: json['baseUrl'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'source': 'gemini',
    'apiKey': _apiKey,
    'model': model,
    'baseUrl': baseUrl,
  };

  @override
  String get apiKey => _apiKey ?? '';
}

abstract class AiBase {
  String get sourceName;

  String get providerKey;

  Future<Res<String>> chat(List<AiMessage> messages, {String? systemPrompt});

  Future<Res<String>> generate(String prompt, {String? systemPrompt}) =>
      chat([AiUserMessage(content: prompt)], systemPrompt: systemPrompt);

  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    String? systemPrompt,
  });

  AiResponse parseResponse(dynamic responseData);

  Map<String, String> buildHeaders(AiProviderConfig config);

  String buildUrl(AiProviderConfig config);

  AiProviderConfig buildConfig(AiApiKey row);

  /// 从数据库读取当前服务商的 Key 行
  Future<AiApiKey?> getKeyRow() =>
      AiDatabase.instance.aiApiKeyDao.getByProvider(providerKey);
}

class AiFactory {
  static AiBase? create(String source) {
    switch (source) {
      case 'siliconFlow':
        return SiliconFlowAi();
      case 'doubao':
        return DoubaoAi();
      case 'gemini':
        return GeminiAi();
      default:
        return null;
    }
  }

  static AiBase? createFromConfig(AiProviderConfig config) {
    if (config is SiliconFlowConfig) return SiliconFlowAi();
    if (config is DoubaoConfig) return DoubaoAi();
    if (config is GeminiConfig) return GeminiAi();
    return null;
  }
}

// ─────────────────────────────────────────────────────────
// SiliconFlow
// ─────────────────────────────────────────────────────────

class SiliconFlowAi extends AiBase {
  @override
  String get sourceName => 'SiliconFlow';

  @override
  String get providerKey => 'siliconFlow';

  @override
  AiProviderConfig buildConfig(AiApiKey row) => SiliconFlowConfig(
    apiKey: row.apiKey,
    model: row.model ?? 'THUDM/GLM-4-9B-0414',
    baseUrl: row.baseUrl ?? 'https://api.siliconflow.cn/v1',
  );

  @override
  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    String? systemPrompt,
  }) {
    final allMessages = <AiMessage>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      allMessages.add(AiSystemMessage(content: systemPrompt));
    }
    allMessages.addAll(messages);
    return {
      'model': 'THUDM/GLM-4-9B-0414',
      'messages': allMessages.map((m) => m.toJson()).toList(),
    };
  }

  @override
  AiResponse parseResponse(dynamic responseData) {
    final model = SfChatModel.fromJson(responseData as Map<String, dynamic>);
    return SfAiResponse(
      content: model.content,
      usage: SfAiUsage(
        promptTokens: model.usage.promptTokens,
        completionTokens: model.usage.completionTokens,
        totalTokens: model.usage.totalTokens,
      ),
    );
  }

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${config.apiKey}',
  };

  @override
  String buildUrl(AiProviderConfig config) =>
      '${config.baseUrl ?? "https://api.siliconflow.cn/v1"}/chat/completions';

  @override
  Future<Res<String>> chat(
    List<AiMessage> messages, {
    String? systemPrompt,
  }) async {
    try {
      final keyRow = await getKeyRow();
      if (keyRow == null || !keyRow.isEnabled) {
        return Res.error('SiliconFlow API Key 未配置或已禁用');
      }
      final config = buildConfig(keyRow);
      final response = await AppDio().request(
        buildUrl(config),
        data: buildRequest(messages, systemPrompt: systemPrompt),
        options: Options(
          method: 'POST',
          headers: buildHeaders(config),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return Res(parseResponse(response.data).content);
    } catch (e) {
      return Res.error(e.toString());
    }
  }
}

// ─────────────────────────────────────────────────────────
// Doubao
// ─────────────────────────────────────────────────────────

class DoubaoAi extends AiBase {
  @override
  String get sourceName => 'Doubao';

  @override
  String get providerKey => 'doubao';

  @override
  AiProviderConfig buildConfig(AiApiKey row) => DoubaoConfig(
    apiKey: row.apiKey,
    model: row.model ?? 'doubao-1-5-lite-32k-250115',
    baseUrl: row.baseUrl ?? 'https://ark.cn-beijing.volces.com/api/v3',
  );

  @override
  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    String? systemPrompt,
  }) {
    final allMessages = <AiMessage>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      allMessages.add(AiSystemMessage(content: systemPrompt));
    }
    allMessages.addAll(messages);
    return {
      'model': 'doubao-1-5-lite-32k-250115',
      'messages': allMessages.map((m) => m.toJson()).toList(),
    };
  }

  @override
  AiResponse parseResponse(dynamic responseData) {
    final model = DbChatModel.fromJson(responseData as Map<String, dynamic>);
    return DoubaoAiResponse(
      content: model.content,
      usage: DoubaoAiUsage(
        promptTokens: model.usage.promptTokens,
        completionTokens: model.usage.completionTokens,
        totalTokens: model.usage.totalTokens,
      ),
    );
  }

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${config.apiKey}',
  };

  @override
  String buildUrl(AiProviderConfig config) =>
      '${config.baseUrl ?? "https://ark.cn-beijing.volces.com/api/v3"}/chat/completions';

  @override
  Future<Res<String>> chat(
    List<AiMessage> messages, {
    String? systemPrompt,
  }) async {
    try {
      final keyRow = await getKeyRow();
      if (keyRow == null || !keyRow.isEnabled) {
        return Res.error('Doubao API Key 未配置或已禁用');
      }
      final config = buildConfig(keyRow);
      final response = await AppDio().request(
        buildUrl(config),
        data: buildRequest(messages, systemPrompt: systemPrompt),
        options: Options(
          method: 'POST',
          headers: buildHeaders(config),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return Res(parseResponse(response.data).content);
    } catch (e) {
      return Res.error(e.toString());
    }
  }
}

// ─────────────────────────────────────────────────────────
// Gemini
// ─────────────────────────────────────────────────────────

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
    String? systemPrompt,
  }) {
    final contents = <Map<String, dynamic>>[];
    for (final message in messages) {
      contents.add({
        'role': message.role == 'assistant' ? 'model' : message.role,
        'parts': [
          {'text': message.content},
        ],
      });
    }
    return {
      'contents': contents,
      'systemInstruction': systemPrompt != null
          ? {
              'parts': [
                {'text': systemPrompt},
              ],
            }
          : null,
      'generationConfig': {
        'temperature': 0.9,
        'topP': 0.95,
        'topK': 40,
        'maxOutputTokens': 2048,
      },
    };
  }

  @override
  AiResponse parseResponse(dynamic responseData) {
    final model = GmGenerateContentModel.fromJson(
      responseData as Map<String, dynamic>,
    );
    return GeminiAiResponse(
      content: model.content,
      usage: GeminiAiUsage(
        promptTokens: model.usageMetadata.promptTokenCount,
        completionTokens: model.usageMetadata.candidatesTokenCount,
        totalTokens: model.usageMetadata.totalTokenCount,
      ),
    );
  }

  @override
  Map<String, String> buildHeaders(AiProviderConfig config) => {
    'Content-Type': 'application/json',
  };

  @override
  String buildUrl(AiProviderConfig config) =>
      '${config.baseUrl ?? "https://generativelanguage.googleapis.com/v1beta"}/models/${config.model}:generateContent';

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
        data: buildRequest(messages, systemPrompt: systemPrompt),
        options: Options(
          method: 'POST',
          headers: buildHeaders(config),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return Res(parseResponse(response.data).content);
    } catch (e) {
      return Res.error(e.toString());
    }
  }
}

// ─────────────────────────────────────────────────────────
// Response / Usage 数据类
// ─────────────────────────────────────────────────────────

class SfAiResponse extends AiResponse {
  final SfAiUsage usage;

  const SfAiResponse({required super.content, required this.usage});
}

class SfAiUsage extends AiUsage {
  const SfAiUsage({
    required super.promptTokens,
    required super.completionTokens,
    required super.totalTokens,
  });
}

class DoubaoAiResponse extends AiResponse {
  final DoubaoAiUsage usage;

  const DoubaoAiResponse({required super.content, required this.usage});
}

class DoubaoAiUsage extends AiUsage {
  const DoubaoAiUsage({
    required super.promptTokens,
    required super.completionTokens,
    required super.totalTokens,
  });
}

class GeminiAiResponse extends AiResponse {
  final GeminiAiUsage usage;

  const GeminiAiResponse({required super.content, required this.usage});
}

class GeminiAiUsage extends AiUsage {
  const GeminiAiUsage({
    required super.promptTokens,
    required super.completionTokens,
    required super.totalTokens,
  });
}
