part of 'settings_page.dart';

class BangumiSettings extends StatefulWidget {
  const BangumiSettings({super.key});

  @override
  State<BangumiSettings> createState() => _BangumiSettingsState();
}

class _BangumiSettingsState extends State<BangumiSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.bangumi)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.bangumi,
                    icon: Icons.radio_button_unchecked_outlined,
                  ),
                  _SwitchSetting(
                    title: t.animeCardUseBlur,
                    settingKey: "animeCardUseBlur",
                    dataSource: SwitchDataSource.implicit,
                  ),
                  _IntSliderSetting(
                    title: t.bangumiCardPerRow,
                    settingsIndex: "bangumiCardPerRow",
                    options: [0, 2, 3],
                  ),
                  _SwitchSetting(
                    title: t.calendarFetchEpisodes,
                    settingKey: "calendarFetchEpisodes",
                  ),
                  _SwitchSetting(
                    title: '启用跳过bangumi日程',
                    settingKey: "enableSkipUpdate",
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
