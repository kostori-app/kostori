import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/character/character_full_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_search_page.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:path_provider/path_provider.dart';

final GlobalKey repaintKey = GlobalKey();

Future<void> captureAndSave() async {
  try {
    RenderRepaintBoundary boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary;

    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List uint8List = byteData!.buffer.asUint8List();

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/popup_image.png');
    await file.writeAsBytes(uint8List);

    Uint8List data = await file.readAsBytes();
    await Share.shareFile(
      data: data,
      filename: 'popup_image.png',
      mime: 'image/png',
    );
    Log.addLog(LogLevel.info, '截图保存', file.path);
  } catch (e) {
    Log.addLog(LogLevel.error, '截图失败', '$e');
  }
}

class ShareWidget extends StatefulWidget {
  const ShareWidget({
    super.key,
    this.id,
    this.selectedBangumiItems,
    this.anime,
    this.useBriefMode,
    this.airDate,
    this.tag,
    this.sort,
    this.endDate,
    this.characterFullItem,
  });

  final int? id;

  final Map<BangumiItem, bool>? selectedBangumiItems;

  final AnimeDetails? anime;

  final bool? useBriefMode;

  final String? airDate;

  final String? endDate;

  final List<String>? tag;

  final String? sort;

  final CharacterFullItem? characterFullItem;

  @override
  State<ShareWidget> createState() => _ShareWidgetState();
}

class _ShareWidgetState extends State<ShareWidget> {
  bool showLineChart = false;
  bool isLoding = true;

  late final BangumiItem bangumiItem;
  late final List<EpisodeInfo> allEpisodes;

  late int id;
  late AnimeDetails anime;
  late Map<BangumiItem, bool> selectedBangumiItems;
  late CharacterFullItem characterFullItem;

