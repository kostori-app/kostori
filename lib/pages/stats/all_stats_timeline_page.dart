import 'package:flutter/material.dart';
import 'package:kostori/components/timeline_tree.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';

/// 某一天某个「条目」的粗略汇总（多来源已按 bangumi 归并为一条）
class _DayUnitSummary {
  _DayUnitSummary({required this.title});

  final String title;
  int watchSeconds = 0;
  int clicks = 0;
  int ratingCount = 0;
  int commentCount = 0;
  int favoriteCount = 0;
}

/// 全局粗略时间线：所有条目所有记录，按 年 > 月 > 日 分层展示。
/// 每一天是一个节点，节点里仅保留当天的粗略汇总，避免过于占空间。
class AllStatsTimelineScreen extends StatefulWidget {
  const AllStatsTimelineScreen({super.key});

  @override
  State<AllStatsTimelineScreen> createState() => _AllStatsTimelineScreenState();
}

class _AllStatsTimelineScreenState extends State<AllStatsTimelineScreen> {
  bool _loading = true;
  bool _failed = false;

  /// date(仅年月日) → 当天各条目汇总
  final Map<DateTime, Map<String, _DayUnitSummary>> _byDay = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    try {
      final manager = StatsManager();
      await manager.init();
      final all = await manager.getStatsAll();

      // 同 bangumi id 的来源归并为一条；无 bangumi id 各自独立
      final groups = <int?, List<StatsDataImpl>>{};
      for (final s in all) {
        groups.putIfAbsent(s.bangumiId, () => []).add(s);
      }
      final units = <List<StatsDataImpl>>[
        ...groups.values.where((g) => g.first.bangumiId != null),
      ];
      for (final group in groups.values.where(
        (g) => g.first.bangumiId == null,
      )) {
        for (final s in group) {
          units.add([s]);
        }
      }

      for (final group in units) {
        final master =
            group.where((s) => s.isBangumi).firstOrNull ?? group.first;
        final title =
            master.title?.isNotEmpty == true ? master.title! : master.id;
        final unitKey = master.bangumiId != null
            ? 'bgm:${master.bangumiId}'
            : '${master.id}\u0000${master.type}';

        void unitOf(DateTime day, void Function(_DayUnitSummary) update) {
          final unit = _byDay
              .putIfAbsent(_dayOf(day), () => {})
              .putIfAbsent(unitKey, () => _DayUnitSummary(title: title));
          update(unit);
        }

        for (final stat in group) {
          for (final daily in stat.totalWatchDurations) {
            if (daily.platformEventRecords.isEmpty) continue;
            unitOf(daily.date, (u) {
              for (final r in daily.platformEventRecords) {
                u.watchSeconds += r.value;
              }
            });
          }
          for (final daily in stat.totalClickCount) {
            if (daily.platformEventRecords.isEmpty) continue;
            unitOf(daily.date, (u) {
              for (final r in daily.platformEventRecords) {
                u.clicks += r.value;
              }
            });
          }
          for (final daily in stat.rating) {
            if (daily.platformEventRecords.isEmpty) continue;
            unitOf(daily.date, (u) {
              u.ratingCount += daily.platformEventRecords.length;
            });
          }
          for (final daily in stat.comment) {
            if (daily.platformEventRecords.isEmpty) continue;
            unitOf(daily.date, (u) {
              u.commentCount += daily.platformEventRecords.length;
            });
          }
          for (final daily in stat.favorite) {
            if (daily.platformEventRecords.isEmpty) continue;
            unitOf(daily.date, (u) {
              u.favoriteCount += daily.platformEventRecords.length;
            });
          }
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      StatsLog.error('AllStatsTimelineScreen._load', e.toString());
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Widget _summaryChips(BuildContext context, _DayUnitSummary u) {
    final colorScheme = Theme.of(context).colorScheme;
    final chips = <Widget>[];

    void add(IconData icon, String text, [Color? color]) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color ?? colorScheme.primary),
              const SizedBox(width: 2),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (u.watchSeconds > 0) {
      add(Icons.schedule, Utils.formatHMS(u.watchSeconds), colorScheme.tertiary);
    }
    if (u.clicks > 0) add(Icons.touch_app_outlined, '${u.clicks}');
    if (u.ratingCount > 0) {
      add(Icons.star_rounded, 'x${u.ratingCount}', Colors.amber);
    }
    if (u.commentCount > 0) {
      add(Icons.mode_comment_outlined, 'x${u.commentCount}');
    }
    if (u.favoriteCount > 0) {
      add(Icons.bookmark_add_outlined, 'x${u.favoriteCount}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          u.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(spacing: 2, runSpacing: 2, children: chips),
          ),
      ],
    );
  }

  Widget _dayContent(
    BuildContext context,
    DateTime day,
    Map<String, _DayUnitSummary> dayUnits,
  ) {
    final units = dayUnits.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              t.statsTimelineDay(month: day.month, day: day.day),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: units
                  .map((u) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _summaryChips(context, u),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_failed || _byDay.isEmpty) {
      body = Center(child: Text(t.statsTimelineNoRecords));
    } else {
      final days = _byDay.keys.toList()..sort((a, b) => b.compareTo(a));

      final years = days.map((d) => d.year).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      final monthsOf = <int, List<int>>{};
      final daysOf = <String, List<DateTime>>{};
      for (final d in days) {
        final ys = monthsOf.putIfAbsent(d.year, () => []);
        if (!ys.contains(d.month)) ys.add(d.month);
        daysOf.putIfAbsent('${d.year}-${d.month}', () => []).add(d);
      }
      for (final l in monthsOf.values) {
        l.sort((a, b) => b.compareTo(a));
      }
      for (final l in daysOf.values) {
        l.sort((a, b) => b.compareTo(a));
      }

      final yearNodes = <Widget>[];
      for (var y = 0; y < years.length; y++) {
        final year = years[y];
        final yearMonths = monthsOf[year]!;
        final monthNodes = <Widget>[];
        for (var m = 0; m < yearMonths.length; m++) {
          final month = yearMonths[m];
          final monthDays = daysOf['$year-$month']!;
          monthNodes.add(
            TimelineTreeNode(
              title: Text(
                '$year-${month.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              color: colorScheme.secondary,
              dotSize: 12,
              isFirst: m == 0,
              isLast: m == yearMonths.length - 1,
              childrenIndent: 32,
              children: [
                for (var d = 0; d < monthDays.length; d++)
                  TimelineTreeNode(
                    title: _dayContent(context, monthDays[d], _byDay[monthDays[d]]!),
                    color: colorScheme.tertiary,
                    dotSize: 10,
                    isFirst: d == 0,
                    isLast: d == monthDays.length - 1,
                  ),
              ],
            ),
          );
        }
        yearNodes.add(
          TimelineTreeNode(
            title: Text(
              t.statsYearSuffix(year: year),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            color: colorScheme.primary,
            dotSize: 16,
            isFirst: y == 0,
            isLast: y == years.length - 1,
            childrenIndent: 32,
            children: monthNodes,
          ),
        );
      }

      body = ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        children: yearNodes,
      );
    }

    return Scaffold(
      appBar: Appbar(title: Text(t.statsAllTimelineTitle)),
      body: body,
    );
  }
}
