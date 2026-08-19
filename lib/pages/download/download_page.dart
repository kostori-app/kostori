import 'package:flutter/material.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:kostori/services/download/download_task.dart';
import 'package:kostori/utils/io.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// 视频下载管理页
class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  @override
  void initState() {
    super.initState();
    DownloadManager.instance.init();
    DownloadManager.instance.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// 下载设置弹窗：并发数 + 仅 WiFi
  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final concurrent = appdata.implicitData['downloadConcurrent'] as int? ?? 2;
          final segment = appdata.implicitData['downloadSegmentConcurrent'] as int? ?? 4;
          final wifiOnly = appdata.implicitData['downloadWifiOnly'] as bool? ?? false;

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

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.downloadSettings,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  sliderRow(
                    label: t.downloadConcurrent,
                    value: concurrent,
                    min: 1,
                    max: 4,
                    onChanged: (v) {
                      appdata.implicitData['downloadConcurrent'] = v;
                      appdata.writeImplicitData();
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
    final manager = DownloadManager.instance;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.download),
          actions: [
            IconButton(
              tooltip: t.downloadSettings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showSettings(context),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: t.downloadActive),
              Tab(text: t.downloadRecords),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildActiveTab(context, manager),
            const _RecordsTab(),
          ],
        ),
      ),
    );
  }

  /// 正在下载：操作按钮行 + 未完成任务列表
  Widget _buildActiveTab(BuildContext context, DownloadManager manager) {
    final tasks = manager.tasks;
    final unfinished = tasks
        .where((t) => t.status != DownloadStatus.completed)
        .toList();
    if (unfinished.isEmpty) {
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

    Widget actionButton({
      required IconData icon,
      required String label,
      required Future<void> Function() onTap,
    }) {
      return Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              actionButton(
                icon: Icons.refresh,
                label: t.redownload,
                onTap: manager.retryFailed,
              ),
              const SizedBox(width: 6),
              actionButton(
                icon: Icons.play_arrow,
                label: t.startAll,
                onTap: manager.resumeAll,
              ),
              const SizedBox(width: 6),
              actionButton(
                icon: Icons.pause,
                label: t.pauseAll,
                onTap: manager.pauseAll,
              ),
              const SizedBox(width: 6),
              actionButton(
                icon: Icons.delete_outline,
                label: t.cancelAll,
                onTap: manager.cancelAll,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final t in unfinished) _DownloadTile(task: t),
            ],
          ),
        ),
      ],
    );
  }
}

/// 下载记录 tab：已完成的下载（本地播放 / 外部播放 / 删除）
class _RecordsTab extends StatefulWidget {
  const _RecordsTab();

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  List<Map<String, dynamic>> _records = [];

  /// filePath → 文件是否仍存在
  final Map<String, bool> _exists = {};

  @override
  void initState() {
    super.initState();
    DownloadManager.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    DownloadManager.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final records = await DownloadManager.allRecords();
    final exists = <String, bool>{};
    for (final r in records) {
      final fp = r['filePath'] as String? ?? '';
      exists[fp] = fp.isNotEmpty && await File(fp).exists();
    }
    if (mounted) {
      setState(() {
        _records = records;
        _exists
          ..clear()
          ..addAll(exists);
      });
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
    try {
      await launchUrlString('file://$path');
    } catch (_) {}
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final path = r['filePath'] as String?;
    if (path == null || path.isEmpty) return;
    await DownloadManager.instance.deleteRecord(path);
    await _reload();
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: _records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final r = _records[index];
        final title = r['title'] as String? ?? '';
        final episode = r['episode'] as String? ?? '';
        final resolution = r['resolution'] as String? ?? '';
        final fp = r['filePath'] as String? ?? '';
        final exists = _exists[fp] ?? false;
        final time = (r['time'] as String? ?? '')
            .replaceAll('T', ' ')
            .replaceAll('.000', '');
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    exists
                        ? Icons.download_done
                        : Icons.error_outline,
                    color: exists ? Colors.green : colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.isNotEmpty
                              ? '$title · $episode'
                                  '${resolution.isNotEmpty ? ' · $resolution' : ''}'
                              : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: exists ? null : colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          exists ? time : '$time · ${t.deleted}',
                          style: TextStyle(
                            fontSize: 11,
                            color: exists
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (exists)
                    IconButton(
                      tooltip: t.openWithOtherPlayer,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.open_in_new, color: colorScheme.primary),
                      onPressed: () => _openExternal(r),
                    ),
                  IconButton(
                    tooltip: t.delete,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    onPressed: () => _delete(r),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _buildCover(context),
              const SizedBox(width: 12),
              Expanded(child: _buildInfo(context)),
              const SizedBox(width: 4),
              _buildActions(context),
            ],
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
      child = Image(
        image: CachedImageProvider(task.cover!, sourceKey: 'bangumi'),
        fit: BoxFit.cover,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 54,
        height: 72,
        child: child,
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        if (task.subtitle != null && task.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            task.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 6),
        _buildStatus(context),
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: task.progress,
            borderRadius: BorderRadius.circular(4),
            minHeight: 4,
          ),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued)
          IconButton(
            tooltip: t.pauseDownload,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.pause_circle_outline),
            onPressed: () => DownloadManager.instance.pause(task.id),
          ),
        if (task.status == DownloadStatus.paused ||
            task.status == DownloadStatus.failed)
          IconButton(
            tooltip: task.status == DownloadStatus.failed
                ? t.retryDownload
                : t.resumeDownload,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              task.status == DownloadStatus.failed
                  ? Icons.refresh
                  : Icons.play_circle_outline,
            ),
            onPressed: () => DownloadManager.instance.resume(task.id),
          ),
        IconButton(
          tooltip: t.delete,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          onPressed: () => DownloadManager.instance.cancel(task.id),
        ),
      ],
    );
  }

  Widget _buildStatus(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (task.status) {
      DownloadStatus.queued => (t.downloadQueued, colorScheme.onSurfaceVariant),
      DownloadStatus.downloading => (
        '${(task.progress * 100).toStringAsFixed(0)}%',
        colorScheme.primary,
      ),
      DownloadStatus.paused => (t.pausedDownload, colorScheme.onSurfaceVariant),
      DownloadStatus.completed => (
        '${t.downloadCompleted} · ${_shortPath(task.filePath)}',
        colorScheme.primary,
      ),
      DownloadStatus.failed => (t.downloadFailed, colorScheme.error),
    };
    return Text(
      label,
      style: TextStyle(fontSize: 12, color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _shortPath(String? path) {
    if (path == null || path.isEmpty) return '';
    return path.split('/').last.split('\\').last;
  }
}
