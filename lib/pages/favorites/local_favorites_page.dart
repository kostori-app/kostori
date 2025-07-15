part of 'favorites_page.dart';

const _asyncDataFetchLimit = 500;

final excludedFolders = ["default", "默认"];

class _LocalFavoritesPage extends StatefulWidget {
  const _LocalFavoritesPage({required this.favoritesController});

  final FavoritesController favoritesController;

  @override
  State<_LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<_LocalFavoritesPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ScrollController scrollController = ScrollController();

  late _FavoritesPageState favPage;
  late FavoriteSortType sortType;

  FavoritesController get favoritesController => widget.favoritesController;

  Map<Anime, bool> selectedAnimes = {};

  var selectedLocalFolders = <String>{};

  late List<String> added = [];

  String keyword = "";

  bool searchMode = false;
  bool searchAllMode = false;

  bool multiSelectMode = false;

  int? lastSelectedIndex;

  LocalFavoritesManager get manager => LocalFavoritesManager();

  bool isLoading = false;

  Map<String, List<FavoriteItem>> searchResults = {};

  void updateSearchAllResult() {
    setState(() {
      if (keyword.trim().isEmpty) {
        searchResults = Map.from(favoritesController.animes);
        favoritesController.tabs = getTabs();
      } else {
        searchResults = {};
        for (var entry in favoritesController.animes.entries) {
          final filtered = entry.value
              .where((anime) => matchKeyword(keyword, anime))
              .toList();
          if (filtered.isNotEmpty) {
            searchResults[entry.key] = filtered;
          }
        }
        favoritesController.tabs = getTabs();
      }
    });
  }

  Future<void> updateAnimes() async {
    if (isLoading) return;
    final Map<String, List<FavoriteItem>> result = {};

    favoritesController.folders = manager.folderNames.where((name) {
      if (name == 'default') {
        return manager
            .getAllAnimes('default', FavoriteSortType.nameAsc)
            .isNotEmpty;
      }
      return true;
    }).toList();

    for (var folder in favoritesController.folders) {
      final count = manager.folderAnimes(folder);
      if (count < _asyncDataFetchLimit) {
        result[folder] = manager.getAllAnimes(folder, sortType);
      } else {
        isLoading = true;
        result[folder] = await manager
            .getFolderAnimesAsync(folder, sortType)
            .minTime(const Duration(milliseconds: 200));
      }
    }

    if (favoritesController.isRefreshEnabled) {
      final data = appdata.implicitData['favoriteFolder'];

      if (data != null) {
        favoritesController.index = favoritesController.folders.indexWhere(
          (folderName) => folderName == data['name'],
        );
      }
      if (favoritesController.index < 0 ||
          favoritesController.index >= favoritesController.folders.length) {
        favoritesController.index = 0;
      }
      favoritesController.tabs.clear();
      favoritesController.tabs = getTabs();
      favoritesController.folder =
          favoritesController.folders[favoritesController.index];
      favPage.setFolder(false, favoritesController.folder);
      favoritesController.tabController.dispose();
      favoritesController.tabController = TabController(
        length: favoritesController.folders.length,
        vsync: this,
        initialIndex: favoritesController.index,
      );
      favoritesController.tabController.addListener(() {
        setState(() {
          int indexs = favoritesController.tabController.index;
          String folderName = favoritesController.folders[indexs];
          if (multiSelectMode) {
            multiSelectMode = false;
            selectedAnimes.clear();
          }
          favoritesController.folder = folderName;
          favPage.setFolder(false, folderName);
        });
      });
      favoritesController.isRefreshEnabled = false;
    }

    if (!mounted) return;

    setState(() {
      favoritesController.animes.clear();
      favoritesController.animes.addAll(result);
      isLoading = false;
    });
  }

  bool matchKeyword(String keyword, FavoriteItem anime) {
    var list = keyword.split(" ");
    for (var k in list) {
      if (k.isEmpty) continue;
      if (anime.title.contains(k)) {
        continue;
      } else if (anime.subtitle != null && anime.subtitle!.contains(k)) {
        continue;
      } else if (anime.tags.any((tag) {
        if (tag == k) {
          return true;
        } else if (tag.contains(':') && tag.split(':')[1] == k) {
          return true;
        }
        return false;
      })) {
        continue;
      } else if (anime.author == k) {
        continue;
      }
      return false;
    }
    return true;
  }

