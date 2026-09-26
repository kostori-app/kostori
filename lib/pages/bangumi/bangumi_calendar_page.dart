import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/calendar_screenshot_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/init.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/utils.dart';

Future<List<List<BangumiItem>>> loadBangumiCalendar({
  bool isFetchEpisodes = true,
  bool fetchEpisodeInfo = true,
  List<int>? days,
}) async {
  try {
    final manager = providerContainer.read(bangumiManagerProvider);
    if (isFetchEpisodes) {
      // 一次性清理：旧版本会把补全条目（含已完结旧番/未放送番）写进日历缓存，
      // 而 getCalendarData 当天已拉取时会跳过、不会清表，导致坏卡片一直残留。
      // 这里清空日历表并重置拉取时间，强制重新拉取一次。
      // V4：改为不再把补全条目写回日历表（见下方补全逻辑），故再清一次历史坏行。
      if (appdata.implicitData['bangumiCalendarPurgedV4'] != true) {
        await manager.clearBangumiCalendar();
        appdata.settings['getCalendarDataTime'] = '';
        appdata.saveData();
        appdata.implicitData['bangumiCalendarPurgedV4'] = true;
        appdata.writeImplicitData();
      }
      // V5：改用 allEpInfo 判定完结，触发一次全量重新补全
      if (appdata.implicitData['bangumiCalendarPurgedV5'] != true) {
        await manager.clearBangumiCalendar();
        appdata.implicitData['bangumiCalendarSkipIds'] = <int>[];
        appdata.settings['getCalendarDataTime'] = '';
        appdata.settings['getBangumiAllEpInfoTime'] = null;
        appdata.saveData();
        appdata.implicitData['bangumiCalendarPurgedV5'] = true;
        appdata.writeImplicitData();
      }
      await Bangumi.instance.getCalendarData();
      await Bangumi.instance.checkBangumiData();
    }
    // 默认全周；主页只取当天时传 days: [today]
    final targetDays = days ?? const [1, 2, 3, 4, 5, 6, 7];
    // 清掉旧版本遗留的坏占位行（标题为原始 JSON）
    await manager.cleanupBrokenCalendarRows();
    final allItems = await manager.getWeeks(targetDays);
    // bgm /calendar 当季 API 来源的 id：bgm 认定其当季在播，直接信任。
    // 其余（bangumi-data 补全 / binding 缓存）可能实为他国语言重播、
    // 或早已完结的旧番（其 begin 因他国开播而显得"近期"），需按条目
    // 自身 air_date + 话数复核（见 _isLikelyFinished）。
    final apiIds = allItems.map((item) => item.id).toSet();

    // 补全：bangumi_data 表（全量）中日历表缺失的近期条目。
    // 窗口取 210 天覆盖半年番（bangumi-data 的 end 对这类番常只标第一季）。
    final supplement = await manager.getAllBangumiDataEntries();
    final existingIds = allItems.map((item) => item.id).toSet();
    final beginWindow = DateTime.now().subtract(const Duration(days: 210));
    final recentIds = supplement.entries
        .where((e) {
          final begin = DateTime.tryParse(e.value.begin ?? '');
          if (begin == null) return false;
          if (!targetDays.contains(begin.weekday)) return false;
          // 未放送：开播日在未来（留 1 天余量，避免误伤当天/次日深夜档首播）
          if (begin.isAfter(DateTime.now().add(const Duration(days: 1)))) {
            return false;
          }
          return begin.isAfter(beginWindow);
        })
        .map((e) => e.key);
    // 曾补全失败/脏数据（日期对不上、拿不到条目）的 id 记下来，不再反复请求
    final skipRaw = appdata.implicitData['bangumiCalendarSkipIds'];
    final skipIds = <int>{
      if (skipRaw is List) ...skipRaw.whereType<num>().map((e) => e.toInt()),
    };
    final newSkipIds = <int>{};
    final missingIds = recentIds
        .where((id) => !existingIds.contains(id) && !skipIds.contains(id))
        .toList();
    // 已缓存过详情（binding 表）的条目直接拿来用，不再请求网络
    if (missingIds.isNotEmpty) {
      final cachedItems = <BangumiItem>[];
      for (final id in List<int>.from(missingIds)) {
        final cached = await manager.getBangumiItem(id);
        if (cached == null) continue;
        missingIds.remove(id);
        cachedItems.add(cached);
      }
      for (final item in cachedItems) {
        existingIds.add(item.id);
        allItems.add(item);
      }
    }

    final supplementToCache = <BangumiItem>[];
    if (missingIds.isNotEmpty) {
      const batchSize = 5;
      for (var i = 0; i < missingIds.length; i += batchSize) {
        final batch = missingIds.sublist(
          i,
          (i + batchSize).clamp(0, missingIds.length),
        );
        final fetched = await Future.wait(
          batch.map((id) => Bangumi.instance.getBangumiInfoByID(id)),
        );
        for (var j = 0; j < batch.length; j++) {
          final id = batch[j];
          final basic = supplement[id]!;
          final info = fetched[j];
          // 临时失败不记入跳过名单，下次重试
          if (info == null) continue;
          final begin = DateTime.tryParse(basic.begin ?? '');
          // bangumi-data 的 begin 有时与实际档期不符（如把 2023 旧番标成 2026）。
          // 与 bgm 条目自身首播日相差过大时视为脏数据，跳过补全。
          final infoAir = DateTime.tryParse(info.airDate);
          final tooOld =
              infoAir != null &&
              infoAir.isBefore(
                DateTime.now().subtract(const Duration(days: 400)),
              );
          if (tooOld ||
              (begin != null &&
                  infoAir != null &&
                  begin.difference(infoAir).inDays.abs() > 180)) {
            // 过期条目 / 脏数据：跳过并记住，否则下次还会把它当"缺失条目"再请求
            newSkipIds.add(id);
            continue;
          }
          // 补全成功：解除历史跳过
          skipIds.remove(id);
          final item = begin != null
              ? info.copyWith(airTime: basic.begin, airWeekday: begin.weekday)
              : info;
          allItems.add(item);
          supplementToCache.add(item);
        }
      }
      // 只写入 binding 表缓存详情，不再写回日历表：
      // 补全条目按需在内存中合成并已做日期窗过滤，避免过期/未放送条目
      // 长期留在 bangumi_calendar 里、每次 getWeeks 都被当成当季番重复显示。
      try {
        for (final item in supplementToCache) {
          await manager.addBangumiBinding(item);
        }
      } catch (e, s) {
        Log.warning('补全binding缓存', '$e\n$s');
      }
      // 持久化跳过集合（成功解除的已从 skipIds 移除）
      skipIds.addAll(newSkipIds);
      appdata.implicitData['bangumiCalendarSkipIds'] = skipIds.toList();
      appdata.writeImplicitData();
    }

    final allIds = allItems.map((item) => item.id.toString()).toList();
    final existenceMap = await manager.checkWhetherDataExistsBatch(allIds);

    final validItems = allItems
        .where((item) => existenceMap.containsKey(item.id.toString()))
        .toList();

    final fetchEpisodes = appdata.settings['calendarFetchEpisodes'] ?? false;
    final shouldFetchEpisodes =
        fetchEpisodes && isFetchEpisodes && fetchEpisodeInfo;

    final now = DateTime.now();
    final currentWeekInfo = Utils.getISOWeekNumber(now);

    // 缺 end / end 已过的条目优先用 allEpInfo 复核，取不到才回退 end
    final endCheckItems = validItems.where((it) {
      final end = existenceMap[it.id.toString()]?.end;
      if (end == null || end.isEmpty) return true;
      final endDate = DateTime.tryParse(end);
      return endDate == null || !endDate.isAfter(now);
    }).toList();

    Map<int, List<EpisodeInfo>> allEpisodesMap;
    Map<int, int> seriesTotalMap;
    if (shouldFetchEpisodes) {
      final r = await _fetchEpisodesInBatches(validItems);
      allEpisodesMap = r.$1;
      seriesTotalMap = r.$2;
    } else if (endCheckItems.isNotEmpty && isFetchEpisodes) {
      // 主页（fetchEpisodeInfo=false）也拉一次，按天节流
      final r = await _fetchEpisodesInBatches(endCheckItems);
      allEpisodesMap = r.$1;
      seriesTotalMap = r.$2;
    } else if (endCheckItems.isNotEmpty) {
      final r = await _readCachedEpisodes(endCheckItems);
      allEpisodesMap = r.$1;
      seriesTotalMap = r.$2;
    } else {
      allEpisodesMap = <int, List<EpisodeInfo>>{};
      seriesTotalMap = <int, int>{};
    }

    final newCalendar = List.generate(7, (_) => <BangumiItem>[]);

    for (final item in validItems) {
      final entry = existenceMap[item.id.toString()]!;
      final airTimeStr = entry.begin ?? item.airTime;
      if (airTimeStr == null) continue;

      try {
        final parsedTime = parseBangumiAirTime(airTimeStr);
        if (parsedTime == null) continue;
        // 未放送：首播日在未来（1 天余量同上），直接跳过
        if (parsedTime.isAfter(now.add(const Duration(days: 1)))) continue;
        final episodes = allEpisodesMap[item.id];
        final hasEpisodes = episodes != null && episodes.isNotEmpty;
        // 无剧集信息时才用 air_date + 话数估算，过滤他国重播/旧番
        if (!hasEpisodes &&
            !apiIds.contains(item.id) &&
            _isLikelyFinished(item, now)) {
          continue;
        }
        final weekday = parsedTime.weekday;

        // 有剧集信息时按实际播出判定，否则回退 end
        EpisodeResult? episodeResult;
        if (hasEpisodes) {
          episodeResult = await _processEpisodeInfo(
            episodes: episodes,
            now: now,
            currentWeekInfo: currentWeekInfo,
            bangumiItem: item,
            seriesTotal: seriesTotalMap[item.id] ?? 0,
          );
        }
        episodeResult ??= EpisodeResult.fromEndDate(entry.end);

        if (episodeResult.shouldSkip) continue;

        newCalendar[weekday - 1].add(
          item.copyWith(airTime: airTimeStr, extraInfo: episodeResult),
        );
      } catch (e, s) {
        Log.error('处理番剧时间', 'ID:${item.id}, 时间:$airTimeStr\n$e\n$s');
      }
    }

    _sortCalendarByTime(newCalendar);
    return newCalendar;
  } catch (e, s) {
    Log.error('处理番剧日历', '$e\n$s');
    return List.generate(7, (_) => <BangumiItem>[]);
  }
}

