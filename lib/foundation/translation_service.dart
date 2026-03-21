import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_base.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/foundation/translation/sort.dart';
import 'package:kostori/foundation/translation/translation_models.dart';
import 'package:kostori/foundation/translation/translation_source.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/utils/translations.dart';

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
      _ => _translateWithBing(text, targetLanguage),
    };
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
      if (ai == null) return Res.error('未知服务商: $provider');

      final config = await AiDatabase.instance.aiConfigDao.getById(1);

      final baseSystemPrompt = config?.systemPrompt ?? '';

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
      return Res.error(e.toString());
    }
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
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';
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
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';
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
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';
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

class TranslationController extends ChangeNotifier {
  bool _isTranslating = false;
  String? _translatedText;
  String? _rawTranslatedText;
  bool _isTranslationComplete = false;

  bool get isTranslating => _isTranslating;

  String? get translatedText => _translatedText;

  String? get rawTranslatedText => _rawTranslatedText;

  bool get isTranslationComplete => _isTranslationComplete;

  bool get hasTranslation => _translatedText != null;

  // 服务
  final TranslationService _translationService = TranslationService();

  void _setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  Future<void> translate(String text, {String? targetLanguage}) async {
    Log.info('TranslationController', '开始翻译，文本长度: ${text.length}');
    if (_isTranslating) {
      Log.warning('TranslationController', '翻译正在进行中，忽略此次请求');
      return;
    }

    _setState(() {
      _isTranslating = true;
      _isTranslationComplete = false;
      _rawTranslatedText = null;
      _translatedText = null;
    });

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
      _setState(() {
        _rawTranslatedText = result.data;
        _translatedText = _rawTranslatedText;
        _isTranslating = false;
        _isTranslationComplete = true;
      });
    } else {
      Log.error('TranslationController', '翻译失败: ${result.errorMessage}');
      _setState(() {
        _rawTranslatedText = 'translate failed please try again later'.tl;
        _translatedText = _rawTranslatedText;
        _isTranslating = false;
        _isTranslationComplete = true;
      });
    }
  }

  void clearTranslation() {
    _setState(() {
      _translatedText = null;
      _rawTranslatedText = null;
      _isTranslationComplete = false;
    });
  }
}
