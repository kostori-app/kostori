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
        SliverAppbar(title: Text("Explore".tl)),
        SelectSetting(
          title: "Display mode of anime tile".tl,
          settingKey: "animeDisplayMode",
          optionTranslation: {
            "detailed": "Detailed".tl,
            "brief": "Brief".tl,
          },
        ).toSliver(),
        _SliderSetting(
          title: "Size of anime tile".tl,
          settingsIndex: "animeTileScale",
          interval: 0.05,
          min: 0.75,
          max: 1.25,
        ).toSliver(),
        _PopupWindowSetting(
          title: "Explore Pages".tl,
          builder: setExplorePagesWidget,
        ).toSliver(),
        _SwitchSetting(
          title: "Show favorite status on anime tile".tl,
          settingKey: "showFavoriteStatusOnTile",
        ).toSliver(),
        _SwitchSetting(
          title: "Show history on anime tile".tl,
          settingKey: "showHistoryStatusOnTile",
        ).toSliver(),
        SelectSetting(
          title: "Default Search Target".tl,
          settingKey: "defaultSearchTarget",
          optionTranslation: {
            '_aggregated_': "Aggregated".tl,
            ...(() {
              var map = <String, String>{};
              for (var c in AnimeSource.all()) {
                map[c.key] = c.name;
              }
              return map;
            }()),
          },
        ).toSliver(),
        SelectSetting(
          title: "Initial Page".tl,
          settingKey: "initialPage",
          optionTranslation: {
            '0': "Me".tl,
            '1': "Bangumi".tl,
            '2': "Following".tl,
            '3': "History".tl,
            '4': "Explore".tl,
          },
        ).toSliver(),
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
      title: "Keyword blocking".tl,
      tailing: [
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text("Add".tl),
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
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "Add keyword".tl,
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                label: Text("Keyword".tl),
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
                  if (appdata.settings["blockedWords"]
                      .contains(controller.text)) {
                    setState(() {
                      error = "Keyword already exists".tl;
                    });
                    return;
                  }
                  appdata.settings["blockedWords"].add(controller.text);
                  appdata.saveData();
                  this.setState(() {});
                  context.pop();
                },
                child: Text("Add".tl),
              ),
            ],
          );
        });
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
    title: "Explore Pages".tl,
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
    title: "Category Pages".tl,
    settingsIndex: "categories",
    pages: pages,
  );
}

Widget setFavoritesPagesWidget() {
  var pages = <String, String>{};
  for (var c in AnimeSource.all()) {
    if (c.favoriteData != null) {
      pages[c.favoriteData!.key] = c.favoriteData!.title;
    }
  }
  return _MultiPagesFilter(
    title: "Network Favorite Pages".tl,
    settingsIndex: "favorites",
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
    title: "Search Sources".tl,
    settingsIndex: "searchSources",
    pages: pages,
  );
}
