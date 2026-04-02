import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';

class _DragState {
  final Duration position;
  final Duration duration;
  final Duration? dragPosition; // 非 null = 正在拖动

  const _DragState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.dragPosition,
  });

  bool get isDragging => dragPosition != null;

  Duration get display => dragPosition ?? position;

  _DragState copyWith({
    Duration? position,
    Duration? duration,
    Duration? dragPosition,
    bool clearDrag = false,
  }) => _DragState(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    dragPosition: clearDrag ? null : (dragPosition ?? this.dragPosition),
  );
}

class _DragNotifier extends StateNotifier<_DragState> {
  _DragNotifier() : super(const _DragState());

  DateTime? _cooldownUntil;

  void syncStatus(PlayerStatus status) {
    if (state.isDragging) return;
    if (_cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!)) {
      return;
    }
    state = state.copyWith(
      position: Duration(milliseconds: (status.position * 1000).toInt()),
      duration: Duration(milliseconds: (status.duration * 1000).toInt()),
    );
  }

  void dragStart(double positionSeconds) {
    final pos = Duration(milliseconds: (positionSeconds * 1000).toInt());
    state = state.copyWith(position: pos, dragPosition: pos);
  }

  void dragUpdate(double deltaDx, double widthPx) {
    if (state.duration.inMilliseconds == 0 || widthPx == 0) return;
    final deltaMs = (deltaDx * (180000 / widthPx)).round();
    final base = state.dragPosition ?? state.position;
    final next = Duration(
      milliseconds: (base.inMilliseconds + deltaMs).clamp(
        0,
        state.duration.inMilliseconds,
      ),
    );
    state = state.copyWith(dragPosition: next);
  }

  /// 返回最终位置供调用方 seek
  Duration dragEnd() {
    final finalPos = state.dragPosition ?? state.position;
    _cooldownUntil = DateTime.now().add(const Duration(seconds: 2));
    state = state.copyWith(position: finalPos, clearDrag: true);
    return finalPos;
  }
}

final _dragProvider =
    StateNotifierProvider.autoDispose<_DragNotifier, _DragState>(
      (ref) => _DragNotifier(),
    );

class RemoteControlPage extends ConsumerStatefulWidget {
  final LanDiscoveredDevice device;

  const RemoteControlPage({super.key, required this.device});

