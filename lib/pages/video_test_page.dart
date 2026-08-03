import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/proxy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class HeaderEntry {
  final String key;
  final String value;

  const HeaderEntry(this.key, this.value);

  HeaderEntry copyWith({String? key, String? value}) =>
      HeaderEntry(key ?? this.key, value ?? this.value);
}

class VideoTestState {
  final String url;
  final List<HeaderEntry> headers;
  final bool playing;
  final bool buffering;
  final bool completed;
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final double speed;
  final List<PlayerLogEntry> logs;

  const VideoTestState({
    this.url = '',
    this.headers = const [],
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffer = Duration.zero,
    this.speed = 1.0,
    this.logs = const [],
  });

  VideoTestState copyWith({
    String? url,
    List<HeaderEntry>? headers,
    bool? playing,
    bool? buffering,
    bool? completed,
    Duration? position,
    Duration? duration,
    Duration? buffer,
    double? speed,
    List<PlayerLogEntry>? logs,
  }) => VideoTestState(
    url: url ?? this.url,
    headers: headers ?? this.headers,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    completed: completed ?? this.completed,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffer: buffer ?? this.buffer,
    speed: speed ?? this.speed,
    logs: logs ?? this.logs,
  );
}

class VideoTestNotifier extends StateNotifier<VideoTestState> {
  final Player player = Player(
    configuration: PlayerConfiguration(
      bufferSize: 64 * 1024 * 1024,
      logLevel: MPVLogLevel.v,
      protocolWhitelist: const [
        'file',
        'http',
        'https',
        'tcp',
        'tls',
        'crypto',
        'hls',
        'applehttp',
        'udp',
        'rtp',
        'data',
        'httpproxy',
        'content',
        'fd',
      ],
    ),
  );

  late final VideoController videoController;

  final List<StreamSubscription> _subs = [];

  VideoTestNotifier() : super(const VideoTestState()) {
    videoController = VideoController(player);
    _applyProxy();
    _listenStreams();
  }

  void _listenStreams() {
    _subs.addAll([
      player.stream.playing.listen((v) => state = state.copyWith(playing: v)),
      player.stream.buffering.listen(
        (v) => state = state.copyWith(buffering: v),
      ),
      player.stream.completed.listen(
        (v) => state = state.copyWith(completed: v),
      ),
      player.stream.position.listen((v) => state = state.copyWith(position: v)),
      player.stream.duration.listen((v) => state = state.copyWith(duration: v)),
      player.stream.buffer.listen((v) => state = state.copyWith(buffer: v)),
      player.stream.log.listen((event) {
        state = state.copyWith(logs: [...state.logs, PlayerLogEntry(event)]);
      }),
    ]);
  }

  Future<void> load(String url, List<HeaderEntry> headers) async {
    if (url.trim().isEmpty) return;
    final headerMap = {
      for (final h in headers)
        if (h.key.trim().isNotEmpty) h.key.trim(): h.value.trim(),
    };
    state = state.copyWith(
      url: url,
      headers: headers,
      position: Duration.zero,
      duration: Duration.zero,
      completed: false,
    );
    await player.open(
      Media(url, httpHeaders: headerMap.isEmpty ? null : headerMap),
    );
  }

  Future<void> togglePlay() async {
    await player.playOrPause();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await player.setRate(speed);
    state = state.copyWith(speed: speed);
  }

  Future<void> _applyProxy() async {
    var pp = player.platform as NativePlayer;
    await pp.setProperty('tls-verify', 'no');
    await pp.setProperty('insecure', 'yes');
    if (appdata.settings['proxy'] != 'direct' &&
        appdata.settings['proxy'] != null) {
      final proxyAddr = await getProxy();
      if (proxyAddr != null) {
        final proxyUrl = proxyAddr.startsWith('http://')
            ? proxyAddr
            : 'http://$proxyAddr';
        await pp.setProperty('http-proxy', proxyUrl);
      }
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    super.dispose();
  }
}

final videoTestProvider =
    StateNotifierProvider.autoDispose<VideoTestNotifier, VideoTestState>(
      (ref) => VideoTestNotifier(),
    );

class VideoTestPage extends ConsumerStatefulWidget {
  const VideoTestPage({super.key, this.url});

  /// 可选：进入页面后自动播放该视频地址
  final String? url;

  @override
  ConsumerState<VideoTestPage> createState() => _VideoTestPageState();
}

class _VideoTestPageState extends ConsumerState<VideoTestPage> {
  @override
  void initState() {
    super.initState();
    final url = widget.url;
    if (url != null && url.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(videoTestProvider.notifier).load(url, const []);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(videoTestProvider.notifier);

    return Scaffold(
      appBar: Appbar(title: Text(t.videoTestLabel)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _PlayerView(videoController: notifier.videoController),
                const _BufferingOverlay(),
                const _CompletedOverlay(),
              ],
            ),
          ),

          const _ControlPanel(),
        ],
      ),
    );
  }
}

