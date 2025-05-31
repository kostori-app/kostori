import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/utils/utils.dart';
import 'package:kostori/components/misc_components.dart';

class BangumiWidget {
  static Widget buildBriefMode(
      BuildContext context, BangumiItem bangumiItem, String heroTag) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight - 16;
            Widget image = Container(
              decoration: BoxDecoration(
                color: context.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
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
                child: CachedNetworkImage(
                  imageUrl: bangumiItem.images['large']!,
                  width: height * 0.72,
                  height: height,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => MiscComponents.placeholder(
                      context, height * 0.72, height),
                  errorListener: (e) {
                    Log.addLog(LogLevel.error, 'image', e.toString());
                  },
                  errorWidget:
                      (BuildContext context, String url, Object error) =>
                          MiscComponents.placeholder(context, 100, 100),
                ),
              ),
            );

            return InkWell(
              borderRadius: BorderRadius.circular(8),
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
                        Align(
                          alignment: Alignment.bottomRight,
                          child: (() {
                            var children = <Widget>[];
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: children,
                            );
                          })(),
                        ),
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
          borderRadius: BorderRadius.circular(8),
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
          child: CachedNetworkImage(
            imageUrl: bangumiItem.images['large']!,
            width: height * 0.72,
            height: height,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                MiscComponents.placeholder(context, height * 0.72, height),
            errorListener: (e) {
              Log.addLog(LogLevel.error, 'image', e.toString());
            },
            errorWidget: (BuildContext context, String url, Object error) =>
                MiscComponents.placeholder(context, 100, 100),
          ),
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
}
