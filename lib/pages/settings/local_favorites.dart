part of 'settings_page.dart';

class LocalFavoritesSettings extends StatefulWidget {
  const LocalFavoritesSettings({super.key});

  @override
  State<LocalFavoritesSettings> createState() => _LocalFavoritesSettingsState();
}

class _LocalFavoritesSettingsState extends State<LocalFavoritesSettings> {
  final excludeSet = {
    appdata.settings.s.favoriteTypeWish,
    appdata.settings.s.favoriteTypeDoing,
    appdata.settings.s.favoriteTypeCollect,
    appdata.settings.s.favoriteTypeOnHold,
    appdata.settings.s.favoriteTypeDropped,
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
                  settingKey: "favoriteTypeWish",
                  help: t.markTheSelectedFavoritesAs + t.wishStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings.s.favoriteTypeWish)
                        e: e,
                  },
                ),
                SelectSetting(
                  title: t.favoriteType + t.doingStatus,
                  settingKey: "favoriteTypeDoing",
                  help: t.markTheSelectedFavoritesAs + t.doingStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings.s.favoriteTypeDoing)
                        e: e,
                  },
                ),
                SelectSetting(
                  title: t.favoriteType + t.collectStatus,
                  settingKey: "favoriteTypeCollect",
                  help: t.markTheSelectedFavoritesAs + t.collectStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings.s.favoriteTypeCollect)
                        e: e,
                  },
                ),
                SelectSetting(
                  title: t.favoriteType + t.onHoldStatus,
                  settingKey: "favoriteTypeOnHold",
                  help: t.markTheSelectedFavoritesAs + t.onHoldStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings.s.favoriteTypeOnHold)
                        e: e,
                  },
                ),
                SelectSetting(
                  title: t.favoriteType + t.droppedStatus,
                  settingKey: "favoriteTypeDropped",
                  help: t.markTheSelectedFavoritesAs + t.droppedStatus,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings.s.favoriteTypeDropped)
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
