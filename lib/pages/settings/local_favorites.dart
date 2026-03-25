part of 'settings_page.dart';

class LocalFavoritesSettings extends StatefulWidget {
  const LocalFavoritesSettings({super.key});

  @override
  State<LocalFavoritesSettings> createState() => _LocalFavoritesSettingsState();
}

class _LocalFavoritesSettingsState extends State<LocalFavoritesSettings> {
  final excludeSet = {
    appdata.settings['FavoriteTypeWish'],
    appdata.settings['FavoriteTypeDoing'],
    appdata.settings['FavoriteTypeCollect'],
    appdata.settings['FavoriteTypeOnHold'],
    appdata.settings['FavoriteTypeDropped'],
  };

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.localFavorites)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                SelectSetting(
                  title: t.addNewFavoriteTo,
                  settingKey: "newFavoriteAddTo",
                  optionTranslation: {"start": t.start, "end": t.end},
                ),
                SelectSetting(
                  title: t.quickFavorite,
                  settingKey: "quickFavorite",
                  help: t.longPressOnTheFavoriteButtonToQuicklyAddToThisFolder,
                  optionTranslation: {
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default') e: e,
                  },
                ),
                SelectSetting(
                  title: t.favoriteType + t.wishStatus,
                  settingKey: "FavoriteTypeWish",
                  help: t.markTheSelectedFavoritesAs + t.wishStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeWish'])
                        e: e,
                  },
                ),
                SelectSetting(
                  title: t.favoriteType + t.doingStatus,
                  settingKey: "FavoriteTypeDoing",
                  help: t.markTheSelectedFavoritesAs + t.doingStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeDoing'])
                        e: e,
                  },
                ),
                SelectSetting(
                  title: t.favoriteType + t.collectStatus,
                  settingKey: "FavoriteTypeCollect",
                  help: t.markTheSelectedFavoritesAs + t.collectStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeCollect'])
                        e: e,
                  },
                ),
                SelectSetting(
                  title: t.favoriteType + t.onHoldStatus,
                  settingKey: "FavoriteTypeOnHold",
                  help: t.markTheSelectedFavoritesAs + t.onHoldStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeOnHold'])
                        e: e,
                  },
                ),
                SelectSetting(
                  title: t.favoriteType + t.droppedStatus,
                  settingKey: "FavoriteTypeDropped",
                  help: t.markTheSelectedFavoritesAs + t.droppedStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeDropped'])
                        e: e,
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
