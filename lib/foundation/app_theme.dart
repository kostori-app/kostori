import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/utils/utils.dart';

/// 外观设置里的主题色名 → Material 种子色，启动页与正式界面共用。
Color resolveSeedColor(String? colorName, {String? customColor}) {
  return switch (colorName?.toLowerCase()) {
    'teal' => Colors.teal,
    'deep purple' => Colors.deepPurple,
    'orange' => Colors.orange,
    'blue' => Colors.blue,
    'pink' => Colors.pink,
    'green' => Colors.green,
    'red' => Colors.red,
    'purple' => Colors.purple,
    'yellow' => Colors.yellow,
    'cyan' => Colors.cyan,
    'm3 default' => const Color(0xff6750a4),
    'deep orange' => Colors.deepOrange,
    'indigo' => Colors.indigo,
    'cloudy blue' => const Color(0xFFACC2D9),
    'dark pastel green' => const Color(0xFF56AE57),
    'dust' => const Color(0xFFB2996E),
    'electric lime' => const Color(0xFFA8FF04),
    'fresh green' => const Color(0xFF69D84F),
    'light eggplant' => const Color(0xFF894585),
    'nasty green' => const Color(0xFF70B23F),
    'really light blue' => const Color(0xFFD4FFFF),
    'tea' => const Color(0xFF65AB7C),
    'warm purple' => const Color(0xFF952E8F),
    'yellowish tan' => const Color(0xFFFCFC81),
    'cement' => const Color(0xFFA5A391),
    'dark grass green' => const Color(0xFF388004),
    'dusty teal' => const Color(0xFF4C9085),
    'grey teal' => const Color(0xFF5E9B8A),
    'macaroni and cheese' => const Color(0xFFEFB435),
    'pinkish tan' => const Color(0xFFD99B82),
    'spruce' => const Color(0xFF0A5F38),
    'strong blue' => const Color(0xFF0C06F7),
    'toxic green' => const Color(0xFF61DE2A),
    'windows blue' => const Color(0xFF3778BF),
    'blue blue' => const Color(0xFF2242C7),
    'blue with a hint of purple' => const Color(0xFF533CC6),
    'booger' => const Color(0xFF9BB53C),
    'bright sea green' => const Color(0xFF05FFA6),
    'green teal' => const Color(0xFF17B890),
    'brownish' => const Color(0xFF582E1B),
    'off green' => const Color(0xFFBDD393),
    'tangerine' => const Color(0xFFFF964F),
    'ugly green' => const Color(0xFF84B701),
    'custom' => Utils.hexToColor(customColor) ?? Color(0xFF6677ff),
    _ => Colors.blue,
  };
}

/// 应用主题。[amoled] 为真时深色背景使用纯黑（AMOLED）。
ThemeData buildAppTheme({
  required Color primary,
  Color? secondary,
  Color? tertiary,
  required Brightness brightness,
  required bool amoled,
}) {
  String? font;
  List<String>? fallback;
  if (App.isLinux || App.isWindows) {
    font = 'Noto Sans CJK';
    fallback = [
      'Segoe UI',
      'Noto Sans SC',
      'Noto Sans TC',
      'Noto Sans',
      'Microsoft YaHei',
      'PingFang SC',
      'Arial',
      'sans-serif',
    ];
  }
  return ThemeData(
    colorScheme: amoled
        ? ColorScheme.fromSeed(
            seedColor: primary,
            brightness: brightness,
          ).copyWith(surface: Colors.black)
        : SeedColorScheme.fromSeeds(
            primaryKey: primary,
            secondaryKey: secondary,
            tertiaryKey: tertiary,
            brightness: brightness,
            tones: FlexTones.vividBackground(brightness),
          ),
    useMaterial3: true,
    fontFamily: font,
    fontFamilyFallback: fallback,
  );
}
