/// 服务商编辑器共用的配置，内置和自定义使用相同字段。
class AiProviderSettings {
  const AiProviderSettings({
    required this.source,
    required this.name,
    required this.baseUrl,
    this.apiKey = '',
    this.model = '',
    this.apiFormat = 'openai',
    this.modelsUrl = '',
    this.balanceUrl = '',
    this.balanceKey = '',
    this.isEnabled = true,
    this.isNew = false,
    this.fixedApiFormat = false,
  });

  final String source;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String apiFormat;
  final String modelsUrl;
  final String balanceUrl;
  final String balanceKey;
  final bool isEnabled;
  final bool isNew;
  final bool fixedApiFormat;

  bool get isCustom => source.startsWith('custom_');
  String get provider => isCustom ? source.substring(7) : source;
  bool get isConfigured =>
      AiProviderApi.isHttpUrl(baseUrl) &&
      model.trim().isNotEmpty &&
      (apiKey.trim().isNotEmpty || isCustom);

  AiProviderSettings copyWith({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? apiFormat,
    String? modelsUrl,
    String? balanceUrl,
    String? balanceKey,
    bool? isEnabled,
    bool? isNew,
  }) => AiProviderSettings(
    source: source,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    apiFormat: apiFormat ?? this.apiFormat,
    modelsUrl: modelsUrl ?? this.modelsUrl,
    balanceUrl: balanceUrl ?? this.balanceUrl,
    balanceKey: balanceKey ?? this.balanceKey,
    isEnabled: isEnabled ?? this.isEnabled,
    isNew: isNew ?? this.isNew,
    fixedApiFormat: fixedApiFormat,
  );
}

/// 统一处理 API 根地址、版本路径和认证，避免拼出 /v1/v1/responses。
abstract final class AiProviderApi {
  static const formats = ['openai', 'openai_responses', 'gemini', 'claude'];

  static bool isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  static String baseUrl(String value) {
    final uri = Uri.parse(value.trim());
    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    path = path.replaceFirst(
      RegExp(r'/models/[^/]+:(?:generateContent|streamGenerateContent)$'),
      '',
    );
    for (final suffix in [
      '/chat/completions',
      '/responses',
      '/messages',
      '/models',
    ]) {
      if (path.endsWith(suffix)) {
        path = path.substring(0, path.length - suffix.length);
        break;
      }
    }
    return uri.replace(path: path).removeFragment().toString();
  }

  static String endpoint(String base, String path, {bool versioned = false}) {
    final uri = Uri.parse(baseUrl(base));
    var prefix = uri.path;
    final hasVersion = RegExp(r'/v\d+(?:alpha\d*|beta\d*)?$').hasMatch(prefix);
    if (!hasVersion && (versioned || uri.host == 'api.openai.com')) {
      prefix += '/v1';
    }
    return uri.replace(path: '$prefix/$path').toString();
  }

  static String modelsEndpoint(AiProviderSettings settings) {
    final base = baseUrl(settings.baseUrl);
    if (settings.modelsUrl.trim().isNotEmpty) {
      final override = settings.modelsUrl.trim();
      if (isHttpUrl(override)) return override;
      final uri = Uri.parse(base);
      return uri.replace(path: '${uri.path}/').resolve(override).toString();
    }
    return endpoint(
      base,
      'models',
      versioned:
          settings.apiFormat == 'claude' ||
          settings.apiFormat == 'openai_responses',
    );
  }

  static Map<String, String> headers(String apiFormat, String apiKey) => {
    'Content-Type': 'application/json',
    if (apiKey.isNotEmpty)
      if (apiFormat == 'gemini')
        'x-goog-api-key': apiKey
      else if (apiFormat == 'claude')
        'x-api-key': apiKey
      else
        'Authorization': 'Bearer $apiKey',
    if (apiFormat == 'claude') 'anthropic-version': '2023-06-01',
  };
}
