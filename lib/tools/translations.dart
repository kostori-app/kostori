

import '../foundation/app.dart';

extension AppTranslation on String {
  String _translate() {
    var locale = App.locale;
    var key = "${locale.languageCode}_${locale.countryCode}";
    if (locale.languageCode == "en") {
      key = "en_US";
    }
    return (translations[key]?[this]) ?? this;
  }

  String tlParams(Map<String, String> values) {
    var res = _translate();
    for (var entry in values.entries) {
      res = res.replaceFirst("@${entry.key}", entry.value);
    }
    return res;
  }

  static late final Map<String, Map<String, String>> translations;
}