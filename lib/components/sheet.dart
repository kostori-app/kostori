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
    final height = MediaQuery.of(context).size.height * initialSize;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        color: cs.surface,
        height: height,
        child: Column(
          children: [
            _SheetHandle(),
            _SheetHeader(title: title, icon: icon, trailing: headerTrailing),
            Expanded(child: builder(context, sc)),
            if (footer != null) footer!,
          ],
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
        desktopSuccessMessage: '二维码已复制到剪贴板',
        mobileSuccessMessage: '二维码已保存',
      );
      Navigator.pop(context);
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
            FilledButton.icon(
              onPressed: _isExporting ? null : _share,
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: PolygonRefreshIndicator(),
                    )
                  : const Icon(Icons.share_outlined, size: 16),
              label: Text(_isExporting ? t.exporting : t.share),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (config.title != null && config.showTitle) ...[
                      Text(
                        config.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black45),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: config.qrBackground,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: PrettyQrView.data(
                          data: config.content,
                          errorCorrectLevel: QrErrorCorrectLevel.H,
                          decoration: PrettyQrDecoration(
                            background: config.qrBackground,
                            shape: const PrettyQrSmoothSymbol(
                              color: PrettyQrBrush.gradient(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF80D8DA),
                                    Color(0xFFF1919B),
                                  ],
                                ),
                              ),
                              roundFactor: 1.0,
                            ),
                            image: const PrettyQrDecorationImage(
                              image: AssetImage('images/app_icon.png'),
                              scale: 0.2,
                              position:
                                  PrettyQrDecorationImagePosition.embedded,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (config.subtitle != null && config.showSubtitle) ...[
                      const SizedBox(height: 10),
                      Text(
                        config.subtitle!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Kostori',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 2,
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
            Image.network(
              bgPath,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _GradientBg(color: config.themeColor),
            )
          else
            Image.file(
              File(bgPath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _GradientBg(color: config.themeColor),
            ),
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
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
