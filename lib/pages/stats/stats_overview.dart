part of 'stats_page.dart';

enum TimeRange { daily, weekly, monthly, quarterly, halfYearly, yearly }

class StatsOverviewScreen extends StatelessWidget {
  const StatsOverviewScreen({
    super.key,
    required this.stats,
    required this.selectedDay,
    required this.title,
    required this.timeRange,
  });

  final List<StatsDataImpl> stats;
  final DateTime selectedDay;
  final String title;
  final TimeRange timeRange;

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: title,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StatsOverview(
            stats: stats,
            selectedDate: selectedDay,
            timeRange: timeRange,
          ),
        ),
      ),
    );
  }
}

class StatsOverview extends StatelessWidget {
  const StatsOverview({
    super.key,
    required this.stats,
    required this.selectedDate,
    required this.timeRange,
  });

  final List<StatsDataImpl> stats;
  final DateTime selectedDate;
  final TimeRange timeRange;

  List<StatsDataImpl> get _deduplicatedStats {
    final Map<String, StatsDataImpl> uniqueStats = {};

    for (final stat in stats) {
      final uniqueKey = '${stat.id}_${stat.type}';

      final existing = uniqueStats[uniqueKey];
      if (existing == null) {
        uniqueStats[uniqueKey] = stat;
      }
    }

    return uniqueStats.values.toList();
  }

  bool _isInTimeRange(DateTime date) {
    switch (timeRange) {
      case TimeRange.daily:
        return isSameDay(date, selectedDate);
      case TimeRange.weekly:
        return Utils.isSameWeek(date, selectedDate);
      case TimeRange.monthly:
        return Utils.isSameMonth(date, selectedDate);
      case TimeRange.quarterly:
        return Utils.isSameQuarter(date, selectedDate);
      case TimeRange.halfYearly:
        return Utils.isSameHalfYear(date, selectedDate);
      case TimeRange.yearly:
        return Utils.isSameYear(date, selectedDate);
    }
  }

  List<PlatformEventRecord> _getTimeRangeRecords(List<DailyEvent> events) {
    final List<PlatformEventRecord> records = [];

    for (final event in events) {
      if (_isInTimeRange(event.date)) {
        records.addAll(event.platformEventRecords);
      }
    }

    return records;
  }

  List<int> get _uniqueBangumiIds {
    final Set<int> uniqueIds = {};
    for (final stat in _deduplicatedStats) {
      if (stat.bangumiId != null) {
        uniqueIds.add(stat.bangumiId!);
      }
    }
    return uniqueIds.toList();
  }

  List<BangumiItem> get _bangumiItems {
    final uniqueIds = _uniqueBangumiIds;
    final List<BangumiItem> items = [];

    for (final bangumiId in uniqueIds) {
      final item = BangumiManager().getBangumiItem(bangumiId);
      if (item != null) {
        items.add(item);
      }
    }

    return items;
  }

