import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/widget_utils.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 播放器快进/快退、亮度/音量 HUD 的共享实现：
/// anime page 播放器与本地播放器共用同一套外观与逻辑。

/// 快进/快退、亮度/音量、倍速 HUD 距播放器顶部的偏移。
/// 竖屏全屏时更靠下（避开状态栏/刘海），其余为 50。
/// 两个播放器共用，保证同一组件的位置一致。
double playerHudTop({required bool isPortraitFullscreen}) =>
    isPortraitFullscreen ? 140 : 50;

/// HUD 底：磨砂玻璃卡片（模糊背景 + 深色半透明底 + 圆角边框）
class PlayerHudCard extends StatelessWidget {
  const PlayerHudCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BlurEffect(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.toOpacity(0.60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.toOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.toOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 播放器时间格式：mm:ss / h:mm:ss
String formatPlayerTime(Duration d) {
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// 快进 / 快退 HUD（左右滑动时显示）。
/// 方向配色：快进青绿 / 快退橙红。
class PlayerSeekHud extends StatelessWidget {
  const PlayerSeekHud({
    super.key,
    required this.target,
    required this.current,
    required this.total,
  });

  final Duration target;
  final Duration current;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final isForward = target > current;
    final diffSec = (target - current).inSeconds.abs().clamp(0, 999);
    final totalSec = total.inSeconds > 0 ? total.inSeconds : 1;
    final progress = (target.inMilliseconds / (totalSec * 1000)).clamp(
      0.0,
      1.0,
    );
    final accent = isForward
        ? const Color(0xFF2ED8A7)
        : const Color(0xFFFF7A6B);
    final icon = isForward
        ? Icons.fast_forward_rounded
        : Icons.fast_rewind_rounded;

    return IgnorePointer(
      child: PlayerHudCard(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(icon, key: ValueKey(icon), color: accent, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isForward
                      ? t.seekForward(s: diffSec)
                      : t.seekBackward(s: diffSec),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatPlayerTime(target),
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' / ${formatPlayerTime(total)}',
                      style: TextStyle(
                        color: Colors.white.toOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 120,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Stack(
                      children: [
                        Container(color: Colors.white.toOpacity(0.15)),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(color: accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 亮度 / 音量 HUD（竖直滑动时显示）。[value] 为 0~100。
class PlayerLevelHud extends StatelessWidget {
  const PlayerLevelHud({
    super.key,
    required this.isBrightness,
    required this.value,
  });

  final bool isBrightness;
  final double value;

  // 亮度用暖色、音量用冷色，作视觉区分
  static const _brightnessColor = Color(0xFFF5A623);
  static const _volumeColor = Color(0xFF4DB6FF);

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100);
    final accent = isBrightness ? _brightnessColor : _volumeColor;
    final icon = isBrightness
        ? Icons.brightness_7_rounded
        : (v <= 0
              ? Icons.volume_off_rounded
              : v < 50
              ? Icons.volume_down_rounded
              : Icons.volume_up_rounded);

    return IgnorePointer(
      child: PlayerHudCard(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 切换图标时缩放+淡入，模拟“点亮”（动画在 AnimatedSwitcher 内处理）
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Icon(icon, key: ValueKey(icon), color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(color: Colors.white.toOpacity(0.15)),
                    // 从当前宽度平滑过渡，不会从 0 弹起
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: 110 * (v / 100),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: accent.toOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 38,
              child: Text(
                '${v.round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
