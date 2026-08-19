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

  FavoritesState get favState => ref.watch(favoritesControllerProvider);

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

    // folders/folder/index 已在 FavoritesController.build() 初始化，
    // 这里无需再改 provider。
    _buildTabController();
    updateAnimes();
    manager.addListener(updateAnimes);
  }

  @override
  void dispose() {
    manager.removeListener(updateAnimes);
    favoritesController.tabController?.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _buildTabController({int? initialIndex}) {
    final length = favState.folders.length;
    final idx = (initialIndex ?? favState.index).clamp(0, length - 1);
    favoritesController.tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: idx,
    );
    favoritesController.tabController!.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final idx = favoritesController.tabController!.index;
    if (idx >= favState.folders.length) return;
    final folderName = favState.folders[idx];
    setState(() {
      if (multiSelectMode) {
        multiSelectMode = false;
        selectedAnimes.clear();
      }
      favoritesController.setFolder(folderName);
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
    // 过滤后为空（完全无收藏）时保留 default 作为可选中项，
    // 与 FavoritesController.build() 兜底逻辑保持一致
    final effectiveFolders = newFolders.isNotEmpty ? newFolders : ['default'];

    final result = <String, List<FavoriteItem>>{};
    isLoading = true;
    try {
      for (final folder in effectiveFolders) {
        final count = manager.folderAnimes(folder);
        if (count < _asyncDataFetchLimit) {
          result[folder] = manager.getAllAnimes(folder, sortType);
        } else {
          result[folder] = await manager
              .getFolderAnimesAsync(folder, sortType)
              .minTime(const Duration(milliseconds: 200));
        }
      }
    } finally {
      isLoading = false;
    }

    if (!mounted) return;

    int newIndex = effectiveFolders.indexWhere(
      (name) => name == favState.folder,
    );
    if (newIndex < 0) {
      final data = appdata.implicitData['favoriteFolder'];
      if (data != null) {
        newIndex = effectiveFolders.indexWhere((name) => name == data['name']);
      }
    }
    newIndex = newIndex.clamp(0, effectiveFolders.length - 1);

    if (favoritesController.tabController?.length != effectiveFolders.length) {
      favoritesController.tabController?.removeListener(_onTabChanged);
      favoritesController.tabController?.dispose();
      favoritesController.setFolders(effectiveFolders);
      _buildTabController(initialIndex: newIndex);
    } else {
      favoritesController.setFolders(effectiveFolders);
    }

    final newFolder = effectiveFolders.isEmpty
        ? ''
        : effectiveFolders[newIndex];
    favoritesController.setIndex(newIndex);

    setState(() {
      favoritesController.setAnimes(result);
      favoritesController.setFolder(newFolder);
    });

    favPage.setFolder(false, newFolder.isEmpty ? null : newFolder);
    favoritesController.setIsRefreshEnabled(false);
  }

  void updateSearchAllResult() {
    setState(() {
      if (keyword.trim().isEmpty) {
        searchResults = Map.from(favState.animes);
      } else {
        searchResults = {};
        for (final entry in favState.animes.entries) {
          final filtered = entry.value
              .where((a) => _matchKeyword(keyword, a))
              .toList();
          if (filtered.isNotEmpty) searchResults[entry.key] = filtered;
        }
      }
    });
  }

  bool _matchKeyword(String keyword, FavoriteItem anime) {
    for (final k in keyword.split(' ')) {
      if (k.isEmpty) continue;
      if (k == anime.type.sourceKey) return true;
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

    return favState.folders.map((name) {
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
      child: TabBar(
        controller: favoritesController.tabController,
        isScrollable: true,
        tabs: _buildTabs(),
        dividerHeight: 0,
        tabAlignment: TabAlignment.start,
        labelColor: context.colorScheme.primary,
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
    return _buildAppbar(
      key: PageStorageKey('${manager.folderAnimes(favState.folder)}'),
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
            if (favState.folder != 'default')
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
            if (favState.folder != 'default')
              MenuEntry(
                icon: Icons.delete_outline,
                text: t.deleteFolder,
                color: context.colorScheme.error,
                onClick: _deleteFolder,
              ),
          ],
        ),
      ],
      tab: tab,
    );
  }

  Widget _buildMultiSelectAppbar(PreferredSizeWidget tab) {
    return _buildAppbar(
      key: PageStorageKey('${manager.folderAnimes(favState.folder)}'),
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
      tab: tab,
    );
  }

  Widget _buildSearchAppbar(PreferredSizeWidget tab) {
    return _buildAppbar(
      key: PageStorageKey('${manager.folderAnimes(favState.folder)}'),
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
      tab: tab,
    );
  }

  /// 三个 appbar 共用的 SliverAppbar 骨架
  Widget _buildAppbar({
    required Key key,
    required Widget leading,
    required Widget title,
    List<Widget> actions = const [],
    required PreferredSizeWidget tab,
  }) {
    return SliverAppbar(
      key: key,
      style: context.width < changePoint
          ? AppbarStyle.shadow
          : AppbarStyle.blur,
      leading: leading,
      title: title,
      actions: actions,
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
      favoritesController.setIsRefreshEnabled(true);
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
        favoritesController.setIsRefreshEnabled(true);
        manager.rename(favState.folder, value.toString());
        manager.initCounts();
        favPage.setFolder(false, value.toString());
        return null;
      },
    );
  }

  void _exportFolder() {
    final json = manager.folderToJson(favState.folder);
    saveFile(data: utf8.encode(json), filename: '${favState.folder}.json');
  }

  void _deleteFolder() {
    showConfirmDialog(
      context: App.rootContext,
      title: t.delete,
      content: t.deleteFolderF(f: favState.folder),
      btnColor: context.colorScheme.error,
      onConfirm: () {
        favoritesController.setIsRefreshEnabled(true);
        manager.deleteFolder(favState.folder);
        final oldIndex = favState.index;
        if (favState.folders.isEmpty) {
          favoritesController.setIndex(0);
          favoritesController.setFolder('');
          favPage.setFolder(false, null);
        } else {
          favoritesController.setIndex(
            oldIndex >= favState.folders.length
                ? favState.folders.length - 1
                : oldIndex,
          );
          favoritesController.setFolder(favState.folders[favState.index]);
          favPage.setFolder(false, favState.folder);
        }
        setState(() {});
      },
    );
  }

  Future<void> _showFavoriteDialog() async {
    favoritesController.setIsRefreshEnabled(true);
    final changed = await _FavoriteDialog.show(
      context: context,
      selectedAnimes: selectedAnimes,
      favPage: favPage,
      cancel: _cancel,
      favoritesController: favoritesController,
    );
    if (changed == true) {
      manager.initCounts();
      favoritesController.setIsRefreshEnabled(true);
      await updateAnimes();
      if (searchAllMode) updateSearchAllResult();
      if (mounted) {
        setState(() {
          multiSelectMode = false;
          selectedAnimes.clear();
        });
      }
    }
  }

  void update() => setState(() {});

  void selectAll() {
    setState(() {
      selectedAnimes = {};
      final list = _currentList(favState.folder);
      for (final anime in list) {
        selectedAnimes[anime] = true;
      }
    });
  }

  void invertSelection() {
    setState(() {
      final list = _currentList(favState.folder);
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

  List<FavoriteItem> _currentList(String name) =>
      searchMode ? (searchResults[name] ?? []) : (favState.animes[name] ?? []);

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
    favoritesController.setIsRefreshEnabled(true);
    final toDelete = selectedAnimes.keys.map((e) => e as FavoriteItem).toList();
    manager.batchDeleteAnimes(favState.folder, toDelete);
    _cancel();
  }

  void _onAnimeTap(Anime a, int heroID) {
    if (a.viewMore != null && a.viewMore?.attributes != null) {
      var context = App.mainNavigatorKey!.currentContext!;
      a.viewMore!.jump(context);
    } else {
      App.mainNavigatorKey?.currentContext?.to(
        () => AnimePage(
          id: a.id,
          sourceKey: a.sourceKey,
          cover: a.cover,
          title: a.title,
          heroID: heroID,
        ),
      );
      // 使用 FavoriteItem 自己的 type（而非从 sourceKey 字符串 hash 派生），
      // 避免源未安装时 sourceKey 变为 "Unknown:xxx" 导致 type 不一致。
      final item = a is FavoriteItem ? a.type : AnimeType(a.sourceKey.hashCode);
      final stats = StatsManager();
      if (!stats.isExist(a.id, item)) {
        try {
          stats.addStats(
            stats.createStatsData(
              id: a.id,
              title: a.title,
              cover: a.cover,
              type: item.value,
            ),
          );
        } catch (e) {
          StatsLog.error('addStats', e.toString());
        }
      }
    }

    final item = a is FavoriteItem ? a.type : AnimeType(a.sourceKey.hashCode);
    manager.updateRecentlyWatched(a.id, item);
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

  /// 长按菜单（由 AnimeTile 在长按位置自动弹出）：多选入口
  List<MenuEntry> _buildLongPressMenu(Anime a) {
    return [
      MenuEntry(
        icon: Icons.check_box_outlined,
        text: t.multiSelect,
        onClick: () {
          setState(() {
            multiSelectMode = true;
            selectedAnimes[a as FavoriteItem] = true;
            lastSelectedIndex = _currentList(favState.folder).indexOf(a);
          });
        },
      ),
    ];
  }

  void _rangeSelect(Anime a, String name) {
    setState(() {
      final item = a as FavoriteItem;
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
              key: PageStorageKey('${favState.folders}'),
              controller: widget.favoritesController.tabController,
              children: favState.folders.map((name) {
                return SliverGridAnimes(
                  key: PageStorageKey('local_$name'),
                  asSliver: false,
                  animes: searchAllMode
                      ? (searchResults[name] ?? [])
                      : (favState.animes[name] ?? []),
                  selections: selectedAnimes,
                  enableFavorite: false,
                  // 非多选：长按由 AnimeTile 在位置弹菜单（含"多选"入口）
                  menuBuilder: multiSelectMode ? null : _buildLongPressMenu,
                  onTap: multiSelectMode
                      ? (a, heroID) => _onAnimeMultiTap(a, heroID, name)
                      : _onAnimeTap,
                  // 多选模式下长按保留范围选择
                  onLongPressed: multiSelectMode
                      ? (a, heroID) => _rangeSelect(a, name)
                      : null,
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
      key: PageStorageKey('${favState.folders}'),
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
