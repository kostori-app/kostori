import 'dart:async';
import 'dart:ui';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/pages/auth_page.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'components/components.dart';
import 'components/window_frame.dart';
import 'foundation/app.dart';
import 'foundation/appdata.dart';
import 'foundation/log.dart';
import 'init.dart';
import 'pages/main_page.dart';

void main(List<String> args) {
  if (runWebViewTitleBarWidget(args)) return;
  overrideIO(() {
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        if (App.isAndroid) {
          await FlutterDownloader.initialize(
            debug: true,
            // optional: set to false to disable printing logs to console (default: true)
            ignoreSsl:
                true, // option: set to false to disable working with http links (default: false)
          );
        }
        MediaKit.ensureInitialized();
        await init();

        runApp(ProviderScope(child: MyApp()));
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
      },
      (error, stack) {
        Log.error("Unhandled Exception", error, stack);
      },
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    App.registerForceRebuild(forceRebuild);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
    checkUpdates();
    super.initState();
  }

  bool isAuthPageActive = false;

  OverlayEntry? hideContentOverlay;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint("应用进入后台");
      Future.microtask(() {
        DataSync().onDataChanged();
      });
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("应用回到前台");
    } else if (state == AppLifecycleState.inactive) {
      debugPrint("应用处于非活动状态");
      if (App.isDesktop) {
        Future.microtask(() {
          DataSync().onDataChanged();
        });
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
      isAuthPageActive = true;
      App.rootContext.to(
        () => AuthPage(
          onSuccessfulAuth: () {
            App.rootContext.pop();
            isAuthPageActive = false;
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
    final colorName = appdata.settings['color'];
    return switch (colorName.toLowerCase()) {
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
      'custom' =>
        Utils.hexToColor(appdata.implicitData['customColor']) ??
            Color(0xFF6677ff),
      _ => Colors.blue,
    };
  }

  ThemeData getTheme(
    Color primary,
    Color? secondary,
    Color? tertiary,
    Brightness brightness,
  ) {
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
    final isAmoled =
        (appdata.settings['theme_mode'] == 'dark' &&
        appdata.settings['AMOLED']);

    final Color color = primary;
    return ThemeData(
      colorScheme: isAmoled
          ? ColorScheme.fromSeed(
              seedColor: color,
              brightness: Brightness.dark,
            ).copyWith(surface: Colors.black).harmonized()
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

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (appdata.settings['authorizationRequired']) {
      home = AuthPage(
        onSuccessfulAuth: () {
          App.rootContext.toReplacement(() => const MainPage());
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
        return MaterialApp(
          home: home,
          debugShowCheckedModeBanner: false,
          scrollBehavior: MyCustomScrollBehavior(),
          theme: getTheme(primary, secondary, tertiary, Brightness.light),
          navigatorKey: App.rootNavigatorKey,
          darkTheme: getTheme(primary, secondary, tertiary, Brightness.dark),
          themeMode: switch (appdata.settings['theme_mode']) {
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
            final isPaddingCheckError =
                MediaQuery.of(context).padding.top <= 0 ||
                MediaQuery.of(context).padding.top > 80;

            ErrorWidget.builder = (details) {
              Log.error(
                "Unhandled Exception",
                "${details.exception}\n${details.stack}",
              );
              return Material(
                child: Center(child: Text(details.exception.toString())),
              );
            };
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
              //有点问题,只能暂时解决
              if (isPaddingCheckError) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: MediaQuery.of(context).padding.copyWith(top: 24),
                  ),
                  child: _SystemUiProvider(
                    Material(
                      color: App.isLinux ? Colors.transparent : null,
                      child: widget,
                    ),
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
}
