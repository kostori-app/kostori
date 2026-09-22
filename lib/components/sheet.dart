part of "components.dart";

class Sheet extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget Function(BuildContext context, ScrollController sc) builder;
  final Widget? headerTrailing;
  final Widget? footer;
  final double initialSize;

  const Sheet({
    super.key,
    required this.title,
    required this.builder,
    this.icon,
    this.headerTrailing,
    this.footer,
    this.initialSize = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = ScrollController();
    final height = MediaQuery.sizeOf(context).height * initialSize;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: height,
        child: Material(
          color: cs.surface,
          child: Column(
            children: [
              _SheetHandle(),
              _SheetHeader(title: title, icon: icon, trailing: headerTrailing),
              Expanded(child: builder(context, sc)),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.toOpacity(0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const _SheetHeader({required this.title, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: cs.onSurface.toOpacity(0.7)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) trailing!,
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outlineVariant.toOpacity(0.4),
        ),
      ],
    );
  }
}

class QrShareConfig {
  final String content;

  final String? title;

  final String? subtitle;

  final String? backgroundImagePath;

  final Color qrForeground;

  final Color qrBackground;

  final Color themeColor;

  final double exportPixelRatio;

  final double exportWidth;

  final bool showTitle;

  final bool showSubtitle;

  const QrShareConfig({
    required this.content,
    this.title,
    this.subtitle,
    this.backgroundImagePath,
    this.qrForeground = Colors.black,
    this.qrBackground = Colors.white,
    this.themeColor = const Color(0xFF6C63FF),
    this.exportPixelRatio = 3.0,
    this.exportWidth = 800.0,
    this.showTitle = true,
    this.showSubtitle = true,
  });

  factory QrShareConfig.fromProtocol(
    ParsedProtocol parsed, {
    String? title,
    String? backgroundImagePath,
    Color themeColor = const Color(0xFF6C63FF),
  }) {
    return QrShareConfig(
      content: parsed.resolvedProtocol,
      title: title ?? parsed.type.label,
      subtitle: parsed.payload,
      backgroundImagePath: backgroundImagePath,
      themeColor: themeColor,
    );
  }

  QrShareConfig copyWith({
    String? backgroundImagePath,
    bool clearBackground = false,
    bool? showTitle,
    bool? showSubtitle,
  }) {
    return QrShareConfig(
      content: content,
      title: title,
      subtitle: subtitle,
      backgroundImagePath: clearBackground
          ? null
          : (backgroundImagePath ?? this.backgroundImagePath),
      qrForeground: qrForeground,
      qrBackground: qrBackground,
      themeColor: themeColor,
      exportPixelRatio: exportPixelRatio,
      exportWidth: exportWidth,
      showTitle: showTitle ?? this.showTitle,
      showSubtitle: showSubtitle ?? this.showSubtitle,
    );
  }
}

class QrShareSheet extends ConsumerStatefulWidget {
  const QrShareSheet({super.key, required this.config});

  final QrShareConfig config;

  @override
  ConsumerState<QrShareSheet> createState() => _QrShareSheetState();
}

class _QrShareSheetState extends ConsumerState<QrShareSheet> {
  late QrShareConfig _config;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  Future<void> _pickBackground() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _config = _config.copyWith(backgroundImagePath: file.path));
  }

  void _clearBackground() {
    setState(() => _config = _config.copyWith(clearBackground: true));
  }

  Future<void> _share() async {
    setState(() => _isExporting = true);

    try {
      final bytes = await ImageSaver.captureWidgetToImage(
        context: context,
        child: _QrCard(config: _config),
        width: _config.exportWidth,
        pixelRatio: _config.exportPixelRatio,
      );

      if (bytes == null) {
        ImageSaver.showResult(
          success: false,
          message: t.screenshotFailedPleaseRetry,
        );
        return;
      }

      final filename =
          'kostori_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      await ImageSaver.saveOrShareImage(
        bytes: bytes,
        filename: filename,
        desktopSuccessMessage: t.qrCopiedToClipboard,
        mobileSuccessMessage: t.qrSavedToGallery,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ImageSaver.showResult(success: false, message: t.shareFailed);
    } finally {
      await ref.read(imagesProvider.notifier).loadImages();
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBackground = _config.backgroundImagePath != null;

    return Sheet(
      title: t.shareQrCode,
      icon: Icons.qr_code_outlined,
      initialSize: 0.65,
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            _Chip(
              label: t.imageTitle,
              icon: Icons.title_outlined,
              selected: _config.showTitle,
              onSelected: (v) =>
                  setState(() => _config = _config.copyWith(showTitle: v)),
              useTooltip: true,
            ),
            const SizedBox(width: 8),
            _Chip(
              label: t.imageSubtitle,
              icon: Icons.subtitles_outlined,
              selected: _config.showSubtitle,
              onSelected: (v) =>
                  setState(() => _config = _config.copyWith(showSubtitle: v)),
              useTooltip: true,
            ),
            const SizedBox(width: 8),
            _Chip(
              label: hasBackground ? t.changeBackground : t.selectBackground,
              icon: Icons.image_outlined,
              onTap: _pickBackground,
              useTooltip: true,
            ),
            if (hasBackground) ...[
              const SizedBox(width: 8),
              _Chip(
                label: t.clearBackground,
                icon: Icons.hide_image_outlined,
                onTap: _clearBackground,
                useTooltip: true,
              ),
            ],
            const Spacer(),
            CapsuleButton(
              primary: true,
              isLoading: _isExporting,
              enabled: !_isExporting,
              leading: const Icon(Icons.share_outlined, size: 16),
              text: _isExporting ? t.exporting : t.share,
              onTap: _share,
            ),
          ],
        ),
      ),
      builder: (context, sc) => SingleChildScrollView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: _QrCard(config: _config),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.config});

  final QrShareConfig config;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
          _BackgroundLayer(config: config),
          // 复用统一二维码卡片组件（标题 + 二维码 + 副标题 + 水印）
          KostoriQrCard(
            content: config.content,
            title: config.title,
            subtitle: config.subtitle,
            showTitle: config.showTitle,
            showSubtitle: config.showSubtitle,
            qrBackground: config.qrBackground,
          ),
        ],
      ),
    ),
  ),
);
  }
}

