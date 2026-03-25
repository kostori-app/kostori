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
  return _ExplorePagesFilter();
}

class _ExplorePagesFilter extends StatefulWidget {
  const _ExplorePagesFilter();

  @override
  State<_ExplorePagesFilter> createState() => _ExplorePagesFilterState();
}

enum _ItemType { source, page }

class _ListItem {
  _ListItem({
    required this.id,
    required this.type,
    this.sourceKey,
    this.title,
    this.pageTitle,
    this.pageIndex,
    this.sourceIndex,
    this.hasAdd = false,
  });

  final String id;
  final _ItemType type;
  final String? sourceKey;
  final String? title;
  final String? pageTitle;
  final int? pageIndex;
  final int? sourceIndex;
  final bool hasAdd;
}

class _ExplorePagesFilterState extends State<_ExplorePagesFilter> {
  late List<String> sourceKeys;
  late Map<String, List<String>> sourcePages;
  late Map<String, bool> sourceExpanded;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    var selectedPages = List<String>.from(appdata.settings["explore_pages"]);
    var savedOrder = List<String>.from(
      appdata.settings["explore_sources_order"] ?? [],
    );
    sourcePages = {};
    sourceExpanded = {};
    sourceKeys = [];

    // 按保存的顺序加载
    for (var key in savedOrder) {
      var source = AnimeSource.find(key);
      if (source == null) continue;
      var pagesForSource = source.explorePages.map((e) => e.title).toList();
      var selectedForSource = pagesForSource
          .where((p) => selectedPages.contains(p))
          .toList();
      if (pagesForSource.isNotEmpty) {
        sourceKeys.add(key);
        sourcePages[key] = selectedForSource;
        sourceExpanded[key] = selectedForSource.isNotEmpty;
      }
    }

    // 添加新出现的源（未保存顺序的）
    for (var source in AnimeSource.all()) {
      if (!sourceKeys.contains(source.key)) {
        var pagesForSource = source.explorePages.map((e) => e.title).toList();
        var selectedForSource = pagesForSource
            .where((p) => selectedPages.contains(p))
            .toList();
        if (pagesForSource.isNotEmpty) {
          sourceKeys.add(source.key);
          sourcePages[source.key] = selectedForSource;
          sourceExpanded[source.key] = selectedForSource.isNotEmpty;
        }
      }
    }
  }

  void _saveData() {
    var allSelected = <String>[];
    for (var key in sourceKeys) {
      allSelected.addAll(sourcePages[key] ?? []);
    }
    appdata.settings["explore_pages"] = allSelected;
    appdata.settings["explore_sources_order"] = List<String>.from(sourceKeys);
    appdata.saveData();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.explorePages,
      body: _buildReorderableList(),
    );
  }

  Widget _buildReorderableList() {
    var items = <_ListItem>[];

    for (var i = 0; i < sourceKeys.length; i++) {
      var sourceKey = sourceKeys[i];
      var source = AnimeSource.find(sourceKey);
      var sourceName = source?.name ?? sourceKey;
      var selectedPages = sourcePages[sourceKey] ?? [];
      var allPages = source?.explorePages.map((e) => e.title).toList() ?? [];

      // 源项
      items.add(
        _ListItem(
          id: "source_$sourceKey",
          type: _ItemType.source,
          sourceKey: sourceKey,
          title: sourceName,
          hasAdd: selectedPages.length < allPages.length,
          sourceIndex: i,
        ),
      );

      // 如果展开，显示页面项
      if (sourceExpanded[sourceKey] ?? false) {
        for (var j = 0; j < selectedPages.length; j++) {
          items.add(
            _ListItem(
              id: "page_${sourceKey}_${selectedPages[j]}",
              type: _ItemType.page,
              sourceKey: sourceKey,
              title: selectedPages[j].ts(sourceKey),
              pageTitle: selectedPages[j],
              pageIndex: j,
            ),
          );
        }
      }
    }

    return ReorderableListView.builder(
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          var oldItem = items[oldIndex];
          var newItem = items[newIndex];

          // 只能在同类型间排序
          if (oldItem.type != newItem.type) return;

          if (oldItem.type == _ItemType.source) {
            var oldSourceIdx = sourceKeys.indexOf(oldItem.sourceKey!);
            var newSourceIdx = sourceKeys.indexOf(newItem.sourceKey!);
            if (oldSourceIdx >= 0 && newSourceIdx >= 0) {
              var key = sourceKeys.removeAt(oldSourceIdx);
              var insertIdx = newSourceIdx > oldSourceIdx
                  ? newSourceIdx - 1
                  : newSourceIdx;
              sourceKeys.insert(insertIdx, key);
            }
          } else if (oldItem.type == _ItemType.page) {
            var sourceKey = oldItem.sourceKey!;
            var pages = sourcePages[sourceKey] ?? [];
            var oldPageIdx = pages.indexOf(oldItem.pageTitle!);
            var newPageIdx = pages.indexOf(newItem.pageTitle!);
            if (oldPageIdx >= 0 && newPageIdx >= 0) {
              var page = pages.removeAt(oldPageIdx);
              var insertIdx = newPageIdx > oldPageIdx
                  ? newPageIdx - 1
                  : newPageIdx;
              pages.insert(insertIdx, page);
              sourcePages[sourceKey] = pages;
            }
          }
        });
        _saveData();
      },
      itemBuilder: (context, index) {
        var item = items[index];
        if (item.type == _ItemType.source) {
          return ListTile(
            key: Key(item.id),
            leading: const Icon(Icons.drag_handle),
            title: Row(
              children: [
                Expanded(child: Text(item.title ?? '')),
                if (item.hasAdd)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      var allPages =
                          AnimeSource.find(
                            item.sourceKey!,
                          )?.explorePages.map((e) => e.title).toList() ??
                          [];
                      _showAddDialog(
                        item.sourceKey!,
                        allPages,
                        sourcePages[item.sourceKey] ?? [],
                      );
                    },
                  ),
                IconButton(
                  icon: Icon(
                    sourceExpanded[item.sourceKey] ?? false
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      sourceExpanded[item.sourceKey!] =
                          !(sourceExpanded[item.sourceKey] ?? false);
                    });
                    _saveData();
                  },
                ),
              ],
            ),
          );
        } else {
          return ListTile(
            key: Key(item.id),
            leading: const Icon(Icons.drag_handle),
            title: Text(item.title ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  sourcePages[item.sourceKey!]?.remove(item.pageTitle);
                });
                _saveData();
              },
            ),
          );
        }
      },
    );
  }

  void _showAddDialog(
    String sourceKey,
    List<String> allPages,
    List<String> selectedPages,
  ) {
    var canAdd = allPages.where((p) => !selectedPages.contains(p)).toList();
    var source = AnimeSource.find(sourceKey);

    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: "Add ${source?.name ?? sourceKey} Page",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: canAdd.map((page) {
              return ListTile(
                title: Text(page.ts(sourceKey)),
                onTap: () {
                  context.pop();
                  setState(() {
                    sourcePages[sourceKey]!.add(page);
                  });
                  _saveData();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
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
