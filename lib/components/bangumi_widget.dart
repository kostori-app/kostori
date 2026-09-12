// ignore_for_file: use_build_context_synchronously

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/custom_markdown_widget.dart';
import 'package:kostori/components/image_preview_widget.dart';
import 'package:kostori/components/translation_widget.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/character/character_casts_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/translation_service.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/pages/bangumi/character_page.dart';
import 'package:kostori/pages/bangumi/person_page.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/utils.dart';
import 'package:marquee/marquee.dart';
import 'package:skeletonizer/skeletonizer.dart';

part 'bangumi_cards.dart';

class BangumiWidget {
  static void showBottomPage(BuildContext context, Widget page) {
    showModalBottomSheet(
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 3 / 4,
        maxWidth: MediaQuery.sizeOf(context).width < 600
            ? MediaQuery.sizeOf(context).width
            : App.isDesktop
            ? MediaQuery.sizeOf(context).width * 9 / 16
            : MediaQuery.sizeOf(context).width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (context) => page,
    );
  }

  static Widget bangumiSkeletonSliverBrief() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Skeletonizer.zone(
                        child: Bone(
                          height: double.infinity,
                          width: double.infinity,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Positioned(
                        bottom: 34,
                        right: 4,
                        child: Skeletonizer.zone(
                          child: Bone.text(width: 40, fontSize: 12),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Skeletonizer.zone(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Bone.square(size: 12, uniRadius: 3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Bone.text(width: 60, fontSize: 7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Skeletonizer.zone(
                child: Bone.text(width: double.infinity, fontSize: 12),
              ),
            ],
          ),
        );
      }, childCount: 20),
      gridDelegate: SliverGridDelegateWithBangumiItems(true),
    );
  }

