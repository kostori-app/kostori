import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 全屏弹幕样式配置：读写在 appdata.implicitData，弹幕层按需读取。
class DanmakuSettings {
  DanmakuSettings._();

  static const _fontSizeKey = 'danmakuFontSize';
  static const _opacityKey = 'danmakuOpacity';
  static const _areaKey = 'danmakuArea';
  static const _durationKey = 'danmakuDuration';
  static const _lineHeightKey = 'danmakuLineHeight';
  static const _colorKey = 'danmakuColor';

  static double _get(String key, double def) =>
      (appdata.implicitData[key] as num?)?.toDouble() ?? def;

  static void _set(String key, double value) {
    appdata.implicitData[key] = value;
    appdata.writeImplicitData();
  }

  /// 字号
  static double get fontSize => _get(_fontSizeKey, 14);

  /// 不透明度
  static double get opacity => _get(_opacityKey, 1.0);

  /// 显示区域（占屏高比例）
  static double get area => _get(_areaKey, 0.4);

  /// 持续时长（秒，弹幕从入屏到完全离屏）
  static double get duration => _get(_durationKey, 8);

  /// 行高（像素）
  static double get lineHeight => _get(_lineHeightKey, 36);

  /// 弹幕文字颜色（发言人昵称按 userId 自动配色）
  static Color get color {
    final v = appdata.implicitData[_colorKey];
    if (v is int) return Color(v);
    return Colors.white;
  }

  static void setFontSize(double v) => _set(_fontSizeKey, v);

  static void setOpacity(double v) => _set(_opacityKey, v);

  static void setArea(double v) => _set(_areaKey, v);

  static void setDuration(double v) => _set(_durationKey, v);

  static void setLineHeight(double v) => _set(_lineHeightKey, v);

  static void setColor(Color c) {
    appdata.implicitData[_colorKey] = c.toARGB32();
    appdata.writeImplicitData();
  }
}

/// 弹幕样式设置对话框（在设置页/播放器全屏弹幕设置按钮中打开）
void showDanmakuSettingsDialog(BuildContext context) {
  ContentDialog.show(
    context: context,
    title: t.danmakuSettings,
    content: _DanmakuSettingsBody(),
    actions: [TextButton(onPressed: () => context.pop(), child: Text(t.ok))],
  );
}

class _DanmakuSettingsBody extends StatefulWidget {
  const _DanmakuSettingsBody();

  @override
  State<_DanmakuSettingsBody> createState() => _DanmakuSettingsBodyState();
}

class _DanmakuSettingsBodyState extends State<_DanmakuSettingsBody> {
  late double _fontSize = DanmakuSettings.fontSize;
  late double _opacity = DanmakuSettings.opacity;
  late double _area = DanmakuSettings.area;
  late double _duration = DanmakuSettings.duration;
  late double _lineHeight = DanmakuSettings.lineHeight;
  late Color _color = DanmakuSettings.color;

  static const List<Color> _presetColors = [
    Colors.white,
    Color(0xFFFFF59D),
    Color(0xFFFFB74D),
    Color(0xFFFF8A80),
    Color(0xFFF06292),
    Color(0xFFBA68C8),
    Color(0xFF4FC3F7),
    Color(0xFF4DB6AC),
    Color(0xFFAED581),
    Color(0xFFFFD54F),
  ];

  Widget _row(String title, String value, Widget slider) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          slider,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(
          t.danmakuColor,
          '#${_color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _presetColors)
                GestureDetector(
                  onTap: () {
                    setState(() => _color = c);
                    DanmakuSettings.setColor(c);
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color.toARGB32() == c.toARGB32()
                            ? cs.primary
                            : Colors.black26,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _row(
          t.danmakuFontSize,
          _fontSize.toStringAsFixed(0),
          Slider(
            value: _fontSize,
            min: 10,
            max: 30,
            divisions: 20,
            label: _fontSize.toStringAsFixed(0),
            onChanged: (v) {
              setState(() => _fontSize = v);
              DanmakuSettings.setFontSize(v);
            },
          ),
        ),
        _row(
          t.danmakuOpacity,
          _opacity.toStringAsFixed(2),
          Slider(
            value: _opacity,
            min: 0.2,
            max: 1.0,
            divisions: 16,
            label: _opacity.toStringAsFixed(2),
            onChanged: (v) {
              setState(() => _opacity = v);
              DanmakuSettings.setOpacity(v);
            },
          ),
        ),
        _row(
          t.danmakuArea,
          '${(_area * 100).round()}%',
          Slider(
            value: _area,
            min: 0.2,
            max: 1.0,
            divisions: 16,
            label: '${(_area * 100).round()}%',
            onChanged: (v) {
              setState(() => _area = v);
              DanmakuSettings.setArea(v);
            },
          ),
        ),
        _row(
          t.danmakuDuration,
          '${_duration.toStringAsFixed(1)}s',
          Slider(
            value: _duration,
            min: 3,
            max: 20,
            divisions: 34,
            label: '${_duration.toStringAsFixed(1)}s',
            onChanged: (v) {
              setState(() => _duration = v);
              DanmakuSettings.setDuration(v);
            },
          ),
        ),
        _row(
          t.danmakuLineHeight,
          _lineHeight.toStringAsFixed(0),
          Slider(
            value: _lineHeight,
            min: 24,
            max: 60,
            divisions: 36,
            label: _lineHeight.toStringAsFixed(0),
            onChanged: (v) {
              setState(() => _lineHeight = v);
              DanmakuSettings.setLineHeight(v);
            },
          ),
        ),
      ],
    );
  }
}
