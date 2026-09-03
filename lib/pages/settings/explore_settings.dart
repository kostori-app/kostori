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
                  _SettingRow(
                    title: t.displayModeOfAnimeTile,
                    trailing: _DisplayModeSelector(
                      value: appdata.settings['animeDisplayMode'] ?? 'brief',
                      onChanged: (v) {
                        appdata.settings['animeDisplayMode'] = v;
                        appdata.saveData();
                        // 立即刷新当前选中态 + 全局重建，让探索页等同步生效
                        if (mounted) setState(() {});
                        App.forceRebuild();
                      },
                    ),
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
                    title: t.tileTitleMarquee,
                    settingKey: "tileTitleMarquee",
                  ),
                  _SwitchSetting(
                    title: t.showFavoriteStatusOnAnimeTile,
                    settingKey: "showFavoriteStatusOnTile",
                  ),
                  _SwitchSetting(
                    title: t.showHistoryOnAnimeTile,
                    settingKey: "showHistoryStatusOnTile",
                  ),
                  _SwitchSetting(
                    title: t.horizontalLayout,
                    settingKey: "exploreHorizontalLayout",
                  ),

                  SelectSetting(
                    title: t.defaultSearchTarget,
                    settingKey: "defaultSearchTarget",
                    optionTranslation: {
                      '_aggregated_': t.aggregated,
                      ...(() {
                        var map = <String, String>{};
                        for (var c in AnimeSource.allSources()) {
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

class _ExplorePagesFilter extends StatelessWidget {
  const _ExplorePagesFilter();

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(title: t.explorePages, body: _SourcesList());
  }
}

class _SourcesList extends StatefulWidget {
  @override
  State<_SourcesList> createState() => _SourcesListState();
}

class _SourcesListState extends State<_SourcesList> {
  late List<String> sourceKeys;
  late Map<String, List<String>> sourcePages;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    var savedOrder = List<String>.from(appdata.settings.s.exploreSourcesOrder);
    sourcePages = {};
    sourceKeys = [];

    final rawMap = appdata.settings.s.explorePagesV2;
    Map<String, List<String>>? pagesMap;
    pagesMap = rawMap.map((k, v) => MapEntry(k, List<String>.from(v as List)));

    for (var key in savedOrder) {
      var source = AnimeSource.find(key);
      if (source == null) continue;
      var allPagesForSource = source.explorePages.map((e) => e.title).toList();
      if (allPagesForSource.isNotEmpty) {
        sourceKeys.add(key);
        sourcePages[key] = (pagesMap[key] ?? [])
            .where((p) => allPagesForSource.contains(p))
            .toList();
      }
    }

    for (var source in AnimeSource.allSources()) {
      if (!sourceKeys.contains(source.key)) {
        var allPagesForSource = source.explorePages
            .map((e) => e.title)
            .toList();
        if (allPagesForSource.isNotEmpty) {
          sourceKeys.add(source.key);
          sourcePages[source.key] = (pagesMap[source.key] ?? [])
              .where((p) => allPagesForSource.contains(p))
              .toList();
        }
      }
    }
  }

  void _saveData() {
    var pagesMap = <String, List<String>>{};
    for (var key in sourceKeys) {
      pagesMap[key] = sourcePages[key] ?? [];
    }
    appdata.settings.update((s) => s.copyWith(explorePagesV2: pagesMap));
    appdata.settings.update((s) => s.copyWith(exploreSourcesOrder: sourceKeys));
    appdata.saveData();
  }

  @override
  Widget build(BuildContext context) {
    return _SourceReorderableList(
      sourceKeys: sourceKeys,
      sourcePages: sourcePages,
      onReorder: (reorderFunc) {
        setState(() {
          sourceKeys = List.from(reorderFunc(sourceKeys));
        });
        _saveData();
      },
      onSourceTap: (sourceKey) {
        var source = AnimeSource.find(sourceKey);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _SourcePagesList(
              sourceKey: sourceKey,
              sourceName: source?.name ?? sourceKey,
              pages: sourcePages[sourceKey] ?? [],
              onPagesChanged: (newPages) {
                setState(() {
                  sourcePages[sourceKey] = newPages;
                });
                _saveData();
              },
            ),
          ),
        );
      },
    );
  }
}

class _SourceReorderableList extends StatelessWidget {
  final List<String> sourceKeys;
  final Map<String, List<String>> sourcePages;
  final void Function(List<String> Function(List<String>) reorderFunc)
  onReorder;
  final void Function(String sourceKey) onSourceTap;

  const _SourceReorderableList({
    required this.sourceKeys,
    required this.sourcePages,
    required this.onReorder,
    required this.onSourceTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingReorderableList<String>(
      items: sourceKeys,
      itemHeight: 64,
      itemBuilder: (sourceKey) {
        var source = AnimeSource.find(sourceKey);
        var sourceName = source?.name ?? sourceKey;
        var pageCount = sourcePages[sourceKey]?.length ?? 0;

        return ListTile(
          title: Text(sourceName),
          subtitle: Text(t.pagesCount(n: pageCount)),
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.chevron_right), Icon(Icons.drag_handle)],
          ),
          onTap: () => onSourceTap(sourceKey),
        );
      },
      onReorder: onReorder,
    );
  }
}

class _SourcePagesList extends StatefulWidget {
  final String sourceKey;
  final String sourceName;
  final List<String> pages;
  final void Function(List<String> newPages) onPagesChanged;

  const _SourcePagesList({
    required this.sourceKey,
    required this.sourceName,
    required this.pages,
    required this.onPagesChanged,
  });

  @override
  State<_SourcePagesList> createState() => _SourcePagesListState();
}

class _SourcePagesListState extends State<_SourcePagesList> {
  late List<String> _pages;

  @override
  void initState() {
    super.initState();
    _pages = widget.pages.toSet().toList();
  }

  @override
  void didUpdateWidget(_SourcePagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pages != oldWidget.pages) {
      _pages = widget.pages.toSet().toList();
    }
  }

  void _saveData() {
    widget.onPagesChanged(_pages);
  }

  void _onDelete(int index) {
    _pages.removeAt(index);
    setState(() {});
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: widget.sourceName,
      tailing: [
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text(t.add),
          onPressed: _showAddDialog,
        ),
      ],
      body: SettingReorderableList<String>(
        items: _pages,
        itemHeight: 56,
        itemKey: (page) => ValueKey("${widget.sourceKey}_$page"),
        itemBuilder: (page) {
          return ListTile(
            title: Text(page.ts(widget.sourceKey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _onDelete(_pages.indexOf(page)),
                ),
                const Icon(Icons.drag_handle),
              ],
            ),
          );
        },
        onReorder: (reorderFunc) {
          setState(() {
            _pages = List.from(reorderFunc(_pages));
          });
          _saveData();
        },
      ),
    );
  }

  void _showAddDialog() {
    var allPages =
        AnimeSource.find(
          widget.sourceKey,
        )?.explorePages.map((e) => e.title).toList() ??
        [];
    var canAdd = allPages.where((p) => !_pages.contains(p)).toList();
    var source = AnimeSource.find(widget.sourceKey);

    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: "Add ${source?.name ?? widget.sourceKey} Page",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: canAdd.map((page) {
              return ListTile(
                title: Text(page.ts(widget.sourceKey)),
                onTap: () {
                  context.pop();
                  setState(() {
                    _pages.add(page);
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
  for (var c in AnimeSource.allSources()) {
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
  for (var c in AnimeSource.allSources()) {
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
