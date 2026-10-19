import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/bbcode/bbcode_precache.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/empty_state.dart';
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

class _BangumiTrendingSnapshot {
  const _BangumiTrendingSnapshot({
    required this.items,
    required this.pageCount,
    required this.cachedAt,
  });

  final List<BangumiItem> items;
  final int pageCount;
  final DateTime cachedAt;
}

class _BangumiPageState extends ConsumerState<BangumiPage>
    with SingleTickerProviderStateMixin {
  static const _trendingCacheDuration = Duration(minutes: 30);
  static _BangumiTrendingSnapshot? _trendingSnapshot;
  static final Map<int, Future<List<BangumiItem>>> _trendingRequests = {};
  static int _trendingCacheGeneration = 0;

  // 趋势数据异步加载，恢复旧的长列表偏移会让空列表首次布局时超出范围，
  // RenderViewport 可能在修正偏移前尝试绘制尚未完成布局的 Sliver。
  final ScrollController scrollController = ScrollController(
    keepScrollOffset: false,
  );
  List<BangumiItem> bangumiItems = [];
  bool isLoadingMore = false;
  bool _trendHasMore = true;
  bool showFB = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  int count = 0;
  int _queryGeneration = 0;
  bool _loadMoreScheduled = false;

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

    final snapshot = _readTrendingSnapshot();
    if (snapshot == null) {
      queryBangumiByTrend();
    } else {
      bangumiItems.addAll(snapshot.items);
      count = snapshot.pageCount;
    }
  }

  static _BangumiTrendingSnapshot? _readTrendingSnapshot() {
    final snapshot = _trendingSnapshot;
    if (snapshot == null) return null;
    if (DateTime.now().difference(snapshot.cachedAt) >=
        _trendingCacheDuration) {
      _trendingSnapshot = null;
      return null;
    }
    return snapshot;
  }

  static Future<List<BangumiItem>> _loadTrendingPage(
    int page, {
    bool forceRefresh = false,
  }) async {
    final pending = _trendingRequests[page];
    if (!forceRefresh && pending != null) return pending;

    final request = Bangumi.instance.getBangumiTrendsList(offset: page * 24);
    _trendingRequests[page] = request;
    try {
      return await request;
    } finally {
      if (identical(_trendingRequests[page], request)) {
        _trendingRequests.remove(page);
      }
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
    // 列表为空时不触发（首次加载由 initState 负责）：
    // 否则布局/窗口尺寸变化也会命中"接近底部"而重复请求
    if (!scrollController.hasClients || bangumiItems.isEmpty) return;
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        _trendHasMore &&
        !_loadMoreScheduled) {
      // RenderViewport 恢复滚动偏移期间可能触发监听器。此时同步重建 Sliver
      // 会导致子项尚未完成布局就进入绘制阶段。
      _loadMoreScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMoreScheduled = false;
        if (!mounted || !scrollController.hasClients || isLoadingMore) return;
        unawaited(queryBangumiByTrend());
      });
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

  Future<void> queryBangumiByTrend({bool forceRefresh = false}) async {
    // 防止并发/重复请求
    if ((isLoadingMore || !_trendHasMore) && !forceRefresh) return;
    if (forceRefresh) _trendHasMore = true;
    final queryGeneration = ++_queryGeneration;
    final cacheGeneration = _trendingCacheGeneration;
    final page = count;
    isLoadingMore = true;
    if (mounted) setState(() {});
    try {
      final result = await _loadTrendingPage(page, forceRefresh: forceRefresh);
      if (queryGeneration != _queryGeneration) return;

      await _commitTrendingResult(
        result,
        page: page,
        queryGeneration: queryGeneration,
        cacheGeneration: cacheGeneration,
      );
    } finally {
      if (queryGeneration == _queryGeneration) {
        isLoadingMore = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _commitTrendingResult(
    List<BangumiItem> result, {
    required int page,
    required int queryGeneration,
    required int cacheGeneration,
  }) async {
    void commit() {
      if (!mounted || queryGeneration != _queryGeneration) return;
      if (result.isEmpty) {
        _trendHasMore = false;
        return;
      }
      count = page + 1;
      bangumiItems.addAll(result);
      if (cacheGeneration == _trendingCacheGeneration) {
        _trendingSnapshot = _BangumiTrendingSnapshot(
          items: List.unmodifiable(bangumiItems),
          pageCount: count,
          cachedAt: DateTime.now(),
        );
      }
      _precacheTrendingImages(result);
    }

    // 请求可能在布局或绘制期间完成。将列表变更延迟到当前帧结束，避免
    // RenderViewport 绘制结构不完整的 Sliver 子项。
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      commit();
      return;
    }
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      commit();
      completer.complete();
    });
    WidgetsBinding.instance.scheduleFrame();
    await completer.future;
  }

  void _precacheTrendingImages(List<BangumiItem> items) {
    // 预热新增封面，减少详情页图片请求挤出列表页缓存的情况。
    if (!mounted) return;
    // 预热宽度需与 BangumiBriefCard 的内容宽一致，否则 ResizeImage 缓存键不同。
    // 内容宽 = 屏幕宽 - SliverPadding(16) - 相邻列间距(4) - 卡片水平内边距(4)。
    final columns = _getFixedCrossAxisCount() ?? _resolveMasonryColumns();
    final cardW =
        (MediaQuery.sizeOf(context).width - 16 - 4 * (columns - 1)) / columns -
        4;
    _imageCache.precacheAll(
      context,
      items.map((e) => e.cardImage).where((u) => u.isNotEmpty),
      sourceKey: 'bangumi',
      cacheWidth: (cardW * MediaQuery.devicePixelRatioOf(context)).round(),
    );
  }

  Future<void> resetBangumiTrend() async {
    if (scrollController.hasClients && scrollController.offset != 0) {
      scrollController.jumpTo(0);
    }
    _trendingCacheGeneration++;
    _trendingSnapshot = null;
    _trendingRequests.clear();
    _queryGeneration++;
    bangumiItems.clear();
    count = 0;
    _trendHasMore = true;
    await queryBangumiByTrend(forceRefresh: true);
  }

  int? _getFixedCrossAxisCount() {
    final perRow = appdata.implicitData['bangumiCardPerRow'];
    if (perRow != null && perRow.toString().isNotEmpty) {
      final parsed = int.tryParse(perRow.toString());
      return parsed != null && parsed > 0 ? parsed : null;
    }
    return null;
  }

  /// bangumi 趋势列表瀑布流（统一封面比例，与简洁布局一致）
  Widget _buildMasonryGrid(List<BangumiItem> items) {
    final perRow = _getFixedCrossAxisCount();
    final columns = perRow ?? _resolveMasonryColumns();
    return SliverMasonryGrid.count(
      crossAxisCount: columns,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childCount: items.length,
      itemBuilder: (context, index) {
        return BangumiBriefCard(
          bangumiItem: items[index],
          heroTag: 'Trending$index',
          masonryFactor: 1.35,
        );
      },
    );
  }

  /// 瀑布流列数：按每列最小宽度动态计算，窄屏少列
  int _resolveMasonryColumns() {
    final width = MediaQuery.sizeOf(context).width;
    const minColWidth = 140.0;
    return (width / minColWidth).floor().clamp(2, 6);
  }

  List<Widget> buildBangumiTrendingSlivers(BuildContext context) {
    // Sliver 构建时使用同一份不可变快照提供 childCount 和子项数据，避免
    // 请求完成替换源列表后，在布局过程中读到不一致的数据。
    final items = List<BangumiItem>.of(bangumiItems);
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
                  child: Text('${items.length}', style: ts.s12),
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
      // 状态区和网格使用稳定的独立 Sliver，避免返回页面恢复偏移时切换
      // Sliver 类型造成旧 RenderSliver 暂时缺少几何信息。
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: items.isEmpty
              ? SizedBox(
                  height: 220,
                  child: Center(
                    child: isLoadingMore
                        ? const PolygonRefreshIndicator(size: 32)
                        : ErrorState(
                            message: t.noData,
                            retry: () =>
                                queryBangumiByTrend(forceRefresh: true),
                          ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: appdata.implicitData['bangumiDisplayMode'] == 'masonry'
            ? _buildMasonryGrid(items)
            : SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return BangumiBriefCard(
                    bangumiItem: items[index],
                    heroTag: 'Trending$index',
                  );
                }, childCount: items.length),
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
            // 首次加载时空状态区域已经显示加载指示器；底部仅用于翻页，
            // 避免页面初次打开同时出现两个加载提示。
            child: bangumiItems.isNotEmpty && isLoadingMore
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
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                  onTap: () async {
                    await resetBangumiTrend();
                  },
                ),
                SpeedDialChild(
                  child: const Icon(Icons.vertical_align_top),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
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
    final cs = context.colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        height: 44,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              context.to(() => const BangumiSearchPage());
            },
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.search, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.search,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (context.width > changePoint) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                ],
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

  /// 会话内当日时间表缓存：番剧 tab 的 State 被系统重建（如从后台返回、
  /// 主视图重建）时直接复用，避免重复执行 loadBangumiCalendar
  /// （会读库、检查 bangumi-data 版本、拉剧集）。跨天自动失效。
  static String? _cachedDay;
  static List<BangumiItem>? _cachedToday;

  @override
  void initState() {
    super.initState();
    weekday = DateTime.now().weekday;
    filterTodayBangumiItems();
  }

  Future<void> filterTodayBangumiItems() async {
    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    if (_cachedDay == dayKey && _cachedToday != null) {
      if (mounted) setState(() => bangumiCalendar = _cachedToday!);
      return;
    }
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
      _cachedDay = dayKey;
      _cachedToday = todayItems;

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
                            heroCacheWidth:
                                (itemWidth *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .round(),
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
