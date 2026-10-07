import 'dart:math' as math;

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' show TaskState;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/empty_state.dart';
import 'package:kostori/components/torrent_file_list.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';
import 'package:kostori/services/torrent/torrent_network.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/foundation/context.dart';

class TorrentDetailSheet extends ConsumerStatefulWidget {
  const TorrentDetailSheet({super.key, required this.job});
  final TorrentJob job;

  @override
  ConsumerState<TorrentDetailSheet> createState() => _TorrentDetailSheetState();
}

class _TorrentDetailSheetState extends ConsumerState<TorrentDetailSheet>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 5, vsync: this);
  final Map<String, ({int users, int seeds, int downloaded, int? downloaders})>
  _stats = {};
  final Map<String, String> _errors = {};
  final Set<String> _refreshing = {};
  bool _runBusy = false;
  bool _deleteBusy = false;
  late final TorrentManager _manager;
  TorrentJob get _job => widget.job;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(torrentManagerProvider.notifier);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _status(TorrentJobStatus status) => switch (status) {
    TorrentJobStatus.metadata => t.torrentStatusMetadata,
    TorrentJobStatus.downloading => t.torrentStatusDownloading,
    TorrentJobStatus.paused => t.torrentStatusPaused,
    TorrentJobStatus.completed => t.torrentStatusCompleted,
    TorrentJobStatus.failed => t.torrentStatusFailed,
  };

  @override
  Widget build(BuildContext context) {
    ref.watch(torrentManagerProvider);
    final files = _manager.filesOf(_job);
    final wanted = _job.selectedFiles.isEmpty
        ? files.map((file) => file.index).toSet()
        : _job.selectedFiles.where((index) => index >= 0).toSet();
    return Sheet(
      title: _job.name.isEmpty ? t.torrentTab : _job.name,
      initialSize: 0.92,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Button.icon(
            icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
            tooltip: _isRunning ? t.torrentPause : t.torrentResume,
            isLoading: _runBusy,
            onPressed: _toggleRun,
          ),
          Button.icon(
            icon: const Icon(Icons.delete_outline),
            tooltip: t.torrentDelete,
            isLoading: _deleteBusy,
            onPressed: _delete,
          ),
        ],
      ),
      builder: (_, _) => Column(
        children: [
          AppTabBar(
            controller: _tabs,
            tabs: [
              Tab(text: t.overview),
              Tab(text: t.torrentFilesTab),
              Tab(text: t.torrentTrackersTab),
              Tab(text: t.torrentUsersTab),
              Tab(text: t.torrentHttpSourcesTab),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _overview(files),
                TorrentFileList(
                  files: files,
                  wanted: wanted,
                  priorities: _job.filePriorities,
                  emptyMessage: _job.isFetchingMeta
                      ? t.torrentFetchingMeta
                      : t.torrentFilesEmpty,
                  onPlay: _play,
                  onRename: _rename,
                  onSetPriority: (indices, priority) {
                    _manager.setFilePriority(_job, indices, priority);
                  },
                  onDeleteFiles: _deleteFiles,
                ),
                _trackers(),
                _users(),
                _httpSources(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isRunning {
    if (_job.isFetchingMeta || _job.status == TorrentJobStatus.downloading) {
      return true;
    }
    return _job.status == TorrentJobStatus.completed &&
        _manager.engineOf(_job)?.state == TaskState.running;
  }

  Future<void> _toggleRun() async {
    if (_runBusy) return;
    final running = _isRunning;
    setState(() => _runBusy = true);
    try {
      if (running) {
        _manager.pause(_job);
      } else {
        await _manager.resume(
          _job,
          isRetry: _job.status == TorrentJobStatus.failed,
        );
      }
    } catch (error) {
      if (mounted) {
        context.showMessage(message: '${t.downloadFailed}: $error');
      }
    } finally {
      if (mounted) setState(() => _runBusy = false);
    }
  }

  Widget _overview(List<TorrentFileEntry> files) {
    final model = _manager.modelOf(_job);
    final engine = _manager.engineOf(_job);
    final bitfield = engine?.fileManager?.localBitfield;
    final completed = bitfield?.completedPieces.toSet() ?? <int>{};
    final pieces = model?.pieces?.length ?? 0;
    final cs = Theme.of(context).colorScheme;
    final isCompleted =
        !_job.isFetchingMeta && _job.totalWanted > 0 && _job.progress >= 1.0;
    final displayedDone = isCompleted ? _job.totalWanted : _job.totalDone;
    final displayedProgress = isCompleted ? 1.0 : _job.progress;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(_job.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text(
          '${formatBytesShort(displayedDone)} / ${formatBytesShort(_job.totalWanted)} · '
          '${(displayedProgress * 100).toStringAsFixed(1)}%',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: _job.isFetchingMeta ? 0 : displayedProgress,
          minHeight: 4,
        ),
        const SizedBox(height: 10),
        Text(
          _status(_job.status),
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        if (_job.error != null && !isCompleted) ...[
          const SizedBox(height: 10),
          Text(_job.error!, style: TextStyle(color: cs.error, fontSize: 12)),
        ],
        if (pieces > 0) ...[
          _heading(t.torrentPieces),
          SizedBox(
            height: 36,
            width: double.infinity,
            child: CustomPaint(
              painter: _PiecesPainter(
                pieces,
                completed,
                cs.primary,
                cs.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.torrentPieceSummary(
              done: completed.length,
              total: pieces,
              size: formatBytesShort(model!.pieceLength),
            ),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
        _heading(t.torrentInfo),
        _info(
          t.torrentTotalSize,
          formatBytesShort(files.fold<int>(0, (sum, file) => sum + file.size)),
        ),
        _info(
          t.torrentAddedAt,
          DateTime.fromMillisecondsSinceEpoch(_job.createdAt)
              .toLocal()
              .toString()
              .split('.')
              .first,
        ),
        _info(t.torrentInfoHashLabel, _job.infoHash, copy: true),
        _info(t.torrentMagnetLinkLabel, _job.magnet, copy: true),
        _info(t.torrentSavePathLabel, _job.savePath, copy: true),
        _info(t.torrentFileCount, '${files.length}'),
        _heading(t.torrentTransfer),
        _info(
          t.download,
          isCompleted
              ? '${formatBytesShort(displayedDone)} / '
                    '${formatBytesShort(_job.totalWanted)}'
              : '${formatSpeed(_job.downloadRate)} / '
                    '${formatBytesShort(displayedDone)}',
        ),
        _info(t.upload, formatSpeed(_job.uploadRate)),
        _info(t.torrentUploadedTotal, formatBytesShort(_job.uploadedBytes)),
        _info(t.torrentSeedRatio, _seedRatio),
        _info(t.torrentSeedDuration, _seedDuration),
        _info(t.torrentPeers, '${_job.numPeers}'),
        _info(t.torrentSeeds, '${_job.numSeeds}'),
        _info(t.torrentLeechers, '${_job.numDownloaders}'),
        _info(t.torrentTrackersTab, '${_manager.trackersOf(_job).length}'),
        _info(t.torrentDht, '${_manager.dhtNodes.length}'),
      ],
    );
  }

  String get _seedRatio {
    if (_job.seedingStartedAt == null || _job.totalWanted <= 0) return '--';
    return (_job.uploadedBytes / _job.totalWanted).toStringAsFixed(2);
  }

  String get _seedDuration {
    final startedAt = _job.seedingStartedAt;
    if (startedAt == null) return '--';
    final duration = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(startedAt),
    );
    String pad(int value) => value.toString().padLeft(2, '0');
    final hours = pad(duration.inHours);
    final minutes = pad(duration.inMinutes % 60);
    final seconds = pad(duration.inSeconds % 60);
    return '$hours:$minutes:$seconds';
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _info(String label, String value, {bool copy = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: AppSelectableText(
            value.isEmpty ? '--' : value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        if (copy)
          Button.icon(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: t.copy,
            onPressed: () => _copy(value),
          ),
      ],
    ),
  );

  Widget _trackers() {
    final engine = _manager.engineOf(_job);
    final peers = engine?.activePeers?.toList() ?? [];
    final sources = <String, int>{};
    for (final peer in peers) {
      sources.update(peer.source.name, (count) => count + 1, ifAbsent: () => 1);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        for (final source in [('DHT', 'dht'), ('PeX', 'pex'), ('LSD', 'lsd')])
          _trackerRow(source.$1, users: sources[source.$2] ?? 0),
        for (final url in _manager.trackersOf(_job))
          _trackerRow(
            url,
            users: _stats[url]?.users,
            seeds: _stats[url]?.seeds,
            downloaders: _stats[url]?.downloaders,
            downloaded: _stats[url]?.downloaded,
            url: url,
          ),
      ],
    );
  }

  Widget _trackerRow(
    String title, {
    int? users,
    int? seeds,
    int? downloaders,
    int? downloaded,
    String? url,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppSelectableText(
                      title,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (url != null)
                    Button.icon(
                      icon: const Icon(Icons.refresh, size: 19),
                      tooltip: t.refresh,
                      isLoading: _refreshing.contains(url),
                      onPressed: () => _refreshTracker(url),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat(Icons.people_outline, t.torrentUsersTab, users),
                  _stat(Icons.arrow_upward, t.torrentSeeds, seeds),
                  _stat(Icons.arrow_downward, t.torrentLeechers, downloaders),
                  _stat(Icons.download_done, t.torrentDownloaded, downloaded),
                ],
              ),
              if (_errors.containsKey(url))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    t.torrentTrackerUnavailable,
                    style: TextStyle(color: cs.error, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, int? value) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 6),
        Text(value?.toString() ?? '--', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Future<void> _refreshTracker(String url) async {
    final engine = _manager.engineOf(_job);
    if (engine == null || !_refreshing.add(url)) return;
    setState(() {});
    try {
      final result = await TorrentNetwork.run(
        () => engine.scrapeTracker(Uri.parse(url)),
      ).timeout(const Duration(seconds: 12));
      final stats = result.getStatsForInfoHash(_job.infoHash);
      if (!mounted) return;
      setState(() {
        if (stats == null || !result.isSuccess) {
          _errors[url] = result.error ?? '';
        } else {
          _errors.remove(url);
          _stats[url] = (
            users: stats.incomplete + stats.complete,
            seeds: stats.complete,
            downloaded: stats.downloaded,
            downloaders: stats.downloaders ?? stats.incomplete,
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _errors[url] = '');
    } finally {
      if (mounted) setState(() => _refreshing.remove(url));
    }
  }

  Widget _users() {
    final peers =
        _manager
            .engineOf(_job)
            ?.activePeers
            ?.where((peer) => !peer.isDisposed)
            .toList() ??
        [];
    if (peers.isEmpty) return EmptyState(message: t.torrentUsersEmpty);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: peers.length,
      itemBuilder: (_, index) {
        final peer = peers[index];
        final progress = peer.remoteBitfield?.piecesNum == 0
            ? 0.0
            : peer.remoteCompletePieces.length /
                  (peer.remoteBitfield?.piecesNum ?? 1);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    peer.isSeeder ? Icons.upload : Icons.people_outline,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          torrentPeerClientName(peer.remotePeerId) ??
                              t.torrentPeerUnknownClient,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppSelectableText(
                          peer.address.toContactEncodingString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    peer.type.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
              ),
              const SizedBox(height: 6),
              Text(
                '${(progress * 100).toStringAsFixed(1)}% · ${peer.source.name.toUpperCase()} · '
                '↓ ${formatSpeed((peer.currentDownloadSpeed * 1024).round())} · '
                '↑ ${formatSpeed((peer.averageUploadSpeed * 1024).round())}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
            ],
          ),
        );
      },
    );
  }

  Widget _httpSources() {
    final sources = _manager.httpSourcesOf(_job);
    if (sources.isEmpty) return EmptyState(message: t.torrentHttpSourcesEmpty);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final source in sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.http),
                const SizedBox(width: 12),
                Expanded(
                  child: AppSelectableText(
                    source,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Button.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: t.copy,
                  onPressed: () => _copy(source),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    context.showMessage(message: t.copySuccess);
  }

  Future<Object?> _rename(int index, String name) async {
    if (!TorrentManager.isValidFileName(name)) return t.torrentInvalidFileName;
    try {
      await _manager.renameFile(_job, index, name);
      return null;
    } on FileSystemException {
      return t.torrentRenameFailed;
    } catch (error) {
      Log.error('种子文件改名失败', '$error');
      return t.torrentRenameFailed;
    }
  }

  Future<void> _deleteFiles(Set<int> indices) async {
    if (indices.isEmpty) return;
    final confirmed = await ContentDialog.show<bool>(
      context: context,
      title: t.torrentDeleteFiles,
      content: Text(t.torrentDeleteFilesConfirm),
      actions: [
        Button.text(onPressed: () => context.pop(false), child: Text(t.cancel)),
        Button.filled(
          onPressed: () => context.pop(true),
          child: Text(t.confirm),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    try {
      await _manager.deleteFiles(_job, indices);
    } catch (error) {
      Log.error('种子内容删除失败', '$error');
      if (mounted) context.showMessage(message: t.deleteFailed);
    }
  }

  Future<void> _play(int index) async {
    try {
      final url = await _manager.streamUrl(_job, index);
      if (!mounted) return;
      context.to(
        () => LocalPlayerPage(
          filePath: url,
          // 捕获已经解析出的管理器实例；播放器销毁时详情页可能已经
          // 卸载，此时再通过 ref.read 会触发 Riverpod 的生命周期断言。
          onDispose: () => _manager.stopStreams(_job),
        ),
      );
    } catch (error) {
      Log.error('种子播放失败', '$error');
      if (mounted) context.showMessage(message: t.torrentPlaybackFailed);
    }
  }

  void _delete() {
    if (_deleteBusy) return;
    ContentDialog.show(
      context: context,
      title: t.torrentDelete,
      content: Text(t.torrentDeleteConfirm),
      actions: [
        Button.text(
          onPressed: () {
            context.pop();
            _removeJob(deleteFiles: false);
          },
          child: Text(t.torrentDeleteTaskOnly),
        ),
        Button.filled(
          onPressed: () {
            context.pop();
            _removeJob(deleteFiles: true);
          },
          child: Text(t.torrentDeleteWithFiles),
        ),
      ],
    );
  }

  Future<void> _removeJob({required bool deleteFiles}) async {
    setState(() => _deleteBusy = true);
    try {
      await _manager.remove(_job, deleteFiles: deleteFiles);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) context.showMessage(message: t.deleteFailed);
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }
}

class _PiecesPainter extends CustomPainter {
  _PiecesPainter(this.total, this.completed, this.doneColor, this.pendingColor);
  final int total;
  final Set<int> completed;
  final Color doneColor;
  final Color pendingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bins = math.min(total, 200);
    if (bins <= 0) return;
    final paint = Paint();
    for (var bin = 0; bin < bins; bin++) {
      final start = bin * total ~/ bins;
      final end = (bin + 1) * total ~/ bins;
      var done = 0;
      for (var piece = start; piece < end; piece++) {
        if (completed.contains(piece)) done++;
      }
      paint.color = Color.lerp(pendingColor, doneColor, done / (end - start))!;
      canvas.drawRect(
        Rect.fromLTWH(
          bin * size.width / bins,
          0,
          size.width / bins,
          size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PiecesPainter oldDelegate) => true;
}
