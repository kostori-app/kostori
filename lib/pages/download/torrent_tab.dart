import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';
import 'package:kostori/utils/io.dart';

/// 添加种子弹窗（供下载页 AppBar 调用）
Future<void> showAddTorrentSheet(BuildContext context) async {
  final magnetCtrl = TextEditingController();
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
                '${t.torrentSaveDir}: ${TorrentManager.downloadDir}',
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
              FilledButton.icon(
                onPressed: () async {
                  final magnet = magnetCtrl.text.trim();
                  if (magnet.isEmpty) {
                    App.rootContext.showMessage(message: t.torrentNeedMagnet);
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  App.rootContext.showMessage(message: t.torrentFetchingMeta);
                  await ProviderScope.containerOf(context)
                      .read(torrentManagerProvider.notifier)
                      .add(magnet, stopAfter: stopAfter);
                },
                icon: const Icon(Icons.check),
                label: Text(t.torrentParse),
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
  final total = job.totalWanted > 0 ? job.totalWanted : job.totalDone;
  if (total <= 0) return '${(job.progress * 100).toStringAsFixed(1)}%';
  final done = (job.progress * total).round().clamp(0, total);
  return '${formatBytesShort(done)} / ${formatBytesShort(total)}  '
      '${(job.progress * 100).toStringAsFixed(1)}%';
}

class _TorrentTabState extends ConsumerState<TorrentTab> {
  TorrentManager get _m => ref.read(torrentManagerProvider.notifier);
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
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
      if (j.status == TorrentJobStatus.paused) await _m.resume(j);
    }
  }

  void _pauseAll() {
    for (final j in _m.jobs) {
      if (j.status == TorrentJobStatus.downloading ||
          j.status == TorrentJobStatus.metadata) {
        _m.pause(j);
      }
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
          child: ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            children: [for (final job in jobs) _jobCard(job)],
          ),
        ),
      ],
    );
  }

  Widget _jobCard(TorrentJob job) {
    final cs = Theme.of(context).colorScheme;
    final paused = job.status == TorrentJobStatus.paused;
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
                            job.name.isNotEmpty
                                ? job.name
                                : t.torrentFetchingMeta,
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
                  value: job.hasMetadata ? job.progress : null,
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
                    if (!job.isFinished)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                        tooltip: paused ? t.torrentResume : t.torrentPause,
                        onPressed: () =>
                            paused ? _m.resume(job) : _m.pause(job),
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
      builder: (_) => _TorrentDetailSheet(job: job),
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
        TextButton(
          onPressed: () {
            navigator.pop();
            _m.remove(job, deleteFiles: false);
          },
          child: Text(t.torrentDeleteTaskOnly),
        ),
        FilledButton(
          onPressed: () {
            navigator.pop();
            _m.remove(job);
          },
          child: Text(t.torrentDeleteWithFiles),
        ),
      ],
    );
  }
}

/// 种子详情：基本信息 / 内容（可左右滑动切换）
class _TorrentDetailSheet extends ConsumerStatefulWidget {
  const _TorrentDetailSheet({required this.job});

  final TorrentJob job;

  @override
  ConsumerState<_TorrentDetailSheet> createState() =>
      _TorrentDetailSheetState();
}