Future<EpisodeResult?> _processEpisodeInfo({
  required List<EpisodeInfo>? episodes,
  required DateTime now,
  required (int, int) currentWeekInfo,
  required BangumiItem bangumiItem,
  required int seriesTotal,
}) async {
  if (episodes == null || episodes.isEmpty) return null;

  final (_, currentWeek) = currentWeekInfo;
  final type0Episodes = episodes.where((ep) => ep.type == 0).toList();
  if (type0Episodes.isEmpty) return null;

  final currentWeekEp = await BangumiUtils.findCurrentWeekEpisode(
    episodes,
    bangumiItem,
    true,
  );

  final effectiveTotal = seriesTotal > 0
      ? seriesTotal
      : bangumiItem.totalEpisodes;

  return resolveEpisodeResult(
    type0Episodes: type0Episodes,
    currentEpisode: currentWeekEp.values.first,
    seriesTotal: effectiveTotal,
    now: now,
    currentWeek: currentWeek,
  );
}

/// 按条目自身首播日 + 总话数估算是否早已播完（按周更，末话后再留 2 周缓冲）。
/// 用于过滤 bangumi-data 补全里的「他国语言重播 / 早已完结旧番」：
/// 这类条目的 begin 可能因他国开播而显得近期，但 bgm 条目自身 air_date 很旧。
/// 集数未知（0）或日期无法解析时返回 false，交由当季 API / 其他窗口逻辑背书。
bool _isLikelyFinished(BangumiItem item, DateTime now) {
  final start = DateTime.tryParse(item.airDate);
  final eps = item.totalEpisodes;
  if (start == null || eps <= 0) return false;
  final expectedEnd = start.add(Duration(days: (eps - 1) * 7 + 14));
  return now.isAfter(expectedEnd);
}

