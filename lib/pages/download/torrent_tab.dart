import 'dart:async';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' show TaskState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/torrent/indexer/bt_indexer.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';
import 'package:kostori/pages/download/torrent_detail_sheet.dart';
import 'package:kostori/utils/io.dart';

/// 添加种子弹窗（供下载页 AppBar 与选中文本菜单调用）。
/// [initialMagnet] 非空时预填磁力输入框（如从选中文本里的磁力链进入）。
Future<void> showAddTorrentSheet(
  BuildContext context, {
  String? initialMagnet,
}) async {
  final magnetCtrl = TextEditingController(
    // 预填时先规范化：插件传来的可能是裸 40 位信息哈希
    text: initialMagnet == null ? '' : normalizeMagnet(initialMagnet),
  );
  var stopAfter = TorrentStopPolicy.none;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => Sheet(
        title: t.torrentAdd,
        icon: Icons.add_link,
        initialSize: 0.6,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: magnetCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: t.torrentMagnetHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${t.torrentSaveDir}: ${TorrentManager.torrentDownloadDir}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(ctx).colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Text(t.torrentStopAfter, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              CapsuleOptions(
                wrap: true,
                alignment: WrapAlignment.center,
                children: [
                  CapsuleOption(
                    text: t.torrentStopNone,
                    isSelected: stopAfter == TorrentStopPolicy.none,
                    onTap: () =>
                        setSt(() => stopAfter = TorrentStopPolicy.none),
                  ),
                  CapsuleOption(
                    text: t.torrentStopAfterMetadata,
                    isSelected: stopAfter == TorrentStopPolicy.afterMetadata,
                    onTap: () => setSt(
                      () => stopAfter = TorrentStopPolicy.afterMetadata,
                    ),
                  ),
                  CapsuleOption(
                    text: t.torrentStopAfterDownload,
                    isSelected: stopAfter == TorrentStopPolicy.afterDownload,
                    onTap: () => setSt(
                      () => stopAfter = TorrentStopPolicy.afterDownload,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await selectFile(ext: ['torrent']);
                        if (picked == null) return;
                        final bytes = await picked.readAsBytes();
                        if (bytes.isEmpty) {
                          App.rootContext.showMessage(
                            message: t.downloadFailed,
                          );
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        App.rootContext.showMessage(
                          message: t.torrentFetchingMeta,
                        );
                        await ProviderScope.containerOf(context)
                            .read(torrentManagerProvider.notifier)
                            .addTorrentFile(bytes, stopAfter: stopAfter);
                      },
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(t.torrentImportFile),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final magnet = magnetCtrl.text.trim();
                        if (magnet.isEmpty) {
                          App.rootContext.showMessage(
                            message: t.torrentNeedMagnet,
                          );
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        App.rootContext.showMessage(
                          message: t.torrentFetchingMeta,
                        );
                        await ProviderScope.containerOf(context)
                            .read(torrentManagerProvider.notifier)
                            .add(magnet, stopAfter: stopAfter);
                      },
                      icon: const Icon(Icons.check),
                      label: Text(t.torrentParse),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  magnetCtrl.dispose();
}

/// 下载页「种子」Tab：一个种子 = 一张卡片；点击进详情。
class TorrentTab extends ConsumerStatefulWidget {
  const TorrentTab({super.key});

  @override
  ConsumerState<TorrentTab> createState() => _TorrentTabState();
}

String _statusLabel(TorrentJobStatus s) {
  switch (s) {
    case TorrentJobStatus.metadata:
      return t.torrentStatusMetadata;
    case TorrentJobStatus.downloading:
      return t.torrentStatusDownloading;
    case TorrentJobStatus.paused:
      return t.torrentStatusPaused;
    case TorrentJobStatus.completed:
      return t.torrentStatusCompleted;
    case TorrentJobStatus.failed:
      return t.torrentStatusFailed;
  }
}

/// 下载进度文本：已下载 / 总大小 + 百分比。
String _progressText(TorrentJob job) {
  if (job.isFinished) return '100.0%';
  final total = job.totalWanted > 0 ? job.totalWanted : job.totalDone;
  if (total <= 0) return '${(job.progress * 100).toStringAsFixed(1)}%';
  final done = (job.progress * total).round().clamp(0, total);
  return '${formatBytesShort(done)} / ${formatBytesShort(total)}  '
      '${(job.progress * 100).toStringAsFixed(1)}%';
}

/// 无种子名时的占位标题：仅抓取元数据阶段提示获取中，其余状态回退到 info hash。
String _jobTitle(TorrentJob job) {
  if (job.name.isNotEmpty) return job.name;
  if (job.isFetchingMeta) return t.torrentFetchingMeta;
  final hash = job.infoHash;
  if (hash.isEmpty) return t.torrentFetchingMeta;
  final upper = hash.toUpperCase();
  return upper.length > 12 ? 'BTIH ${upper.substring(0, 12)}…' : upper;
}

class _TorrentTabState extends ConsumerState<TorrentTab> {
  late final TorrentManager _manager;
  TorrentManager get _m => _manager;
  String _filter = 'all';
  final Set<String> _startingJobs = {};

  @override
  void initState() {
    super.initState();
    _manager = ref.read(torrentManagerProvider.notifier);
    _m.init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _matches(TorrentJob j) {
    switch (_filter) {
      case 'downloading':
        return j.status == TorrentJobStatus.downloading ||
            j.status == TorrentJobStatus.metadata;
      case 'paused':
        return j.status == TorrentJobStatus.paused;
      case 'completed':
        return j.status == TorrentJobStatus.completed;
      case 'failed':
        return j.status == TorrentJobStatus.failed;
    }
    return true;
  }

  Future<void> _startAll() async {
    for (final j in _m.jobs) {
      // _pauseAll 会连 metadata 状态一起暂停，「全部开始」必须也能把它恢复，
      // 否则被「全部暂停」停掉元数据任务后永远回不来。
      if (j.status == TorrentJobStatus.paused ||
          j.status == TorrentJobStatus.metadata ||
          j.status == TorrentJobStatus.failed) {
        await _m.resume(j, isRetry: j.status == TorrentJobStatus.failed);
      }
    }
  }

  void _pauseAll() {
    for (final j in _m.jobs) {
      final engineRunning = _m.engineOf(j)?.state == TaskState.running;
      if (j.status == TorrentJobStatus.downloading ||
          j.status == TorrentJobStatus.metadata ||
          (j.status == TorrentJobStatus.completed && engineRunning)) {
        _m.pause(j);
      }
    }
  }

  bool _isRunning(TorrentJob job) {
    if (job.isFetchingMeta || job.status == TorrentJobStatus.downloading) {
      return true;
    }
    return job.status == TorrentJobStatus.completed &&
        _m.engineOf(job)?.state == TaskState.running;
  }

  Future<void> _toggleJob(TorrentJob job) async {
    if (!_startingJobs.add(job.id)) return;
    setState(() {});
    try {
      if (_isRunning(job)) {
        _m.pause(job);
      } else {
        await _m.resume(job, isRetry: job.status == TorrentJobStatus.failed);
      }
    } catch (error) {
      if (mounted) context.showMessage(message: '${t.downloadFailed}: $error');
    } finally {
      _startingJobs.remove(job.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _clearCompleted() async {
    for (final j in List.of(_m.jobs)) {
      if (j.status == TorrentJobStatus.completed) {
        await _m.remove(j, deleteFiles: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(torrentManagerProvider).jobs;
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stream,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              t.torrentEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final jobs = all.where(_matches).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${t.all} (${all.length})',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        // 筛选胶囊 + 批量操作，同一行可横滑
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              CapsuleOptions(
                children: [
                  for (final (key, label) in [
                    ('all', t.all),
                    ('downloading', t.downloading),
                    ('paused', t.paused),
                    ('completed', t.completed),
                    ('failed', t.failed),
                  ])
                    CapsuleOption(
                      text: label,
                      isSelected: _filter == key,
                      onTap: () => setState(() => _filter = key),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              CapsuleButtonBar(
                padding: EdgeInsets.zero,
                children: [
                  Tooltip(
                    message: t.startAll,
                    child: CapsuleButton(
                      flat: true,
                      leading: const Icon(Icons.play_arrow),
                      onTap: _startAll,
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
                      onTap: _pauseAll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: t.torrentClearCompleted,
                    child: CapsuleButton(
                      flat: true,
                      leading: const Icon(Icons.delete_sweep_outlined),
                      onTap: _clearCompleted,
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
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            itemCount: jobs.length,
            itemBuilder: (context, index) =>
                RepaintBoundary(child: _jobCard(jobs[index])),
          ),
        ),
      ],
    );
  }

  Widget _jobCard(TorrentJob job) {
    final cs = Theme.of(context).colorScheme;
    final running = _isRunning(job);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetailSheet(job),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        job.isFinished
                            ? Icons.check_circle_outline
                            : job.isFetchingMeta
                            ? Icons.downloading_outlined
                            : Icons.stream,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _jobTitle(job),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_statusLabel(job.status)} · '
                            '${t.torrentPeers} ${job.numPeers}/${job.numSeeds}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  // 元数据阶段保持静态轨道，避免卡片反复闪动。
                  value: job.isFetchingMeta ? 0 : job.progress,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 4,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.hasMetadata
                            ? _progressText(job)
                            : _statusLabel(job.status),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '↓ ${formatSpeed(job.downloadRate)}  '
                      '↑ ${formatSpeed(job.uploadRate)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(running ? Icons.pause : Icons.play_arrow),
                      tooltip: running ? t.torrentPause : t.torrentResume,
                      onPressed: () => _toggleJob(job),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: t.torrentDelete,
                      onPressed: () => _confirmDelete(job),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetailSheet(TorrentJob job) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TorrentDetailSheet(job: job),
    );
  }

  /// 删除前询问是否连同已下载文件一起删除
  void _confirmDelete(TorrentJob job) {
    final navigator = Navigator.of(App.rootContext, rootNavigator: true);
    ContentDialog.show(
      context: App.rootContext,
      title: t.torrentDelete,
      content: Text(t.torrentDeleteConfirm),
      actions: [
        Button.text(
          onPressed: () {
            navigator.pop();
            _removeJob(job, deleteFiles: false);
          },
          child: Text(t.torrentDeleteTaskOnly),
        ),
        Button.filled(
          onPressed: () {
            navigator.pop();
            _removeJob(job, deleteFiles: true);
          },
          child: Text(t.torrentDeleteWithFiles),
        ),
      ],
    );
  }

  Future<void> _removeJob(TorrentJob job, {required bool deleteFiles}) async {
    try {
      await _m.remove(job, deleteFiles: deleteFiles);
    } catch (_) {
      if (mounted) context.showMessage(message: t.deleteFailed);
    }
  }
}
