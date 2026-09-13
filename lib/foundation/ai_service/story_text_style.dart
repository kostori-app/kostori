// 酒馆正文的沉浸式文字样式（引号高亮 / 阴影 / 字体 / 字号），全局持久化。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoryTextStyle {
  /// 引号对白高亮着色
  final bool highlightQuotes;

  /// 文字阴影
  final bool shadow;

  /// 使用系统字体（关闭时用衬线字体）
  final bool systemFont;

  /// 斜体（对白斜体），默认关闭
  final bool italic;

  /// 字号缩放
  final double fontScale;

  const StoryTextStyle({
    this.highlightQuotes = true,
    this.shadow = false,
    this.systemFont = true,
    this.italic = false,
    this.fontScale = 1.0,
  });

  StoryTextStyle copyWith({
    bool? highlightQuotes,
    bool? shadow,
    bool? systemFont,
    bool? italic,
    double? fontScale,
  }) => StoryTextStyle(
    highlightQuotes: highlightQuotes ?? this.highlightQuotes,
    shadow: shadow ?? this.shadow,
    systemFont: systemFont ?? this.systemFont,
    italic: italic ?? this.italic,
    fontScale: fontScale ?? this.fontScale,
  );

  factory StoryTextStyle.fromJson(Map<String, dynamic> json) => StoryTextStyle(
    highlightQuotes: json['highlightQuotes'] as bool? ?? true,
    shadow: json['shadow'] as bool? ?? false,
    systemFont: json['systemFont'] as bool? ?? true,
    italic: json['italic'] as bool? ?? false,
    fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
  );

  Map<String, dynamic> toJson() => {
    'highlightQuotes': highlightQuotes,
    'shadow': shadow,
    'systemFont': systemFont,
    'italic': italic,
    'fontScale': fontScale,
  };
}

class StoryTextStyleStore extends ChangeNotifier {
  static final StoryTextStyleStore instance = StoryTextStyleStore._();

  StoryTextStyleStore._();

  static const _kKey = 'story_text_style';

  StoryTextStyle _style = const StoryTextStyle();
  bool _loaded = false;

  StoryTextStyle get style => _style;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _style = StoryTextStyle.fromJson(decoded.cast<String, dynamic>());
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  Future<void> update(StoryTextStyle style) async {
    _style = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(style.toJson()));
  }
}
