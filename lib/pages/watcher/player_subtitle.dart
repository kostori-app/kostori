import 'package:flutter/material.dart';
import 'package:kostori/components/color_pick_page.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 播放器字幕样式（Flutter 侧渲染时生效）。
class PlayerSubtitleStyle {
  final Color color;
  final Color outlineColor;
  final double fontSize;
  final double outlineWidth;

  const PlayerSubtitleStyle({
    this.color = const Color(0xffffffff),
    this.outlineColor = const Color(0xcc000000),
    this.fontSize = 32.0,
    this.outlineWidth = 2.0,
  });

  PlayerSubtitleStyle copyWith({
    Color? color,
    Color? outlineColor,
    double? fontSize,
    double? outlineWidth,
  }) {
    return PlayerSubtitleStyle(
      color: color ?? this.color,
      outlineColor: outlineColor ?? this.outlineColor,
      fontSize: fontSize ?? this.fontSize,
      outlineWidth: outlineWidth ?? this.outlineWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerSubtitleStyle &&
      color == other.color &&
      outlineColor == other.outlineColor &&
      fontSize == other.fontSize &&
      outlineWidth == other.outlineWidth;

  @override
  int get hashCode => Object.hash(color, outlineColor, fontSize, outlineWidth);
}

/// 全局字幕样式：单一数据源（读写 `appdata.implicitData` 持久化），
/// 用 [ValueNotifier] 让所有播放器（anime page / 本地播放器）同步重建。
class PlayerSubtitleStyleController {
  PlayerSubtitleStyleController._();

  static final ValueNotifier<PlayerSubtitleStyle> notifier =
      ValueNotifier(_load());

  static PlayerSubtitleStyle _load() {
    final data = appdata.implicitData;
    Color color(String key, Color fallback) {
      final v = data[key];
      return v is num ? Color(v.toInt()) : fallback;
    }

    double number(String key, double fallback) {
      final v = data[key];
      return v is num ? v.toDouble() : fallback;
    }

    const def = PlayerSubtitleStyle();
    return PlayerSubtitleStyle(
      color: color('subtitleColor', def.color),
      outlineColor: color('subtitleOutlineColor', def.outlineColor),
      fontSize: number('subtitleFontSize', def.fontSize),
      outlineWidth: number('subtitleOutlineWidth', def.outlineWidth),
    );
  }

  /// 更新样式；[persist] 为 false 时只改内存（滑块拖动中），松手时再持久化。
  static void update(PlayerSubtitleStyle style, {bool persist = true}) {
    notifier.value = style;
    if (!persist) return;
    final data = appdata.implicitData;
    data['subtitleColor'] = style.color.toARGB32();
    data['subtitleOutlineColor'] = style.outlineColor.toARGB32();
    data['subtitleFontSize'] = style.fontSize;
    data['subtitleOutlineWidth'] = style.outlineWidth;
    appdata.writeImplicitData();
  }
}

/// 构造 media_kit 字幕样式（[Video.subtitleViewConfiguration]）：
/// - 无背景（`backgroundColor` 全透明）；
/// - 四周 0 距离差、低模糊的 `shadows` 近似描边。
///
/// 注意：若 PlayerConfiguration 开启了 `libass`（原生 mpv 渲染），本配置不生效。
SubtitleViewConfiguration buildPlayerSubtitleViewConfiguration(
  PlayerSubtitleStyle style,
) {
  return SubtitleViewConfiguration(
    style: TextStyle(
      height: 1.4,
      fontSize: style.fontSize,
      letterSpacing: 0.0,
      wordSpacing: 0.0,
      color: style.color,
      fontWeight: FontWeight.normal,
      backgroundColor: const Color(0x00000000),
      shadows: _subtitleOutlineShadows(style.outlineColor, style.outlineWidth),
    ),
  );
}

List<Shadow> _subtitleOutlineShadows(Color color, double width) {
  if (width <= 0) return const [];
  final w = width;
  final d = w * 0.75;
  return [
    Shadow(color: color, blurRadius: 1, offset: Offset(-w, 0)),
    Shadow(color: color, blurRadius: 1, offset: Offset(w, 0)),
    Shadow(color: color, blurRadius: 1, offset: Offset(0, -w)),
    Shadow(color: color, blurRadius: 1, offset: Offset(0, w)),
    Shadow(color: color, blurRadius: 1, offset: Offset(-d, -d)),
    Shadow(color: color, blurRadius: 1, offset: Offset(d, -d)),
    Shadow(color: color, blurRadius: 1, offset: Offset(-d, d)),
    Shadow(color: color, blurRadius: 1, offset: Offset(d, d)),
  ];
}

/// 默认字幕配置（未接设置的少数位置沿用）。
final SubtitleViewConfiguration kPlayerSubtitleViewConfiguration =
    buildPlayerSubtitleViewConfiguration(const PlayerSubtitleStyle());

/// 共享字幕设置面板（本地播放器 / anime page 共用）。
Future<void> showPlayerSubtitleSettingsSheet(BuildContext context) async {
  var style = PlayerSubtitleStyleController.notifier.value;
  await showModalBottomSheet(
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setModalState) {
        return Sheet(
          title: t.subtitleSettings,
          icon: Icons.text_fields,
          builder: (_, sc) => ListView(
            controller: sc,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _colorRow(
                context,
                label: t.subtitleTextColor,
                value: style.color,
                onPicked: (c) {
                  setModalState(() => style = style.copyWith(color: c));
                  PlayerSubtitleStyleController.update(style);
                },
              ),
              _colorRow(
                context,
                label: t.subtitleOutlineColor,
                value: style.outlineColor,
                onPicked: (c) {
                  setModalState(() => style = style.copyWith(outlineColor: c));
                  PlayerSubtitleStyleController.update(style);
                },
              ),
              const SizedBox(height: 12),
              Text('${t.subtitleFontSize}: ${style.fontSize.round()}'),
              Slider(
                value: style.fontSize.clamp(12, 72),
                min: 12,
                max: 72,
                divisions: 60,
                onChanged: (v) {
                  setModalState(() => style = style.copyWith(fontSize: v));
                  PlayerSubtitleStyleController.update(
                    style,
                    persist: false,
                  );
                },
                onChangeEnd: (_) => PlayerSubtitleStyleController.update(style),
              ),
              Text(
                '${t.subtitleOutlineWidth}: ${style.outlineWidth.toStringAsFixed(1)}',
              ),
              Slider(
                value: style.outlineWidth.clamp(0, 6),
                min: 0,
                max: 6,
                divisions: 12,
                onChanged: (v) {
                  setModalState(() => style = style.copyWith(outlineWidth: v));
                  PlayerSubtitleStyleController.update(
                    style,
                    persist: false,
                  );
                },
                onChangeEnd: (_) => PlayerSubtitleStyleController.update(style),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _colorRow(
  BuildContext context, {
  required String label,
  required Color value,
  required ValueChanged<Color> onPicked,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () async {
      final picked = await showDialog<Color>(
        context: context,
        builder: (_) => ColorPickPage(initialColor: value),
      );
      if (picked != null) onPicked(picked);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: value,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}
