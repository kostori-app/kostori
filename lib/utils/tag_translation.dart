/*
数据来自于:
https://github.com/EhTagTranslation/Database/tree/master/database

繁体中文由 @NeKoOuO (https://github.com/NeKoOuO) 提供
*/

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:kostori/utils/ext.dart';

import '../foundation/app.dart';

extension TagsTranslation on String {
  static final Map<String, Map<String, String>> _data = {};

  static Future<void> readData() async {
    if (App.locale.languageCode != "zh") {
      return;
    }
    var fileName = App.locale.countryCode == 'TW'
        ? "assets/tags_tw.json"
        : "assets/tags.json";
    var data = await rootBundle.load(fileName);
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    const JsonDecoder()
        .convert(const Utf8Decoder().convert(bytes))
        .forEach((key, value) {
      _data[key] = {};
      value.forEach((key1, value1) {
        _data[key]?[key1] = value1;
      });
    });
  }

  static bool _haveNamespace(String key) {
    return _data.containsKey(key);
  }
}
