import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/foundation/translation/ai/doubao_chat_models.dart';
import 'package:kostori/foundation/translation/ai/gemini_chat_models.dart';
import 'package:kostori/foundation/translation/ai/sf_chat_models.dart';
import 'package:kostori/foundation/translation/sort.dart';
import 'package:kostori/foundation/translation/translation_models.dart';
import 'package:kostori/foundation/translation/translation_source.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/utils/translations.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();

  factory TranslationService() => _instance;

  TranslationService._internal();

  static const int _googleMaxChunkChars = 2000; // 单段最大字符数，留余量避免请求过大
  static const int _googleMaxConcurrency = 3; // 适量并发数，平衡速度与稳定性

  String? savedLang = appdata.implicitData['currentLanguage'];

  /// 获取当前翻译语言
  String _getCurrentLanguage(String? targetLanguage) {
    return targetLanguage ?? savedLang ?? translationSorts.first.extData;
  }

  Future<Res<String>> translate(String text, {String? targetLanguage}) async {
    final translationSource = TranslationSourceExt.fromString(
      appdata.settings['translationSource'] ?? 'bing',
    );
    return switch (translationSource) {
      TranslationSource.bing => _translateWithBing(text, targetLanguage),
      TranslationSource.google => _translateWithGoogle(text, targetLanguage),
      TranslationSource.deepl => _translateWithDeepl(text, targetLanguage),
      TranslationSource.siliconFlow => _translateWithSiliconFlow(
        text,
        targetLanguage,
      ),
      TranslationSource.doubao => _translateWithDoubao(text, targetLanguage),
      TranslationSource.gemini => _translateWithGemini(text, targetLanguage),
      _ => _translateWithBing(text, targetLanguage),
    };
  }

  Future<Res<String>> _translateWithGoogle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) {
        return const Res('');
      }

      final chunks = _splitTextForGoogle(
        text,
        maxChunkChars: _googleMaxChunkChars,
      );

      // 单段直接调用
      if (chunks.length == 1) {
        final translated = await googleTranslateSingle(
          chunks.first,
          targetLanguage,
        );
        return Res(translated);
      }

      // 分段并发翻译（按批次控制并发度，保证顺序拼接）
      final buffer = StringBuffer();
      for (int i = 0; i < chunks.length; i += _googleMaxConcurrency) {
        final end = min(i + _googleMaxConcurrency, chunks.length);
        final batch = chunks.sublist(i, end);
        final futures = batch
            .map((seg) => googleTranslateSingle(seg, targetLanguage))
            .toList();
        final results = await Future.wait(futures);
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

  Future<Res<String>> _translateWithBing(
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) {
        return const Res('');
      }

      final res = await bingTranslateSingle(text, targetLanguage);

      return Res(res);
    } catch (e) {
      Log.warning('TranslationService', e.toString());
      return Res.error(e.toString());
    }
  }

  Future<Res<String>> _translateWithDeepl(
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) {
        return const Res('');
      }

      final res = await deeplTranslateSingle(text, targetLanguage);

      return Res(res);
    } catch (e) {
      Log.warning('TranslationService', e.toString());
      return Res.error(e.toString());
    }
  }

  Future<Res<String>> _translateWithSiliconFlow(
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) {
        return const Res('');
      }

      final res = await siliconFlowTranslateSingle(text, targetLanguage);

      return Res(res);
    } catch (e) {
      Log.warning('TranslationService', e.toString());
      return Res.error(e.toString());
    }
  }

  Future<Res<String>> _translateWithGemini(
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) {
        return const Res('');
      }

      final res = await geminiTranslateSingle(text, targetLanguage);

      return Res(res);
    } catch (e) {
      Log.warning('TranslationService', e.toString());
      return Res.error(e.toString());
    }
  }

  Future<Res<String>> _translateWithDoubao(
    String text,
    String? targetLanguage,
  ) async {
    try {
      if (text.trim().isEmpty) {
        return const Res('');
      }

      final res = await doubaoTranslateSingle(text, targetLanguage);

      return Res(res);
    } catch (e) {
      Log.warning('TranslationService', e.toString());
      return Res.error(e.toString());
    }
  }

  // 单段 Google 翻译，带重试与超时
  Future<String> googleTranslateSingle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      var params = {
        "client": "gtx",
        "sl": "auto",
        "tl": _getCurrentLanguage(targetLanguage),
        "dt": "t",
        "q": text,
      };
      final response = await AppDio().request(
        "https://translate.googleapis.com/translate_a/t",
        queryParameters: params,
        options: Options(
          method: 'GET',
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final res = _parseGoogleResponse(response.data);
      if (res.isEmpty) {
        throw Exception('Empty google translation response');
      }
      return res;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';

      App.rootContext.showMessage(message: message);
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> bingTranslateSingle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      var params = {
        "api-version": "3.0",
        "from": "",
        "to": _getCurrentLanguage(targetLanguage),
      };

      var data = [
        {"Text": text},
      ];

      final auth = await AppDio().request(
        'https://edge.microsoft.com/translate/auth',
        options: Options(method: 'GET'),
      );

      if (auth.statusCode != 200) {
        throw Exception('Auth acquisition error');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth.data}',
      };

      final response = await AppDio().request(
        "https://api-edge.cognitive.microsofttranslator.com/translate",
        data: data,
        queryParameters: params,
        options: Options(
          method: 'POST',
          headers: headers,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final list = MsTranslatorModel.listFromJson(response.data);
      final res = list.map((e) => e.translations.first.text).join('');
      if (res.isEmpty) {
        throw Exception('Empty bing translation response');
      }
      return res;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';

      App.rootContext.showMessage(message: message);
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> deeplTranslateSingle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      final configs = appdata.settings['translationConfig'] as List;
      final deeplConfig = configs.firstWhere(
        (e) => e['source'] == 'deepl',
        orElse: () => null,
      );

      final apiKey = deeplConfig['apiKey'];

      var data = {
        "text": [text],
        "target_lang": "ZH",
      };

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'DeepL-Auth-Key $apiKey',
      };

      final response = await AppDio().request(
        "https://api-free.deepl.com/v2/translate",
        data: data,
        options: Options(
          method: 'POST',
          headers: headers,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final json = DeepLTranslationModel.fromJson(response.data);
      final res = json.content;
      if (res.isEmpty) {
        throw Exception('Empty deepl translation response');
      }
      return res;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';

      App.rootContext.showMessage(message: message);
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> siliconFlowTranslateSingle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      final configs = appdata.settings['translationConfig'] as List;
      final siliconFlowConfig = configs.firstWhere(
        (e) => e['source'] == 'siliconFlow',
        orElse: () => null,
      );

      final isSiliconFlow = appdata.implicitData['isSiliconFlow'] ?? true;

      final contentTemplate = isSiliconFlow
          ? (siliconFlowConfig?['aiTranslatePrompt'] ??
                appdata.settings['aiTranslatePrompt'])
          : appdata.settings['aiTranslatePrompt'];

      final translationContentTemplate = "翻译为@a（仅输出译文内容）：";

      final currentExtData = _getCurrentLanguage(targetLanguage);

      final currentLabel = translationSorts.labelByExtData(currentExtData);

      final content = contentTemplate.replaceAll('@a', currentLabel);
      final processedTemplate = translationContentTemplate.replaceAll(
        '@a',
        currentLabel,
      );

      final translationContent = '$processedTemplate$text';

      final defaultModel = "THUDM/GLM-4-9B-0414";

      final model = isSiliconFlow
          ? (siliconFlowConfig?['model'] ?? defaultModel)
          : defaultModel;

      var data = {
        "model": model,
        "messages": [
          {"role": "system", "content": content},
          {"role": "user", "content": translationContent},
        ],
      };

      String auth;
      if (!isSiliconFlow) {
        final res = await AppDio().request(
          'https://api2.immersivetranslate.com/free-model/get-token?deviceId=fake-device-id',
          options: Options(method: 'GET'),
        );
        if (res.statusCode != 200) {
          throw Exception(res.statusMessage);
        }
        auth = res.data["data"] as String;
      } else {
        auth = siliconFlowConfig['apiKey'];
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $auth',
      };

      final String url = isSiliconFlow
          ? 'https://api.siliconflow.cn/v1/chat/completions'
          : 'https://aigw1.immersivetranslate.com/v1/free/chat/completions';

      final response = await AppDio().request(
        url,
        data: data,
        options: Options(
          method: 'POST',
          headers: headers,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final json = SfChatModel.fromJson(response.data);

      final res = json.content;

      if (res.isEmpty) {
        throw Exception('Empty siliconFlow translation response');
      }
      return res;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';

      App.rootContext.showMessage(message: message);
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> doubaoTranslateSingle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      final configs = appdata.settings['translationConfig'] as List;

      final doubaoConfig = configs.firstWhere(
        (e) => e['source'] == 'doubao',
        orElse: () => null,
      );

      final contentTemplate =
          doubaoConfig?['aiTranslatePrompt'] ??
          appdata.settings['aiTranslatePrompt'] ??
          '';

      final translationContentTemplate = "翻译为@a（仅输出译文内容）：";

      final currentExtData = _getCurrentLanguage(targetLanguage);

      final currentLabel = translationSorts.labelByExtData(currentExtData);

      final content = contentTemplate.replaceAll('@a', currentLabel);
      final processedTemplate = translationContentTemplate.replaceAll(
        '@a',
        currentLabel,
      );

      final translationContent = '$processedTemplate$text';

      final apiKey = doubaoConfig['apiKey'];

      final defaultModel = "doubao-1-5-lite-32k-250115";

      final model = doubaoConfig?['model'] ?? defaultModel;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

      var data = {
        "model": model,
        "messages": [
          {"role": "system", "content": content},
          {"role": "user", "content": translationContent},
        ],
      };

      final response = await AppDio().request(
        'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
        data: data,
        options: Options(
          method: 'POST',
          headers: headers,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final json = DbChatModel.fromJson(response.data);

      final res = json.content;

      if (res.isEmpty) {
        throw Exception('Empty doubao translation response');
      }
      return res;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';

      App.rootContext.showMessage(message: message);
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> geminiTranslateSingle(
    String text,
    String? targetLanguage,
  ) async {
    try {
      final configs = appdata.settings['translationConfig'] as List;

      final geminiConfig = configs.firstWhere(
        (e) => e['source'] == 'gemini',
        orElse: () => null,
      );

      final contentTemplate =
          geminiConfig?['aiTranslatePrompt'] ??
          appdata.settings['aiTranslatePrompt'] ??
          '';

      final translationContentTemplate = "翻译为@a（仅输出译文内容）：";

      final currentExtData = _getCurrentLanguage(targetLanguage);

      final currentLabel = translationSorts.labelByExtData(currentExtData);

      final content = contentTemplate.replaceAll('@a', currentLabel);
      final processedTemplate = translationContentTemplate.replaceAll(
        '@a',
        currentLabel,
      );

      final translationContent = '$processedTemplate$text';

      final defaultModel = "gemini-2.5-flash-lite";

      final model = geminiConfig?['model'] ?? defaultModel;

      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

      final apiKey = geminiConfig['apiKey'];

      var data = {
        "system_instruction": {
          "parts": [
            {"text": content},
          ],
        },
        "contents": [
          {
            "parts": [
              {"text": translationContent},
            ],
          },
        ],
      };

      final headers = {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      };

      final response = await AppDio().request(
        url,
        data: data,
        options: Options(
          method: 'POST',
          headers: headers,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final json = GmGenerateContentModel.fromJson(response.data);

      final res = json.content;

      if (res.isEmpty) {
        throw Exception('Empty gemini translation response');
      }
      return res;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';

      App.rootContext.showMessage(message: message);
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  List<String> _splitTextForGoogle(String text, {int maxChunkChars = 2000}) {
    if (text.length <= maxChunkChars) {
      return [text];
    }

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
          final ch = slice[i];
          if (boundaries.contains(ch)) {
            cut = i + 1; // 包含边界字符
            break;
          }
        }
        if (cut <= 0) {
          // 找不到自然边界，硬切
          cut = slice.length;
        }
        slice = slice.substring(0, cut);
        take = slice.length;
      }

      chunks.add(slice);
      index += take;
    }

    return chunks;
  }

  // 兼容不同返回格式的解析
  String _parseGoogleResponse(dynamic data) {
    try {
      if (data is List && data.isNotEmpty) {
        final first = data[0];

        // 典型结构：[[["译文","原文", ...], ["片段2", ...], ...], ...]
        if (first is List) {
          final buffer = StringBuffer();
          for (final item in first) {
            if (item is List && item.isNotEmpty && item[0] is String) {
              buffer.write(item[0] as String);
            }
          }
          final text = buffer.toString();
          if (text.isNotEmpty) {
            return text;
          }
        }

        // 退化结构：data[0][0] 直接是字符串
        if (data[0] is List &&
            (data[0] as List).isNotEmpty &&
            data[0][0] is String) {
          return data[0][0] as String;
        }
      }
    } catch (_) {
      // ignore
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
