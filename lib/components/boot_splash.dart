import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/app_theme.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 启动页底色。
///
/// 必须与原生启动窗口完全一致，否则 Flutter 首帧落地时会整屏变色：
/// - Android `@color/launch_background`（`values/` 与 `values-night/`）
/// - iOS `LaunchScreen.storyboard` 的 `LaunchBackground`
///
/// 原生窗口跑在 Dart 之前，读不到 `themeMode` / `amoled` / 主题种子色，
/// 只能写死一个值；所以启动页这边也写死，等 init() 完成后由 `main.dart`
/// 的 `AnimatedSwitcher` 交叉淡入到真实主题。
const Color kBootBackground = Color(0xFF0F1114);

/// 启动页 logo 边长（逻辑像素）。
///
/// 必须与原生一致，否则 logo 会在交接瞬间缩放：
/// - iOS `LaunchImage` 为 132pt（见 `Assets.xcassets/LaunchImage.imageset`）
/// - Android 12+ 通过 `windowSplashScreenIconBackgroundSize` 设为 132dp
const double kBootLogoSize = 132.0;

/// logo 与 loading 指示器之间的间距。
const double kBootLogoGap = 36.0;

/// loading 指示器尺寸。
const double kBootSpinnerSize = 26.0;

/// 启动页：在 `init()` 完成前占位。首帧之前系统只有原生启动窗口，
/// 而 `init()` 通常要 1~3 秒。
///
/// 布局刻意与原生启动画面对齐（底色、logo 尺寸与居中位置），
/// 交接时应当看不出跳变：logo **不做淡入、不做缩放动画**——
/// 原生窗口已经把它画出来了，再动一次就是闪烁。
/// 只有 loading 指示器带动画，因为原生启动窗口无法做动画（静态画面）。
class BootSplash extends StatelessWidget {
  const BootSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final s = appdata.settings.s;
    final primary = resolveSeedColor(
      s.color,
      customColor: appdata.implicitData['customColor'],
    );
    // 底色固定为深色，主题也固定用深色，否则浅色主题下 loading 配色在深底上几乎看不见
    final theme = buildAppTheme(
      primary: primary,
      brightness: Brightness.dark,
      amoled: false,
    );
    return MaterialApp(
      title: "kostori",
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: theme,
      home: const _BootSplashBody(),
    );
  }
}

class _BootSplashBody extends StatelessWidget {
  const _BootSplashBody();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 底色恒为深色，状态栏图标固定用浅色
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: kBootBackground,
        body: Stack(
          children: [
            // logo 精确居中于屏幕正中，与原生启动画面的居中位置一致。
            // 注意不能用 Center + Column：那样 logo 会因为下面的 loading 和版本号
            // 而被顶到中心之上（历史上正是这 31px 位移造成交接时的上跳）。
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: kBootLogoSize,
                height: kBootLogoSize,
                child: Image(
                  // 展示尺寸只有 132px，按 2 倍解码避免拉取 1024px 原图
                  image: ResizeImage(
                    const AssetImage("images/app_logo.png"),
                    width: (kBootLogoSize * 2).round(),
                  ),
                  filterQuality: FilterQuality.medium,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // loading 固定在 logo 正下方。
            // 用 Transform.translate 而不是外层 Padding：Align 会把「加过 padding 的
            // 盒子」居中，那样偏移量会被 (屏幕高 - 内容高) / 2 二次抵消。
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(
                  0,
                  kBootLogoSize / 2 + kBootLogoGap + kBootSpinnerSize / 2,
                ),
                child: const PolygonRefreshIndicator(size: kBootSpinnerSize),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Center(
                    child: Text(
                      "v${App.version}",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.toOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 启动失败兜底页：init() 抛错时替代永久启动页，提供重试入口。
///
/// 底色沿用 [kBootBackground]，否则从启动页切过来会整屏变色。
class BootError extends StatelessWidget {
  const BootError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = appdata.settings.s;
    final primary = resolveSeedColor(
      s.color,
      customColor: appdata.implicitData['customColor'],
    );
    final theme = buildAppTheme(
      primary: primary,
      brightness: Brightness.dark,
      amoled: false,
    );
    return MaterialApp(
      title: 'kostori',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: theme,
      home: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: kBootBackground,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      t.failedToLoadPleaseTryAgain,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Button.filled(onPressed: onRetry, child: Text(t.retry)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
