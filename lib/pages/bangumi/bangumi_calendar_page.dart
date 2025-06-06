import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/utils/translations.dart';

import 'package:kostori/utils/utils.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';

import '../../components/bangumi_widget.dart';
import '../../components/misc_components.dart';

class BangumiCalendarPage extends StatefulWidget {
  const BangumiCalendarPage({super.key});

  @override
  State<BangumiCalendarPage> createState() => _BangumiCalendarPageState();
}

class _BangumiCalendarPageState extends State<BangumiCalendarPage>
    with SingleTickerProviderStateMixin {
  TabController? controller;

  List<List<BangumiItem>> bangumiCalendar = [];

  bool _isLoading = true; // 新增加载状态标识

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday - 1;
    controller = TabController(
        vsync: this, length: getTabs().length, initialIndex: weekday);
    _initializeData(); // 修改初始化方法
  }

  // 新增初始化方法
  Future<void> _initializeData() async {
    try {
      await filterExistingBangumiItems();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 修改后的数据过滤方法（完整版）
  Future<void> filterExistingBangumiItems() async {
    try {
      // 1. 获取所有番剧数据并检查存在性
      final allItems = BangumiManager().getWeeks([1, 2, 3, 4, 5, 6, 7]);
      final allIds = allItems.map((item) => item.id.toString()).toList();
      final existenceMap =
          await BangumiManager().checkWhetherDataExistsBatch(allIds);

      // 2. 批量获取有效番剧的剧集数据（分批处理）
      final validItems = allItems
          .where((item) => existenceMap.containsKey(item.id.toString()))
          .toList();
      final allEpisodesMap = await _fetchEpisodesInBatches(validItems);

      // 3. 创建并填充日历数据
      final newCalendar = List.generate(7, (_) => <BangumiItem>[]);
      final now = DateTime.now();
      final currentWeekInfo = Utils.getISOWeekNumber(now);

      for (final item in validItems) {
        final airTimeStr = existenceMap[item.id.toString()] ?? item.airTime;
        if (airTimeStr == null) continue;

        try {
          final airTime = DateTime.parse(airTimeStr).toLocal();
          final weekday = airTime.weekday;

          final episodes = allEpisodesMap[item.id];
          final episodeResult = _processEpisodeInfo(
            episodes: episodes,
            airTime: airTime,
            now: now,
            currentWeekInfo: currentWeekInfo,
            bangumiItem: item,
          );

          if (episodeResult == null) continue;

          final isLastEpisode = episodes != null &&
              episodeResult['episode_ep'] == episodes.last.sort;
          final episodeAirDate =
              Utils.safeParseDate(episodeResult['episode_airdate']);
          final episodeWeek = episodeAirDate != null
              ? Utils.getISOWeekNumber(episodeAirDate).$2
              : -1;

          // 剔除非本周的最后一集条目
          if (isLastEpisode && episodeWeek != currentWeekInfo.$2) {
            continue;
          }

          final enrichedItem = item.copyWith(
            airTime: airTimeStr,
            extraInfo: episodeResult,
          );
          newCalendar[weekday - 1].add(enrichedItem);
        } catch (e, s) {
          Log.addLog(LogLevel.error, '处理番剧时间',
              'ID:${item.id}, 时间:$airTimeStr\n$e\n$s');
        }
      }

      // 4. 排序并过滤空日期
      _sortCalendarByTime(newCalendar);
      final filteredCalendar =
          newCalendar.where((day) => day.isNotEmpty).toList();

      if (mounted) {
        setState(() => bangumiCalendar = filteredCalendar);
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, '处理番剧日历', '$e\n$s');
      if (mounted) setState(() => bangumiCalendar = []);
    }
  }

  Map<String, dynamic>? _processEpisodeInfo({
    required List<EpisodeInfo>? episodes,
    required DateTime airTime,
    required DateTime now,
    required (int, int) currentWeekInfo,
    required BangumiItem
        bangumiItem, // 需要传入bangumiItem用于调用findCurrentWeekEpisode
  }) {
    if (episodes == null || episodes.isEmpty) return null;

    final currentWeekEp = Utils.findCurrentWeekEpisode(episodes, bangumiItem);

    if (currentWeekEp == null) return null;

    // 是否为最后一集
    final isLast = episodes.last.sort == currentWeekEp.sort;

    return {
      'episode_airdate': currentWeekEp.airDate,
      'episode_name': currentWeekEp.name,
      'episode_name_cn': currentWeekEp.nameCn,
      'episode_ep': currentWeekEp.sort,
      'isLastEpisode': isLast,
    };
  }

// 按播出时间排序
  void _sortCalendarByTime(List<List<BangumiItem>> calendar) {
    for (final dayList in calendar) {
      dayList.sort((a, b) => _compareTimeStrings(a.airTime, b.airTime));
    }
  }

  // 批量获取剧集数据（每批10个）
  Future<Map<int, List<EpisodeInfo>>> _fetchEpisodesInBatches(
      List<BangumiItem> items) async {
    final result = <int, List<EpisodeInfo>>{};
    for (var i = 0; i < items.length; i += 10) {
      final batch = items.sublist(i, min(i + 10, items.length));
      try {
        result.addAll(await _fetchBatchEpisodes(batch));
      } catch (e, s) {
        Log.addLog(LogLevel.warning, '获取剧集批次${i ~/ 10 + 1}失败', '$e\n$s');
      }
    }
    return result;
  }

// 时间字符串比较
  int _compareTimeStrings(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return _parseTime(a).compareTo(_parseTime(b));
  }

// 解析时间（仅比较时分）
  DateTime _parseTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return DateTime(2000, 1, 1, dt.hour, dt.minute);
    } catch (e) {
      return DateTime(2000, 1, 1); // 解析失败默认值
    }
  }

