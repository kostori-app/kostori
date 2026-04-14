part of 'favorites_page.dart';

const _asyncDataFetchLimit = 500;
const excludedFolders = ['default', '默认'];

class _LocalFavoritesPage extends ConsumerStatefulWidget {
  const _LocalFavoritesPage({required this.favoritesController});

  final FavoritesController favoritesController;

  @override
  ConsumerState<_LocalFavoritesPage> createState() =>
      _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends ConsumerState<_LocalFavoritesPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ScrollController scrollController = ScrollController();

  late _FavoritesPageState favPage;
  late FavoriteSortType sortType;

  FavoritesController get favoritesController => widget.favoritesController;

  LocalFavoritesManager get manager => LocalFavoritesManager();
  Map<Anime, bool> selectedAnimes = {};
  Map<String, List<FavoriteItem>> searchResults = {};

  String keyword = '';
  bool searchMode = false;
  bool searchAllMode = false;
  bool searchHasUpper = false;
  bool multiSelectMode = false;
  bool isLoading = false;

  int? lastSelectedIndex;

  @override
  void initState() {
    super.initState();
    final sort = appdata.implicitData['favori_sort'] ?? 'displayOrder_asc';
    sortType = FavoriteSortType.fromString(sort);
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;

    _initFolders();
    _buildTabController();
    updateAnimes();
    manager.addListener(updateAnimes);
  }

