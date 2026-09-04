part of 'favorites_page.dart';

class BangumiFavoritesPage extends ConsumerStatefulWidget {
  const BangumiFavoritesPage({super.key, required this.favoritesController});

  final FavoritesController favoritesController;

  @override
  ConsumerState<BangumiFavoritesPage> createState() =>
      _BangumiFavoritesPageState();
}

class _BangumiFavoritesPageState extends ConsumerState<BangumiFavoritesPage>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<BangumiFavoritesPage> {
  late TabController controller;
  late _FavoritesPageState favPage;

  FavoritesController get favoritesController =>
      ref.read(favoritesControllerProvider.notifier);

  FavoritesState get favState => ref.watch(favoritesControllerProvider);

  String get name => favState.bangumiUserName;

  final List<String> tab = [t.dropped, t.wantToWatch, t.watching, t.onHold, t.completed];

  bool get useBriefMode => _layoutMode == 'brief';

  /// bangumi 收藏布局：独立 override（favoritesBangumiLayout），缺省跟随
  /// bangumi 全局（bangumiDisplayMode），再回落 brief
  String get _layoutMode {
    final v = appdata.implicitData['favoritesBangumiLayout'] as String?;
    if (v != null && v.isNotEmpty) return v;
    return appdata.implicitData['bangumiDisplayMode'] as String? ?? 'brief';
  }

  void _setLayoutMode(String v) {
    appdata.implicitData['favoritesBangumiLayout'] = v;
    appdata.writeImplicitData();
    setState(() {});
  }

  bool doingIsLoading = false;
  bool collectIsLoading = false;
  bool wishIsLoading = false;
  bool onHoldIsLoading = false;
  bool droppedIsLoading = false;

  bool doingQueryTimeout = false;
  bool collectQueryTimeout = false;
  bool wishQueryTimeout = false;
  bool onHoldQueryTimeout = false;
  bool droppedQueryTimeout = false;

  @override
  void initState() {
    super.initState();
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
    controller = TabController(length: 5, vsync: this, initialIndex: 2);
    controller.addListener(() {
      int index = controller.index;
      if (index == 0 && favState.droppedList.isEmpty && !droppedIsLoading) {
        if (name.isNotEmpty) {
          loadDroppedList();
        }
      }
      if (index == 1 && favState.wishList.isEmpty && !wishIsLoading) {
        if (name.isNotEmpty) {
          loadWishList();
        }
      }
      if (index == 3 && favState.onHoldList.isEmpty && !onHoldIsLoading) {
        if (name.isNotEmpty) {
          loadOnHoldList();
        }
      }
      if (index == 4 && favState.collectList.isEmpty && !collectIsLoading) {
        if (name.isNotEmpty) {
          loadCollectList();
        }
      }
    });
    if (name.isNotEmpty) {
      // 列表已有缓存时不重复调取，仅首次加载
      final cached = ref.read(favoritesControllerProvider).doingList;
      if (cached.isEmpty) {
        loadDoingList();
      }
    }
  }

  Future<void> _loadList({
    required int offset,
    required bool Function() isLoading,
    required void Function(bool) setLoading,
    required Future<void> Function({int offset, required String name}) query,
  }) async {
    if (isLoading()) return;
    setState(() => setLoading(true));
    await query(name: name, offset: offset);
    if (!mounted) return;
    setState(() => setLoading(false));
  }

  Future<void> loadDoingList({int offset = 0}) => _loadList(
    offset: offset,
    isLoading: () => doingIsLoading,
    setLoading: (v) => doingIsLoading = v,
    query: favoritesController.queryBangumiDoing,
  );

  Future<void> loadCollectList({int offset = 0}) => _loadList(
    offset: offset,
    isLoading: () => collectIsLoading,
    setLoading: (v) => collectIsLoading = v,
    query: favoritesController.queryBangumiCollect,
  );

  Future<void> loadWishList({int offset = 0}) => _loadList(
    offset: offset,
    isLoading: () => wishIsLoading,
    setLoading: (v) => wishIsLoading = v,
    query: favoritesController.queryBangumiWish,
  );

  Future<void> loadOnHoldList({int offset = 0}) => _loadList(
    offset: offset,
    isLoading: () => onHoldIsLoading,
    setLoading: (v) => onHoldIsLoading = v,
    query: favoritesController.queryBangumiOnHold,
  );

  Future<void> loadDroppedList({int offset = 0}) => _loadList(
    offset: offset,
    isLoading: () => droppedIsLoading,
    setLoading: (v) => droppedIsLoading = v,
    query: favoritesController.queryBangumiDropped,
  );

