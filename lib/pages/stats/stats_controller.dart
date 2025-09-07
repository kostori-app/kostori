// ignore_for_file: library_private_types_in_public_api

import 'package:ensemble_table_calendar/ensemble_table_calendar.dart';
import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/utils/translations.dart';
import 'package:mobx/mobx.dart';

part 'stats_controller.g.dart';

class StatsController = _StatsController with _$StatsController;

abstract class _StatsController with Store {
  final StatsManager statsManager = StatsManager();

  _StatsController() {
    loadEvents();
  }

  @observable
  DateTime focusedDay = DateTime.now();

  @observable
  DateTime? selectedDay;

  @observable
  CalendarFormat calendarFormat = CalendarFormat.month;

  @observable
  bool isLoading = true;

  @observable
  ObservableMap<DateTime, List<StatsDataImpl>> eventMap = ObservableMap();

  @computed
  List<StatsDataImpl> get entriesForSelectedDay {
    final selected = selectedDay ?? focusedDay;

    final entries = eventMap.entries
        .firstWhere(
          (e) => isSameDay(e.key, selected),
          orElse: () => MapEntry(DateTime(0), <StatsDataImpl>[]),
        )
        .value;

    DateTime? latestFromDailyList(List<DailyEvent> list) {
      for (final de in list) {
        if (isSameDay(de.date, selected)) {
          DateTime? maxDt;
          for (final r in de.platformEventRecords) {
            final dt = r.date;
            if (dt != null && (maxDt == null || dt.isAfter(maxDt))) {
              maxDt = dt;
            }
          }
          return maxDt;
        }
      }
      return null;
    }

    DateTime? latestForStats(StatsDataImpl s) {
      final candidates = <DateTime?>[
        latestFromDailyList(s.comment),
        latestFromDailyList(s.totalClickCount),
        latestFromDailyList(s.totalWatchDurations),
        latestFromDailyList(s.rating),
        latestFromDailyList(s.favorite),
      ];
      DateTime? mx;
      for (final c in candidates) {
        if (c != null && (mx == null || c.isAfter(mx))) mx = c;
      }
      return mx;
    }

    return [...entries]..sort((a, b) {
      final aDt = latestForStats(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDt = latestForStats(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDt.compareTo(aDt);
    });
  }

  @computed
  int get totalEventCount =>
      eventMap.values.fold(0, (sum, list) => sum + list.length);

  @action
  Future<void> loadEvents() async {
    isLoading = true;
    final map = await statsManager.getEventMap();

    runInAction(() {
      eventMap = ObservableMap.of(map);
      selectedDay ??= focusedDay;
      isLoading = false;
    });
  }

  @action
  void onDaySelected(DateTime newSelectedDay, DateTime newFocusedDay) {
    if (!isSameDay(selectedDay, newSelectedDay)) {
      selectedDay = newSelectedDay;
      focusedDay = newFocusedDay;
    }
  }

  @action
  void onPageChanged(DateTime newFocusedDay) {
    focusedDay = newFocusedDay;
  }

  @action
  void onFormatChanged(CalendarFormat format) {
    if (calendarFormat != format) {
      calendarFormat = format;
    }
  }

  @action
  void jumpToDate(DateTime targetDate) {
    focusedDay = targetDate;
    selectedDay = targetDate;
  }

  Future<void> showAnimeSourlList() async {
    final baseList = AnimeSource.all().map((a) => a.name).toList();

    final selectors = appdata.settings['statsSelectors'] ?? [];
    final selectorList = List<int>.from(
      selectors,
    ).map((i) => AnimeType(i)).toList();

    final activeList = selectorList
        .map((t) => t.sourceKey)
        .whereType<String>()
        .toList();
    showDialog(
      context: App.rootContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              title: '选择清单',
              content: SizedBox(
                width: double.maxFinite,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: baseList.map((item) {
                    final isInactive = activeList.contains(item);

                    return InputChip(
                      label: Text(item),
                      selected: !isInactive,
                      onSelected: (selected) {
                        setState(() {
                          if (isInactive) {
                            activeList.remove(item);
                          } else {
                            activeList.add(item);
                          }
                        });
                      },
                      backgroundColor: Colors.black.toOpacity(0.1),
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primary.toOpacity(0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: isInactive
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.toOpacity(0.7)
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(30),
                        ),
                      ),
                      showCheckmark: true,
                    );
                  }).toList(),
                ),
              ),
              actions: [
                FilledButton(
                  child: Text("Apply".tl),
                  onPressed: () async {
                    final selectedAnimeTypes = activeList
                        .map((sourceKey) => AnimeType.fromKey(sourceKey))
                        .toList();

                    final selectedInts = selectedAnimeTypes
                        .map((t) => t.value)
                        .toList();

                    appdata.settings['statsSelectors'] = selectedInts;
                    appdata.saveData();
                    await loadEvents();
                    Navigator.pop(context);
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
    return matchEntry.value;
  }
}