  @override
  void dispose() {
    manager.removeListener(updateAnimes);
    favoritesController.tabController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _initFolders() {
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
        (name) => name == data['name'],
      );
    }
    if (favoritesController.index < 0 ||
        favoritesController.index >= favoritesController.folders.length) {
      favoritesController.index = 0;
    }
    if (favoritesController.folders.isNotEmpty) {
      favoritesController.folder =
          favoritesController.folders[favoritesController.index];
    }
  }

  void _buildTabController({int? initialIndex}) {
    final idx = (initialIndex ?? favoritesController.index).clamp(
      0,
      (favoritesController.folders.length - 1).clamp(
        0,
        double.maxFinite.toInt(),
      ),
    );
    favoritesController.tabController = TabController(
      length: favoritesController.folders.length,
      vsync: this,
      initialIndex: idx,
    );
    favoritesController.tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final idx = favoritesController.tabController.index;
    if (idx >= favoritesController.folders.length) return;
    final folderName = favoritesController.folders[idx];
    setState(() {
      if (multiSelectMode) {
        multiSelectMode = false;
        selectedAnimes.clear();
      }
      favoritesController.folder = folderName;
      favPage.setFolder(false, folderName);
    });
  }

  Future<void> updateAnimes() async {
    if (isLoading) return;

    final newFolders = manager.folderNames.where((name) {
      if (name == 'default') {
        return manager
            .getAllAnimes('default', FavoriteSortType.nameAsc)
            .isNotEmpty;
      }
      return true;
    }).toList();

    final result = <String, List<FavoriteItem>>{};
    isLoading = true;
    for (final folder in newFolders) {
      final count = manager.folderAnimes(folder);
      if (count < _asyncDataFetchLimit) {
        result[folder] = manager.getAllAnimes(folder, sortType);
      } else {
        result[folder] = await manager
            .getFolderAnimesAsync(folder, sortType)
            .minTime(const Duration(milliseconds: 200));
      }
    }
    isLoading = false;

    if (!mounted) return;

    int newIndex = newFolders.indexWhere(
      (name) => name == favoritesController.folder,
    );
    if (newIndex < 0) {
      final data = appdata.implicitData['favoriteFolder'];
      if (data != null) {
        newIndex = newFolders.indexWhere((name) => name == data['name']);
      }
    }
    newIndex = newIndex.clamp(
      0,
      (newFolders.length - 1).clamp(0, double.maxFinite.toInt()),
    );

    if (favoritesController.tabController.length != newFolders.length) {
      favoritesController.tabController.removeListener(_onTabChanged);
      favoritesController.tabController.dispose();
      favoritesController.folders = newFolders;
      _buildTabController(initialIndex: newIndex);
    } else {
      favoritesController.folders = newFolders;
    }

    final newFolder = newFolders.isEmpty ? '' : newFolders[newIndex];
    favoritesController.index = newIndex;

    setState(() {
      favoritesController.animes
        ..clear()
        ..addAll(result);
      favoritesController.tabs = _buildTabs();
      favoritesController.folder = newFolder;
    });

    favPage.setFolder(false, newFolder.isEmpty ? null : newFolder);
    favoritesController.isRefreshEnabled = false;
  }

  void updateSearchAllResult() {
    setState(() {
      if (keyword.trim().isEmpty) {
        searchResults = Map.from(favoritesController.animes);
      } else {
        searchResults = {};
        for (final entry in favoritesController.animes.entries) {
          final filtered = entry.value
              .where((a) => _matchKeyword(keyword, a))
              .toList();
          if (filtered.isNotEmpty) searchResults[entry.key] = filtered;
        }
      }
      favoritesController.tabs = _buildTabs();
    });
  }

  bool _matchKeyword(String keyword, FavoriteItem anime) {
    for (final k in keyword.split(' ')) {
      if (k.isEmpty) continue;
      if (keyword == anime.type.sourceKey) return true;
      if (_contains(k, anime.title)) continue;
      if (anime.subtitle != null && _contains(k, anime.subtitle!)) continue;
      if (anime.tags.any(
        (tag) =>
            _equals(k, tag) ||
            (tag.contains(':') && _equals(k, tag.split(':')[1])),
      )) {
        continue;
      }
      if (_equals(k, anime.author)) continue;
      return false;
    }
    return true;
  }

  bool _contains(String keyword, String value) {
    final v = searchHasUpper ? value : value.toLowerCase();
    return v.contains(keyword);
  }

  bool _equals(String keyword, String value) {
    final v = searchHasUpper ? value : value.toLowerCase();
    return v == keyword;
  }

  List<Tab> _buildTabs() {
    final wish = appdata.settings.s.favoriteTypeWish;
    final doing = appdata.settings.s.favoriteTypeDoing;
    final collect = appdata.settings.s.favoriteTypeCollect;
    final onHold = appdata.settings.s.favoriteTypeOnHold;
    final dropped = appdata.settings.s.favoriteTypeDropped;

    final iconMap = <String, IconData>{
      wish: Icons.star_rounded,
      doing: Icons.favorite,
      collect: Icons.task_alt_outlined,
      onHold: Icons.access_time,
      dropped: Icons.heart_broken,
    };

    return favoritesController.folders.map((name) {
      final count = manager.folderAnimes(name);
      final displayCount = searchAllMode
          ? (searchResults[name]?.length ?? 0).toString()
          : count.toString();
      final icon = iconMap[name];

      return Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: context.colorScheme.onSurface),
              const SizedBox(width: 4),
            ],
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                name == 'default' ? t.kDefault : name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colorScheme.secondaryContainer.toOpacity(0.72),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayCount,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  PreferredSizeWidget _buildTabBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Observer(
        builder: (_) => TabBar(
          controller: favoritesController.tabController,
          isScrollable: true,
          tabs: favoritesController.tabs,
          dividerHeight: 0,
          tabAlignment: TabAlignment.start,
          labelColor: context.colorScheme.primary,
        ),
      ),
    );
  }

  MenuButton _buildSortMenu() {
    IconData? endIcon(FavoriteSortType asc, FavoriteSortType desc) {
      if (sortType == asc) return Icons.arrow_upward;
      if (sortType == desc) return Icons.arrow_downward;
      return null;
    }

    void setSort(FavoriteSortType asc, FavoriteSortType desc) {
      setState(() {
        sortType = sortType == asc ? desc : asc;
        appdata.implicitData['favori_sort'] = sortType.value;
        appdata.writeImplicitData();
        updateAnimes();
      });
    }

    return MenuButton(
      icon: Icons.sort,
      message: t.sort,
      entries: [
        MenuEntry(
          icon: Icons.receipt_long,
          endIcon: endIcon(
            FavoriteSortType.recentlyWatchedAsc,
            FavoriteSortType.recentlyWatchedDesc,
          ),
          text: t.recentlyWatched,
          onClick: () => setSort(
            FavoriteSortType.recentlyWatchedAsc,
            FavoriteSortType.recentlyWatchedDesc,
          ),
        ),
        MenuEntry(
          icon: Icons.sort_by_alpha,
          endIcon: endIcon(FavoriteSortType.nameAsc, FavoriteSortType.nameDesc),
          text: t.byName,
          onClick: () =>
              setSort(FavoriteSortType.nameAsc, FavoriteSortType.nameDesc),
        ),
        MenuEntry(
          icon: Icons.access_time,
          endIcon: endIcon(FavoriteSortType.timeAsc, FavoriteSortType.timeDesc),
          text: t.byTime,
          onClick: () =>
              setSort(FavoriteSortType.timeAsc, FavoriteSortType.timeDesc),
        ),
        MenuEntry(
          icon: Icons.view_list,
          endIcon: endIcon(
            FavoriteSortType.displayOrderAsc,
            FavoriteSortType.displayOrderDesc,
          ),
          text: t.defaultOrder,
          onClick: () => setSort(
            FavoriteSortType.displayOrderAsc,
            FavoriteSortType.displayOrderDesc,
          ),
        ),
      ],
    );
  }

  Widget _buildNormalAppbar(PreferredSizeWidget tab) {
    return SliverAppbar(
      key: PageStorageKey(
        '${manager.folderAnimes(favoritesController.folder)}',
      ),
      style: context.width < changePoint
          ? AppbarStyle.shadow
          : AppbarStyle.blur,
      leading: Tooltip(
        message: t.folders,
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
        child: Text(
          favPage.folder != null
              ? LocalFavoritesManager().totalAnimes.toString()
              : t.unselected,
        ),
      ),
      actions: [
        Tooltip(
          message: t.search,
          child: IconButton(
            icon: const Icon(Icons.search),
            onPressed: _enterSearchAllMode,
            onLongPress: _enterSearchAllMode,
          ),
        ),
        _buildSortMenu(),
        MenuButton(
          entries: [
            if (favoritesController.folder != 'default')
              MenuEntry(
                icon: Icons.edit_outlined,
                text: t.rename,
                onClick: _renameFolder,
              ),
            MenuEntry(
              icon: Icons.upload_file,
              text: t.export,
              onClick: _exportFolder,
            ),
            if (favoritesController.folder != 'default')
              MenuEntry(
                icon: Icons.delete_outline,
                text: t.deleteFolder,
                color: context.colorScheme.error,
                onClick: _deleteFolder,
              ),
          ],
        ),
      ],
      bottom: tab,
    );
  }

  Widget _buildMultiSelectAppbar(PreferredSizeWidget tab) {
    return SliverAppbar(
      key: PageStorageKey(
        '${manager.folderAnimes(favoritesController.folder)}',
      ),
      style: context.width < changePoint
          ? AppbarStyle.shadow
          : AppbarStyle.blur,
      leading: Tooltip(
        message: t.cancel,
        child: IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
      ),
      title: Text(t.selectedAAnimes(a: selectedAnimes.length)),
      actions: [
        MenuButton(
          entries: [
            MenuEntry(
              icon: Icons.star_rounded,
              text: t.favoriteActions,
              onClick: _showFavoriteDialog,
            ),
            MenuEntry(
              icon: Icons.select_all,
              text: t.selectAll,
              onClick: selectAll,
            ),
            MenuEntry(icon: Icons.deselect, text: t.deselect, onClick: _cancel),
            MenuEntry(
              icon: Icons.flip,
              text: t.invertSelection,
              onClick: invertSelection,
            ),
            MenuEntry(
              icon: Icons.delete_outline,
              text: t.deleteAnime,
              color: context.colorScheme.error,
              onClick: () => showConfirmDialog(
                context: context,
                title: t.delete,
                content: t.deleteCAnimes(c: selectedAnimes.length),
                btnColor: context.colorScheme.error,
                onConfirm: _deleteAnimeWithId,
              ),
            ),
          ],
        ),
      ],
      bottom: tab,
    );
  }

  Widget _buildSearchAppbar(PreferredSizeWidget tab) {
    return SliverAppbar(
      key: PageStorageKey(
        '${manager.folderAnimes(favoritesController.folder)}',
      ),
      style: context.width < changePoint
          ? AppbarStyle.shadow
          : AppbarStyle.blur,
      leading: Tooltip(
        message: t.cancel,
        child: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSearchAllMode,
        ),
      ),
      title: TextField(
        decoration: InputDecoration(
          hintText: keyword.isNotEmpty ? keyword : t.searchAll,
          border: const UnderlineInputBorder(),
        ),
        onChanged: (v) {
          keyword = v;
          searchHasUpper = keyword.contains(RegExp(r'[A-Z]'));
          updateSearchAllResult();
        },
      ).paddingBottom(4).paddingRight(8),
      bottom: tab,
    );
  }

  void _enterSearchAllMode() {
    setState(() {
      keyword = '';
      searchAllMode = true;
      updateSearchAllResult();
    });
  }

  void _exitSearchAllMode() {
    setState(() {
      searchAllMode = false;
      favoritesController.isRefreshEnabled = true;
    });
    updateAnimes();
  }

  void _renameFolder() {
    showInputDialog(
      context: App.rootContext,
      title: t.rename,
      hintText: t.newName,
      onConfirm: (value) {
        final err = validateFolderName(value.toString());
        if (err != null) return err;
        favoritesController.isRefreshEnabled = true;
        manager.rename(favoritesController.folder, value.toString());
        manager.initCounts();
        favPage.setFolder(false, value.toString());
        return null;
      },
    );
  }

  void _exportFolder() {
    final json = manager.folderToJson(favoritesController.folder);
    saveFile(
      data: utf8.encode(json),
      filename: '${favoritesController.folder}.json',
    );
  }

  void _deleteFolder() {
    showConfirmDialog(
      context: App.rootContext,
      title: t.delete,
      content: t.deleteFolderF(f: favoritesController.folder),
      btnColor: context.colorScheme.error,
      onConfirm: () {
        favoritesController.isRefreshEnabled = true;
        manager.deleteFolder(favoritesController.folder);
        final oldIndex = favoritesController.index;
        if (favoritesController.folders.isEmpty) {
          favoritesController.index = 0;
          favoritesController.folder = '';
          favPage.setFolder(false, null);
        } else {
          favoritesController.index =
              oldIndex >= favoritesController.folders.length
              ? favoritesController.folders.length - 1
              : oldIndex;
          favoritesController.folder =
              favoritesController.folders[favoritesController.index];
          favPage.setFolder(false, favoritesController.folder);
        }
        setState(() {});
      },
    );
  }

  Future<void> _showFavoriteDialog() async {
    favoritesController.isRefreshEnabled = true;
    final changed = await _FavoriteDialog.show(
      context: context,
      selectedAnimes: selectedAnimes,
      favPage: favPage,
      cancel: _cancel,
      favoritesController: favoritesController,
    );
    if (changed == true) {
      manager.initCounts();
      favoritesController.isRefreshEnabled = true;
      await updateAnimes();
      if (searchAllMode) updateSearchAllResult();
      if (mounted) {
        setState(() {
          multiSelectMode = false;
          selectedAnimes.clear();
          favoritesController.tabs = _buildTabs();
        });
      }
    }
  }

  void update() => setState(() {});

  void selectAll() {
    setState(() {
      selectedAnimes = {};
      final list = _currentList(favoritesController.folder);
      for (final anime in list) {
        selectedAnimes[anime] = true;
      }
    });
  }

  void invertSelection() {
    setState(() {
      final list = _currentList(favoritesController.folder);
      for (final anime in list) {
        if (selectedAnimes.containsKey(anime)) {
          selectedAnimes.remove(anime);
        } else {
          selectedAnimes[anime] = true;
        }
      }
    });
  }

  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  List<FavoriteItem> _currentList(String name) => searchMode
      ? (searchResults[name] ?? [])
      : (favoritesController.animes[name] ?? []);

  void _checkExitSelectMode() {
    if (selectedAnimes.isEmpty) {
      setState(() => multiSelectMode = false);
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
    final toDelete = selectedAnimes.keys.map((e) => e as FavoriteItem).toList();
    manager.batchDeleteAnimes(favoritesController.folder, toDelete);
    _cancel();
  }

  void _onAnimeTap(Anime a, int heroID) {
    if (a.viewMore != null && a.viewMore?.attributes != null) {
      var context = App.mainNavigatorKey!.currentContext!;
      a.viewMore!.jump(context);
      return;
    }
    App.mainNavigatorKey?.currentContext?.to(
      () => AnimePage(
        id: a.id,
        sourceKey: a.sourceKey,
        cover: a.cover,
        title: a.title,
        heroID: heroID,
      ),
    );
    final stats = StatsManager();
    if (!stats.isExist(a.id, AnimeType(a.sourceKey.hashCode))) {
      try {
        stats.addStats(
          stats.createStatsData(
            id: a.id,
            title: a.title,
            cover: a.cover,
            type: a.sourceKey.hashCode,
          ),
        );
      } catch (e) {
        StatsLog.error('addStats', e.toString());
      }
    }
    manager.updateRecentlyWatched(a.id, AnimeType(a.sourceKey.hashCode));
  }

  void _onAnimeMultiTap(Anime a, int heroID, String name) {
    setState(() {
      final item = a as FavoriteItem;
      if (selectedAnimes.containsKey(item)) {
        selectedAnimes.remove(item);
        _checkExitSelectMode();
      } else {
        selectedAnimes[item] = true;
      }
      lastSelectedIndex = _currentList(name).indexOf(item);
    });
  }

  void _onAnimeLongPress(Anime a, int heroID, String name) {
    setState(() {
      final item = a as FavoriteItem;
      if (!multiSelectMode) {
        multiSelectMode = true;
        selectedAnimes[item] = true;
        lastSelectedIndex = _currentList(name).indexOf(item);
        return;
      }
      // Range select.
      if (lastSelectedIndex != null && lastSelectedIndex! >= 0) {
        int start = lastSelectedIndex!;
        int end = _currentList(name).indexOf(item);
        if (end < 0) return;
        if (start > end) {
          final tmp = start;
          start = end;
          end = tmp;
        }
        final list = _currentList(name);
        for (int i = start; i <= end; i++) {
          if (i == lastSelectedIndex) continue;
          final anime = list[i];
          if (selectedAnimes.containsKey(anime)) {
            selectedAnimes.remove(anime);
          } else {
            selectedAnimes[anime] = true;
          }
        }
      }
      lastSelectedIndex = _currentList(name).indexOf(item);
      _checkExitSelectMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (favoritesController.tabs.isEmpty) {
      favoritesController.tabs = _buildTabs();
    }

    final tab = _buildTabBar();

    Widget body = NestedScrollView(
      controller: scrollController,
      headerSliverBuilder: (context, _) => [
        if (!searchAllMode && !searchMode && !multiSelectMode)
          _buildNormalAppbar(tab)
        else if (multiSelectMode)
          _buildMultiSelectAppbar(tab)
        else if (searchAllMode)
          _buildSearchAppbar(tab),
      ],
      body: isLoading
          ? const Center(
              child: SizedBox(
                height: 200,
                width: 200,
                child: KostoriRefreshIndicator(),
              ),
            )
          : TabBarView(
              key: PageStorageKey('${widget.favoritesController.folders}'),
              controller: widget.favoritesController.tabController,
              children: widget.favoritesController.folders.map((name) {
                return Observer(
                  builder: (context) => SliverGridAnimes(
                    key: PageStorageKey('local_$name'),
                    asSliver: false,
                    animes: searchAllMode
                        ? (searchResults[name] ?? [])
                        : (favoritesController.animes[name] ?? []),
                    selections: selectedAnimes,
                    enableFavorite: false,
                    onTap: multiSelectMode
                        ? (a, heroID) => _onAnimeMultiTap(a, heroID, name)
                        : _onAnimeTap,
                    onLongPressed: (a, heroID) =>
                        _onAnimeLongPress(a, heroID, name),
                  ),
                );
              }).toList(),
            ),
    );

    body = Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          bottom: 10,
          right: 10,
          child: FloatingMenu(
            controller: scrollController,
            child: [
              [
                SpeedDialChild(
                  child: const Icon(Icons.refresh),
                  backgroundColor: context.colorScheme.primaryContainer,
                  foregroundColor: context.colorScheme.onPrimaryContainer,
                  onTap: updateAnimes,
                ),
              ],
              [
                SpeedDialChild(
                  child: const Icon(Icons.vertical_align_top),
                  backgroundColor: context.colorScheme.primaryContainer,
                  foregroundColor: context.colorScheme.onPrimaryContainer,
                  onTap: scrollToTop,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    body = AppScrollBar(
      topPadding:
          52.0 + MediaQuery.of(context).padding.top + tab.preferredSize.height,
      controller: scrollController,
      isNested: true,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );

    return PopScope(
      key: PageStorageKey('${favoritesController.folders}'),
      canPop: !multiSelectMode && !searchAllMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedAnimes.clear();
          });
        } else if (searchAllMode) {
          _exitSearchAllMode();
        }
      },
      child: body,
    );
  }
}
