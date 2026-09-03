import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:kostori/services/download/download_task.dart';
import 'package:kostori/network/external_player.dart';
import 'package:kostori/utils/io.dart';

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconTileButton(
                icon: const Icon(Icons.refresh),
                label: t.redownload,
                onTap: () {
                  manager.retryFailed();
                },
              ),
              const SizedBox(width: 4),
              IconTileButton(
                icon: const Icon(Icons.play_arrow),
                label: t.startAll,
                onTap: () {
                  manager.resumeAll();
                },
              ),
              const SizedBox(width: 4),
              IconTileButton(
                icon: const Icon(Icons.pause),
                label: t.pauseAll,
                onTap: () {
                  manager.pauseAll();
                },
              ),
              const SizedBox(width: 4),
              IconTileButton(
                icon: const Icon(Icons.delete_outline),
                label: t.cancelAll,
                onTap: () {
                  manager.cancelAll();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final (i, t) in unfinished.indexed)
                _DownloadTile(index: i + 1, task: t),
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

  /// filePath → 文件大小（字节）
  final Map<String, int> _sizes = {};

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
    final sizes = <String, int>{};
    for (final r in records) {
      final fp = r['filePath'] as String? ?? '';
      final f = File(fp);
      exists[fp] = fp.isNotEmpty && await f.exists();
      if (exists[fp] == true) {
        sizes[fp] = await f.length();
      }
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
        final sourceKey = r['sourceKey'] as String? ?? '';
        final sourceName = sourceKey.isEmpty
            ? ''
            : (AnimeSource.find(sourceKey)?.name ?? sourceKey);
        final exists = _exists[fp] ?? false;
        final time = (r['time'] as String? ?? '')
            .replaceAll('T', ' ')
            .replaceAll('.000', '');

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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                        chip(_formatBytes(_sizes[fp] ?? 0))
                      else
                        chip(t.deleted, textColor: colorScheme.onError),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 操作按钮：放到底部居中
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.index, required this.task});

  final int index;

  final DownloadTask task;

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
            // 左上角圆形序号徽章
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
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
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
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
      _formatBytes(task.downloadedBytes),
      if (task.totalBytes > 0) _formatBytes(task.totalBytes),
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
          tooltip: t.delete,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          icon: Icon(Icons.close, color: colorScheme.error),
          onPressed: () => DownloadManager.instance.cancel(task.id),
        ),
      ],
    );
  }

  void _showError(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: '${t.downloadFailed} · ${task.title}',
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: SelectableText(
              task.error ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.close),
          ),
        ],
      ),
    );
  }

  /// 来源/分辨率元信息行（无来源且无分辨率时隐藏）
  Widget _buildMetaRow(BuildContext context) {
    final String? src = task.sourceKey == null
        ? null
        : AnimeSource.find(task.sourceKey!)?.name;
    final res = task.resolution?.trim();
    final parts = <String>[
      if (src != null && src.isNotEmpty) src,
      if (res != null && res.isNotEmpty) res,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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
      final pct = (task.progress * 100).clamp(0.0, 100.0).toStringAsFixed(0);
      final speed = _formatSpeed(task.downloadSpeed);
      return Row(
        children: [
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          if (speed.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              speed,
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

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '';
    if (bytesPerSec < 1024) {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}
