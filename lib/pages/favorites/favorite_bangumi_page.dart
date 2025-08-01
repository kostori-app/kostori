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
  final bManager = BangumiManager();

  List<History> allHistory = [];
  List<BangumiItem> allBind = [];
  List<History> favoriteHistory = [];
  List<BangumiItem> favoriteBind = [];

  bool loading = false;
  bool useBriefMode = true;

  void loadFavorites() {
    setState(() {
      loading = true;
    });
    allHistory = hManager.getAll();
    allBind = bManager.getBindAll();

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

  Widget _bangumiListSliver(List<BangumiItem> bangumiItems) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        var bangumi = useBriefMode
            ? BangumiWidget.buildBriefMode(
                context,
                bangumiItems[index],
                'favorite_bind',
                showPlaceholder: false,
              )
            : BangumiWidget.buildDetailedMode(
                context,
                bangumiItems[index],
                'favorite_bind',
              );
        return bangumi;
      }, childCount: bangumiItems.length),
      gridDelegate: SliverGridDelegateWithBangumiItems(useBriefMode),
    );
  }

  @override
  void initState() {
    super.initState();
    useBriefMode = appdata.settings['animeDisplayMode'] == 'brief';
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
            message: "Folders".tl,
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
        loading
            ? (useBriefMode
                  ? BangumiWidget.bangumiSkeletonSliverBrief()
                  : BangumiWidget.bangumiSkeletonSliverDetailed())
            : _bangumiListSliver(favoriteBind),
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
