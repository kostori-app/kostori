library;

import 'dart:math';

import 'package:ensemble_table_calendar/ensemble_table_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/pages/stats/stats_controller.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:word_cloud/word_cloud_data.dart';
import 'package:word_cloud/word_cloud_shape.dart';
import 'package:word_cloud/word_cloud_view.dart';

part 'stat_item_card.dart';

part 'stats_overview.dart';

part 'stats_view_page.dart';

class StatsCalendarPage extends StatefulWidget {
  const StatsCalendarPage({super.key, required this.controller});

  final StatsController controller;

  @override
  State<StatsCalendarPage> createState() => _StatsCalendarPageState();
}

class _StatsCalendarPageState extends State<StatsCalendarPage> {
  late final StatsController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    DataSync().addListener(controller.loadEvents);
  }

  @override
  void dispose() {
    super.dispose();
    DataSync().removeListener(controller.loadEvents);
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
            child: CircularProgressIndicator(),
          );
        }
        final groupedEntries = _groupEntriesByBangumiId(
          controller.entriesForSelectedDay,
        );
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
                  children: [
                    Center(child: Text('统计日历'.tl, style: ts.s18)),
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
                    MenuAnchor(
                      builder: (context, controller, child) {
                        return IconButton(
                          tooltip: '时间范围统计',
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
                              title: '周统计',
                              timeRange: TimeRange.weekly,
                            );
                          },
                          child: const ListTile(
                            leading: Icon(Icons.date_range, size: 20),
                            title: Text('周统计'),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            showStats(
                              stats: controller.getEntriesForTimeRange(
                                TimeRange.monthly,
                              ),
                              title: '月统计',
                              timeRange: TimeRange.monthly,
                            );
                          },
                          child: const ListTile(
                            leading: Icon(Icons.calendar_month, size: 20),
                            title: Text('月统计'),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            showStats(
                              stats: controller.getEntriesForTimeRange(
                                TimeRange.quarterly,
                              ),
                              title: '季统计',
                              timeRange: TimeRange.quarterly,
                            );
                          },
                          child: const ListTile(
                            leading: Icon(Icons.event_note_rounded, size: 20),
                            title: Text('季统计'),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            showStats(
                              stats: controller.getEntriesForTimeRange(
                                TimeRange.halfYearly,
                              ),
                              title: '半年统计',
                              timeRange: TimeRange.halfYearly,
                            );
                          },
                          child: const ListTile(
                            leading: Icon(Icons.event, size: 20),
                            title: Text('半年统计'),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            showStats(
                              stats: controller.getEntriesForTimeRange(
                                TimeRange.yearly,
                              ),
                              title: '年统计',
                              timeRange: TimeRange.yearly,
                            );
                          },
                          child: const ListTile(
                            leading: Icon(Icons.calendar_today, size: 20),
                            title: Text('年统计'),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: '来源清单',
                      icon: const Icon(Icons.list_alt),
                      onPressed: () async {
                        await controller.showAnimeSourlList().then((_) {
                          setState(() {});
                        });
                      },
                    ),
                    IconButton(
                      tooltip: '选择日期',
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
                    const SizedBox(width: 10),
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
                          'Sunday'.tl,
                          'Monday'.tl,
                          'Tuesday'.tl,
                          'Wednesday'.tl,
                          'Thursday'.tl,
                          'Friday'.tl,
                          'Saturday'.tl,
                        ];
                        return weekDays[date.weekday % 7];
                      },
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextFormatter: (date, locale) {
                        var months = [
                          'January'.tl,
                          'February'.tl,
                          'March'.tl,
                          'April'.tl,
                          'May'.tl,
                          'June'.tl,
                          'July'.tl,
                          'August'.tl,
                          'September'.tl,
                          'October'.tl,
                          'November'.tl,
                          'December'.tl,
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

                        // 限制最多显示 4 个标记
                        final displayCount = events.length > 4
                            ? 4
                            : events.length;

                        List<Color> colors = List.generate(displayCount, (
                          index,
                        ) {
                          if (events.length <= 4) {
                            return Theme.of(context).colorScheme.primary;
                          } else {
                            // 根据事件总数决定前几个颜色
                            switch (index) {
                              case 0:
                                return events.length > 4
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary;
                              case 1:
                                return events.length > 8
                                    ? Colors.orange
                                    : Theme.of(context).colorScheme.primary;
                              case 2:
                                return events.length > 16
                                    ? Colors.deepPurple
                                    : Theme.of(context).colorScheme.primary;
                              default:
                                return Theme.of(context).colorScheme.primary;
                            }
                          }
                        });

                        return Positioned(
                          bottom: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(displayCount, (i) {
                              return Container(
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  right: 2,
                                ),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors[i],
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
                              children: [
                                Center(child: Text('当天的记录'.tl, style: ts.s18)),
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
                                    '${groupedEntries.length}',
                                    style: ts.s12,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: '天统计',
                                  icon: const Icon(Icons.today),
                                  onPressed: () async {
                                    showStats(
                                      stats: controller.getEntriesForTimeRange(
                                        TimeRange.daily,
                                      ),
                                      title: '天统计',
                                      timeRange: TimeRange.daily,
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
                              children: List.generate(groupedEntries.length, (
                                index,
                              ) {
                                final statGroup = groupedEntries[index];
                                return Padding(
                                  key: ValueKey(statGroup.first.id),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Material(
                                      color:
                                          context.brightness == Brightness.light
                                          ? Colors.white.toOpacity(0.72)
                                          : const Color(
                                              0xFF1E1E1E,
                                            ).toOpacity(0.72),
                                      elevation: 4,
                                      shadowColor: Theme.of(
                                        context,
                                      ).colorScheme.shadow,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: InkWell(
                                        onTap: () {},
                                        child: StatItemWidget(
                                          statsGroup: statGroup,
                                          selectedDay:
                                              controller.selectedDay ??
                                              controller.focusedDay,
                                        ),
                                      ),
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

class ResponsiveWordCloud extends StatefulWidget {
  final List<Map<String, dynamic>> wordCloudData;

  const ResponsiveWordCloud({super.key, required this.wordCloudData});

  @override
  State<ResponsiveWordCloud> createState() => _ResponsiveWordCloudState();
}

class _ResponsiveWordCloudState extends State<ResponsiveWordCloud> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return WordCloudView(
          data: WordCloudData(data: widget.wordCloudData),
          mapwidth: constraints.maxWidth,
          mapheight: 300,
          mintextsize: 6,
          maxtextsize: 28,
          colorlist: standardColorMap.keys.toList(),
          shape: WordCloudCircle(radius: constraints.maxWidth - 100),
        );
      },
    );
  }
}

String _formatHMS(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;

  final parts = <String>[];
  if (h > 0) parts.add('${h}h');
  if (m > 0) parts.add('${m}m');
  if (s > 0 || parts.isEmpty) parts.add('${s}s');

  return parts.join(' ');
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
