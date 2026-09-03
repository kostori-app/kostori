part of 'stats_page.dart';

class StatsViewPage extends StatefulWidget {
  const StatsViewPage({super.key});

  @override
  State<StatsViewPage> createState() => _StatsViewPageState();
}

class _StatsViewPageState extends State<StatsViewPage> {
  Map<String, int> ratingMap = {};
  List<int> ratingList = [];
  double average = 0;
  double stdDev = 0;
  int totalCount = 0;
  bool loading = true;
  Map<int, List<BangumiItem>> ratingBangumiMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final map = await StatsManager().getRatingsWithBangumiIds();
    final manager = providerContainer.read(bangumiManagerProvider);

    final newMap = <int, List<BangumiItem>>{};

    for (final entry in map.entries) {
      if (!mounted) return;

      final results = await Future.wait(
        entry.value.map((s) async {
          // bangumi.db 数据缺失时用统计自带的 title/cover 兜底
          final item = await manager.getBangumiItem(s.bangumiId!);
          return item ?? s.toBangumiItem();
        }),
      );

      if (!mounted) return;

      newMap[entry.key] = results.toList();
    }

    ratingBangumiMap = newMap;
    ratingList = List.generate(10, (i) => ratingBangumiMap[i + 1]?.length ?? 0);
    _calculateStats();