class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer({required this.config});

  final QrShareConfig config;

  @override
  Widget build(BuildContext context) {
    final bgPath = config.backgroundImagePath;

    if (bgPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (bgPath.startsWith('http'))
            // 走项目统一图片加载（带代理/headers/缓存），裸 Image.network 会加载失败
            Image(
              image: CachedImageProvider(bgPath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _GradientBg(color: config.themeColor),
            )
          else
            Image.file(
              File(bgPath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _GradientBg(color: config.themeColor),
            ),
          BlurEffect(
            child: Container(color: Colors.black.toOpacity(0.35)),
          ),
        ],
      );
    }

    return _GradientBg(color: config.themeColor);
  }
}

class _GradientBg extends StatelessWidget {
  const _GradientBg({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.5)!],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    this.selected,
    this.onTap,
    this.onSelected,
    this.useTooltip = false,
  });

  final String label;
  final IconData icon;
  final bool? selected;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onSelected;
  final bool useTooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOn = selected ?? false;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOn ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isOn ? cs.onPrimary : cs.onSurfaceVariant,
          ),
          if (!useTooltip) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isOn ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    if (useTooltip) {
      return Tooltip(
        message: label,
        child: GestureDetector(
          onTap: selected != null ? () => onSelected!(!isOn) : onTap,
          child: content,
        ),
      );
    }

    return GestureDetector(
      onTap: selected != null ? () => onSelected!(!isOn) : onTap,
      child: content,
    );
  }
}

Future<void> showQrShareSheet(
  BuildContext context,
  WidgetRef ref, {
  required QrShareConfig config,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => QrShareSheet(config: config),
  );
}

