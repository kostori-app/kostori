import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/pages/aggregated_search_page.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../foundation/anime_type.dart';
import '../../../foundation/favorites.dart';
import '../../../pages/anime_details_page/anime_page.dart';
import '../../../pages/bangumi/info_controller.dart';

class BangumiInfoCardV extends StatefulWidget {
  const BangumiInfoCardV({
    super.key,
    required this.bangumiItem,
    required this.isLoading,
    required this.allEpisodes,
    this.heroTag,
    required this.infoController,
  });

  final BangumiItem bangumiItem;
  final List<EpisodeInfo> allEpisodes;
  final bool isLoading;
  final String? heroTag;
  final InfoController infoController;

  @override
  State<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends State<BangumiInfoCardV> {
  BangumiItem get bangumiItem => widget.bangumiItem;

  InfoController get infoController => widget.infoController;

  List<EpisodeInfo> get allEpisodes => widget.allEpisodes;

  Widget get voteBarChart => LineChatPage(bangumiItem: widget.bangumiItem);

  void showBangumiHistoryPagePickerDialog(BuildContext context) {
    final scrollController = ScrollController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 600, // 根据需求调整
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.transparent,
                    child: ListView.builder(
                      controller: scrollController,
                      shrinkWrap: true,
                      itemCount: infoController.bangumiHistory.length,
                      itemBuilder: (context, index) {
                        final history = infoController.bangumiHistory[index];

                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            App.mainNavigatorKey?.currentContext?.to(
                              () => AnimePage(
                                id: history.id,
                                sourceKey: history.sourceKey,
                              ),
                            );
                            LocalFavoritesManager().updateRecentlyWatched(
                              history.id,
                              AnimeType(history.sourceKey.hashCode),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BangumiWidget.kostoriImage(
                                    context,
                                    history.cover,
                                    width: 200 * 0.72,
                                    height: 200,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(history.title),
                                      const SizedBox(height: 4),
                                      Text(history.sourceKey),
                                      const SizedBox(height: 4),
                                      Text(
                                        '上次看到: 第 ${history.lastWatchEpisode} 话',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _button() {
    return Row(
      children: [
        // 搜索按钮
        FilledButton.tonal(
          onPressed: () {
            final context = App.mainNavigatorKey!.currentContext!;
            context.to(
              () => AggregatedSearchPage(
                keyword: bangumiItem.nameCn.isEmpty
                    ? bangumiItem.name
                    : bangumiItem.nameCn,
                bangumiPage: true,
                keywords: bangumiItem.alias,
              ),
            );
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(80, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          ),
          child: const Text('搜索'),
        ),

        const SizedBox(width: 8),

        // 开始观看按钮（仅在历史记录存在时显示）
        if (infoController.bangumiHistory.isNotEmpty)
          FilledButton(
            onPressed: () async {
              showBangumiHistoryPagePickerDialog(context);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('开始观看'),
          ),
      ],
    );
  }

  final count = [];

  @override
  Widget build(BuildContext context) {
    final bool showRightButton = MediaQuery.of(context).size.width >= 626;
    final bool showBottomButton = !showRightButton; // 确保互斥
    double standardDeviation = Utils.getDeviation(
      widget.bangumiItem.total,
      (widget.bangumiItem.count != null)
          ? widget.bangumiItem.count!.values.toList()
          : count,
      widget.bangumiItem.score,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 950, maxHeight: 300),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width <= 550 ? 450 : 475,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    double height =
                        MediaQuery.of(context).size.width <=
                            constraints.maxWidth + 150
                        ? 230
                        : 280;
                    double width = height * 0.72;
                    // 获取当前周的剧集
                    final currentWeekEp = Utils.findCurrentWeekEpisode(
                      allEpisodes,
                      bangumiItem,
                    );

                    final type0Episodes = allEpisodes
                        .where((ep) => ep.type == 0)
                        .toList();

                    final isCompleted =
                        currentWeekEp.values.first != null &&
                        type0Episodes.isNotEmpty &&
                        currentWeekEp.values.first == type0Episodes.last;

                    return Container(
                      width: MediaQuery.of(context).size.width,
                      height: height,
                      padding: EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              BangumiWidget.showImagePreview(
                                context,
                                widget.bangumiItem.images['large']!,
                                widget.bangumiItem.nameCn,
                                '${widget.heroTag}-${widget.bangumiItem.id}',
                              );
                            },
                            borderRadius: BorderRadius.circular(
                              12,
                            ), // 水波纹保持一致圆角
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Hero(
                                tag: (widget.heroTag == null)
                                    ? widget.bangumiItem.id
                                    : '${widget.heroTag}-${widget.bangumiItem.id}',
                                child: BangumiWidget.kostoriImage(
                                  context,
                                  widget.bangumiItem.images['large']!,
                                  width: width,
                                  height: height,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.0),
                          Container(
                            height: height,
                            constraints: BoxConstraints(maxWidth: 235),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onLongPress: () {
                                    Clipboard.setData(
                                      ClipboardData(text: bangumiItem.nameCn),
                                    );
                                    App.rootContext.showMessage(
                                      message: '已复制到剪贴板.',
                                    );
                                  },
                                  child: Text(
                                    bangumiItem.nameCn,
                                    style: TextStyle(
                                      fontSize: width * 1 / 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onLongPress: () {
                                    Clipboard.setData(
                                      ClipboardData(text: bangumiItem.name),
                                    );
                                    App.rootContext.showMessage(
                                      message: '已复制到剪贴板.',
                                    );
                                  },
                                  child: Text(
                                    bangumiItem.name,
                                    style: TextStyle(fontSize: width * 1 / 24),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(height: 12.0),
                                (!widget.isLoading)
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          if (bangumiItem.airDate.isNotEmpty)
                                            Container(
                                              padding: EdgeInsets.fromLTRB(
                                                8,
                                                5,
                                                8,
                                                5,
                                              ),
                                              // 可选，设置内边距
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      8.0,
                                                    ), // 设置圆角半径
                                                color: Colors.transparent,
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .toOpacity(0.72),
                                                  width: 1.0, // 设置边框宽度
                                                ),
                                              ),
                                              child: Text(
                                                bangumiItem.airDate,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          SizedBox(width: 4.0),
                                          BangumiWidget.bangumiTimeText(
                                            bangumiItem,
                                            currentWeekEp,
                                            isCompleted,
                                          ),
                                        ],
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SizedBox(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Skeletonizer.zone(
                                                child: Bone.text(
                                                  fontSize: 12,
                                                  width: 60,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Skeletonizer.zone(
                                                child: Bone.text(
                                                  fontSize: 12,
                                                  width: 60,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                Spacer(),
                                (!widget.isLoading)
                                    ? Align(
                                        alignment: Alignment.bottomRight,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            if (bangumiItem.total >= 20) ...[
                                              Text(
                                                '${bangumiItem.score}',
                                                style: TextStyle(
                                                  fontSize: 24.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 5),
                                              Container(
                                                padding: EdgeInsets.fromLTRB(
                                                  8,
                                                  5,
                                                  8,
                                                  5,
                                                ), // 可选，设置内边距
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        8,
                                                      ), // 设置圆角半径
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .toOpacity(0.72),
                                                    width: 1.0, // 设置边框宽度
                                                  ),
                                                ),
                                                child: Text(
                                                  Utils.getRatingLabel(
                                                    bangumiItem.score,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                            ],
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end, // 右对齐
                                              children: [
                                                RatingBarIndicator(
                                                  itemCount: 5,
                                                  rating:
                                                      bangumiItem.score
                                                          .toDouble() /
                                                      2,
                                                  itemBuilder:
                                                      (context, index) =>
                                                          const Icon(
                                                            Icons.star_rounded,
                                                          ),
                                                  itemSize: 20.0,
                                                ),
                                                Text(
                                                  '@t reviews | #@r'.tlParams({
                                                    'r': bangumiItem.rank,
                                                    't': bangumiItem.total,
                                                  }),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      )
                                    : Align(
                                        alignment: Alignment.bottomRight,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Skeletonizer.zone(
                                                child: Bone.text(
                                                  fontSize: 10,
                                                  width: 120,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Skeletonizer.zone(
                                                child: Bone.text(
                                                  fontSize: 10,
                                                  width: 120,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                if (showRightButton) ...[
                                  // Spacer(),
                                  SizedBox(height: 4),
                                  (!widget.isLoading)
                                      ? _button()
                                      : Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: SizedBox(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Skeletonizer.zone(
                                                  child: Bone.text(
                                                    fontSize: 24,
                                                    width: 60,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Skeletonizer.zone(
                                                  child: Bone.text(
                                                    fontSize: 24,
                                                    width: 120,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ), // 底部按钮
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      (bangumiItem.collection != null && !widget.isLoading)
                          ? Align(
                              child: BangumiWidget.buildStatsRow(
                                context,
                                infoController.bangumiItem,
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SizedBox(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Skeletonizer.zone(
                                      child: Bone.text(
                                        fontSize: 10,
                                        width: 240,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      if (showBottomButton) ...[
                        Spacer(),
                        (!widget.isLoading)
                            ? _button()
                            : Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: SizedBox(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Skeletonizer.zone(
                                        child: Bone.text(
                                          fontSize: 24,
                                          width: 60,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Skeletonizer.zone(
                                        child: Bone.text(
                                          fontSize: 24,
                                          width: 120,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ), // 底部按钮
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (MediaQuery.sizeOf(context).width >= 1200 &&
                      !widget.isLoading &&
                      widget.bangumiItem.total > 20)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 400,
                        maxHeight: 300,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Rating Statistics Chart'.tl,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${bangumiItem.score}',
                                  style: ts.s12,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    infoController.showLineChart =
                                        !infoController.showLineChart;
                                  });
                                },
                                icon: Icon(
                                  infoController.showLineChart
                                      ? Icons.show_chart
                                      : Icons.bar_chart,
                                ),
                                label: Text(
                                  infoController.showLineChart
                                      ? 'Line Chart'.tl
                                      : 'Bar Chart'.tl,
                                ),
                              ),
                              Text('${widget.bangumiItem.total} votes'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Standard Deviation: @s'.tlParams({
                                    's': standardDeviation.toStringAsFixed(2),
                                  }),
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Utils.getDispute(standardDeviation),
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Spacer(),
                          Expanded(
                            child: infoController.showLineChart
                                ? LineChatPage(bangumiItem: widget.bangumiItem)
                                : BangumiBarChartPage(
                                    bangumiItem: widget.bangumiItem,
                                  ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
