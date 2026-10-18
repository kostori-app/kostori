import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_factory.dart';
import 'package:kostori/foundation/ai_service/role_management.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/foundation/provider_container.dart';
import 'package:kostori/foundation/translation/sort.dart';
import 'package:kostori/foundation/translation/translation_models.dart';
import 'package:kostori/foundation/translation/translation_source.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();

  factory TranslationService() => _instance;

  TranslationService._internal();

  static const int _googleMaxChunkChars = 2000;
  static const int _googleMaxConcurrency = 3;

  String? savedLang = appdata.implicitData['currentLanguage'];

  String _getCurrentLanguage(String? targetLanguage) =>
      targetLanguage ?? savedLang ?? translationSorts.first.extData;

  Future<Res<String>> translate(String text, {String? targetLanguage}) async {
    final source = TranslationSourceExt.fromString(
      appdata.settings['translationSource'] ?? 'bing',
    );
    return switch (source) {
      TranslationSource.bing => _translateWithBing(text, targetLanguage),
      TranslationSource.google => _translateWithGoogle(text, targetLanguage),
      TranslationSource.deepl => _translateWithDeepl(text, targetLanguage),
      TranslationSource.siliconFlow => _translateWithAi(
        'siliconFlow',
        text,
        targetLanguage,
      ),
      TranslationSource.doubao => _translateWithAi(
        'doubao',
        text,
        targetLanguage,
      ),
      TranslationSource.gemini => _translateWithAi(
        'gemini',
        text,
        targetLanguage,
      ),
      TranslationSource.deepseek => _translateWithAi(
        'deepseek',
        text,
        targetLanguage,
      ),
      TranslationSource.qiniu => _translateWithAi(
        'qiniu',
        text,
        targetLanguage,
      ),
      TranslationSource.openrouter => _translateWithAi(
        'openrouter',
        text,
        targetLanguage,
      ),
      TranslationSource.ohmygpt => _translateWithAi(
        'ohmygpt',
        text,
        targetLanguage,
      ),
      _ => _translateWithBing(text, targetLanguage),
    };
  }

  static String getPoweredName() {
    final translationSource =
        TranslationSourceExt.fromString(
          appdata.settings['translationSource'] ?? 'bing',
        ) ??
        TranslationSource.bing;

    final powered = switch (translationSource) {
      TranslationSource.bing => 'Bing',
      TranslationSource.google => 'Google',
      TranslationSource.deepl => 'Deepl',
      TranslationSource.siliconFlow => 'SiliconFlow',
      TranslationSource.doubao => '火山引擎',
      TranslationSource.gemini => 'Gemini',
      TranslationSource.deepseek => 'Deepseek',
      TranslationSource.qiniu => 'qiniu',
      TranslationSource.openrouter => 'openrouter',
      TranslationSource.ohmygpt => 'ohmygpt',
    };

    return powered;
  }

  // ─── AI 翻译（统一用 AiBase）──────────────

  Future<Res<String>> _translateWithAi(
    String provider,
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) return const Res('');

      final ai = AiFactory.create(provider);
      if (ai == null) {
        return Res.error(t.unknownServiceProvider(provider: provider));
      }

      await PromptInjectionStore.instance.ensureLoaded();
      final injection = PromptInjectionStore.instance.findById(
        kInjectionTranslator,
      );
      final baseSystemPrompt = injection?.content ?? aiTranslatePrompt;

      final currentExtData = _getCurrentLanguage(targetLanguage);
      final currentLabel = translationSorts.labelByExtData(currentExtData);

      final processedSystemPrompt = baseSystemPrompt.replaceAll(
        '@a',
        currentLabel,
      );
      final userPrompt = '翻译为$currentLabel（仅输出译文内容）：$text';

      final result = await ai.generate(
        userPrompt,
        systemPrompt: processedSystemPrompt.isNotEmpty
            ? processedSystemPrompt
            : null,
      );

      if (!result.success) return result;
      if (result.data.isEmpty) {
        return Res.error('Empty $provider translation response');
      }
      return Res(result.data);
    } catch (e) {
      Log.warning('TranslationService', e.toString());
      return Res.error(_aiTranslateErrorMessage(e));
    }
  }

  /// 将 AI 翻译的异常映射为清晰的 i18n 提示
  String _aiTranslateErrorMessage(Object error) {
    final raw = aiErrorMessageOf(error);
    final lower = raw.toLowerCase();
    if (lower.contains('location is not supported') ||
        (lower.contains('permission_denied') && lower.contains('location'))) {
      return t.translationErrorRegionNotSupported;
    }
    if (lower.contains('model must be one of') ||
        lower.contains('not a supported model') ||
        lower.contains('invalid model') ||
        lower.contains('model not found') ||
        lower.contains('unknown model')) {
      return t.translationErrorModelNotSupported;
    }
    if (lower.contains('invalid api key') ||
        lower.contains('api key not valid') ||
        lower.contains('unauthorized') ||
        lower.contains('authentication failed') ||
        lower.contains('401') ||
        lower.contains('403')) {
      return t.translationErrorApiKeyInvalid;
    }
    if (lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('429') ||
        lower.contains('insufficient')) {
      return t.translationErrorRateLimited;
    }
    return '${t.translationErrorRequestFailed}：$raw';
  }

  // ─── Google ────────────────────────────────

  Future<Res<String>> _translateWithGoogle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) return const Res('');
      final chunks = _splitTextForGoogle(
        text,
        maxChunkChars: _googleMaxChunkChars,
      );
      if (chunks.length == 1) {
        return Res(await googleTranslateSingle(chunks.first, targetLanguage));
      }
      final buffer = StringBuffer();
      for (int i = 0; i < chunks.length; i += _googleMaxConcurrency) {
        final end = min(i + _googleMaxConcurrency, chunks.length);
        final results = await Future.wait(
          chunks
              .sublist(i, end)
              .map((s) => googleTranslateSingle(s, targetLanguage)),
        );
        for (final r in results) {
          buffer.write(r);
        }
      }
      return Res(buffer.toString());
    } catch (e) {
      Log.warning('TranslationService', e.toString());
      return Res.error(e.toString());
    }
  }

  Future<String> googleTranslateSingle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      final response = await AppDio().request(
        "https://translate.googleapis.com/translate_a/t",
        queryParameters: {
          "client": "gtx",
          "sl": "auto",
          "tl": _getCurrentLanguage(targetLanguage),
          "dt": "t",
          "q": text,
        },
        options: Options(
          method: 'GET',
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final res = _parseGoogleResponse(response.data);
      if (res.isEmpty) throw Exception('Empty google translation response');
      return res;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ??
          e.message ??
          t.networkRequestFailed;
      App.rootContext.showMessage(message: message);
      rethrow;
    }
  }

  // ─── Bing ──────────────────────────────────

  Future<Res<String>> _translateWithBing(
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) return const Res('');
      return Res(await bingTranslateSingle(text, targetLanguage));
    } catch (e) {
      Log.warning('TranslationService', e.toString());
      return Res.error(e.toString());
    }
  }

  Future<String> bingTranslateSingle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      final auth = await AppDio().request(
        'https://edge.microsoft.com/translate/auth',
        options: Options(method: 'GET'),
      );
      if (auth.statusCode != 200) throw Exception('Auth acquisition error');

      final response = await AppDio().request(
        "https://api-edge.cognitive.microsofttranslator.com/translate",
        data: [
          {"Text": text},
        ],
        queryParameters: {
          "api-version": "3.0",
          "from": "",
          "to": _getCurrentLanguage(targetLanguage),
        },
        options: Options(
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.data}',
          },
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final list = MsTranslatorModel.listFromJson(response.data);
      final res = list.map((e) => e.translations.first.text).join('');
      if (res.isEmpty) throw Exception('Empty bing translation response');
      return res;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ??
          e.message ??
          t.networkRequestFailed;
      App.rootContext.showMessage(message: message);
      rethrow;
    }
  }

  // ─── DeepL ─────────────────────────────────

  Future<Res<String>> _translateWithDeepl(
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) return const Res('');
      return Res(await deeplTranslateSingle(text, targetLanguage));
    } catch (e) {
      Log.warning('TranslationService', e.toString());
      return Res.error(e.toString());
    }
  }

  Future<String> deeplTranslateSingle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      final apiKey = appdata.settings['deeplKey'] as String?;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('DeepL not configured');
      }

      final response = await AppDio().request(
        "https://api-free.deepl.com/v2/translate",
        data: {
          "text": [text],
          "target_lang": "ZH",
        },
        options: Options(
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'DeepL-Auth-Key $apiKey',
          },
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final res = DeepLTranslationModel.fromJson(response.data).content;
      if (res.isEmpty) throw Exception('Empty deepl translation response');
      return res;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ??
          e.message ??
          t.networkRequestFailed;
      App.rootContext.showMessage(message: message);
      rethrow;
    }
  }

  // ─── 工具 ──────────────────────────────────

  List<String> _splitTextForGoogle(String text, {int maxChunkChars = 2000}) {
    if (text.length <= maxChunkChars) return [text];
    const boundaries = {
      '\n',
      '\r',
      '。',
      '！',
      '？',
      '；',
      '，',
      '、',
      '.',
      '!',
      '?',
      ';',
      ':',
      ' ',
    };
    final chunks = <String>[];
    int index = 0;
    while (index < text.length) {
      final remaining = text.length - index;
      int take = remaining <= maxChunkChars ? remaining : maxChunkChars;
      String slice = text.substring(index, index + take);
      if (remaining > maxChunkChars) {
        int cut = -1;
        for (int i = slice.length - 1; i >= 0; i--) {
          if (boundaries.contains(slice[i])) {
            cut = i + 1;
            break;
          }
        }
        if (cut <= 0) cut = slice.length;
        slice = slice.substring(0, cut);
        take = slice.length;
      }
      chunks.add(slice);
      index += take;
    }
    return chunks;
  }

  String _parseGoogleResponse(dynamic data) {
    try {
      if (data is! List || data.isEmpty) return '';
      final first = data[0];
      if (first is List) {
        final buffer = StringBuffer();
        for (final item in first) {
          if (item is List && item.isNotEmpty && item[0] is String) {
            buffer.write(item[0] as String);
          }
        }
        final text = buffer.toString();
        if (text.isNotEmpty) return text;
      }
      if (first is List && first.isNotEmpty && first[0] is String) {
        return first[0] as String;
      }
    } catch (e, st) {
      Log.error('TranslationService', 'Error parsing Google response: $e\n$st');
    }
    return '';
  }
}