  @override
  void initState() {
    if (widget.id != null) {
      id = widget.id!;
      queryBangumi();
    } else if (widget.anime != null) {
      anime = widget.anime!;
      isLoding = false;
    } else if (widget.selectedBangumiItems != null) {
      selectedBangumiItems = widget.selectedBangumiItems!;
      isLoding = false;
    } else if (widget.characterFullItem != null) {
      characterFullItem = widget.characterFullItem!;
      isLoding = false;
    }
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
            Text('${bangumiItem.score}', style: TextStyle(fontSize: 28.0)),
            SizedBox(width: 5),
            Container(
              padding: EdgeInsets.fromLTRB(8, 5, 8, 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.toOpacity(0.72),
                  width: 1.0,
                ),
              ),
              child: Text(Utils.getRatingLabel(bangumiItem.score)),
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
                itemSize: 18.0,
              ),
              Text(
                '@t reviews | #@r'.tlParams({
                  'r': bangumiItem.rank,
                  't': bangumiItem.total,
                }),
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _animeInfoPage() {
    return RepaintBoundary(
      key: repaintKey,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: context.padding.bottom + 16,
          top: context.padding.top,
          right: 20,
          left: 20,
        ),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Material(
            color: context.brightness == Brightness.light
                ? Colors.white.toOpacity(0.72)
                : const Color(0xFF1E1E1E).toOpacity(0.72),
            elevation: 4,
            shadowColor: Theme.of(context).colorScheme.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SizedBox(height: 64.0),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 16),
                      //封面
                      Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          height: 256,
                          width: 256 * 0.72,
                          clipBehavior: Clip.antiAlias,
                          child: AnimatedImage(
                            image: CachedImageProvider(
                              anime.cover,
                              sourceKey: anime.sourceKey,
                            ),
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              //标题
                              Text(anime.title, style: ts.s20),
                              if (anime.subTitle != null)
                                SelectableText(anime.subTitle!, style: ts.s14),
                              //源名称
                              Text(
                                (AnimeSource.find(anime.sourceKey)?.name) ?? '',
                                style: ts.s12,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                anime.tags.entries
                                    .map((entry) {
                                      // 对每个键值对，创建一个字符串表示形式
                                      return '${entry.key}: ${entry.value.join(', ')}';
                                    })
                                    .join('\n'), // 用换行符分隔每个键值对
                                style: ts.s12,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                    ],
                  ),
                ),
                Text('Introduction'.tl, style: ts.s18),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  child: SelectableText(
                    anime.description!,
                  ).fixWidth(double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bangumiInfoPage() {
    double standardDeviation = Utils.getDeviation(
      bangumiItem.total,
      bangumiItem.count!.values.toList(),
      bangumiItem.score,
    );

    // 获取当前周的剧集
    final currentWeekEp = Utils.findCurrentWeekEpisode(
      allEpisodes,
      bangumiItem,
    );

    final type0Episodes = allEpisodes.where((ep) => ep.type == 0).toList();

    final isCompleted =
        currentWeekEp.values.first != null &&
        type0Episodes.isNotEmpty &&
        currentWeekEp.values.first == type0Episodes.last;
    return RepaintBoundary(
      key: repaintKey,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: context.padding.bottom + 16,
          top: context.padding.top,
          right: 20,
          left: 20,
        ),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Material(
            color: context.brightness == Brightness.light
                ? Colors.white.toOpacity(0.72)
                : const Color(0xFF1E1E1E).toOpacity(0.72),
            elevation: 4,
            shadowColor: Theme.of(context).colorScheme.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SizedBox(height: 64.0),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 16),
                            //封面
                            Material(
                              color: Colors.transparent,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                height: height,
                                width: width,
                                clipBehavior: Clip.antiAlias,
                                child: BangumiWidget.kostoriImage(
                                  context,
                                  bangumiItem.images['large']!,
                                  width: width,
                                  height: height,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    //标题
                                    Text(
                                      bangumiItem.nameCn.isNotEmpty
                                          ? bangumiItem.nameCn
                                          : bangumiItem.name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      bangumiItem.name,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        if (bangumiItem.airDate.isNotEmpty)
                                          Container(
                                            padding: EdgeInsets.fromLTRB(
                                              8,
                                              5,
                                              8,
                                              5,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .toOpacity(0.72),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Text(bangumiItem.airDate),
                                          ),
                                        SizedBox(width: 12.0),
                                        BangumiWidget.bangumiTimeText(
                                          bangumiItem,
                                          currentWeekEp,
                                          isCompleted,
                                        ),
                                      ],
                                    ),

                                    Spacer(),
                                    score(context, bangumiItem),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 16,
                  ),
                  child: Align(
                    child: BangumiWidget.buildStatsRow(context, bangumiItem),
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
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Introduction'.tl,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
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
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        'Tags'.tl,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
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
                          '${bangumiItem.tags.length}',
                          style: ts.s12,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: App.isDesktop ? 8 : 0,
                    children: List<Widget>.generate(bangumiItem.tags.length, (
                      int index,
                    ) {
                      return Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${bangumiItem.tags[index].name} '),
                            Text(
                              '${bangumiItem.tags[index].count}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
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
                      vertical: 6,
                      horizontal: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Rating Chart'.tl,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
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
                                  showLineChart = !showLineChart;
                                });
                              },
                              icon: Icon(
                                showLineChart
                                    ? Icons.show_chart
                                    : Icons.bar_chart,
                              ),
                              label: Text(
                                showLineChart
                                    ? 'Line Chart'.tl
                                    : 'Bar Chart'.tl,
                              ),
                            ),
                            Text('${bangumiItem.total} votes'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    child: showLineChart
                        ? LineChatPage(bangumiItem: bangumiItem)
                        : BangumiBarChartPage(bangumiItem: bangumiItem),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchPage() {
    final keyList = selectedBangumiItems.keys.toList();

    return RepaintBoundary(
      key: repaintKey,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: context.padding.bottom + 16,
          top: context.padding.top,
          right: 20,
          left: 20,
        ),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Material(
            color: context.brightness == Brightness.light
                ? Colors.white.toOpacity(0.72)
                : const Color(0xFF1E1E1E).toOpacity(0.72),
            elevation: 4,
            shadowColor: Theme.of(context).colorScheme.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SizedBox(height: 64.0),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if ((widget.airDate ?? '').isNotEmpty)
                        Text(
                          widget.airDate!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.green,
                          ),
                        ),
                      if ((widget.airDate ?? '').isNotEmpty &&
                          (widget.endDate ?? '').isNotEmpty)
                        const Text(
                          ' - ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.grey,
                          ),
                        ),
                      if ((widget.endDate ?? '').isNotEmpty)
                        Text(
                          widget.endDate!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.blue,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if ((widget.sort ?? '').isNotEmpty)
                        Text(
                          widget.sort!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 6.0,
                    children: widget.tag!.map((tag) {
                      return ActionChip(
                        label: Text(tag),
                        onPressed: () {},
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.toOpacity(0.72),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: keyList.length,
                    gridDelegate: SliverGridDelegateWithBangumiItems(
                      widget.useBriefMode!,
                    ),
                    itemBuilder: (context, index) {
                      return widget.useBriefMode!
                          ? BangumiWidget.buildBriefMode(
                              context,
                              keyList[index],
                              '',
                              showPlaceholder: false,
                            )
                          : BangumiWidget.buildDetailedMode(
                              context,
                              keyList[index],
                              '',
                            );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _characterPage() {
    return RepaintBoundary(
      key: repaintKey,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: context.padding.bottom + 16,
          top: context.padding.top,
          right: 20,
          left: 20,
        ),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Material(
            color: context.brightness == Brightness.light
                ? Colors.white.toOpacity(0.72)
                : const Color(0xFF1E1E1E).toOpacity(0.72),
            elevation: 4,
            shadowColor: Theme.of(context).colorScheme.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SizedBox(height: 64.0),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: constraints.maxWidth,
                        child: BangumiWidget.kostoriImage(
                          context,
                          characterFullItem.image,
                          enableDefaultSize: false,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Text(
                    characterFullItem.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Text(
                    characterFullItem.nameCN,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
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
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Text(
                    'Profile Information'.tl,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Text(
                    characterFullItem.info,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.justify,
                  ),
                ),

                const SizedBox(height: 16.0),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Text(
                    'Character Introduction'.tl,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Text(
                    characterFullItem.summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.anime != null) {
      return _animeInfoPage();
    } else if (widget.id != null) {
      return _bangumiInfoPage();
    } else if (widget.selectedBangumiItems != null) {
      return _searchPage();
    } else if (widget.characterFullItem != null) {
      return _characterPage();
    } else {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoding) {
      return PopUpWidgetScaffold(
        title: 'Screenshot Share'.tl,
        body: MiscComponents.placeholder(context, 100, 100, Colors.transparent),
      );
    }

    return PopUpWidgetScaffold(
      title: 'Screenshot Share'.tl,
      body: Stack(
        children: [
          Positioned.fill(child: SingleChildScrollView(child: _buildBody())),
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
