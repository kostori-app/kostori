import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_calendar_page.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/pages/bangumi/bangumi_search_page.dart';
import 'package:kostori/pages/bangumi/bangumi_subject_tab_page.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';

class BangumiPage extends StatefulWidget {
  const BangumiPage({super.key});

  @override
  State<BangumiPage> createState() => _BangumiPageState();
}

class _BangumiPageState extends State<BangumiPage> {
  final ScrollController scrollController = ScrollController();
  List<BangumiItem> bangumiItems = [];
  bool isLoadingMore = false;
  bool showFB = false;

  @override
  void initState() {
    super.initState();
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
    if (scrollController.offset > 50) {
      if (!showFB) {
        setState(() {
          showFB = true;
        });
      }
    } else {
      if (showFB) {
        setState(() {
          showFB = false;
        });
      }
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
    var result = await Bangumi.getBangumiTrendsList(
      offset: bangumiItems.length,
    );
    bangumiItems.addAll(result);
    isLoadingMore = false;
    if (mounted) setState(() {});
  }

  Future<void> resetBangumiTrend() async {
    bangumiItems.clear();
    await queryBangumiByTrend();
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
                Text('Popularity Ranking'.tl, style: ts.s18),
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
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            return bangumiItems.isNotEmpty
                ? BangumiWidget.buildBriefMode(
                    context,
                    bangumiItems[index],
                    'Trending$index',
                    showPlaceholder: false,
                  )
                : null;
          }, childCount: bangumiItems.length),
          gridDelegate: SliverGridDelegateWithBangumiItems(true),
        ),
      ),

      // 加载更多指示器
      if (isLoadingMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: MiscComponents.placeholder(
                context,
                40,
                40,
                Colors.transparent,
              ),
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
          bottom: 10,
          right: 10,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            opacity: showFB ? 1 : 0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 0),
              child: GridSpeedDial(
                icon: Icons.menu,
                activeIcon: Icons.close,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                spacing: 6,
                spaceBetweenChildren: 4,
                direction: SpeedDialDirection.up,
                childPadding: const EdgeInsets.all(6),
                childrens: [
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
          ),
        ),
      ],
    );
    widget = AppScrollBar(
      topPadding: 82,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );

    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
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
                Text('Search'.tl, style: ts.s16),
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

  @override
  void initState() {
    weekday = DateTime.now().weekday;
    // 异步加载数据
    filterTodayBangumiItems();
    BangumiManager().addListener(onHistoryChange);
    super.initState();
  }

  @override
  void dispose() {
    BangumiManager().removeListener(onHistoryChange);
    super.dispose();
  }

  Future<void> filterTodayBangumiItems() async {
    try {
      final today = DateTime.now();
      final todayWeekday = today.weekday;

      // 获取一周7天的所有番剧条目
      final allItems = BangumiManager().getWeeks([1, 2, 3, 4, 5, 6, 7]);

      // 批量检测这些条目的数据是否存在，existenceMap: idStr -> airTimeStr
      final existenceMap = await BangumiManager().checkWhetherDataExistsBatch(
        allItems.map((e) => e.id.toString()).toList(),
      );

      // 过滤只保留存在数据的条目
      final validItems = allItems
          .where((item) => existenceMap.containsKey(item.id.toString()))
          .toList();

      // 批量拉取剧集列表，allEpisodesMap: id -> List<EpisodeInfo>
      final allEpisodesMap = await _fetchBatchEpisodes(validItems);

      final todayItems = <BangumiItem>[];

      for (final item in validItems) {
        final airTimeStr = existenceMap[item.id.toString()] ?? item.airTime;
        if (airTimeStr == null) continue;

        try {
          final airTime = DateTime.parse(airTimeStr).toLocal();

          // 只保留今日对应weekday的番剧
          if (airTime.weekday != todayWeekday) continue;

          final episodeInfo = _processEpisodeInfo(
            episodes: allEpisodesMap[item.id],
            now: today,
            currentWeekInfo: Utils.getISOWeekNumber(today),
            bangumiItem: item,
          );

          if (episodeInfo == null) continue;

          // 剔除“最后一集且无后续集且非本周”的番剧
          if (episodeInfo['isFinalEpisode'] == true &&
              episodeInfo['hasNextEpisodes'] == false &&
              episodeInfo['isCurrentWeek'] == false) {
            continue;
          }

          todayItems.add(
            item.copyWith(airTime: airTimeStr, extraInfo: episodeInfo),
          );
        } catch (e, s) {
          Log.addLog(
            LogLevel.error,
            '解析airTime或处理剧集失败',
            '${item.id}\n$airTimeStr\n$e\n$s',
          );
        }
      }

      // 按airTime排序
      todayItems.sort((a, b) => _compareTimeStrings(a.airTime, b.airTime));

      if (mounted) {
        setState(() => bangumiCalendar = todayItems);
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, '处理今日番剧失败', "$e\n$s");
      if (mounted) setState(() => bangumiCalendar = []);
    }
  }

  // 判断是否“本周最后一集”，并返回本周剧集信息
  Map<String, dynamic>? _processEpisodeInfo({
    required List<EpisodeInfo>? episodes,
    required DateTime now,
    required (int, int) currentWeekInfo,
    required BangumiItem bangumiItem,
  }) {
    if (episodes == null || episodes.isEmpty) return null;

    final (currentYear, currentWeek) = currentWeekInfo;

    // 取所有 type==0 的剧集（通常是主线剧集）
    final type0Episodes = episodes.where((ep) => ep.type == 0).toList();
    if (type0Episodes.isEmpty) return null;

    // 最后一集（type0中最后一集）
    final finalEpisode = type0Episodes.last;

    // 找本周对应的集数
    final currentWeekEp = Utils.findCurrentWeekEpisode(episodes, bangumiItem);

    // 判断当前集数是否为最后一集
    final isFinalEpisode =
        currentWeekEp.values.first != null &&
        currentWeekEp.values.first?.sort == finalEpisode.sort;

    final airTime = Utils.safeParseDate(currentWeekEp.values.first?.airDate);

    if (airTime == null) return null;

    // 判断是否为当前周
    final airWeek = Utils.getISOWeekNumber(airTime).$2;
    bool isCurrentWeek = currentWeek == airWeek;

    if (currentWeekEp.keys.first == true && isCurrentWeek == false) {
      if (currentWeek == airWeek + 1) {
        isCurrentWeek = true;
      }
    }

    // 判断是否还有后续集数（finalEpisode不是最后一集时为true）
    final maxSort = type0Episodes
        .map((e) => e.sort)
        .reduce((a, b) => a > b ? a : b);

    return {
      'episode_airdate': finalEpisode.airDate,
      'episode_name': finalEpisode.name,
      'episode_name_cn': finalEpisode.nameCn,
      'episode_ep': finalEpisode.sort,
      'isCurrentWeek': isCurrentWeek,
      'isFinalEpisode': isFinalEpisode,
      'hasNextEpisodes': finalEpisode.sort < maxSort,
    };
  }

  // 辅助方法：比较 airTime 只保留时分排序
  DateTime _parseTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return DateTime(2000, 1, 1, dt.hour, dt.minute);
    } catch (e) {
      return DateTime(2000, 1, 1);
    }
  }

  int _compareTimeStrings(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return _parseTime(a).compareTo(_parseTime(b));
  }

  Future<Map<int, List<EpisodeInfo>>> _fetchBatchEpisodes(
    List<BangumiItem> batch,
  ) async {
    final result = <int, List<EpisodeInfo>>{};

    try {
      await Future.wait(
        batch.map((item) async {
          try {
            final episodes = await BangumiManager().allEpInfoFind(item.id);
            if (episodes.isNotEmpty) result[item.id] = episodes;
          } catch (e, s) {
            Log.addLog(LogLevel.warning, '批量获取剧集', '${item.id}: $e\n$s');
          }
        }),
      );
    } catch (e, s) {
      Log.addLog(LogLevel.warning, '批量获取剧集', '$e\n$s');
    }

    return result;
  }

  String getWeekdayString(int weekday) {
    var weekdays = [
      'Monday Schedule'.tl,
      'Tuesday Schedule'.tl,
      'Wednesday Schedule'.tl,
      'Thursday Schedule'.tl,
      'Friday Schedule'.tl,
      'Saturday Schedule'.tl,
      'Sunday Schedule'.tl,
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
            App.mainNavigatorKey?.currentContext?.to(
              () => BangumiCalendarPage(),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
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
                    Text('Timetable'.tl),
                  ],
                ),
              ).paddingHorizontal(16),
              SizedBox(
                height: 384,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    scrollbars: true,
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: bangumiCalendar.length,
                    itemBuilder: (BuildContext context, int index) {
                      return BangumiCard(
                        bangumiItem: bangumiCalendar[index],
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
