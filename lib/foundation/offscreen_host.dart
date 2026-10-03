import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/app_theme.dart';
import 'package:kostori/foundation/appdata.dart';

/// 无头模式下的离屏渲染宿主。
///
/// 无头模式不调用 runApp，因此不存在 widget 树，图片导出依赖的
/// Overlay 与 MediaQuery/Theme 都取不到。这里用
/// [WidgetsBinding.attachRootWidget] 挂一棵根 widget：根节点只放
/// `SizedBox.shrink`，不显示任何界面，但提供了完整渲染环境供
/// `RepaintBoundary.toImage` 抓帧。
///
/// GUI 模式下 [ImageCaptureHost] 会优先使用界面自身的 Overlay，只有拿不到
/// 时才回退到这里，因此本类只服务于无头 / 无界面场景。
class OffscreenHost {
  OffscreenHost._();

  static final instance = OffscreenHost._();

  final rootKey = GlobalKey();
  final overlayKey = GlobalKey<OverlayState>();

  bool _attached = false;

  ThemeData? _theme;

  /// 离屏树是否已挂载。
  bool get attached => _attached;

  /// 外观设置里配置的明暗，缺省跟随系统。
  static Brightness get systemBrightness {
    final mode = appdata.settings['themeMode']?.toString();
    if (mode == 'dark') return Brightness.dark;
    if (mode == 'light') return Brightness.light;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  /// 离屏树当前使用的配色。
  ThemeData get theme =>
      _theme ??
      buildAppTheme(
        primary: resolveSeedColor(
          appdata.settings['color'] as String?,
          customColor: appdata.implicitData['customColor'] as String?,
        ),
        brightness: Brightness.light,
        amoled: appdata.settings['amoled'] == true,
      );

  /// 按外观设置构建主题。[theme] 非空时直接采用，供接口层指定配色。
  static ThemeData buildTheme({ThemeData? theme, Brightness? brightness}) {
    if (theme != null) return theme;
    final resolved = brightness ?? systemBrightness;
    return buildAppTheme(
      primary: resolveSeedColor(
        appdata.settings['color'] as String?,
        customColor: appdata.implicitData['customColor'] as String?,
      ),
      brightness: resolved,
      amoled: appdata.settings['amoled'] == true || resolved == Brightness.dark,
    );
  }

  /// 挂载离屏树。幂等，可重复调用。
  ///
  /// 主题取当前外观设置，保证截图配色与 GUI 一致；[theme] 可覆盖配色。
  void attach({Brightness? brightness, ThemeData? theme}) {
    if (_attached && theme == null) return;
    _theme = buildTheme(theme: theme, brightness: brightness);
    if (_attached) return;
    final binding = WidgetsBinding.instance;
    // 与 runApp 走同一条路径：wrapWithDefaultView 补上隐式 View，
    // 这样 MediaQuery/Theme 等依赖 View 的 widget 能正常构建
    binding.attachRootWidget(
      binding.wrapWithDefaultView(
        _OffscreenRoot(
          key: rootKey,
          overlayKey: overlayKey,
          theme: _theme!,
          brightness: _theme!.brightness,
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
    return ProviderScope(
      // 离屏渲染的组件可能用到 Riverpod（与 runApp 的 ProviderScope 对齐），
      // 缺了会在元素挂载时抛 container 查找失败
      child: Directionality(
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
      ),
    );
  }
}
