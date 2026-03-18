import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/bean/card/comments_card.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/bangumi_subject_relations_item.dart';
import 'package:kostori/foundation/bangumi/character/character_casts_item.dart';
import 'package:kostori/foundation/bangumi/character/character_full_item.dart';
import 'package:kostori/foundation/bangumi/comment/comment_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';

final GlobalKey repaintKey = GlobalKey();

Future<void> captureAndSave(BuildContext context) async {
  try {
    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'popup_$timestamp.png';

    final file = await ImageSaver.writeFile(bytes: bytes, filename: filename);
    if (file == null) return;

    ImageSaver.showResult(success: true, message: '截图成功');
    Log.info('截图保存', file.path);

    final data = await file.readAsBytes();
    await Share.shareFile(data: data, filename: filename, mime: 'image/png');
  } catch (e) {
    ImageSaver.showResult(success: false, message: '截图失败: $e');
    Log.error('截图失败', '$e');
  }
}

class ShareWidget extends StatefulWidget {
  const ShareWidget({
    super.key,
    this.id,
    this.selectedBangumiItems,
    this.anime,
    this.airDate,
    this.tag,
    this.sort,
    this.endDate,
    this.characterFullItem,
    this.selectedCharacterItems,
  });

  final int? id;

  final Map<BangumiItem, bool>? selectedBangumiItems;

  final Map<CharacterActor, bool>? selectedCharacterItems;

  final AnimeDetails? anime;

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
  late final List<BangumiSRI> bangumiSRI;
  late final List<CommentItem> commentsList;
  late final StatsDataImpl stats;

  late int id;
  late AnimeDetails anime;
  late Map<BangumiItem, bool> selectedBangumiItems;
  late Map<CharacterActor, bool> selectedCharacterItems;
  late CharacterFullItem characterFullItem;

