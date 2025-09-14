// ignore_for_file: use_build_context_synchronously

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/pages/bangumi/bangumi_search_page.dart';
import 'package:kostori/utils/extension.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:marquee/marquee.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BangumiWidget {
  static Widget buildBriefMode(
    BuildContext context,
    BangumiItem bangumiItem,
    String heroTag, {
    bool showPlaceholder = true,
    void Function(BangumiItem)? onTap,
    void Function(BangumiItem)? onLongPressed,
  }) {
    Widget score() {
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
            SizedBox(width: 4),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end, // 右对齐
            children: [
              RatingBarIndicator(
                itemCount: 5,
                rating: bangumiItem.score.toDouble() / 2,
                itemBuilder: (context, index) => const Icon(Icons.star_rounded),
                itemSize: App.isAndroid ? 12 : 14.0,
              ),
              Text(
                '@t reviews | #@r'.tlParams({
                  'r': bangumiItem.rank,
                  't': bangumiItem.total,
                }),
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
                showPlaceholder: showPlaceholder,
              ),
            ),
          );

          final title = bangumiItem.nameCn == ''
              ? bangumiItem.name
              : bangumiItem.nameCn;
          const style = TextStyle(fontWeight: FontWeight.w500);

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
                onTap(bangumiItem);
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
                ? () => onLongPressed(bangumiItem)
                : null,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: image),
                      if (bangumiItem.airDate.isNotEmpty)
                        Positioned(
                          bottom: App.isAndroid ? 34 : 40,
                          right: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: 0.6,
                                          child: Image.asset(
                                            'assets/img/noise.png',
                                            // 模拟毛玻璃颗粒的纹理图
                                            fit: BoxFit.cover,
                                            color:
                                                context.brightness ==
                                                    Brightness.light
                                                ? Colors.white.toOpacity(0.3)
                                                : Colors.black.toOpacity(0.3),
                                            colorBlendMode: BlendMode.srcOver,
                                          ),
                                        ),
                                      ),
                                      // 渐变遮罩（调整透明度过渡）
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                context.brightness ==
                                                    Brightness.light
                                                ? Colors.white.toOpacity(0.3)
                                                : Colors.black.toOpacity(0.3),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 原有内容（需要在模糊层之上）
                                Padding(
                                  padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                                  child: Text(
                                    bangumiItem.airDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: 0.6,
                                        child: Image.asset(
                                          'assets/img/noise.png',
                                          fit: BoxFit.cover,
                                          color:
                                              context.brightness ==
                                                  Brightness.light
                                              ? Colors.white.toOpacity(0.3)
                                              : Colors.black.toOpacity(0.3),
                                          colorBlendMode: BlendMode.srcOver,
                                        ),
                                      ),
                                    ),

                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              context.brightness ==
                                                  Brightness.light
                                              ? Colors.white.toOpacity(0.3)
                                              : Colors.black.toOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                                child: score(),
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

  static Widget buildDetailedMode(
    BuildContext context,
    BangumiItem bangumiItem,
    String heroTag, {
    void Function(BangumiItem)? onTap,
    void Function(BangumiItem)? onLongPressed,
  }) {
    return LayoutBuilder(
      builder: (context, constrains) {
        final height = constrains.maxHeight - 16;

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
              onTap(bangumiItem);
            } else {
              App.mainNavigatorKey?.currentContext?.to(
                () =>
                    BangumiInfoPage(bangumiItem: bangumiItem, heroTag: heroTag),
              );
            }
          },
          onLongPress: onLongPressed != null
              ? () => onLongPressed(bangumiItem)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                image,
                SizedBox.fromSize(size: const Size(16, 5)),
                Expanded(child: _bangumiDescription(context, bangumiItem)),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _bangumiDescription(
    BuildContext context,
    BangumiItem bangumiItem,
  ) {
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
          style: TextStyle(
            // fontSize: imageWidth * 0.12,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          bangumiItem.name,
          style: TextStyle(
            // fontSize: imageWidth * 0.08,
            color: Colors.grey[600],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
          children: [
            if (bangumiItem.airDate.isNotEmpty)
              Text(
                bangumiItem.airDate,
                style: TextStyle(
                  // fontSize: imageWidth * 0.12,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            if (bangumiItem.airDate.isNotEmpty && status != '')
              Text(
                ' • ',
                style: TextStyle(
                  // fontSize: imageWidth * 0.12,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            if (status != '')
              Text(
                status,
                style: TextStyle(
                  // fontSize: imageWidth * 0.12,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        const Spacer(),
        // 评分信息
        Align(
          alignment: Alignment.bottomRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (bangumiItem.total >= 20) ...[
                Text('${bangumiItem.score}', style: TextStyle(fontSize: 24.0)),
                SizedBox(width: 5),
                Container(
                  padding: EdgeInsets.all(2.0), // 可选，设置内边距
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8), // 设置圆角半径
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.toOpacity(0.72),
                      width: 2.0, // 设置边框宽度
                    ),
                  ),
                  child: Text(
                    Utils.getRatingLabel(bangumiItem.score),
                    style: TextStyle(fontSize: 12.0),
                  ),
                ),
                SizedBox(width: 4),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.end, // 右对齐
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
                    style: TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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

  static Widget buildStatsRow(BuildContext context, BangumiItem bangumiItem) {
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...stats.expand(
              (stat) => [
                Text(
                  '${formatCount(collection[stat.key] ?? 0)} ${stat.label}',
                  style: TextStyle(fontSize: 12, color: stat.color),
                ),
                const Text(' / '),
              ],
            ),
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

  static Future<void> showImagePreview(
    BuildContext context,
    String url,
    String title,
    String heroTag, {
    List<File>? allUrls,
    int? initialIndex,
  }) async {
    try {
      final isLocal = File(url).existsSync();

      // 计算初始索引
      int initIndex = 0;
      if (allUrls != null && allUrls.isNotEmpty) {
        initIndex =
            initialIndex ??
            allUrls
                .indexWhere((f) => f.path == url)
                .clamp(0, allUrls.length - 1);
      }

      final pageController = PageController(initialPage: initIndex);
      final urls = ValueNotifier<List<File>>(allUrls ?? []);
      final currentIndex = ValueNotifier<int>(initIndex);

      final ImageProvider img = isLocal
          ? FileImage(File(url))
          : NetworkImage(url);

      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  SizedBox.expand(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Center(
                    child: ValueListenableBuilder<List<File>>(
                      valueListenable: urls,
                      builder: (context, imageList, _) {
                        if (imageList.length > 1) {
                          return PhotoViewGallery.builder(
                            itemCount: imageList.length,
                            pageController: pageController,
                            backgroundDecoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            onPageChanged: (i) => currentIndex.value = i,
                            builder: (context, i) {
                              final file = imageList[i];
                              return PhotoViewGalleryPageOptions(
                                imageProvider: FileImage(file),
                                heroAttributes: PhotoViewHeroAttributes(
                                  tag: file.path,
                                ),
                                initialScale: PhotoViewComputedScale.contained,
                                minScale: PhotoViewComputedScale.contained / 3,
                                maxScale: PhotoViewComputedScale.covered * 100,
                              );
                            },
                          );
                        } else {
                          return PhotoView.customChild(
                            initialScale: PhotoViewComputedScale.contained,
                            minScale: PhotoViewComputedScale.contained / 3,
                            maxScale: PhotoViewComputedScale.covered * 100,
                            heroAttributes: PhotoViewHeroAttributes(
                              tag: heroTag,
                            ),
                            backgroundDecoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: AnimatedImage(
                              image: img,
                              fit: BoxFit.contain,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
                  // 顶部操作栏
                  Positioned(
                    top: context.padding.top,
                    left: 16,
                    right: 16,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          _iconBackground(
                            icon: Icons.close,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ValueListenableBuilder<int>(
                              valueListenable: currentIndex,
                              builder: (context, index, _) {
                                final file = urls.value.isNotEmpty
                                    ? urls.value[index]
                                    : File(url);
                                final filename = file.path
                                    .split(Platform.pathSeparator)
                                    .last;
                                return _textBackground(filename);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          isLocal
                              ? ValueListenableBuilder<int>(
                                  valueListenable: currentIndex,
                                  builder: (context, index, _) {
                                    if (urls.value.isEmpty && !isLocal) {
                                      return const SizedBox();
                                    }

                                    final currentFile = urls.value.isNotEmpty
                                        ? urls.value[index]
                                        : File(url);

                                    final localExists = currentFile
                                        .existsSync();

                                    return Row(
                                      children: [
                                        _iconBackground(
                                          icon: Icons.share,
                                          onPressed: () async {
                                            final filename = currentFile.path
                                                .split(Platform.pathSeparator)
                                                .last;
                                            Uint8List data = await currentFile
                                                .readAsBytes();
                                            await Share.shareFile(
                                              data: data,
                                              filename: filename,
                                              mime: 'image/png',
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        if (localExists)
                                          _iconBackground(
                                            icon: Icons.delete,
                                            onPressed: () async {
                                              showConfirmDialog(
                                                context: context,
                                                title: "确认删除该图片?".tl,
                                                content: '删除后将无法恢复',
                                                btnColor: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                                onConfirm: () async {
                                                  try {
                                                    await currentFile.delete();

                                                    if (urls.value.isNotEmpty) {
                                                      urls.value.removeAt(
                                                        index,
                                                      );

                                                      if (urls.value.isEmpty) {
                                                        Navigator.pop(context);
                                                        return;
                                                      }

                                                      final newIndex =
                                                          index >=
                                                              urls.value.length
                                                          ? urls.value.length -
                                                                1
                                                          : index;

                                                      currentIndex.value =
                                                          newIndex;
                                                      urls.value = [
                                                        ...urls.value,
                                                      ];

                                                      WidgetsBinding.instance
                                                          .addPostFrameCallback(
                                                            (_) {
                                                              if (pageController
                                                                  .hasClients) {
                                                                pageController
                                                                    .jumpToPage(
                                                                      newIndex,
                                                                    );
                                                              }
                                                            },
                                                          );
                                                    } else {
                                                      Navigator.pop(context);
                                                    }
                                                  } catch (e) {
                                                    Log.addLog(
                                                      LogLevel.error,
                                                      '删除失败',
                                                      e.toString(),
                                                    );
                                                    context.showMessage(
                                                      message: '删除失败: $e',
                                                    );
                                                  }
                                                },
                                              );
                                            },
                                          ),
                                      ],
                                    );
                                  },
                                )
                              : _iconBackground(
                                  icon: Icons.download,
                                  onPressed: () {
                                    saveImageToGallery(context, url);
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'showImagePreviewOverlay', '$e\n$s');
    }
  }

  static Widget _iconBackground({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.toOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  static Widget _textBackground(String title) {
    const style = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.toOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textPainter = TextPainter(
              text: TextSpan(text: title, style: style),
              maxLines: 1,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            final shouldScroll =
                textPainter.width >= constraints.maxWidth * 0.7;

            return ClipRect(
              child: shouldScroll
                  ? Marquee(
                      text: title,
                      style: style,
                      scrollAxis: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      blankSpace: 10.0,
                      velocity: 40.0,
                      pauseAfterRound: Duration.zero,
                      accelerationDuration: Duration.zero,
                      decelerationDuration: Duration.zero,
                    )
                  : Text(
                      title,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            );
          },
        ),
      ),
    );
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

      if (App.isAndroid) {
        final folder = await KostoriFolder.checkPermissionAndPrepareFolder();
        if (folder != null) {
          final file = File(
            '${folder.path}/${_generateFilename(imageUrl)}.png',
          );
          await file.writeAsBytes(response.data!);

          // 调用弹窗/提示等
          showCenter(
            seconds: 1,
            icon: Gif(
              image: const AssetImage('assets/img/check.gif'),
              height: 80,
              fps: 120,
              color: Theme.of(context).colorScheme.primary,
              autostart: Autostart.once,
            ),
            message: '保存成功',
            context: context,
          );
          const platform = MethodChannel('kostori/media');
          await platform.invokeMethod('scanFolder', {'path': folder.path});
          Log.addLog(LogLevel.info, '保存长图成功', file.path);
        } else {
          showCenter(
            seconds: 3,
            icon: Gif(
              image: AssetImage('assets/img/warning.gif'),
              height: 64,
              fps: 120,
              color: Theme.of(context).colorScheme.primary,
              autostart: Autostart.once,
            ),
            message: '保存失败',
            context: context,
          );
          Log.addLog(LogLevel.error, '保存失败：权限或目录异常', '');
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final folderPath = '${directory.path}/Kostori';
        final folder = Directory(folderPath);

        if (!await folder.exists()) {
          await folder.create(recursive: true);
          Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
        }

        final filePath = '$folderPath/${_generateFilename(imageUrl)}';
        await File(filePath).writeAsBytes(response.data!);

        showCenter(
          seconds: 1,
          icon: Gif(
            image: const AssetImage('assets/img/check.gif'),
            height: 80,
            fps: 120,
            color: Theme.of(context).colorScheme.primary,
            autostart: Autostart.once,
          ),
          message: '保存成功',
          context: context,
        );

        Log.addLog(LogLevel.info, 'saveImageToGallery', filePath);
      }
    } catch (e, s) {
      showCenter(
        seconds: 3,
        icon: Gif(
          image: AssetImage('assets/img/warning.gif'),
          height: 64,
          fps: 120,
          color: Theme.of(context).colorScheme.primary,
          autostart: Autostart.once,
        ),
        message: '保存失败: ${e.toString()}',
        context: context,
      );
      Log.addLog(LogLevel.error, 'saveImageToGallery', '$e\n$s');
    }
  }

  static String _generateFilename(String url) {
    final uri = Uri.parse(url);
    final filename = uri.pathSegments.last;
    return filename.isNotEmpty
        ? 'bangumi_$filename'
        : 'bangumi_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  // 全局记录加载失败的图片 URL
  static final Set<String> _failedImageUrls = {};

  // 添加全部重置方法（可选）
  static void resetAllFailedImages() {
    _failedImageUrls.clear();
  }

  static Widget kostoriImage(
    BuildContext context,
    String imageUrl, {
    double width = 100,
    double height = 100,
    bool showPlaceholder = true,
    bool enableDefaultSize = true,
  }) {
    if (_failedImageUrls.contains(imageUrl)) {
      return MiscComponents.placeholder(
        context,
        width,
        height,
        Colors.transparent,
      );
    }

    //   //// We need this to shink memory usage
    int? memCacheWidth, memCacheHeight;
    double aspectRatio = (width / height).toDouble();

    void setMemCacheSizes() {
      if (aspectRatio > 1) {
        memCacheHeight = height.cacheSize(context);
      } else if (aspectRatio < 1) {
        memCacheWidth = width.cacheSize(context);
      } else {
        memCacheWidth = width.cacheSize(context);
        memCacheHeight = height.cacheSize(context);
      }
    }

    setMemCacheSizes();

    if (memCacheWidth == null && memCacheHeight == null) {
      memCacheWidth = width.toInt();
    }

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
        cacheWidth: memCacheWidth,
        cacheHeight: memCacheHeight,
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

  const ExpandableText({super.key, required this.text, this.maxLines = 7});

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
          return SelectableText(
            widget.text,
            scrollPhysics: const NeverScrollableScrollPhysics(),
            selectionHeightStyle: ui.BoxHeightStyle.max,
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
                  child: SelectableText(
                    widget.text,
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                  ),
                ),
                // if (!expanded)
                //   Positioned(
                //     bottom: 0,
                //     left: 0,
                //     right: 0,
                //     child: Container(
                //       color: Theme.of(context).scaffoldBackgroundColor,
                //       padding: const EdgeInsets.only(left: 2.0),
                //       child: Text(
                //         '...',
                //         style: TextStyle(fontWeight: FontWeight.bold),
                //       ),
                //     ),
                //   ),
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

class ExpandableTags extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axis: Axis.vertical,
            axisAlignment: -1.0,
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: Wrap(
        key: ValueKey(fullTag),
        spacing: 8.0,
        runSpacing: App.isDesktop ? 8 : 0,
        children: [
          ...List<Widget>.generate(
            fullTag ? tags.length : min(12, tags.length),
            (index) => ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${tags[index].name} '),
                  Text(
                    '${tags[index].count}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              onPressed: () => onTagTap(index),
            ),
          ),
          if (tags.length > 12)
            ActionChip(
              label: Text(
                fullTag ? 'Show less -'.tl : 'Show more +'.tl,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}
