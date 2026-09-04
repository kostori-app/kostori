library;

import 'dart:math';

import 'package:ensemble_table_calendar/ensemble_table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/share_widget.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/components/word_cloud_widget.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/init.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/pages/stats/stats_controller.dart';
import 'package:kostori/pages/stats/stat_display.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:word_cloud/word_cloud_data.dart';
import 'package:word_cloud/word_cloud_exporter.dart';
import 'package:word_cloud/word_cloud_view.dart';

part 'stat_item_card.dart';

part 'stats_overview.dart';

part 'stats_view_page.dart';

class StatsCalendarPage extends ConsumerStatefulWidget {
  const StatsCalendarPage({super.key, required this.controller});

  final StatsController controller;

  @override
  ConsumerState<StatsCalendarPage> createState() => _StatsCalendarPageState();
}

class _StatsCalendarPageState extends ConsumerState<StatsCalendarPage> {
  StatsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    DataSync().addListener(controller.loadEvents);
  }

  @override
  void dispose() {
    DataSync().removeListener(controller.loadEvents);
    super.dispose();
  }

  void showStats({
    required List<StatsDataImpl> stats,
    required String title,
    required TimeRange timeRange,
  }) {
    showPopUpWidget(
      App.rootContext,
      StatefulBuilder(
        builder: (context, setState) {
          return StatsOverviewScreen(
            stats: stats,
            selectedDay: controller.selectedDay ?? controller.focusedDay,
            title: title,
            timeRange: timeRange,
          );
        },
      ),
    );
  }

  List<List<StatsDataImpl>> _groupEntriesByBangumiId(
    List<StatsDataImpl> entries,
  ) {
    final Map<int?, List<StatsDataImpl>> groups = {};

    for (final entry in entries) {
      final bangumiId = entry.bangumiId;
      groups.putIfAbsent(bangumiId, () => []).add(entry);
    }

    final List<List<StatsDataImpl>> result = [];

    final groupsWithId = groups.entries
        .where((entry) => entry.key != null)
        .map((entry) => entry.value)
        .toList();

    result.addAll(groupsWithId);

    final independentEntries = groups[null] ?? [];
    for (final entry in independentEntries) {
      result.add([entry]);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (controller.isLoading) {
          return const Center(
            heightFactor: 10,
            child: KostoriRefreshIndicator(),
          );
        }
        final groupedEntries = _groupEntriesByBangumiId(
          controller.entriesForSelectedDay,
        );
        final limitedEntries = groupedEntries.take(9).toList();
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(child: Text(t.statsCalendar, style: ts.s18)),
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
                      child: Text(
                        '${controller.totalEventCount}',
                        style: ts.s12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: t.statsYearlyOverview,
                      icon: const Icon(Icons.grid_view_rounded),
                      onPressed: () {
                        context.to(
                          () => YearlyTilePage(
                            year: controller.focusedDay.year,
                            controller: controller,
                          ),
                        );
                      },
                    ),
                    MenuAnchor(
                      builder: (context, controller, child) {
                        return IconButton(
                          tooltip: t.statsRangeOverview,
                          icon: const Icon(Icons.timeline),
                          onPressed: () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          },
                        );
                      },
                      menuChildren: [
                        MenuItemButton(
                          onPressed: () async {
                            showStats(
                              stats: controller.getEntriesForTimeRange(
                                TimeRange.weekly,
                              ),
                              title: t.statsWeekly,
                              timeRange: TimeRange.weekly,
                            );
                          },
                          child: ListTile(
                            leading: Icon(Icons.date_range, size: 20),
                            title: Text(t.statsWeekly),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            showStats(
                              stats: controller.getEntriesForTimeRange(
                                TimeRange.monthly,
                              ),
                              title: t.statsMonthly,
                              timeRange: TimeRange.monthly,
                            );
                          },
                          child: ListTile(
                            leading: Icon(Icons.calendar_month, size: 20),
                            title: Text(t.statsMonthly),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            showStats(
                              stats: controller.getEntriesForTimeRange(
                                TimeRange.quarterly,
                              ),
                              title: t.statsQuarterly,
                              timeRange: TimeRange.quarterly,
                            );
                          },
                          child: ListTile(
                            leading: Icon(Icons.event_note_rounded, size: 20),
                            title: Text(t.statsQuarterly),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            showStats(
                              stats: controller.getEntriesForTimeRange(
                                TimeRange.halfYearly,
                              ),
                              title: t.statsHalfYearly,
                              timeRange: TimeRange.halfYearly,
                            );
                          },
                          child: ListTile(
                            leading: Icon(Icons.event, size: 20),
                            title: Text(t.statsHalfYearly),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            showStats(
                              stats: controller.getEntriesForTimeRange(
                                TimeRange.yearly,
                              ),
                              title: t.statsYearly,
                              timeRange: TimeRange.yearly,
                            );
                          },
                          child: ListTile(
                            leading: Icon(Icons.calendar_today, size: 20),
                            title: Text(t.statsYearly),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: t.statsSourceList,
                      icon: const Icon(Icons.list_alt),
                      onPressed: () async {
                        await controller.showAnimeSourlList().then((_) {
                          setState(() {});
                        });
                      },
                    ),
                    IconButton(
                      tooltip: t.statsSelectDate,
                      icon: const Icon(Icons.edit_calendar_rounded),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: controller.focusedDay,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2077),
                        );

                        if (pickedDate != null) {
                          controller.jumpToDate(pickedDate);
                        }
                      },
                    ),
                  ],
                ),
              ).paddingHorizontal(16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Material(
                  color: context.brightness == Brightness.light
                      ? Colors.white.toOpacity(0.72)
                      : const Color(0xFF1E1E1E).toOpacity(0.72),
                  elevation: 4,
                  shadowColor: Theme.of(context).colorScheme.shadow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TableCalendar(
                    // key: const PageStorageKey("stats_TableCalendar"),
                    firstDay: DateTime.utc(2000, 1, 1),
                    lastDay: DateTime.utc(2077, 12, 31),
                    focusedDay: controller.focusedDay,
                    selectedDayPredicate: (day) =>
                        isSameDay(controller.selectedDay, day),
                    calendarFormat: controller.calendarFormat,
                    onDaySelected: controller.onDaySelected,
                    onPageChanged: controller.onPageChanged,
                    onFormatChanged: controller.onFormatChanged,
                    eventLoader: controller.getEventsForDay,
                    daysOfWeekHeight: 24,
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                      weekendStyle: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      dowTextFormatter: (date, locale) {
                        var weekDays = [
                          t.sunday,
                          t.monday,
                          t.tuesday,
                          t.wednesday,
                          t.thursday,
                          t.friday,
                          t.saturday,
                        ];
                        return weekDays[date.weekday % 7];
                      },
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextFormatter: (date, locale) {
                        var months = [
                          t.january,
                          t.february,
                          t.march,
                          t.april,
                          t.may,
                          t.june,
                          t.july,
                          t.august,
                          t.september,
                          t.october,
                          t.november,
                          t.december,
                        ];
                        return '${months[date.month - 1]} ${date.year}';
                      },
                      leftChevronMargin: EdgeInsets.only(left: 40),
                      rightChevronMargin: EdgeInsets.only(right: 40),
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.toOpacity(0.72),
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.toOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return const SizedBox();

                        final colors = standardColorMap.keys.toList();
                        final count = events.length;
                        final displayCount = count.clamp(1, 6);

                        return Positioned(
                          bottom: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(displayCount, (i) {
                              final color = count <= 6
                                  ? colors[i % colors.length]
                                  : colors[(i + (count ~/ 6)) % colors.length];

                              return Container(
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  right: 2,
                                ),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }),
                          ),
                        );
                      },
                      defaultBuilder: (context, day, focusedDay) {
                        return DayCell(
                          day: day,
                          backgroundColor: Colors.transparent,
                          onSelected: (d) {
                            setState(() {
                              controller.selectedDay = d;
                            });
                          },
                        );
                      },

                      // 今天
                      todayBuilder: (context, day, focusedDay) {
                        return DayCell(
                          day: day,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary.toOpacity(0.36),
                          onSelected: (d) {
                            setState(() {
                              controller.selectedDay = d;
                            });
                          },
                        );
                      },
                      // 选中日期
                      selectedBuilder: (context, day, focusedDay) {
                        return DayCell(
                          day: day,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.toOpacity(0.48),
                          onSelected: (d) {
                            setState(() {
                              controller.selectedDay = d;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: groupedEntries.isNotEmpty
                    ? Column(
                        key: const ValueKey('entries_column'),
                        children: [
                          const SizedBox(height: 4),
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
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 56,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Center(
                                  child: Text(t.todaysRecords, style: ts.s18),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    groupedEntries.length <= 9
                                        ? '${groupedEntries.length}'
                                        : '${groupedEntries.length} ( 9 )',
                                    style: ts.s12,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: t.dailyStats,
                                  icon: const Icon(Icons.today),
                                  onPressed: () async {
                                    showStats(
                                      stats: controller.getEntriesForTimeRange(
                                        TimeRange.daily,
                                      ),
                                      title: t.statsDaily,
                                      timeRange: TimeRange.daily,
                                    );
                                  },
                                ),
                                if (groupedEntries.length > 9)
                                  IconButton(
                                    tooltip: t.viewAll,
                                    icon: const Icon(
                                      Icons.format_list_bulleted,
                                    ),
                                    onPressed: () {
                                      context.to(
                                        () => FullStatsPage(
                                          statsDataList: groupedEntries,
                                          selectedDay:
                                              controller.selectedDay ??
                                              controller.focusedDay,
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ).paddingHorizontal(16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            child: Column(
                              children: List.generate(limitedEntries.length, (
                                index,
                              ) {
                                final statGroup = limitedEntries[index];
                                return Padding(
                                  key: ValueKey(statGroup.first.id),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                  child: StatEntryCard(
                    onTap: () => showPopUpWidget(
                      context,
                      PopUpWidgetScaffold(
                        title: statGroup.first.title ??
                            statGroup.first.id,
                        body: StatsTimelineView(group: statGroup),
                      ),
                    ),
                    child: StatItemWidget(
                                      statsGroup: statGroup,
                                      selectedDay:
                                          controller.selectedDay ??
                                          controller.focusedDay,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FullStatsPage extends StatelessWidget {
  FullStatsPage({
    super.key,
    required this.statsDataList,
    required this.selectedDay,
  });

  final List<List<StatsDataImpl>> statsDataList;

  final DateTime selectedDay;

  final ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    Widget widget = Scaffold(
      appBar: Appbar(title: Text(t.statsDayRecords)),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: ListView.builder(
          controller: scrollController,
          itemCount: statsDataList.length,
          itemBuilder: (context, index) {
            final statGroup = statsDataList[index];
            return Padding(
              key: ValueKey(statGroup.first.id),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: StatEntryCard(
                onTap: () => showPopUpWidget(
                  context,
                  PopUpWidgetScaffold(
                    title: statGroup.first.title ?? statGroup.first.id,
                    body: StatsTimelineView(group: statGroup),
                  ),
                ),
                child: StatItemWidget(
                  statsGroup: statGroup,
                  selectedDay: selectedDay,
                ),
              ),
            );
          },
        ),
      ),
    );
    widget = AppScrollBar(
      topPadding: 82,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );
    return widget;
  }
}

class DayCell extends StatelessWidget {
  final DateTime day;
  final Color backgroundColor;
  final ValueChanged<DateTime>? onSelected;

  const DayCell({
    super.key,
    required this.day,
    required this.backgroundColor,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: InkWell(
        onTap: () => onSelected?.call(day),
        customBorder: const CircleBorder(),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DailyEvent? _getDailyEvent(List<DailyEvent> events, DateTime date) {
  for (final event in events) {
    if (_isSameDay(event.date, date)) {
      return event;
    }
  }
  return null;
}

String _getSourceType(int type) {
  if (type == 'bangumi'.hashCode) {
    return 'bangumi';
  }
  try {
    return AnimeType(type).sourceKey;
  } catch (e) {
    return 'unknown';
  }
}

class YearlyTilePage extends ConsumerStatefulWidget {
  const YearlyTilePage({
    super.key,
    required this.year,
    required this.controller,
  });

  final int year;
  final StatsController controller;

  @override
  ConsumerState<YearlyTilePage> createState() => _YearlyTilePageState();
}

class _YearlyTilePageState extends ConsumerState<YearlyTilePage> {
  late int _year = widget.year;
  late Map<DateTime, double> _heatmapData = _buildYearHeatmap();

  Future<void> _captureOffscreen(BuildContext context) async {
    try {
      final bytes = await ImageSaver.captureWidgetToImage(
        context: context,
        width: 1200.0,
        delay: const Duration(milliseconds: 500),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.statsYearSuffix(year: _year),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemCount: 12,
                itemBuilder: (context, i) => _buildTile(context, i),
              ),
            ],
          ),
        ),
      );
      if (bytes == null) return;

      final filename = 'yearly_${DateTime.now().millisecondsSinceEpoch}.png';
      await ImageSaver.saveOrShareImage(
        bytes: bytes,
        filename: filename,
        desktopSuccessMessage: t.statsCopiedToClipboard,
      );
    } catch (e) {
      ImageSaver.showResult(success: false, message: t.screenshotFailed);
      Log.error('截图失败', '$e');
    } finally {
      await ref.read(imagesProvider.notifier).loadImages();
    }
  }

  static List<String> get _monthNames => [
    t.statsMonth1,
    t.statsMonth2,
    t.statsMonth3,
    t.statsMonth4,
    t.statsMonth5,
    t.statsMonth6,
    t.statsMonth7,
    t.statsMonth8,
    t.statsMonth9,
    t.statsMonth10,
    t.statsMonth11,
    t.statsMonth12,
  ];

  final now = DateTime.now();

  List<StatsDataImpl> _getMonthStats(int month) {
    return widget.controller.eventMap.entries
        .where((e) => e.key.year == _year && e.key.month == month)
        .expand((e) => e.value)
        .toList();
  }

  double _monthIntensity(int month) {
    return widget.controller.eventMap.entries
        .where((e) => e.key.year == _year && e.key.month == month)
        .fold(0.0, (sum, e) => sum + e.value.length);
  }

  Map<DateTime, double> _buildYearHeatmap() {
    final map = <DateTime, double>{};
    for (final entry in widget.controller.eventMap.entries) {
      if (entry.key.year != _year) continue;
      final key = DateTime(entry.key.year, entry.key.month, entry.key.day);
      map[key] = (map[key] ?? 0) + entry.value.length;
    }
    return map;
  }

  void _changeYear(int delta) {
    setState(() {
      _year += delta;
      _heatmapData = _buildYearHeatmap();
    });
  }

  void _showMonthStats(BuildContext context, int month) {
    final stats = _getMonthStats(month);
    if (stats.isEmpty) {
      context.showMessage(
        message: t.noRecordForMonth(month: _monthNames[month - 1]),
      );
      return;
    }
    showPopUpWidget(
      App.rootContext,
      StatsOverviewScreen(
        stats: stats,
        selectedDay: DateTime(_year, month, 1),
        title: t.statsYearMonthName(year: _year, month: _monthNames[month - 1]),
        timeRange: TimeRange.monthly,
      ),
    );
  }

  Widget _buildTile(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme;
    final intensities = List.generate(12, (i) => _monthIntensity(i + 1));
    final maxIntensity = intensities.isEmpty
        ? 1.0
        : intensities
              .reduce((a, b) => a > b ? a : b)
              .clamp(1.0, double.infinity);
    final month = i + 1;
    final stats = _getMonthStats(month);
    final isEmpty = stats.isEmpty;
    final isFuture =
        _year > now.year || (_year == now.year && month > now.month);
    final intensity = maxIntensity > 0 ? intensities[i] / maxIntensity : 0.0;

    return GestureDetector(
      onTap: isEmpty || isFuture ? null : () => _showMonthStats(context, month),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isEmpty || isFuture
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : scheme.primary.withValues(alpha: 0.05 + intensity * 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEmpty || isFuture
                ? scheme.outlineVariant.withValues(alpha: 0.4)
                : scheme.primary.withValues(alpha: 0.2 + intensity * 0.3),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _monthNames[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isEmpty || isFuture
                        ? scheme.onSurface.withValues(alpha: 0.3)
                        : scheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (!isEmpty && !isFuture)
                  Text(
                    '${stats.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (!isEmpty && !isFuture)
              Expanded(
                child: _MiniHeatmap(
                  data: _heatmapData,
                  year: _year,
                  month: month,
                  intensity: intensity,
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    isFuture ? t.statsFuture : t.statsNoRecordsOnDay,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeYear(-1),
            ),
            Text(t.statsYearSuffix(year: _year)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeYear(1),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _captureOffscreen(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
          ),
          itemCount: 12,
          itemBuilder: (context, i) => _buildTile(context, i),
        ),
      ),
    );
  }
}

class _MiniHeatmap extends StatelessWidget {
  const _MiniHeatmap({
    required this.data,
    required this.year,
    required this.month,
    required this.intensity,
  });

  final Map<DateTime, double> data;
  final int year;
  final int month;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final primary = Theme.of(context).colorScheme.primary;

    final monthData = <int, double>{};
    for (final e in data.entries) {
      if (e.key.year == year && e.key.month == month) {
        monthData[e.key.day] = e.value;
      }
    }

    final maxVal = monthData.values.isEmpty
        ? 1.0
        : monthData.values
              .reduce((a, b) => a > b ? a : b)
              .clamp(1.0, double.infinity);

    final paddedDays = [
      ...List<int?>.filled(firstWeekday - 1, null),
      ...List.generate(daysInMonth, (i) => i + 1),
    ];
    while (paddedDays.length % 7 != 0) {
      paddedDays.add(null);
    }
    final rows = paddedDays.length ~/ 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 2.0;
        final cellSize = (constraints.maxHeight - 6 * gap) / 7;
        final trendHeight = (cellSize * 0.35).clamp(4.0, 35.0);

        final heatmap = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (row) {
            return Row(
              children: List.generate(7, (col) {
                final idx = row * 7 + col;
                final day = idx < paddedDays.length ? paddedDays[idx] : null;
                final val = day != null ? (monthData[day] ?? 0) : 0.0;
                final cellIntensity = day != null
                    ? (val / maxVal).clamp(0.0, 1.0)
                    : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(gap),
                    child: SizedBox(
                      height: cellSize,
                      child: Container(
                        decoration: BoxDecoration(
                          color: day == null
                              ? Colors.transparent
                              : cellIntensity == 0
                              ? primary.withValues(alpha: 0.07)
                              : primary.withValues(
                                  alpha: 0.15 + cellIntensity * 0.7,
                                ),
                          borderRadius: BorderRadius.circular(cellSize * 0.3),
                          boxShadow: day != null && cellIntensity > 0
                              ? [
                                  BoxShadow(
                                    color: primary.withValues(
                                      alpha: cellIntensity * 0.3,
                                    ),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: day == null
                            ? null
                            : Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: (cellSize * 0.45).clamp(4.0, 9.0),
                                    height: 1,
                                    fontWeight: cellIntensity > 0.5
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cellIntensity > 0.6
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : primary.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        );

        return Stack(
          children: [
            Positioned.fill(child: heatmap),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: trendHeight,
                    child: CustomPaint(
                      painter: _MiniTrendPainter(
                        monthData: monthData,
                        daysInMonth: daysInMonth,
                        maxVal: maxVal,
                        color: primary,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: intensity,
                      minHeight: 3,
                      backgroundColor: primary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(
                        primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniTrendPainter extends CustomPainter {
  const _MiniTrendPainter({
    required this.monthData,
    required this.daysInMonth,
    required this.maxVal,
    required this.color,
  });

  final Map<int, double> monthData;
  final int daysInMonth;
  final double maxVal;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (monthData.isEmpty || daysInMonth < 2) return;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    Offset toOffset(int day) {
      final x = size.width * (day - 1) / (daysInMonth - 1);
      final val = monthData[day] ?? 0;
      final y = size.height * (1 - (val / maxVal).clamp(0.0, 1.0)) * 0.85 + 2;
      return Offset(x, y);
    }

    final days = List.generate(daysInMonth, (i) => i + 1);

    final fillPath = Path()..moveTo(0, size.height);
    for (final d in days) {
      final o = toOffset(d);
      if (d == 1) {
        fillPath.lineTo(o.dx, o.dy);
      } else {
        fillPath.lineTo(o.dx, o.dy);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path();
    for (var i = 0; i < days.length; i++) {
      final o = toOffset(days[i]);
      if (i == 0) {
        linePath.moveTo(o.dx, o.dy);
      } else {
        linePath.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_MiniTrendPainter old) =>
      old.monthData != monthData || old.maxVal != maxVal;
}
