import 'package:flutter/material.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';

/// 某一天某个「条目」的粗略汇总（多来源已按 bangumi 归并为一条）
class _DayUnitSummary {
  _DayUnitSummary({required this.title, this.cover});

  final String title;
  final String? cover;
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
              .putIfAbsent(
                unitKey,
                () => _DayUnitSummary(title: title, cover: master.cover),
              );
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

  Widget _unitCard(BuildContext context, _DayUnitSummary u) {
    final colorScheme = Theme.of(context).colorScheme;
    final chips = <Widget>[];

    void add(IconData icon, String text, [Color? color]) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color ?? colorScheme.primary),
              const SizedBox(width: 3),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
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

    final cover = u.cover;
    final Widget thumb;
    if (cover?.isNotEmpty == true) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BangumiWidget.kostoriImage(
          context,
          cover!,
          width: 64,
          height: 92,
        ),
      );
    } else {
      thumb = Container(
        width: 64,
        height: 92,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          thumb,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (chips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 4, runSpacing: 4, children: chips),
                  ),
              ],
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
      body = const Center(child: KostoriRefreshIndicator());
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

      // 扁平化所有行（每行独立渲染，进入视口附近才构建，封面图随之懒加载）
      final specs = <_RowSpec>[];
      for (final year in years) {
        specs.add(
          _RowSpec(
            type: _RowType.year,
            depth: 0,
            open: const [0],
            year: year,
          ),
        );
        final yearMonths = monthsOf[year]!;
        for (final month in yearMonths) {
          specs.add(
            _RowSpec(
              type: _RowType.month,
              depth: 1,
              open: const [0, 1],
              year: year,
              month: month,
            ),
          );
          final monthDays = daysOf['$year-$month']!;
          for (final day in monthDays) {
            specs.add(
              _RowSpec(
                type: _RowType.day,
                depth: 2,
                open: const [0, 1, 2],
                date: day,
              ),
            );
            final units = _byDay[day]!.values.toList()
              ..sort((a, b) => a.title.compareTo(b.title));
            for (final unit in units) {
              specs.add(
                _RowSpec(
                  type: _RowType.card,
                  depth: 3,
                  open: const [0, 1, 2, 3],
                  unit: unit,
                ),
              );
            }
          }
        }
      }

      Widget contentOf(BuildContext context, _RowSpec spec) {
        switch (spec.type) {
          case _RowType.year:
            return Text(
              t.statsYearSuffix(year: spec.year!),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            );
          case _RowType.month:
            return Text(
              '${spec.year}-${spec.month.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            );
          case _RowType.day:
            return Text(
              t.statsTimelineDay(month: spec.date!.month, day: spec.date!.day),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            );
          case _RowType.card:
            return _unitCard(context, spec.unit!);
        }
      }

      body = ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        itemCount: specs.length,
        itemBuilder: (context, index) {
          final spec = specs[index];
          return _TimelineFlatRow(
            depth: spec.depth,
            openDepths: spec.open,
            child: contentOf(context, spec),
          );
        },
      );
    }

    return Scaffold(
      appBar: Appbar(title: Text(t.statsAllTimelineTitle)),
      body: body,
    );
  }
}

/// 扁平化时间线单行：只负责画这一行需要延续的各层竖线与本行圆点
class _TimelineFlatRow extends StatelessWidget {
  const _TimelineFlatRow({
    required this.depth,
    required this.openDepths,
    required this.child,
  });

  final int depth;
  final List<int> openDepths;
  final Widget child;

  static const double base = 10;
  static const double step = 18;

  Color colorFor(int d, ColorScheme cs) {
    switch (d) {
      case 0:
        return cs.primary;
      case 1:
        return cs.secondary;
      case 2:
        return cs.tertiary;
      default:
        return cs.primary.withValues(alpha: 0.85);
    }
  }

  double dotSizeFor(int d) {
    switch (d) {
      case 0:
        return 15;
      case 1:
        return 13;
      case 2:
        return 11;
      default:
        return 8;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lineColors = <Color>[];
    for (final d in openDepths) {
      lineColors.add(colorFor(d, cs).withValues(alpha: 0.4));
    }
    final xs = openDepths.map((d) => base + d * step).toList();
    final ownX = base + depth * step;
    final contentLeft = base + (depth + 1) * step;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _FlatRowPainter(
              lineXs: xs,
              lineColors: lineColors,
              ownX: ownX,
              ownY: 12,
              ownSize: dotSizeFor(depth),
              ownColor: colorFor(depth, cs),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            contentLeft,
            7,
            14,
            depth == 3 ? 8 : 3,
          ),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ],
    );
  }
}

class _FlatRowPainter extends CustomPainter {
  _FlatRowPainter({
    required this.lineXs,
    required this.lineColors,
    required this.ownX,
    required this.ownY,
    required this.ownSize,
    required this.ownColor,
  });

  final List<double> lineXs;
  final List<Color> lineColors;
  final double ownX;
  final double ownY;
  final double ownSize;
  final Color ownColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < lineXs.length; i++) {
      paint.color = lineColors[i];
      canvas.drawLine(
        Offset(lineXs[i], 0),
        Offset(lineXs[i], size.height),
        paint,
      );
    }
    canvas.drawCircle(
      Offset(ownX, ownY),
      ownSize / 2,
      Paint()..color = ownColor,
    );
  }

  @override
  bool shouldRepaint(covariant _FlatRowPainter oldDelegate) =>
      oldDelegate.ownX != ownX ||
      oldDelegate.ownY != ownY ||
      oldDelegate.ownColor != ownColor;
}
enum _RowType { year, month, day, card }

class _RowSpec {
  _RowSpec({
    required this.type,
    required this.depth,
    required this.open,
    this.year,
    this.month,
    this.date,
    this.unit,
  });

  final _RowType type;
  final int depth;
  final List<int> open;
  final int? year;
  final int? month;
  final DateTime? date;
  final _DayUnitSummary? unit;
}