  /// 手动刷新当前 tab 的 Bangumi 收藏列表
  Future<void> _refresh() async {
    if (name.isEmpty) return;
    switch (controller.index) {
      case 0:
        await loadDroppedList();
        break;
      case 1:
        await loadWishList();
        break;
      case 2:
        await loadDoingList();
        break;
      case 3:
        await loadOnHoldList();
        break;
      case 4:
        await loadCollectList();
        break;
    }
  }

  Widget _bangumiListSliver(BuildContext context, List<BangumiItem> bangumiItems) {
    if (_layoutMode == 'detailed') {
      return SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          return BangumiDetailedCard(
            bangumiItem: bangumiItems[index],
            heroTag: 'favorite',
          );
        }, childCount: bangumiItems.length),
        gridDelegate: SliverGridDelegateWithBangumiItems(false),
      );
    }
    if (!useBriefMode) {
      final columns =
          ((MediaQuery.of(context).size.width / 140).floor()).clamp(2, 6);
      return SliverMasonryGrid.count(
        crossAxisCount: columns,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childCount: bangumiItems.length,
        itemBuilder: (context, index) => BangumiBriefCard(
          bangumiItem: bangumiItems[index],
          heroTag: 'favorite',
          masonryFactor: 1.35,
        ),
      );
    }
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        return BangumiBriefCard(
          bangumiItem: bangumiItems[index],
          heroTag: 'favorite',
        );
      }, childCount: bangumiItems.length),
      gridDelegate: SliverGridDelegateWithBangumiItems(true),
    );
  }

  Widget _listBody({
    required String storageKey,
    required List<BangumiItem> list,
    required bool isLoading,
    required Future<void> Function(int offset) loadMore,
  }) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: (scrollEnd) {
        final metrics = scrollEnd.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - 200) {
          if (name.isNotEmpty) {
            loadMore(list.length);
          }
        }
        return true;
      },
      child: CustomScrollView(
        scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
        key: PageStorageKey<String>(storageKey),
        slivers: <Widget>[
          list.isEmpty
              ? (_layoutMode == 'detailed'
                    ? BangumiWidget.bangumiSkeletonSliverDetailed()
                    : BangumiWidget.bangumiSkeletonSliverBrief())
              : _bangumiListSliver(context, list),
          if (isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(child: PolygonRefreshIndicator(size: 40)),
              ),
            ),
        ],
      ),
    );
  }

  Widget get doingListBody => _listBody(
    storageKey: 'doing',
    list: favState.doingList,
    isLoading: doingIsLoading,
    loadMore: (o) => loadDoingList(offset: o),
  );

  Widget get collectListBody => _listBody(
    storageKey: 'collect',
    list: favState.collectList,
    isLoading: collectIsLoading,
    loadMore: (o) => loadCollectList(offset: o),
  );

  Widget get wishListBody => _listBody(
    storageKey: 'wish',
    list: favState.wishList,
    isLoading: wishIsLoading,
    loadMore: (o) => loadWishList(offset: o),
  );

  Widget get onHoldListBody => _listBody(
    storageKey: 'onHold',
    list: favState.onHoldList,
    isLoading: onHoldIsLoading,
    loadMore: (o) => loadOnHoldList(offset: o),
  );

  Widget get droppedListBody => _listBody(
    storageKey: 'dropped',
    list: favState.droppedList,
    isLoading: droppedIsLoading,
    loadMore: (o) => loadDroppedList(offset: o),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
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
        actions: [
          PopupMenuButton<String>(
            tooltip: t.displayModeOfAnimeTile,
            icon: const Icon(Icons.grid_view_outlined),
            onSelected: _setLayoutMode,
            itemBuilder: (_) => [
              for (final (key, label) in [
                ('brief', t.brief),
                ('detailed', t.detailed),
                ('masonry', t.masonry),
              ])
                PopupMenuItem(
                  value: key,
                  child: Row(
                    children: [
                      Icon(
                        _layoutMode == key
                            ? Icons.check
                            : Icons.circle_outlined,
                        size: 18,
                        color: _layoutMode == key
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  ),
                ),
            ],
          ),
          Tooltip(
            message: t.refresh,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          ),
        ],
        bottom: TabBar(
          tabs: tab.map((title) => Tab(text: title)).toList(),
          controller: controller,
          tabAlignment: TabAlignment.center,
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: [
          droppedListBody,
          wishListBody,
          doingListBody,
          onHoldListBody,
          collectListBody,
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