class _TorrentDetailSheetState extends ConsumerState<_TorrentDetailSheet>
    with SingleTickerProviderStateMixin {
  TorrentManager get _m => ref.read(torrentManagerProvider.notifier);

  /// 0 = 基本信息，1 = 内容（可左右滑动切换）
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  List<TorrentFileEntry> _files = const [];

  /// 长按范围选择的起点（第一个长按的文件下标）
  int? _rangeAnchor;

  @override
  void initState() {
    super.initState();
    _refreshFiles();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _refreshFiles() {
    _files = _m.filesOf(widget.job);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    ref.watch(torrentManagerProvider);
    _refreshFiles();
    return Sheet(
      title: job.name.isNotEmpty ? job.name : t.torrentFetchingMeta,
      icon: Icons.stream,
      initialSize: 0.8,
      builder: (_, _) => Column(
        children: [
          CapsuleTabBar(
            controller: _tabCtrl,
            labels: [t.torrentInfo, t.torrentContent],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: _infoSection(job),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: _contentSection(job),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 基本信息 ──────────────────────────────────────────────────────────────
  List<Widget> _infoSection(TorrentJob job) {
    final total = job.totalWanted > 0 ? job.totalWanted : job.totalDone;
    final done = total > 0 ? (job.progress * total).round().clamp(0, total) : 0;
    return [
      _infoRow(t.status, _statusLabel(job.status)),
      _infoRow(
        t.torrentProgressLabel,
        job.hasMetadata ? '${(job.progress * 100).toStringAsFixed(1)}%' : '--',
      ),
      _infoRow(
        t.download,
        job.hasMetadata && total > 0
            ? '${formatBytesShort(done)} / ${formatBytesShort(total)}'
            : '--',
      ),
      _infoRow(t.torrentDownloadLimit, '↓ ${formatSpeed(job.downloadRate)}'),
      _infoRow(t.torrentUploadLimit, '↑ ${formatSpeed(job.uploadRate)}'),
      _infoRow(t.torrentPeers, '${job.numPeers}/${job.numSeeds}'),
      _infoRow(t.torrentSavePathLabel, TorrentManager.downloadDir),
      if (job.infoHash.isNotEmpty)
        _infoRow(t.torrentInfoHashLabel, job.infoHash),
      if (job.error != null && job.error!.isNotEmpty)
        _infoRow(t.downloadFailed, job.error!),
    ];
  }

  // ── 内容：文件列表（大小 + 已下/未下 + 单文件进度） ────────────────────────
  List<Widget> _contentSection(TorrentJob job) {
    final cs = Theme.of(context).colorScheme;
    if (_files.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            job.hasMetadata ? t.torrentPickFile : t.torrentFetchingMeta,
            style: TextStyle(color: cs.outline),
          ),
        ),
      ];
    }
    final all = {for (final f in _files) f.index};
    final selected = _selectedIndices(job);
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Text(
              t.torrentSelectFiles,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            _selectAction(t.selectAll, () => _setSelection(job, all)),
            _selectAction(t.selectNone, () => _setSelection(job, <int>{})),
            _selectAction(t.invertSelection, () => _invertSelection(job)),
          ],
        ),
      ),
      for (final f in _files) _fileTile(job, f, selected.contains(f.index)),
    ];
  }

  Widget _selectAction(String label, VoidCallback onTap) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: onTap,
    child: Text(label),
  );

  /// 当前选中下标集合（空 selectedFiles = 全部；[kTorrentNoFile] = 全不选）
  Set<int> _selectedIndices(TorrentJob job) {
    final all = {for (final f in _files) f.index};
    final sel = job.selectedFiles;
    if (sel.length == 1 && sel.first == kTorrentNoFile) return <int>{};
    if (sel.isEmpty) return all;
    return sel.where(all.contains).toSet();
  }

  void _setSelection(TorrentJob job, Set<int> set) {
    final all = {for (final f in _files) f.index};
    if (set.isEmpty) {
      _m.setSelectedFiles(job, const [kTorrentNoFile]);
      return;
    }
    if (set.length >= all.length) {
      _m.setSelectedFiles(job, const []); // 空 = 全部
      return;
    }
    _m.setSelectedFiles(job, set.toList()..sort());
  }

  void _invertSelection(TorrentJob job) {
    final all = {for (final f in _files) f.index};
    _setSelection(job, all.difference(_selectedIndices(job)));
  }

  void _toggleFile(TorrentJob job, int index) {
    _rangeAnchor = null;
    final sel = _selectedIndices(job).toSet();
    if (!sel.remove(index)) sel.add(index);
    _setSelection(job, sel);
  }

  /// 长按起始文件后再长按结束文件 = 选中两者之间整段
  void _longPressFile(TorrentJob job, int index) {
    final anchor = _rangeAnchor;
    if (anchor == null) {
      _rangeAnchor = index;
      _setSelection(job, _selectedIndices(job)..add(index));
      setState(() {});
      return;
    }
    final lo = anchor < index ? anchor : index;
    final hi = anchor < index ? index : anchor;
    final sel = _selectedIndices(job).toSet();
    for (var i = lo; i <= hi; i++) {
      sel.add(i);
    }
    _rangeAnchor = null;
    _setSelection(job, sel);
    setState(() {});
  }

  Widget _fileTile(TorrentJob job, TorrentFileEntry f, bool selected) {
    final cs = Theme.of(context).colorScheme;
    final done = f.completed;
    final pct = (f.progress * 100).clamp(0, 100).toStringAsFixed(0);
    final statusText = done
        ? t.torrentFileDone
        : f.isDownloading
        ? t.torrentFileDownloading
        : t.torrentFilePending;
    final statusColor = done
        ? cs.primary
        : f.isDownloading
        ? cs.tertiary
        : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? cs.primaryContainer.withValues(alpha: 0.45)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _toggleFile(job, f.index),
          onLongPress: () => _longPressFile(job, f.index),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: f.size > 0 ? f.progress : null,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${formatBytesShort(f.downloaded)} / '
                            '${formatBytesShort(f.size)}  $pct%',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: done || f.isDownloading
                                  ? FontWeight.w500
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (f.isStreamable)
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    tooltip: t.torrentPlay,
                    onPressed: () => _play(f.index),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Future<void> _play(int fileIndex) async {
    final url = await _m.streamUrl(widget.job, fileIndex);
    if (!mounted) return;
    context.to(
      () => LocalPlayerPage(
        filePath: url,
        onDispose: () => _m.stopStreams(widget.job),
      ),
    );
  }
}
