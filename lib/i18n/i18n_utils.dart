import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';

class I18nUtils {
  static void updateLocale() {
    var lang = appdata.settings['language'];

    if (lang == 'system') {
      LocaleSettings.useDeviceLocale();
      return;
    }

    switch (lang) {
      case 'zh-CN':
        LocaleSettings.setLocale(AppLocale.zhCn);
        break;
      case 'zh-TW':
        LocaleSettings.setLocale(AppLocale.zhTw);
        break;
      case 'en-US':
        LocaleSettings.setLocale(AppLocale.en);
        break;
      default:
        LocaleSettings.useDeviceLocale();
    }
  }

  static Future<void> init() async {
    // 读取保存的语言设置
    var lang =
        appdata.settings['language']; // 'system', 'zh-CN', 'zh-TW', 'en' 等

    if (lang == 'system') {
      await LocaleSettings.useDeviceLocale();
    } else {
      // slang 会自动匹配 Raw string 到 AppLocale
      await LocaleSettings.setLocaleRaw(lang);
    }
  }

  /// 翻译 - 直接用 t 对象
  static String translate(String key) {
    return t[key]; // ← 用中括号访问！
  }

  /// 带参数翻译
  static String translateWithParams(String key, Map<String, Object> params) {
    var text = translate(key);
    params.forEach((k, v) {
      text = text.replaceAll('@$k', v.toString());
      text = text.replaceAll('{$k}', v.toString());
    });
    return text;
  }
}

extension I18nStringExtension on String {
  String get tll => I18nUtils.translate(this);

  String tlp(Map<String, Object> values) {
    return I18nUtils.translateWithParams(this, values);
  }
}
