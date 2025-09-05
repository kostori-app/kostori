import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:table_calendar/table_calendar.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  @override
  Widget build(BuildContext context) {
    var widget = SmoothCustomScrollView(
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
        const _SyncDataWidget(),
        const _ImageManipulation(),
        const _StatsCalendarPage(),
      ],
    );
    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
  }
}

class _SyncDataWidget extends StatefulWidget {
  const _SyncDataWidget();

  @override
  State<_SyncDataWidget> createState() => _SyncDataWidgetState();
}

class _SyncDataWidgetState extends State<_SyncDataWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    DataSync().addListener(update);
    WidgetsBinding.instance.addObserver(this);
    lastCheck = DateTime.now();
  }

  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
    DataSync().removeListener(update);
    WidgetsBinding.instance.removeObserver(this);
  }

  late DateTime lastCheck;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(lastCheck) > const Duration(minutes: 10)) {
        lastCheck = DateTime.now();
        DataSync().downloadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (!DataSync().isEnabled) {
      child = const SliverPadding(padding: EdgeInsets.zero);
    } else if (DataSync().isUploading || DataSync().isDownloading) {
      child = SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.primary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: Text('Syncing Data'.tl),
            trailing: const CircularProgressIndicator(
              strokeWidth: 2,
            ).fixWidth(18).fixHeight(18),
          ),
        ),
      );
    } else {
      child = SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: Text('Sync Data'.tl),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (DataSync().lastError != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      showDialogMessage(
                        App.rootContext,
                        "Error".tl,
                        DataSync().lastError!,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text('Error'.tl, style: ts.s12),
                        ],
                      ),
                    ),
                  ).paddingRight(4),
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  onPressed: () async {
                    DataSync().uploadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cloud_download_outlined),
                  onPressed: () async {
                    DataSync().downloadData();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverAnimatedPaintExtent(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

class _ImageManipulation extends ConsumerStatefulWidget {
  const _ImageManipulation();

  @override
  ConsumerState<_ImageManipulation> createState() => _ImageManipulationState();
}

class _ImageManipulationState extends ConsumerState<_ImageManipulation> {
  @override
  void initState() {
    super.initState();
    // 延迟执行避免在构建期间修改provider
    Future.microtask(() async {
      final files = await loadKostoriImages();
      ref.read(imagesProvider.notifier).setImages(files);
    });
  }

  Future<List<File>> loadKostoriImages() async {
    Directory directory;

    if (App.isAndroid) {
      directory = (await KostoriFolder.checkPermissionAndPrepareFolder())!;
    } else {
      final folderDirectory = await getApplicationDocumentsDirectory();
      final folderPath = '${folderDirectory.path}/Kostori';
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
        Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
      }
      directory = folder;
    }

    if (!await directory.exists()) {
      return [];
    }

    final files = directory.listSync(recursive: false).whereType<File>().where((
      file,
    ) {
      final ext = file.path.toLowerCase();
      return ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.png') ||
          ext.endsWith('.webp') ||
          ext.endsWith('.gif');
    }).toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return files;
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(imagesProvider);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.to(() => ImageManipulationPage(initialImages: images));
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Center(child: Text('Image Operations'.tl, style: ts.s18)),
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
                      child: Text('${images.length}', style: ts.s12),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_month),
                    const SizedBox(width: 10),
                  ],
                ),
              ).paddingHorizontal(16),
              SizedBox(
                height: 384,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    scrollbars: true,
                    dragDevices: {
                      ui.PointerDeviceKind.touch,
                      ui.PointerDeviceKind.mouse,
                      ui.PointerDeviceKind.stylus,
                      ui.PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length > 10 ? 10 : images.length,
                    itemBuilder: (context, index) {
                      final file = images[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Card(
                          margin: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              BangumiWidget.showImagePreview(
                                context,
                                file.path,
                                App.isAndroid
                                    ? file.path.split('/').last
                                    : file.path.split('\\').last,
                                App.isAndroid
                                    ? file.path.split('/').last
                                    : file.path.split('\\').last,
                                allUrls: images,
                                initialIndex: index,
                              );
                              // provider管理，不用调用loadImages
                            },
                            child: SizedBox(
                              width: 300 * 1.8,
                              height: 300,
                              child: Hero(
                                tag: App.isAndroid
                                    ? file.path.split('/').last
                                    : file.path.split('\\').last,
                                child: Image.file(file, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ).paddingHorizontal(8).paddingVertical(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCalendarPage extends StatefulWidget {
  const _StatsCalendarPage();

  @override
  State<_StatsCalendarPage> createState() => _StatsCalendarPageState();
}

class _StatsCalendarPageState extends State<_StatsCalendarPage> {
  final StatsManager statsManager = StatsManager();
  Map<DateTime, List<StatsDataImpl>> _eventMap = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _loading = true;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final map = await statsManager.getEventMap();

    setState(() {
      _eventMap = map;
      _loading = false;
    });
  }

  List<StatsDataImpl> entriesForSelectedDay() {
    return _eventMap.entries
        .firstWhere(
          (e) => isSameDay(e.key, _selectedDay ?? _focusedDay),
          orElse: () => MapEntry(DateTime(0), []),
        )
        .value;
  }

  @override
  Widget build(BuildContext context) {
    final entries = entriesForSelectedDay();
    if (_loading) {
      return const Center(child: CircularProgressIndicator()).toSliver();
    }
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    key: const PageStorageKey("stats_calendar"),
                    firstDay: DateTime.utc(2000, 1, 1),
                    lastDay: DateTime.utc(2077, 12, 31),
                    focusedDay: _focusedDay,
                    locale: 'zh_cn',
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    calendarStyle: CalendarStyle(
                      markerDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                  ),
                ),
              ),
              if (entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final stats = entries[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Material(
                          color: context.brightness == Brightness.light
                              ? Colors.white.toOpacity(0.72)
                              : const Color(0xFF1E1E1E).toOpacity(0.72),
                          elevation: 4,
                          shadowColor: Theme.of(context).colorScheme.shadow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: StatItemWidget(
                            stats: stats,
                            selectedDay: _selectedDay ?? _focusedDay,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatItemWidget extends StatelessWidget {
  final StatsDataImpl stats;

  final DateTime selectedDay;

  const StatItemWidget({
    super.key,
    required this.stats,
    required this.selectedDay,
  });

  final height = 160.0;

  DailyEvent? _getDailyEvent(List<DailyEvent> events) {
    for (final event in events) {
      if (_isSameDay(event.date, selectedDay)) {
        return event;
      }
    }
    return null;
  }

  /// 日期只比对年月日
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget buildCommentWidget() {
    final commentList = stats.comment;

    if (commentList.isEmpty) {
      return const SizedBox.shrink(); // 没有评论
    }

    // 情况1：只有一个 DailyEvent
    if (commentList.length == 1) {
      final comment = commentList.first.platformEventRecords.isNotEmpty
          ? commentList.first.platformEventRecords.first.comment ?? ''
          : '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${commentList.first.platformEventRecords.first.date} 创建了一条评论:',
            style: const TextStyle(fontSize: 14),
          ),
          Text(comment, style: const TextStyle(fontSize: 14)),
        ],
      );
    }

    // 情况2：多个 DailyEvent
    int sum = 0;
    for (final event in commentList) {
      if (event.date.isBefore(selectedDay)) {
        final records = event.platformEventRecords;
        if (records.isNotEmpty) {
          sum += records.last.value; // 取每条 DailyEvent 的最后一条 value
        }
      }
    }
    final commentEvent = _getDailyEvent(stats.comment);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final record in commentEvent!.platformEventRecords)
          Builder(
            builder: (_) {
              final text = '${record.date} 第${sum + record.value} 次修改了评论:';
              sum += record.value; // 累加给下一条使用
              return Column(
                children: [
                  Text(text, style: const TextStyle(fontSize: 14)),
                  Text(record.comment!, style: const TextStyle(fontSize: 14)),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget buildRathingWidget() {
    final ratingList = stats.rating;

    if (ratingList.isEmpty) {
      return const SizedBox.shrink(); // 没有评论
    }

    // 情况1：只有一个 DailyEvent
    if (ratingList.length == 1) {
      final comment = ratingList.first.platformEventRecords.isNotEmpty
          ? ratingList.first.platformEventRecords.first.rating ?? ''
          : '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ratingList.first.platformEventRecords.first.date} 创建了一条评级:',
            style: const TextStyle(fontSize: 14),
          ),
          Text(comment.toString(), style: const TextStyle(fontSize: 14)),
        ],
      );
    }

    // 情况2：多个 DailyEvent
    int sum = 0;
    for (final event in ratingList) {
      if (event.date.isBefore(selectedDay)) {
        final records = event.platformEventRecords;
        if (records.isNotEmpty) {
          sum += records.last.value; // 取每条 DailyEvent 的最后一条 value
        }
      }
    }
    final ratingEvent = _getDailyEvent(stats.rating);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final record in ratingEvent!.platformEventRecords)
          Builder(
            builder: (_) {
              final text = '${record.date} 第${sum + record.value} 次修改了评级:';
              sum += record.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: const TextStyle(fontSize: 14)),
                  Text(
                    record.rating.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget buildClickWidget() {
    final clickEvent = _getDailyEvent(stats.totalClickCount);

    if (clickEvent == null || clickEvent.platformEventRecords.isEmpty) {
      return const SizedBox.shrink(); // 没有点击数据
    }

    // 先生成每条记录的 Widget 列表，同时累加总和
    int totalClicks = 0;
    final children = <Widget>[];
    for (final record in clickEvent.platformEventRecords) {
      children.add(
        Text(
          '在${record.platform?.value ?? '未知'}点击${record.value}次',
          style: const TextStyle(fontSize: 14),
        ),
      );
      totalClicks += record.value;
    }

    // 添加总和
    children.add(const SizedBox(height: 4));
    children.add(
      Text(
        '总点击次数: $totalClicks',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget buildWatchWidget() {
    final watchEvent = _getDailyEvent(stats.totalWatchDurations);

    if (watchEvent == null || watchEvent.platformEventRecords.isEmpty) {
      return const SizedBox.shrink(); // 没有观看数据
    }

    int totalSeconds = 0;

    String formatHMS(int seconds) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final s = seconds % 60;

      final parts = <String>[];
      if (h > 0) parts.add('${h}h');
      if (m > 0) parts.add('${m}m');
      if (s > 0 || parts.isEmpty) parts.add('${s}s'); // 秒数总显示，防止全部为0

      return parts.join(' ');
    }

    final children = <Widget>[];

    for (final record in watchEvent.platformEventRecords) {
      children.add(
        Text(
          '在${record.platform?.value ?? '未知'}观看: ${formatHMS(record.value)}',
          style: const TextStyle(fontSize: 14),
        ),
      );
      totalSeconds += record.value; // 直接累加
    }

    // 添加总观看时长
    children.add(const SizedBox(height: 4));
    children.add(
      Text(
        '本日观看时长: ${formatHMS(totalSeconds)}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          if (stats.cover != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Hero(
                tag: '$stats.id',
                child: BangumiWidget.kostoriImage(
                  context,
                  stats.cover!,
                  width: height * 0.72,
                  height: height,
                  showPlaceholder: true,
                ),
              ),
            ),
          const SizedBox(width: 12),
          // 文字信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.title!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                buildCommentWidget(),
                buildRathingWidget(),
                buildClickWidget(),
                buildWatchWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