abstract class VideoInfoSource {
  /// 原生播放器（用于读取 mpv 调试属性），不可用时为 null
  Player? get player;

  List<Media> get medias;

  String get videoUrl;

  VideoParams get videoParams;

  AudioParams get audioParams;

  AudioTrack get audioTrack;

  VideoTrack get videoTrack;

  String get audioBitrate;

  List<PlayerLogEntry> get logs;

  /// 播放该视频实际使用的请求头（含自动附加的 cookie）
  Map<String, String>? get videoHeaders;
}

class PlayerControllerInfoSource implements VideoInfoSource {
  final PlayerController controller;

  const PlayerControllerInfoSource(this.controller);

  @override
  Player? get player => controller.player;

  @override
  List<Media> get medias => controller.playerPlaylist.medias;

  @override
  String get videoUrl => controller.videoUrl;

  @override
  VideoParams get videoParams => controller.playerVideoParams;

  @override
  AudioParams get audioParams => controller.playerAudioParams;

  @override
  AudioTrack get audioTrack => controller.playerAudioTracks;

  @override
  VideoTrack get videoTrack => controller.playerVideoTracks;

  @override
  String get audioBitrate => controller.playerAudioBitrate;

  @override
  List<PlayerLogEntry> get logs => controller.playerLog;

  @override
  Map<String, String>? get videoHeaders => controller.videoHeaders;
}

class RawPlayerInfoSource implements VideoInfoSource {
  @override
  final Player player;
  @override
  final String videoUrl;
  @override
  final List<PlayerLogEntry> logs;
  @override
  final Map<String, String>? videoHeaders;

  const RawPlayerInfoSource({
    required this.player,
    required this.videoUrl,
    required this.logs,
    this.videoHeaders,
  });

  @override
  List<Media> get medias => player.state.playlist.medias;

  @override
  VideoParams get videoParams => player.state.videoParams;

  @override
  AudioParams get audioParams => player.state.audioParams;

  @override
  AudioTrack get audioTrack => player.state.track.audio;

  @override
  VideoTrack get videoTrack => player.state.track.video;

  @override
  String get audioBitrate => player.state.audioBitrate?.toString() ?? '-';
}

class ParamCard extends StatelessWidget {
  final String title;
  final Map<String, Object?> params;

  const ParamCard({super.key, required this.title, required this.params});

  @override
  Widget build(BuildContext context) {
    final String allText = [
      title,
      ...params.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}: ${e.value}'),
    ].join('\n');

