// ignore_for_file: use_build_context_synchronously

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
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
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/pages/bangumi/bangumi_search_page.dart';
import 'package:kostori/pages/bangumi/character_page.dart';
import 'package:kostori/pages/bangumi/person_page.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:marquee/marquee.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BangumiWidget {
  static void showBottomPage(BuildContext context, Widget page) {
    showModalBottomSheet(
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
        maxWidth: MediaQuery.of(context).size.width < 600
            ? MediaQuery.of(context).size.width
            : App.isDesktop
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
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
    final collection = bangumiItem.collection!;
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
      StatItem('doing', 'doing'.tl, Theme.of(context).colorScheme.primary),
      StatItem('collect', 'collect'.tl, Theme.of(context).colorScheme.error),
      StatItem('wish', 'wish'.tl, Colors.blueAccent),
      StatItem('on_hold', 'on hold'.tl, null),
      StatItem('dropped', 'dropped'.tl, Colors.grey),
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
          '@t Total count'.tlParams({'t': formatCount(total)}),
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
    // DateTime time = Utils.safeParseDate(now.toString())!;
    return (currentWeekEp.values.first?.sort != null)
        ? Expanded(
            child: Text(
              isCompleted
                  ? 'Full @b episodes released'.tlParams({
                      'b': bangumiItem.totalEpisodes,
                    })
                  : currentWeekEp.values.first?.sort ==
                        currentWeekEp.values.first?.ep
                  ? 'Up to ep @s • Total @t eps planned'.tlParams({
                      's': currentWeekEp.values.first?.sort as int,
                      't': bangumiItem.totalEpisodes,
                    })
                  : 'Up to ep @e (@s) • Total @t eps planned'.tlParams({
                      'e': currentWeekEp.values.first?.ep as int,
                      's': currentWeekEp.values.first?.sort as int,
                      't': bangumiItem.totalEpisodes,
                    }),
              style: TextStyle(fontSize: 12.0),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : (!now.isAfter(Utils.safeParseDate(bangumiItem.airDate)!))
        ? Text(
            'Not Yet Airing'.tl,
            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
          )
        : Text(
            'Full @b episodes released'.tlParams({
              'b': bangumiItem.totalEpisodes,
            }),
            style: TextStyle(fontSize: 12.0),
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
  }) async {
    try {
      final isLocal = File(url).existsSync();
      final initIndex = _resolveInitIndex(url, allUrls, initialIndex);
      final pageController = PageController(initialPage: initIndex);
      final img = isLocal
          ? FileImage(File(url)) as ImageProvider
          : NetworkImage(url);

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
          ),
        ),
      );
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'showImagePreviewOverlay', '$e\n$s');
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

  static Future<void> saveImageToGallery(
    BuildContext context,
    String imageUrl,
  ) async {
    try {
      context.showMessage(message: '正在保存图片...');

      final response = await AppDio().request<Uint8List>(
        imageUrl,
        options: Options(method: 'GET', responseType: ResponseType.bytes),
      );

      final savedPath = await _saveImageToLocalFolder(imageUrl, response.data!);

      if (savedPath != null) {
        _showResult(context, success: true);
        Log.addLog(LogLevel.info, 'saveImageToGallery', savedPath);
      } else {
        _showResult(context, success: false, message: '保存失败：权限或目录异常');
        Log.addLog(LogLevel.error, '保存失败：权限或目录异常', '');
      }
    } catch (e, s) {
      _showResult(context, success: false, message: '保存失败: $e');
      Log.addLog(LogLevel.error, 'saveImageToGallery', '$e\n$s');
    }
  }

  static Future<String?> _saveImageToLocalFolder(
    String imageUrl,
    Uint8List data,
  ) async {
    if (App.isAndroid) {
      final folder = await KostoriFolder.checkPermissionAndPrepareFolder();
      if (folder == null) return null;

      final file = File('${folder.path}/${_generateFilename(imageUrl)}.png');
      await file.writeAsBytes(data);

      const platform = MethodChannel('kostori/media');
      await platform.invokeMethod('scanFolder', {'path': folder.path});
      return file.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final folderPath = '${directory.path}/Kostori';
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        await folder.create(recursive: true);
        Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
      }

      final filePath = '$folderPath/${_generateFilename(imageUrl)}';
      await File(filePath).writeAsBytes(data);
      return filePath;
    }
  }

  static void _showResult(
    BuildContext context, {
    required bool success,
    String? message,
  }) {
    showCenter(
      seconds: success ? 1 : 3,
      icon: Gif(
        image: AssetImage(
          success ? 'assets/img/check.gif' : 'assets/img/warning.gif',
        ),
        height: success ? 80 : 64,
        fps: 120,
        color: Theme.of(context).colorScheme.primary,
        autostart: Autostart.once,
      ),
      message: message ?? (success ? '保存成功' : '保存失败'),
      context: context,
    );
  }

  static String _generateFilename(String url) {
    final uri = Uri.parse(url);
    final filename = uri.pathSegments.last;
    return filename.isNotEmpty
        ? 'bangumi_$filename'
        : 'bangumi_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  ///sourcekey写死了bangumi所以可想而知是用在哪的
  static Widget kostoriImage(
    BuildContext context,
    String imageUrl, {
    double width = 100,
    double height = 100,
    bool enableDefaultSize = true,
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
      );
    }
    return AnimatedImage(
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
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

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 7,
    this.translationController,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool expanded = false;
  double? collapsedHeight;
  double? fullHeight;

  double _computeHeight(String text, double maxWidth, {int? maxLines}) {
    final tp = TextPainter(
      text: TextSpan(text: text),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );
    tp.layout(maxWidth: maxWidth);
    return tp.height;
  }

  int _computeNumLines(String text, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: maxWidth);
    return tp.computeLineMetrics().length;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final numLines = _computeNumLines(widget.text, maxWidth);
        fullHeight ??= _computeHeight(widget.text, maxWidth);
        if (numLines <= widget.maxLines) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomMarkdownWidget(data: widget.text),
              if (widget.translationController!.isTranslating ||
                  (widget.translationController!.isTranslationComplete &&
                      widget.translationController != null)) ...[
                const SizedBox(height: 16),
                TranslatedContent(
                  data: widget.text,
                  translationController: widget.translationController!,
                ),
              ],
            ],
          );
        }
        collapsedHeight ??= _computeHeight(
          widget.text,
          maxWidth,
          maxLines: widget.maxLines,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: expanded ? fullHeight! : collapsedHeight!,
                    end: expanded ? fullHeight! : collapsedHeight!,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.topLeft,
                        heightFactor: value / fullHeight!,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomMarkdownWidget(data: widget.text),
                      if (widget.translationController!.isTranslating ||
                          (widget
                                  .translationController!
                                  .isTranslationComplete &&
                              widget.translationController != null)) ...[
                        const SizedBox(height: 16),
                        TranslatedContent(
                          data: widget.text,
                          translationController: widget.translationController!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => expanded = !expanded),
                  child: Text(expanded ? 'Show less -'.tl : 'Show more +'.tl),
                ),
              ],
            ),
          ],
        );
      },
    );
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

    final extraTags = max(widget.tags.length - ExpandableTags.previewCount, 0);
    final totalDuration = 250 + extraTags * 30;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDuration),
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
    final start = min((index - ExpandableTags.previewCount) * 0.03, 1.0);
    final end = min(start + 0.25, 1.0);
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
                    ? 'Show less -'.tl
                    : 'Show more +'.tl,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onPressed: _handleToggle,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
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

