import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/bangumi/bangumi_page.dart';
import 'package:kostori/pages/categories_page.dart';
import 'package:kostori/pages/explore_Page.dart';
import 'package:kostori/pages/favorites/favorites_page.dart';
import 'package:kostori/pages/history_page.dart';
import 'package:kostori/pages/me_page.dart';
import 'package:kostori/pages/search_page.dart';
import 'package:kostori/pages/settings/settings_page.dart';

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

  @override
  void initState() {
    _observer = NaviObserver();
    _navigatorKey = GlobalKey();
    App.mainNavigatorKey = _navigatorKey;
    index = int.tryParse(appdata.settings['initialPage'].toString()) ?? 0;
    super.initState();
  }

  final _pages = [
    const MePage(key: PageStorageKey('me')),
    const BangumiPage(key: PageStorageKey('bangumi')),
    const FavoritesPage(key: PageStorageKey('favorites')),
    const HistoryPage(key: PageStorageKey('history')),
    const ExplorePage(key: PageStorageKey('explore')),
  ];

  var index = 0;

  @override
  Widget build(BuildContext context) {
    return NaviPane(
      initialPage: index,
      observer: _observer,
      navigatorKey: _navigatorKey!,
      paneItems: [
        PaneItemEntry(
          label: t.me,
          icon: Icons.person_outline,
          activeIcon: Icons.person,
        ),
        PaneItemEntry(
          label: t.bangumi,
          icon: Icons.account_balance_outlined,
          activeIcon: Icons.account_balance,
        ),
        PaneItemEntry(
          label: t.following,
          icon: Icons.star_border,
          activeIcon: Icons.star,
        ),
        PaneItemEntry(
          label: t.history,
          icon: Icons.history_toggle_off,
          activeIcon: Icons.history,
        ),
        PaneItemEntry(
          label: t.explore,
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore_rounded,
        ),
      ],
      paneActions: [
        PaneActionEntry(
          icon: Icons.search,
          label: t.search,
          onTap: () {
            to(() => const SearchPage(), preventDuplicate: true);
          },
        ),
        PaneActionEntry(
          icon: Icons.category,
          label: t.categories,
          onTap: () {
            to(() => const CategoriesPage(), preventDuplicate: true);
          },
        ),
        PaneActionEntry(
          icon: Icons.settings,
          label: t.settings,
          onTap: () {
            to(() => const SettingsPage(), preventDuplicate: true);
          },
        ),
      ],
      pageBuilder: (index) {
        return _pages[index];
      },
      onPageChanged: (i) {
        HapticFeedback.selectionClick();
        setState(() {
          index = i;
        });
      },
    );
  }
}