  @override
  void initState() {
    // favoritesController.isRefreshEnabled = true;
    var sort = appdata.implicitData["favori_sort"] ?? "displayOrder_asc";
    sortType = FavoriteSortType.fromString(sort);
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
    favoritesController.folders = manager.folderNames.where((name) {
      if (name == 'default') {
        return manager
            .getAllAnimes('default', FavoriteSortType.nameAsc)
            .isNotEmpty;
      }
      return true;
    }).toList();
    final data = appdata.implicitData['favoriteFolder'];

    if (data != null) {
      favoritesController.index = favoritesController.folders.indexWhere(
        (folderName) => folderName == data['name'],
      );
    }
    if (favoritesController.index < 0 ||
        favoritesController.index >= favoritesController.folders.length) {
      favoritesController.index = 0;
    }

    favoritesController.folder =
        favoritesController.folders[favoritesController.index];
    favoritesController.tabController = TabController(
      length: favoritesController.folders.length,
      vsync: this,
      initialIndex: favoritesController.index,
    );
    favoritesController.tabController.addListener(() {
      setState(() {
        int indexs = favoritesController.tabController.index;
        String folderName = favoritesController.folders[indexs];
        if (multiSelectMode) {
          multiSelectMode = false;
          selectedAnimes.clear();
        }
        favoritesController.folder = folderName;
        favPage.setFolder(false, folderName);
      });
    });
    updateAnimes();
    manager.addListener(updateAnimes);
    super.initState();
  }

  @override
  void dispose() {
    favoritesController.tabController.dispose();
    manager.removeListener(updateAnimes);
    super.dispose();
  }

  void update() {
    setState(() {});
  }

  void selectAll() {
    setState(() {
      selectedAnimes = {};
      final currentList = searchMode
          ? (searchResults[favoritesController.folder] ?? [])
          : (favoritesController.animes[favoritesController.folder] ?? []);
      for (var anime in currentList) {
        selectedAnimes[anime] = true;
      }
    });
  }

  void invertSelection() {
    setState(() {
      final currentList = searchMode
          ? (searchResults[favoritesController.folder] ?? [])
          : (favoritesController.animes[favoritesController.folder] ?? []);
      for (var anime in currentList) {
        if (selectedAnimes.containsKey(anime)) {
          selectedAnimes.remove(anime);
        } else {
          selectedAnimes[anime] = true;
        }
      }
    });
  }

