// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/boot_splash.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/app_theme.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/me_plugin/me_plugin.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/main_isolate_runner.dart';
import 'package:kostori/foundation/webview_resolver.dart';
import 'package:kostori/headless.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/init.dart';
import 'package:kostori/pages/auth_page.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:kostori/pages/main_page.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/external_video_intent.dart';
import 'package:kostori/utils/io.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

/// init() 结束后置为 true，[BootGate] 据此切换到正式界面
final bootReady = ValueNotifier(false);

/// 启动失败标记：init() 抛错时记录，[BootGate] 据此显示错误页而非永久启动页
final bootError = ValueNotifier<Object?>(null);

bool _booting = false;

/// 安装全局错误组件构造器（只装一次，勿放在 build 内）。
/// release 下不展示原始异常文本（可能含路径/URL/请求内容），只给通用提示。
void _installErrorWidget() {
  ErrorWidget.builder = (details) {
    Log.error("Unhandled Exception", "${details.exception}\n${details.stack}");
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            kReleaseMode
                ? t.failedToLoadPleaseTryAgain
                : details.exception.toString(),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };
}

Future<void> _boot() async {
  if (_booting) return;
  _booting = true;
  try {
    await init();
  } catch (e, s) {
    Log.error('init', '$e\n$s');
    bootError.value = e;
    return;
  } finally {
    _booting = false;
  }

  bootError.value = null;
  OpenAiProviderRegistry.refreshCustomProviders().catchError(
    (e) => Log.error("refreshCustomProviders", e),
  );

  bootReady.value = true;
  // 延迟触发个人页插件的“启动自动签到”（等 JS 引擎/首帧就绪）
  Future<void>.delayed(const Duration(seconds: 3), () async {
    try {
      await MePagePluginManager().autoSigninAtStart();
    } catch (_) {}
  });
  if (App.isDesktop) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: App.isMacOS,
      );
      if (App.isLinux) {
        await windowManager.setBackgroundColor(Colors.transparent);
      }
      await windowManager.setMinimumSize(const Size(500, 600));
      var placement = await WindowPlacement.loadFromFile();
      if (App.isLinux) {
        await windowManager.show();
        await placement.applyToWindow();
      } else {
        await placement.applyToWindow();
        await windowManager.show();
      }

      WindowPlacement.loop();
    });
  }
}

void main(List<String> args) {
  if (args.contains('--headless')) {
    runHeadlessMode(args);
    return;
  }
  if (runWebViewTitleBarWidget(args)) return;
  overrideIO(() {
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        MediaKit.ensureInitialized();
        _installErrorWidget();

        // 增大图片缓存容量：番剧列表/详情页图片量大，默认 1000 张/100MB
        // 在跳转详情页加载新图时容易把列表页缓存逐出，返回后图片重新解码导致卡顿
        PaintingBinding.instance.imageCache.maximumSize = 2000;
        PaintingBinding.instance.imageCache.maximumSizeBytes =
            200 * 1024 * 1024;

        // 注册主 isolate 任务通道：WebView2 等平台操作需在主线程执行
        MainIsolateRunner.register();
        WebViewResolver.registerMainIsolateHandler();
        JsEngine.registerWorkerBridgeHandler();

        // init() 要 1~3 秒，提前挂载启动页避免这段时间只有系统白屏
        runApp(const BootGate());

        await _boot();
      },
      (error, stack) {
        Log.error("Unhandled Exception", error, stack);
      },
    );
  });
}

/// 启动门闩：init() 期间显示 [BootSplash]，完成后淡入切换到 [MyApp]。
class BootGate extends StatelessWidget {
  const BootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ListenableBuilder(
        listenable: Listenable.merge([bootReady, bootError]),
        builder: (context, _) {
          final Widget child;
          if (bootError.value != null) {
            child = BootError(
              key: const ValueKey('boot-error'),
              onRetry: _boot,
            );
          } else if (bootReady.value) {
            // 与 init() 共用容器，避免创建两套后台管理器互相覆盖下载通知。
            child = UncontrolledProviderScope(
              key: const ValueKey("app"),
              container: providerContainer,
              child: const MyApp(),
            );
          } else {
            child = const BootSplash(key: ValueKey("splash"));
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: child,
          );
        },
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DateTime _lastSyncCheck = DateTime.now();
  StreamSubscription<String>? _externalVideoSubscription;
  String? _pendingExternalVideo;
  bool _openingExternalVideo = false;
  late bool _externalVideoAuthorized;

  @override
  void initState() {
    App.registerForceRebuild(forceRebuild);
    _externalVideoAuthorized =
        appdata.settings['authorizationRequired'] != true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addObserver(this);
    // 幂等：热重载会重跑 initState，确保主 isolate 通道与 webview 处理器始终就位
    MainIsolateRunner.register();
    WebViewResolver.registerMainIsolateHandler();
    JsEngine.registerWorkerBridgeHandler();
    _listenForExternalVideos();
    checkUpdates();
    super.initState();
  }

  void _listenForExternalVideos() {
    if (!App.isMobile) return;
    _externalVideoSubscription = ExternalVideoIntent.videoPaths.listen(
      _queueExternalVideo,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final path = await ExternalVideoIntent.getInitialVideoPath();
      if (path != null && path.isNotEmpty) _queueExternalVideo(path);
    });
  }