    if (mounted) setState(() => loading = false);
  }

  void _calculateStats() {
    totalCount = ratingList.reduce((a, b) => a + b);
    if (totalCount > 0) {
      // 平均分
      int weightedSum = 0;
      for (int i = 0; i < ratingList.length; i++) {
        weightedSum += ratingList[i] * (i + 1);
      }
      average = weightedSum / totalCount;
      // 标准差
      double varianceSum = 0;
      for (int i = 0; i < ratingList.length; i++) {
        varianceSum += ratingList[i] * pow((i + 1) - average, 2);
      }
      stdDev = sqrt(varianceSum / totalCount);
    }
  }

  void _showRatingDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
        maxWidth: MediaQuery.of(context).size.width <= 600
            ? MediaQuery.of(context).size.width
            : (App.isDesktop)
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RatingDetailPage(ratingBangumiMap: ratingBangumiMap),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _buildSkeleton(context);
    }
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Icon(Icons.query_stats_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Center(child: Text(t.statsInfo, style: ts.s16)),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.calendar_month_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    context.to(() => _StatsCalendarPage());
                  },
                  tooltip: t.statsCalendar,
                ),
                IconButton(
                  icon: Icon(
                    Icons.wb_cloudy_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    context.to(() => _WordCloud());
                  },
                  tooltip: t.wordCloud,
                ),
              ],
            ),
          ).paddingHorizontal(16),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(24),
            child: buildViewWidget(context),
          ),
        ],
      ),
    );
  }

  /// 加载骨架：复刻真实卡片的边框/头部/统计瓦片/图表布局，与项目风格一致
  Widget _buildSkeleton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 850;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Skeletonizer.zone(child: Bone.square(size: 20, uniRadius: 6)),
                const SizedBox(width: 8),
                Skeletonizer.zone(child: Bone.text(width: 56, fontSize: 16)),
                const Spacer(),
                Skeletonizer.zone(child: Bone.square(size: 28, uniRadius: 8)),
                const SizedBox(width: 8),
                Skeletonizer.zone(child: Bone.square(size: 28, uniRadius: 8)),
              ],
            ),
          ).paddingHorizontal(16),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(24),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _skeletonStatsCards(context)),
                      const SizedBox(width: 16),
                      Expanded(child: _skeletonChart(context)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _skeletonStatsCards(context),
                      const SizedBox(height: 24),
                      _skeletonChart(context),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonStatsCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 8;
        const double cardHeight = 80;
        final cardWidth = (constraints.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            6,
            (index) => SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Skeletonizer.zone(
                child: Bone(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _skeletonChart(BuildContext context) {
    return Skeletonizer.zone(
      child: Bone(
        width: double.infinity,
        height: 220,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget buildViewWidget(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 850;

    return KeyedSubtree(
      key: const ValueKey('chart'),
      child: isWide ? _buildWideLayout() : _buildNormalLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildStatsCards()),
        const SizedBox(width: 16),
        Expanded(child: _buildChart()),
      ],
    );
  }

  Widget _buildNormalLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildStatsCards(), const SizedBox(height: 24), _buildChart()],
    );
  }

  Widget _buildStatsCards() {
    const int itemsPerRow = 3;
    const double cardHeight = 80;
    const double spacing = 8;

    final int doing = appdata.settings.s.favoriteTypeDoing != 'none'
        ? LocalFavoritesManager().folderAnimes(
            appdata.settings.s.favoriteTypeDoing,
          )
        : 0;
    final int wish = appdata.settings.s.favoriteTypeWish != 'none'
        ? LocalFavoritesManager().folderAnimes(
            appdata.settings.s.favoriteTypeWish,
          )
        : 0;
    final int collect = appdata.settings.s.favoriteTypeCollect != 'none'
        ? LocalFavoritesManager().folderAnimes(
            appdata.settings.s.favoriteTypeCollect,
          )
        : 0;

    final int all = doing + wish + collect;
    List<Widget> cardList = List.generate(6, (index) {
      Widget content;
      switch (index) {
        case 0:
          content = Text(t.statsFavoritesTotal(n: all));
          break;
        case 1:
          content = Text(
            t.statsCompletedCount(
              n: appdata.settings.s.favoriteTypeCollect != 'none'
                  ? LocalFavoritesManager().folderAnimes(
                      appdata.settings.s.favoriteTypeCollect,
                    )
                  : '0',
            ),
          );
          break;
        case 2:
          content = Text(
            t.statsCompletionRate(
              n: appdata.settings.s.favoriteTypeCollect != 'none'
                  ? '${(LocalFavoritesManager().folderAnimes(appdata.settings.s.favoriteTypeCollect) / all * 100).toStringAsFixed(1)}%'
                  : '0%',
            ),
          );
          break;
        case 3:
          content = Text(t.statsAverageScore(n: average.toStringAsFixed(2)));
          break;
        case 4:
          content = Text(t.statsStdDev(n: stdDev.toStringAsFixed(2)));
          break;
        case 5:
          content = InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showRatingDetail(context),
            child: Center(child: Text(t.statsRatingCount(n: totalCount))),
          );
          break;
        default:
          content = Text(t.statsDefault);
      }

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Center(child: content),
      );
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - (itemsPerRow - 1) * spacing) / itemsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cardList.map((card) {
            return SizedBox(width: cardWidth, height: cardHeight, child: card);
          }).toList(),
        );
      },
    );
  }

  Widget _buildChart() {
    return SizedBox(
      height: 220,
      child: IntListBarChartPage(values: ratingList),
    );
  }
}

class _StatsCalendarPage extends StatelessWidget {
  _StatsCalendarPage();

  final StatsController controller = StatsController();
  final ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    Widget widget = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppbar(title: Text(t.statsCalendar)),
        SliverToBoxAdapter(child: StatsCalendarPage(controller: controller)),
      ],
    );
    widget = AppScrollBar(
      topPadding: 56,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );
    return widget;
  }
}

class _WordCloud extends ConsumerStatefulWidget {
  const _WordCloud();

  @override
  ConsumerState<_WordCloud> createState() => _WordCloudState();
}

