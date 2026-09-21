import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/download_filter.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:kostori/services/download/download_task.dart';
import 'package:kostori/network/external_player.dart';
import 'package:kostori/utils/io.dart';

// 下载筛选的持久化 key
const String _recordFilterKey = 'downloadRecordFilter';
const String _taskFilterKey = 'downloadTaskFilter';
const String _recordGroupFilterKey = 'downloadRecordGroupFilter';

/// 视频下载管理页
class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with SingleTickerProviderStateMixin {
  String _taskFilter = readDownloadFilter(_taskFilterKey, 'all');

  /// 下载记录的「存在的/已删除」筛选（可选项，不是必选维度：
  /// 点已选中的项即取消筛选回到「全部」）
  String _recordExistsFilter = readDownloadFilter(_recordFilterKey, 'all');

  late final TabController _tabCtrl = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  /// 下载记录 tab 的分组管理入口
  final _recordsKey = GlobalKey<_RecordsTabState>();

  bool get _isRecordsTab => _tabCtrl.index == 1;

  @override
  void initState() {
    super.initState();
    DownloadManager.instance.init();
    DownloadManager.instance.addListener(_onChange);
    // 兼容旧版单维度筛选存下的值（如 ungrouped / 分组名）：无效值按「全部」处理
    if (!const ['all', 'exists', 'deleted'].contains(_recordExistsFilter)) {
      _recordExistsFilter = 'all';
      saveDownloadFilter(_recordFilterKey, 'all');
    }
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _setTaskFilter(String value) {
    setState(() => _taskFilter = value);
    saveDownloadFilter(_taskFilterKey, value);
  }

  void _setRecordExistsFilter(String value) {
    // 作为筛选能力可以不选：再次点击已选中的筛选项即取消（回到「全部」）
    final next =
        (value == _recordExistsFilter && value != 'all') ? 'all' : value;
    setState(() => _recordExistsFilter = next);
    saveDownloadFilter(_recordFilterKey, next);
  }

  /// 长按卡片：选择移动到哪个分组（= 下载目录子目录）
  ///
  /// 正在下载的任务会被移动到别的目录，导致写入中的分片/临时文件路径失效，
  /// 因此要求先暂停（暂停或排队中移动是安全的）。
  Future<void> _moveTaskToGroup(DownloadTask task) async {
    if (task.status == DownloadStatus.downloading) {
      App.rootContext.showMessage(
        message: t.downloadPauseBeforeMove,
        level: LogLevel.warning,
      );
      return;
    }
    await showDownloadGroupPicker(
      context,
      current: task.group,
      onSelected: (g) async {
        await DownloadManager.instance.setTaskGroup(task.id, g);
        if (mounted) setState(() {});
      },
    );
  }

  /// 下载设置弹窗：并发数 + 仅 WiFi
  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final concurrent = appdata.implicitData['downloadConcurrent'] as int? ?? 2;
          final segment = appdata.implicitData['downloadSegmentConcurrent'] as int? ?? 4;
          final wifiOnly = appdata.implicitData['downloadWifiOnly'] as bool? ?? false;
          final ignoreEpisodeTitle =
              appdata.implicitData['downloadIgnoreEpisodeTitle'] as bool? ??
              false;

          Widget sliderRow({
            required String label,
            required int value,
            required int min,
            required int max,
            required void Function(int) onChanged,
          }) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  SizedBox(
                    width: 220,
                    child: Slider(
                      value: value.toDouble(),
                      min: min.toDouble(),
                      max: max.toDouble(),
                      divisions: max - min,
                      label: '$value',
                      onChanged: (v) {
                        onChanged(v.round());
                        setSheetState(() {});
                      },
                    ),
                  ),
                  SizedBox(width: 32, child: Text('$value')),
                ],
              ),
            );
          }

          return Sheet(
            title: t.downloadSettings,
            icon: Icons.settings_outlined,
            initialSize: 0.5,
            builder: (sheetCtx, sc) => SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  sliderRow(
                    label: t.downloadConcurrent,
                    value: concurrent,
                    min: 1,
                    max: 4,
                    onChanged: (v) {
                      appdata.implicitData['downloadConcurrent'] = v;
                      appdata.writeImplicitData();
                      DownloadManager.instance.poke();
                    },
                  ),
                  sliderRow(
                    label: t.downloadSegmentConcurrent,
                    value: segment,
                    min: 1,
                    max: 8,
                    onChanged: (v) {
                      appdata.implicitData['downloadSegmentConcurrent'] = v;
                      appdata.writeImplicitData();
                    },
                  ),
                  ListTile(
                    title: Text(t.downloadIgnoreEpisodeTitle),
                    subtitle: Text(t.downloadIgnoreEpisodeTitleDesc),
                    trailing: CustomSwitch(
                      value: ignoreEpisodeTitle,
                      onChanged: (v) {
                        appdata.implicitData['downloadIgnoreEpisodeTitle'] = v;
                        appdata.writeImplicitData();
                        setSheetState(() {});
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(t.downloadWifiOnly),
                    trailing: CustomSwitch(
                      value: wifiOnly,
                      onChanged: (v) {
                        appdata.implicitData['downloadWifiOnly'] = v;
                        appdata.writeImplicitData();
                        setSheetState(() {});
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(t.downloadDir),
                    // Q9：剩余/总量空间已移到页面外部 StorageBar 常驻显示，
                    // 这里只保留目录本身
                    subtitle: Text(
                      _currentDownloadDir(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      final dir = await selectDirectory();
                      if (dir != null && dir.isNotEmpty) {
                        appdata.implicitData['downloadDir'] = dir;
                        appdata.writeImplicitData();
                        setSheetState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _currentDownloadDir() {
    final dir = appdata.implicitData['downloadDir'] as String?;
    if (dir != null && dir.isNotEmpty) return dir;
    return '${App.dataPath}/downloads';
  }

  @override
  void dispose() {
    DownloadManager.instance.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(t.download),
        actions: [
          IconButton(
            tooltip: _sortByName ? t.sortModeName : t.sortModeTime,
            icon: Icon(_sortByName ? Icons.sort_by_alpha : Icons.sort),
            onPressed: _toggleSort,
          ),
          IconButton(
            tooltip: t.manageGroups,
            icon: const Icon(Icons.tune),
            onPressed: () =>
                _isRecordsTab ? _recordsKey.currentState?.manage() : _manageTaskGroups(),
          ),
          IconButton(
            tooltip: t.downloadSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettings(context),
          ),
        ],
        bottom: _DownloadAppbarBottom(
          controller: _tabCtrl,
          existsFilter: _recordExistsFilter,
          onExistsFilter: _setRecordExistsFilter,
        ),
      ),
      body: Column(
        children: [
          // Q9：剩余/全部存储移到页面外部常驻（设置弹窗里不再重复显示）
          const StorageBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _ActiveTab(
                  filter: _taskFilter,
                  onFilter: _setTaskFilter,
                  onMove: _moveTaskToGroup,
                ),
                _RecordsTab(
                  key: _recordsKey,
                  existsFilter: _recordExistsFilter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 排序方式：false = 时间，true = 名称 A-Z
  bool get _sortByName => appdata.implicitData['downloadSortByName'] == true;

  void _toggleSort() {
    setState(() {
      appdata.implicitData['downloadSortByName'] = !_sortByName;
      appdata.writeImplicitData();
    });
  }

  /// AppBar 分组管理入口：条目取全部任务
  Future<void> _manageTaskGroups() async {
    final tasks = DownloadManager.instance.tasks;
    await showDownloadGroupManageSheet(
      context,
      items: [
        for (final task in tasks)
          (
            key: task.id,
            label: (task.episode ?? '').isEmpty
                ? task.title
                : '${task.title} · ${task.episode}',
            group: task.group,
          ),
      ],
      onSetGroup: (key, group) =>
          DownloadManager.instance.setTaskGroup(key, group),
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() {});
  }
}

/// AppBar 底部：正在下载/下载记录 主导航 +（仅下载记录）存在的/已删除筛选
class _DownloadAppbarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  const _DownloadAppbarBottom({
    required this.controller,
    required this.existsFilter,
    required this.onExistsFilter,
  });

  final TabController controller;
  final String existsFilter;
  final ValueChanged<String> onExistsFilter;

  static const double _height = 46;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isRecords = controller.index == 1;
        return SizedBox(
          height: _height,
          child: Row(
            children: [
              // 主导航靠左；占满剩余宽度，把右侧筛选推到最右
              Expanded(
                child: CapsuleTabBar(
                  controller: controller,
                  labels: [t.downloadActive, t.downloadRecords],
                  height: _height,
                  center: false,
                  padding: const EdgeInsets.fromLTRB(12, 2, 4, 4),
                ),
              ),
              if (isRecords)
                DownloadFilterBar(
                  padding: const EdgeInsets.only(right: 12, bottom: 2),
                  builtins: [
                    (key: 'all', label: t.all),
                    (key: 'exists', label: t.exists),
                    (key: 'deleted', label: t.deleted),
                  ],
                  selected: existsFilter,
                  onSelected: onExistsFilter,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 正在下载：筛选条（仅状态）+ 操作按钮行 + 未完成任务列表
class _ActiveTab extends StatelessWidget {
  const _ActiveTab({
    required this.filter,
    required this.onFilter,
    required this.onMove,
  });

  final String filter;
  final ValueChanged<String> onFilter;
  final void Function(DownloadTask task) onMove;

  bool get _sortByName => appdata.implicitData['downloadSortByName'] == true;

  List<DownloadTask> _filterTasks(List<DownloadTask> unfinished) {
    switch (filter) {
      case 'downloading':
        return unfinished
            .where((t) => t.status == DownloadStatus.downloading)
            .toList();
      case 'paused':
        return unfinished
            .where((t) => t.status == DownloadStatus.paused)
            .toList();
      case 'failed':
        return unfinished
            .where((t) => t.status == DownloadStatus.failed)
            .toList();
    }
    return unfinished;
  }

  List<DownloadTask> _sortTasks(List<DownloadTask> list) {
    if (!_sortByName) return list;
    return [...list]..sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = DownloadManager.instance;
    final tasks = manager.tasks;
    final unfinished = tasks
        .where((t) => t.status != DownloadStatus.completed)
        .toList();
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              t.downloadEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _sortTasks(_filterTasks(unfinished));
    // Q19：序号按任务创建时间全局稳定编号（新任务排末尾），
    // 不随筛选/排序重置，避免“1 下完了下一个又变 1”
    final ordered = [...tasks]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final globalIndex = <String, int>{
      for (var i = 0; i < ordered.length; i++) ordered[i].id: i + 1,
    };
    return Column(
      children: [
        // Q16：正在下载条目计数
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              Text(
                '${t.all} (${unfinished.length})',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Q21：总任务进度（完成数/失败数双色单条；完成后保留到手动关闭）
        if (manager.batchVisible) _BatchProgressBar(manager: manager),
        // Q18：筛选胶囊 + 4 个批量操作放在同一行可横滑；
        // 操作按钮用项目分段胶囊样式，只显示 icon，文字放 tooltip
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              DownloadFilterBar(
                builtins: [
                  (key: 'all', label: t.all),
                  (key: 'downloading', label: t.downloading),
                  (key: 'paused', label: t.paused),
                  (key: 'failed', label: t.failed),
                ],
                selected: filter,
                onSelected: onFilter,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              CapsuleButtonBar(
                padding: EdgeInsets.zero,
                children: [
                  Tooltip(
                    message: t.redownload,
                    child: CapsuleButton(
                      flat: true,
                      leading: const Icon(Icons.refresh),
                      onTap: () => manager.retryFailed(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: t.startAll,
                    child: CapsuleButton(
                      flat: true,
                      leading: const Icon(Icons.play_arrow),
                      onTap: () => manager.resumeAll(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: t.pauseAll,
                    child: CapsuleButton(
                      flat: true,
                      leading: const Icon(Icons.pause),
                      onTap: () => manager.pauseAll(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: t.cancelAll,
                    child: CapsuleButton(
                      flat: true,
                      leading: const Icon(Icons.delete_outline),
                      onTap: () => manager.cancelAll(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    t.noData,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    for (final task in filtered)
                      _DownloadTile(
                        index: globalIndex[task.id] ?? 0,
                        task: task,
                        onLongPress: () => onMove(task),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Q21：总任务进度条（按任务完成数计数，失败也计数）：
/// 单条双色（完成=主题色，失败=错误色），初始为 0 不显示，
/// 完成后保留显示直到用户手动关闭；内部 try/catch 保底，绝不崩列表。
class _BatchProgressBar extends StatelessWidget {
  const _BatchProgressBar({required this.manager});

  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    try {
      final total = manager.batchTotal;
      if (total <= 0) return const SizedBox.shrink();
      final done = manager.batchDoneView;
      final failed = manager.batchFailedView;
      final rest = (total - done - failed).clamp(0, total);
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant, width: 0.6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      failed > 0
                          ? '${t.downloadCompleted} $done/$total · ${t.failed} $failed'
                          : '${t.downloadCompleted} $done/$total',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 6,
                        child: Row(
                          children: [
                            if (done > 0)
                              Expanded(
                                flex: done,
                                child: ColoredBox(color: cs.primary),
                              ),
                            if (failed > 0)
                              Expanded(
                                flex: failed,
                                child: ColoredBox(color: cs.error),
                              ),
                            if (rest > 0)
                              Expanded(
                                flex: rest,
                                child: ColoredBox(
                                  color: cs.surfaceContainerHighest,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.close,
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.close),
                onPressed: () => manager.dismissBatch(),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

/// 下载记录 tab：已完成的下载（本地播放 / 外部播放 / 删除）
class _RecordsTab extends StatefulWidget {
  const _RecordsTab({super.key, required this.existsFilter});

  /// 存在的/已删除筛选（由 AppBar 底部那行控制）
  final String existsFilter;

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  List<Map<String, dynamic>> _records = [];

  /// filePath → 文件是否仍存在
  final Map<String, bool> _exists = {};

  /// filePath → 文件大小（字节）
  final Map<String, int> _sizes = {};

  /// 分组筛选：all / ungrouped / g:<分组名>
  String _groupFilter = readDownloadFilter(_recordGroupFilterKey, 'all');

  /// 子组筛选：子组完整名（空 = 该组全部）
  String _subFilter = '';

  Timer? _reloadTimer;
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    DownloadManager.instance.addListener(_scheduleReload);
    _reload();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    DownloadManager.instance.removeListener(_scheduleReload);
    super.dispose();
  }

  /// 下载管理器进度通知很频繁：合并为最多每 400ms 刷新一次
  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _reload() async {
    if (_reloading) return;
    _reloading = true;
    try {
      final records = await DownloadManager.allRecords();
      // 并行检查文件是否存在/大小，避免逐条 await 拖慢首次加载
      final checks = await Future.wait(
        records.map((r) async {
          final fp = r['filePath'] as String? ?? '';
          if (fp.isEmpty) return (fp, false, 0);
          try {
            final stat = await File(fp).stat();
            final exists = stat.type != FileSystemEntityType.notFound;
            return (fp, exists, exists ? stat.size : 0);
          } catch (_) {
            return (fp, false, 0);
          }
        }),
      );
      final exists = <String, bool>{};
      final sizes = <String, int>{};
      for (final (fp, e, s) in checks) {
        exists[fp] = e;
        if (e) sizes[fp] = s;
      }
      if (mounted) {
        setState(() {
          _records = records;
          _exists
            ..clear()
            ..addAll(exists);
          _sizes
            ..clear()
            ..addAll(sizes);
        });
      }
    } finally {
      _reloading = false;
    }
  }

  void _play(Map<String, dynamic> r) {
    final path = r['filePath'] as String?;
    if (path == null || path.isEmpty) return;
    App.mainNavigatorKey?.currentContext?.to(
      () => LocalPlayerPage(filePath: path),
    );
  }

  Future<void> _openExternal(Map<String, dynamic> r) async {
    final path = r['filePath'] as String?;
    if (path == null || path.isEmpty) return;
    // 原生通道唤起系统默认播放器（Android: Intent + FileProvider；Windows: ShellExecute）
    final ok = await ExternalPlayer.openLocalVideo(path);
    if (!ok) {
      App.rootContext.showMessage(message: t.failedToOpen);
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final path = r['filePath'] as String?;
    if (path == null || path.isEmpty) return;
    await DownloadManager.instance.deleteRecord(path);
    await _reload();
  }

  /// 长按卡片：选择移动到哪个分组（= 下载目录子目录）
  Future<void> _moveToGroup(Map<String, dynamic> r) async {
    final fp = r['filePath'] as String? ?? '';
    if (fp.isEmpty) return;
    await showDownloadGroupPicker(
      context,
      current: r['group']?.toString() ?? '',
      onSelected: (g) async {
        await DownloadManager.instance.setRecordGroup(fp, g);
        await _reload();
      },
    );
  }

  /// 重命名已下载文件（同时改磁盘文件名与记录标题）
  Future<void> _rename(Map<String, dynamic> r) async {
    final fp = r['filePath'] as String? ?? '';
    if (fp.isEmpty) return;
    final ctrl = TextEditingController(text: r['title'] as String? ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.rename,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          decoration: InputDecoration(labelText: t.fileName),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final n = name?.trim() ?? '';
    if (n.isEmpty) return;
    await DownloadManager.instance.renameRecord(fp, n);
    await _reload();
  }

  /// 排序方式：false = 时间，true = 名称 A-Z（AppBar 统一切换）
  bool get _sortByName => appdata.implicitData['downloadSortByName'] == true;

  /// 记录排序：已删除（文件不存在）沉底，其余按时间倒序或名称 A-Z
  List<Map<String, dynamic>> _sortRecords(List<Map<String, dynamic>> list) {
    final byName = _sortByName;
    return [...list]..sort((a, b) {
      final da = _exists[a['filePath']] == true ? 0 : 1;
      final db = _exists[b['filePath']] == true ? 0 : 1;
      if (da != db) return da - db;
      if (byName) {
        return (a['title'] as String? ?? '').toLowerCase().compareTo(
          (b['title'] as String? ?? '').toLowerCase(),
        );
      }
      return (b['time'] as String? ?? '').compareTo(
        a['time'] as String? ?? '',
      );
    });
  }

  /// 记录筛选：存在的/已删除（AppBar）+ 分组/子组（本页胶囊行）独立组合
  List<Map<String, dynamic>> _filtered() {
    var list = _records;
    switch (widget.existsFilter) {
      case 'exists':
        list = list.where((r) => _exists[r['filePath']] == true).toList();
      case 'deleted':
        list = list.where((r) => _exists[r['filePath']] != true).toList();
    }
    if (_groupFilter == 'ungrouped') {
      list = list.where((r) => (r['group']?.toString() ?? '') == '').toList();
    } else if (_groupFilter.startsWith(kDownloadGroupPrefix)) {
      final name = _groupFilter.substring(kDownloadGroupPrefix.length);
      if (_subFilter.isNotEmpty) {
        // 选中具体子组：只看该子组
        list = list
            .where((r) => (r['group']?.toString() ?? '') == _subFilter)
            .toList();
      } else {
        // 顶层组：含其子组（子组行可选具体子组收窄）
        final prefix = '$name${DownloadManager.groupSeparator}';
        list = list.where((r) {
          final g = r['group']?.toString() ?? '';
          return g == name || g.startsWith(prefix);
        }).toList();
      }
    }
    return _sortRecords(list);
  }

  /// 分组条目数（按当前 存在的/已删除 筛选统计）：
  /// 父组累计其下所有子组的条目，子组统计自身（含更深层子组）
  Map<String, int> _groupCounts() {
    final counts = <String, int>{};
    for (final r in _records) {
      final exists = _exists[r['filePath']] == true;
      if (widget.existsFilter == 'exists' && !exists) continue;
      if (widget.existsFilter == 'deleted' && exists) continue;
      var g = r['group']?.toString() ?? '';
      while (g.isNotEmpty) {
        counts[g] = (counts[g] ?? 0) + 1;
        final i = g.lastIndexOf(DownloadManager.groupSeparator);
        if (i <= 0) break;
        g = g.substring(0, i);
      }
    }
    return counts;
  }

  /// 某个分组下「直接属于它」（不含子组）的条目数（按当前 存在的/已删除 筛选）
  int _directGroupCount(String group) {
    var n = 0;
    for (final r in _records) {
      if ((r['group']?.toString() ?? '') != group) continue;
      final exists = _exists[r['filePath']] == true;
      if (widget.existsFilter == 'exists' && !exists) continue;
      if (widget.existsFilter == 'deleted' && exists) continue;
      n++;
    }
    return n;
  }

  /// 当前选中的自定义分组（完整名）；未选中自定义分组时为 null
  String? get _selectedGroup {
    if (!_groupFilter.startsWith(kDownloadGroupPrefix)) return null;
    return _groupFilter.substring(kDownloadGroupPrefix.length);
  }

  void _setGroupFilter(String value) {
    setState(() {
      _groupFilter = value;
      // 切换分组时清掉子组筛选
      if (!value.startsWith(kDownloadGroupPrefix)) _subFilter = '';
    });
    saveDownloadFilter(_recordGroupFilterKey, value);
  }

  String _recordLabel(Map<String, dynamic> r) {
    final title = r['title'] as String? ?? '';
    final episode = r['episode'] as String? ?? '';
    final resolution = r['resolution'] as String? ?? '';
    return episode.isNotEmpty
        ? '$title · $episode${resolution.isNotEmpty ? ' · $resolution' : ''}'
        : title;
  }

  /// AppBar 的「管理分组」入口调用
  Future<void> manage() => _manageGroups();

  Future<void> _manageGroups() async {
    await showDownloadGroupManageSheet(
      context,
      items: [
        for (final r in _records)
          if ((r['filePath'] as String? ?? '').isNotEmpty)
            (
              key: r['filePath'] as String,
              label: _recordLabel(r),
              group: r['group']?.toString() ?? '',
            ),
      ],
      onSetGroup: (key, group) =>
          DownloadManager.instance.setRecordGroup(key, group),
      onChanged: () {
        if (mounted) _reload();
      },
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_done,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              t.recordsEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final filtered = _filtered();
    final groupCounts = _groupCounts();
    return Column(
      children: [
        // 分组行：全部 / 未分组 + 顶层自建组（带条目数，含其子组）
        DownloadFilterBar(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
          builtins: [
            (key: 'all', label: t.all),
            (key: 'ungrouped', label: t.ungrouped),
          ],
          groups: DownloadManager.rootGroups(),
          groupCounts: groupCounts,
          selected: _groupFilter,
          onSelected: _setGroupFilter,
        ),
        // 有子组的分组：全部 / 父组（只在本组的条目） + 各子组
        if (_selectedGroup != null &&
            DownloadManager.hasSubGroups(_selectedGroup!))
          DownloadFilterBar(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
            builtins: [(key: 'all', label: t.all)],
            groups: [
              _selectedGroup!,
              ...DownloadManager.subGroupsOf(_selectedGroup!),
            ],
            groupCounts: {
              ...groupCounts,
              // 父组这一项只统计「直接在本组」的条目
              _selectedGroup!: _directGroupCount(_selectedGroup!),
            },
            selected: _subFilter.isEmpty
                ? 'all'
                : '$kDownloadGroupPrefix$_subFilter',
            onSelected: (v) => setState(() {
              _subFilter = v == 'all'
                  ? ''
                  : v.substring(kDownloadGroupPrefix.length);
            }),
          ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    t.noData,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final r = filtered[index];
        final title = r['title'] as String? ?? '';
        final episode = r['episode'] as String? ?? '';
        final resolution = r['resolution'] as String? ?? '';
        final fp = r['filePath'] as String? ?? '';
        final sourceKey = r['sourceKey'] as String? ?? '';
        final sourceName = sourceKey.isEmpty
            ? ''
            : (AnimeSource.find(sourceKey)?.name ?? sourceKey);
        final exists = _exists[fp] ?? false;
        // Q15：时间精确到秒（YYYY-MM-DD HH:MM:SS）
        var time = (r['time'] as String? ?? '')
            .replaceAll('T', ' ')
            .replaceAll('.000', '');
        if (time.length > 19) time = time.substring(0, 19);

        Widget chip(String text, {Color? textColor, Color? boxColor}) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: boxColor ??
                  (exists
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.errorContainer),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: exists
                    ? colorScheme.outlineVariant
                    : colorScheme.error.withValues(alpha: 0.5),
                width: 0.6,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: textColor ??
                    (exists
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.error),
              ),
            ),
          );
        }

        final subtitleText = title;
        return Material(
          color: exists
              ? colorScheme.surfaceContainerLow
              : colorScheme.errorContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (!exists) {
                App.rootContext.showMessage(message: t.fileNotFound);
                return;
              }
              _play(r);
            },
            onLongPress: () => _moveToGroup(r),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.isNotEmpty
                        ? '$subtitleText · $episode'
                            '${resolution.isNotEmpty ? ' · $resolution' : ''}'
                        : subtitleText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: exists ? null : colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (time.isNotEmpty) chip(time),
                      if (sourceName.isNotEmpty) chip(sourceName),
                      if (exists)
                        chip(formatBytesShort(_sizes[fp] ?? 0))
                      else
                        chip(t.deleted, textColor: colorScheme.onError),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 操作按钮：靠右
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (exists)
                        IconButton(
                          tooltip: t.openWithOtherPlayer,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.open_in_new,
                            color: colorScheme.primary,
                          ),
                          onPressed: () => _openExternal(r),
                        ),
                      IconButton(
                        tooltip: t.rename,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.edit_outlined,
                          color: colorScheme.primary,
                        ),
                        onPressed: () => _rename(r),
                      ),
                      IconButton(
                        tooltip: t.delete,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          color: colorScheme.error,
                        ),
                        onPressed: () => _delete(r),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
                ),
        ),
      ],
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.index,
    required this.task,
    this.onLongPress,
  });

  final int index;

  final DownloadTask task;

  /// 长按卡片：选择移动到哪个分组
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final error = task.status == DownloadStatus.failed &&
            task.error != null &&
            task.error!.isNotEmpty
        ? task.error!
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：横封面（含序号） + 右侧：标题 + 来源/分辨率 + 状态
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCover(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _buildMetaRow(context),
                        const SizedBox(height: 6),
                        _buildStateLine(context),
                      ],
                    ),
                  ),
                ],
              ),
              // 底部：合并中显示矩形进度框，否则进度条 + 下载进度信息
              if (task.isMerging)
                _buildMergingIndicator(context)
              else ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: task.progress,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 4,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _buildProgressInfo(),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    // 操作按钮放在下载进度信息这一行的最右边（删除用 ×）
                    _buildInlineActions(context),
                  ],
                ),
              ],
              // 错误信息行（与上方下载进度信息之间用分割线隔开）
              if (error != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _showError(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 14, color: colorScheme.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatError(error),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: colorScheme.error),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget child;
    if (task.cover == null || task.cover!.isEmpty) {
      child = ColoredBox(
        color: colorScheme.secondaryContainer,
        child: Icon(Icons.movie_outlined, color: colorScheme.outline),
      );
    } else {
      // 用任务所属源加载缩略图（固定 'bangumi' 会缺少该源的加载配置/headers）
      child = Image(
        image: CachedImageProvider(task.cover!, sourceKey: task.sourceKey),
        fit: BoxFit.cover,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        // 横向封面（宽比高大，贴近视频截图比例），尺寸放大提升观感
        width: 120,
        height: 72,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            // 左上角序号徽章：Q16 支持 3 位数（自适应宽度，两位数内圆形，更多变胶囊）
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 0.6,
                  ),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 合并中矩形进度框：左侧加载动画，右侧合并百分比
  Widget _buildMergingIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = (task.progress * 100).clamp(0.0, 100.0).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            const PolygonRefreshIndicator(size: 16),
            const SizedBox(width: 10),
            Text(
              t.downloadMerging,
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
            const Spacer(),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 下载进度信息文本（排队中暂无数据时返回空串）
  String _buildProgressInfo() {
    if (task.status == DownloadStatus.queued) return '';
    final parts = <String>[
      formatBytesShort(task.downloadedBytes),
      if (task.totalBytes > 0) formatBytesShort(task.totalBytes),
    ];
    final bytes = parts.join(' / ');
    final segs = task.segTotal > 0 ? '${task.segDone}/${task.segTotal}' : '';
    return [
      if (bytes.isNotEmpty) bytes,
      if (segs.isNotEmpty) segs,
    ].join('  ·  ');
  }

  /// 进度信息行最右侧的操作按钮：主操作（暂停/继续/重试/强合）+ 删除（×）
  Widget _buildInlineActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued)
          IconButton(
            tooltip: t.pauseDownload,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: const Icon(Icons.pause_circle_outline),
            onPressed: () => DownloadManager.instance.pause(task.id),
          ),
        if (task.status == DownloadStatus.paused)
          IconButton(
            tooltip: t.resumeDownload,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => DownloadManager.instance.resume(task.id),
          ),
        if (task.status == DownloadStatus.failed)
          IconButton(
            tooltip: t.retryDownload,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: const Icon(Icons.refresh),
            onPressed: () => DownloadManager.instance.resume(task.id),
          ),
        if (task.status == DownloadStatus.failed && task.isHls)
          IconButton(
            tooltip: t.forceMerge,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(Icons.merge_type, color: colorScheme.primary),
            onPressed: () {
              // 直接合并：进度写入 task.progress，由卡片进度条实时显示
              DownloadManager.instance.forceMerge(task.id);
            },
          ),
        IconButton(
          tooltip: t.downloadViewHeaders,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => _showHeaders(context),
        ),
        IconButton(
          tooltip: t.delete,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          icon: Icon(Icons.close, color: colorScheme.error),
          onPressed: () => DownloadManager.instance.cancel(task.id),
        ),
      ],
    );
  }

  /// 查看该下载任务的请求地址与请求头（排查 403/410、鉴权失败）
  void _showHeaders(BuildContext context) {
    final headers = task.headers;
    final buf = StringBuffer('URL: ${task.url}\n');
    if (headers.isEmpty) {
      buf.write('\n${t.downloadNoHeaders}');
    } else {
      buf.write('\n');
      for (final e in headers.entries) {
        buf.write('${e.key}: ${e.value}\n');
      }
    }
    // 只读请求头：不显示按钮（点遮罩关闭）
    showDialog<void>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: '${t.downloadViewHeaders} · ${task.title}',
        displayButton: false,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: SelectableText(contextMenuBuilder: appEditableSelectionContextMenu,
              buf.toString(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context) {
    // 只读错误详情：不显示任何按钮（点遮罩关闭）
    showDialog<void>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: '${t.downloadFailed} · ${task.title}',
        displayButton: false,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: SelectableText(contextMenuBuilder: appEditableSelectionContextMenu,
              task.error ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  /// 来源元信息行（无来源时隐藏；分辨率在状态行左侧展示，避免重复）
  /// Q13：右侧追加“下载到哪个文件组”，最多一行省略
  Widget _buildMetaRow(BuildContext context) {
    final String? src = task.sourceKey == null
        ? null
        : AnimeSource.find(task.sourceKey!)?.name;
    final group = task.group.trim();
    if ((src == null || src.isEmpty) && group.isEmpty) {
      return const SizedBox.shrink();
    }
    final style = TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        if (src != null && src.isNotEmpty)
          Expanded(
            child: Text(
              src,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        if (src != null && src.isNotEmpty && group.isNotEmpty)
          const SizedBox(width: 8),
        if (group.isNotEmpty)
          Expanded(
            child: Text(
              group,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
      ],
    );
  }

  /// 状态行：下载中显示百分比（替代“正在下载”），
  /// 下载速度作为独立文本放在百分比右侧；其余状态显示图标+文字
  Widget _buildStateLine(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (task.status == DownloadStatus.downloading) {
      if (task.isMerging) {
        // 合并中：顶部显示“正在合并”，百分比由下方矩形进度框呈现
        return Row(
          children: [
            Icon(Icons.merge_type, size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              t.downloadMerging,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.primary,
              ),
            ),
            const Spacer(),
          ],
        );
      }
      // Q12：m3u8 未下完时百分比封顶 99%，避免 79/80 显示 100% 误导
      // （已完成/合并态不受影响）
      var pctValue = (task.progress * 100).clamp(0.0, 100.0);
      if (task.segTotal > 0 &&
          task.segDone < task.segTotal &&
          pctValue >= 100) {
        pctValue = 99;
      }
      final pct = pctValue.toStringAsFixed(0);
      final speed = formatSpeed(task.downloadSpeed, zeroText: '');
      final res = task.resolution?.trim();
      final hasRes = res != null && res.isNotEmpty;
      // 百分比组件：容器内 = 多边形加载动画(左) + 百分比(右)，
      // 右侧用 `·` 分隔显示速度；最左侧显示分辨率
      final pctBox = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: PolygonRefreshIndicator(size: 16),
            ),
            const SizedBox(width: 6),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      );
      return Row(
        children: [
          if (hasRes) ...[
            Text(
              res,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
          pctBox,
          if (speed.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              '·  $speed',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const Spacer(),
        ],
      );
    }
    final (label, color, icon) = switch (task.status) {
      DownloadStatus.queued => (
        t.downloadQueued,
        colorScheme.onSurfaceVariant,
        Icons.schedule,
      ),
      DownloadStatus.paused => (
        t.pausedDownload,
        colorScheme.onSurfaceVariant,
        Icons.pause_circle_outline,
      ),
      DownloadStatus.completed => (
        t.downloadCompleted,
        colorScheme.primary,
        Icons.check_circle_outline,
      ),
      _ => (t.downloadFailed, colorScheme.error, Icons.error_outline),
    };
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  /// 精简错误信息：去 Exception 前缀、去堆栈，截断显示
  String _formatError(String error) {
    var s = error.replaceFirst('Exception: ', '');
    s = s.split('\n').first.trim();
    if (s.length > 48) s = '${s.substring(0, 48)}...';
    return s;
  }
}
