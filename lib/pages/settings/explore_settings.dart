part of 'settings_page.dart';

class ExploreSettings extends StatefulWidget {
  const ExploreSettings({super.key});

  @override
  State<ExploreSettings> createState() => _ExploreSettingsState();
}

class _ExploreSettingsState extends State<ExploreSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.explore)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _SettingCard(
                children: [
                  SelectSetting(
                    title: t.displayModeOfAnimeTile,
                    settingKey: "animeDisplayMode",
                    optionTranslation: {
                      "detailed": t.detailed,
                      "brief": t.brief,
                    },
                  ),
                  _SliderSetting(
                    title: t.sizeOfAnimeTile,
                    settingsIndex: "animeTileScale",
                    interval: 0.05,
                    min: 0.75,
                    max: 1.25,
                  ),
                  _PopupWindowSetting(
                    title: t.explorePages,
                    builder: setExplorePagesWidget,
                  ),
                  _SwitchSetting(
                    title: t.showFavoriteStatusOnAnimeTile,
                    settingKey: "showFavoriteStatusOnTile",
                  ),
                  _SwitchSetting(
                    title: t.showHistoryOnAnimeTile,
                    settingKey: "showHistoryStatusOnTile",
                  ),

                  SelectSetting(
                    title: t.defaultSearchTarget,
                    settingKey: "defaultSearchTarget",
                    optionTranslation: {
                      '_aggregated_': t.aggregated,
                      ...(() {
                        var map = <String, String>{};
                        for (var c in AnimeSource.all()) {
                          map[c.key] = c.name;
                        }
                        return map;
                      }()),
                    },
                  ),
                  SelectSetting(
                    title: t.initialPage,
                    settingKey: "initialPage",
                    optionTranslation: {
                      '0': t.me,
                      '1': t.bangumi,
                      '2': t.following,
                      '3': t.history,
                      '4': t.explore,
                    },
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

class _ManageBlockingWordView extends StatefulWidget {
  const _ManageBlockingWordView();

  @override
  State<_ManageBlockingWordView> createState() =>
      _ManageBlockingWordViewState();
}

class _ManageBlockingWordViewState extends State<_ManageBlockingWordView> {
  @override
  Widget build(BuildContext context) {
    assert(appdata.settings["blockedWords"] is List);
    return PopUpWidgetScaffold(
      title: t.keywordBlocking,
      tailing: [
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text(t.add),
          onPressed: add,
        ),
      ],
      body: ListView.builder(
        itemCount: appdata.settings["blockedWords"].length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(appdata.settings["blockedWords"][index]),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                appdata.settings["blockedWords"].removeAt(index);
                appdata.saveData();
                setState(() {});
              },
            ),
          );
        },
      ),
    );
  }

  void add() {
    showDialog(
      context: App.rootContext,
      builder: (context) {
        var controller = TextEditingController();
        String? error;
        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              title: t.addKeyword,
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  label: Text(t.keyword),
                  errorText: error,
                ),
                onChanged: (s) {
                  if (error != null) {
                    setState(() {
                      error = null;
                    });
                  }
                },
              ).paddingHorizontal(12),
              actions: [
                Button.filled(
                  onPressed: () {
                    if (appdata.settings["blockedWords"].contains(
                      controller.text,
                    )) {
                      setState(() {
                        error = t.keywordAlreadyExists;
                      });
                      return;
                    }
                    appdata.settings["blockedWords"].add(controller.text);
                    appdata.saveData();
                    this.setState(() {});
                    context.pop();
                  },
                  child: Text(t.add),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Widget setExplorePagesWidget() {
  var pages = <String, String>{};
  for (var c in AnimeSource.all()) {
    for (var page in c.explorePages) {
      pages[page.title] = page.title.ts(c.key);
    }
  }
  return _MultiPagesFilter(
    title: t.explorePages,
    settingsIndex: "explore_pages",
    pages: pages,
  );
}

Widget setCategoryPagesWidget() {
  var pages = <String, String>{};
  for (var c in AnimeSource.all()) {
    if (c.categoryData != null) {
      pages[c.categoryData!.key] = c.categoryData!.title;
    }
  }
  return _MultiPagesFilter(
    title: t.categoryPages,
    settingsIndex: "categories",
    pages: pages,
  );
}

Widget setSearchSourcesWidget() {
  var pages = <String, String>{};
  for (var c in AnimeSource.all()) {
    if (c.searchPageData != null) {
      pages[c.key] = c.name;
    }
  }
  return _MultiPagesFilter(
    title: t.searchSources,
    settingsIndex: "searchSources",
    pages: pages,
  );
}
