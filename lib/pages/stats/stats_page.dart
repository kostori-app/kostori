import 'package:collection/collection.dart';
import 'package:ensemble_table_calendar/ensemble_table_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/pages/stats/stats_controller.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';

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

        final entries = controller.entriesForSelectedDay;
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
                      icon: const Icon(Icons.calendar_month),
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
                    // rowHeight: 24,
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
                child: entries.isNotEmpty
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
                                    '${entries.length}',
                                    style: ts.s12,
                                  ),
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
                              children: List.generate(entries.length, (index) {
                                final stats = entries[index];
                                return Padding(
                                  key: ValueKey(stats.id),
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
                                          stats: stats,
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

class StatItemWidget extends StatelessWidget {
  final StatsDataImpl stats;

  final DateTime selectedDay;

  StatItemWidget({super.key, required this.stats, required this.selectedDay});

  final height =
      (App.isAndroid || MediaQuery.of(App.rootContext).size.width <= 700)
      ? 240.0
      : 300.0;

  DailyEvent? _getDailyEvent(List<DailyEvent> events) {
    for (final event in events) {
      if (_isSameDay(event.date, selectedDay)) {
        return event;
      }
    }
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String formatHMSForRating({int? seconds}) {
    seconds ??= 0;

    if (seconds <= 0) return '';

    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    if (s > 0 || parts.isEmpty) parts.add('${s}s');

    return '(评价时 ${parts.join(' ')})';
  }

  Widget buildAllEventsWidget(BuildContext context) {
    final commentEvent = _getDailyEvent(stats.comment);
    final ratingEvent = _getDailyEvent(stats.rating);
    final favoriteEvent = _getDailyEvent(stats.favorite);

    if ((commentEvent == null || commentEvent.platformEventRecords.isEmpty) &&
        (ratingEvent == null || ratingEvent.platformEventRecords.isEmpty) &&
        (favoriteEvent == null || favoriteEvent.platformEventRecords.isEmpty)) {
      return const SizedBox.shrink();
    }

    final List<Map<String, dynamic>> allRecords = [];

    void addEventRecords(
      DailyEvent? event,
      DailyEventType type,
      List<DailyEvent> list,
    ) {
      if (event == null) return;
      final dailyIndex = list.indexOf(event);
      for (int ri = 0; ri < event.platformEventRecords.length; ri++) {
        allRecords.add({
          'type': type,
          'dailyIndex': dailyIndex,
          'recordIndex': ri,
          'dailyList': list,
          'record': event.platformEventRecords[ri],
        });
      }
    }

    addEventRecords(commentEvent, DailyEventType.comment, stats.comment);
    addEventRecords(ratingEvent, DailyEventType.rating, stats.rating);
    addEventRecords(favoriteEvent, DailyEventType.favorite, stats.favorite);

    allRecords.sort(
      (a, b) => (a['record'] as PlatformEventRecord).date!.compareTo(
        (b['record'] as PlatformEventRecord).date!,
      ),
    );

    return buildMaterialWidget(
      context: context,
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: allRecords.map((entry) {
          final type = entry['type'] as DailyEventType;
          final dailyIndex = entry['dailyIndex'] as int;
          final recordIndex = entry['recordIndex'] as int;
          final dailyList = entry['dailyList'] as List<DailyEvent>;
          final record = entry['record'] as PlatformEventRecord;

          switch (type) {
            case DailyEventType.comment:
              if (dailyList.length == 1 || dailyIndex == 0) {
                final text = recordIndex == 0
                    ? '${record.date!.hhmmss} 创建了评论 ${formatHMSForRating(seconds: record.watchDuration)}:'
                          .tl
                    : '${record.date!.hhmmss} 第${record.value - 1}次修改了评论 ${formatHMSForRating(seconds: record.watchDuration)}:'
                          .tl;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          record.comment ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              } else {
                int sum = 0;
                for (int i = 0; i < dailyIndex; i++) {
                  final rList = dailyList[i].platformEventRecords;
                  if (rList.isNotEmpty) sum += rList.last.value;
                }
                final text =
                    '${record.date!.hhmmss} 第${sum + record.value - 1}次修改了评论 ${formatHMSForRating(seconds: record.watchDuration)}:'
                        .tl;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          record.comment ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }

            case DailyEventType.rating:
              if (dailyList.length == 1 || dailyIndex == 0) {
                final text = recordIndex == 0
                    ? '${record.date!.hhmmss} 创建了评级 ${formatHMSForRating(seconds: record.watchDuration)}:'
                          .tl
                    : '${record.date!.hhmmss} 第${record.value - 1}次修改了评级 ${formatHMSForRating(seconds: record.watchDuration)}:'
                          .tl;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          record.rating.toString(),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
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
                          child: Text(Utils.getRatingLabel(record.rating!)),
                        ),
                        const SizedBox(width: 4),
                        RatingBarIndicator(
                          itemCount: 5,
                          rating: record.rating! / 2,
                          itemBuilder: (context, index) =>
                              const Icon(Icons.star_rounded),
                          itemSize: 20.0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              } else {
                int sum = 0;
                for (int i = 0; i < dailyIndex; i++) {
                  final rList = dailyList[i].platformEventRecords;
                  if (rList.isNotEmpty) sum += rList.last.value;
                }
                final text =
                    '${record.date!.hhmmss} 第${sum + record.value - 1}次修改了评级 ${formatHMSForRating(seconds: record.watchDuration)}:'
                        .tl;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          record.rating.toString(),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
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
                          child: Text(Utils.getRatingLabel(record.rating!)),
                        ),
                        const SizedBox(width: 4),
                        RatingBarIndicator(
                          itemCount: 5,
                          rating: record.rating! / 2,
                          itemBuilder: (context, index) =>
                              const Icon(Icons.star_rounded),
                          itemSize: 20.0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }

            case DailyEventType.favorite:
              String actionText;
              switch (record.favoriteAction) {
                case FavoriteAction.add:
                  actionText = "添加到 ${record.favorite?.tl ?? '未知文件夹'}";
                  break;
                case FavoriteAction.remove:
                  actionText = "从 ${record.favorite?.tl ?? '未知文件夹'} 删除";
                  break;
                case FavoriteAction.move:
                  if (record.favorite != null &&
                      record.favorite!.contains(',')) {
                    final parts = record.favorite!.split(',');
                    actionText = "从 ${parts[0].tl} 移动到 ${parts[1].tl}";
                  } else {
                    actionText = "移动操作，目标未知".tl;
                  }
                  break;
                default:
                  actionText = "操作未知".tl;
                  break;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.date!.hhmmss} $actionText',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                ],
              );

            default:
              return const SizedBox.shrink();
          }
        }).toList(),
      ),
    );
  }

  Widget buildClickWidget(BuildContext context) {
    final clickEvent = _getDailyEvent(stats.totalClickCount);

    if (clickEvent == null || clickEvent.platformEventRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    int totalClicks = 0;
    final recordStrings = <String>[];
    for (final record in clickEvent.platformEventRecords) {
      recordStrings.add('在${record.platform?.value ?? '未知'}点击${record.value}次');
      totalClicks += record.value;
    }

    children.add(
      Text(
        '本日点击次数: $totalClicks',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
    children.add(const SizedBox(height: 4));

    children.add(
      Text(recordStrings.join(', '), style: const TextStyle(fontSize: 14)),
    );

    return buildMaterialWidget(
      context: context,
      widget: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget buildWatchWidget(BuildContext context) {
    final watchEvent = _getDailyEvent(stats.totalWatchDurations);

    if (watchEvent == null || watchEvent.platformEventRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    int totalSeconds = 0;

    String formatHMS(int seconds) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final s = seconds % 60;

      final parts = <String>[];
      if (h > 0) parts.add('${h}h');
      if (m > 0) parts.add('${m}m');
      if (s > 0 || parts.isEmpty) parts.add('${s}s');

      return parts.join(' ');
    }

    final children = <Widget>[];

    final recordStrings = <String>[];
    for (final record in watchEvent.platformEventRecords) {
      recordStrings.add(
        '在${record.platform?.value ?? '未知'}观看: ${formatHMS(record.value)}',
      );
      totalSeconds += record.value;
    }

    children.add(
      Text(
        '本日观看时长: ${formatHMS(totalSeconds)}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
    children.add(const SizedBox(height: 4));

    children.add(
      Text(recordStrings.join(', '), style: const TextStyle(fontSize: 14)),
    );

    if (totalSeconds == 0) {
      return const SizedBox.shrink();
    }

    return buildMaterialWidget(
      context: context,
      widget: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ],
      ),
    );
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

  Widget buildInfoWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '记录: ',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6),
        buildClickWidget(context),
        SizedBox(height: 6),
        buildWatchWidget(context),
        SizedBox(height: 6),
        buildAllEventsWidget(context),
        SizedBox(height: 6),
      ],
    );
  }

  Widget buildTitleWidget(BuildContext context, BangumiItem? bangumiItem) {
    DailyEvent? todayWatchEvent = stats.totalWatchDurations.firstWhereOrNull((
      event,
    ) {
      return event.date.year == selectedDay.year &&
          event.date.month == selectedDay.month &&
          event.date.day == selectedDay.day;
    });
    DailyEvent? todayClickEvent = stats.totalClickCount.firstWhereOrNull((
      event,
    ) {
      return event.date.year == selectedDay.year &&
          event.date.month == selectedDay.month &&
          event.date.day == selectedDay.day;
    });

    PlatformEventRecord? latestWatchRecord;
    PlatformEventRecord? latestClickRecord;

    if (todayWatchEvent != null) {
      final nonNullRecords = todayWatchEvent.platformEventRecords
          .where((r) => r.date != null)
          .toList();
      if (nonNullRecords.isNotEmpty) {
        latestWatchRecord = nonNullRecords.reduce((a, b) {
          return a.date!.isAfter(b.date!) ? a : b;
        });
      }
    }
    if (todayClickEvent != null) {
      final nonNullRecords = todayClickEvent.platformEventRecords
          .where((r) => r.date != null)
          .toList();
      if (nonNullRecords.isNotEmpty) {
        latestClickRecord = nonNullRecords.reduce((a, b) {
          return a.date!.isAfter(b.date!) ? a : b;
        });
      }
    }

    Widget buildCoverWidget() {
      String cover;
      if (bangumiItem != null) {
        cover = bangumiItem.images['large']!;
      } else {
        cover = stats.cover!;
      }

      if (stats.cover == null && bangumiItem == null) {
        return const SizedBox.shrink();
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Hero(
          tag: '$stats.id',
          child: BangumiWidget.kostoriImage(
            context,
            cover,
            width: height * 0.72,
            height: height,
            showPlaceholder: true,
          ),
        ),
      );
    }

    Widget buildTypeWidget() {
      String type;
      if (stats.isBangumi) {
        type = 'bangumi';
      } else {
        type = AnimeType(stats.type).sourceKey;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pix, size: 16),
            const SizedBox(width: 4),
            Text(type, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    Widget titleBuild() {
      return bangumiItem != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(bangumiItem.nameCn), Text(bangumiItem.name)],
            )
          : stats.title != null
          ? Text(
              stats.title!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            )
          : const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildCoverWidget(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBuild(),
                Spacer(),
                Row(
                  children: [
                    Icon(
                      stats.liked ? Icons.favorite : Icons.favorite_border,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                    SizedBox(width: 8),
                    buildTypeWidget(),
                  ],
                ),
                if (latestClickRecord?.date != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '当日最后点击: ${latestClickRecord?.date!.hhmmss}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
                if (latestWatchRecord?.date != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '当日最后观看: ${latestWatchRecord?.date!.hhmmss}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    BangumiItem? bangumiItem;
    if (stats.bangumiId != null) {
      bangumiItem = BangumiManager().getBangumiItem(stats.bangumiId!);
    }
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: MediaQuery.of(context).size.width >= 700
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: buildTitleWidget(context, bangumiItem),
                ),
                Expanded(flex: 1, child: buildInfoWidget(context)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildTitleWidget(context, bangumiItem)),
                  ],
                ),
                const SizedBox(height: 10),
                buildInfoWidget(context),
              ],
            ),
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
