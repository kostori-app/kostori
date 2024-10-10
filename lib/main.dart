import 'dart:async';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kostori/pages/auth_page.dart';
import 'package:kostori/pages/welcome_page.dart';
import 'package:kostori/tools/mouse_listener.dart';
import 'package:window_manager/window_manager.dart';
import 'components/components.dart';
import 'foundation/log.dart';
import 'init.dart';
import 'network/http_client.dart';
import 'network/webdav.dart';
import 'pages/main_page.dart';
import 'package:kostori/base.dart';
import 'components/window_frame.dart';
import 'foundation/app.dart';
import 'foundation/app_page_route.dart';

bool notFirstUse = false;

void main(List<String> args) {
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await init();
    FlutterError.onError = (details) {
      LogManager.addLog(LogLevel.error, "Unhandled Exception",
          "${details.exception}\n${details.stack}");
    };
    notFirstUse = appdata.firstUse[3] == "1";
    setNetworkProxy();
    runApp(const MyApp());
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
        if (!App.isLinux) {
          // https://github.com/leanflutter/window_manager/issues/460
          var placement = await WindowPlacement.loadFromFile();
          await placement.applyToWindow();
          await windowManager.show();
          WindowPlacement.loop();
        }
      });
    }
  }, (error, stack) {
    LogManager.addLog(LogLevel.error, "Unhandled Exception", "$error\n$stack");
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void Function()? updater;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DateTime time = DateTime.fromMillisecondsSinceEpoch(0);

  bool forceRebuild = false;

  OverlayEntry? hideContentOverlay;

  void hideContent() {
    if (hideContentOverlay != null) return;
    hideContentOverlay = OverlayEntry(
        builder: (context) => Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width,
              color: Theme.of(context).colorScheme.surface,
            ));
    OverlayWidget.addOverlay(hideContentOverlay!);
  }

  void showContent() {
    hideContentOverlay = null;
    OverlayWidget.removeAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    bool enableAuth = appdata.settings[13] == "1";
    if (App.isAndroid && appdata.settings[38] == "1") {
      try {
        FlutterDisplayMode.setHighRefreshRate();
      } catch (e) {
        // ignore
      }
    }
    setNetworkProxy();
    scheduleMicrotask(() {
      if (state == AppLifecycleState.hidden && enableAuth) {
        if (!AuthPage.lock && appdata.settings[13] == "1") {
          AuthPage.initial = false;
          AuthPage.lock = true;
          App.to(App.globalContext!, () => const AuthPage());
        }
      }

      if (state == AppLifecycleState.inactive && enableAuth) {
        hideContent();
      } else if (state == AppLifecycleState.resumed) {
        showContent();
        // Future.delayed(const Duration(milliseconds: 200), checkClipboard);
      }

      if (DateTime.now().millisecondsSinceEpoch - time.millisecondsSinceEpoch >
          7200000) {
        Webdav.syncData();
        time = DateTime.now();
      }
    });
  }

  @override
  void initState() {
    MyApp.updater = () => setState(
          () {
            updateBrightness();
            forceRebuild = true;
          },
        );
    time = DateTime.now();
    // TagsTranslation.readData();
    if (App.isAndroid && appdata.settings[38] == "1") {
      try {
        FlutterDisplayMode.setHighRefreshRate();
      } finally {}
    }
    listenMouseSideButtonToBack();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addObserver(this);
    notifications.init();
    if (appdata.settings[12] == "1") {
      // blockScreenshot();
    }
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    updateBrightness();
    super.didChangeDependencies();
  }

  late SystemUiOverlayStyle systemUiStyle;

  void updateBrightness() {
    var mode = appdata.appSettings.darkMode;
    final Brightness brightness = switch (mode) {
      1 => Brightness.light,
      2 => Brightness.dark,
      _ => View.of(context).platformDispatcher.platformBrightness,
    };
    if (brightness == Brightness.light) {
      systemUiStyle = const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false);
    } else {
      systemUiStyle = const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false);
    }
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      updateBrightness();
    });
  }

  (ColorScheme, ColorScheme) _generateColorSchemes(
      ColorScheme? light, ColorScheme? dark) {
    Color? color;
    if (int.parse(appdata.settings[27]) != 0) {
      color = colors[int.parse(appdata.settings[27]) - 1];
    } else {
      color = light?.primary ?? Colors.blueAccent;
    }
    light = ColorScheme.fromSeed(seedColor: color);
    dark = ColorScheme.fromSeed(seedColor: color, brightness: Brightness.dark);
    if (appdata.settings[32] == "1") {
      // light mode
      dark = light;
    } else if (appdata.settings[32] == "2") {
      // dark mode
      light = dark;
    }
    return (light, dark);
  }

  @override
  Widget build(BuildContext context) {
    if (forceRebuild) {
      forceRebuild = false;
      void rebuild(Element el) {
        el.markNeedsBuild();
        el.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: DynamicColorBuilder(builder: (light, dark) {
        var (lightColor, darkColor) = _generateColorSchemes(light, dark);
        return MaterialApp(
          title: 'kostori',
          debugShowCheckedModeBanner: false,
          navigatorKey: App.navigatorKey,
          theme: ThemeData(
            colorScheme: lightColor,
            useMaterial3: true,
            fontFamily: App.isWindows ? "font" : "",
          ),
          darkTheme: ThemeData(
            colorScheme: darkColor,
            useMaterial3: true,
            fontFamily: App.isWindows ? "font" : "",
          ),
          onGenerateRoute: (settings) => AppPageRoute(
            builder: (context) => notFirstUse
                ? (appdata.settings[13] == "1"
                    ? const AuthPage()
                    : const MainPage())
                : const WelcomePage(),
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('zh', 'TW'),
            Locale('en', 'US')
          ],
          builder: (context, widget) {
            ErrorWidget.builder = (details) {
              LogManager.addLog(LogLevel.error, "Unhandled Exception",
                  "${details.exception}\n${details.stack}");
              return Material(
                child: Center(
                  child: Text(details.exception.toString()),
                ),
              );
            };
            if (widget != null) {
              widget = OverlayWidget(widget);
              if (App.isDesktop) {
                widget = Shortcuts(
                  shortcuts: {
                    LogicalKeySet(LogicalKeyboardKey.escape):
                        VoidCallbackIntent(
                      () {
                        if (App.canPop) {
                          App.globalBack();
                        } else {
                          App.mainNavigatorKey?.currentContext?.pop();
                        }
                      },
                    ),
                  },
                  child: WindowFrame(widget),
                );
              }
              return widget;
            }
            throw ('widget is null');
          },
        );
      }),
    );
  }
}