class _WordCloudState extends ConsumerState<_WordCloud> {
  List<Map<String, dynamic>> wordCloudData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWordCloudData();
  }

  Future<void> _loadWordCloudData() async {
    setState(() => _loading = true);
    final allStats = await StatsManager().getStatsAll();

    final seenIds = <int>{};
    final likedStats = allStats
        .where(
          (s) => s.bangumiId != null && s.liked && seenIds.add(s.bangumiId!),
        )
        .toList();

    final likedItems = <BangumiItem>[];
    for (final s in likedStats) {
      final item = await providerContainer
          .read(bangumiManagerProvider)
          .getBangumiItem(s.bangumiId!);
      // bangumi.db 数据缺失时用统计自带的 title/cover 兜底
      likedItems.add(item ?? s.toBangumiItem());
    }

    setState(() {
      wordCloudData = BangumiUtils.sortedTagItemMap(
        likedItems,
        minTagCount: 2,
        minItemCount: 2,
      );
      _loading = false;
    });
  }

  void _showTagBottomSheet(String word, List<dynamic> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
        maxWidth: MediaQuery.of(context).size.width < 600
            ? MediaQuery.of(context).size.width
            : App.isDesktop
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
      ),
      builder: (_) => Sheet(
        title: word,
        icon: Icons.tag,
        headerTrailing: Text(
          t.statsItemCountSuffix(n: items.length),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        builder: (context, sc) => SmoothCustomScrollView(
          controller: sc,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = items[index];
                  return BangumiBriefCard(
                    bangumiItem: item,
                    heroTag: 'TagCloud$word$index',
                  );
                }, childCount: items.length),
                gridDelegate: SliverGridDelegateWithBangumiItems(true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> savePng({required BuildContext context}) async {
    final bytes = await exportWordCloudToPng(
      data: WordCloudData(data: wordCloudData),
      width: 1600,
      height: 1600,
      minTextSize: 12,
      maxTextSize: 120,
      colorlist: standardColorMap.keys.toList(),
      ratio: 3,
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await ImageSaver.saveImage(
      bytes: bytes,
      filename: 'word_cloud_$timestamp.png',
      ref: ref,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: KostoriRefreshIndicator());
    }
    if (wordCloudData.length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              t.noTagData,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Appbar(
          title: Text(t.wordCloud),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              onPressed: () async {
                await savePng(context: context);
              },
              icon: Icon(Icons.share),
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight.isInfinite
                      ? 400.0
                      : constraints.maxHeight;

                  final minSize = (w * 0.01).clamp(5.0, 12.0);
                  final maxSize = (w * 0.08).clamp(20.0, 120.0);

                  return RepaintBoundary(
                    child: WordCloudView(
                      key: ValueKey('$w-$h'),
                      data: WordCloudData(data: wordCloudData),
                      mapwidth: w,
                      mapheight: h,
                      mintextsize: minSize,
                      maxtextsize: maxSize,
                      attempt: 8,
                      colorlist: standardColorMap.keys.toList(),
                      onWordTap: (word) {
                        final entry = wordCloudData.firstWhere(
                          (e) => e['word'] == word,
                          orElse: () => <String, Object>{},
                        );
                        if (entry.isEmpty) return;
                        final items = entry['items'] as List<dynamic>;
                        _showTagBottomSheet(word, items);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingDetailPage extends StatefulWidget {
  final Map<int, List<BangumiItem>> ratingBangumiMap;

  const _RatingDetailPage({required this.ratingBangumiMap});

  @override
  State<_RatingDetailPage> createState() => _RatingDetailPageState();
}

class _RatingDetailPageState extends State<_RatingDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    int initialIndex =
        appdata.implicitData['ratingDetailPageInitialIndex'] ?? 9;
    if (appdata.implicitData['ratingDetailPageInitialIndex'] == null) {
      for (int i = 9; i >= 0; i--) {
        if (widget.ratingBangumiMap[i + 1]?.isNotEmpty == true) {
          initialIndex = i;
          break;
        }
      }
    }

    _tabController = TabController(
      length: 10,
      vsync: this,
      initialIndex: initialIndex,
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        appdata.implicitData['ratingDetailPageInitialIndex'] =
            _tabController.index;
        appdata.writeImplicitData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.ratingDetails,
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: List.generate(10, (i) {
              final count = widget.ratingBangumiMap[i + 1]?.length ?? 0;
              return Tab(
                text: t.statsScoreCount(score: i + 1, count: count),
              );
            }),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(10, (i) {
                final items = widget.ratingBangumiMap[i + 1] ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(t.statsNoRatingItems(score: i + 1)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithBangumiItems(true),
                  itemCount: items.length,
                  itemBuilder: (context, index) => BangumiBriefCard(
                    bangumiItem: items[index],
                    heroTag: null,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
