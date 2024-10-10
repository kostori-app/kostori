import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kostori/pages/bingeWatchPage.dart';
import 'package:kostori/pages/explorePage.dart';
import 'package:kostori/pages/historyPage.dart';
import 'package:kostori/pages/homePage.dart';
import 'package:kostori/pages/musicPage.dart';
import 'package:kostori/pages/personsPage.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import '../components/components.dart';
import '../base.dart';
import '../foundation/app.dart';
import '../foundation/app_page_route.dart';
import '../network/webdav.dart';
import 'category_page.dart';

// class MainPage extends StatefulWidget {
//   const MainPage({Key? key}) : super(key: key);
//   static NaviObserver? _observer;
//   static GlobalKey<NavigatorState>? _navigatorKey;
//   static void to(Widget Function() widget,
//       {bool preventDuplicate = false}) async {
//     while (_navigatorKey == null) {
//       await Future.delayed(const Duration(milliseconds: 100));
//     }
//     if (preventDuplicate) {
//       var page = widget();
//       if ("/${page.runtimeType}" == _observer?.routes.last.toString()) return;
//     }
//     App.to(_navigatorKey!.currentContext!, widget);
//   }
//
//   final String title;
//   static canPop() =>
//       Navigator.of(_navigatorKey?.currentContext ?? App.globalContext!)
//           .canPop();
//
//   static void back() {
//     if (canPop()) {
//       _navigatorKey?.currentState?.pop();
//     }
//   }
//
//   @override
//   State<MainPage> createState() => _MyHomePageState();
// }
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  static MainPageState of(BuildContext context) {
    return context.findAncestorStateOfType<MainPageState>()!;
  }

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  GlobalKey<NavigatorState>? _navigatorKey;

  late final NaviObserver _observer;
  List<Widget> get _pages => [
        const Personspage(),
        Homepage(),
        Bingewatchpage(),
        Historypage(),
        Explorepage(
          key: Key(appdata.appSettings.explorePages.length.toString()),
        ),
        Musicpage(),
        const AllCategoryPage(),
      ];
  @override
  void initState() {
    _navigatorKey = GlobalKey();
    App.mainNavigatorKey = _navigatorKey;
    // _login();
    notifications.requestPermission();
    notifications.cancelAll();
    _observer = NaviObserver();
    // super.initState();

    if (appdata.firstUse[3] == "0") {
      appdata.firstUse[3] = "1";
      appdata.writeData();
    }

    // Future.delayed(const Duration(milliseconds: 300), () => Webdav.syncData())
    //     .then((v) => checkClipboard());
    // _observer = NaviObserver();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NaviPane(
      initialPage: int.parse(appdata.settings[23]),
      observer: _observer,
      paneItems: [
        PaneItemEntry(
          label: '个人',
          icon: Icons.person_outline,
          activeIcon: Icons.person,
        ),
        PaneItemEntry(
          label: '主页',
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
        ),
        PaneItemEntry(
          label: '追番',
          icon: Icons.local_activity_outlined,
          activeIcon: Icons.local_activity,
        ),
        PaneItemEntry(
          label: '历史',
          icon: Icons.history_toggle_off,
          activeIcon: Icons.history,
        ),
        PaneItemEntry(
          label: '探索',
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore_rounded,
        ),
        PaneItemEntry(
          label: '音乐',
          icon: Icons.music_note_outlined,
          activeIcon: Icons.music_note,
        ),
      ],
      paneActions: [
        PaneActionEntry(icon: Icons.search, label: "搜索", onTap: () {}),
        PaneActionEntry(
            icon: Icons.settings,
            label: "设置",
            onTap: () => SettingsPage.open()),
      ],
      pageBuilder: (index) {
        return Navigator(
          observers: [_observer],
          key: _navigatorKey,
          onGenerateRoute: (settings) => AppPageRoute(
            preventRebuild: false,
            isRootRoute: true,
            builder: (context) {
              return NaviPaddingWidget(child: _pages[index]);
            },
          ),
        );
      },
      onPageChange: (index) {
        _navigatorKey!.currentState?.pushAndRemoveUntil(
            AppPageRoute(
                preventRebuild: false,
                isRootRoute: true,
                builder: (context) {
                  return NaviPaddingWidget(child: _pages[index]);
                }),
            (route) => false);
      },
    );
  }
}
