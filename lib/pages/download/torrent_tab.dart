import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';
import 'package:kostori/services/torrent/torrent_task.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

/// 添加种子弹窗（供下载页 AppBar 调用）
Future<void> showAddTorrentSheet(BuildContext context) async {
  final magnetCtrl = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Sheet(
      title: t.torrentAdd,
      icon: Icons.add_link,
      initialSize: 0.45,
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final magnet = magnetCtrl.text.trim();
                if (magnet.isEmpty) {
                  App.rootContext.showMessage(message: t.torrentNeedMagnet);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await TorrentManager.instance.add(magnet);
              },
              icon: const Icon(Icons.check),
              label: Text(t.torrentParse),
            ),
          ],
        ),
      ),
    ),
  );
  magnetCtrl.dispose();
}

/// 下载页「种子」Tab：一个种子 = 一张卡片；点击进详情。
class TorrentTab extends StatefulWidget {
  const TorrentTab({super.key});

  @override
  State<TorrentTab> createState() => _TorrentTabState();
}

class _TorrentTabState extends State<TorrentTab> {
  final _m = TorrentManager.instance;

  @override
  void initState() {
    super.initState();
    _m.init();
    _m.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _m.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _m.tasks;
    if (tasks.isEmpty) {
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
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      children: [for (final task in tasks) _taskCard(task)],
    );
  }

  String _statusLabel(TorrentTaskStatus s) {
    switch (s) {
      case TorrentTaskStatus.metadata:
        return t.torrentStatusMetadata;
      case TorrentTaskStatus.downloading:
        return t.torrentStatusDownloading;
      case TorrentTaskStatus.paused:
        return t.torrentStatusPaused;
      case TorrentTaskStatus.completed:
        return t.torrentStatusCompleted;
      case TorrentTaskStatus.failed:
        return t.torrentStatusFailed;
    }
  }

  Widget _taskCard(TorrentTask task) {
    final cs = Theme.of(context).colorScheme;
    final paused = task.status == TorrentTaskStatus.paused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetailSheet(task),
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
                        task.isFinished
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
                            task.name.isNotEmpty
                                ? task.name
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
                            '${_statusLabel(task.status)} · '
                            '${t.torrentPeers} ${task.numPeers}/${task.numSeeds}',
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
                  value: task.hasMetadata ? task.progress : null,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 4,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.hasMetadata
                            ? '${formatBytes(task.totalDone)} / '
                                  '${formatBytes(task.totalWanted)}  '
                                  '${(task.progress * 100).toStringAsFixed(1)}%'
                            : _statusLabel(task.status),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '↓ ${formatSpeed(task.downloadRate)}  '
                      '↑ ${formatSpeed(task.uploadRate)}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        paused ? Icons.play_arrow : Icons.pause_circle_outline,
                      ),
                      tooltip: paused ? t.torrentPlay : t.torrentStatusPaused,
                      onPressed: () =>
                          paused ? _m.resume(task) : _m.pause(task),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: t.torrentDelete,
                      onPressed: () => _m.remove(task),
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

  Future<void> _showDetailSheet(TorrentTask task) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TorrentDetailSheet(task: task, manager: _m),
    );
  }
}

/// 种子详情：基本信息 + 内容（文件卡片，观看按钮在右）
class _TorrentDetailSheet extends StatefulWidget {
  const _TorrentDetailSheet({required this.task, required this.manager});

  final TorrentTask task;
  final TorrentManager manager;

  @override
  State<_TorrentDetailSheet> createState() => _TorrentDetailSheetState();
}

class _TorrentDetailSheetState extends State<_TorrentDetailSheet> {
  final _m = TorrentManager.instance;

  @override
  void initState() {
    super.initState();
    _m.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _m.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final files = _m.filesOf(task);
    final cs = Theme.of(context).colorScheme;
    return Sheet(
      title: task.name.isNotEmpty ? task.name : t.torrentFetchingMeta,
      icon: Icons.stream,
      initialSize: 0.8,
      builder: (ctx, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            t.torrentInfo,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _infoRow(t.status, _statusLabel(task.status)),
          _infoRow(
            t.torrentProgressLabel,
            task.hasMetadata
                ? '${(task.progress * 100).toStringAsFixed(1)}%'
                : '--',
          ),
          _infoRow(
            t.download,
            task.hasMetadata
                ? '${formatBytes(task.totalDone)} / '
                      '${formatBytes(task.totalWanted)}'
                : '--',
          ),
          _infoRow(
            t.torrentDownloadLimit,
            '↓ ${formatSpeed(task.downloadRate)}',
          ),
          _infoRow(t.torrentUploadLimit, '↑ ${formatSpeed(task.uploadRate)}'),
          _infoRow(
            t.torrentPeers,
            '${task.numPeers}/${task.numSeeds}',
          ),
          _infoRow(t.torrentSavePathLabel, TorrentManager.downloadDir),
          if (task.infoHash.isNotEmpty)
            _infoRow(t.torrentInfoHashLabel, task.infoHash),
          const SizedBox(height: 12),
          Text(
            t.torrentContent,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                task.hasMetadata ? t.torrentPickFile : t.torrentFetchingMeta,
                style: TextStyle(color: cs.outline),
              ),
            )
          else
            for (final f in files)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
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
                              Text(
                                formatBytes(f.size),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
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
        ],
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
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _statusLabel(TorrentTaskStatus s) {
    switch (s) {
      case TorrentTaskStatus.metadata:
        return t.torrentStatusMetadata;
      case TorrentTaskStatus.downloading:
        return t.torrentStatusDownloading;
      case TorrentTaskStatus.paused:
        return t.torrentStatusPaused;
      case TorrentTaskStatus.completed:
        return t.torrentStatusCompleted;
      case TorrentTaskStatus.failed:
        return t.torrentStatusFailed;
    }
  }

  void _play(int fileIndex) {
    final url = _m.startStream(widget.task, fileIndex).url;
    if (!mounted) return;
    context.to(() => LocalPlayerPage(filePath: url));
  }
}
