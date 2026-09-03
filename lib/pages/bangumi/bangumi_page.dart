import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/bbcode/bbcode_precache.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_calendar_page.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/pages/bangumi/bangumi_search_page.dart';
import 'package:kostori/pages/bangumi/bangumi_subject_tab_page.dart';

class BangumiPage extends ConsumerStatefulWidget {
  const BangumiPage({super.key});

  @override
  ConsumerState<BangumiPage> createState() => _BangumiPageState();
}

class _BangumiPageState extends ConsumerState<BangumiPage>
    with SingleTickerProviderStateMixin {
  final ScrollController scrollController = ScrollController();
  List<BangumiItem> bangumiItems = [];
  bool isLoadingMore = false;
  bool showFB = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  int count = 0;

  /// 页面级图片缓存保持：跳转到详情页/返回时图片不因 ImageCache 逐出而重载
  final BangumiPageImageCache _imageCache = BangumiPageImageCache();

  @override
  void initState() {
    super.initState();

    // 动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    scrollController.addListener(scrollListener);
    scrollController.addListener(onScroll);

    if (bangumiItems.isEmpty) {
      queryBangumiByTrend();
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(scrollListener);
    scrollController.removeListener(onScroll);
    scrollController.dispose();
    _controller.dispose();
    _imageCache.dispose();
    super.dispose();
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore) {
      queryBangumiByTrend();
    }
  }

  void onScroll() {
    final shouldShow = scrollController.offset > 50;
    if (shouldShow && !showFB) {
      showFB = true;
      _controller.forward();
    } else if (!shouldShow && showFB) {
      showFB = false;
      _controller.reverse();
    }
  }

  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> queryBangumiByTrend() async {
    isLoadingMore = true;
    setState(() {});
    var result = await Bangumi.instance.getBangumiTrendsList(
      offset: count * 24,
    );
    count += 1;
    bangumiItems.addAll(result);
    // 保持本页所有条目封面，避免跳详情页加载新图后逐出列表页缓存
    if (mounted) {
      final columns = _getFixedCrossAxisCount() ?? _resolveMasonryColumns();
      final cardW = (MediaQuery.of(context).size.width - 32) / columns;
      _imageCache.precacheAll(
        context,
        bangumiItems
            .map((e) => e.images['large'] ?? '')
            .where((u) => u.isNotEmpty),
        sourceKey: 'bangumi',
        cacheWidth: (cardW * MediaQuery.devicePixelRatioOf(context)).round(),
      );
    }
    isLoadingMore = false;
    if (mounted) setState(() {});
  }

  Future<void> resetBangumiTrend() async {
    bangumiItems.clear();
    count = 0;
    await queryBangumiByTrend();
  }

  int? _getFixedCrossAxisCount() {
    final perRow = appdata.implicitData['bangumiCardPerRow'];
    if (perRow != null && perRow.toString().isNotEmpty) {
      return int.tryParse(perRow.toString());
    }
    return null;
  }

  /// bangumi 趋势列表瀑布流（统一封面比例，与简洁布局一致）
  Widget _buildMasonryGrid() {
    final perRow = _getFixedCrossAxisCount();
    final columns = perRow ?? _resolveMasonryColumns();
    return SliverMasonryGrid.count(
      crossAxisCount: columns,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childCount: bangumiItems.length,
      itemBuilder: (context, index) {
        return BangumiBriefCard(
          bangumiItem: bangumiItems[index],
          heroTag: 'Trending$index',
          masonryFactor: 1.35,
        );
      },
    );
  }

  /// 瀑布流列数：按每列最小宽度动态计算，窄屏少列
  int _resolveMasonryColumns() {
    final width = MediaQuery.of(context).size.width;
    const minColWidth = 140.0;
    return (width / minColWidth).floor().clamp(2, 6);
  }

  List<Widget> buildBangumiTrendingSlivers(BuildContext context) {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        sliver: SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(t.popularityRanking, style: ts.s18),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${bangumiItems.length}', style: ts.s12),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    context.to(() => BangumiSubjectTabPage());
                  },
                  icon: Icon(Icons.messenger_outline),
                ),
              ],
            ).paddingHorizontal(16),
          ),
        ),
      ),
      // Grid 部分
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: appdata.implicitData['bangumiDisplayMode'] == 'masonry'
            ? _buildMasonryGrid()
            : SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return bangumiItems.isNotEmpty
                      ? BangumiBriefCard(
                          bangumiItem: bangumiItems[index],
                          heroTag: 'Trending$index',
                        )
                      : null;
                }, childCount: bangumiItems.length),
                gridDelegate: SliverGridDelegateWithBangumiItems(
                  true,
                  fixedCrossAxisCount: _getFixedCrossAxisCount(),
                ),
              ),
      ),
      // 底部固定高度区域：加载更多指示器常驻不增删，避免 maxScrollExtent
      // 随指示器出现/消失反复突变（下滑触发翻页时滚动条上下摆动的来源）
      SliverToBoxAdapter(
        child: SizedBox(
          height: 64,
          child: Center(
            child: isLoadingMore
                ? const PolygonRefreshIndicator(size: 32)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    Widget widget = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
        const _SearchBar(),
        const _Timetable(),
        ...buildBangumiTrendingSlivers(context),
      ],
    );

    widget = Stack(
      children: [
        Positioned.fill(child: widget),
        Positioned(
          bottom: 15,
          right: 10,
          child: FloatingMenu(
            controller: scrollController,
            child: [
              [
                SpeedDialChild(
                  child: const Icon(Icons.refresh),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  onTap: () async {
                    await resetBangumiTrend();
                  },
                ),
              ],
              [
                SpeedDialChild(
                  child: const Icon(Icons.vertical_align_top),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  onTap: () => scrollToTop(),
                ),
              ],
            ],
          ),
        ),
        // 条目数量浮动框
        Positioned(
          bottom: 2,
          right: 2,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: IgnorePointer(
              ignoring: !showFB,
              child: Transform.scale(
                scale: 1.2,
                alignment: Alignment.bottomRight,
                child: RepaintBoundary(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.toOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 10,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            t.itemsCount(n: bangumiItems.length),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    widget = AppScrollBar(
      // topPadding: 82,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );

    return ValueListenableBuilder<int>(
      valueListenable: appdata.implicitVersion,
      builder: (context, _, _) =>
          context.width > changePoint ? widget.paddingHorizontal(8) : widget,
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: App.isMobile ? 52 : 46,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Material(
          color: context.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(32),
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () {
              context.to(() => const BangumiSearchPage());
            },
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search),
                const SizedBox(width: 8),
                Text(t.search, style: ts.s16),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Timetable extends StatefulWidget {
  const _Timetable();

  @override
  State<_Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<_Timetable> {
  late int count;

  List<BangumiItem> bangumiCalendar = [];

  late int weekday;

  final itemHeight = 270.0;
  final verticalPadding = 16.0 * 2;

  @override
  void initState() {
    super.initState();
    weekday = DateTime.now().weekday;
    filterTodayBangumiItems();
  }

  Future<void> filterTodayBangumiItems() async {
    try {
      // 与日历页同一 loadBangumiCalendar（含深夜番跨天）；主页仅展示封面标题，
      // fetchEpisodeInfo:false 避免打开主页就批量拉剧集数据（每日同步仍进行）
      final todayWeekday = weekday;
      final yesterdayWeekday = todayWeekday == 1 ? 7 : todayWeekday - 1;
      final calendar = await loadBangumiCalendar(
        days: [yesterdayWeekday, todayWeekday],
        fetchEpisodeInfo: false,
      );
      final todayItems = calendar[todayWeekday - 1];

      if (mounted) {
        setState(() => bangumiCalendar = todayItems);
      }
    } catch (e, s) {
      Log.error('处理今日番剧失败', '$e\n$s');
      if (mounted) setState(() => bangumiCalendar = []);
    }
  }

  String getWeekdayString(int weekday) {
    var weekdays = [
      t.mondaySchedule,
      t.tuesdaySchedule,
      t.wednesdaySchedule,
      t.thursdaySchedule,
      t.fridaySchedule,
      t.saturdaySchedule,
      t.sundaySchedule,
    ];
    return weekdays[weekday - 1];
  }

  void onHistoryChange() {
    setState(() {
      filterTodayBangumiItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            context.to(() => BangumiCalendarPage());
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 46,
                child: Row(
                  children: [
                    Center(
                      child: Text(getWeekdayString(weekday), style: ts.s18),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${bangumiCalendar.length}', style: ts.s12),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_month),
                    SizedBox(width: 10),
                    Text(t.timetable),
                  ],
                ),
              ).paddingHorizontal(16),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SizedBox(
                height: bangumiCalendar.isEmpty
                    ? 0
                    : itemHeight + verticalPadding,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: bangumiCalendar.length,
                  itemBuilder: (context, index) {
                    final itemWidth = itemHeight * 0.72;
                    return BangumiCard(
                      bangumiItem: bangumiCalendar[index],
                      width: itemWidth,
                      height: itemHeight,
                      onTap: () async {
                        App.mainNavigatorKey?.currentContext?.to(
                          () => BangumiInfoPage(
                            bangumiItem: bangumiCalendar[index],
                            heroTag: 'Timetable',
                          ),
                        );
                      },
                      heroTag: 'Timetable',
                    ).paddingHorizontal(8).paddingVertical(2);
                  },
                ).paddingHorizontal(8).paddingVertical(16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