void _sortCalendarByTime(List<List<BangumiItem>> calendar) {
  for (final dayList in calendar) {
    dayList.sort((a, b) => _compareTimeStrings(a.airTime, b.airTime));
  }
}

int _compareTimeStrings(String? a, String? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return _parseTime(a).compareTo(_parseTime(b));
}

DateTime _parseTime(String timeStr) {
  try {
    final dt = DateTime.parse(timeStr).toLocal();
    return DateTime(2000, 1, 1, dt.hour, dt.minute);
  } catch (_) {
    return DateTime(2000, 1, 1);
  }
}

typedef _EpisodeBatch = (Map<int, List<EpisodeInfo>>, Map<int, int>);

/// 系列总话数优先取接口 total，缺失时回退条目字段（仍为 0 则不判定完结）。
int _resolveSeriesTotal(int? apiTotal, BangumiItem item) {
  if (apiTotal != null && apiTotal > 0) return apiTotal;
  return item.totalEpisodes;
}

Future<_EpisodeBatch> _fetchEpisodesInBatches(List<BangumiItem> items) async {
  final episodes = <int, List<EpisodeInfo>>{};
  final totals = <int, int>{};
  const batchSize = 10;
  final nowStr = Utils.formatDate(DateTime.now());
  final needsUpdate = appdata.settings['getBangumiAllEpInfoTime'] != nowStr;

  if (needsUpdate) {
    for (var i = 0; i < items.length; i += batchSize) {
      final batch = items.sublist(i, (i + batchSize).clamp(0, items.length));
      try {
        final r = await _fetchBatchEpisodes(batch, needsUpdate: needsUpdate);
        episodes.addAll(r.$1);
        totals.addAll(r.$2);
      } catch (e, s) {
        Log.error('获取剧集批次${i ~/ batchSize + 1}失败', '$e\n$s');
      }
    }
    appdata.settings['getBangumiAllEpInfoTime'] = nowStr;
    appdata.saveData();
  } else {
    final r = await _fetchBatchEpisodes(items, needsUpdate: needsUpdate);
    episodes.addAll(r.$1);
    totals.addAll(r.$2);
  }

  return (episodes, totals);
}