  @override
  ConsumerState<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends ConsumerState<RemoteControlPage> {
  bool _isConnected = false;
  bool _isSending = false;

  // Status sync state
  PlayerStatus? _playerStatus;
  CurrentAnime? _currentAnime;
  bool _isWaitingForData = true;

  @override
  void initState() {
    super.initState();
    _isConnected = LanControlClient.instance.isConnected;
    LanControlClient.instance.addStateChangedListener(_onConnectionChanged);
    _initStatusSync();
  }

  Future<void> _initStatusSync() async {
    // Listen to status sync updates
    LanControlClient.instance.addStatusSyncListener(_onStatusSync);

    // Request initial sync
    if (_isConnected) {
      await _requestStatusSync();
    }
  }

  void _onStatusSync(LanStatusSyncMessage message) {
    if (!mounted) return;
    // 转发给 provider，不再触发进度条重建
    if (message.playerStatus != null) {
      ref.read(_dragProvider.notifier).syncStatus(message.playerStatus!);
    }
    setState(() {
      _playerStatus = message.playerStatus;
      _currentAnime = message.currentAnime;
      _isWaitingForData = _playerStatus == null && _currentAnime == null;
    });
  }

  Future<void> _sendDirect(Future<void> Function() action) async {
    if (!_isConnected) return;
    try {
      await action();
    } catch (_) {}
  }

  Future<void> _requestStatusSync() async {
    try {
      final status = await LanControlClient.instance.requestStatusSync();
      if (status != null && mounted) {
        _onStatusSync(status);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWaitingForData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    LanControlClient.instance.removeStateChangedListener(_onConnectionChanged);
    LanControlClient.instance.removeStatusSyncListener(_onStatusSync);
    super.dispose();
  }

  void _onConnectionChanged(LanControlServiceState state, String? error) {
    if (!mounted) return;
    final wasConnected = _isConnected;
    setState(() {
      _isConnected = state == LanControlServiceState.connected;
    });
    HubLog.info(
      'RemoteControl',
      '_isConnected = $_isConnected (was $wasConnected), state = $state',
    );
    if (!_isConnected) {
      if (mounted) Navigator.pop(context);
    } else {
      _requestStatusSync();
    }
  }

  Future<void> _send(Future<void> Function() action) async {
    if (!_isConnected || _isSending) return;
    setState(() => _isSending = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _play() => _send(
    () => LanControlClient.instance.sendPlayerControl(PlayerControlAction.play),
  );

  Future<void> _pause() => _send(
    () =>
        LanControlClient.instance.sendPlayerControl(PlayerControlAction.pause),
  );

  Future<void> _seekForward() => _send(
    () => LanControlClient.instance.sendPlayerControl(
      PlayerControlAction.seekForward,
      10,
    ),
  );

  Future<void> _seekBack() => _send(
    () => LanControlClient.instance.sendPlayerControl(
      PlayerControlAction.seekBackward,
      10,
    ),
  );

  Future<void> _nextEpisode() => _send(
    () => LanControlClient.instance.sendPlayerControl(
      PlayerControlAction.nextEpisode,
    ),
  );

  Future<void> _prevEpisode() => _send(
    () => LanControlClient.instance.sendPlayerControl(
      PlayerControlAction.previousEpisode,
    ),
  );

  Future<void> _seekTo(Duration position) => _send(
    () => LanControlClient.instance.sendSeek(position.inSeconds.toDouble()),
  );

  Future<void> _selectEpisode(int episode) => _send(() async {
    if (_currentAnime != null) {
      await LanControlClient.instance.sendEpisodeSelect(
        animeId: _currentAnime!.animeId,
        source: _currentAnime!.source,
        episode: episode,
      );
    }
  });

  Future<void> _seekThenResume(Duration position, bool shouldResume) async {
    await _sendDirect(
      () => LanControlClient.instance.sendSeek(position.inSeconds.toDouble()),
    );
    if (shouldResume) {
      await _sendDirect(
        () => LanControlClient.instance.sendPlayerControl(
          PlayerControlAction.play,
        ),
      );
    }
  }

  void _disconnect() {
    LanControlClient.instance.disconnect();
    App.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dragPos = ref.watch(_dragProvider).dragPosition;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isConnected) {
          await LanControlClient.instance.sendNavigate(
            NavigateTarget.exitPlayer,
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: Appbar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_outlined),
            onPressed: () async {
              if (_isConnected) {
                await LanControlClient.instance.sendNavigate(
                  NavigateTarget.exitPlayer,
                );
              }
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Text('${t.lanRemoteControl}: ${widget.device.name}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: _disconnect,
              tooltip: t.lanExitControl,
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _ConnectionBanner(
                  isConnected: _isConnected,
                  device: widget.device,
                ),

                if (_isSending)
                  const LinearProgressIndicator()
                else
                  const SizedBox(height: 4),

                const Divider(height: 1),

                Expanded(
                  child: _isConnected
                      ? ListView(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 20,
                            bottom: 120,
                          ),
                          children: [
                            // Current anime info
                            if (_currentAnime != null) ...[
                              _CurrentAnimeCard(anime: _currentAnime!),
                              const SizedBox(height: 24),
                            ],
                            // Episode selection
                            _EpisodeSelectionSection(
                              episodes: _currentAnime?.episodes,
                              currentEpisode:
                                  _currentAnime?.currentEpisode ?? 0,
                              watchedEpisodes: _currentAnime?.watchedEpisodes,
                              isWaiting: _isWaitingForData,
                              onSelectEpisode: _selectEpisode,
                            ),
                            const SizedBox(height: 24),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                size: 56,
                                color: cs.outlineVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t.lanRemoteControlConnectionFailed,
                                style: TextStyle(color: cs.outline),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            if (dragPos != null)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Utils.durationToString(dragPos),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _TimeProgressSection(
                playerStatus: _playerStatus,
                isWaiting: _isWaitingForData,
                onSeek: _seekTo,
                onDragEnd: _seekThenResume,
                onPlay: _play,
                onPause: _pause,
                onSeekBack: _seekBack,
                onSeekForward: _seekForward,
                onPrevEpisode: _prevEpisode,
                onNextEpisode: _nextEpisode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentAnimeCard extends StatelessWidget {
  final CurrentAnime anime;

  const _CurrentAnimeCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (anime.coverUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  anime.coverUrl!,
                  width: 60,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '第 ${anime.currentEpisode} 集',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeProgressSection extends ConsumerStatefulWidget {
  final PlayerStatus? playerStatus;
  final bool isWaiting;
  final Future<void> Function(Duration) onSeek;
  final Future<void> Function(Duration, bool) onDragEnd;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onPrevEpisode;
  final VoidCallback onNextEpisode;

  const _TimeProgressSection({
    required this.playerStatus,
    required this.isWaiting,
    required this.onSeek,
    required this.onDragEnd,
    required this.onPlay,
    required this.onPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onPrevEpisode,
    required this.onNextEpisode,
  });

  @override
  ConsumerState<_TimeProgressSection> createState() =>
      _TimeProgressSectionState();
}

class _TimeProgressSectionState extends ConsumerState<_TimeProgressSection> {
  void _handleDragStart(DragStartDetails _) {
    ref
        .read(_dragProvider.notifier)
        .dragStart(widget.playerStatus?.position ?? 0);
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    ref.read(_dragProvider.notifier).dragUpdate(details.delta.dx, width);
  }

  void _handleDragEnd(DragEndDetails _) {
    final wasPlaying = widget.playerStatus?.isPlaying ?? false;
    final finalPos = ref.read(_dragProvider.notifier).dragEnd();
    widget.onDragEnd(finalPos, wasPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final drag = ref.watch(_dragProvider);
    final position = drag.display;
    final total = drag.duration;
    final isPlaying = widget.playerStatus?.isPlaying ?? false;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 手势区
          LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () {
                final isPlaying = widget.playerStatus?.isPlaying ?? false;
                isPlaying ? widget.onPause() : widget.onPlay();
              },
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragUpdate: (d) =>
                  _handleDragUpdate(d, constraints.maxWidth),
              onHorizontalDragEnd: _handleDragEnd,
              child: const SizedBox(height: 50, width: double.infinity),
            ),
          ),
          // 进度条行
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  Utils.durationToString(position),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: widget.isWaiting
                      ? _WaitingProgressBar()
                      : ProgressBar(
                          thumbRadius: 8,
                          thumbGlowRadius: 18,
                          timeLabelLocation: TimeLabelLocation.none,
                          progress: position,
                          buffered: Duration.zero,
                          total: total,
                          onSeek: widget.onSeek,
                        ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  Utils.durationToString(total),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 控制按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CompactIconButton(
                icon: Icons.skip_previous,
                tooltip: t.lanPreviousEpisode,
                onPressed: widget.onPrevEpisode,
              ),
              _CompactIconButton(
                icon: Icons.replay_10,
                tooltip: t.lanSeekBack,
                onPressed: widget.onSeekBack,
              ),
              _CompactIconButton(
                icon: isPlaying ? Icons.pause : Icons.play_arrow,
                tooltip: isPlaying ? t.lanPause : t.lanPlay,
                onPressed: isPlaying ? widget.onPause : widget.onPlay,
              ),
              _CompactIconButton(
                icon: Icons.forward_10,
                tooltip: t.lanSeekForward,
                onPressed: widget.onSeekForward,
              ),
              _CompactIconButton(
                icon: Icons.skip_next,
                tooltip: t.lanNextEpisode,
                onPressed: widget.onNextEpisode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingProgressBar extends StatefulWidget {
  @override
  State<_WaitingProgressBar> createState() => _WaitingProgressBarState();
}

class _WaitingProgressBarState extends State<_WaitingProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(2),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.3 + 0.4 * _controller.value,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EpisodeSelectionSection extends StatefulWidget {
  final Map<String, Map<String, String>>? episodes;
  final int currentEpisode;
  final Set<int>? watchedEpisodes;
  final bool isWaiting;
  final Future<void> Function(int) onSelectEpisode;

  const _EpisodeSelectionSection({
    required this.episodes,
    required this.currentEpisode,
    this.watchedEpisodes,
    required this.isWaiting,
    required this.onSelectEpisode,
  });

  @override
  State<_EpisodeSelectionSection> createState() =>
      _EpisodeSelectionSectionState();
}

class _EpisodeSelectionSectionState extends State<_EpisodeSelectionSection> {
  int _selectedRoadIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Debug log
    HubLog.info(
      'EpisodeSection',
      'episodes = ${widget.episodes}, isWaiting = ${widget.isWaiting}',
    );

    final hasMultipleRoads =
        widget.episodes != null && widget.episodes!.length > 1;

    return _ControlSection(
      title: t.allEpisodes,
      children: widget.isWaiting
          ? [_WaitingEpisodeGrid()]
          : widget.episodes != null
          ? [
              // Road selector
              if (hasMultipleRoads)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(t.playlist),
                      const SizedBox(width: 8),
                      MenuAnchor(
                        consumeOutsideTap: true,
                        builder: (_, MenuController controller, _) {
                          return TextButton(
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(EdgeInsets.zero),
                            ),
                            onPressed: () {
                              controller.isOpen
                                  ? controller.close()
                                  : controller.open();
                            },
                            child: Text(
                              widget.episodes!.keys.elementAt(
                                _selectedRoadIndex,
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        },
                        menuChildren: List<MenuItemButton>.generate(
                          widget.episodes!.keys.length,
                          (int i) => MenuItemButton(
                            onPressed: () {
                              setState(() {
                                _selectedRoadIndex = i;
                              });
                            },
                            child: Container(
                              height: 40,
                              constraints: const BoxConstraints(minWidth: 112),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                widget.episodes!.keys.elementAt(i),
                                style: TextStyle(
                                  color: i == _selectedRoadIndex
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  fontWeight: i == _selectedRoadIndex
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Episode grid
              _buildEpisodeGrid(context),
            ]
          : [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '等待被控制端发送剧集信息...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
    );
  }

  Widget _buildEpisodeGrid(BuildContext context) {
    final roadKey = widget.episodes!.keys.elementAt(_selectedRoadIndex);
    final road = widget.episodes![roadKey]!;
    final episodes = road.entries.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: episodes.asMap().entries.map((indexedEntry) {
        final index = indexedEntry.key;
        final entry = indexedEntry.value;
        final episodeNum = index + 1;
        final isWatched = widget.watchedEpisodes?.contains(episodeNum) ?? false;
        final isCurrent = episodeNum == widget.currentEpisode;

        return _EpisodeButton(
          episode: episodeNum,
          title: entry.value,
          isCurrent: isCurrent,
          isWatched: isWatched,
          onTap: () => widget.onSelectEpisode(episodeNum),
        );
      }).toList(),
    );
  }
}

class _EpisodeButton extends StatelessWidget {
  final int episode;
  final String title;
  final bool isCurrent;
  final bool isWatched;
  final VoidCallback onTap;

  const _EpisodeButton({
    required this.episode,
    required this.title,
    required this.isCurrent,
    this.isWatched = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: isCurrent
          ? cs.primaryContainer
          : isWatched
          ? cs.primaryContainer.toOpacity(0.3)
          : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWatched && !isCurrent)
                Icon(Icons.check, size: 14, color: cs.primary),
              if (isWatched && !isCurrent) const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: isCurrent ? cs.onPrimaryContainer : cs.onSurface,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingEpisodeGrid extends StatefulWidget {
  @override
  State<_WaitingEpisodeGrid> createState() => _WaitingEpisodeGridState();
}

class _WaitingEpisodeGridState extends State<_WaitingEpisodeGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(12, (index) {
              final delay = (index / 12 + _controller.value) % 1.0;
              return Container(
                width: 40,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest
                      .withAlpha((100 + 155 * delay).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final bool isConnected;
  final LanDiscoveredDevice device;

  const _ConnectionBanner({required this.isConnected, required this.device});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isConnected
          ? cs.primaryContainer.withAlpha(80)
          : cs.errorContainer.withAlpha(80),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : cs.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isConnected
                  ? '${t.lanRemoteControlConnected}  •  ${device.ip}:${device.port}'
                  : t.lanRemoteControlConnectionFailed,
              style: TextStyle(
                fontSize: 13,
                color: isConnected
                    ? cs.onPrimaryContainer
                    : cs.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ControlSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: children),
      ],
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 40),
        ),
      ),
    );
  }
}
