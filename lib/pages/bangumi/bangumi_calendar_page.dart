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
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
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
    if (isFetchEpisodes) {
      await Bangumi.instance.getCalendarData();
      await Bangumi.instance.checkBangumiData();
    }
    // 默认全周；主页只取当天时传 days: [today]
    final targetDays = days ?? const [1, 2, 3, 4, 5, 6, 7];
    final manager = providerContainer.read(bangumiManagerProvider);
    final allItems = await manager.getWeeks(targetDays);

    // 补全：bangumi_data 表（全量）中日历表缺失的近期条目。
    // 仅补最近 ~12 个月内开播的（覆盖当季 + 半年番），避免对历史数据大量请求；
    // 补全成功写回本地日历表，下次直接读取，不再重复请求接口。
    final supplement = await manager.getAllBangumiDataEntries();
    final existingIds = allItems.map((item) => item.id).toSet();
    // 仅补全「近期在播或刚完结」且播放日在目标天内的条目
    final recentIds = supplement.entries
        .where((e) {
          final begin = DateTime.tryParse(e.value.begin ?? '');
          if (begin == null) return false;
          if (!targetDays.contains(begin.weekday)) return false;
          // 开始时间在最近 12 个月内
          if (!begin.isAfter(
            DateTime.now().subtract(const Duration(days: 365)),
          )) {
            return false;
          }
          // 在播（end 为空/在未来）或最近 60 天内完结。
          // 无 end 的条目只有"近期开播"才补：开播已久仍未标 end 的多是
          // 漏标/已无更新的单集条目（周更在播番本就在 bgm 每周 API 里，
          // 不需要靠补全进来），避免旧番长期按周重复出现
          final end = DateTime.tryParse(e.value.end ?? '');
          if (end == null) {
            return begin.isAfter(
              DateTime.now().subtract(const Duration(days: 90)),
            );
          }
          return end.isAfter(DateTime.now().subtract(const Duration(days: 60)));
        })
        .map((e) => e.key);
    final missingIds = recentIds
        .where((id) => !existingIds.contains(id))
        .toList();

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
          final begin = DateTime.tryParse(basic.begin ?? '');
          var item = info;
          if (item != null && begin != null) {
            item = item.copyWith(airTime: basic.begin, airWeekday: begin.weekday);
          } else {
            // 接口失败：用 bangumi_data 基础信息占位（标题 + 时间）
            item = BangumiItem(
              id: id,
              type: 2,
              name: basic.titleTranslate ?? basic.title,
              nameCn: basic.titleTranslate ?? basic.title,
              summary: '',
              airDate: basic.begin ?? '2077',
              airWeekday: begin?.weekday ?? 0,
              rank: 0,
              total: 0,
              totalEpisodes: 0,
              score: 0,
              images: const {},
              tags: const [],
              airTime: basic.begin,
            );
          }
          allItems.add(item);
          supplementToCache.add(item);
        }
      }
      // 写回本地缓存，下次 getWeeks 直接命中，不再请求接口
      try {
        await manager.batchAddBangumiCalendar(supplementToCache);
      } catch (e, s) {
        Log.warning('补全日历缓存', '$e\n$s');
      }
    }

    final allIds = allItems.map((item) => item.id.toString()).toList();
    final existenceMap = await manager.checkWhetherDataExistsBatch(allIds);

    final validItems = allItems
        .where((item) => existenceMap.containsKey(item.id.toString()))
        .toList();

    final fetchEpisodes = appdata.settings['calendarFetchEpisodes'] ?? false;
    final shouldFetchEpisodes =
        fetchEpisodes && isFetchEpisodes && fetchEpisodeInfo;
    final allEpisodesMap = shouldFetchEpisodes
        ? await _fetchEpisodesInBatches(validItems)
        : <int, List<EpisodeInfo>>{};

    final newCalendar = List.generate(7, (_) => <BangumiItem>[]);
    final now = DateTime.now();
    final currentWeekInfo = Utils.getISOWeekNumber(now);

    for (final item in validItems) {
      final entry = existenceMap[item.id.toString()]!;
      final airTimeStr = entry.begin ?? item.airTime;
      if (airTimeStr == null) continue;

      try {
        final parsedTime = parseBangumiAirTime(airTimeStr);
        if (parsedTime == null) continue;
        final weekday = parsedTime.weekday;
        final episodes = allEpisodesMap[item.id];

        final episodeResult = shouldFetchEpisodes
            ? await _processEpisodeInfo(
                episodes: episodes,
                now: now,
                currentWeekInfo: currentWeekInfo,
                bangumiItem: item,
              )
            : EpisodeResult.fromEndDate(entry.end);

        if (episodeResult == null || episodeResult.shouldSkip) continue;

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
}) async {
  if (episodes == null || episodes.isEmpty) return null;

  final (_, currentWeek) = currentWeekInfo;
  final type0Episodes = episodes.where((ep) => ep.type == 0).toList();
  if (type0Episodes.isEmpty) return null;

  final finalEpisode = type0Episodes.last;
  final currentWeekEp = await BangumiUtils.findCurrentWeekEpisode(
    episodes,
    bangumiItem,
    true,
  );

  final currentEp = currentWeekEp.values.first;
  final airTime = Utils.safeParseDate(currentEp?.airDate);
  if (airTime == null) return null;

  final airWeek = Utils.getISOWeekNumber(airTime).$2;
  var isCurrentWeek = currentWeek == airWeek;
  if (currentWeekEp.keys.first == true && !isCurrentWeek) {
    if (currentWeek == airWeek + 1) isCurrentWeek = true;
  }

  final isFinalEpisode =
      currentEp != null && currentEp.sort == finalEpisode.sort;
  final maxSort = type0Episodes
      .map((e) => e.sort)
      .reduce((a, b) => a > b ? a : b);

  return EpisodeResult(
    episodeAirdate: currentEp?.airDate,
    episodeName: currentEp?.name,
    episodeNameCn: currentEp?.nameCn,
    episodeEp: currentEp?.sort.toDouble(),
    isCurrentWeek: isCurrentWeek,
    isFinalEpisode: isFinalEpisode,
    hasNextEpisodes: finalEpisode.sort < maxSort,
  );
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

Future<Map<int, List<EpisodeInfo>>> _fetchEpisodesInBatches(
  List<BangumiItem> items,
) async {
  final result = <int, List<EpisodeInfo>>{};
  const batchSize = 10;
  final nowStr = Utils.formatDate(DateTime.now());
  final needsUpdate = appdata.settings['getBangumiAllEpInfoTime'] != nowStr;

  if (needsUpdate) {
    for (var i = 0; i < items.length; i += batchSize) {
      final batch = items.sublist(i, (i + batchSize).clamp(0, items.length));
      try {
        result.addAll(
          await _fetchBatchEpisodes(batch, needsUpdate: needsUpdate),
        );
      } catch (e, s) {
        Log.error('获取剧集批次${i ~/ batchSize + 1}失败', '$e\n$s');
      }
    }
    appdata.settings['getBangumiAllEpInfoTime'] = nowStr;
    appdata.saveData();
  } else {
    result.addAll(await _fetchBatchEpisodes(items, needsUpdate: needsUpdate));
  }

  return result;
}

Future<Map<int, List<EpisodeInfo>>> _fetchBatchEpisodes(
  List<BangumiItem> batch, {
  required bool needsUpdate,
}) async {
  final result = <int, List<EpisodeInfo>>{};
  final manager = providerContainer.read(bangumiManagerProvider);
  await Future.wait(
    batch.map((item) async {
      try {
        DebugLog.info(
          'fetch episodes',
          'querying id=${item.id}, type=${item.id.runtimeType}',
        );
        final episodes = needsUpdate
            ? await Bangumi.instance.getBangumiEpisodeAllByID(item.id)
            : await manager.allEpInfoFind(item.id);
        DebugLog.info('fetch episodes', 'result count=${episodes.length}');
        if (episodes.isNotEmpty) result[item.id] = episodes;
      } catch (e, s) {
        Log.warning('_fetchBatchEpisodes', '${item.id}: $e\n$s');
      }
    }),
  );

  return result;
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
      final batch = urls.sublist(
        i,
        (i + batchSize).clamp(0, urls.length),
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
  }

  /// 全部番剧数量（一周总和）
  int _allCount() {
    return bangumiCalendar.fold<int>(
      0,
      (sum, day) => sum + day.length,
    );
  }

  List<Tab> getTabs() {
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

      return Tab(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formattedDate,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(dayOfWeek),
          ],
        ),
      );
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

    DebugLog.info('contentList', bangumiCalendar.length.toString());

    return List.generate(7, (weekdayIndex) {
      final bangumiList = bangumiCalendar[weekdayIndex];
      DebugLog.info('day[$weekdayIndex] count', bangumiList.length.toString());
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
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: Scaffold(
              appBar: Appbar(
                title: Text(t.timetableCount(timetable: t.timetable, count: _allCount())),
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
                bottom: TabBar(
                  controller: controller,
                  tabs: getTabs(),
                  isScrollable: true,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabAlignment: TabAlignment.center,
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
        child: Icon(
          Icons.movie_outlined,
          size: 36,
          color: colorScheme.outline,
        ),
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
                        child: Hero(
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
        headerTrailing: FilledButton.icon(
          onPressed: () => previewKey.currentState?.popWithValue(),
          icon: const Icon(Icons.save_alt, size: 18),
          label: Text(t.save),
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
      // 保存后刷新图片操作页列表，让截图出现在其中
      providerContainer.read(imagesProvider.notifier).loadImages();
    }
  } catch (e) {
    removeLoading();
    if (context.mounted) {
      ImageSaver.showResult(success: false, message: t.screenshotFailed);
    }
    Log.error('截图失败', '$e');
  }
}