Future<_EpisodeBatch> _readCachedEpisodes(List<BangumiItem> items) async {
  final episodes = <int, List<EpisodeInfo>>{};
  final totals = <int, int>{};
  final manager = providerContainer.read(bangumiManagerProvider);
  for (final item in items) {
    try {
      final (list, apiTotal) = await manager.allEpInfoFindWithTotal(item.id);
      if (list.isEmpty) continue;
      episodes[item.id] = list;
      final total = _resolveSeriesTotal(apiTotal, item);
      if (total > 0) totals[item.id] = total;
    } catch (_) {}
  }
  return (episodes, totals);
}

Future<_EpisodeBatch> _fetchBatchEpisodes(
  List<BangumiItem> batch, {
  required bool needsUpdate,
}) async {
  final episodes = <int, List<EpisodeInfo>>{};
  final totals = <int, int>{};
  final manager = providerContainer.read(bangumiManagerProvider);
  await Future.wait(
    batch.map((item) async {
      try {
        List<EpisodeInfo> list;
        int? apiTotal;
        if (needsUpdate) {
          (list, apiTotal) = await Bangumi.instance
              .getBangumiEpisodeAllWithTotalByID(item.id);
        } else {
          (list, apiTotal) = await manager.allEpInfoFindWithTotal(item.id);
        }
        if (list.isEmpty) return;
        episodes[item.id] = list;
        final total = _resolveSeriesTotal(apiTotal, item);
        if (total > 0) totals[item.id] = total;
      } catch (e, s) {
        Log.warning('_fetchBatchEpisodes', '${item.id}: $e\n$s');
      }
    }),
  );

  return (episodes, totals);
}

