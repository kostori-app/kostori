import 'package:flutter/material.dart';
import 'package:kostori/foundation/app_theme.dart';
import 'package:kostori/foundation/appdata.dart';

/// 无头模式下的离屏渲染宿主。
///
/// 无头模式不调用 runApp，因此不存在 widget 树，`generateBangumiCalendarPng`
/// 依赖的 Overlay 与 MediaQuery/Theme 都取不到。这里用
/// [WidgetsBinding.attachRootWidget] 挂一棵根 widget：根节点只放
/// `SizedBox.shrink`，不显示任何界面，但提供了完整渲染环境供
/// RepaintBoundary.toImage 抓帧。
class OffscreenHost {
  OffscreenHost._();

  static final instance = OffscreenHost._();

  final rootKey = GlobalKey();
  final overlayKey = GlobalKey<OverlayState>();

  bool _attached = false;

  /// 挂载离屏树。幂等，可重复调用。
  ///
  /// 主题取当前外观设置，保证截图配色与 GUI 一致。
  void attach({required Brightness brightness}) {
    if (_attached) return;
    final binding = WidgetsBinding.instance;
    // 与 runApp 走同一条路径：wrapWithDefaultView 补上隐式 View，
    // 这样 MediaQuery/Theme 等依赖 View 的 widget 能正常构建
    binding.attachRootWidget(
      binding.wrapWithDefaultView(
        _OffscreenRoot(
          key: rootKey,
          overlayKey: overlayKey,
          theme: buildAppTheme(
            primary: resolveSeedColor(
              appdata.settings['color'] as String?,
              customColor: appdata.implicitData['customColor'] as String?,
            ),
            brightness: brightness,
            amoled: appdata.settings['amoled'] == true,
          ),
          brightness: brightness,
        ),
      ),
    );
    _attached = true;
  }

  /// 离屏树的 [BuildContext]，未挂载或已卸载时为 null。
  BuildContext? get context {
    final ctx = rootKey.currentContext;
    return (ctx != null && ctx.mounted) ? ctx : null;
  }

  /// 可插入 [OverlayEntry] 的 [OverlayState]，Overlay 尚未建好时为 null。
  OverlayState? get overlay => overlayKey.currentState;
}

class _OffscreenRoot extends StatelessWidget {
  const _OffscreenRoot({
    super.key,
    required this.overlayKey,
    required this.theme,
    required this.brightness,
  });

  final GlobalKey<OverlayState> overlayKey;
  final ThemeData theme;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          devicePixelRatio: 1.0,
          platformBrightness: brightness,
          textScaler: TextScaler.noScaling,
        ),
        child: Theme(
          data: theme,
          // 根节点不显示任何内容，Overlay 仅作为离屏渲染容器使用
          child: Overlay(
            key: overlayKey,
            initialEntries: [
              OverlayEntry(builder: (context) => const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}
