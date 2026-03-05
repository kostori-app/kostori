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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final map = await Future(() => StatsManager().getLatestRatingsCountMap());
    ratingList = List.generate(10, (index) {
      return map[(index + 1).toString()] ?? 0;
    });
    _calculateStats();
    setState(() {
      loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Skeletonizer.zone(child: Bone.multiText(lines: 3));
    }
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
                Center(child: Text('统计图表'.tl, style: ts.s18)),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.calendar_month_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    context.to(() => _StatsCalendarPage());
                  },
                  tooltip: 'Stats Calendar'.tl,
                ),
                IconButton(
                  icon: Icon(
                    Icons.wb_cloudy_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    context.to(() => _WordCloud());
                  },
                  tooltip: 'Word Cloud'.tl,
                ),
              ],
            ),
          ).paddingHorizontal(16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: buildViewWidget(context),
          ),
        ],
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
      children: [_buildStatsCards(), const SizedBox(height: 12), _buildChart()],
    );
  }

  Widget _buildStatsCards() {
    const int itemsPerRow = 3;
    const double cardHeight = 80;
    const double spacing = 8;

    List<Widget> cardList = List.generate(6, (index) {
      Widget content;
      switch (index) {
        case 0:
          content = Text('收藏: ${LocalFavoritesManager().totalAnimes}');
          break;
        case 1:
          content = Text(
            '完成: ${appdata.settings['FavoriteTypeCollect'] != 'none' ? LocalFavoritesManager().folderAnimes(appdata.settings['FavoriteTypeCollect']) : '0'}',
          );
          break;
        case 2:
          content = Text(
            '完成率: ${appdata.settings['FavoriteTypeCollect'] != 'none' ? '${(LocalFavoritesManager().folderAnimes(appdata.settings['FavoriteTypeCollect']) / LocalFavoritesManager().totalAnimes * 100).toStringAsFixed(1)}%' : '0%'}',
          );
          break;
        case 3:
          content = Text('平均分: ${average.toStringAsFixed(2)}');
          break;
        case 4:
          content = Text('标准差: ${stdDev.toStringAsFixed(2)}');
          break;
        case 5:
          content = Text('评分数: $totalCount');
          break;
        default:
          content = const Text('默认');
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
        SliverAppbar(title: Text("Stats Calendar".tl)),
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

  @override
  void initState() {
    super.initState();
    _loadWordCloudData();
  }

  Future<void> _loadWordCloudData() async {
    final allStats = await Future(() => StatsManager().getStatsAll());

    // 按 bangumiId 分组，只保留 liked 的
    final Map<int, List<StatsDataImpl>> likedGroups = {};
    for (final stat in allStats) {
      if (stat.bangumiId != null && stat.liked) {
        likedGroups.putIfAbsent(stat.bangumiId!, () => []).add(stat);
      }
    }

    // 统计 tag -> {count, bangumiItems}
    final Map<String, ({int count, List<BangumiItem> items})> tagMap = {};

    for (final bangumiId in likedGroups.keys) {
      final bangumiItem = BangumiManager().getBangumiItem(bangumiId);
      if (bangumiItem == null) continue;

      for (final tag in bangumiItem.tags) {
        final existing = tagMap[tag.name];
        if (existing == null) {
          tagMap[tag.name] = (count: 1, items: [bangumiItem]);
        } else {
          tagMap[tag.name] = (
            count: existing.count + 1,
            items: existing.items..add(bangumiItem),
          );
        }
      }
    }

    final sortedTags = tagMap.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    setState(() {
      wordCloudData = sortedTags
          .map(
            (entry) => {
              'word': entry.key,
              'value': entry.value.count.toDouble(),
              'items': entry.value.items, // List<BangumiItem>
            },
          )
          .toList();
    });
  }

  void _showTagBottomSheet(String word, List<dynamic> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
        maxWidth: MediaQuery.of(context).size.width < 600
            ? MediaQuery.of(context).size.width
            : App.isDesktop
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 顶部拖动条
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Text(word, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 8),
                    Text(
                      '${items.length} 部',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 列表
              Expanded(
                child: SmoothCustomScrollView(
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
            ],
          ),
        );
      },
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
    if (App.isAndroid) {
      Uint8List screenData = bytes;
      try {
        final folder = await KostoriFolder.checkPermissionAndPrepareFolder();
        if (folder != null) {
          final file = File('${folder.path}/word_cloud_$timestamp.png');
          await file.writeAsBytes(screenData);
          showCenter(
            seconds: 1,
            icon: Gif(
              image: AssetImage('assets/img/check.gif'),
              height: 80,
              fps: 120,
              color: Theme.of(context).colorScheme.primary,
              autostart: Autostart.once,
            ),
            message: '截图成功',
            context: App.rootContext,
          );
          const platform = MethodChannel('kostori/media');
          await platform.invokeMethod('scanFolder', {'path': folder.path});
          Log.addLog(LogLevel.info, '保存文件成功', '');
        } else {
          Log.addLog(LogLevel.error, '保存失败：权限或目录异常', '');
        }
      } catch (e) {
        Log.addLog(LogLevel.error, '截图失败', '$e');
      }
    } else {
      try {
        Uint8List? screenData = bytes;
        final directory = await getApplicationDocumentsDirectory();
        final folderPath = '${directory.path}/Kostori';
        final folder = Directory(folderPath);
        if (!await folder.exists()) {
          await folder.create(recursive: true);
          Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
        } else {
          Log.addLog(LogLevel.info, '文件夹已存在', folderPath);
        }

        final filePath = '$folderPath/word_cloud_$timestamp.png';
        // 将图像保存为文件
        final file = File(filePath);
        await file.writeAsBytes(screenData);
        showCenter(
          seconds: 1,
          icon: Gif(
            image: AssetImage('assets/img/check.gif'),
            height: 80,
            fps: 120,
            color: Theme.of(context).colorScheme.primary,
            autostart: Autostart.once,
          ),
          message: '截图成功',
          context: App.rootContext,
        );
      } catch (e) {
        Log.addLog(LogLevel.error, '截图失败', '$e');
      }
    }
    final notifier = ref.read(imagesProvider.notifier);
    await notifier.loadImages();
  }

  @override
  Widget build(BuildContext context) {
    if (wordCloudData.length < 2) {
      return const Center(child: PolygonRefreshIndicator());
    }
    return Column(
      children: [
        Appbar(
          title: Text("Word Cloud".tl),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30),
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
                    final maxSize = (w * 0.08).clamp(20.0, 80.0);

                    return WordCloudView(
                      key: ValueKey('$w-$h'),
                      data: WordCloudData(data: wordCloudData),
                      mapwidth: w,
                      mapheight: h,
                      mintextsize: minSize,
                      maxtextsize: maxSize,
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
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