    return Material(
      elevation: 2,
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white.toOpacity(0.72)
          : const Color(0xFF1E1E1E).toOpacity(0.72),
      shadowColor: Theme.of(context).colorScheme.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: allText));
          App.rootContext.showMessage(message: t.copySuccess);
        },
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSelectableText(title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                scrollPhysics: const NeverScrollableScrollPhysics(),
              ),
              const SizedBox(height: 8),
              ...params.entries
                  .where((e) => e.value != null)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: AppSelectableText.rich(TextSpan(
                          children: [
                            TextSpan(
                              text: '${e.key}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: e.value.toString()),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 过滤掉 null / 空 / unknown / auto 之类的无效项，避免出现「nullxnull」这种噪声
Map<String, Object?> _compact(Map<String, Object?> map) {
  bool valid(Object? value) {
    if (value == null) return false;
    final s = value.toString().trim();
    if (s.isEmpty) return false;
    final lower = s.toLowerCase();
    if (lower == 'unknown' || lower == 'null' || lower == 'auto') return false;
    if (s == '-') return false;
    return true;
  }

  return {
    for (final e in map.entries)
      if (valid(e.value)) e.key: e.value,
  };
}

class MediaInfoWidget extends StatelessWidget {
  final VideoParams? videoParams;
  final AudioParams? audioParams;
  final AudioTrack? audioTrack;
  final VideoTrack? videoTrack;
  final String? audioBitrate;

  const MediaInfoWidget({
    super.key,
    this.videoParams,
    this.audioParams,
    this.audioTrack,
    this.videoTrack,
    this.audioBitrate,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [];

    final vp = videoParams;
    if (vp != null) {
      final resolution = (vp.w == null || vp.h == null)
          ? null
          : '${vp.w}x${vp.h}';
      final display = (vp.dw == null || vp.dh == null)
          ? null
          : '${vp.dw}x${vp.dh}';
      final videoMap = _compact({
        // 先放最有用的信息，读不到的不展示
        t.trackCodec: videoTrack?.codec,
        t.resolution: resolution,
        t.trackFps: videoTrack?.fps,
        t.trackBitrate: videoTrack?.bitrate,
        t.pixelFormat: vp.pixelformat,
        t.hwPixelFormat: vp.hwPixelformat,
        t.displayResolution: display,
        t.aspect: vp.aspect,
        t.pixelAspectRatio: vp.par,
        t.colormatrix: vp.colormatrix,
        t.colorLevels: vp.colorlevels,
        t.primaries: vp.primaries,
        t.gamma: vp.gamma,
        t.signalPeak: vp.sigPeak,
        t.lights: vp.light,
        t.chromaLocation: vp.chromaLocation,
        t.rotate: vp.rotate,
        t.stereoIn: vp.stereoIn,
        t.averageBpp: vp.averageBpp,
        t.alpha: vp.alpha,
        t.trackDecoder: videoTrack?.decoder,
        t.trackTitle: videoTrack?.title,
        t.trackLanguage: videoTrack?.language,
      });
      cards.add(ParamCard(title: t.video, params: videoMap));
    }

    final ap = audioParams;
    if (ap != null) {
      final audioMap = _compact({
        t.trackCodec: audioTrack?.codec,
        t.sampleRate: ap.sampleRate,
        t.channels: ap.channels,
        t.channelCount: ap.channelCount,
        t.bitrate: audioTrack?.bitrate,
        t.audioBitrate: audioBitrate,
        t.format: ap.format,
        t.hrChannels: ap.hrChannels,
        t.trackDecoder: audioTrack?.decoder,
        t.trackTitle: audioTrack?.title,
        t.trackLanguage: audioTrack?.language,
      });
      cards.add(ParamCard(title: t.audio, params: audioMap));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: card,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class MediaWidget extends StatelessWidget {
  final Media media;

  const MediaWidget({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final String allText = media.uri;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: allText));
          App.rootContext.showMessage(message: t.copySuccess);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.media,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(media.uri, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoInfoSheet extends StatefulWidget {
  factory VideoInfoSheet.fromController(
    PlayerController controller, {
    VideoProbeResult? probe,
    String? playbackError,
    bool? playbackOk,
    bool firstFrame = false,
  }) => VideoInfoSheet._(
    source: PlayerControllerInfoSource(controller),
    probe: probe,
    playbackError: playbackError,
    playbackOk: playbackOk,
    firstFrame: firstFrame,
  );

  factory VideoInfoSheet.fromPlayer({
    required Player player,
    required String videoUrl,
    required List<PlayerLogEntry> logs,
    Map<String, String>? videoHeaders,
    VideoProbeResult? probe,
    String? playbackError,
    bool? playbackOk,
    bool firstFrame = false,
  }) => VideoInfoSheet._(
    source: RawPlayerInfoSource(
      player: player,
      videoUrl: videoUrl,
      logs: logs,
      videoHeaders: videoHeaders,
    ),
    probe: probe,
    playbackError: playbackError,
    playbackOk: playbackOk,
    firstFrame: firstFrame,
  );

  const VideoInfoSheet._({
    required this.source,
    this.probe,
    this.playbackError,
    this.playbackOk,
    this.firstFrame = false,
  });

  final VideoInfoSource source;

  /// 已完成的地址探测（为空时 sheet 自己探测一次）
  final VideoProbeResult? probe;

  /// 播放错误信息
  final String? playbackError;

  /// 播放结果：null = 未确定
  final bool? playbackOk;

  final bool firstFrame;

  @override
  _VideoInfoSheetState createState() => _VideoInfoSheetState();
}

class _VideoInfoSheetState extends State<VideoInfoSheet>
    with TickerProviderStateMixin {
  late TabController _tabControllerZero;
  late TabController _tabControllerOne;
  Timer? _refreshTimer;

  VideoProbeResult? _probe;
  bool _probing = false;
  Map<String, String> _mpvProperties = const {};
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _tabControllerZero = TabController(length: 3, vsync: this);
    _tabControllerOne = TabController(length: 3, vsync: this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      // 诊断页停留时定期重读 mpv 属性：硬件解码/帧率等要开始播放后才有值
      _tick++;
      if (_tabControllerZero.index == 1 && _tick % 2 == 0) {
        unawaited(_loadMpvProperties());
      }
    });
    _probe = widget.probe;
    if (_probe == null) unawaited(_runProbe());
    unawaited(_loadMpvProperties());
  }

  Future<void> _runProbe() async {
    final url = widget.source.videoUrl.trim();
    if (url.isEmpty) return;
    setState(() => _probing = true);
    final result = await probeVideoUrl(
      url,
      headers: widget.source.videoHeaders,
    );
    if (!mounted) return;
    setState(() {
      _probe = result;
      _probing = false;
    });
  }

  Future<void> _loadMpvProperties() async {
    final player = widget.source.player;
    if (player == null) return;
    final props = await readMpvProperties(player);
    if (!mounted) return;
    setState(() => _mpvProperties = props);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabControllerZero.dispose();
    _tabControllerOne.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        children: [
          CapsuleTabBar(
            controller: _tabControllerZero,
            labels: [t.status, t.vtDiagnostics, t.log],
          ),
          Expanded(
            child: ExtendedTabBarView(
              shouldIgnorePointerWhenScrolling: false,
              controller: _tabControllerZero,
              children: [
                KeepAliveWrapper(child: _buildVideoInfoTab()),
                KeepAliveWrapper(child: _buildDiagnosticsTab()),
                KeepAliveWrapper(child: _buildVideoLogTab()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfoTab() {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.source.medias.isNotEmpty)
                MediaWidget(media: widget.source.medias.first),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onLongPress: () {
                    Clipboard.setData(
                      ClipboardData(text: widget.source.videoUrl),
                    );
                    App.rootContext.showMessage(message: t.copySuccess);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSelectableText(t.source,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          scrollPhysics: const NeverScrollableScrollPhysics(),
                        ),
                        const SizedBox(height: 8),
                        AppSelectableText('URI: ${widget.source.videoUrl}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          scrollPhysics: const NeverScrollableScrollPhysics(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildRequestHeadersCard(context),
              const SizedBox(height: 12),
              MediaInfoWidget(
                videoParams: widget.source.videoParams,
                audioParams: widget.source.audioParams,
                audioTrack: widget.source.audioTrack,
                videoTrack: widget.source.videoTrack,
                audioBitrate: widget.source.audioBitrate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestHeadersCard(BuildContext context) {
    final headers = widget.source.videoHeaders;
    final entries =
        headers?.entries.toList() ?? const <MapEntry<String, String>>[];
    final allText = [
      t.requestHeaders,
      if (entries.isEmpty)
        t.playerNoRequestHeaders
      else
        ...entries.map((e) => '${e.key}: ${e.value}'),
    ].join('\n');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: allText));
          App.rootContext.showMessage(message: t.copySuccess);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSelectableText(t.requestHeaders,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                scrollPhysics: const NeverScrollableScrollPhysics(),
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                AppSelectableText(t.playerNoRequestHeaders,
                  style: Theme.of(context).textTheme.bodyMedium,
                  scrollPhysics: const NeverScrollableScrollPhysics(),
                )
              else
                ...entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: AppSelectableText('${e.key}: ${e.value}',
                      style: Theme.of(context).textTheme.bodySmall,
                      scrollPhysics: const NeverScrollableScrollPhysics(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 诊断：地址检测 + 播放检测 + mpv 媒体属性
  Widget _buildDiagnosticsTab() {
    final probe = _probe;
    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _diagCard(
            title: t.vtUrlProbe,
            icon: Icons.travel_explore_outlined,
            trailing: IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: t.vtRecheck,
              onPressed: _probing ? null : _runProbe,
            ),
            rows: [
              if (_probing)
                MapEntry(t.vtProbeRunning, '')
              else if (probe == null)
                MapEntry(t.vtProbeUnreachable, '-')
              else ...[
                MapEntry(
                  probe.reachable ? t.vtProbeReachable : t.vtProbeUnreachable,
                  probe.reachable
                      ? '${probe.statusCode ?? '-'} '
                            '${probe.statusMessage ?? ''}'.trim()
                      : probe.error ?? '-',
                ),
                MapEntry(t.vtVideoType, probe.kind.label),
                MapEntry(
                  probe.kind.playable ? t.vtIsVideoUrl : t.vtNotVideoUrl,
                  probe.kind.playable
                      ? (probe.kind.playlist ? 'playlist' : 'media')
                      : probe.kind.label,
                ),
                MapEntry(t.vtContentType, probe.contentTypeLabel),
                MapEntry(t.vtContentLength, probe.sizeLabel),
                MapEntry(
                  t.vtAcceptRanges,
                  probe.acceptRanges ?? '-',
                ),
                MapEntry(t.vtElapsed, '${probe.elapsedMs} ms'),
                if (probe.redirects.length > 1)
                  MapEntry(
                    t.vtRedirectChain,
                    [
                      for (var i = 0; i < probe.redirects.length; i++)
                        '${i + 1}. ${probe.redirects[i]}',
                    ].join('\n'),
                  ),
              ],
            ],
          ),
          if (probe != null && probe.looksLikeHtml)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.vtHtmlHint,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (probe != null &&
              probe.textPreview.isNotEmpty &&
              (probe.kind == VideoUrlKind.hls ||
                  probe.kind == VideoUrlKind.dash ||
                  probe.kind == VideoUrlKind.html ||
                  probe.kind == VideoUrlKind.unknown))
            _diagCard(
              title: t.vtResponsePreview,
              icon: Icons.short_text,
              rows: [MapEntry('body', probe.textPreview)],
            ),
          _diagCard(
            title: t.vtPlaybackResult,
            icon: Icons.play_circle_outline,
            rows: [
              MapEntry(
                t.vtPlaybackResult,
                widget.playbackOk == null
                    ? t.vtPlaybackPending
                    : (widget.playbackOk! ? t.vtPlaybackOk : t.vtPlaybackFailed),
              ),
              MapEntry(
                t.vtFirstFrame,
                widget.firstFrame ? '✓' : '✗',
              ),
              MapEntry(
                t.media,
                '${widget.source.medias.length} · '
                '${widget.source.videoParams.w ?? '-'}x'
                '${widget.source.videoParams.h ?? '-'}',
              ),
              if (widget.playbackError != null)
                MapEntry(t.vtProbeError, widget.playbackError!),
            ],
          ),
          _diagCard(
            title: t.vtHwAccel,
            icon: Icons.memory,
            trailing: IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: t.vtRecheck,
              onPressed: _loadMpvProperties,
            ),
            rows: [
              MapEntry(
                t.vtHwAccelCurrent,
                switch (isHardwareDecoding(_mpvProperties)) {
                  true =>
                    '${t.vtHwAccelOn}'
                        '${_mpvProperties['hwdec-current']?.isNotEmpty == true ? ' (${_mpvProperties['hwdec-current']})' : ''}',
                  false => t.vtHwAccelOff,
                  _ => t.vtHwAccelUnknown,
                },
              ),
              MapEntry(t.vtHwAccelRequested, _mpvProperties['hwdec'] ?? '-'),
              MapEntry(
                t.hwPixelFormat,
                _mpvProperties['video-params/hw-pixelformat'] ??
                    _mpvProperties['hw-pixelformat'] ??
                    '-',
              ),
              MapEntry(t.vtRenderer, _mpvProperties['vo'] ?? '-'),
              MapEntry(t.vtGpuContext, _mpvProperties['gpu-context'] ?? '-'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
            child: Text(
              '${t.vtHwAccelHint}\n${t.vtLogNoiseHint}',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _diagCard(
            title: t.vtMediaProperties,
            icon: Icons.tune,
            trailing: IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: t.vtRecheck,
              onPressed: _loadMpvProperties,
            ),
            rows: _mpvProperties.isEmpty
                ? [MapEntry(t.vtMediaPropertiesHint, '')]
                : _mpvProperties.entries
                      .map((e) => MapEntry(e.key, e.value))
                      .toList(),
          ),
        ],
      ),
    );
  }

  Widget _diagCard({
    required String title,
    required IconData icon,
    required List<MapEntry<String, String>> rows,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant, width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 6),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          row.key,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: AppSelectableText(row.value.isEmpty ? '-' : row.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLogTab() {
    final logs = widget.source.logs;

    final Map<String, List<PlayerLogEntry>> logsByLevel = {
      'info': [],
      'warn': [],
      'error': [],
    };
    for (var entry in logs) {
      final level = entry.log.level;
      if (logsByLevel.containsKey(level)) {
        logsByLevel[level]!.add(entry);
      } else {
        logsByLevel['info']!.add(entry);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CapsuleTabBar(
        controller: _tabControllerOne,
        labels: [for (final level in logsByLevel.keys) level.toUpperCase()],
      ),
      body: ExtendedTabBarView(
        shouldIgnorePointerWhenScrolling: false,
        controller: _tabControllerOne,
        children: logsByLevel.keys.map((level) {
          final levelLogs = logsByLevel[level]!;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListView.separated(
              itemCount: levelLogs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _LogEntryCard(entry: levelLogs[index]),
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.copy),
        onPressed: () {
          final allText = widget.source.logs
              .map(
                (e) =>
                    '[${DateFormat('HH:mm:ss').format(e.time)}] ${e.log.level} ${e.log.prefix}: ${e.log.text}',
              )
              .join('\n');
          Clipboard.setData(ClipboardData(text: allText));
          App.rootContext.showMessage(message: t.copySuccess);
        },
      ),
    );
  }
}

class PlayerLogEntry {
  final PlayerLog log;
  final DateTime time;

  PlayerLogEntry(this.log) : time = DateTime.now();
}

class _LogEntryCard extends StatefulWidget {
  const _LogEntryCard({required this.entry});

  final PlayerLogEntry entry;

  @override
  State<_LogEntryCard> createState() => _LogEntryCardState();
}

class _LogEntryCardState extends State<_LogEntryCard> {
  final _tc = TranslationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.entry.log;
    final timeStr = DateFormat('HH:mm:ss').format(widget.entry.time);

    return Material(
      elevation: 2,
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white.toOpacity(0.85)
          : const Color(0xFF1E1E1E).toOpacity(0.85),
      shadowColor: Theme.of(context).colorScheme.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 6,
                  ),
                  child: Text(
                    log.prefix,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: log.level == 'error'
                        ? Theme.of(context).colorScheme.error
                        : log.level == 'warn'
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 6,
                  ),
                  child: Text(
                    log.level,
                    style: TextStyle(
                      color: log.level == 'error' ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                TranslateIconButton(data: log.text, controller: _tc),
              ],
            ),
            const SizedBox(height: 6),
            Text(log.text, style: Theme.of(context).textTheme.bodyMedium),
            TranslationOutput(
              controller: _tc,
              padding: const EdgeInsets.only(top: 8),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: log.text));
                  App.rootContext.showMessage(message: t.copySuccess);
                },
                child: Text(t.copy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
