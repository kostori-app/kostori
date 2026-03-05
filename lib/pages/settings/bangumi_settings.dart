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
        SliverAppbar(title: Text("Bangumi".tl)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: "Bangumi".tl,
                    icon: Icons.radio_button_unchecked_outlined,
                  ),
                  _SwitchSetting(
                    title: "番剧卡片使用模糊背景".tl,
                    settingKey: "animeCardUseBlur",
                    dataSource: SwitchDataSource.implicit,
                  ),
                  _SwitchSetting(
                    title: "每日番剧表启动时搜寻集信息".tl,
                    settingKey: "calendarFetchEpisodes",
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
