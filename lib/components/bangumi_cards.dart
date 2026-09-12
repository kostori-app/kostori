part of 'bangumi_widget.dart';

class BangumiBriefCard extends StatelessWidget {
  final BangumiItem bangumiItem;
  final Object? heroTag;
  final void Function(BangumiItem)? onTap;
  final void Function(BangumiItem)? onLongPressed;

  /// 瀑布流模式：非 null 时封面高度 = 卡片宽 × 系数（错落），标题不限行数
  final double? masonryFactor;

  const BangumiBriefCard({
    super.key,
    required this.bangumiItem,
    required this.heroTag,
    this.onTap,
    this.onLongPressed,
    this.masonryFactor,
  });

  Widget _buildScore(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (bangumiItem.total >= 20) ...[
          Text(
            formatScore(bangumiItem.score),
            style: TextStyle(
              fontSize: App.isAndroid ? 13 : 16.0,
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
            // 轻量静态星级（替代 flutter_rating_bar：列表滚动时大量卡片
            // 反复构建动画星级组件是滑动卡顿的主要来源）
            _StaticStars(
              rating: bangumiItem.score / 2,
              size: App.isAndroid ? 12 : 14.0,
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

  @override
  Widget build(BuildContext context) {
    final title = bangumiItem.nameCn.isNotEmpty
        ? bangumiItem.nameCn
        : bangumiItem.name;
    final style = const TextStyle(fontWeight: FontWeight.w500);

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
      // blur 半径直接影响每帧合成开销：卡片滚动时覆盖层实时模糊下层，
      // sigma 10 是滑动卡顿的主要来源，降到 4 视觉仍清晰
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: context.brightness == Brightness.light
              ? Colors.white.toOpacity(0.3)
              : Colors.black.toOpacity(0.3),
          child: child,
        ),
      );
    }

    // RepaintBoundary：隔离每张卡片的合成层，滚动时复用缓存的图片+覆盖层
    // 位图，避免每帧重绘半透明叠加导致的合成开销
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useMarquee = appdata.settings['tileTitleMarquee'] == true;
            // 瀑布流：封面高度 = 卡片宽 × 系数；规整网格：由网格高度决定
            final masonry = masonryFactor != null;
            final height = masonry
                ? constraints.maxWidth * masonryFactor!
                : constraints.maxHeight - 16;
            Widget image = Container(
              decoration: BoxDecoration(
                color: context.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.toOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: KostoriHero(
                tag: heroTag != null
                    ? '$heroTag-${bangumiItem.id}'
                    : bangumiItem.id.toString(),
                child: BangumiWidget.kostoriImage(
                  context,
                  bangumiItem.images['large']!,
                  width: constraints.maxWidth,
                  height: height,
                  // 按显示宽度解码（非原图尺寸），减小缓存占用并加快重新加载
                  cacheWidth:
                      (constraints.maxWidth *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                ),
              ),
            );

            final textPainter = TextPainter(
              text: TextSpan(text: title, style: style),
              maxLines: 1,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            final shouldScroll = textPainter.width >= constraints.maxWidth - 30;

            Offset pressPosition = Offset.zero;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (onTap != null) {
                  onTap?.call(bangumiItem);
                } else {
                  App.mainNavigatorKey?.currentContext?.to(
                    () => BangumiInfoPage(
                      bangumiItem: bangumiItem,
                      heroTag: heroTag,
                    ),
                  );
                }
              },
              onTapDown: (detail) => pressPosition = detail.globalPosition,
              onLongPress: onLongPressed != null
                  ? () => onLongPressed?.call(bangumiItem)
                  : () => _showBangumiMenu(
                      context,
                      pressPosition,
                      bangumiItem,
                      heroTag,
                    ),
              onSecondaryTapDown: (detail) => _showBangumiMenu(
                context,
                detail.globalPosition,
                bangumiItem,
                heroTag,
              ),
              child: Column(
                children: [
                  if (masonry)
                    SizedBox(
                      width: double.infinity,
                      height: height,
                      child: Stack(
                        children: [
                          Positioned.fill(child: image),
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
                                          ? backdropFilter(_buildScore(context))
                                          : containerBackground(
                                              _buildScore(context),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: image),
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
                                          ? backdropFilter(_buildScore(context))
                                          : containerBackground(
                                              _buildScore(context),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (masonry)
                    // 瀑布流卡片高：标题不限行数，按内容换行完整显示
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Text(
                        title,
                        style: style,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: SizedBox(
                        height: 20,
                        child: ClipRect(
                          child: useMarquee && shouldScroll
                              ? Marquee(
                                  text: title,
                                  style: style,
                                  scrollAxis: Axis.horizontal,
                                  blankSpace: 10.0,
                                  velocity: 40.0,
                                  pauseAfterRound: Duration.zero,
                                  accelerationDuration: Duration.zero,
                                  decelerationDuration: Duration.zero,
                                )
                              : Text(
                                  title,
                                  style: style,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ),
                    ),
                ],
              ).paddingHorizontal(2).paddingVertical(2),
            );
          },
        ),
      ),
    );
  }
}

class _StaticStars extends StatelessWidget {
  const _StaticStars({required this.rating, this.size = 12});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filledColor = cs.primary;
    final emptyColor = cs.onSurface.withValues(alpha: 0.2);
    // 星形图标自带横向留白，收紧每颗星的槽宽让星星靠得更近
    final slot = size * 0.84;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          SizedBox(
            width: slot,
            height: size,
            child: OverflowBox(
              maxWidth: size,
              maxHeight: size,
              child: _Star(
                size: size,
                fill: (rating - i).clamp(0.0, 1.0),
                filledColor: filledColor,
                emptyColor: emptyColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({
    required this.size,
    required this.fill,
    required this.filledColor,
    required this.emptyColor,
  });

  final double size;

  final double fill;
  final Color filledColor;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(Icons.star_rounded, size: size, color: emptyColor),
          if (fill > 0)
            ClipRect(
              clipper: _FillClipper(fill),
              child: Icon(Icons.star_rounded, size: size, color: filledColor),
            ),
        ],
      ),
    );
  }
}

class _FillClipper extends CustomClipper<Rect> {
  const _FillClipper(this.fill);

  final double fill;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width * fill, size.height);

  @override
  bool shouldReclip(_FillClipper oldClipper) => oldClipper.fill != fill;
}

class BangumiDetailedCard extends StatelessWidget {
  final BangumiItem bangumiItem;
  final String heroTag;
  final void Function(BangumiItem)? onTap;
  final void Function(BangumiItem)? onLongPressed;

  const BangumiDetailedCard({
    super.key,
    required this.bangumiItem,
    required this.heroTag,
    this.onTap,
    this.onLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight - 16;

        Widget image = Container(
          width: height * 0.72,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: context.colorScheme.outlineVariant,
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: KostoriHero(
            tag: '$heroTag-${bangumiItem.id}',
            child: BangumiWidget.kostoriImage(
              context,
              bangumiItem.images['large']!,
              width: height * 0.72,
              height: height,
            ),
          ),
        );

        Offset pressPosition = Offset.zero;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (onTap != null) {
              onTap!(bangumiItem);
            } else {
              App.mainNavigatorKey?.currentContext?.to(
                () =>
                    BangumiInfoPage(bangumiItem: bangumiItem, heroTag: heroTag),
              );
            }
          },
          onTapDown: (detail) => pressPosition = detail.globalPosition,
          onLongPress: onLongPressed != null
              ? () => onLongPressed!(bangumiItem)
              : () => _showBangumiMenu(
                  context,
                  pressPosition,
                  bangumiItem,
                  heroTag,
                ),
          onSecondaryTapDown: (detail) => _showBangumiMenu(
            context,
            detail.globalPosition,
            bangumiItem,
            heroTag,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                image,
                SizedBox.fromSize(size: Size(16, 5)),
                Expanded(child: _bangumiDescription(context, bangumiItem)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bangumiDescription(BuildContext context, BangumiItem bangumiItem) {
    final now = DateTime.now();
    final air = Utils.safeParseDate(bangumiItem.airDate);

    String status;
    if (bangumiItem.totalEpisodes > 0) {
      if (air != null && air.isBefore(now)) {
        status = t.fullBEpisodesReleased(b: bangumiItem.totalEpisodes);
      } else {
        status = t.notYetAiring;
      }
    } else {
      if (air != null && air.isBefore(now)) {
        status = '';
      } else {
        status = t.notYetAiring;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bangumiItem.nameCn,
          style: const TextStyle(fontWeight: FontWeight.bold, height: 1.2),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          bangumiItem.name,
          style: TextStyle(color: Colors.grey[600]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
          children: [
            if (bangumiItem.airDate.isNotEmpty)
              Text(
                bangumiItem.airDate,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            if (bangumiItem.airDate.isNotEmpty && status != '')
              const Text(
                ' • ',
                style: TextStyle(fontWeight: FontWeight.bold, height: 1.2),
              ),
            if (status != '')
              Text(
                status,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        const Spacer(),
        Align(
          alignment: Alignment.bottomRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (bangumiItem.total >= 20) ...[
                Text(
                  formatScore(bangumiItem.score),
                  style: const TextStyle(fontSize: 24.0),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondaryContainer
                          .toOpacity(0.72),
                      width: 2.0,
                    ),
                  ),
                  child: Text(
                    Utils.getRatingLabel(bangumiItem.score),
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StaticStars(rating: bangumiItem.score / 2, size: 16.0),
                  Text(
                    t.tReviewsR(r: bangumiItem.rank, t: bangumiItem.total),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BangumiCharacterCard extends StatelessWidget {
  const BangumiCharacterCard({
    super.key,
    required this.character,
    required this.heroTag,
    this.onTap,
    this.onLongPressed,
    required this.isCharacter,
    this.useMarquee = true,
  });

  final CharacterActor character;
  final String heroTag;
  final bool isCharacter;
  final bool useMarquee;
  final void Function(CharacterActor)? onTap;
  final void Function(CharacterActor)? onLongPressed;

  @override
  Widget build(BuildContext context) {
    final title = character.nameCN.isNotEmpty
        ? character.nameCN
        : character.name;
    final style = const TextStyle(fontWeight: FontWeight.w500);
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
      // blur 半径直接影响每帧合成开销：卡片滚动时覆盖层实时模糊下层，
      // sigma 10 是滑动卡顿的主要来源，降到 4 视觉仍清晰
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: context.brightness == Brightness.light
              ? Colors.white.toOpacity(0.3)
              : Colors.black.toOpacity(0.3),
          child: child,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight - 36;

          Widget image = Container(
            decoration: BoxDecoration(
              color: context.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.toOpacity(0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: KostoriHero(
              tag: '$heroTag-${character.id}',
              child: BangumiWidget.kostoriImage(
                context,
                character.images.large,
                width: constraints.maxWidth,
                height: height,
              ),
            ),
          );

          Widget titleWidget() {
            if (useMarquee) {
              final textPainter = TextPainter(
                text: TextSpan(text: title, style: style),
                maxLines: 1,
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: constraints.maxWidth);

              final shouldScroll =
                  textPainter.width >= constraints.maxWidth - 30;

              return SizedBox(
                height: 20,
                child: ClipRect(
                  child: shouldScroll
                      ? Marquee(
                          text: title,
                          style: style,
                          scrollAxis: Axis.horizontal,
                          blankSpace: 10.0,
                          velocity: 40.0,
                          pauseAfterRound: Duration.zero,
                          accelerationDuration: Duration.zero,
                          decelerationDuration: Duration.zero,
                        )
                      : Text(
                          title,
                          style: style,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              );
            } else {
              return SizedBox(
                width: constraints.maxWidth,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }
          }

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (onTap != null) {
                onTap?.call(character);
              } else {
                BangumiWidget.showBottomPage(
                  context,
                  isCharacter
                      ? CharacterPage(characterID: character.id)
                      : PersonPage(personID: character.id),
                );
              }
            },
            onLongPress: onLongPressed != null
                ? () => onLongPressed?.call(character)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: constraints.maxWidth,
                  height: height,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: character.images.large.isEmpty
                            ? SizedBox(
                                width: constraints.maxWidth,
                                height: height,
                              )
                            : image,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                  child: titleWidget(),
                ),
              ],
            ).paddingHorizontal(2).paddingVertical(2),
          );
        },
      ),
    );
  }
}

String formatScore(num value) {
  final d = value.toDouble();
  if (d == d.roundToDouble()) return d.toInt().toString();
  return d.toStringAsFixed(1);
}

class BangumiCard extends StatefulWidget {
  const BangumiCard({
    super.key,
    required this.bangumiItem,
    this.onTap,
    this.heroTag,
    this.width = 216,
    this.height = 300,
  });

  final BangumiItem bangumiItem;
  final void Function()? onTap;
  final String? heroTag;
  final double width;
  final double height;

  @override
  State<BangumiCard> createState() => _BangumiCardState();
}

class _BangumiCardState extends State<BangumiCard> {
  BangumiItem get bangumiItem => widget.bangumiItem;

  Widget _score() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          formatScore(bangumiItem.score),
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(width: 5),
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

            _StaticStars(
              rating: bangumiItem.score / 2,
              size: App.isAndroid ? 12 : 14,
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

  @override
  Widget build(BuildContext context) {
    // 各尺寸封面回退，避免某尺寸缺失时 image 为 null 崩溃
    String? image =
        widget.bangumiItem.images['large'] ??
        widget.bangumiItem.images['common'] ??
        widget.bangumiItem.images['medium'];
    final animeCardUseBlur = appdata.implicitData['animeCardUseBlur'] ?? false;
    final showOverlay = appdata.implicitData['showAnimeCardOverlay'] != false;
    final useMarquee = appdata.settings['tileTitleMarquee'] == true;
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
      // blur 半径直接影响每帧合成开销：卡片滚动时覆盖层实时模糊下层，
      // sigma 10 是滑动卡顿的主要来源，降到 4 视觉仍清晰
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: context.brightness == Brightness.light
              ? Colors.white.toOpacity(0.3)
              : Colors.black.toOpacity(0.3),
          child: child,
        ),
      );
    }

    return AnimatedTapRegion(
      borderRadius: 8,
      onTap: widget.onTap ?? () {},
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 无图时用占位色块，避免空指针
            final hasImage = image != null && image.isNotEmpty;
            Widget backgroundImage = hasImage
                ? BangumiWidget.kostoriImage(
                    context,
                    image,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  )
                : const SizedBox.shrink();

            backgroundImage = Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              clipBehavior: Clip.antiAlias,
              child: backgroundImage,
            );
            Widget foregroundImage = KostoriHero(
              tag: '${widget.heroTag}-${widget.bangumiItem.id}',
              child: hasImage
                  ? BangumiWidget.kostoriImage(
                      context,
                      image,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight * 0.85,
                    )
                  : const SizedBox.shrink(),
            );

            foregroundImage = Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              clipBehavior: Clip.antiAlias,
              child: foregroundImage,
            );
            final title = bangumiItem.nameCn == ''
                ? bangumiItem.name
                : bangumiItem.nameCn;
            final style = TextStyle(fontWeight: FontWeight.w500, fontSize: 12);
            final textPainter = TextPainter(
              text: TextSpan(text: title, style: style),
              maxLines: 1,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            final shouldScroll = textPainter.width >= constraints.maxWidth - 30;

            return Stack(
              children: [
                Positioned.fill(
                  child: Opacity(opacity: 0.2, child: backgroundImage),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                    top: 8,
                    bottom: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: constraints.maxHeight * 0.85,
                        width: constraints.maxWidth,
                        child: Stack(
                          children: [
                            Positioned.fill(child: foregroundImage),
                            if (showOverlay)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (bangumiItem.airTime != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: animeCardUseBlur
                                              ? backdropFilter(
                                                  Text(
                                                    bangumiItem.airDate,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              : containerBackground(
                                                  Text(
                                                    bangumiItem.airDate,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: animeCardUseBlur
                                            ? backdropFilter(_score())
                                            : containerBackground(_score()),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 8.0,
                            left: 4,
                            right: 4,
                            bottom: 4,
                          ),
                          child: useMarquee && shouldScroll
                              ? Marquee(
                                  text: title,
                                  style: style,
                                  scrollAxis: Axis.horizontal,
                                  blankSpace: 10.0,
                                  velocity: 40.0,
                                  pauseAfterRound: Duration.zero,
                                  accelerationDuration: Duration.zero,
                                  decelerationDuration: Duration.zero,
                                )
                              : Text(
                                  title,
                                  style: style,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
