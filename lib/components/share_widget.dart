import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/svg.dart';
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

class ShareWidget extends StatefulWidget {
  const ShareWidget({super.key, required this.id});

  final int id;

  @override
  State<ShareWidget> createState() => _ShareWidgetState();
}

class _ShareWidgetState extends State<ShareWidget> {
  int get id => widget.id;
  bool showLineChart = false;
  bool isLoding = true;

  late final BangumiItem bangumiItem;
  late final List<EpisodeInfo> allEpisodes;

  @override
  void initState() {
    queryBangumi();
    super.initState();
  }

  Future<void> queryBangumi() async {
    bangumiItem = (await BangumiManager().bindFind(id))!;
    allEpisodes = await Bangumi.getBangumiEpisodeAllByID(id);
    setState(() {
      isLoding = false;
    });
  }

  Widget score(BuildContext context, BangumiItem bangumiItem) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (bangumiItem.total >= 20) ...[
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
                itemSize: 20.0,
              ),
              Text(
                '@t reviews | #@r'
                    .tlParams({'r': bangumiItem.rank, 't': bangumiItem.total}),
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
    if (isLoding) {
      return PopUpWidgetScaffold(
        title: '截图分享',
        body: MiscComponents.placeholder(context, 100, 100, Colors.transparent),
      );
    }

    double standardDeviation = Utils.getDeviation(bangumiItem.total,
        bangumiItem.count!.values.toList(), bangumiItem.score);

    // 获取当前周的剧集
    final currentWeekEp =
        Utils.findCurrentWeekEpisode(allEpisodes, bangumiItem);

    final type0Episodes = allEpisodes.where((ep) => ep.type == 0).toList();

    final isCompleted = currentWeekEp.values.first != null &&
        type0Episodes.isNotEmpty &&
        currentWeekEp.values.first == type0Episodes.last;

    return PopUpWidgetScaffold(
      title: '截图分享',
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: repaintKey,
                child: Padding(
                  padding: EdgeInsets.only(bottom: context.padding.bottom + 16),
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 64.0,
                          width: 320,
                          child: SvgPicture.asset(
                            'assets/img/header_pattern.svg',
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .toOpacity(0.72),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child:
                                LayoutBuilder(builder: (context, constraints) {
                              double height = constraints.maxWidth / 2;
                              double width = height * 0.72;
                              return Container(
                                width: constraints.maxWidth,
                                height: height,
                                padding: EdgeInsets.all(2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                              bangumiItem.nameCn.isNotEmpty
                                                  ? bangumiItem.nameCn
                                                  : bangumiItem.name,
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            Text(bangumiItem.name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                )),
                                            const SizedBox(height: 16),
                                            if (bangumiItem.airDate.isNotEmpty)
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
                                            (currentWeekEp.values.first?.sort !=
                                                    null)
                                                ? Text(
                                                    isCompleted
                                                        ? '全 ${bangumiItem.totalEpisodes} 话'
                                                        : '连载至 ${currentWeekEp.values.first?.sort} • 预定全 ${bangumiItem.totalEpisodes} 话',
                                                    style: TextStyle(
                                                      fontSize: 12.0,
                                                    ),
                                                  )
                                                : Text(
                                                    'Not Yet Airing'.tl,
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
                            child: BangumiWidget.buildStatsRow(
                                context, bangumiItem),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Introduction'.tl,
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          child: BBCodeWidget(bbcode: bangumiItem.summary),
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text('Tags'.tl,
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${bangumiItem.tags.length}',
                                    style: ts.s12),
                              ),
                            ],
                          ),
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
                                      Text('${bangumiItem.tags[index].name} '),
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

                        if (bangumiItem.total >= 20) ...[
                          const SizedBox(height: 8),
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
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Rating Statistics Chart'.tl,
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold)),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('${bangumiItem.score}',
                                          style: ts.s12),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          showLineChart = !showLineChart;
                                        });
                                      },
                                      icon: Icon(showLineChart
                                          ? Icons.show_chart
                                          : Icons.bar_chart),
                                      label: Text(showLineChart
                                          ? 'Line Chart'.tl
                                          : 'Bar Chart'.tl),
                                    ),
                                    Text('${bangumiItem.total} votes')
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                    'Standard Deviation: @s'.tlParams({
                                      's': standardDeviation.toStringAsFixed(2)
                                    }),
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(
                                  width: 8,
                                ),
                                Text(Utils.getDispute(standardDeviation),
                                    style: TextStyle(fontSize: 12))
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            child: showLineChart
                                ? LineChatPage(bangumiItem: bangumiItem)
                                : BangumiBarChartPage(bangumiItem: bangumiItem),
                          ),
                        ],

                        // const SizedBox(height: 16),
                        SizedBox(
                          height: 64.0,
                          // width: 320,
                          child: SvgPicture.asset(
                            'assets/img/bottom_pattern.svg',
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .toOpacity(0.72),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: FilledButton(
              onPressed: () {
                captureAndSave();
                App.rootContext.pop();
              },
              child: Text('Share'.tl),
            ),
          ),
        ],
      ),
    );
  }
}
