enum TranslationSource {
  bing,
  google,
  deepl,
  siliconFlow,
  doubao,
  gemini,
  deepseek,
  qiniu,
  openrouter,
  ohmygpt,
}

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
      case TranslationSource.deepseek:
        return 'deepseek';
      case TranslationSource.qiniu:
        return 'qiniu';
      case TranslationSource.openrouter:
        return 'openrouter';
      case TranslationSource.ohmygpt:
        return 'ohmygpt';
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
      case 'deepseek':
        return TranslationSource.deepseek;
      case 'qiniu':
        return TranslationSource.qiniu;
      case 'openrouter':
        return TranslationSource.openrouter;
      case 'ohmygpt':
        return TranslationSource.ohmygpt;
      default:
        return null;
    }
  }
}