// 批量获取剧集（保持原有实现）
  Future<Map<int, List<EpisodeInfo>>> _fetchBatchEpisodes(
      List<BangumiItem> batch) async {
    final result = <int, List<EpisodeInfo>>{};
    final nowStr = Utils.formatDate(DateTime.now());
    final lastUpdateTime = appdata.settings['getBangumiAllEpInfoTime'];

    if (lastUpdateTime != null && lastUpdateTime == nowStr) {
      await Future.wait(batch.map((item) async {
        try {
          final episodes = await BangumiManager().allEpInfoFind(item.id);
          if (episodes.isNotEmpty) result[item.id] = episodes;
        } catch (e, s) {
          Log.addLog(LogLevel.warning, '批量获取剧集', '${item.id}: $e\n$s');
        }
      }));
    } else {
      try {
        await Future.wait(batch.map((item) async {
          try {
            final episodes = await Bangumi.getBangumiEpisodeAllByID(item.id);
            if (episodes.isNotEmpty) result[item.id] = episodes;
          } catch (e) {
            Log.addLog(LogLevel.warning, '批量获取剧集', '${item.id}: $e');
          }
        }));
        appdata.settings['getBangumiAllEpInfoTime'] = nowStr;
        appdata.saveData();
      } catch (e, s) {
        Log.addLog(LogLevel.warning, '批量获取剧集', '$e\n$s');
      }
    }
    return result;
  }

  /// 星期列表
  List<Tab> tabs = const <Tab>[];

  // 获取当前日期并生成星期和日期标签
  List<Tab> getTabs() {
    DateTime currentDate = DateTime.now();
    List<Tab> tabs = [];
    for (int i = 0; i < 7; i++) {
      DateTime weekday = currentDate
          .add(Duration(days: i - currentDate.weekday + 1)); // 当前周的日期
      String formattedDate = '${weekday.month}月${weekday.day}日'; // 格式化日期
      String dayOfWeek = '';

      switch (weekday.weekday) {
        case 1:
          dayOfWeek = '周一';
          break;
        case 2:
          dayOfWeek = '周二';
          break;
        case 3:
          dayOfWeek = '周三';
          break;
        case 4:
          dayOfWeek = '周四';
          break;
        case 5:
          dayOfWeek = '周五';
          break;
        case 6:
          dayOfWeek = '周六';
          break;
        case 7:
          dayOfWeek = '周日';
          break;
      }

      tabs.add(
        Tab(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formattedDate,
                style: TextStyle(fontWeight: FontWeight.bold), // 日期样式
              ),
              Text(
                dayOfWeek,
                style: TextStyle(fontWeight: FontWeight.normal), // 星期样式
              ),
            ],
          ),
        ),
      );
    }
    return tabs;
  }

  /// 今天
  int get today => DateTime.now().weekday - 1;

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          context.pop();
        },
        child: Scaffold(
            appBar: AppBar(
              title: Text('Timetable'.tl),
              bottom: TabBar(
                controller: controller,
                tabs: getTabs(),
                isScrollable: true,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 950.0 // 设置最大宽度为800
                    ),
                child: _buildBody(orientation),
              ),
            ) // 修改body构建方式
            ),
      );
    });
  }

  Widget _buildBody(Orientation orientation) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
      child: _isLoading
          ? _buildLoadingIndicator() // 加载状态
          : renderBody(orientation), // 原始内容
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiscComponents.placeholder(context, 100, 100, Colors.transparent),
          const SizedBox(height: 16),
          Text('正在加载时间表数据...', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget renderBody(Orientation orientation) {
    if (bangumiCalendar.isNotEmpty) {
      return TabBarView(
        controller: controller,
        children: contentList(bangumiCalendar, orientation),
      );
    } else {
      return const Center(
        child: Text('数据还没有更新 (´;ω;`)'),
      );
    }
  }

  List<Widget> contentList(
      List<List<BangumiItem>> bangumiCalendar, Orientation orientation) {
    final List<Widget> listViewList = [];
    final DateTime currentTime = DateTime.now().toLocal(); // 当前本地时间
    final String currentTimeStr =
        DateFormat('HH:mm').format(currentTime); // 当前时间（HH:mm）
    final int currentWeekday = currentTime.weekday; // 当前星期几（1=周一, 7=周日）

    for (int weekday = 1; weekday <= 7; weekday++) {
      final bangumiList = bangumiCalendar[weekday - 1]; // 获取对应星期几的列表
      if (bangumiList.isEmpty) continue;

      int lastPastIndex = -1;

      // 1. 预处理：找到最后一个早于当前时间的卡片索引
      for (int i = 0; i < bangumiList.length; i++) {
        final item = bangumiList[i];
        if (item.airTime == null) continue;

        try {
          // 提取时间部分（HH:mm）
          final itemTimeStr = _extractTimeFromISO(item.airTime!);
          if (itemTimeStr.compareTo(currentTimeStr) < 0) {
            lastPastIndex = i; // 更新为最后一个符合条件的索引
          }
        } catch (e, s) {
          Log.addLog(LogLevel.error, '时间解析', '$e\n$s');
        }
      }

      // 2. 计算是否需要插入横线（仅在当前日期的 Tab 中插入）
      final bool shouldInsertDivider = weekday == currentWeekday;

      listViewList.add(
        CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  // 3. 插入横线逻辑
                  if (shouldInsertDivider && index == lastPastIndex + 1) {
                    return _buildCurrentTimeDivider(currentTime);
                  }

                  // 4. 调整卡片索引
                  final adjustedIndex =
                      shouldInsertDivider && index > lastPastIndex
                          ? index - 1
                          : index;

                  // 5. 边界检查
                  if (adjustedIndex >= bangumiList.length) return null;

                  return InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      App.mainNavigatorKey?.currentContext
                          ?.to(() => BangumiInfoPage(
                                bangumiItem: bangumiList[adjustedIndex],
                                heroTag: 'calendar',
                              ));
                    },
                    child: bangumiCalendarCard(
                        context, bangumiList[adjustedIndex]),
                  );
                },
                childCount: bangumiList.isEmpty
                    ? 0
                    : (shouldInsertDivider
                        ? bangumiList.length + 1
                        : bangumiList.length),
              ),
            ),
          ],
        ),
      );
    }
    return listViewList;
  }

