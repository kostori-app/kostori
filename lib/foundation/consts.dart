import 'app.dart';

import 'package:flutter/material.dart';

const changePoint = 600;

const changePoint2 = 1300;

const webUA =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36";

// Bangumi API 文档要求的UA格式
Map<String, String> bangumiHTTPHeader = {
  'user-agent':
      'axlmly/kostori/${App.version} (Android) (https://github.com/kostori-app/kostori)',
  'referer': '',
};

Map<int, String> ratingLabels = {
  1: '不忍直视',
  2: '很差',
  3: '差',
  4: '较差',
  5: '不过不失',
  6: '还行',
  7: '推荐',
  8: '力荐',
  9: '神作',
  10: '超神作',
};

class StyleString {
  static const double cardSpace = 8;
  static const double safeSpace = 12;
  static BorderRadius mdRadius = BorderRadius.circular(10);
  static const Radius imgRadius = Radius.circular(10);
  static const double aspectRatio = 16 / 10;
}