  int? latestRating;
  String? latestComment;
  int? watchDuration;

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
    } else if (widget.selectedCharacterItems != null) {
      selectedCharacterItems = widget.selectedCharacterItems!;
      isLoding = false;
    }
    super.initState();
  }

  Future<void> queryBangumi() async {
    bangumiItem = (await BangumiManager().bindFind(id))!;
    allEpisodes = await Bangumi.getBangumiEpisodeAllByID(id);
    bangumiSRI = await Bangumi.getBangumiSRIByID(id);
    commentsList = (await Bangumi.getBangumiCommentsByID(
      id,
      offset: 0,
    )).commentList;
    try {
      stats = StatsManager().getStatsByIdAndType(
        id: bangumiItem.id.toString(),
        type: 'bangumi'.hashCode,
      )!;
      latestRating =
          stats.rating.lastOrNull?.platformEventRecords.lastOrNull?.rating;
      latestComment =
          stats.comment.lastOrNull?.platformEventRecords.lastOrNull?.comment;
      watchDuration =
          stats
              .comment
              .lastOrNull
              ?.platformEventRecords
              .lastOrNull
              ?.watchDuration ??
          stats
              .rating
              .lastOrNull
              ?.platformEventRecords
              .lastOrNull
              ?.watchDuration;
    } catch (_) {}
    setState(() {
      isLoding = false;
    });
  }

  Widget score(BuildContext context, BangumiItem bangumiItem) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RatingBarIndicator(
                    itemCount: 5,
                    rating: bangumiItem.score.toDouble() / 2,
                    itemBuilder: (context, index) =>
                        const Icon(Icons.star_rounded),
                    itemSize: 12.0,
                  ),
                  Text(
                    '@t reviews | #@r'.tlParams({
                      'r': bangumiItem.rank,
                      't': bangumiItem.total,
                    }),
                    style: TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (bangumiItem.total >= 20) ...[
                Text('${bangumiItem.score}', style: TextStyle(fontSize: 24.0)),
                SizedBox(width: 3),
                Container(
                  padding: EdgeInsets.fromLTRB(8, 5, 8, 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.toOpacity(0.72),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    Utils.getRatingLabel(bangumiItem.score),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
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
                SizedBox(height: 32.0),
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
                                SelectableText(
                                  anime.subTitle!,
                                  style: ts.s14,
                                  scrollPhysics:
                                      const NeverScrollableScrollPhysics(),
                                ),
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
    final currentWeekEp = BangumiUtils.findCurrentWeekEpisode(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 32.0),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double height = constraints.maxWidth / 1.5;
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
                            const SizedBox(width: 4),
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
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      bangumiItem.name,
                                      style: TextStyle(fontSize: 8),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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
                                            child: Text(
                                              bangumiItem.airDate,
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 6.0),
                                    BangumiWidget.bangumiTimeText(
                                      bangumiItem,
                                      currentWeekEp,
                                      isCompleted,
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
                    child: BangumiWidget.buildStatsRow(
                      context: context,
                      bangumiItem: bangumiItem,
                      isCenter: true,
                    ),
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
                if (bangumiSRI.isNotEmpty) ...[
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Linked Items'.tl,
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
                          child: Text('${bangumiSRI.length}', style: ts.s12),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = 3;
                        final spacing = 8.0;
                        final totalSpacing = (crossAxisCount - 1) * spacing;
                        final itemWidth =
                            (constraints.maxWidth - totalSpacing) /
                            crossAxisCount;
                        final imageHeight = itemWidth * 1.3;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: 16,
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: bangumiSRI.map((item) {
                            return BangumiHorizontalCard(
                              bangumiItem: item,
                              width: itemWidth,
                              imageHeight: imageHeight,
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
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
                if (commentsList.isNotEmpty) ...[
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '最新评论'.tl,
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
                            '${commentsList.length >= 5 ? 5 : commentsList.length}',
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
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        final commentItem = commentsList[index];
                        return CommentsCard(commentItem: commentItem);
                      },
                    ),
                  ),
                ],
                if (latestComment != null || latestRating != null) ...[
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '我的评价'.tl,
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
                    child: Column(
                      children: [
                        if (latestRating != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                child: Image(
                                  image: AssetImage("images/app_icon.png"),
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Kostori'),
                                  Text(
                                    '评价时 ${Utils.formatHMS(watchDuration ?? 0)}',
                                  ),
                                ],
                              ),
                              Spacer(),
                              RatingBarIndicator(
                                itemCount: 5,
                                rating: latestRating!.toDouble() / 2,
                                itemBuilder: (context, index) =>
                                    const Icon(Icons.star_rounded),
                                itemSize: 20.0,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (latestComment != null)
                          Row(
                            children: [Expanded(child: Text(latestComment!))],
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchSubjectPage() {
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
                SizedBox(height: 32.0),
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
                        child: Text('${keyList.length}', style: ts.s12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = 3;
                      final spacing = 8.0;
                      final totalSpacing = (crossAxisCount - 1) * spacing;
                      final itemWidth =
                          (constraints.maxWidth - totalSpacing) /
                          crossAxisCount;
                      final itemHeight = itemWidth * 1.4;

                      return Center(
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: 16,
                          children: keyList.map((item) {
                            return BangumiGridCard(
                              bangumiItem: item,
                              width: itemWidth,
                              height: itemHeight,
                            );
                          }).toList(),
                        ),
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

  Widget _searchCharacterPage() {
    final keyList = selectedCharacterItems.keys.toList();

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
                SizedBox(height: 32.0),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                        child: Text('${keyList.length}', style: ts.s12),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = 3;
                      final spacing = 8.0;
                      final totalSpacing = (crossAxisCount - 1) * spacing;
                      final itemWidth =
                          (constraints.maxWidth - totalSpacing) /
                          crossAxisCount;
                      final itemHeight = itemWidth * 1.4;

                      return Center(
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: 16,
                          children: keyList.map((item) {
                            return _BangumiCharacterCard(
                              character: item,
                              width: itemWidth,
                              height: itemHeight,
                            );
                          }).toList(),
                        ),
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
                SizedBox(height: 32.0),
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
      return _searchSubjectPage();
    } else if (widget.characterFullItem != null) {
      return _characterPage();
    } else if (widget.selectedCharacterItems != null) {
      return _searchCharacterPage();
    } else {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoding) {
      return PopUpWidgetScaffold(
        title: 'Screenshot Share'.tl,
        body: Center(child: KostoriRefreshIndicator()),
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
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    captureAndSave(context);
                    App.rootContext.pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.share,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BangumiGridCard extends StatelessWidget {
  final BangumiItem bangumiItem;
  final double width;
  final double height;

  const BangumiGridCard({
    required this.bangumiItem,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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

    Widget scoreWidget() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (bangumiItem.total >= 20) ...[
            Text(
              '${bangumiItem.score}',
              style: TextStyle(
                fontSize: App.isAndroid ? 13 : 16,
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
                rating: bangumiItem.score / 2,
                itemBuilder: (context, index) => const Icon(Icons.star_rounded),
                itemSize: App.isAndroid ? 12 : 14,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: width,
          height: height,
          margin: const EdgeInsets.only(bottom: 8),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BangumiWidget.kostoriImage(
                  context,
                  bangumiItem.images['large']!,
                  width: width,
                  height: height,
                ),
              ),
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
                            ? backdropFilter(scoreWidget())
                            : containerBackground(scoreWidget()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: width,
          child: Text(
            bangumiItem.nameCn.isNotEmpty
                ? bangumiItem.nameCn
                : bangumiItem.name,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class BangumiHorizontalCard extends StatelessWidget {
  final BangumiSRI bangumiItem;
  final double width;
  final double imageHeight;

  const BangumiHorizontalCard({
    required this.bangumiItem,
    required this.width,
    required this.imageHeight,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final title = bangumiItem.nameCn.isEmpty
        ? bangumiItem.name
        : bangumiItem.nameCn;

    return SizedBox(
      width: width,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: width / imageHeight,
              child: Ink.image(
                image: CachedImageProvider(
                  bangumiItem.images['large']!,
                  sourceKey: 'bangumi',
                ),
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(2.0),
              child: Center(
                child: Text(
                  bangumiItem.relation,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BangumiCharacterCard extends StatelessWidget {
  const _BangumiCharacterCard({
    required this.character,
    required this.width,
    required this.height,
  });

  final CharacterActor character;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final title = character.nameCN.isNotEmpty
        ? character.nameCN
        : character.name;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: width,
          height: height,
          margin: const EdgeInsets.only(bottom: 8),
          child: Stack(
            children: [
              Positioned.fill(
                child: character.images.large.isEmpty
                    ? SizedBox(width: width, height: height)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BangumiWidget.kostoriImage(
                          context,
                          character.images.large,
                          width: width,
                          height: height,
                        ),
                      ),
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
        SizedBox(
          width: width,
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
