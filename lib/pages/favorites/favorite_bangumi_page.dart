part of 'favorites_page.dart';

class FavoriteBangumiPage extends StatefulWidget {
  const FavoriteBangumiPage({super.key});

  @override
  State<FavoriteBangumiPage> createState() => _FavoriteBangumiPageState();
}

class _FavoriteBangumiPageState extends State<FavoriteBangumiPage> {
  late _FavoritesPageState favPage;
  final ScrollController scrollController = ScrollController();
  final hManager = HistoryManager();
  final fManager = LocalFavoritesManager();
  final bManager = providerContainer.read(bangumiManagerProvider);

  List<History> allHistory = [];
  List<BangumiItem> allBind = [];
  List<History> favoriteHistory = [];
  List<BangumiItem> favoriteBind = [];

  bool loading = false;

  Future<void> loadFavorites() async {
    setState(() {
      loading = true;
    });
    allHistory = await hManager.getAll();
    allBind = await bManager.getBindAll();

    favoriteHistory = allHistory.where((anime) {
      return fManager.isExist(anime.id, AnimeType(anime.sourceKey.hashCode));
    }).toList();

    final bindMap = {for (var b in allBind) b.id: b};

    favoriteBind = favoriteHistory
        .where((anime) => bindMap.containsKey(anime.bangumiId))
        .map((anime) => bindMap[anime.bangumiId]!)
        .toList();
    setState(() {
      loading = false;
    });
  }

  bool get useBriefMode => _layoutMode == 'brief';

  String get _layoutMode {
    final v = appdata.implicitData['favoritesBangumiBindingLayout'] as String?;
    if (v != null && v.isNotEmpty) return v;
    return appdata.implicitData['bangumiDisplayMode'] as String? ?? 'brief';
  }

  void _setLayoutMode(String v) {
    appdata.implicitData['favoritesBangumiBindingLayout'] = v;
    appdata.writeImplicitData();
    setState(() {});
  }

  Widget _bangumiListSliver(BuildContext context, List<BangumiItem> bangumiItems) {
    if (_layoutMode == 'detailed') {
      return SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          return BangumiDetailedCard(
            bangumiItem: bangumiItems[index],
            heroTag: 'favorite_bind',
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
          heroTag: 'favorite_bind',
          masonryFactor: 1.35,
        ),
      );
    }
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        return BangumiBriefCard(
          bangumiItem: bangumiItems[index],
          heroTag: 'favorite_bind',
        );
      }, childCount: bangumiItems.length),
      gridDelegate: SliverGridDelegateWithBangumiItems(true),
    );
  }

  @override
  void initState() {
    super.initState();
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
    loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    Widget body = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppbar(
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
          title: Text(favoriteBind.length.toString()),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: favoritesLayoutCapsule(
                context,
                value: _layoutMode,
                onChanged: _setLayoutMode,
                modes: [
                  ('brief', t.brief),
                  ('detailed', t.detailed),
                  ('masonry', t.masonry),
                ],
              ),
            ),
          ),
        ),
        loading
            ? _layoutMode == 'detailed'
                  ? BangumiWidget.bangumiSkeletonSliverDetailed()
                  : BangumiWidget.bangumiSkeletonSliverBrief()
            : _bangumiListSliver(context, favoriteBind),
      ],
    );
    body = AppScrollBar(
      topPadding: 52.0 + MediaQuery.of(context).padding.top,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );
    return body;
  }
}
