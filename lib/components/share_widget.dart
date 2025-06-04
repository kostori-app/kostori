import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/utils/translations.dart';
import 'package:path_provider/path_provider.dart';

import '../bbcode/bbcode_widget.dart';
import '../foundation/bangumi.dart';
import '../foundation/bangumi/episode/episode_item.dart';
import '../foundation/log.dart';
import '../network/bangumi.dart';
import '../pages/line_chart_page.dart';
import '../utils/io.dart';
import '../utils/utils.dart';
import 'components.dart';
import 'misc_components.dart';

final GlobalKey repaintKey = GlobalKey();

// 截取图像并保存
Future<void> captureAndSave() async {
  try {
    RenderRepaintBoundary boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary;

// 获取截图数据
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List uint8List = byteData!.buffer.asUint8List();

// 保存文件
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/popup_image.png');
    await file.writeAsBytes(uint8List);
//     // 使用 shareFile 函数分享文件
    Uint8List data = await file.readAsBytes();
    Share.shareFile(data: data, filename: 'image.jpg', mime: 'image/jpeg');
    Log.addLog(LogLevel.info, '截图保存', file.path);
  } catch (e) {
    Log.addLog(LogLevel.error, '截图失败', '$e');
  }
}

class _StatItem {
  final String key;
  final String label;
  final Color? color;

  _StatItem(this.key, this.label, this.color);
}

class ShareWidget extends StatefulWidget {
  const ShareWidget({super.key, required this.id, required this.title});

  final int id;
  final String title;

  @override
  State<ShareWidget> createState() => _ShareWidgetState();
}

class _ShareWidgetState extends State<ShareWidget> {
  int get id => widget.id;

  String get title => widget.title;

  Widget score(BuildContext context, BangumiItem bangumiItem) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
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
            padding: EdgeInsets.fromLTRB(8, 5, 8, 5),
            // 可选，设置内边距
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              // 设置圆角半径
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.toOpacity(0.72),
                width: 1.0, // 设置边框宽度
              ),
            ),
            child: Text(
              Utils.getRatingLabel(bangumiItem.score),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        BangumiManager().bindFind(id),
        // Future 1
        Bangumi.getBangumiEpisodeAllByID(id),
        // Future 2
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return PopUpWidgetScaffold(
            title: title,
            body: Center(
                child: MiscComponents.placeholder(
                    context, 100, 100, Colors.transparent)), // Loading state
          );
        }

        final bangumiItem = snapshot.data?[0] as BangumiItem;
        final allEpisodes = snapshot.data?[1] as List<EpisodeInfo>;

        Widget buildStatsRow(BuildContext context) {
          final collection = bangumiItem.collection; // 提前解构，避免重复访问
          print(collection);
          final total = collection?.values
              .fold<int>(0, (sum, val) => sum + (val)); // 计算总数

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
                    Text('${collection?[stat.key]} ${stat.label}',
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

        // 获取当前周的剧集
        final currentWeekEp =
            Utils.findCurrentWeekEpisode(allEpisodes, bangumiItem);

        // 判断是否已全部播出（检查是否是最后一项）
        final isCompleted = currentWeekEp != null &&
            allEpisodes.isNotEmpty &&
            currentWeekEp == allEpisodes.last;

        return PopUpWidgetScaffold(
          title: title,
          body: SingleChildScrollView(
            child: Column(
              children: [
                RepaintBoundary(
                  key: repaintKey,
                  child: Padding(
                    padding:
                        EdgeInsets.only(bottom: context.padding.bottom + 16),
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Column(
                        children: [
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: LayoutBuilder(
                                  builder: (context, constraints) {
                                double height = constraints.maxWidth / 2;
                                double width = height * 0.72;
                                return Container(
                                  width: constraints.maxWidth,
                                  height: height,
                                  padding: EdgeInsets.all(2),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(width: 16),
                                      //封面
                                      Material(
                                        color: Colors.transparent,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: context
                                                .colorScheme.primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          height: height,
                                          width: width,
                                          clipBehavior: Clip.antiAlias,
                                          child: BangumiWidget.kostoriImage(
                                              context,
                                              bangumiItem.images['large']!,
                                              width: width,
                                              height: height),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              //标题
                                              Text(
                                                title,
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              Text(bangumiItem.name,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  )),
                                              const SizedBox(height: 16),
                                              Container(
                                                padding: EdgeInsets.fromLTRB(
                                                    8, 5, 8, 5),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .toOpacity(0.72),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                child:
                                                    Text(bangumiItem.airDate),
                                              ),
                                              SizedBox(height: 12.0),
                                              (currentWeekEp?.sort != null)
                                                  ? Text(
                                                      isCompleted
                                                          ? '全 ${bangumiItem.totalEpisodes} 话'
                                                          : '连载至 ${currentWeekEp?.sort} • 预定全 ${bangumiItem.totalEpisodes} 话',
                                                      style: TextStyle(
                                                        fontSize: 12.0,
                                                      ),
                                                    )
                                                  : Text(
                                                      '未开播',
                                                      style: TextStyle(
                                                          fontSize: 12.0,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                              Spacer(),
                                              score(context, bangumiItem)
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 2, horizontal: 16),
                            child: Align(
                              child: buildStatsRow(context),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              width: 120,
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.grey.toOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '简介',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 24),
                            child: BBCodeWidget(bbcode: bangumiItem.summary),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              width: 120,
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.grey.toOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '标签',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                            child: Wrap(
                                spacing: 8.0,
                                runSpacing: App.isDesktop ? 8 : 0,
                                children: List<Widget>.generate(
                                    bangumiItem.tags.length, (int index) {
                                  return Chip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            '${bangumiItem.tags[index].name} '),
                                        Text(
                                          '${bangumiItem.tags[index].count}',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList()),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              width: 120,
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.grey.toOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '评分统计图',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          LineChatPage(
                            bangumiItem: bangumiItem,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              width: 120,
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.grey.toOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                // Spacer(), // 使用 Spacer 将按钮区域移至弹出框外
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Spacer(),
                      FilledButton(
                        onPressed: () {
                          captureAndSave();
                          App.rootContext.pop();
                        },
                        child: Text('Share'.tl),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
