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
    switch (json['source'] as String?) {
      case 'gemini':
        return GeminiConfig.fromJson(json);
      default:
        // SF / Doubao / DeepSeek 等 OpenAI 兼容格式统一走这里
        if (json['source'] != null) {
          return OpenAiCompatibleConfig.fromJson(json);
        }
        return null;
    }
  }
}

class OpenAiCompatibleConfig extends AiProviderConfig {
  final String source;

  const OpenAiCompatibleConfig({
    required this.source,
    required super.apiKey,
    required super.model,
    required String baseUrl,
  }) : super(baseUrl: baseUrl);

  factory OpenAiCompatibleConfig.fromJson(Map<String, dynamic> json) =>
      OpenAiCompatibleConfig(
        source: json['source'] ?? '',
        apiKey: json['apiKey'] ?? '',
        model: json['model'] ?? '',
        baseUrl: json['baseUrl'] ?? '',
      );

  @override
  Map<String, dynamic> toJson() => {
    'source': source,
    'apiKey': apiKey,
    'model': model,
    'baseUrl': baseUrl,
  };
}

class GeminiConfig extends AiProviderConfig {
  const GeminiConfig({
    String? apiKey,
    super.model = 'gemini-2.0-flash',
    super.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : super(apiKey: apiKey ?? '');

  factory GeminiConfig.fromJson(Map<String, dynamic> json) => GeminiConfig(
    apiKey: json['apiKey'],
    model: json['model'] ?? 'gemini-2.0-flash',
    baseUrl: json['baseUrl'],
  );

  @override
  Map<String, dynamic> toJson() => {
    'source': 'gemini',
    'apiKey': apiKey,
    'model': model,
    'baseUrl': baseUrl,
  };
}
