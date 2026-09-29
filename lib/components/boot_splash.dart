import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/app_theme.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 启动页：在 `init()`（数据库、脚本引擎、资源源、下载任务…）完成前占位。
///
/// 移动端首帧之前系统只显示纯白的启动窗口，而 `init()` 通常要 1~3 秒，
/// 这段时间用户只能看到白屏。这里提前绘制一个带品牌信息的启动页，
/// 并复用正式界面的色板（[buildAppTheme]），交棒给 `MyApp` 时不会闪白。
class BootSplash extends StatelessWidget {
  const BootSplash({super.key});

  @override
  Widget build(BuildContext context) {
    // 监听 settings：appdata 载入后启动页会立刻跟随用户的浅色/深色主题
    return ListenableBuilder(
      listenable: appdata.settings,
      builder: (context, _) {
        final s = appdata.settings.s;
        Color primary() => resolveSeedColor(
          s.color,
          customColor: appdata.implicitData['customColor'],
        );
        // AMOLED 只对深色主题生效（与 MyApp 的判定保持一致）
        final amoled = s.amoled;
        return MaterialApp(
          title: "kostori",
          debugShowCheckedModeBanner: false,
          themeMode: switch (s.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          theme: buildAppTheme(
            primary: primary(),
            brightness: Brightness.light,
            amoled: false,
          ),
          darkTheme: buildAppTheme(
            primary: primary(),
            brightness: Brightness.dark,
            amoled: amoled,
          ),
          home: const _BootSplashBody(),
        );
      },
    );
  }
}

class _BootSplashBody extends StatefulWidget {
  const _BootSplashBody();

  @override
  State<_BootSplashBody> createState() => _BootSplashBodyState();
}

class _BootSplashBodyState extends State<_BootSplashBody>
    with TickerProviderStateMixin {
  late final AnimationController _enter;

  late final AnimationController _pulse;

  late final CurvedAnimation _enterAnimation;

  late final CurvedAnimation _pulseCurve;

  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    // 呼吸缩放：初始化期间画面静止，用轻微的律动表示仍在加载
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _enterAnimation = CurvedAnimation(
      parent: _enter,
      curve: Curves.easeOutCubic,
    );
    _pulseCurve = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    _pulseAnimation = Tween(begin: 0.965, end: 1.0).animate(_pulseCurve);
  }

  @override
  void dispose() {
    _enterAnimation.dispose();
    _pulseCurve.dispose();
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Stack(
          children: [
            // 顶部到底部极淡的品牌色渐变，避免整屏死板的纯色
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.alphaBlend(
                        colorScheme.primary.toOpacity(0.05),
                        colorScheme.surface,
                      ),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _enterAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: SizedBox(
                        width: 200,
                        height: 132,
                        child: Image(
                          // 启动页只需要约 200px 宽，避免解码 1024px 原图
                          image: ResizeImage(
                            const AssetImage("images/app_logo.png"),
                            width: 400,
                          ),
                          filterQuality: FilterQuality.medium,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const PolygonRefreshIndicator(size: 26),
                  ],
                ),
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
                    child: FadeTransition(
                      opacity: _enterAnimation,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// 启动失败兜底页：init() 抛错时替代永久启动页，提供重试入口。
class BootError extends StatelessWidget {
  const BootError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = appdata.settings.s;
    Color primary() => resolveSeedColor(
      s.color,
      customColor: appdata.implicitData['customColor'],
    );
    final amoled = s.themeMode == 'dark' && s.amoled;
    return MaterialApp(
      title: 'kostori',
      debugShowCheckedModeBanner: false,
      themeMode: switch (s.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      theme: buildAppTheme(
        primary: primary(),
        brightness: Brightness.light,
        amoled: amoled,
      ),
      darkTheme: buildAppTheme(
        primary: primary(),
        brightness: Brightness.dark,
        amoled: amoled,
      ),
      home: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: cs.surface,
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
