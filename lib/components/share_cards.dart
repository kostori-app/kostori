part of 'share_widget.dart';

class BangumiGridCard extends StatelessWidget {
  final BangumiItem bangumiItem;
  final double width;
  final double height;

  const BangumiGridCard({
    required this.bangumiItem,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final animeCardUseBlur = appdata.implicitData['animeCardUseBlur'] ?? false;
    final showOverlay = appdata.implicitData['showAnimeCardOverlay'] != false;

    Widget containerBackground(Widget child) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.toOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.brightness == Brightness.light
                ? Colors.white.toOpacity(0.6)
                : Colors.black.toOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      );
    }

    Widget backdropFilter(Widget child) {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: context.brightness == Brightness.light
              ? Colors.white.toOpacity(0.3)
              : Colors.black.toOpacity(0.3),
          child: child,
        ),
      );
    }

    Widget scoreWidget() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (bangumiItem.total >= 20) ...[
            Text(
              '${bangumiItem.score}',
              style: TextStyle(
                fontSize: App.isAndroid ? 13 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${bangumiItem.rank}',
                style: TextStyle(
                  fontSize: App.isAndroid ? 7 : 9,
                  fontWeight: FontWeight.bold,
                ),
              ),

              RatingBarIndicator(
                itemCount: 5,
                rating: bangumiItem.score / 2,
                itemBuilder: (context, index) => const Icon(Icons.star_rounded),
                itemSize: App.isAndroid ? 12 : 14,
              ),
              Text(
                t.tReviews(t: bangumiItem.total),
                style: TextStyle(
                  fontSize: App.isAndroid ? 7 : 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: width,
          height: height,
          margin: const EdgeInsets.only(bottom: 8),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BangumiWidget.kostoriImage(
                  context,
                  bangumiItem.images['large']!,
                  width: width,
                  height: height,
                ),
              ),
              if (showOverlay)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (bangumiItem.airDate.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: animeCardUseBlur
                                ? backdropFilter(
                                    Text(
                                      bangumiItem.airDate,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : containerBackground(
                                    Text(
                                      bangumiItem.airDate,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: animeCardUseBlur
                              ? backdropFilter(scoreWidget())
                              : containerBackground(scoreWidget()),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: width,
          child: Text(
            bangumiItem.nameCn.isNotEmpty
                ? bangumiItem.nameCn
                : bangumiItem.name,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class BangumiHorizontalCard extends StatelessWidget {
  final BangumiSRI bangumiItem;
  final double width;
  final double imageHeight;

  const BangumiHorizontalCard({
    required this.bangumiItem,
    required this.width,
    required this.imageHeight,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final title = bangumiItem.nameCn.isEmpty
        ? bangumiItem.name
        : bangumiItem.nameCn;

    return SizedBox(
      width: width,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: width / imageHeight,
              child: Ink.image(
                image: CachedImageProvider(
                  bangumiItem.images['large']!,
                  sourceKey: 'bangumi',
                ),
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(2.0),
              child: Center(
                child: Text(
                  bangumiItem.relation,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BangumiCharacterCard extends StatelessWidget {
  const _BangumiCharacterCard({
    required this.character,
    required this.width,
    required this.height,
  });

  final CharacterActor character;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final title = character.nameCN.isNotEmpty
        ? character.nameCN
        : character.name;
    final animeCardUseBlur = appdata.implicitData['animeCardUseBlur'] ?? false;

    Widget info() {
      return Text(character.info, style: const TextStyle(fontSize: 12.0));
    }

    Widget containerBackground(Widget child) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.toOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.brightness == Brightness.light
                ? Colors.white.toOpacity(0.6)
                : Colors.black.toOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      );
    }

    Widget backdropFilter(Widget child) {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: context.brightness == Brightness.light
              ? Colors.white.toOpacity(0.3)
              : Colors.black.toOpacity(0.3),
          child: child,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: width,
          height: height,
          margin: const EdgeInsets.only(bottom: 8),
          child: Stack(
            children: [
              Positioned.fill(
                child: character.images.large.isEmpty
                    ? SizedBox(width: width, height: height)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BangumiWidget.kostoriImage(
                          context,
                          character.images.large,
                          width: width,
                          height: height,
                        ),
                      ),
              ),
              if (character.info.isNotEmpty)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: animeCardUseBlur
                          ? backdropFilter(info())
                          : containerBackground(info()),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: width,
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class ShareQrCode extends StatefulWidget {
  const ShareQrCode({
    super.key,
    required this.type,
    required this.payload,
    this.showQrCode = true,
  });

  final KostoriRouteType type;
  final String payload;

  /// false 时只显示底部标签，不含开关
  final bool showQrCode;

  @override
  State<ShareQrCode> createState() => _ShareQrCodeState();
}

class _ShareQrCodeState extends State<ShareQrCode> {
  bool _expanded = false;
  String? _cachedContent;

  String get _content {
    if (!widget.showQrCode) return '';
    return _cachedContent ??= ProtocolParser.encodeWithBase64Payload(
      widget.type,
      widget.payload,
    );
  }

  @override
  void didUpdateWidget(covariant ShareQrCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type || oldWidget.payload != widget.payload) {
      _cachedContent = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qrBg = isDark ? cs.surfaceContainerHighest : cs.surface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showQrCode && _expanded) ...[
            Divider(thickness: 0.5, color: Colors.grey.toOpacity(0.3)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _expanded = false),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: qrBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant.toOpacity(0.5),
                        width: 0.8,
                      ),
                    ),
                    child: KostoriQrCode(
                      content: _content,
                      size: 96,
                      background: qrBg,
                      logoScale: 0.2,
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    height: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.scanToJump,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.type.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 11,
                              color: Colors.grey.toOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Generated by Kostori v${App.version}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.toOpacity(0.6),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.showQrCode && !_expanded) ...[
            Divider(thickness: 0.5, color: Colors.grey.toOpacity(0.3)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: Colors.grey.toOpacity(0.6),
                ),
                const SizedBox(width: 5),
                Text(
                  'Generated by Kostori v${App.version}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.toOpacity(0.6),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _expanded = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_rounded,
                          size: 11,
                          color: Colors.grey.toOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t.qrCode,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.toOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