/// 解析 bangumi 播出时间（支持深夜番 `25:00` 等超过 24 点的时间，
/// 会进位到次日，如 `2026-08-17 25:00` → 2026-08-18 01:00）
DateTime? parseBangumiAirTime(String str) {
  final t = DateTime.tryParse(str);
  if (t != null) return t.toLocal();
  final m = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(str);
  if (m == null) return null;
  return DateTime(
    int.parse(m[1]!),
    int.parse(m[2]!),
    int.parse(m[3]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
    int.parse(m[6] ?? '0'),
  ).toLocal();
}

class BangumiCalendarPage extends ConsumerStatefulWidget {
  const BangumiCalendarPage({super.key});

  @override
  ConsumerState<BangumiCalendarPage> createState() =>
      _BangumiCalendarPageState();
}

class _BangumiCalendarPageState extends ConsumerState<BangumiCalendarPage>
    with SingleTickerProviderStateMixin {
  TabController? controller;
  List<List<BangumiItem>> bangumiCalendar = [];
  bool _isLoading = true;
  BangumiManager get manager => ref.watch(bangumiManagerProvider);

  @override
  void initState() {
    super.initState();
    controller = TabController(
      vsync: this,
      length: 7,
      initialIndex: DateTime.now().weekday - 1,
    );
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final newCalendar = await loadBangumiCalendar();
      if (mounted) setState(() => bangumiCalendar = newCalendar);
      // 后台预取封面到本地缓存，避免显示时逐张网络加载
      unawaited(_precacheImages(newCalendar));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 批量下载封面图片到本地缓存（仅未缓存的会走网络）
  Future<void> _precacheImages(List<List<BangumiItem>> calendar) async {
    final urls = calendar
        .expand((day) => day)
        .map((item) => item.images['large'])
        .whereType<String>()
        .toSet()
        .toList();
    const batchSize = 6;
    for (var i = 0; i < urls.length; i += batchSize) {
      final batch = urls.sublist(i, (i + batchSize).clamp(0, urls.length));
      await Future.wait(
        batch.map((url) async {
          try {
            await precacheImage(
              CachedImageProvider(url, sourceKey: 'bangumi'),
              context,
            );
          } catch (_) {}
        }),
      );
    }
  }

  /// 全部番剧数量（一周总和）
  int _allCount() {
    return bangumiCalendar.fold<int>(0, (sum, day) => sum + day.length);
  }

  List<String> getTabs() {
    final currentDate = DateTime.now();
    return List.generate(7, (i) {
      final weekday = currentDate.add(
        Duration(days: i - currentDate.weekday + 1),
      );
      final formattedDate = t.calDateDay(
        month: weekday.month,
        day: weekday.day,
      );
      final dayOfWeek = switch (weekday.weekday) {
        1 => t.monday,
        2 => t.tuesday,
        3 => t.wednesday,
        4 => t.thursday,
        5 => t.friday,
        6 => t.saturday,
        7 => t.sunday,
        _ => '',
      };

      return '$formattedDate $dayOfWeek';
    });
  }

  String _extractTimeFromISO(String isoTime) {
    try {
      return DateFormat('HH:mm').format(DateTime.parse(isoTime).toLocal());
    } catch (e, s) {
      Log.warning('时间解析', '$e\n$s');
      return '00:00';
    }
  }

  Widget _buildCurrentTimeDivider(DateTime currentTime) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: constraints.maxWidth * 0.06,
                color: Theme.of(context).colorScheme.primary,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  DateFormat('HH:mm').format(currentTime),
                  style: TextStyle(
                    fontSize: constraints.maxWidth * 0.07,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Theme.of(context).colorScheme.primary,
                  thickness: constraints.maxWidth * 0.005,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> contentList(
    List<List<BangumiItem>> bangumiCalendar,
    Orientation orientation,
  ) {
    final now = DateTime.now().toLocal();
    final currentTimeStr = DateFormat('HH:mm').format(now);
    final currentWeekday = now.weekday;

    return List.generate(7, (weekdayIndex) {
      final bangumiList = bangumiCalendar[weekdayIndex];
      if (bangumiList.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                t.calNoAnimeToday,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }

      final weekday = weekdayIndex + 1;
      final shouldInsertDivider = weekday == currentWeekday;

      int lastPastIndex = -1;
      if (shouldInsertDivider) {
        for (int i = 0; i < bangumiList.length; i++) {
          final item = bangumiList[i];
          if (item.airTime == null) continue;
          try {
            if (_extractTimeFromISO(item.airTime!).compareTo(currentTimeStr) <
                0) {
              lastPastIndex = i;
            }
          } catch (e, s) {
            Log.error('时间解析', '$e\n$s');
          }
        }
      }

      return CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (shouldInsertDivider && index == lastPastIndex + 1) {
                  return _buildCurrentTimeDivider(now);
                }

                final adjustedIndex =
                    shouldInsertDivider && index > lastPastIndex
                    ? index - 1
                    : index;

                if (adjustedIndex >= bangumiList.length) return null;

                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => App.mainNavigatorKey?.currentContext?.to(
                    () => BangumiInfoPage(
                      bangumiItem: bangumiList[adjustedIndex],
                      heroTag: 'Timetable',
                    ),
                  ),
                  child: _BangumiCalendarCard(
                    bangumiItem: bangumiList[adjustedIndex],
                  ),
                );
              },
              childCount: shouldInsertDivider
                  ? bangumiList.length + 1
                  : bangumiList.length,
            ),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.pop();
          },
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: Scaffold(
              appBar: Appbar(
                title: Text(
                  t.timetableCount(timetable: t.timetable, count: _allCount()),
                ),
                actions: [
                  IconButton(
                    onPressed: () {
                      appdata.settings['getBangumiAllEpInfoTime'] = null;
                      appdata.saveData();
                      setState(() {
                        _isLoading = true;
                        _initializeData();
                      });
                    },
                    icon: const Icon(Icons.restart_alt),
                    tooltip: t.calRefreshStatus,
                  ),
                  IconButton(
                    onPressed: () => captureBangumiCalendarScreenshot(
                      context,
                      bangumiCalendar,
                    ),
                    icon: const Icon(Icons.share),
                    tooltip: t.calScreenshotSave,
                  ),
                ],
                bottom: CapsuleTabBar(
                  controller: controller,
                  labels: getTabs(),
                ),
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PolygonRefreshIndicator(size: 100),
                                const SizedBox(height: 16),
                                Text(
                                  t.calLoadingSchedule,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          )
                        : bangumiCalendar.isNotEmpty
                        ? TabBarView(
                            controller: controller,
                            children: contentList(bangumiCalendar, orientation),
                          )
                        : Center(child: Text(t.calDataNotUpdated)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BangumiCalendarCard extends StatelessWidget {
  const _BangumiCalendarCard({required this.bangumiItem});

  final BangumiItem bangumiItem;

  Widget _buildCover(
    BuildContext context,
    ColorScheme colorScheme,
    double imageWidth,
    double imageHeight,
  ) {
    final imageUrl =
        bangumiItem.images['large'] ??
        bangumiItem.images['common'] ??
        bangumiItem.images['medium'] ??
        '';
    if (imageUrl.isEmpty) {
      // 补全条目接口失败时无图，显示占位
      return Container(
        width: imageWidth,
        height: imageHeight,
        color: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.movie_outlined, size: 36, color: colorScheme.outline),
      );
    }
    return BangumiWidget.kostoriImage(
      context,
      imageUrl,
      width: imageWidth,
      height: imageHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = constraints.maxWidth * 5 / 16;
          final imageWidth = imageHeight * 0.72;

          return SizedBox(
            height: constraints.maxWidth * 7 / 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Utils.buildTimeIndicator(bangumiItem.airTime, imageHeight),
                SizedBox(
                  height: imageHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: KostoriHero(
                          tag: 'Timetable-${bangumiItem.id}',
                          child: _buildCover(
                            context,
                            Theme.of(context).colorScheme,
                            imageWidth,
                            imageHeight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CardInfo(
                          bangumiItem: bangumiItem,
                          imageWidth: imageWidth,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardInfo extends StatelessWidget {
  const _CardInfo({required this.bangumiItem, required this.imageWidth});

  final BangumiItem bangumiItem;
  final double imageWidth;

  String get _episodeName {
    final cn = bangumiItem.extraInfo?.episodeNameCn;
    final name = bangumiItem.extraInfo?.episodeName ?? '';
    return (cn == null || cn.isEmpty) ? name : cn;
  }

  @override
  Widget build(BuildContext context) {
    final title = bangumiItem.nameCn.isNotEmpty
        ? bangumiItem.nameCn
        : bangumiItem.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: imageWidth * 0.12,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        if (bangumiItem.name.isNotEmpty &&
            bangumiItem.name != bangumiItem.nameCn)
          Text(
            bangumiItem.name,
            style: TextStyle(
              fontSize: imageWidth * 0.08,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (appdata.settings['calendarFetchEpisodes'] ?? false)
          Text(
            '${t.episodeEp(ep: bangumiItem.extraInfo?.episodeEp?.toCleanString() ?? 0)}: $_episodeName',
            style: TextStyle(fontSize: imageWidth * 0.11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        const Spacer(),
        _ScoreRow(bangumiItem: bangumiItem, imageWidth: imageWidth),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.bangumiItem, required this.imageWidth});

  final BangumiItem bangumiItem;
  final double imageWidth;

  @override
  Widget build(BuildContext context) {
    final ratingBar = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RatingBarIndicator(
          itemCount: 5,
          rating: bangumiItem.score.toDouble() / 2,
          itemBuilder: (_, _) => const Icon(Icons.star_rounded),
          itemSize: imageWidth * 0.14,
        ),
        Text(
          t.tReviewsR(t: bangumiItem.total, r: bangumiItem.rank),
          style: TextStyle(fontSize: imageWidth * 0.1),
        ),
      ],
    );

    if (bangumiItem.total < 20) return ratingBar;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${bangumiItem.score}',
          style: TextStyle(fontSize: imageWidth * 0.16),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.toOpacity(0.72),
            ),
          ),
          child: Text(
            Utils.getRatingLabel(bangumiItem.score),
            style: TextStyle(fontSize: imageWidth * 0.12),
          ),
        ),
        const SizedBox(width: 4),
        ratingBar,
      ],
    );
  }
}

class _ScreenshotPreviewSheet extends StatefulWidget {
  const _ScreenshotPreviewSheet({
    super.key,
    required this.bangumiCalendar,
    required this.captureTime,
    required this.scrollController,
  });

  final List<List<BangumiItem>> bangumiCalendar;
  final DateTime captureTime;
  final ScrollController scrollController;

  @override
  State<_ScreenshotPreviewSheet> createState() =>
      _ScreenshotPreviewSheetState();
}

class _ScreenshotPreviewSheetState extends State<_ScreenshotPreviewSheet> {
  bool _showWeekly = true; // true = 本周，false = 今天

  List<List<BangumiItem>> get _todayCalendar {
    final todayIndex = widget.captureTime.weekday - 1;
    return List.generate(
      7,
      (i) => i == todayIndex ? widget.bangumiCalendar[i] : [],
    );
  }

  void popWithValue() {
    Navigator.pop(context, _showWeekly ? 'weekly' : 'today');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 切换按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(t.calThisWeek),
                icon: Icon(Icons.calendar_view_week),
              ),
              ButtonSegment(
                value: false,
                label: Text(t.calToday),
                icon: Icon(Icons.today),
              ),
            ],
            selected: {_showWeekly},
            onSelectionChanged: (val) =>
                setState(() => _showWeekly = val.first),
          ),
        ),
        const Divider(height: 1),
        // 预览内容
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: CalendarScreenshotWidget(
                bangumiCalendar: _showWeekly
                    ? widget.bangumiCalendar
                    : _todayCalendar,
                captureTime: widget.captureTime,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<Uint8List?> generateBangumiCalendarPng({
  required BuildContext context,
  required List<List<BangumiItem>> bangumiCalendar,
  required DateTime captureTime,
  required bool showWeekly,
}) async {
  final overlayState = context.findAncestorStateOfType<OverlayWidgetState>();
  if (overlayState == null) {
    Log.error('截图失败', '未找到 OverlayWidgetState');
    return null;
  }

  final todayIndex = captureTime.weekday - 1;
  // 数据未加载完全时（为空或不足 7 天）补空行，避免越界/空列表崩溃
  final calendarToCapture = List<List<BangumiItem>>.generate(7, (i) {
    if (showWeekly) {
      return i < bangumiCalendar.length
          ? bangumiCalendar[i]
          : const <BangumiItem>[];
    }
    return i == todayIndex && todayIndex < bangumiCalendar.length
        ? bangumiCalendar[i]
        : const <BangumiItem>[];
  });

  final repaintKey = GlobalKey();
  final screenshotWidget = RepaintBoundary(
    key: repaintKey,
    child: MediaQuery(
      data: MediaQuery.of(context),
      child: Theme(
        data: Theme.of(context),
        child: CalendarScreenshotWidget(
          bangumiCalendar: calendarToCapture,
          captureTime: captureTime,
        ),
      ),
    ),
  );

  final renderEntry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      child: SizedBox(width: 800, child: screenshotWidget),
    ),
  );
  overlayState.addOverlay(renderEntry);

  try {
    await Future.delayed(const Duration(milliseconds: 1000));
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      Log.error('截图失败', 'RenderRepaintBoundary 为空');
      return null;
    }

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  } catch (e, s) {
    Log.error('截图失败', '$e\n$s');
    return null;
  } finally {
    overlayState.remove(renderEntry);
  }
}

Future<void> captureBangumiCalendarScreenshot(
  BuildContext context,
  List<List<BangumiItem>> bangumiCalendar,
) async {
  final overlayState = context.findAncestorStateOfType<OverlayWidgetState>();
  OverlayEntry? loadingEntry;

  void showLoading(String message) {
    loadingEntry?.remove();
    loadingEntry = OverlayEntry(
      builder: (_) => LoadingOverlay(message: message),
    );
    overlayState?.addOverlay(loadingEntry!);
  }

  void removeLoading() {
    if (loadingEntry != null) {
      overlayState?.remove(loadingEntry!);
      loadingEntry = null;
    }
  }

  try {
    showLoading(t.calLoadingImage);

    final imageUrls = bangumiCalendar
        .expand((day) => day)
        .map((item) => item.images['large'])
        .whereType<String>()
        .toSet()
        .toList();

    const batchSize = 8;
    for (var i = 0; i < imageUrls.length; i += batchSize) {
      final batch = imageUrls.sublist(
        i,
        (i + batchSize).clamp(0, imageUrls.length),
      );
      await Future.wait(
        batch.map((url) async {
          try {
            await precacheImage(
              CachedImageProvider(url, sourceKey: 'bangumi'),
              context,
            );
          } catch (_) {}
        }),
      );
    }

    removeLoading();

    if (!context.mounted) return;

    final captureTime = DateTime.now();
    final previewKey = GlobalKey<_ScreenshotPreviewSheetState>();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Sheet(
        title: t.calScreenshotPreview,
        icon: Icons.screenshot_outlined,
        initialSize: 0.6,
        headerTrailing: CapsuleButton(
          primary: true,
          leading: const Icon(Icons.save_alt, size: 18),
          text: t.save,
          onTap: () => previewKey.currentState?.popWithValue(),
        ),
        builder: (ctx, sc) => _ScreenshotPreviewSheet(
          key: previewKey,
          scrollController: sc,
          bangumiCalendar: bangumiCalendar,
          captureTime: captureTime,
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    showLoading(t.calGeneratingScreenshot);

    final bytes = await generateBangumiCalendarPng(
      context: context,
      bangumiCalendar: bangumiCalendar,
      captureTime: captureTime,
      showWeekly: result == 'weekly',
    );

    removeLoading();

    if (bytes == null) {
      if (context.mounted) {
        ImageSaver.showResult(success: false, message: t.screenshotFailed);
      }
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (context.mounted) {
      await ImageSaver.saveImage(
        bytes: bytes,
        filename: result == 'weekly'
            ? 'timetable_weekly_$timestamp.png'
            : 'timetable_today_$timestamp.png',
      );
    }
  } catch (e) {
    removeLoading();
    if (context.mounted) {
      ImageSaver.showResult(success: false, message: t.screenshotFailed);
    }
    Log.error('截图失败', '$e');
  }
}