class BangumiBriefCard extends StatelessWidget {
  final BangumiItem bangumiItem;
  final String heroTag;
  final void Function(BangumiItem)? onTap;
  final void Function(BangumiItem)? onLongPressed;

  const BangumiBriefCard({
    super.key,
    required this.bangumiItem,
    required this.heroTag,
    this.onTap,
    this.onLongPressed,
  });

  Widget _buildScore(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (bangumiItem.total >= 20) ...[
          Text(
            '${bangumiItem.score}',
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
            RatingBarIndicator(
              itemCount: 5,
              rating: bangumiItem.score.toDouble() / 2,
              itemBuilder: (context, index) => const Icon(Icons.star_rounded),
              itemSize: App.isAndroid ? 12 : 14.0,
            ),
            Text(
              '@t reviews'.tlParams({'t': bangumiItem.total}),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight - 16;
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
            child: Hero(
              tag: '$heroTag-${bangumiItem.id}',
              child: BangumiWidget.kostoriImage(
                context,
                bangumiItem.images['large']!,
                width: constraints.maxWidth,
                height: height,
              ),
            ),
          );

          final textPainter = TextPainter(
            text: TextSpan(text: title, style: style),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);

          final shouldScroll = textPainter.width >= constraints.maxWidth - 30;

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
            onLongPress: onLongPressed != null
                ? () => onLongPressed?.call(bangumiItem)
                : null,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: image),
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
                                    : containerBackground(_buildScore(context)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: SizedBox(
                    height: 20,
                    child: ClipRect(
                      child: shouldScroll
                          ? Marquee(
                              text: title,
                              style: style,
                              scrollAxis: Axis.horizontal,
                              blankSpace: 10.0,
                              velocity: 40.0,
                              // startPadding: 10.0,
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
    );
  }
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
          child: Hero(
            tag: '$heroTag-${bangumiItem.id}',
            child: BangumiWidget.kostoriImage(
              context,
              bangumiItem.images['large']!,
              width: height * 0.72,
              height: height,
            ),
          ),
        );

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
          onLongPress: onLongPressed != null
              ? () => onLongPressed!(bangumiItem)
              : null,
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
        status = 'Full @b episodes released'.tlParams({
          'b': bangumiItem.totalEpisodes,
        });
      } else {
        status = 'Not Yet Airing'.tl;
      }
    } else {
      if (air != null && air.isBefore(now)) {
        status = '';
      } else {
        status = 'Not Yet Airing'.tl;
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
                  '${bangumiItem.score}',
                  style: const TextStyle(fontSize: 24.0),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.toOpacity(0.72),
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
                  RatingBarIndicator(
                    itemCount: 5,
                    rating: bangumiItem.score.toDouble() / 2,
                    itemBuilder: (context, index) =>
                        const Icon(Icons.star_rounded),
                    itemSize: 16.0,
                  ),
                  Text(
                    '@t reviews | #@r'.tlParams({
                      'r': bangumiItem.rank,
                      't': bangumiItem.total,
                    }),
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
            child: Hero(
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
