part of 'stats_page.dart';

enum TimeRange { daily, weekly, monthly, quarterly, halfYearly, yearly }

class StatsOverviewScreen extends ConsumerStatefulWidget {
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
  ConsumerState<StatsOverviewScreen> createState() =>
      _StatsOverviewScreenState();
}

class _StatsOverviewScreenState extends ConsumerState<StatsOverviewScreen> {
  List<StatsDataImpl> get stats => widget.stats;

  DateTime get selectedDay => widget.selectedDay;

  String get title => widget.title;

  TimeRange get timeRange => widget.timeRange;

  Future<void> _captureOffscreen(BuildContext context) async {
    try {
      final bytes = await ImageSaver.captureWidgetToImage(
        context: context,
        child: SizedBox(
          width: 800,
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
      if (bytes == null) return;

      final filename = 'stats_${DateTime.now().millisecondsSinceEpoch}.png';
      await ImageSaver.saveOrShareImage(bytes: bytes, filename: filename);
    } catch (e) {
      ImageSaver.showResult(success: false, message: '截图失败: $e');
      Log.error('截图失败', '$e');
    } finally {
      await ref.read(imagesProvider.notifier).loadImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: title,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: repaintKey,
                  child: StatsOverview(
                    stats: stats,
                    selectedDate: selectedDay,
                    timeRange: timeRange,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await _captureOffscreen(context);
                    App.rootContext.pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.share,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatsOverview extends StatefulWidget {
  const StatsOverview({
    super.key,
    required this.stats,
    required this.selectedDate,
    required this.timeRange,
  });

  final List<StatsDataImpl> stats;
  final DateTime selectedDate;
  final TimeRange timeRange;

  @override
  State<StatsOverview> createState() => _StatsOverviewState();
}

class _StatsOverviewState extends State<StatsOverview> {
  List<BangumiItem> _bangumiItems = [];

  @override
  void initState() {
    super.initState();
    _loadBangumiItems();
  }

  Future<void> _loadBangumiItems() async {
    final items = <BangumiItem>[];
    for (final id in _uniqueBangumiIds) {
      final item = await BangumiManager().getBangumiItem(id);
      if (item != null) items.add(item);
    }
    if (mounted) setState(() => _bangumiItems = items);
  }

  List<StatsDataImpl> get stats => widget.stats;

  DateTime get selectedDate => widget.selectedDate;

  TimeRange get timeRange => widget.timeRange;

  List<StatsDataImpl> get _deduplicatedStats {
    final map = <String, StatsDataImpl>{};
    for (final stat in stats) {
      map.putIfAbsent('${stat.id}_${stat.type}', () => stat);
    }
    return map.values.toList();
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
    return events
        .where((e) => _isInTimeRange(e.date))
        .expand((e) => e.platformEventRecords)
        .toList();
  }

  List<int> get _uniqueBangumiIds {
    final ids = <int>{};
    for (final s in _deduplicatedStats) {
      if (s.bangumiId != null) ids.add(s.bangumiId!);
    }
    return ids.toList();
  }

  List<MapEntry<String, int>> get _sortedTagCounts =>
      BangumiUtils.sortedTagCounts(_bangumiItems);

  List<String> get _topFiveTagNames =>
      _sortedTagCounts.take(5).map((e) => e.key).toList();

  List<Map<String, Object>> get dataList => _sortedTagCounts
      .map(
        (e) => {'word': e.key, 'value': e.value > 0 ? e.value.toDouble() : 1.0},
      )
      .toList();

  double _calculateWeightedActivityScore(StatsDataImpl stat) {
    final commentRecords = _getTimeRangeRecords(stat.comment);
    final ratingRecords = _getTimeRangeRecords(stat.rating);
    final clickRecords = _getTimeRangeRecords(stat.totalClickCount);
    final watchMinutes = _getTotalWatchTime(stat) / 60;
    return (commentRecords.length * 10.0 +
            ratingRecords.length * 10.0 +
            clickRecords.length * 1.0 +
            watchMinutes)
        .roundToDouble();
  }

  int _getTotalWatchTime(StatsDataImpl stat) {
    return _getTimeRangeRecords(
      stat.totalWatchDurations,
    ).fold(0, (sum, r) => sum + r.value);
  }

  List<DailyEvent> _mergeDailyEvents(List<DailyEvent> events) {
    final mergedMap = <DateTime, DailyEvent>{};
    for (final event in events) {
      final key = DateTime(event.date.year, event.date.month, event.date.day);
      if (mergedMap.containsKey(key)) {
        final existing = mergedMap[key]!;
        mergedMap[key] = DailyEvent(
          dateStr:
              '${key.year}-${key.month.toString().padLeft(2, '0')}-${key.day.toString().padLeft(2, '0')}',
          platformEventRecords: [
            ...existing.platformEventRecords,
            ...event.platformEventRecords,
          ],
        );
      } else {
        mergedMap[key] = event;
      }
    }
    return mergedMap.values.toList();
  }

  List<RankedStatsItem> getRankedCoverItems(List<StatsDataImpl> allStats) {
    final grouped = <int?, List<StatsDataImpl>>{};
    final itemsWithCover = <StatsDataImpl>[];

    for (final stat in allStats) {
      if (stat.cover == null) continue;
      if (stat.bangumiId != null) {
        grouped.putIfAbsent(stat.bangumiId, () => []).add(stat);
      } else {
        itemsWithCover.add(stat);
      }
    }

    for (final group in grouped.values) {
      var master = group.firstWhere(
        (s) => s.isBangumi,
        orElse: () => group.first,
      );
      master = StatsDataImpl(
        id: master.id,
        title: master.title,
        cover: master.cover,
        bangumiId: master.bangumiId,
        type: master.type,
        liked: master.liked,
        isBangumi: true,
        comment: _mergeDailyEvents(group.expand((s) => s.comment).toList()),
        totalClickCount: _mergeDailyEvents(
          group.expand((s) => s.totalClickCount).toList(),
        ),
        totalWatchDurations: _mergeDailyEvents(
          group.expand((s) => s.totalWatchDurations).toList(),
        ),
        rating: _mergeDailyEvents(group.expand((s) => s.rating).toList()),
        favorite: _mergeDailyEvents(group.expand((s) => s.favorite).toList()),
        firstClickTime: master.firstClickTime,
        lastClickTime: master.lastClickTime,
      );
      itemsWithCover.add(master);
    }

    final active =
        itemsWithCover
            .where((s) => _calculateWeightedActivityScore(s) > 0)
            .toList()
          ..sort(
            (a, b) => _calculateWeightedActivityScore(
              b,
            ).compareTo(_calculateWeightedActivityScore(a)),
          );

    return active
        .take(9)
        .toList()
        .asMap()
        .entries
        .map(
          (e) => RankedStatsItem(
            stat: e.value,
            rank: e.key + 1,
            activityScore: _calculateWeightedActivityScore(e.value),
          ),
        )
        .toList();
  }

  Color _getRankColor(int rank) => switch (rank) {
    1 => Colors.amber,
    2 => Colors.grey[400]!,
    3 => Colors.brown[400]!,
    _ => Colors.blue,
  };

  String _timeRangeTitle(TimeRange range) => switch (range) {
    TimeRange.daily => '当天',
    TimeRange.weekly => '当周',
    TimeRange.monthly => '当月',
    TimeRange.quarterly => '当季',
    TimeRange.halfYearly => '半年',
    TimeRange.yearly => '当年',
  };

  Widget _section(BuildContext context, String title, Widget child) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.secondaryContainer.toOpacity(0.72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ─── 热力图数据 ─────────────────────────────

  /// 生成时间范围内每天的活动强度 Map<日期, 活跃度>
  Map<DateTime, double> _buildHeatmapData() {
    final map = <DateTime, double>{};
    for (final stat in _deduplicatedStats) {
      void addEvents(List<DailyEvent> events) {
        for (final e in events) {
          if (!_isInTimeRange(e.date)) continue;
          final key = DateTime(e.date.year, e.date.month, e.date.day);
          map[key] =
              (map[key] ?? 0) +
              e.platformEventRecords.fold(
                0.0,
                (sum, r) => sum + r.value.clamp(0, 100),
              );
        }
      }

      addEvents(stat.totalClickCount);
      addEvents(stat.totalWatchDurations);
      addEvents(stat.comment);
      addEvents(stat.rating);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    int totalClicks = 0;
    int totalWatchSeconds = 0;
    int totalComments = 0;
    int totalRatings = 0;
    int totalFavorites = 0;

    for (final stat in _deduplicatedStats) {
      for (final r in _getTimeRangeRecords(stat.totalClickCount)) {
        totalClicks += r.value;
      }
      for (final r in _getTimeRangeRecords(stat.totalWatchDurations)) {
        totalWatchSeconds += r.watchDuration ?? r.value;
      }
      totalComments += _getTimeRangeRecords(stat.comment).length;
      totalRatings += _getTimeRangeRecords(stat.rating).length;
      totalFavorites += _getTimeRangeRecords(stat.favorite).length;
    }

    final rankedItems = getRankedCoverItems(_deduplicatedStats);
    int totalActiveCount = 0;
    final seenIds = <int?>{};
    for (final stat in _deduplicatedStats) {
      if (_calculateWeightedActivityScore(stat) > 0) {
        if (stat.bangumiId == null || seenIds.add(stat.bangumiId)) {
          totalActiveCount++;
        }
      }
    }

    final heatmapData = _buildHeatmapData();
    final showHeatmap =
        timeRange != TimeRange.daily &&
        heatmapData.isNotEmpty &&
        heatmapData.values.any((v) => v > 0);
    final coverW = 100.0;
    final coverH = coverW / 0.72;

    if (_deduplicatedStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('暂无活动记录', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // ── 时间范围标题 ────────────────────────
        Center(
          child: Text(
            _timeRangeTitle(timeRange),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),

        // ── 统计数字瓦片 ────────────────────────
        _section(
          context,
          '活动统计',
          _StatsTileGrid(
            tiles: [
              _StatsTile(
                icon: Icons.play_circle_fill,
                label: '观看时长',
                value: Utils.formatHMS(totalWatchSeconds),
                color: Colors.green,
              ),
              _StatsTile(
                icon: Icons.touch_app,
                label: '点击次数',
                value: '$totalClicks 次',
                color: Colors.blue,
              ),
              _StatsTile(
                icon: Icons.star,
                label: '评级',
                value: '$totalRatings 次',
                color: Colors.amber,
              ),
              _StatsTile(
                icon: Icons.comment,
                label: '评论',
                value: '$totalComments 条',
                color: Colors.orange,
              ),
              _StatsTile(
                icon: Icons.favorite,
                label: '收藏',
                value: '$totalFavorites 次',
                color: Colors.redAccent,
              ),
              _StatsTile(
                icon: Icons.local_fire_department,
                label: '活跃条目',
                value: '$totalActiveCount 个',
                color: Colors.deepOrange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── 热力图（周/月/季/半年/年）────────────
        if (showHeatmap) ...[
          _section(
            context,
            '活跃热力图',
            _ActivityHeatmap(
              data: heatmapData,
              timeRange: timeRange,
              selectedDate: selectedDate,
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (showHeatmap) ...[
          _section(
            context,
            '观看趋势',
            _WatchTrendChart(
              data: heatmapData,
              timeRange: timeRange,
              selectedDate: selectedDate,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── 活跃条目封面网格 ────────────────────
        if (rankedItems.isNotEmpty) ...[
          _section(
            context,
            totalActiveCount > 9
                ? '活跃条目 (前${rankedItems.length}/$totalActiveCount个)'
                : '活跃条目 ($totalActiveCount个)',
            _CoverGrid(
              items: rankedItems,
              coverW: coverW,
              coverH: coverH,
              getRankColor: _getRankColor,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── 观看时长条形图（按条目）───────────────
        if (_deduplicatedStats.any(
          (s) => _getTimeRangeRecords(
            s.totalWatchDurations,
          ).any((r) => r.value > 0),
        )) ...[
          _section(
            context,
            '观看时长分布',
            _WatchBarChart(
              stats: _deduplicatedStats,
              getRecords: _getTimeRangeRecords,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── 常看标签 ────────────────────────────
        if (_topFiveTagNames.isNotEmpty && _bangumiItems.length > 1) ...[
          _section(
            context,
            '常看标签',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sortedTagCounts.take(10).map((e) {
                final max = _sortedTagCounts.isNotEmpty
                    ? _sortedTagCounts.first.value
                    : 1;
                final ratio = e.value / max;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1 + ratio * 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: ratio * 0.5),
                    ),
                  ),
                  child: Text(
                    '${e.key}  ${e.value}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: ratio > 0.7
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── 标签词云 ────────────────────────────
        if (dataList.isNotEmpty && _bangumiItems.length > 1) ...[
          _section(
            context,
            '标签词云',
            SizedBox(
              height: 280,
              child: WordCloudWidget(wordCloudData: dataList),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 统计数字瓦片网格
// ─────────────────────────────────────────────

class _StatsTile {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _StatsTileGrid extends StatelessWidget {
  const _StatsTileGrid({required this.tiles});

  final List<_StatsTile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 400 ? 3 : 2;
        final tileW = (constraints.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tiles.map((t) {
            return SizedBox(
              width: tileW,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: t.color.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: t.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(t.icon, size: 17, color: t.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: t.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// 活跃热力图
// ─────────────────────────────────────────────

class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap({
    required this.data,
    required this.timeRange,
    required this.selectedDate,
  });

  final Map<DateTime, double> data;
  final TimeRange timeRange;
  final DateTime selectedDate;

  List<DateTime> _getDays() {
    DateTime start;
    DateTime end = DateTime.now();
    switch (timeRange) {
      case TimeRange.weekly:
        final wd = selectedDate.weekday;
        start = selectedDate.subtract(Duration(days: wd - 1));
        end = start.add(const Duration(days: 6));
        break;
      case TimeRange.monthly:
        start = DateTime(selectedDate.year, selectedDate.month, 1);
        end = DateTime(selectedDate.year, selectedDate.month + 1, 0);
        break;
      case TimeRange.quarterly:
        final q = ((selectedDate.month - 1) ~/ 3);
        start = DateTime(selectedDate.year, q * 3 + 1, 1);
        end = DateTime(selectedDate.year, q * 3 + 4, 0);
        break;
      case TimeRange.halfYearly:
        start = selectedDate.month <= 6
            ? DateTime(selectedDate.year, 1, 1)
            : DateTime(selectedDate.year, 7, 1);
        end = selectedDate.month <= 6
            ? DateTime(selectedDate.year, 6, 30)
            : DateTime(selectedDate.year, 12, 31);
        break;
      case TimeRange.yearly:
        start = DateTime(selectedDate.year, 1, 1);
        end = DateTime(selectedDate.year, 12, 31);
        break;
      default:
        return [];
    }
    final days = <DateTime>[];
    var cur = start;
    while (!cur.isAfter(end)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDays();
    if (days.isEmpty) return const SizedBox.shrink();

    final maxVal = data.values.isEmpty
        ? 1.0
        : data.values.reduce((a, b) => a > b ? a : b);
    final primary = Theme.of(context).colorScheme.primary;
    const cellSize = 14.0;
    const gap = 2.0;

    // 按周排列（7行，N列）
    final firstWeekday = days.first.weekday; // 1=Mon
    final paddedDays = [
      ...List.filled(firstWeekday - 1, null),
      ...days.map<DateTime?>((d) => d),
    ];
    final weeks = (paddedDays.length / 7).ceil();

    final weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 星期标签
          Column(
            children: List.generate(7, (i) {
              return SizedBox(
                height: cellSize + gap,
                width: 16,
                child: Text(
                  weekLabels[i],
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 4),
          // 格子
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(7, (row) {
              return Row(
                children: List.generate(weeks, (col) {
                  final idx = col * 7 + row;
                  if (idx >= paddedDays.length) {
                    return SizedBox(width: cellSize + gap);
                  }
                  final day = paddedDays[idx];
                  if (day == null) {
                    return SizedBox(
                      width: cellSize + gap,
                      height: cellSize + gap,
                    );
                  }
                  final key = DateTime(day.year, day.month, day.day);
                  final val = data[key] ?? 0;
                  final intensity = maxVal > 0
                      ? (val / maxVal).clamp(0.0, 1.0)
                      : 0.0;
                  final isToday = isSameDay(day, DateTime.now());

                  return Tooltip(
                    message:
                        '${day.month}/${day.day}  ${val.toStringAsFixed(0)}',
                    child: Container(
                      width: cellSize,
                      height: cellSize,
                      margin: const EdgeInsets.all(gap / 2),
                      decoration: BoxDecoration(
                        color: intensity == 0
                            ? primary.withValues(alpha: 0.06)
                            : primary.withValues(
                                alpha: 0.15 + intensity * 0.75,
                              ),
                        borderRadius: BorderRadius.circular(2),
                        border: isToday
                            ? Border.all(color: primary, width: 1)
                            : null,
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 封面网格（贴瓷砖）
// ─────────────────────────────────────────────

class _CoverGrid extends StatelessWidget {
  const _CoverGrid({
    required this.items,
    required this.coverW,
    required this.coverH,
    required this.getRankColor,
  });

  final List<RankedStatsItem> items;
  final double coverW;
  final double coverH;
  final Color Function(int) getRankColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: items.map((ranked) {
        final stat = ranked.stat;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: coverW,
              height: coverH,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BangumiWidget.kostoriImage(
                      context,
                      stat.cover!,
                      width: coverW,
                      height: coverH,
                    ),
                  ),
                  // 排名徽章
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: getRankColor(ranked.rank),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${ranked.rank}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 活跃度分数
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ranked.activityScore.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: coverW,
              child: Text(
                stat.title ?? '未知',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
// 观看时长条形图
// ─────────────────────────────────────────────

class _WatchBarChart extends StatelessWidget {
  const _WatchBarChart({required this.stats, required this.getRecords});

  final List<StatsDataImpl> stats;
  final List<PlatformEventRecord> Function(List<DailyEvent>) getRecords;

  @override
  Widget build(BuildContext context) {
    final watchMap = <String, int>{};
    for (final s in stats) {
      final seconds = getRecords(
        s.totalWatchDurations,
      ).fold(0, (sum, r) => sum + r.value);
      if (seconds > 0) watchMap[s.title ?? s.id] = seconds;
    }
    if (watchMap.isEmpty) return const SizedBox.shrink();

    final sorted = watchMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxVal = top.first.value;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: top.map((e) {
        final ratio = e.value / maxVal;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  e.key,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Text(
                  Utils.formatHMS(e.value),
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
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

class _WatchTrendChart extends StatelessWidget {
  const _WatchTrendChart({
    required this.data,
    required this.timeRange,
    required this.selectedDate,
  });

  final Map<DateTime, double> data;
  final TimeRange timeRange;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final points = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (points.isEmpty) return const SizedBox.shrink();

    final maxVal = points.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final primary = Theme.of(context).colorScheme.primary;

    // 均匀取最多6个时间标签
    final labelCount = points.length.clamp(2, 6);
    final step = (points.length / (labelCount - 1)).ceil();
    final labelIndices = <int>{0};
    for (var i = step; i < points.length - 1; i += step) {
      labelIndices.add(i);
    }
    labelIndices.add(points.length - 1);
    final sortedIndices = labelIndices.toList()..sort();

    String fmt(DateTime d) {
      switch (timeRange) {
        case TimeRange.weekly:
          return '${d.month}/${d.day}';
        case TimeRange.monthly:
          return '${d.day}日';
        case TimeRange.quarterly:
        case TimeRange.halfYearly:
          return '${d.month}/${d.day}';
        case TimeRange.yearly:
          return '${d.month}月';
        default:
          return '${d.month}/${d.day}';
      }
    }

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _TrendPainter(
              points: points,
              maxVal: maxVal,
              color: primary,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 4),
        // 时间标签行
        LayoutBuilder(
          builder: (ctx, constraints) {
            return Stack(
              children: [
                SizedBox(width: constraints.maxWidth, height: 16),
                ...sortedIndices.map((i) {
                  final ratio = points.length > 1
                      ? i / (points.length - 1)
                      : 0.5;
                  final label = fmt(points[i].key);
                  return Positioned(
                    left: (constraints.maxWidth * ratio - 20).clamp(
                      0,
                      constraints.maxWidth - 40,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.points,
    required this.maxVal,
    required this.color,
  });

  final List<MapEntry<DateTime, double>> points;
  final double maxVal;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Offset toOffset(int i) {
      final x = size.width * i / (points.length - 1);
      final y = size.height * (1 - points[i].value / maxVal) * 0.85 + 8;
      return Offset(x, y);
    }

    // 填充区域
    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    for (var i = 0; i < points.length; i++) {
      final o = toOffset(i);
      if (i == 0) {
        fillPath.lineTo(o.dx, o.dy);
      } else {
        fillPath.lineTo(o.dx, o.dy);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // 折线
    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final o = toOffset(i);
      if (i == 0) {
        linePath.moveTo(o.dx, o.dy);
      } else {
        linePath.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // 数据点
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(toOffset(i), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.maxVal != maxVal;
}
