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
        SliverAppbar(title: Text("Local Favorites".tl)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                SelectSetting(
                  title: "Add new favorite to".tl,
                  settingKey: "newFavoriteAddTo",
                  optionTranslation: {"start": "Start".tl, "end": "End".tl},
                ),
                SelectSetting(
                  title: "Quick Favorite".tl,
                  settingKey: "quickFavorite",
                  help:
                      "Long press on the favorite button to quickly add to this folder"
                          .tl,
                  optionTranslation: {
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default') e: e,
                  },
                ),
                SelectSetting(
                  title: "Favorite Type".tl + "Wish".tl,
                  settingKey: "FavoriteTypeWish",
                  help: "Mark the selected favorites as".tl + "Wish".tl,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeWish'])
                        e: e,
                  },
                ),
                SelectSetting(
                  title: "Favorite Type".tl + "Doing".tl,
                  settingKey: "FavoriteTypeDoing",
                  help: "Mark the selected favorites as".tl + "Doing".tl,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeDoing'])
                        e: e,
                  },
                ),
                SelectSetting(
                  title: "Favorite Type".tl + "Collect".tl,
                  settingKey: "FavoriteTypeCollect",
                  help: "Mark the selected favorites as".tl + "Collect".tl,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeCollect'])
                        e: e,
                  },
                ),
                SelectSetting(
                  title: "Favorite Type".tl + "On Hold".tl,
                  settingKey: "FavoriteTypeOnHold",
                  help: "Mark the selected favorites as".tl + "On Hold".tl,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeOnHold'])
                        e: e,
                  },
                ),
                SelectSetting(
                  title: "Favorite Type".tl + "Dropped".tl,
                  settingKey: "FavoriteTypeDropped",
                  help: "Mark the selected favorites as".tl + "Dropped".tl,
                  optionTranslation: {
                    'none': 'none',
                    for (var e in LocalFavoritesManager().folderNames)
                      if (e != 'default' && !excludeSet.contains(e) ||
                          e == appdata.settings['FavoriteTypeDropped'])
                        e: e,
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
