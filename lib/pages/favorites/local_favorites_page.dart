part of 'favorites_page.dart';

const _asyncDataFetchLimit = 500;

final excludedFolders = ["default", "默认"];

class _LocalFavoritesPage extends StatefulWidget {
  const _LocalFavoritesPage({required this.folder, super.key});

  final String folder;

  @override
  State<_LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<_LocalFavoritesPage> {
  late _FavoritesPageState favPage;

  late List<FavoriteItem> animes;

  late FavoriteSortType sortType;

  Map<Anime, bool> selectedAnimes = {};

  var selectedLocalFolders = <String>{};

  late List<String> added = [];

  List<String> filteredFolders = [];

  String keyword = "";

  bool searchMode = false;
  bool searchAllMode = false;

  bool multiSelectMode = false;

  int? lastSelectedIndex;

  LocalFavoritesManager get manager => LocalFavoritesManager();

  bool isLoading = false;

  var searchResults = <FavoriteItem>[];

  void updateSearchResult() {
    setState(() {
      if (keyword.trim().isEmpty) {
        searchResults = animes;
      } else {
        searchResults = [];
        for (var anime in animes) {
          if (matchKeyword(keyword, anime)) {
            searchResults.add(anime);
          }
        }
      }
    });
  }

  void updateSearchAllResult() {
    setState(() {
      animes = LocalFavoritesManager().search(keyword, sortType);
      if (keyword.trim().isEmpty) {
        searchResults = animes;
      } else {
        searchResults = [];
        for (var anime in animes) {
          if (matchKeyword(keyword, anime)) {
            searchResults.add(anime);
          }
        }
      }
    });
  }

  void updateAnimes() {
    if (isLoading) return;
    var folderAnimes = manager.folderAnimes(widget.folder);
    if (folderAnimes < _asyncDataFetchLimit) {
      animes = manager.getAllAnimes(widget.folder, sortType);
    } else {
      isLoading = true;
      manager
          .getFolderAnimesAsync(widget.folder, sortType)
          .minTime(const Duration(milliseconds: 200))
          .then((value) {
        if (mounted) {
          setState(() {
            isLoading = false;
            animes = value;
          });
        }
      });
    }
    setState(() {});
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
    var sort = appdata.implicitData["favori_sort"] ?? "displayOrder_asc";
    sortType = FavoriteSortType.fromString(sort);
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
    animes = [];
    animes = LocalFavoritesManager().getAllAnimes(widget.folder, sortType);
    LocalFavoritesManager().addListener(updateAnimes);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    LocalFavoritesManager().removeListener(updateAnimes);
  }

  void selectAll() {
    setState(() {
      if (searchMode) {
        selectedAnimes = searchResults.asMap().map((k, v) => MapEntry(v, true));
      } else {
        selectedAnimes = animes.asMap().map((k, v) => MapEntry(v, true));
      }
    });
  }

  void invertSelection() {
    setState(() {
      if (searchMode) {
        for (var c in searchResults) {
          if (selectedAnimes.containsKey(c)) {
            selectedAnimes.remove(c);
          } else {
            selectedAnimes[c] = true;
          }
        }
      } else {
        for (var c in animes) {
          if (selectedAnimes.containsKey(c)) {
            selectedAnimes.remove(c);
          } else {
            selectedAnimes[c] = true;
          }
        }
      }
    });
  }

  var scrollController = ScrollController();

  MenuButton _buildSortMenuItems() {
    return MenuButton(
      icon: Icons.sort,
      message: "Sort",
      entries: [
        MenuEntry(
            icon: Icons.receipt_long,
            endIcon: (sortType == FavoriteSortType.recentlyWatchedAsc ||
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
            }),
        MenuEntry(
            icon: Icons.sort_by_alpha,
            endIcon: (sortType == FavoriteSortType.nameAsc ||
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
            }),
        MenuEntry(
            icon: Icons.access_time,
            endIcon: (sortType == FavoriteSortType.timeAsc ||
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
            }),
        MenuEntry(
            icon: Icons.view_list,
            endIcon: (sortType == FavoriteSortType.displayOrderAsc ||
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
            }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        if (!searchAllMode && !searchMode && !multiSelectMode)
          SliverAppbar(
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
              child: Text(favPage.folder != null
                  ? '${'${favPage.folder}'.tl} ( ${animes.length} )'
                  : "Unselected".tl),
            ),
            actions: [
              Tooltip(
                message: "Search".tl,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      keyword = "";
                      searchMode = true;
                      updateSearchResult();
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
                  if (widget.folder != 'default')
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
                              LocalFavoritesManager().rename(
                                widget.folder,
                                value.toString(),
                              );
                              manager.initCounts();
                              favPage.folderList?.updateFolders();
                              favPage.setFolder(false, value.toString());
                              return null;
                            },
                          );
                        }),
                  MenuEntry(
                      icon: Icons.upload_file,
                      text: "Export".tl,
                      onClick: () {
                        var json = LocalFavoritesManager().folderToJson(
                          widget.folder,
                        );
                        saveFile(
                          data: utf8.encode(json),
                          filename: "${widget.folder}.json",
                        );
                      }),
                  MenuEntry(
                      icon: Icons.update,
                      text: "Update Animes Info".tl,
                      onClick: () {
                        updateAnimesInfo(widget.folder).then((newAnimes) {
                          if (mounted) {
                            setState(() {
                              animes = newAnimes;
                            });
                          }
                        });
                      }),
                  MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Folder".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        showConfirmDialog(
                          context: App.rootContext,
                          title: "Delete".tl,
                          content: "Delete folder '@f' ?".tlParams({
                            "f": widget.folder,
                          }),
                          btnColor: context.colorScheme.error,
                          onConfirm: () {
                            favPage.setFolder(false, null);
                            LocalFavoritesManager().deleteFolder(widget.folder);
                            favPage.folderList?.updateFolders();
                          },
                        );
                      }),
                ],
              ),
            ],
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
                  "Selected @c animes".tlParams({"c": selectedAnimes.length})),
              actions: [
                MenuButton(entries: [
                  MenuEntry(
                      icon: Icons.star_rounded,
                      text: "Favorite actions".tl,
                      onClick: () => _FavoriteDialog.show(
                          context: App.rootContext,
                          selectedAnimes: selectedAnimes,
                          favPage: favPage,
                          updateAnimes: () => updateAnimes(),
                          cancel: () => _cancel())),
                  MenuEntry(
                      icon: Icons.select_all,
                      text: "Select All".tl,
                      onClick: selectAll),
                  MenuEntry(
                      icon: Icons.deselect,
                      text: "Deselect".tl,
                      onClick: _cancel),
                  MenuEntry(
                      icon: Icons.flip,
                      text: "Invert Selection".tl,
                      onClick: invertSelection),
                  MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Anime".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        showConfirmDialog(
                          context: context,
                          title: "Delete".tl,
                          content: "Delete @c animes?"
                              .tlParams({"c": selectedAnimes.length}),
                          btnColor: context.colorScheme.error,
                          onConfirm: () {
                            _deleteAnimeWithId();
                          },
                        );
                      }),
                ]),
              ])
        else if (searchMode)
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
                    searchMode = false;
                  });
                },
              ),
            ),
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search".tl,
                border: UnderlineInputBorder(),
              ),
              onChanged: (v) {
                keyword = v;
                updateSearchResult();
              },
            ).paddingBottom(8).paddingRight(8),
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
                    animes = LocalFavoritesManager()
                        .getAllAnimes(widget.folder, sortType);
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
            ).paddingBottom(8).paddingRight(8),
          ),
        if (isLoading)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(
                child: MiscComponents.placeholder(
                    context, 200, 200, Colors.transparent),
              ),
            ),
          )
        else
          SliverGridAnimes(
            animes: searchMode ? searchResults : animes,
            selections: selectedAnimes,
            enableFavorite: false,
            onTap: multiSelectMode
                ? (a) {
                    setState(() {
                      if (selectedAnimes.containsKey(a as FavoriteItem)) {
                        selectedAnimes.remove(a);
                        _checkExitSelectMode();
                      } else {
                        selectedAnimes[a] = true;
                      }
                      lastSelectedIndex = animes.indexOf(a);
                    });
                  }
                : (a) {
                    App.mainNavigatorKey?.currentContext
                        ?.to(() => AnimePage(id: a.id, sourceKey: a.sourceKey));
                    LocalFavoritesManager().updateRecentlyWatched(
                        a.id, AnimeType(a.sourceKey.hashCode));
                  },
            onLongPressed: (a) {
              setState(() {
                if (!multiSelectMode) {
                  multiSelectMode = true;
                  if (!selectedAnimes.containsKey(a as FavoriteItem)) {
                    selectedAnimes[a] = true;
                  }
                  lastSelectedIndex = animes.indexOf(a);
                } else {
                  if (lastSelectedIndex != null) {
                    int start = lastSelectedIndex!;
                    int end = animes.indexOf(a as FavoriteItem);
                    if (start > end) {
                      int temp = start;
                      start = end;
                      end = temp;
                    }

                    for (int i = start; i <= end; i++) {
                      if (i == lastSelectedIndex) continue;

                      var anime = animes[i];
                      if (selectedAnimes.containsKey(anime)) {
                        selectedAnimes.remove(anime);
                      } else {
                        selectedAnimes[anime] = true;
                      }
                    }
                  }
                  lastSelectedIndex = animes.indexOf(a as FavoriteItem);
                }
                _checkExitSelectMode();
              });
            },
          ),
      ],
    );
    body = AppScrollBar(
      topPadding: 48,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );
    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedAnimes.clear();
          });
        } else if (searchMode) {
          setState(() {
            searchMode = false;
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
    var toBeDeleted =
        selectedAnimes.keys.map((e) => e as FavoriteItem).toList();
    LocalFavoritesManager().batchDeleteAnimes(widget.folder, toBeDeleted);
    // updateAnimes();
    _cancel();
  }
}