  List<Tab> getTabs() {
    return favoritesController.folders.map((name) {
      int count = manager.folderAnimes(name);
      return Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                name == 'default' ? 'default'.tl : name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                searchAllMode
                    ? searchResults[name] == null
                          ? '0'
                          : searchResults[name]!.length.toString()
                    : count.toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  MenuButton _buildSortMenuItems() {
    return MenuButton(
      icon: Icons.sort,
      message: "Sort",
      entries: [
        MenuEntry(
          icon: Icons.receipt_long,
          endIcon:
              (sortType == FavoriteSortType.recentlyWatchedAsc ||
                  sortType == FavoriteSortType.recentlyWatchedDesc)
              ? (sortType == FavoriteSortType.recentlyWatchedAsc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward)
              : null,
          text: "最近观看".tl,
          onClick: () {
            setState(() {
              sortType = sortType == FavoriteSortType.recentlyWatchedAsc
                  ? FavoriteSortType.recentlyWatchedDesc
                  : FavoriteSortType.recentlyWatchedAsc;
              appdata.implicitData["favori_sort"] = sortType.value;
              appdata.writeImplicitData();
              updateAnimes();
            });
          },
        ),
        MenuEntry(
          icon: Icons.sort_by_alpha,
          endIcon:
              (sortType == FavoriteSortType.nameAsc ||
                  sortType == FavoriteSortType.nameDesc)
              ? (sortType == FavoriteSortType.nameAsc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward)
              : null,
          text: "按名称".tl,
          onClick: () {
            setState(() {
              sortType = sortType == FavoriteSortType.nameAsc
                  ? FavoriteSortType.nameDesc
                  : FavoriteSortType.nameAsc;
              appdata.implicitData["favori_sort"] = sortType.value;
              appdata.writeImplicitData();
              updateAnimes();
            });
          },
        ),
        MenuEntry(
          icon: Icons.access_time,
          endIcon:
              (sortType == FavoriteSortType.timeAsc ||
                  sortType == FavoriteSortType.timeDesc)
              ? (sortType == FavoriteSortType.timeAsc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward)
              : null,
          text: "按时间".tl,
          onClick: () {
            setState(() {
              sortType = sortType == FavoriteSortType.timeAsc
                  ? FavoriteSortType.timeDesc
                  : FavoriteSortType.timeAsc;
              appdata.implicitData["favori_sort"] = sortType.value;
              appdata.writeImplicitData();
              updateAnimes();
            });
          },
        ),
        MenuEntry(
          icon: Icons.view_list,
          endIcon:
              (sortType == FavoriteSortType.displayOrderAsc ||
                  sortType == FavoriteSortType.displayOrderDesc)
              ? (sortType == FavoriteSortType.displayOrderAsc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward)
              : null,
          text: "默认顺序".tl,
          onClick: () {
            setState(() {
              sortType = sortType == FavoriteSortType.displayOrderAsc
                  ? FavoriteSortType.displayOrderDesc
                  : FavoriteSortType.displayOrderAsc;
              appdata.implicitData["favori_sort"] = sortType.value;
              appdata.writeImplicitData();
              updateAnimes();
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (favoritesController.tabs.isEmpty) {
      favoritesController.tabs = getTabs();
    }
    PreferredSizeWidget tab = PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Observer(
        builder: (_) => TabBar(
          controller: favoritesController.tabController,
          isScrollable: true,
          tabs: favoritesController.tabs,
          dividerHeight: 0,
          tabAlignment: TabAlignment.start,
          labelColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    Widget body = NestedScrollView(
      controller: scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        if (!searchAllMode && !searchMode && !multiSelectMode)
          SliverAppbar(
            key: PageStorageKey(
              "${manager.folderAnimes(favoritesController.folder)}",
            ),
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Folders".tl,
              child: context.width <= _kTwoPanelChangeWidth
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      color: context.colorScheme.primary,
                      onPressed: favPage.showFolderSelector,
                    )
                  : const SizedBox(),
            ),
            title: GestureDetector(
              onTap: context.width < _kTwoPanelChangeWidth
                  ? favPage.showFolderSelector
                  : null,
              child: Text(favPage.folder != null ? '' : "Unselected".tl),
            ),
            actions: [
              Tooltip(
                message: "Search".tl,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      keyword = "";
                      searchAllMode = true;
                      updateSearchAllResult();
                    });
                  },
                  onLongPress: () {
                    setState(() {
                      keyword = "";
                      searchAllMode = true;
                      updateSearchAllResult();
                    });
                  },
                ),
              ),
              _buildSortMenuItems(),
              MenuButton(
                entries: [
                  if (favoritesController.folder != 'default')
                    MenuEntry(
                      icon: Icons.edit_outlined,
                      text: "Rename".tl,
                      onClick: () {
                        showInputDialog(
                          context: App.rootContext,
                          title: "Rename".tl,
                          hintText: "New Name".tl,
                          onConfirm: (value) {
                            var err = validateFolderName(value.toString());
                            if (err != null) {
                              return err;
                            }
                            favoritesController.isRefreshEnabled = true;
                            manager.rename(
                              favoritesController.folder,
                              value.toString(),
                            );
                            manager.initCounts();
                            // favPage.folderList?.updateFolders();
                            favPage.setFolder(false, value.toString());
                            return null;
                          },
                        );
                      },
                    ),
                  MenuEntry(
                    icon: Icons.upload_file,
                    text: "Export".tl,
                    onClick: () {
                      var json = manager.folderToJson(
                        favoritesController.folder,
                      );
                      saveFile(
                        data: utf8.encode(json),
                        filename: "$favoritesController.folder.json",
                      );
                    },
                  ),
                  if (favoritesController.folder != 'default')
                    MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Folder".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        showConfirmDialog(
                          context: App.rootContext,
                          title: "Delete".tl,
                          content: "Delete folder '@f' ?".tlParams({
                            "f": favoritesController.folder,
                          }),
                          btnColor: context.colorScheme.error,
                          onConfirm: () {
                            favoritesController.isRefreshEnabled = true;
                            manager.deleteFolder(favoritesController.folder);
                            int oldIndex = favoritesController.index;
                            if (favoritesController.folders.isEmpty) {
                              favoritesController.index = 0;
                              favoritesController.folder = '';
                              favPage.setFolder(false, null);
                            } else {
                              if (oldIndex >=
                                  favoritesController.folders.length) {
                                favoritesController.index =
                                    favoritesController.folders.length - 1;
                              } else {
                                favoritesController.index = oldIndex;
                              }

                              favoritesController.folder = favoritesController
                                  .folders[favoritesController.index];
                              favPage.setFolder(
                                false,
                                favoritesController.folder,
                              );
                            }
                            setState(() {});
                            // updateAnimes();
                          },
                        );
                      },
                    ),
                ],
              ),
            ],
            bottom: tab,
          )
        else if (multiSelectMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    multiSelectMode = false;
                    selectedAnimes.clear();
                  });
                },
              ),
            ),
            title: Text(
              "Selected @c animes".tlParams({"c": selectedAnimes.length}),
            ),
            actions: [
              MenuButton(
                entries: [
                  MenuEntry(
                    icon: Icons.star_rounded,
                    text: "Favorite actions".tl,
                    onClick: () async {
                      favoritesController.isRefreshEnabled = true;
                      await _FavoriteDialog.show(
                        context: context,
                        selectedAnimes: selectedAnimes,
                        favPage: favPage,
                        cancel: () => _cancel(),
                        favoritesController: favoritesController,
                      ).then((_) {
                        manager.initCounts();
                        Future.delayed(const Duration(seconds: 1), () async {
                          if (!mounted) return;
                          favoritesController.isRefreshEnabled = true;
                          await updateAnimes();
                          favoritesController.tabs = getTabs();
                          setState(() {});
                        });
                      });
                    },
                  ),
                  MenuEntry(
                    icon: Icons.select_all,
                    text: "Select All".tl,
                    onClick: selectAll,
                  ),
                  MenuEntry(
                    icon: Icons.deselect,
                    text: "Deselect".tl,
                    onClick: _cancel,
                  ),
                  MenuEntry(
                    icon: Icons.flip,
                    text: "Invert Selection".tl,
                    onClick: invertSelection,
                  ),
                  MenuEntry(
                    icon: Icons.delete_outline,
                    text: "Delete Anime".tl,
                    color: context.colorScheme.error,
                    onClick: () {
                      showConfirmDialog(
                        context: context,
                        title: "Delete".tl,
                        content: "Delete @c animes?".tlParams({
                          "c": selectedAnimes.length,
                        }),
                        btnColor: context.colorScheme.error,
                        onConfirm: () {
                          _deleteAnimeWithId();
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
            bottom: tab,
          )
        else if (searchAllMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    searchAllMode = false;
                    favoritesController.isRefreshEnabled = true;
                    updateAnimes();
                  });
                },
              ),
            ),
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search All".tl,
                border: UnderlineInputBorder(),
              ),
              onChanged: (v) {
                keyword = v;
                updateSearchAllResult();
              },
            ).paddingBottom(4).paddingRight(8),
            bottom: tab,
          ),
      ],
      body: isLoading
          ? Center(
              child: SizedBox(
                height: 200,
                width: 200,
                child: MiscComponents.placeholder(
                  context,
                  200,
                  200,
                  Colors.transparent,
                ),
              ),
            )
          : TabBarView(
              key: PageStorageKey("${favoritesController.folders}"),
              controller: favoritesController.tabController,
              children: favoritesController.folders.map((name) {
                return SmoothCustomScrollView(
                  key: PageStorageKey("local_$name"),
                  slivers: [
                    Observer(
                      builder: (context) => SliverGridAnimes(
                        animes: searchAllMode
                            ? (searchResults[name] ?? [])
                            : (favoritesController.animes[name] ?? []),
                        selections: selectedAnimes,
                        enableFavorite: false,
                        onTap: multiSelectMode
                            ? (a) {
                                setState(() {
                                  if (selectedAnimes.containsKey(
                                    a as FavoriteItem,
                                  )) {
                                    selectedAnimes.remove(a);
                                    _checkExitSelectMode();
                                  } else {
                                    selectedAnimes[a] = true;
                                  }
                                  lastSelectedIndex =
                                      (searchMode
                                              ? searchResults[name]
                                              : favoritesController
                                                    .animes[name])
                                          ?.indexOf(a) ??
                                      -1;
                                });
                              }
                            : (a) {
                                App.mainNavigatorKey?.currentContext?.to(
                                  () => AnimePage(
                                    id: a.id,
                                    sourceKey: a.sourceKey,
                                  ),
                                );
                                manager.updateRecentlyWatched(
                                  a.id,
                                  AnimeType(a.sourceKey.hashCode),
                                );
                              },
                        onLongPressed: (a) {
                          setState(() {
                            if (!multiSelectMode) {
                              multiSelectMode = true;
                              if (!selectedAnimes.containsKey(
                                a as FavoriteItem,
                              )) {
                                selectedAnimes[a] = true;
                              }
                              lastSelectedIndex =
                                  (searchMode
                                          ? searchResults[name]
                                          : favoritesController.animes[name])
                                      ?.indexOf(a) ??
                                  -1;
                            } else {
                              if (lastSelectedIndex != null &&
                                  lastSelectedIndex! >= 0) {
                                int start = lastSelectedIndex!;
                                int end =
                                    (searchMode
                                            ? searchResults[name]
                                            : favoritesController.animes[name])
                                        ?.indexOf(a as FavoriteItem) ??
                                    -1;
                                if (end < 0) return;
                                if (start > end) {
                                  int temp = start;
                                  start = end;
                                  end = temp;
                                }

                                var currentList =
                                    (searchMode
                                        ? searchResults[name]
                                        : favoritesController.animes[name]) ??
                                    [];
                                for (int i = start; i <= end; i++) {
                                  if (i == lastSelectedIndex) continue;
                                  var anime = currentList[i];
                                  if (selectedAnimes.containsKey(anime)) {
                                    selectedAnimes.remove(anime);
                                  } else {
                                    selectedAnimes[anime] = true;
                                  }
                                }
                              }
                              lastSelectedIndex =
                                  (searchMode
                                          ? searchResults[name]
                                          : favoritesController.animes[name])
                                      ?.indexOf(a as FavoriteItem) ??
                                  -1;
                            }
                            _checkExitSelectMode();
                          });
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
    body = AppScrollBar(
      topPadding:
          52.0 + MediaQuery.of(context).padding.top + tab.preferredSize.height,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );
    return PopScope(
      key: PageStorageKey("${favoritesController.folders}"),
      canPop: !multiSelectMode && !searchAllMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedAnimes.clear();
          });
        } else if (searchAllMode) {
          setState(() {
            searchAllMode = false;
            keyword = "";
            updateAnimes();
          });
        }
      },
      child: body,
    );
  }

  void _checkExitSelectMode() {
    if (selectedAnimes.isEmpty) {
      setState(() {
        multiSelectMode = false;
      });
    }
  }

  void _cancel() {
    setState(() {
      selectedAnimes.clear();
      multiSelectMode = false;
    });
  }

  void _deleteAnimeWithId() {
    favoritesController.isRefreshEnabled = true;
    var toBeDeleted = selectedAnimes.keys
        .map((e) => e as FavoriteItem)
        .toList();
    manager.batchDeleteAnimes(favoritesController.folder, toBeDeleted);
    // updateAnimes();
    _cancel();
  }

  @override
  bool get wantKeepAlive => true;
}
