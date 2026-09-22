part of 'components.dart';

/// 统一的磨砂玻璃效果。
///
/// 模糊强度与开关统一由「外观」设置控制（持久化在 implicitData）：
/// - `blurEnabled`（默认 true）：全局关闭时不做模糊，改用不透明底色，节省合成开销；
/// - `blurStrength`（默认 15，范围 5~20）：全局模糊强度。
///
/// [enabled] 用于局部按需启用（如 AppBar 仅在内容滚到其下方时才模糊）。
class BlurEffect extends StatelessWidget {
  final Widget child;

  /// 局部是否启用模糊；全局关闭时不生效（会改用不透明底色）
  final bool enabled;

  final BorderRadius? borderRadius;

  /// 全局关闭模糊时使用的不透明底色，默认主题 surface
  final Color? opaqueColor;

  const BlurEffect({
    required this.child,
    this.borderRadius,
    this.enabled = true,
    this.opaqueColor,
    super.key,
  });

  /// 全局是否启用模糊
  static bool get globalEnabled =>
      appdata.implicitData['blurEnabled'] as bool? ?? true;

  /// 全局模糊强度（5~20）
  static double get globalStrength {
    final value = (appdata.implicitData['blurStrength'] as num?)?.toDouble();
    return (value ?? 15).clamp(5, 20).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    if (!globalEnabled) {
      // 全局关闭模糊：用不透明底色替代，省掉 BackdropFilter 的合成开销
      return ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: opaqueColor ?? Theme.of(context).colorScheme.surface,
          child: child,
        ),
      );
    }
    if (!enabled) {
      return ClipRRect(borderRadius: radius, child: child);
    }
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: globalStrength,
          sigmaY: globalStrength,
          tileMode: TileMode.mirror,
        ),
        child: child,
      ),
    );
  }
}