  void _queueExternalVideo(String path) {
    if (path.isEmpty) return;
    if (!_externalVideoAuthorized) {
      _pendingExternalVideo = path;
      return;
    }
    if (_openingExternalVideo) {
      _pendingExternalVideo = path;
      return;
    }
    final context = App.rootContextOrNull;
    if (context == null || !context.mounted) {
      _pendingExternalVideo = path;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pending = _pendingExternalVideo;
        _pendingExternalVideo = null;
        if (pending != null) _queueExternalVideo(pending);
      });
      return;
    }
    _openingExternalVideo = true;
    unawaited(
      context.to(() => LocalPlayerPage(filePath: path)).whenComplete(() {
        _openingExternalVideo = false;
        final pending = _pendingExternalVideo;
        _pendingExternalVideo = null;
        if (pending != null) _queueExternalVideo(pending);
      }),
    );
  }

  void _openPendingExternalVideoAfterAuth() {
    final pending = _pendingExternalVideo;
    _pendingExternalVideo = null;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _queueExternalVideo(pending);
      });
    }
  }

  @override
  void dispose() {
    _externalVideoSubscription?.cancel();
    super.dispose();
  }

  bool isAuthPageActive = false;

  OverlayEntry? hideContentOverlay;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用级数据同步：回到前台超过 10 分钟则自动下载，不依赖个人页是否打开
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(_lastSyncCheck) >
          const Duration(minutes: 10)) {
        _lastSyncCheck = DateTime.now();
        DataSync().downloadData();
      }
    }
    if (!App.isMobile || !appdata.settings['authorizationRequired']) {
      return;
    }
    if (state == AppLifecycleState.inactive && hideContentOverlay == null) {
      hideContentOverlay = OverlayEntry(
        builder: (context) {
          return Positioned.fill(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: App.rootContext.colorScheme.surface,
            ),
          );
        },
      );
      Overlay.of(App.rootContext).insert(hideContentOverlay!);
    } else if (hideContentOverlay != null &&
        state == AppLifecycleState.resumed) {
      hideContentOverlay!.remove();
      hideContentOverlay = null;
    }
    if (state == AppLifecycleState.hidden &&
        !isAuthPageActive &&
        !IO.isSelectingFiles) {
      _externalVideoAuthorized = false;
      isAuthPageActive = true;
      App.rootContext.to(
        () => AuthPage(
          onSuccessfulAuth: () {
            App.rootContext.pop();
            _externalVideoAuthorized = true;
            isAuthPageActive = false;
            _openPendingExternalVideoAfterAuth();
          },
        ),
      );
    }
    super.didChangeAppLifecycleState(state);
  }

  void forceRebuild() {
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
    setState(() {});
  }

  Color translateColorSetting() {
    return resolveSeedColor(
      appdata.settings['color'],
      customColor: appdata.implicitData['customColor'],
    );
  }

  ThemeData getTheme(
    Color primary,
    Color? secondary,
    Color? tertiary,
    Brightness brightness,
  ) {
    final amoled = (brightness == Brightness.dark && appdata.settings.s.amoled);
    return buildAppTheme(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      brightness: brightness,
      amoled: amoled,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (appdata.settings['authorizationRequired']) {
      home = AuthPage(
        onSuccessfulAuth: () {
          _externalVideoAuthorized = true;
          unawaited(App.rootContext.toReplacement(() => const MainPage()));
          _openPendingExternalVideoAfterAuth();
        },
      );
    } else {
      home = const MainPage();
    }
    return DynamicColorBuilder(
      builder: (light, dark) {
        Color? primary, secondary, tertiary;
        if (!appdata.settings['dynamicColor'] ||
            light == null ||
            dark == null) {
          primary = translateColorSetting();
        } else {
          primary = light.harmonized().primary;
          secondary = light.harmonized().secondary;
          tertiary = light.harmonized().tertiary;
        }
        return TranslationProvider(
          child: MaterialApp(
            title: "kostori",
            home: home,
            debugShowCheckedModeBanner: false,
            scrollBehavior: MyCustomScrollBehavior(),
            theme: getTheme(primary, secondary, tertiary, Brightness.light),
            navigatorKey: App.rootNavigatorKey,
            darkTheme: getTheme(primary, secondary, tertiary, Brightness.dark),
            themeMode: switch (appdata.settings['themeMode']) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            color: Colors.transparent,
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            locale: () {
              var lang = appdata.settings['language'];
              if (lang == 'system') {
                return null;
              }
              return switch (lang) {
                'zh-CN' => const Locale('zh', 'CN'),
                'zh-TW' => const Locale('zh', 'TW'),
                'en-US' => const Locale('en'),
                _ => null,
              };
            }(),
            supportedLocales: const [
              Locale('en'),
              Locale('zh', 'CN'),
              Locale('zh', 'TW'),
            ],
            builder: (context, widget) {
              if (widget != null) {
                widget = OverlayWidget(widget);
                if (App.isDesktop) {
                  widget = Shortcuts(
                    shortcuts: {
                      LogicalKeySet(LogicalKeyboardKey.escape):
                          VoidCallbackIntent(App.pop),
                    },
                    child: MouseBackDetector(
                      onTapDown: App.pop,
                      child: WindowFrame(widget),
                    ),
                  );
                }

                return _SystemUiProvider(
                  Material(
                    color: App.isLinux ? Colors.transparent : null,
                    child: widget,
                  ),
                );
              }
              throw ('widget is null');
            },
          ),
        );
      },
    );
  }
}

class _SystemUiProvider extends StatelessWidget {
  const _SystemUiProvider(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    var brightness = Theme.of(context).brightness;
    SystemUiOverlayStyle systemUiStyle;
    if (brightness == Brightness.light) {
      systemUiStyle = SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      );
    } else {
      systemUiStyle = SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: child,
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };

  /// 全局禁用原生滚动条：项目统一使用自定义 AppScrollBar 滚动条
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
