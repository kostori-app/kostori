import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/calendar_screenshot_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';

Future<List<List<BangumiItem>>> loadBangumiCalendar() async {
  try {
    final allItems = await BangumiManager().getWeeks([1, 2, 3, 4, 5, 6, 7]);
    final allIds = allItems.map((item) => item.id.toString()).toList();
    final existenceMap = await BangumiManager().checkWhetherDataExistsBatch(
      allIds,
    );

    final validItems = allItems
        .where((item) => existenceMap.containsKey(item.id.toString()))
        .toList();
    final fetchEpisodes = appdata.settings['calendarFetchEpisodes'] ?? false;
    final allEpisodesMap = fetchEpisodes
        ? await _fetchEpisodesInBatches(validItems)
        : <int, List<EpisodeInfo>>{};

    final newCalendar = List.generate(7, (_) => <BangumiItem>[]);
    final now = DateTime.now();
    final currentWeekInfo = Utils.getISOWeekNumber(now);

    for (final item in validItems) {
      final airTimeStr = existenceMap[item.id.toString()] ?? item.airTime;
      if (airTimeStr == null) continue;

      try {
        final airTime = DateTime.parse(airTimeStr).toLocal();
        final weekday = airTime.weekday;
        final episodes = allEpisodesMap[item.id];
        final episodeResult = await _processEpisodeInfo(
          episodes: episodes,
          now: now,
          currentWeekInfo: currentWeekInfo,
          bangumiItem: item,
        );

        if (episodeResult == null) continue;

        if (episodeResult['isFinalEpisode'] == true &&
            episodeResult['hasNextEpisodes'] == false &&
            episodeResult['isCurrentWeek'] == false) {
          continue;
        }

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

Future<Map<String, dynamic>?> _processEpisodeInfo({
  required List<EpisodeInfo>? episodes,
  required DateTime now,
  required (int, int) currentWeekInfo,
  required BangumiItem bangumiItem,
}) async {
  if (episodes == null || episodes.isEmpty) {
    return appdata.settings['calendarFetchEpisodes'] ?? false ? null : {};
  }

  final (_, currentWeek) = currentWeekInfo;
  final type0Episodes = episodes.where((ep) => ep.type == 0).toList();
  if (type0Episodes.isEmpty) return null;

  final finalEpisode = type0Episodes.last;
  final currentWeekEp = await BangumiUtils.findCurrentWeekEpisode(
    episodes,
    bangumiItem,
    true,
  );

  final isFinalEpisode =
      currentWeekEp.values.first != null &&
      currentWeekEp.values.first?.sort == finalEpisode.sort;

  final airTime = Utils.safeParseDate(currentWeekEp.values.first?.airDate);
  if (airTime == null) return null;

  final airWeek = Utils.getISOWeekNumber(airTime).$2;
  bool isCurrentWeek = currentWeek == airWeek;

  if (currentWeekEp.keys.first == true && !isCurrentWeek) {
    if (currentWeek == airWeek + 1) isCurrentWeek = true;
  }

  final maxSort = type0Episodes
      .map((e) => e.sort)
      .reduce((a, b) => a > b ? a : b);

  return {
    'episode_airdate': currentWeekEp.values.first?.airDate,
    'episode_name': currentWeekEp.values.first?.name,
    'episode_name_cn': currentWeekEp.values.first?.nameCn,
    'episode_ep': currentWeekEp.values.first?.sort,
    'isCurrentWeek': isCurrentWeek,
    'isFinalEpisode': isFinalEpisode,
    'hasNextEpisodes': finalEpisode.sort < maxSort,
  };
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
        result.addAll(await _fetchBatchEpisodes(batch));
      } catch (e, s) {
        Log.error('获取剧集批次${i ~/ batchSize + 1}失败', '$e\n$s');
      }
    }
    appdata.settings['getBangumiAllEpInfoTime'] = nowStr;
    appdata.saveData();
  } else {
    result.addAll(await _fetchBatchEpisodes(items));
  }

  return result;
}

Future<Map<int, List<EpisodeInfo>>> _fetchBatchEpisodes(
  List<BangumiItem> batch,
) async {
  final result = <int, List<EpisodeInfo>>{};
  final nowStr = Utils.formatDate(DateTime.now());
  final needsUpdate = appdata.settings['getBangumiAllEpInfoTime'] != nowStr;

  await Future.wait(
    batch.map((item) async {
      try {
        final episodes = needsUpdate
            ? await Bangumi.getBangumiEpisodeAllByID(item.id)
            : await BangumiManager().allEpInfoFind(item.id);
        if (episodes.isNotEmpty) result[item.id] = episodes;
      } catch (e, s) {
        Log.warning('批量获取剧集', '${item.id}: $e\n$s');
      }
    }),
  );

  return result;
}

class BangumiCalendarPage extends StatefulWidget {
  const BangumiCalendarPage({super.key});

  @override
  State<BangumiCalendarPage> createState() => _BangumiCalendarPageState();
}

class _BangumiCalendarPageState extends State<BangumiCalendarPage>
    with SingleTickerProviderStateMixin {
  TabController? controller;
  List<List<BangumiItem>> bangumiCalendar = [];
  bool _isLoading = true;
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Tab> getTabs() {
    final currentDate = DateTime.now();
    return List.generate(7, (i) {
      final weekday = currentDate.add(
        Duration(days: i - currentDate.weekday + 1),
      );
      final formattedDate = '${weekday.month}月${weekday.day}日';
      final dayOfWeek = _weekdays[weekday.weekday - 1].tl;

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

    return List.generate(7, (weekdayIndex) {
      final bangumiList = bangumiCalendar[weekdayIndex];
      if (bangumiList.isEmpty) {
        return const Center(child: Text('这一天没有番剧'));
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
                title: Text('Timetable'.tl),
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
                    tooltip: '刷新状态',
                  ),
                  IconButton(
                    onPressed: () => captureBangumiCalendarScreenshot(
                      context,
                      bangumiCalendar,
                    ),
                    icon: const Icon(Icons.share),
                    tooltip: '截图保存',
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
                                  '正在加载时间表数据...',
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
                        : const Center(child: Text('数据还没有更新 (´;ω;`)')),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = constraints.maxWidth * 6 / 16;
          final imageWidth = imageHeight * 0.72;

          return SizedBox(
            height: constraints.maxWidth * 8 / 16,
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
                        borderRadius: BorderRadius.circular(24),
                        child: Hero(
                          tag: 'Timetable-${bangumiItem.id}',
                          child: BangumiWidget.kostoriImage(
                            context,
                            bangumiItem.images['large']!,
                            width: imageWidth,
                            height: imageHeight,
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
    final cn = bangumiItem.extraInfo?['episode_name_cn'];
    final name = bangumiItem.extraInfo?['episode_name'] ?? '';
    return (cn == null || (cn as String).isEmpty) ? name : cn;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bangumiItem.nameCn,
          style: TextStyle(
            fontSize: imageWidth * 0.12,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          bangumiItem.name,
          style: TextStyle(fontSize: imageWidth * 0.08),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (appdata.settings['calendarFetchEpisodes'] ?? false)
          Text(
            'Episode @e: @n'.tlParams({
              'e': bangumiItem.extraInfo?['episode_ep'] ?? 0,
              'n': _episodeName,
            }),
            style: TextStyle(fontSize: imageWidth * 0.12),
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
          '@t reviews | #@r'.tlParams({
            'r': bangumiItem.rank,
            't': bangumiItem.total,
          }),
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
    required this.bangumiCalendar,
    required this.captureTime,
  });

  final List<List<BangumiItem>> bangumiCalendar;
  final DateTime captureTime;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部操作栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text(
                '截图预览',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.pop(context, _showWeekly ? 'weekly' : 'today'),
                icon: const Icon(Icons.save_alt, size: 18),
                label: const Text('保存'),
              ),
            ],
          ),
        ),
        // 切换按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('本周'),
                icon: Icon(Icons.calendar_view_week),
              ),
              ButtonSegment(
                value: false,
                label: Text('今天'),
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
  final calendarToCapture = showWeekly
      ? bangumiCalendar
      : List.generate(
          7,
          (i) => i == todayIndex ? bangumiCalendar[i] : <BangumiItem>[],
        );

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

  await Future.delayed(const Duration(milliseconds: 1000));
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;

  final boundary =
      repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

  if (boundary == null) {
    overlayState.remove(renderEntry);
    Log.error('截图失败', 'RenderRepaintBoundary 为空');
    return null;
  }

  final image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  overlayState.remove(renderEntry);
  return bytes;
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
    showLoading('正在加载图片...');

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
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ScreenshotPreviewSheet(
        bangumiCalendar: bangumiCalendar,
        captureTime: captureTime,
      ),
    );

    if (result == null || !context.mounted) return;

    showLoading('正在生成截图...');

    final bytes = await generateBangumiCalendarPng(
      context: context,
      bangumiCalendar: bangumiCalendar,
      captureTime: captureTime,
      showWeekly: result == 'weekly',
    );

    removeLoading();

    if (bytes == null) {
      if (context.mounted) {
        ImageSaver.showResult(success: false, message: '截图失败');
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
      ImageSaver.showResult(success: false, message: '截图失败: $e');
    }
    Log.error('截图失败', '$e');
  }
}
