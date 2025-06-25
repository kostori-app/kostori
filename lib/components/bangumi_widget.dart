// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:gif/gif.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/utils/extension.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';

import 'package:kostori/network/app_dio.dart';
import 'package:kostori/components/components.dart';

import '../foundation/image_loader/cached_image.dart';
import '../utils/io.dart';
import 'misc_components.dart';

class BangumiWidget {
  static Widget buildBriefMode(
      BuildContext context, BangumiItem bangumiItem, String heroTag,
      {bool showPlaceholder = true,
      void Function(BangumiItem)? onTap,
      void Function(BangumiItem)? onLongPressed}) {
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
            SizedBox(
              width: 4,
            ),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end, // 右对齐
            children: [
              RatingBarIndicator(
                itemCount: 5,
                rating: bangumiItem.score.toDouble() / 2,
                itemBuilder: (context, index) => const Icon(
                  Icons.star_rounded,
                ),
                itemSize: App.isAndroid ? 12 : 14.0,
              ),
              Text(
                '@t reviews | #@r'
                    .tlParams({'r': bangumiItem.rank, 't': bangumiItem.total}),
                style: TextStyle(
                    fontSize: App.isAndroid ? 7 : 9,
                    fontWeight: FontWeight.bold),
              )
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
                    context, bangumiItem.images['large']!,
                    width: constraints.maxWidth,
                    height: height,
                    showPlaceholder: showPlaceholder),
              ),
            );

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (onTap != null) {
                  onTap(bangumiItem);
                } else {
                  App.mainNavigatorKey?.currentContext
                      ?.to(() => BangumiInfoPage(
                            bangumiItem: bangumiItem,
                            heroTag: heroTag,
                          ));
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
                        Positioned.fill(
                          child: image,
                        ),
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
                                              color: context.brightness ==
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
                                              color: context.brightness ==
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
                                            // 模拟毛玻璃颗粒的纹理图
                                            fit: BoxFit.cover,
                                            color: context.brightness ==
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
                                            color: context.brightness ==
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
                                  child: score(),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Text(
                      bangumiItem.nameCn,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ).paddingHorizontal(2).paddingVertical(2),
            );
          },
        ));
  }

  static Widget buildDetailedMode(
      BuildContext context, BangumiItem bangumiItem, String heroTag,
      {void Function(BangumiItem)? onTap,
      void Function(BangumiItem)? onLongPressed}) {
    return LayoutBuilder(builder: (context, constrains) {
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
              context, bangumiItem.images['large']!,
              width: height * 0.72, height: height),
        ),
      );

      return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (onTap != null) {
              onTap(bangumiItem);
            } else {
              App.mainNavigatorKey?.currentContext?.to(() => BangumiInfoPage(
                    bangumiItem: bangumiItem,
                    heroTag: heroTag,
                  ));
            }
          },
          onLongPress:
              onLongPressed != null ? () => onLongPressed(bangumiItem) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                image,
                SizedBox.fromSize(
                  size: const Size(16, 5),
                ),
                Expanded(
                  child: _bangumiDescription(context, bangumiItem),
                ),
              ],
            ),
          ));
    });
  }

  static Widget _bangumiDescription(
      BuildContext context, BangumiItem bangumiItem) {
    final now = DateTime.now();
    final air = Utils.safeParseDate(bangumiItem.airDate);

    String status;
    if (bangumiItem.totalEpisodes > 0) {
      if (air != null && air.isBefore(now)) {
        status = 'Full @b episodes released'
            .tlParams({'b': bangumiItem.totalEpisodes});
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

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            )
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
              Text(
                '${bangumiItem.score}',
                style: TextStyle(
                  fontSize: 24.0,
                ),
              ),
              SizedBox(
                width: 5,
              ),
              Container(
                padding: EdgeInsets.all(2.0), // 可选，设置内边距
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8), // 设置圆角半径
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .toOpacity(0.72),
                    width: 2.0, // 设置边框宽度
                  ),
                ),
                child: Text(
                  Utils.getRatingLabel(bangumiItem.score),
                  style: TextStyle(
                    fontSize: 12.0,
                  ),
                ),
              ),
              SizedBox(
                width: 4,
              ),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.end, // 右对齐
              children: [
                RatingBarIndicator(
                  itemCount: 5,
                  rating: bangumiItem.score.toDouble() / 2,
                  itemBuilder: (context, index) => const Icon(
                    Icons.star_rounded,
                  ),
                  itemSize: 16.0,
                ),
                Text(
                  '@t reviews | #@r'.tlParams(
                      {'r': bangumiItem.rank, 't': bangumiItem.total}),
                  style: TextStyle(fontSize: 10),
                )
              ],
            ),
          ],
        ),
      ),
    ]);
  }

  static Widget buildStatsRow(BuildContext context, BangumiItem bangumiItem) {
    final collection = bangumiItem.collection!; // 提前解构，避免重复访问
    final total =
        collection.values.fold<int>(0, (sum, val) => sum + (val)); // 计算总数

    // 定义统计数据项（类型 + 显示文本 + 颜色）
    final stats = [
      StatItem('doing', 'doing'.tl, Theme.of(context).colorScheme.primary),
      StatItem('collect', 'collect'.tl, Theme.of(context).colorScheme.error),
      StatItem('wish', 'wish'.tl, Colors.blueAccent),
      StatItem('on_hold', 'on hold'.tl, null), // 默认文本颜色
      StatItem('dropped', 'dropped'.tl, Colors.grey),
    ];

    return Row(
      children: [
        ...stats.expand((stat) => [
              Text('${collection[stat.key]} ${stat.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: stat.color,
                  )),
              const Text(' / '),
            ]),
        Text('@t Total count'.tlParams({'t': total}),
            style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  static void showImagePreview(
      BuildContext context, String url, String title, String heroTag) {
    try {
      // 判断是否是本地文件（兼容 Windows、Android、iOS、macOS、Linux）
      final isLocal = File(url).existsSync();

      final ImageProvider img = isLocal
          ? FileImage(File(url))
          : CachedImageProvider(url, sourceKey: 'bangumi');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  PhotoView.customChild(
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                    backgroundDecoration:
                        const BoxDecoration(color: Colors.black),
                    child: Image(
                      image: img,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SafeArea(
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          _iconBackground(
                            icon: Icons.arrow_back_ios_new,
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          _textBackground(title),
                          const Spacer(),
                          !isLocal
                              ? _iconBackground(
                                  icon: Icons.download,
                                  onPressed: () {
                                    saveImageToGallery(context, url);
                                  },
                                )
                              : _iconBackground(
                                  icon: Icons.share,
                                  onPressed: () async {
                                    final file = File(url);
                                    Uint8List data = await file.readAsBytes();
                                    Share.shareFile(
                                        data: data,
                                        filename: heroTag,
                                        mime: 'image/png');
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ).padding(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ),
      );
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'showImagePreview', '$e\n$s');
    }
  }

  static Widget _iconBackground(
      {required IconData icon, required VoidCallback onPressed}) {
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
    // 限制最多显示 10 个字符，超出则用 ...
    final displayTitle =
        title.length > 10 ? '${title.substring(0, 10)}...' : title;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.toOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        displayTitle,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  static Future<void> saveImageToGallery(
      BuildContext context, String imageUrl) async {
    try {
      context.showMessage(message: '正在保存图片...');
      final response = await AppDio().request<Uint8List>(
        imageUrl,
        options: Options(method: 'GET', responseType: ResponseType.bytes),
      );

      if (App.isAndroid) {
        final result = await ImageGallerySaverPlus.saveImage(
          response.data!,
          quality: 100,
          name: _generateFilename(imageUrl),
          isReturnImagePathOfIOS: true,
        );

        if (result == null || !(result['isSuccess'] as bool? ?? false)) {
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
              context: context);
        }

        context.showMessage(message: '已保存到相册');
      } else {
        // 其他平台：保存到应用文档目录
        final directory = await getApplicationDocumentsDirectory();
        final folderPath = '${directory.path}/BangumiImages';
        final folder = Directory(folderPath);

        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }

        final filePath = '$folderPath/${_generateFilename(imageUrl)}';
        await File(filePath).writeAsBytes(response.data!);

        context.showMessage(message: '已保存到: $filePath');
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
          context: context);
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
  }) {
    if (_failedImageUrls.contains(imageUrl)) {
      return MiscComponents.placeholder(
          context, width, height, Colors.transparent);
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

// static Widget kostoriImage(BuildContext context, String imageUrl,
//     {double width = 100, double height = 100, bool showPlaceholder = true})
// {
//   // 检查是否已记录为失败图片
//   if (_failedImageUrls.contains(imageUrl)) {
//     return MiscComponents.placeholder(
//         context, width, height, Colors.transparent);
//   }
//   //// We need this to shink memory usage
//   int? memCacheWidth, memCacheHeight;
//   double aspectRatio = (width / height).toDouble();
//
//   void setMemCacheSizes() {
//     if (aspectRatio > 1) {
//       memCacheHeight = height.cacheSize(context);
//     } else if (aspectRatio < 1) {
//       memCacheWidth = width.cacheSize(context);
//     } else {
//       memCacheWidth = width.cacheSize(context);
//       memCacheHeight = height.cacheSize(context);
//     }
//   }
//
//   setMemCacheSizes();
//
//   if (memCacheWidth == null && memCacheHeight == null) {
//     memCacheWidth = width.toInt();
//   }
//
//   return CachedNetworkImage(
//     imageUrl: imageUrl,
//     fit: BoxFit.cover,
//     width: width,
//     height: height,
//     memCacheWidth: memCacheWidth,
//     memCacheHeight: memCacheHeight,
//     fadeOutDuration: const Duration(milliseconds: 120),
//     fadeInDuration: const Duration(milliseconds: 120),
//     filterQuality: FilterQuality.high,
//     progressIndicatorBuilder: (context, url, downloadProgress) {
//       final progress = downloadProgress.progress ?? 0.0;
//       return Stack(
//         alignment: Alignment.center,
//         children: [
//           // 原占位图
//           if (showPlaceholder)
//             MiscComponents.placeholder(
//                 context, width, height, Colors.transparent),
//           // 半透明黑色蒙层
//           Container(
//             // width: width,
//             // height: height,
//             decoration: BoxDecoration(
//               color: Colors.black.toOpacity(0.4),
//               borderRadius: BorderRadius.circular(12),
//             ),
//           ),
//           // 环形进度条，带背景圈
//           SizedBox(
//             // width: width / 2,
//             // height: height / 2,
//             child: Stack(
//               alignment: Alignment.center,
//               children: [
//                 CircularProgressIndicator(
//                   value: 1,
//                   valueColor: AlwaysStoppedAnimation(Colors.white24),
//                   strokeWidth: 4,
//                 ),
//                 CircularProgressIndicator(
//                   value: progress,
//                   valueColor: AlwaysStoppedAnimation(Colors.lightBlueAccent),
//                   strokeWidth: 4,
//                 ),
//                 // 中间文字
//                 Text(
//                   '${(progress * 100).toStringAsFixed(0)}%',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     shadows: [
//                       Shadow(
//                         offset: Offset(0, 0),
//                         blurRadius: 3,
//                         color: Colors.black54,
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       );
//     },
//     errorListener: (e) {
//       Log.addLog(LogLevel.error, 'kostoriImage', e.toString());
//     },
//     errorWidget: (BuildContext context, String url, Object error) {
//       // 记录失败 URL
//       if (!_failedImageUrls.contains(url)) {
//         _failedImageUrls.add(url);
//       }
//       return MiscComponents.placeholder(
//           context, width, height, Colors.transparent);
//     },
//   );
// }
}

class StatItem {
  final String key;
  final String label;
  final Color? color;

  StatItem(this.key, this.label, this.color);
}