@immutable
class TranslationState {
  final bool isTranslating;
  final String? translatedText;
  final String? rawTranslatedText;
  final bool isTranslationComplete;

  const TranslationState({
    this.isTranslating = false,
    this.translatedText,
    this.rawTranslatedText,
    this.isTranslationComplete = false,
  });

  bool get hasTranslation => translatedText != null;

  TranslationState copyWith({
    bool? isTranslating,
    Object? translatedText = _unset,
    Object? rawTranslatedText = _unset,
    bool? isTranslationComplete,
  }) => TranslationState(
    isTranslating: isTranslating ?? this.isTranslating,
    translatedText: identical(translatedText, _unset)
        ? this.translatedText
        : translatedText as String?,
    rawTranslatedText: identical(rawTranslatedText, _unset)
        ? this.rawTranslatedText
        : rawTranslatedText as String?,
    isTranslationComplete: isTranslationComplete ?? this.isTranslationComplete,
  );
}

const _unset = Object();

class TranslationNotifier extends Notifier<TranslationState> {
  TranslationNotifier(this.scopeKey);

  final String scopeKey;
  final TranslationService _translationService = TranslationService();

  @override
  TranslationState build() => const TranslationState();

  Future<void> translate(String text, {String? targetLanguage}) async {
    Log.info('TranslationController', '开始翻译，文本长度: ${text.length}');
    if (state.isTranslating) {
      Log.warning('TranslationController', '翻译正在进行中，忽略此次请求');
      return;
    }

    state = state.copyWith(
      isTranslating: true,
      isTranslationComplete: false,
      rawTranslatedText: null,
      translatedText: null,
    );

    final textToTranslate = text;
    Log.info('TranslationController', '待翻译文本: $textToTranslate');
    Log.info('TranslationController', '使用普通翻译');
    final result = await _translationService.translate(
      textToTranslate,
      targetLanguage: targetLanguage,
    );
    Log.info(
      'TranslationController',
      '普通翻译结果: ${result.success ? "成功" : "失败"}, 数据长度: ${result.success ? result.data.length : result.errorMessage?.length}',
    );
    if (result.success) {
      state = state.copyWith(
        rawTranslatedText: result.data,
        translatedText: result.data,
        isTranslating: false,
        isTranslationComplete: true,
      );
    } else {
      Log.error('TranslationController', '翻译失败: ${result.errorMessage}');
      final errorText =
          result.errorMessage ?? t.translationFailedPleaseTryAgainLater;
      state = state.copyWith(
        rawTranslatedText: errorText,
        translatedText: errorText,
        isTranslating: false,
        isTranslationComplete: true,
      );
    }
  }

  void clearTranslation() {
    state = state.copyWith(
      translatedText: null,
      rawTranslatedText: null,
      isTranslationComplete: false,
    );
  }
}

final translationControllerProvider =
    NotifierProvider.family<TranslationNotifier, TranslationState, String>(
      TranslationNotifier.new,
    );

class TranslationController {
  TranslationController([String? scopeKey])
    : scopeKey = scopeKey ?? 'translation-${_nextScope++}';

  static int _nextScope = 0;
  final String scopeKey;

  TranslationState get state =>
      providerContainer.read(translationControllerProvider(scopeKey));

  bool get isTranslating => state.isTranslating;

  String? get translatedText => state.translatedText;

  String? get rawTranslatedText => state.rawTranslatedText;

  bool get isTranslationComplete => state.isTranslationComplete;

  bool get hasTranslation => state.hasTranslation;

  TranslationNotifier get _notifier =>
      providerContainer.read(translationControllerProvider(scopeKey).notifier);

  Future<void> translate(String text, {String? targetLanguage}) =>
      _notifier.translate(text, targetLanguage: targetLanguage);

  void clearTranslation() => _notifier.clearTranslation();

  void dispose() =>
      providerContainer.invalidate(translationControllerProvider(scopeKey));
}
