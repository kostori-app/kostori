import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:gif/gif.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/utils/extension.dart';
import 'package:kostori/utils/utils.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';

import 'package:kostori/network/app_dio.dart';
import 'package:kostori/components/components.dart';

class BangumiWidget {
  static Widget buildBriefMode(
      BuildContext context, BangumiItem bangumiItem, String heroTag) {
    Widget score() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${bangumiItem.score}',
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            width: 4,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end, // 右对齐
            children: [
              RatingBarIndicator(
                itemCount: 5,
                rating: bangumiItem.score.toDouble() / 2,
                itemBuilder: (context, index) => const Icon(
                  Icons.star_rounded,
                ),
                itemSize: 14.0,
              ),
              Text(
                '${bangumiItem.total} 人评 | #${bangumiItem.rank}',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
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
                    width: constraints.maxWidth, height: height),
              ),
            );

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                App.mainNavigatorKey?.currentContext?.to(() => BangumiInfoPage(
                      bangumiItem: bangumiItem,
                      heroTag: heroTag,
                    ));
              },
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: image,
                        ),
                        Positioned(
                          bottom: 44,
                          right: 4,
                          child: ClipRRect(
                            // 确保圆角区域也能正确裁剪模糊效果
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                // 毛玻璃滤镜层
                                Positioned.fill(
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      color: Colors.black
                                          .toOpacity(0.3), // 必须有一个子容器
                                    ),
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
                          bottom: 8,
                          right: 4,
                          child: ClipRRect(
                            // 确保圆角区域也能正确裁剪模糊效果
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                // 毛玻璃滤镜层
                                Positioned.fill(
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      color: Colors.black
                                          .toOpacity(0.3), // 必须有一个子容器
                                    ),
                                  ),
                                ),
                                // 原有背景（带透明度）
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
                        fontWeight: FontWeight.w500,
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
      BuildContext context, BangumiItem bangumiItem, String heroTag) {
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
            App.mainNavigatorKey?.currentContext?.to(() => BangumiInfoPage(
                  bangumiItem: bangumiItem,
                  heroTag: heroTag,
                ));
          },
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
      Text(
        '${bangumiItem.airDate} • 全${bangumiItem.totalEpisodes}话',
        style: TextStyle(
          // fontSize: imageWidth * 0.12,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      const Spacer(),
      // 评分信息
      Align(
        alignment: Alignment.bottomRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                  '${bangumiItem.total} 人评 | #${bangumiItem.rank}',
                  style: TextStyle(fontSize: 10),
                )
              ],
            ),
          ],
        ),
      ),
    ]);
  }

  static void showImagePreview(
      BuildContext context, String url, String title, String heroTag) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.light, // 状态栏内容为亮色（白色）
                  child: Scaffold(
                    extendBodyBehindAppBar: false, // 允许内容延伸至状态栏
                    backgroundColor: Colors.black,
                    body: Stack(
                      children: [
                        PhotoView.customChild(
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 3,
                          heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                          backgroundDecoration:
                              const BoxDecoration(color: Colors.black),
                          child: GestureDetector(
                            onDoubleTapDown: (details) {
                              final controller = PhotoViewController();
                              final scale = controller.scale ?? 1.0;
                              controller.scale = scale > 1.0 ? 1.0 : 2.5;
                            },
                            child: Image(
                              image: CachedNetworkImageProvider(url),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                // 返回按钮 + 模糊背景
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.toOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new,
                                        color: Colors.white),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // 标题 + 模糊背景
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.toOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),

                                const Spacer(),

                                // 下载按钮 + 模糊背景
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.toOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.download,
                                        color: Colors.white),
                                    onPressed: () {
                                      saveImageToGallery(context, url);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ).paddingSymmetric(horizontal: 12, vertical: 8),
                  ),
                )),
      );
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'showImagePreview', '$e\n$s');
    }
  }

  static Future<void> saveImageToGallery(
      BuildContext context, String imageUrl) async {
    try {
      context.showMessage(message: '正在保存图片...');
      final dio = Dio();
      final response = await dio.get<Uint8List>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
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

  static Widget kostoriImage(BuildContext context, String imageUrl,
      {double width = 100, double height = 100}) {
    //// We need this to shink memory usage
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

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      progressIndicatorBuilder: (context, url, downloadProgress) {
        final progress = downloadProgress.progress ?? 0.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            // 原占位图
            MiscComponents.placeholder(context, width, height),
            // 半透明黑色蒙层
            Container(
              // width: width,
              // height: height,
              decoration: BoxDecoration(
                color: Colors.black.toOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // 环形进度条，带背景圈
            SizedBox(
              // width: width / 2,
              // height: height / 2,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1,
                    valueColor: AlwaysStoppedAnimation(Colors.white24),
                    strokeWidth: 4,
                  ),
                  CircularProgressIndicator(
                    value: progress,
                    valueColor: AlwaysStoppedAnimation(Colors.lightBlueAccent),
                    strokeWidth: 4,
                  ),
                  // 中间文字
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 0),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      errorListener: (e) {
        Log.addLog(LogLevel.error, 'image', e.toString());
      },
      errorWidget: (BuildContext context, String url, Object error) =>
          MiscComponents.placeholder(context, width, height),
      cacheManager: customDiskCache,
    );
  }

  static final customDiskCache = CacheManager(
    Config(
      'kostoryCacheKey', // 🗝️ 1. 缓存 key/命名空间
      stalePeriod: const Duration(days: 30), // ⏳ 2. 过期时间（多久后重新下载）
      maxNrOfCacheObjects: 200, // 📦 3. 最大缓存文件数
      repo: JsonCacheInfoRepository(
        // 🧾 4. 缓存元信息持久化方式
        databaseName: 'kostoriCache', //     SQLite 数据库名
      ),
      fileService: HttpFileService(), // 🌐 5. 下载服务（支持代理/自定义）
    ),
  );
}
