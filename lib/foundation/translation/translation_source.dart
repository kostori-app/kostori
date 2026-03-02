enum TranslationSource { bing, google, deepl, siliconFlow, doubao, gemini }

extension TranslationSourceExt on TranslationSource {
  String get asString {
    switch (this) {
      case TranslationSource.bing:
        return 'bing';
      case TranslationSource.google:
        return 'google';
      case TranslationSource.deepl:
        return 'deepl';
      case TranslationSource.siliconFlow:
        return 'siliconFlow';
      case TranslationSource.doubao:
        return 'doubao';
      case TranslationSource.gemini:
        return 'gemini';
    }
  }

  static TranslationSource? fromString(String value) {
    switch (value) {
      case 'bing':
        return TranslationSource.bing;
      case 'google':
        return TranslationSource.google;
      case 'deepl':
        return TranslationSource.deepl;
      case 'siliconFlow':
        return TranslationSource.siliconFlow;
      case 'doubao':
        return TranslationSource.doubao;
      case 'gemini':
        return TranslationSource.gemini;
      default:
        return null;
    }
  }
}