  Map<String, int> get _tagNameCounts {
    final Map<String, int> countMap = {};

    for (final bangumiItem in _bangumiItems) {
      final tags = bangumiItem.tags;

      for (final tag in tags) {
        final String name = tag.name;
        countMap.update(name, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    return countMap;
  }

  List<MapEntry<String, int>> get _sortedTagCounts {
    final counts = _tagNameCounts;
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries;
  }

  List<String> get _topFiveTagNames {
    final sortedCounts = _sortedTagCounts;
    final topFive = sortedCounts.take(5).toList();
    return topFive.map((entry) => entry.key).toList();
  }

  // 计算活跃度总分
  double _calculateWeightedActivityScore(StatsDataImpl stat) {
    final commentRecords = _getTimeRangeRecords(stat.comment);
    final ratingRecords = _getTimeRangeRecords(stat.rating);
    final clickRecords = _getTimeRangeRecords(stat.totalClickCount);
    final watchTime = _getTotalWatchTime(stat);

    final watchMinutes = watchTime / 60;

    const double commentValue = 10.0; // 1次评论 ≈ 10分钟观看
    const double ratingValue = 10.0; // 1次评级 ≈ 10分钟观看
    const double clickValue = 1.0; // 1次点击 ≈ 1分钟观看

    return (commentRecords.length * commentValue +
            ratingRecords.length * ratingValue +
            clickRecords.length * clickValue +
            watchMinutes)
        .roundToDouble();
  }

  // 获取总观看时间（秒）
  int _getTotalWatchTime(StatsDataImpl stat) {
    final watchRecords = _getTimeRangeRecords(stat.totalWatchDurations);
    int totalSeconds = 0;

    for (final record in watchRecords) {
      totalSeconds += record.value;
    }

    return totalSeconds;
  }

  List<DailyEvent> _mergeDailyEvents(List<DailyEvent> events) {
    final Map<DateTime, DailyEvent> mergedMap = {};

    for (final event in events) {
      final dateKey = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );

      if (mergedMap.containsKey(dateKey)) {
        final existing = mergedMap[dateKey]!;
        mergedMap[dateKey] = DailyEvent(
          dateStr:
              '${event.date.year}-${event.date.month.toString().padLeft(2, '0')}-${event.date.day.toString().padLeft(2, '0')}',
          platformEventRecords: [
            ...existing.platformEventRecords,
            ...event.platformEventRecords,
          ],
        );
      } else {
        mergedMap[dateKey] = event;
      }
    }

    return mergedMap.values.toList();
  }

  List<RankedStatsItem> getRankedCoverItems(List<StatsDataImpl> allStats) {
    final Map<int?, List<StatsDataImpl>> groupedByBangumiId = {};
    final List<StatsDataImpl> itemsWithCover = [];
    for (final stat in allStats) {
      if (stat.cover != null) {
        if (stat.bangumiId != null) {
          groupedByBangumiId.putIfAbsent(stat.bangumiId, () => []).add(stat);
        } else {
          itemsWithCover.add(stat);
        }
      }
    }

    for (final group in groupedByBangumiId.values) {
      StatsDataImpl masterItem = group.firstWhere(
        (stat) => stat.isBangumi,
        orElse: () => group.first,
      );

      if (!masterItem.isBangumi) {
        masterItem = StatsDataImpl(
          id: masterItem.id,
          title: masterItem.title,
          cover: masterItem.cover,
          bangumiId: masterItem.bangumiId,
          type: masterItem.type,
          liked: masterItem.liked,
          isBangumi: true,
          comment: _mergeDailyEvents(
            group.map((s) => s.comment).expand((e) => e).toList(),
          ),
          totalClickCount: _mergeDailyEvents(
            group.map((s) => s.totalClickCount).expand((e) => e).toList(),
          ),
          totalWatchDurations: _mergeDailyEvents(
            group.map((s) => s.totalWatchDurations).expand((e) => e).toList(),
          ),
          rating: _mergeDailyEvents(
            group.map((s) => s.rating).expand((e) => e).toList(),
          ),
          favorite: _mergeDailyEvents(
            group.map((s) => s.favorite).expand((e) => e).toList(),
          ),
          firstClickTime: masterItem.firstClickTime,
          lastClickTime: masterItem.lastClickTime,
        );
      } else {
        masterItem = StatsDataImpl(
          id: masterItem.id,
          title: masterItem.title,
          cover: masterItem.cover,
          bangumiId: masterItem.bangumiId,
          type: masterItem.type,
          liked: masterItem.liked,
          isBangumi: true,
          comment: _mergeDailyEvents([
            ...masterItem.comment,
            ...group
                .where((s) => s != masterItem)
                .map((s) => s.comment)
                .expand((e) => e),
          ]),
          totalClickCount: _mergeDailyEvents([
            ...masterItem.totalClickCount,
            ...group
                .where((s) => s != masterItem)
                .map((s) => s.totalClickCount)
                .expand((e) => e),
          ]),
          totalWatchDurations: _mergeDailyEvents([
            ...masterItem.totalWatchDurations,
            ...group
                .where((s) => s != masterItem)
                .map((s) => s.totalWatchDurations)
                .expand((e) => e),
          ]),
          rating: _mergeDailyEvents([
            ...masterItem.rating,
            ...group
                .where((s) => s != masterItem)
                .map((s) => s.rating)
                .expand((e) => e),
          ]),
          favorite: _mergeDailyEvents([
            ...masterItem.favorite,
            ...group
                .where((s) => s != masterItem)
                .map((s) => s.favorite)
                .expand((e) => e),
          ]),
          firstClickTime: masterItem.firstClickTime,
          lastClickTime: masterItem.lastClickTime,
        );
      }

      itemsWithCover.add(masterItem);
    }

    final List<StatsDataImpl> activeItems = itemsWithCover.where((stat) {
      final totalScore = _calculateWeightedActivityScore(stat);
      return totalScore > 0;
    }).toList();

    activeItems.sort((a, b) {
      final scoreA = _calculateWeightedActivityScore(a);
      final scoreB = _calculateWeightedActivityScore(b);
      return scoreB.compareTo(scoreA);
    });

    final limitedItems = activeItems.take(9).toList();
    return limitedItems.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;
      return RankedStatsItem(
        stat: stat,
        rank: index + 1,
        activityScore: _calculateWeightedActivityScore(stat),
      );
    }).toList();
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.brown[400]!;
      default:
        return Colors.blue;
    }
  }

  Widget buildMaterialWidget({
    required BuildContext context,
    required Widget widget,
  }) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.secondaryContainer.toOpacity(0.72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: widget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataList = _sortedTagCounts
        .map(
          (entry) => {
            'word': entry.key,
            'value': entry.value > 0 ? entry.value.toDouble() : 1.0,
          },
        )
        .toList();

    int totalClicks = 0;
    int totalWatchSeconds = 0;
    int totalComments = 0;
    int totalRatings = 0;
    int totalFavorites = 0;

    for (final stat in _deduplicatedStats) {
      final clickRecords = _getTimeRangeRecords(stat.totalClickCount);
      for (final record in clickRecords) {
        totalClicks += record.value;
      }

      final watchRecords = _getTimeRangeRecords(stat.totalWatchDurations);
      for (final record in watchRecords) {
        totalWatchSeconds += record.watchDuration ?? record.value;
      }

      final commentRecords = _getTimeRangeRecords(stat.comment);
      totalComments += commentRecords.length;

      final ratingRecords = _getTimeRangeRecords(stat.rating);
      totalRatings += ratingRecords.length;

      final favoriteRecords = _getTimeRangeRecords(stat.favorite);
      totalFavorites += favoriteRecords.length;
    }

    final List<RankedStatsItem> rankedItemsWithCover = getRankedCoverItems(
      _deduplicatedStats,
    );

    int totalActiveCount = 0;
    final seenBangumiIds = <int?>{};

    for (final stat in _deduplicatedStats) {
      if (_calculateWeightedActivityScore(stat) > 0) {
        if (stat.bangumiId == null || seenBangumiIds.add(stat.bangumiId)) {
          totalActiveCount++;
        }
      }
    }

    final height = 140.0;
    final width = height * 0.72;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rankedItemsWithCover.isNotEmpty) ...[
          buildMaterialWidget(
            context: context,
            widget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    totalActiveCount > 9
                        ? '活跃条目 (前${rankedItemsWithCover.length}/$totalActiveCount个)'
                        : '活跃条目 ($totalActiveCount个)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 16,
                      children: rankedItemsWithCover.map((rankedItem) {
                        final stat = rankedItem.stat;
                        return Column(
                          children: [
                            Container(
                              width: width,
                              height: height,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: BangumiWidget.kostoriImage(
                                      context,
                                      stat.cover!,
                                      width: width,
                                      height: height,
                                      showPlaceholder: true,
                                    ),
                                  ),

                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: _getRankColor(rankedItem.rank),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.toOpacity(0.3),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${rankedItem.rank}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.toOpacity(0.7),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.toOpacity(0.3),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${rankedItem.activityScore.toStringAsFixed(0)}分',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(
                              width: width,
                              child: Text(
                                stat.title ?? '未知标题',
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 120,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey.toOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],

        buildMaterialWidget(
          context: context,
          widget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '活动统计',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatCard(
                      context,
                      icon: Icons.touch_app,
                      title: '点击次数',
                      value: '$totalClicks 次',
                      color: Colors.blue,
                    ),
                    _buildStatCard(
                      context,
                      icon: Icons.play_circle_fill,
                      title: '观看时长',
                      value: _formatHMS(totalWatchSeconds),
                      color: Colors.green,
                    ),
                    _buildStatCard(
                      context,
                      icon: Icons.comment,
                      title: '评论数量',
                      value: '$totalComments 条',
                      color: Colors.orange,
                    ),
                    _buildStatCard(
                      context,
                      icon: Icons.star,
                      title: '评级数量',
                      value: '$totalRatings 次',
                      color: Colors.amber,
                    ),
                    _buildStatCard(
                      context,
                      icon: Icons.favorite,
                      title: '收藏操作',
                      value: '$totalFavorites 次',
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 120,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.grey.toOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_topFiveTagNames.isNotEmpty &&
            _bangumiItems.length != 1 &&
            _bangumiItems.isNotEmpty) ...[
          buildMaterialWidget(
            context: context,
            widget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '常看标签',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _topFiveTagNames.map((tagName) {
                      return Chip(
                        label: Text(tagName),
                        backgroundColor: Colors.blue.toOpacity(0.1),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 120,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey.toOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],

        if (_sortedTagCounts.isNotEmpty &&
            _bangumiItems.length != 1 &&
            _bangumiItems.isNotEmpty) ...[
          buildMaterialWidget(
            context: context,
            widget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '标签词云',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ResponsiveWordCloud(wordCloudData: dataList),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 120,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey.toOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],

        if (_deduplicatedStats.isEmpty) ...[
          Center(
            child: Column(
              children: [
                const Icon(Icons.inbox, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('暂无活动记录', style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 构建统计卡片
  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.toOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(title),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RankedStatsItem {
  final StatsDataImpl stat;
  final int rank;
  final double activityScore;

  RankedStatsItem({
    required this.stat,
    required this.rank,
    required this.activityScore,
  });
}
