import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/pages/bangumi_page.dart';
import 'package:kostori/pages/explore_Page.dart';
import 'package:kostori/pages/favorites/favorites_page.dart';
import 'package:kostori/pages/history_page.dart';
import 'package:kostori/pages/search_page.dart';
import 'package:kostori/pages/settings/anime_source_settings.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/translations.dart';

import 'bangumi/bangumi.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final NaviObserver _observer;

  GlobalKey<NavigatorState>? _navigatorKey;

  void to(Widget Function() widget, {bool preventDuplicate = false}) async {
    if (preventDuplicate) {
      var page = widget();
      if ("/${page.runtimeType}" == _observer.routes.last.toString()) return;
    }
    _navigatorKey!.currentContext!.to(widget);
  }

  void back() {
    _navigatorKey!.currentContext!.pop();
  }

  void checkUpdates() async {
    var lastCheck = appdata.implicitData['lastCheckUpdate'] ?? 0;
    if (appdata.settings['bangumiDataVer'] == null) {
      await Bangumi.checkBangumiData();
    }
    var now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastCheck < 24 * 60 * 60 * 1000) {
      return;
    }
    appdata.implicitData['lastCheckUpdate'] = now;
    appdata.writeImplicitData();
    AnimeSourceSettings.checkAnimeSourceUpdate();
    await Bangumi.getCalendarData();
    await Bangumi.checkBangumiData();
    if (appdata.settings['checkUpdateOnStart']) {
      await Future.delayed(const Duration(milliseconds: 300));
      await checkUpdateUi(false);
    }
  }

  @override
  void initState() {
    checkUpdates();
    _observer = NaviObserver();
    _navigatorKey = GlobalKey();
    App.mainNavigatorKey = _navigatorKey;
    super.initState();
  }

  final _pages = [
    // const Personspage(),
    const BangumiPage(
      key: PageStorageKey('bangumi'),
    ),
    const FavoritesPage(
      key: PageStorageKey('favorites'),
    ),
    const HistoryPage(key: PageStorageKey('history')),
    const ExplorePage(
      key: PageStorageKey('explore'),
    ),
    // const Musicpage(),
  ];

  var index = 0;

  @override
  Widget build(BuildContext context) {
    return NaviPane(
      observer: _observer,
      navigatorKey: _navigatorKey!,
      paneItems: [
        PaneItemEntry(
          label: '番组计划',
          icon: Icons.account_balance_outlined,
          activeIcon: Icons.account_balance,
        ),
        PaneItemEntry(
          label: '追番',
          icon: Icons.star_border,
          activeIcon: Icons.star,
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
        // PaneItemEntry(
        //   label: '音乐',
        //   icon: Icons.music_note_outlined,
        //   activeIcon: Icons.music_note,
        // ),
      ],
      paneActions: [
        // if(index != 0)
        PaneActionEntry(
          icon: Icons.search,
          label: "Search".tl,
          onTap: () {
            to(() => const SearchPage(), preventDuplicate: true);
          },
        ),
        PaneActionEntry(
          icon: Icons.settings,
          label: "Settings".tl,
          onTap: () {
            to(() => const SettingsPage(), preventDuplicate: true);
          },
        )
      ],
      pageBuilder: (index) {
        return _pages[index];
      },
      onPageChanged: (index) {
        HapticFeedback.selectionClick();
      },
    );
  }
}
