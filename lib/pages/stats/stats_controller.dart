// ignore_for_file: library_private_types_in_public_api

import 'package:ensemble_table_calendar/ensemble_table_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/stats/stats_page.dart';
import 'package:kostori/utils/utils.dart';

@immutable
class StatsState {
  const StatsState({
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.eventMap,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final CalendarFormat calendarFormat;
  final Map<DateTime, List<StatsDataImpl>> eventMap;

  StatsState copyWith({
    DateTime? focusedDay,
    DateTime? selectedDay,
    CalendarFormat? calendarFormat,
    Map<DateTime, List<StatsDataImpl>>? eventMap,
  }) {
    return StatsState(
      focusedDay: focusedDay ?? this.focusedDay,
      selectedDay: selectedDay ?? this.selectedDay,
      calendarFormat: calendarFormat ?? this.calendarFormat,
      eventMap: eventMap ?? this.eventMap,
    );
  }
}

class StatsController extends AsyncNotifier<StatsState> {
  final StatsManager statsManager = StatsManager();

  @override
  Future<StatsState> build() async {
    return _loadState();
  }

  Future<StatsState> _loadState() async {
    final map = await statsManager.getEventMap();
    final focused = DateTime.now();
    return StatsState(
      focusedDay: focused,
      selectedDay: focused,
      calendarFormat: CalendarFormat.month,
      eventMap: Map.of(map),
    );
  }

  DateTime get focusedDay => state.requireValue.focusedDay;
  set focusedDay(DateTime value) {
    if (focusedDay == value) return;
    state = AsyncData(state.requireValue.copyWith(focusedDay: value));
  }

  DateTime? get selectedDay => state.requireValue.selectedDay;
  set selectedDay(DateTime? value) {
    if (selectedDay == value || value == null) return;
    state = AsyncData(state.requireValue.copyWith(selectedDay: value));
  }

  CalendarFormat get calendarFormat => state.requireValue.calendarFormat;
  set calendarFormat(CalendarFormat value) {
    if (calendarFormat == value) return;
    state = AsyncData(state.requireValue.copyWith(calendarFormat: value));
  }

  Map<DateTime, List<StatsDataImpl>> get eventMap =>
      state.requireValue.eventMap;

  List<StatsDataImpl> get entriesForSelectedDay {
    return getEntriesForTimeRange(TimeRange.daily);
  }

  int get totalEventCount =>
      eventMap.values.fold(0, (sum, list) => sum + list.length);

  Future<void> loadEvents() async {
    final previous = state.asData?.value;
    state = const AsyncLoading();
    try {
      final loaded = await _loadState();
      state = AsyncData(
        loaded.copyWith(
          focusedDay: previous?.focusedDay,
          selectedDay: previous?.selectedDay,
          calendarFormat: previous?.calendarFormat,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void onDaySelected(DateTime newSelectedDay, DateTime newFocusedDay) {
    if (!isSameDay(selectedDay, newSelectedDay)) {
      selectedDay = newSelectedDay;
      focusedDay = newFocusedDay;
    }
  }

  void onPageChanged(DateTime newFocusedDay) {
    focusedDay = newFocusedDay;
  }

  void onFormatChanged(CalendarFormat format) {
    if (calendarFormat != format) {
      calendarFormat = format;
    }
  }

  void jumpToDate(DateTime targetDate) {
    focusedDay = targetDate;
    selectedDay = targetDate;
  }

  Future<void> showAnimeSourlList() async {
    final baseList = AnimeSource.allSources().map((a) => a.name).toList();

    final selectors = appdata.settings['statsSelectors'] ?? [];
    final selectorList = List<int>.from(selectors)
        .map((i) => AnimeType(i))
        .toList();

    final activeList = AnimeSource.allSources()
        .where(
          (a) => selectorList.any(
            (t) => t.value == AnimeType.fromKey(a.name).value,
          ),
        )
        .map((a) => a.name)
        .toList();
    showDialog(
      context: App.rootContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              title: t.statsSourceList,
              content: SizedBox(
                width: double.maxFinite,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: baseList.map((item) {
                    final isActive = activeList.contains(item);

                    return InputChip(
                      label: Text(item),
                      selected: isActive,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            activeList.add(item);
                          } else {
                            activeList.remove(item);
                          }
                        });
                      },
                      backgroundColor: Colors.black.toOpacity(0.1),
                      selectedColor: Theme.of(context).colorScheme.primary
                          .toOpacity(0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                                    .toOpacity(0.7)
                              : Theme.of(context).colorScheme.primary
                                    .withAlpha(30),
                        ),
                      ),
                      showCheckmark: true,
                    );
                  }).toList(),
                ),
              ),
              actions: [
                FilledButton(
                  child: Text(t.apply),
                  onPressed: () async {
                    final selectedInts = activeList
                        .map((name) => AnimeType.fromKey(name).value)
                        .toList();

                    appdata.settings['statsSelectors'] = selectedInts;
                    appdata.saveData();
                    await loadEvents();
                    App.pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<StatsDataImpl> getEventsForDay(DateTime day) {
    final matchEntry = eventMap.entries.firstWhere(
      (e) => isSameDay(e.key, day),
      orElse: () => MapEntry(day, <StatsDataImpl>[]),
    );

    // 滤除相同 bangumiId 的条目
    final Map<int?, StatsDataImpl> uniqueEvents = {};
    for (final event in matchEntry.value) {
      if (event.bangumiId != null) {
        if (!uniqueEvents.containsKey(event.bangumiId)) {
          uniqueEvents[event.bangumiId] = event;
        }
      } else {
        // 对于没有 bangumiId 的条目，使用 id 作为键
        uniqueEvents[event.hashCode] = event;
      }
    }

    return uniqueEvents.values.toList();
  }

  List<StatsDataImpl> getEntriesForTimeRange(TimeRange timeRange) {
    final selected = selectedDay ?? focusedDay;

    final entries = eventMap.entries
        .where((entry) {
          switch (timeRange) {
            case TimeRange.daily:
              return isSameDay(entry.key, selected);
            case TimeRange.weekly:
              return Utils.isSameWeek(entry.key, selected);
            case TimeRange.monthly:
              return Utils.isSameMonth(entry.key, selected);
            case TimeRange.quarterly:
              return Utils.isSameQuarter(entry.key, selected);
            case TimeRange.halfYearly:
              return Utils.isSameHalfYear(entry.key, selected);
            case TimeRange.yearly:
              return Utils.isSameYear(entry.key, selected);
          }
        })
        .expand((e) => e.value)
        .toList();

    final timeCache = <StatsDataImpl, DateTime>{};
    for (final entry in entries) {
      timeCache[entry] = _getLatestActivityTime(entry, selected);
    }

    return entries..sort((a, b) {
      return timeCache[b]!.compareTo(timeCache[a]!);
    });
  }

  DateTime _getLatestActivityTime(StatsDataImpl stat, DateTime selectedDate) {
    DateTime latestTime = DateTime.fromMillisecondsSinceEpoch(0);

    void updateLatest(List<DailyEvent> events) {
      for (final event in events) {
        if (isSameDay(event.date, selectedDate)) {
          for (final record in event.platformEventRecords) {
            if (record.date != null && record.date!.isAfter(latestTime)) {
              latestTime = record.date!;
            }
          }
        }
      }
    }

    updateLatest(stat.totalClickCount);
    updateLatest(stat.totalWatchDurations);
    updateLatest(stat.comment);
    updateLatest(stat.rating);
    updateLatest(stat.favorite);

    return latestTime;
  }
}

final statsControllerProvider =
    AsyncNotifierProvider<StatsController, StatsState>(StatsController.new);