// 从 ISO 8601 时间中提取时间部分（HH:mm）
  String _extractTimeFromISO(String isoTime) {
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      return DateFormat('HH:mm').format(dateTime); // 提取并格式化时间部分
    } catch (e, s) {
      Log.addLog(LogLevel.error, '时间解析', '$e\n$s');
      return '00:00'; // 默认值
    }
  }

// 构建当前时间分割线
  Widget _buildCurrentTimeDivider(DateTime currentTime) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 动态计算尺寸
        final iconSize = constraints.maxWidth * 0.06; // 图标大小（基于父容器宽度）
        final textSize = constraints.maxWidth * 0.07; // 文本大小（基于父容器宽度）
        final dividerThickness = constraints.maxWidth * 0.005; // 分割线厚度（基于父容器宽度）

        return Padding(
          padding:
              const EdgeInsets.only(top: 0, left: 24, right: 24, bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: iconSize,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  DateFormat('HH:mm').format(currentTime),
                  style: TextStyle(
                    fontSize: textSize,
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Theme.of(context).colorScheme.tertiary,
                  thickness: dividerThickness,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget bangumiCalendarCard(BuildContext context, BangumiItem bangumiItem) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, left: 24, right: 24, bottom: 12),
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final height = outerConstraints.maxWidth * 8 / 16;
          return SizedBox(
            height: height,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final imageHeight = constraints.maxWidth * 6 / 16;
                  return SizedBox(
                    child: Utils.buildTimeIndicator(
                        bangumiItem.airTime, imageHeight),
                  );
                }),
                LayoutBuilder(builder: (context, constraints) {
                  final imageHeight = constraints.maxWidth * 6 / 16;
                  final imageWidth = imageHeight * 0.72;
                  return SizedBox(
                    height: imageHeight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 图片部分
                        ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Hero(
                              tag: 'calendar-${bangumiItem.id}',
                              child: BangumiWidget.kostoriImage(
                                  context, bangumiItem.images['large']!,
                                  width: imageWidth, height: imageHeight),
                            )),
                        const SizedBox(width: 16),
                        // 信息部分
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题
                              Text(
                                bangumiItem.nameCn,
                                style: TextStyle(
                                  fontSize: imageWidth * 0.12,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bangumiItem.name,
                                style: TextStyle(
                                  fontSize: imageWidth * 0.08,
                                  // color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '第 ${bangumiItem.extraInfo?['episode_ep']} 话 ${(bangumiItem.extraInfo?['episode_name_cn'].isEmpty ?? true) ? (bangumiItem.extraInfo?['episode_name']) ?? '' : bangumiItem.extraInfo?['episode_name_cn']}',
                                style: TextStyle(
                                  fontSize: imageWidth * 0.12,
                                  // color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              // 评分信息
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${bangumiItem.score}',
                                      style: TextStyle(
                                        fontSize: imageWidth * 0.16,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    Container(
                                      padding: EdgeInsets.fromLTRB(
                                          8, 5, 8, 5), // 可选，设置内边距
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(8), // 设置圆角半径
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .toOpacity(0.72),
                                          width: 1.0, // 设置边框宽度
                                        ),
                                      ),
                                      child: Text(
                                        Utils.getRatingLabel(bangumiItem.score),
                                        style: TextStyle(
                                          fontSize: imageWidth * 0.12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 4,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end, // 右对齐
                                      children: [
                                        RatingBarIndicator(
                                          itemCount: 5,
                                          rating:
                                              bangumiItem.score.toDouble() / 2,
                                          itemBuilder: (context, index) =>
                                              const Icon(
                                            Icons.star_rounded,
                                          ),
                                          itemSize: imageWidth * 0.14,
                                        ),
                                        Text(
                                          '${bangumiItem.total} 人评 | #${bangumiItem.rank}',
                                          style: TextStyle(
                                              fontSize: imageWidth * 0.1),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
