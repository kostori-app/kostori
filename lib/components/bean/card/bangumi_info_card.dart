import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/utils.dart';
import 'package:kostori/components/misc_components.dart';

class _StatItem {
  final String key;
  final String label;
  final Color? color;

  _StatItem(this.key, this.label, this.color);
}

class BangumiInfoCardV extends StatefulWidget {
  const BangumiInfoCardV(
      {super.key,
      required this.bangumiItem,
      required this.isLoading,
      required this.allEpisodes});

  final BangumiItem bangumiItem;
  final List<EpisodeInfo> allEpisodes;
  final bool isLoading;

  @override
  State<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends State<BangumiInfoCardV> {
  BangumiItem get bangumiItem => widget.bangumiItem;

  List<EpisodeInfo> get allEpisodes => widget.allEpisodes;

  bool get count => areAllValuesZero(widget.bangumiItem.count!);

  bool areAllValuesZero(Map<String, int> countMap) {
    return countMap.values.every((value) => value == 0);
  }

  Widget get voteBarChart => LineChatPage(
        bangumiItem: widget.bangumiItem,
      );

  Widget _buildStatsRow(BuildContext context) {
    final collection = bangumiItem.collection!; // 提前解构，避免重复访问
    final total =
        collection.values.fold<int>(0, (sum, val) => sum + (val ?? 0)); // 计算总数

    // 定义统计数据项（类型 + 显示文本 + 颜色）
    final stats = [
      _StatItem('doing', '在看', Theme.of(context).colorScheme.primary),
      _StatItem('collect', '看过', Theme.of(context).colorScheme.error),
      _StatItem('wish', '想看', Colors.blueAccent),
      _StatItem('on_hold', '搁置', null), // 默认文本颜色
      _StatItem('dropped', '抛弃', Colors.grey),
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
        Text('$total 总计数', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      constraints: BoxConstraints(maxWidth: 950),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              double height = 250;
              double width = height * 0.72;
              // 获取当前周的剧集
              final currentWeekEp = Utils.findCurrentWeekEpisode(allEpisodes);

              // 判断是否已全部播出（检查是否是最后一项）
              final isCompleted = currentWeekEp != null &&
                  allEpisodes.isNotEmpty &&
                  currentWeekEp == allEpisodes.last;

              return Container(
                width: constraints.maxWidth,
                height: height,
                padding: EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: widget.bangumiItem.images['large']!,
                        width: width,
                        height: height,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            MiscComponents.placeholder(context, width, height),
                      ),
                    ),
                    // SizedBox(width: 12.0),
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: height,
                              constraints: BoxConstraints(maxWidth: 200),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bangumiItem.nameCn,
                                    style: TextStyle(
                                        fontSize: width * 1 / 10,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    bangumiItem.name,
                                    style: TextStyle(
                                      fontSize: width * 1 / 24,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 12.0),
                                  Container(
                                    padding: EdgeInsets.all(8.0),
                                    // 可选，设置内边距
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(16.0), // 设置圆角半径
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                            .toOpacity(0.72),
                                        width: 2.0, // 设置边框宽度
                                      ),
                                    ),
                                    child: Text(
                                      bangumiItem.airDate,
                                    ),
                                  ),
                                  SizedBox(height: 12.0),
                                  Text(
                                    isCompleted
                                        ? '全 ${bangumiItem.totalEpisodes} 话'
                                        : '连载至 ${currentWeekEp?.episode} • 预定全 ${bangumiItem.totalEpisodes} 话',
                                    style: TextStyle(fontSize: 14.0),
                                  ),
                                  Spacer(),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${bangumiItem.score}',
                                          style: TextStyle(
                                            fontSize: 32.0,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 5,
                                        ),
                                        Container(
                                          padding:
                                              EdgeInsets.all(2.0), // 可选，设置内边距
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                                8), // 设置圆角半径
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondaryContainer
                                                  .toOpacity(0.72),
                                              width: 2.0, // 设置边框宽度
                                            ),
                                          ),
                                          child: Text(
                                            Utils.getRatingLabel(
                                                bangumiItem.score),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 4,
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end, // 右对齐
                                          children: [
                                            RatingBarIndicator(
                                              itemCount: 5,
                                              rating:
                                                  bangumiItem.score.toDouble() /
                                                      2,
                                              itemBuilder: (context, index) =>
                                                  const Icon(
                                                Icons.star_rounded,
                                              ),
                                              itemSize: 20.0,
                                            ),
                                            Text(
                                              '${bangumiItem.total} 人评 | #${bangumiItem.rank}',
                                              style: TextStyle(fontSize: 12),
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (MediaQuery.sizeOf(context).width >= 900 &&
                                !widget.isLoading &&
                                !count)
                              Spacer(),
                            if (MediaQuery.sizeOf(context).width >= 900 &&
                                !widget.isLoading &&
                                !count)
                              Container(
                                height: height,
                                constraints: BoxConstraints(maxWidth: 350),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '评分统计图',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Spacer(),
                                    voteBarChart
                                  ],
                                ),
                              ),
                          ]),
                    )),
                  ],
                ),
              );
            },
          ),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bangumiItem.collection != null)
                Align(
                  child: _buildStatsRow(context),
                ),
            ],
          ))
        ],
      ),
    );
  }
}
