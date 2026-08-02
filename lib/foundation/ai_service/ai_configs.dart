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
  final Map<String, String> customHeaders;
  final Map<String, dynamic> extraBodyFields;
  final List<String> stopSequences;

  const OpenAiCompatibleConfig({
    required this.source,
    required super.apiKey,
    required super.model,
    required String baseUrl,
    this.customHeaders = const {},
    this.extraBodyFields = const {},
    this.stopSequences = const [],
  }) : super(baseUrl: baseUrl);

  factory OpenAiCompatibleConfig.fromJson(Map<String, dynamic> json) =>
      OpenAiCompatibleConfig(
        source: json['source'] ?? '',
        apiKey: json['apiKey'] ?? '',
        model: json['model'] ?? '',
        baseUrl: json['baseUrl'] ?? '',
        customHeaders: json['customHeaders'] is Map
            ? (json['customHeaders'] as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              )
            : const {},
        extraBodyFields: json['extraBodyFields'] is Map
            ? (json['extraBodyFields'] as Map).cast<String, dynamic>()
            : const {},
        stopSequences: json['stopSequences'] is List
            ? (json['stopSequences'] as List).whereType<String>().toList()
            : const [],
      );

  /// 应用助手档案的自定义请求设定（⑤），返回新的配置实例
  OpenAiCompatibleConfig withRequestOverrides({
    String? baseUrlOverride,
    String? apiKeyOverride,
    Map<String, String> customHeaders = const {},
    Map<String, dynamic> extraBodyFields = const {},
    List<String> stopSequences = const [],
  }) => OpenAiCompatibleConfig(
    source: source,
    apiKey: (apiKeyOverride == null || apiKeyOverride.isEmpty)
        ? apiKey
        : apiKeyOverride,
    model: model,
    baseUrl: (baseUrlOverride == null || baseUrlOverride.isEmpty)
        ? (baseUrl ?? '')
        : baseUrlOverride,
    customHeaders: {...this.customHeaders, ...customHeaders},
    extraBodyFields: {...this.extraBodyFields, ...extraBodyFields},
    stopSequences: [...this.stopSequences, ...stopSequences],
  );

  @override
  Map<String, dynamic> toJson() => {
    'source': source,
    'apiKey': apiKey,
    'model': model,
    'baseUrl': baseUrl,
    if (customHeaders.isNotEmpty) 'customHeaders': customHeaders,
    if (extraBodyFields.isNotEmpty) 'extraBodyFields': extraBodyFields,
    if (stopSequences.isNotEmpty) 'stopSequences': stopSequences,
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
