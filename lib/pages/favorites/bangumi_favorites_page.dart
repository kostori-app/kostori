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

  final List<String> tab = ['抛弃', '想看', '在看', '搁置', '看过'];

  bool useBriefMode = true;

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
    useBriefMode = appdata.settings['animeDisplayMode'] == 'brief';
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

  Widget _bangumiListSliver(List<BangumiItem> bangumiItems) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        var bangumi = useBriefMode
            ? BangumiBriefCard(
                bangumiItem: bangumiItems[index],
                heroTag: 'favorite',
              )
            : BangumiDetailedCard(
                bangumiItem: bangumiItems[index],
                heroTag: 'favorite',
              );
        return bangumi;
      }, childCount: bangumiItems.length),
      gridDelegate: SliverGridDelegateWithBangumiItems(useBriefMode),
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
              ? (useBriefMode
                    ? BangumiWidget.bangumiSkeletonSliverBrief()
                    : BangumiWidget.bangumiSkeletonSliverDetailed())
              : _bangumiListSliver(list),
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