  static Widget bangumiSkeletonSliverDetailed() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        return LayoutBuilder(
          builder: (context, constrains) {
            final height = constrains.maxHeight - 16;
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Skeletonizer.zone(
                    child: Bone(
                      height: height,
                      width: height * 0.72,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Skeletonizer.zone(
                          child: Bone.text(fontSize: 16, width: 150),
                        ),
                        const SizedBox(height: 4),
                        Skeletonizer.zone(
                          child: Bone.text(fontSize: 12, width: 100),
                        ),
                        const SizedBox(height: 8),
                        Skeletonizer.zone(
                          child: Row(
                            children: [
                              Bone.text(width: 30, fontSize: 12),
                              const SizedBox(width: 4),
                              Bone(
                                width: 60,
                                height: 20,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Skeletonizer.zone(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Bone.text(width: 30, fontSize: 24),
                                const SizedBox(width: 5),
                                Bone(
                                  width: 60,
                                  height: 24,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                const SizedBox(width: 4),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Bone.text(width: 80, fontSize: 10),
                                    const SizedBox(height: 2),
                                    Bone.text(width: 80, fontSize: 10),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }, childCount: 20),
      gridDelegate: SliverGridDelegateWithBangumiItems(false),
    );
  }

  static Widget buildStatsRow({
    required BuildContext context,
    required BangumiItem bangumiItem,
    bool isCenter = false,
  }) {
    final collection = bangumiItem.collection ?? const {};
    final total = collection.values.fold<int>(0, (sum, val) => sum + val);

    String formatCount(int number) {
      if (number >= 1000) {
        final k = number ~/ 1000;
        final r = (number % 1000) ~/ 100;
        return '${k}k$r';
      }
      return number.toString();
    }

    final stats = [
      StatItem('doing', t.doing, Theme.of(context).colorScheme.primary),
      StatItem('collect', t.collect, Theme.of(context).colorScheme.error),
      StatItem('wish', t.wish, Colors.blueAccent),
      StatItem('onHold', t.onHold, null),
      StatItem('dropped', t.dropped, Colors.grey),
    ];

    return Column(
      crossAxisAlignment: isCenter
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isCenter
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            ...stats.expand((stat) sync* {
              yield Text(
                '${formatCount(collection[stat.key] ?? 0)} ${stat.label}',
                style: TextStyle(fontSize: 12, color: stat.color),
              );
              if (stat != stats.last) {
                yield Text(
                  ' / ',
                  style: TextStyle(fontSize: 12, color: stat.color),
                );
              }
            }),
          ],
        ),
        SizedBox(height: 3),
        Text(
          t.tTotalCount(t: formatCount(total)),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  static Widget bangumiTimeText(
    BangumiItem bangumiItem,
    Map<bool, EpisodeInfo?> currentWeekEp,
    bool isCompleted,
  ) {
    final now = DateTime.now();
    if (currentWeekEp.isEmpty) {
      return Expanded(
        child: Text(
          t.notBroadcast,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    final ep = currentWeekEp.values.first;

    if (ep?.sort != null) {
      return Expanded(
        child: Text(
          isCompleted
              ? t.fullBEpisodesReleased(b: bangumiItem.totalEpisodes)
              : ep?.sort == ep?.ep
              ? t.upToEpSTotalEpsPlanned(
                  s: ep!.sort.toCleanString(),
                  t: bangumiItem.totalEpisodes,
                )
              : t.upToEpETotalEpsPlanned(
                  e: ep!.ep,
                  s: ep.sort.toCleanString(),
                  t: bangumiItem.totalEpisodes,
                ),
          style: const TextStyle(fontSize: 12.0),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final airDate = Utils.safeParseDate(bangumiItem.airDate);

    if (airDate == null || !now.isAfter(airDate)) {
      return Text(
        t.notYetAiring,
        style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
      );
    }

    if (!isCompleted) {
      return const SizedBox.shrink();
    }

    return Text(
      t.fullBEpisodesReleased(b: bangumiItem.totalEpisodes),
      style: const TextStyle(fontSize: 12.0),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  static Future<void> showImagePreview({
    required BuildContext context,
    required String url,
    required String title,
    required String heroTag,
    List<File>? allUrls,
    int? initialIndex,
    ImageProvider? imageProvider,
    List<ImageProvider>? galleryProviders,
    List<String>? galleryHeroTags,
  }) async {
    try {
      final isLocal = File(url).existsSync();
      final initIndex = (galleryProviders != null && galleryProviders.isNotEmpty)
          ? (initialIndex ?? 0).clamp(0, galleryProviders.length - 1)
          : _resolveInitIndex(url, allUrls, initialIndex);
      final pageController = PageController(initialPage: initIndex);
      // 优先使用调用方传入的 provider（与被点击封面同 key，缓存必命中）；
      // 缺省用 bangumi 源构造，保证 ImageCache key 与 kostoriImage 一致
      final img =
          imageProvider ??
          (isLocal
              ? FileImage(File(url)) as ImageProvider
              : CachedImageProvider(url, sourceKey: 'bangumi'));

      // 本地文件推入前预热“与预览画廊一致的 ResizeImage 解码”，
      // 保证目标首帧已有图（否则首次无 hero 飞行，二次缓存后才正常）
      if (isLocal) {
        try {
          final mq = MediaQuery.of(context);
          final maxLogical = mq.size.width > mq.size.height
              ? mq.size.width
              : mq.size.height;
          final t = (maxLogical * mq.devicePixelRatio * 1.5).round();
          final decodeWidth = t < 200 ? 200 : (t > 3072 ? 3072 : t);
          await precacheImage(
            ResizeImage.resizeIfNeeded(decodeWidth, null, FileImage(File(url))),
            context,
          );
        } catch (_) {}
      }

      await App.rootContext.toBlurFade(
        () => ProviderScope(
          overrides: [
            imageListProvider.overrideWith((ref) => allUrls ?? []),
            currentIndexProvider.overrideWith((ref) => initIndex),
          ],
          child: ImagePreviewWidget(
            url: url,
            heroTag: heroTag,
            isLocal: isLocal,
            img: img,
            pageController: pageController,
            title: title,
            galleryProviders: galleryProviders,
            galleryHeroTags: galleryHeroTags,
          ),
        ),
      );
    } catch (e, s) {
      Log.error('showImagePreviewOverlay', '$e\n$s');
    }
  }

  /// 计算初始页码
  static int _resolveInitIndex(
    String url,
    List<File>? allUrls,
    int? initialIndex,
  ) {
    if (allUrls == null || allUrls.isEmpty) return 0;
    return initialIndex ??
        allUrls.indexWhere((f) => f.path == url).clamp(0, allUrls.length - 1);
  }

  static Widget kostoriImage(
    BuildContext context,
    String imageUrl, {
    double width = 100,
    double height = 100,
    bool enableDefaultSize = true,
    int? cacheWidth,
  }) {
    ImageProvider? findImageProvider() {
      ImageProvider image;
      image = CachedImageProvider(imageUrl, sourceKey: 'bangumi');

      return image;
    }

    var image = findImageProvider();
    if (image == null) {
      return const SizedBox();
    }

    if (enableDefaultSize) {
      return AnimatedImage(
        image: image,
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        cacheWidth: cacheWidth,
      );
    }
    return AnimatedImage(
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      cacheWidth: cacheWidth,
    );
  }
}

class StatItem {
  final String key;
  final String label;
  final Color? color;

  StatItem(this.key, this.label, this.color);
}

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TranslationController? translationController;
  final bool isLoading;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 7,
    this.translationController,
    this.isLoading = false,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText>
    with SingleTickerProviderStateMixin {
  bool expanded = false;
  late final AnimationController _controller;
  double _fullHeight = 0; // 完整内容高度（真实测量或估算）
  double _collapsedHeight = 0; // 折叠高度
  final GlobalKey _contentKey = GlobalKey();
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => expanded = !expanded);
    if (expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  // 测量 Markdown 完整渲染高度（post-frame），用于动画目标值
  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final ctx = _contentKey.currentContext;
      if (ctx == null) return;
      final h = ctx.size?.height ?? 0;
      if (h > 0 && h.isFinite && _fullHeight != h) {
        setState(() => _fullHeight = h);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 加载中：显示简介骨架占位
    if (widget.isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeletonizer.zone(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Bone.text(fontSize: 14, width: 300 + (i % 3) * 40),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final text = widget.text;
        final collapsedLines = widget.maxLines;

        Widget content() => Column(
          key: _contentKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomMarkdownWidget(data: text),
            if (widget.translationController != null) ...[
              const SizedBox(height: 4),
              TranslationOutput(controller: widget.translationController!),
            ],
          ],
        );

        // 估算是否需要折叠：纯文本行数超限
        final textLines = _estimateTextLines(text, maxWidth);
        final initialNeedsCollapse = textLines > collapsedLines;

        // 折叠高度估算（纯文本行高 × 行数；Markdown 额外高度由裁剪容忍）
        double estCollapsedHeight() {
          final tp = TextPainter(
            text: TextSpan(text: text),
            textDirection: TextDirection.ltr,
          );
          tp.layout(maxWidth: maxWidth);
          final lines = tp.computeLineMetrics().length;
          final lineHeight = tp.height / (lines > 0 ? lines : 1);
          final h = lineHeight * collapsedLines * 1.3;
          return h.isFinite && h > 0 ? h : 24.0 * collapsedLines;
        }

        final collapsedH = estCollapsedHeight();
        if (_collapsedHeight == 0) _collapsedHeight = collapsedH;
        if (_fullHeight == 0) _fullHeight = collapsedH * 3;
        _scheduleMeasure();

        // 内容区：无需折叠时直接完整显示；需要折叠时用 Stack + Positioned 让 child
        // 以自身完整尺寸布局（不被钳制 → 无 overflow），Stack 尺寸固定为动画高度 h 并
        // hardEdge 裁剪：文字顶部保留、从底部渐进收起；GlobalKey 测到的始终是完整高度。
        Widget contentArea() => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!initialNeedsCollapse) {
              return SizedBox(width: maxWidth, child: content());
            }
            // progress: 0=折叠, 1=展开
            final progress = _controller.value;
            final h =
                _collapsedHeight + (_fullHeight - _collapsedHeight) * progress;
            return SizedBox(
              width: maxWidth,
              height: h,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(top: 0, left: 0, right: 0, child: content()),
                ],
              ),
            );
          },
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            contentArea(),
            if (initialNeedsCollapse)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _toggle,
                    child: Text(expanded ? t.showLess : t.showMore),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  // 估算是否需要折叠：纯文本行数超限
  int _estimateTextLines(String text, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: maxWidth);
    return tp.computeLineMetrics().length;
  }
}

class ExpandableTags extends StatefulWidget {
  final List<dynamic> tags;
  final bool fullTag;
  final VoidCallback onToggle;
  final Function(int index) onTagTap;

  const ExpandableTags({
    super.key,
    required this.tags,
    required this.fullTag,
    required this.onToggle,
    required this.onTagTap,
  });

  static const int previewCount = 12;

  @override
  State<ExpandableTags> createState() => _ExpandableTagsState();
}

enum ToggleButtonType { showMore, showLess, none }

class _ExpandableTagsState extends State<ExpandableTags>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _showingTagsCount;
  ToggleButtonType _currentButton = ToggleButtonType.showMore;

  @override
  void initState() {
    super.initState();
    _showingTagsCount = widget.fullTag
        ? widget.tags.length
        : min(widget.tags.length, ExpandableTags.previewCount);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalDuration()),
    );

    if (widget.fullTag) {
      _controller.value = 1.0;
      _currentButton = ToggleButtonType.showLess;
    } else {
      _controller.value = 0.0;
      _currentButton = ToggleButtonType.showMore;
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        setState(() {
          _currentButton = widget.fullTag
              ? ToggleButtonType.showLess
              : ToggleButtonType.showMore;
          if (!widget.fullTag) {
            _showingTagsCount = min(
              widget.tags.length,
              ExpandableTags.previewCount,
            );
          }
        });
      }
    });
  }

  /// 动画总时长：基础 250ms + 额外标签每个 30ms，与 AnimatedSize 保持一致
  int _totalDuration() {
    final extraTags = max(widget.tags.length - ExpandableTags.previewCount, 0);
    return 250 + extraTags * 30;
  }

  @override
  void didUpdateWidget(covariant ExpandableTags oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fullTag != oldWidget.fullTag) {
      if (widget.fullTag) {
        setState(() {
          _showingTagsCount = widget.tags.length;
        });
        _currentButton = ToggleButtonType.none;
        _controller.forward();
      } else {
        _currentButton = ToggleButtonType.none;
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _animationForIndex(int index) {
    // 交错区间：每个额外标签延迟 5% 出现；start 封顶 0.6，保证所有标签都会出现
    final stagger = (index - ExpandableTags.previewCount) * 0.05;
    final start = stagger.clamp(0.0, 0.6);
    final end = min(start + 0.4, 1.0);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  void _handleToggle() {
    widget.onToggle();
  }

  Widget _buildToggleButton() {
    if (widget.tags.length < ExpandableTags.previewCount) {
      return const SizedBox();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        final scaleAnim = Tween<double>(
          begin: 0.1,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            alignment: Alignment.centerLeft,
            scale: scaleAnim,
            child: child,
          ),
        );
      },
      child: _currentButton == ToggleButtonType.none
          ? const SizedBox(key: ValueKey('empty_button'))
          : ActionChip(
              key: ValueKey(_currentButton),
              label: Text(
                _currentButton == ToggleButtonType.showLess
                    ? t.showLess
                    : t.showMore,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onPressed: _handleToggle,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Duration(milliseconds: _totalDuration()),
      curve: Curves.easeInOut,
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          ...List.generate(_showingTagsCount, (index) {
            final isPreview = index < ExpandableTags.previewCount;
            final animation = isPreview
                ? AlwaysStoppedAnimation(1.0)
                : _animationForIndex(index);

            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final scale = 0.9 + 0.1 * animation.value;
                return Opacity(
                  opacity: animation.value,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: ActionChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${widget.tags[index].name} '),
                    Text(
                      '${widget.tags[index].count}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                onPressed: () => widget.onTagTap(index),
              ),
            );
          }),
          _buildToggleButton(),
        ],
      ),
    );
  }
}

/// 显示 Bangumi 条目的长按菜单（含预览图片、复制标题）
void _showBangumiMenu(
  BuildContext context,
  Offset location,
  BangumiItem item,
  Object? heroTag,
) {
  final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
  final hero = heroTag != null ? '$heroTag-${item.id}' : item.id.toString();
  showMenuX(context, location, [
    MenuEntry(
      icon: Icons.image_outlined,
      text: t.preview,
      onClick: () => BangumiWidget.showImagePreview(
        context: App.rootContext,
        url: item.images['large'] ?? '',
        title: title,
        heroTag: hero,
      ),
    ),
    MenuEntry(
      icon: Icons.copy,
      text: t.copyTitle,
      onClick: () {
        Clipboard.setData(ClipboardData(text: title));
        App.rootContext.showMessage(message: t.titleCopied);
      },
    ),
  ]);
}


/// 状态保存
class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveWrapper> createState() => KeepAliveWrapperState();
}

class KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// 安全加载 Bangumi 头像：走应用统一的 CachedImageProvider + AnimatedImage，
/// 加载失败时展示占位图标而非抛出未处理的网络异常。
class BangumiAvatar extends StatelessWidget {
  final String url;
  final double radius;
  final IconData fallbackIcon;

  const BangumiAvatar({
    super.key,
    required this.url,
    this.radius = 20,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(
          fallbackIcon,
          size: radius * 1.1,
          color: cs.onSurfaceVariant,
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.surfaceContainerHighest,
      child: ClipOval(
        child: AnimatedImage(
          image: CachedImageProvider(url, sourceKey: 'bangumi'),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
