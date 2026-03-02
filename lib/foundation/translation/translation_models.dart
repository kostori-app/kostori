class MsTranslatorModel {
  final MsDetectedLanguage detectedLanguage;
  final List<MsTranslation> translations;

  MsTranslatorModel({
    required this.detectedLanguage,
    required this.translations,
  });

  factory MsTranslatorModel.fromJson(Map<String, dynamic> json) {
    return MsTranslatorModel(
      detectedLanguage: MsDetectedLanguage.fromJson(json['detectedLanguage']),
      translations: (json['translations'] as List)
          .map((e) => MsTranslation.fromJson(e))
          .toList(),
    );
  }

  static List<MsTranslatorModel> listFromJson(List json) {
    return json.map((e) => MsTranslatorModel.fromJson(e)).toList();
  }
}

class MsDetectedLanguage {
  final String language;
  final double score;

  MsDetectedLanguage({required this.language, required this.score});

  factory MsDetectedLanguage.fromJson(Map<String, dynamic> json) {
    return MsDetectedLanguage(
      language: json['language'],
      score: (json['score'] as num).toDouble(),
    );
  }
}

class MsTranslation {
  final String text;
  final String to;

  MsTranslation({required this.text, required this.to});

  factory MsTranslation.fromJson(Map<String, dynamic> json) {
    return MsTranslation(text: json['text'], to: json['to']);
  }
}

class DeepLTranslationModel {
  final List<DeepLTranslation> translations;

  DeepLTranslationModel({required this.translations});

  factory DeepLTranslationModel.fromJson(Map<String, dynamic> json) {
    return DeepLTranslationModel(
      translations: (json['translations'] as List<dynamic>? ?? [])
          .map((e) => DeepLTranslation.fromJson(e))
          .toList(),
    );
  }
}

class DeepLTranslation {
  final String text;
  final String detectedSourceLanguage;

  DeepLTranslation({required this.text, required this.detectedSourceLanguage});

  factory DeepLTranslation.fromJson(Map<String, dynamic> json) {
    return DeepLTranslation(
      text: json['text'] ?? '',
      detectedSourceLanguage: json['detected_source_language'] ?? '',
    );
  }
}

extension DeepLTranslationResponseExt on DeepLTranslationModel {
  String get content => translations.isNotEmpty ? translations.first.text : '';
}
