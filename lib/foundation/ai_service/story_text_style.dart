// 酒馆正文的沉浸式文字样式：引号 / 括号（动作）/ 斜体 / 加粗 各自可配颜色、透明度与
// 字体样式，另有引号字形、阴影、字体、字号。全局持久化。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 引号字形
enum StoryQuoteGlyph { curly, straight, corner, cornerSingle }

extension StoryQuoteGlyphX on StoryQuoteGlyph {
  (String, String) get pair => switch (this) {
    StoryQuoteGlyph.curly => ('“', '”'),
    StoryQuoteGlyph.straight => ('"', '"'),
    StoryQuoteGlyph.corner => ('「', '」'),
    StoryQuoteGlyph.cornerSingle => ('『', '』'),
  };

  String get label => switch (this) {
    StoryQuoteGlyph.curly => '“…”',
    StoryQuoteGlyph.straight => '"…"',
    StoryQuoteGlyph.corner => '「…」',
    StoryQuoteGlyph.cornerSingle => '『…』',
  };
}

/// 单类文本样式：明/暗颜色 + 透明度 + 字体样式
class StoryRoleStyle {
  /// 亮色模式颜色（ARGB）；null 表示跟随主题
  final int? light;

  /// 暗色模式颜色（ARGB）；null 表示跟随主题
  final int? dark;
  final double opacity;
  final String fontStyle; // normal | italic | bold

  const StoryRoleStyle({
    this.light,
    this.dark,
    this.opacity = 1.0,
    this.fontStyle = 'normal',
  });

  StoryRoleStyle copyWith({
    int? light,
    int? dark,
    double? opacity,
    String? fontStyle,
    bool clearColor = false,
  }) => StoryRoleStyle(
    light: clearColor ? null : (light ?? this.light),
    dark: clearColor ? null : (dark ?? this.dark),
    opacity: opacity ?? this.opacity,
    fontStyle: fontStyle ?? this.fontStyle,
  );

  factory StoryRoleStyle.fromJson(Map<String, dynamic> json) => StoryRoleStyle(
    light: (json['light'] as num?)?.toInt(),
    dark: (json['dark'] as num?)?.toInt(),
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    fontStyle: json['fontStyle']?.toString() ?? 'normal',
  );

  Map<String, dynamic> toJson() => {
    if (light != null) 'light': light,
    if (dark != null) 'dark': dark,
    'opacity': opacity,
    'fontStyle': fontStyle,
  };
}

class StoryTextStyle {
  /// 文字阴影
  final bool shadow;

  /// 使用系统字体（关闭时用衬线字体）
  final bool systemFont;

  /// 字号缩放
  final double fontScale;

  /// 引号字形
  final StoryQuoteGlyph quoteGlyph;

  /// 引号对白
  final StoryRoleStyle quote;

  /// 括号（动作/描述，渲染时去掉括号）
  final StoryRoleStyle bracket;

  /// Markdown 斜体
  final StoryRoleStyle italic;

  /// Markdown 加粗
  final StoryRoleStyle bold;

  const StoryTextStyle({
    this.shadow = false,
    this.systemFont = true,
    this.fontScale = 1.0,
    this.quoteGlyph = StoryQuoteGlyph.curly,
    this.quote = const StoryRoleStyle(),
    this.bracket = const StoryRoleStyle(opacity: 0.85),
    this.italic = const StoryRoleStyle(opacity: 0.7, fontStyle: 'italic'),
    this.bold = const StoryRoleStyle(fontStyle: 'bold'),
  });

  StoryTextStyle copyWith({
    bool? shadow,
    bool? systemFont,
    double? fontScale,
    StoryQuoteGlyph? quoteGlyph,
    StoryRoleStyle? quote,
    StoryRoleStyle? bracket,
    StoryRoleStyle? italic,
    StoryRoleStyle? bold,
  }) => StoryTextStyle(
    shadow: shadow ?? this.shadow,
    systemFont: systemFont ?? this.systemFont,
    fontScale: fontScale ?? this.fontScale,
    quoteGlyph: quoteGlyph ?? this.quoteGlyph,
    quote: quote ?? this.quote,
    bracket: bracket ?? this.bracket,
    italic: italic ?? this.italic,
    bold: bold ?? this.bold,
  );

  factory StoryTextStyle.fromJson(Map<String, dynamic> json) {
    StoryRoleStyle role(Object? v, StoryRoleStyle fallback) =>
        v is Map ? StoryRoleStyle.fromJson(v.cast<String, dynamic>()) : fallback;
    return StoryTextStyle(
      shadow: json['shadow'] as bool? ?? false,
      systemFont: json['systemFont'] as bool? ?? true,
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      quoteGlyph: StoryQuoteGlyph.values.firstWhere(
        (g) => g.name == json['quoteGlyph'],
        orElse: () => StoryQuoteGlyph.curly,
      ),
      quote: role(json['quote'], const StoryRoleStyle()),
      bracket: role(json['bracket'], const StoryRoleStyle(opacity: 0.85)),
      italic: role(
        json['italic'],
        const StoryRoleStyle(opacity: 0.7, fontStyle: 'italic'),
      ),
      bold: role(json['bold'], const StoryRoleStyle(fontStyle: 'bold')),
    );
  }

  Map<String, dynamic> toJson() => {
    'shadow': shadow,
    'systemFont': systemFont,
    'fontScale': fontScale,
    'quoteGlyph': quoteGlyph.name,
    'quote': quote.toJson(),
    'bracket': bracket.toJson(),
    'italic': italic.toJson(),
    'bold': bold.toJson(),
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