class _PlayerView extends StatelessWidget {
  const _PlayerView({required this.videoController});

  final VideoController videoController;

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: videoController,
      controls: NoVideoControls,
      fill: Colors.black,
    );
  }
}

class _BufferingOverlay extends ConsumerWidget {
  const _BufferingOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buffering = ref.watch(videoTestProvider.select((s) => s.buffering));
    final hasUrl = ref.watch(videoTestProvider.select((s) => s.url.isNotEmpty));
    if (!buffering || !hasUrl) return const SizedBox.shrink();
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

class _CompletedOverlay extends ConsumerWidget {
  const _CompletedOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(videoTestProvider.select((s) => s.completed));
    if (!completed) return const SizedBox.shrink();
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text(
              '播放完毕',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(videoTestProvider.notifier).seek(Duration.zero),
              icon: const Icon(Icons.replay),
              label: const Text('重播'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends ConsumerWidget {
  const _ControlPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 6),
          _DragHandle(),
          SizedBox(height: 8),
          _ProgressRow(),
          _PlaybackRow(),
          _UrlRow(),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ProgressRow extends ConsumerStatefulWidget {
  const _ProgressRow();

  @override
  ConsumerState<_ProgressRow> createState() => _ProgressRowState();
}

class _ProgressRowState extends ConsumerState<_ProgressRow> {
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(videoTestProvider.select((s) => s.position));
    final duration = ref.watch(videoTestProvider.select((s) => s.duration));
    final buffer = ref.watch(videoTestProvider.select((s) => s.buffer));
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ProgressBar(
        thumbRadius: 8,
        thumbGlowRadius: 18,
        timeLabelLocation: TimeLabelLocation.sides,
        timeLabelTextStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 11,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        progressBarColor: cs.primary,
        bufferedBarColor: cs.primary.withValues(alpha: 0.25),
        baseBarColor: cs.outlineVariant.withValues(alpha: 0.4),
        thumbColor: cs.primary,
        thumbGlowColor: cs.primary.withValues(alpha: 0.2),
        progress: _dragPosition ?? position,
        buffered: buffer,
        total: duration > Duration.zero ? duration : const Duration(seconds: 1),
        onSeek: (d) {
          ref.read(videoTestProvider.notifier).seek(d);
        },
        onDragStart: (_) {
          setState(() => _dragPosition = position);
        },
        onDragUpdate: (details) {
          setState(() => _dragPosition = details.timeStamp);
        },
        onDragEnd: () {
          setState(() => _dragPosition = null);
        },
      ),
    );
  }
}

class _PlaybackRow extends ConsumerWidget {
  const _PlaybackRow();

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(videoTestProvider.select((s) => s.playing));
    final speed = ref.watch(videoTestProvider.select((s) => s.speed));
    final hasUrl = ref.watch(videoTestProvider.select((s) => s.url.isNotEmpty));
    final notifier = ref.read(videoTestProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: hasUrl ? notifier.togglePlay : null,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            iconSize: 28,
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: hasUrl
                ? () {
                    final pos = ref.read(videoTestProvider).position;
                    notifier.seek(
                      Duration(
                        milliseconds: (pos.inMilliseconds - 10000).clamp(
                          0,
                          9999999,
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.replay_10_rounded),
            color: cs.onSurface,
          ),
          IconButton(
            onPressed: hasUrl
                ? () {
                    final s = ref.read(videoTestProvider);
                    final target = (s.position.inMilliseconds + 10000).clamp(
                      0,
                      s.duration.inMilliseconds,
                    );
                    notifier.seek(Duration(milliseconds: target));
                  }
                : null,
            icon: const Icon(Icons.forward_10_rounded),
            color: cs.onSurface,
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              final s = ref.read(videoTestProvider);
              final notifier = ref.read(videoTestProvider.notifier);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => Sheet(
                  title: '详情 & 日志',
                  icon: Icons.info_outline_rounded,
                  initialSize: 0.65,
                  builder: (_, sc) => VideoInfoSheet.fromPlayer(
                    player: notifier.player,
                    videoUrl: s.url,
                    logs: s.logs,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '详情 & 日志',
          ),
          const SizedBox(width: 4),
          PopupMenuButton<double>(
            initialValue: speed,
            onSelected: notifier.setSpeed,
            itemBuilder: (_) => _speeds
                .map(
                  (s) => PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        if (s == speed)
                          Icon(Icons.check, size: 16, color: cs.primary)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text('${s}x'),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: Chip(
              label: Text('${speed}x'),
              labelStyle: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
              side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
              backgroundColor: cs.primary.withValues(alpha: 0.08),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlRow extends ConsumerStatefulWidget {
  const _UrlRow();

  @override
  ConsumerState<_UrlRow> createState() => _UrlRowState();
}

class _UrlRowState extends ConsumerState<_UrlRow> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ref.read(videoTestProvider).url);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _load() {
    FocusScope.of(context).unfocus();
    final headers = ref.read(videoTestProvider).headers;
    ref.read(videoTestProvider.notifier).load(_urlCtrl.text.trim(), headers);
  }

  void _openHeaderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HeaderSheet(
        initialHeaders: ref.read(videoTestProvider).headers,
        onApply: (headers) {
          ref
              .read(videoTestProvider.notifier)
              .load(_urlCtrl.text.trim(), headers);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final headerCount = ref.watch(
      videoTestProvider.select((s) => s.headers.length),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '输入播放链接…',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
                suffixIcon: _urlCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _urlCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _load(),
              textInputAction: TextInputAction.go,
            ),
          ),
          const SizedBox(width: 8),
          // Headers button
          Badge(
            isLabelVisible: headerCount > 0,
            label: Text('$headerCount'),
            child: IconButton(
              onPressed: _openHeaderSheet,
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Headers',
              style: IconButton.styleFrom(
                foregroundColor: headerCount > 0 ? cs.primary : null,
                backgroundColor: headerCount > 0
                    ? cs.primary.withValues(alpha: 0.1)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: _urlCtrl.text.trim().isNotEmpty ? _load : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('加载'),
          ),
        ],
      ),
    );
  }
}

class _HeaderSheet extends StatefulWidget {
  const _HeaderSheet({required this.initialHeaders, required this.onApply});

  final List<HeaderEntry> initialHeaders;
  final void Function(List<HeaderEntry>) onApply;

  @override
  State<_HeaderSheet> createState() => _HeaderSheetState();
}

class _HeaderSheetState extends State<_HeaderSheet> {
  late final List<_HeaderRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialHeaders
        .map(
          (h) => _HeaderRow(
            keyCtrl: TextEditingController(text: h.key),
            valueCtrl: TextEditingController(text: h.value),
          ),
        )
        .toList();
    if (_rows.isEmpty) _addRow();
  }

  void _addRow() {
    setState(() {
      _rows.add(
        _HeaderRow(
          keyCtrl: TextEditingController(),
          valueCtrl: TextEditingController(),
        ),
      );
    });
  }

  void _removeRow(int i) {
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  void _apply() {
    final headers = _rows
        .map((r) => HeaderEntry(r.keyCtrl.text.trim(), r.valueCtrl.text.trim()))
        .where((h) => h.key.isNotEmpty)
        .toList();
    widget.onApply(headers);
    Navigator.of(context).pop();
  }

  static const _presets = {
    'Referer': '',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Origin': '',
  };

  void _addPreset(String key, String value) {
    for (final r in _rows) {
      if (r.keyCtrl.text.trim() == key) return;
    }
    setState(() {
      _rows.add(
        _HeaderRow(
          keyCtrl: TextEditingController(text: key),
          valueCtrl: TextEditingController(text: value),
        ),
      );
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  '请求头 (Headers)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加'),
                ),
              ],
            ),
          ),

          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _presets.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          e.key,
                          style: const TextStyle(fontSize: 12),
                        ),
                        avatar: const Icon(Icons.add_circle_outline, size: 14),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _addPreset(e.key, e.value),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: _rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('暂无请求头，点击"添加"新增', textAlign: TextAlign.center),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _HeaderRowTile(
                      row: _rows[i],
                      onRemove: () => _removeRow(i),
                    ),
                  ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      for (final r in _rows) {
                        r.dispose();
                      }
                      _rows.clear();
                    });
                  },
                  child: const Text('清空'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _apply,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('应用并加载'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;

  _HeaderRow({required this.keyCtrl, required this.valueCtrl});

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}

class _HeaderRowTile extends StatelessWidget {
  const _HeaderRowTile({required this.row, required this.onRemove});

  final _HeaderRow row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _CompactField(
            controller: row.keyCtrl,
            hint: 'Key',
            prefixIcon: Icons.key_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: _CompactField(
            controller: row.valueCtrl,
            hint: 'Value',
            prefixIcon: Icons.text_fields_rounded,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
          iconSize: 20,
          color: cs.error,
          visualDensity: VisualDensity.compact,
          tooltip: '删除',
        ),
      ],
    );
  }
}

class _CompactField extends StatelessWidget {
  const _CompactField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(prefixIcon, size: 14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
