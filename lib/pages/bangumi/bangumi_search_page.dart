import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';

class BangumiSearchPage extends StatefulWidget {
  const BangumiSearchPage({super.key, this.tag});

  final String? tag;

  @override
  State<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

class _BangumiSearchPageState extends State<BangumiSearchPage> {
  final ScrollController _scrollController = ScrollController();
  final maxWidth = 1250.0;
  List<String> tags = [];
  List<BangumiItem> bangumiItems = [];

  bool useBriefMode = false;
  bool displayLabels = false;

  String keyword = '';

  String sort = 'rank';

  bool _isLoading = false;

  final List<String> options = ['最佳匹配', '最高排名', '最多收藏'];

  String selectedOption = '最高排名'; // 当前选中的选项
  final Map<String, String> optionToSortType = {
    '最佳匹配': 'match',
    '最高排名': 'rank',
    '最多收藏': 'heat',
  };

  @override
  void initState() {
    super.initState();
    if (widget.tag != null) {
      tags.add(widget.tag!);
      displayLabels = true;
      _loadinitial();
    }
    _scrollController.addListener(_loadMoreData);
  }

  @override
  void dispose() {
    bangumiItems.clear();
    _scrollController.removeListener(_loadMoreData);
    super.dispose();
  }

  Future<void> _loadinitial() async {
    final newItems =
        await Bangumi.bangumiPostSearch(keyword, tags: tags, sort: sort);
    bangumiItems = newItems;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadMoreData() async {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        bangumiItems.length >= 20) {
      _isLoading = true;
      final result = await Bangumi.bangumiPostSearch(keyword,
          tags: tags, offset: bangumiItems.length, sort: sort);
      bangumiItems.addAll(result);
      _isLoading = false;
      setState(() {});
    }
  }

  // 构建所有标签分类
  List<Widget> _buildTagCategories() {
    final categories = [
      TagCategory(title: '类型', tags: type),
      TagCategory(title: '背景', tags: background),
      TagCategory(title: '角色', tags: role),
      TagCategory(title: '情感', tags: emotional),
      TagCategory(title: '来源', tags: source),
      TagCategory(title: '受众', tags: audience),
      TagCategory(title: '分类', tags: classification),
    ];

    return categories.map((category) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Builder(
                builder: (context) {
                  // 获取屏幕宽度
                  final screenWidth =
                      (MediaQuery.of(context).size.width > maxWidth)
                          ? maxWidth
                          : MediaQuery.of(context).size.width - 32;
                  // 计算可用宽度（减去标题和间距）
                  final availableWidth =
                      screenWidth - 16 * 2 - 60 - 8; // padding + title + gap

                  final tagWidgets = category.tags.map((tag) {
                    final isSelected = tags.contains(tag);
                    return ChoiceChip(
                      label: Text(tag, style: TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (selected) async {
                        setState(() {
                          selected ? tags.add(tag) : tags.remove(tag);
                        });

                        final newItems = await Bangumi.bangumiPostSearch(
                            keyword,
                            tags: tags,
                            sort: sort);
                        if (mounted) setState(() => bangumiItems = newItems);
                      },
                      selectedColor: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .toOpacity(0.72),
                      labelPadding: EdgeInsets.symmetric(horizontal: 8),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .toOpacity(0.72)
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha(20),
                          width: 1,
                        ),
                      ),
                    );
                  }).toList();

                  // 估算行数（简化版，实际需要更精确计算）
                  final estimatedLineCount = _estimateLineCount(
                    tagWidgets.length,
                    availableWidth,
                    averageTagWidth: 40, // 平均标签宽度，可根据实际情况调整
                  );

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题（固定宽度）
                      Container(
                        width: 60,
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          category.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // 标签区域（动态高度）
                      Expanded(
                        child: SizedBox(
                          height: estimatedLineCount * 32 +
                              (estimatedLineCount - 1) * 8, // 动态高度
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: {
                                ui.PointerDeviceKind.touch,
                                ui.PointerDeviceKind.mouse,
                              },
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: BouncingScrollPhysics(),
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: (MediaQuery.of(context).size.width >
                                          maxWidth)
                                      ? maxWidth
                                      : MediaQuery.of(context).size.width - 32,
                                ),
                                child: Wrap(
                                  direction: Axis.horizontal,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: tagWidgets,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Divider(height: 1, thickness: 0.5),
          ],
        ),
      );
    }).toList();
  }

// 估算需要的行数
  int _estimateLineCount(int tagCount, double availableWidth,
      {double averageTagWidth = 80}) {
    final tagsPerLine = (availableWidth / (averageTagWidth + 8)).floor();
    if (tagsPerLine <= 0) return 1;
    final lineCount = (tagCount / tagsPerLine).ceil();
    return lineCount.clamp(1, 2); // 限制最大2行
  }

  // 内容列表（根据选中标签过滤）
  Widget _buildContentList() {
    return GridView.builder(
      key: ValueKey(selectedOption),
      itemCount: bangumiItems.length,
      itemBuilder: (context, index) {
        return useBriefMode
            ? _buildBriefMode(context, bangumiItems[index])
            : _buildDetailedMode(context, bangumiItems[index]);
      },
      gridDelegate: SliverGridDelegateWithBangumiItems(useBriefMode),
    );
  }

  Widget _buildBriefMode(BuildContext context, BangumiItem bangumiItem) {
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
                tag: bangumiItem.id,
                child: CachedNetworkImage(
                  imageUrl: bangumiItem.images['large']!,
                  width: height * 0.72,
                  height: height,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => MiscComponents.placeholder(
                      context, height * 0.72, height),
                ),
              ),
            );

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                App.mainNavigatorKey?.currentContext?.to(() => BangumiInfoPage(
                      bangumiItem: bangumiItem,
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

  Widget _buildDetailedMode(BuildContext context, BangumiItem bangumiItem) {
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
          tag: bangumiItem.id,
          child: CachedNetworkImage(
            imageUrl: bangumiItem.images['large']!,
            width: height * 0.72,
            height: height,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                MiscComponents.placeholder(context, height * 0.72, height),
          ),
        ),
      );

      return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            App.mainNavigatorKey?.currentContext?.to(() => BangumiInfoPage(
                  bangumiItem: bangumiItem,
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
                  child: _bangumiDescription(bangumiItem),
                ),
              ],
            ),
          ));
    });
  }

  Widget _bangumiDescription(BangumiItem bangumiItem) {
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
                fontSize: 32.0,
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
      ),
    ]);
  }

  Widget _toolBoxWidget() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: MediaQuery.of(context).size.width - 30,
      color: Colors.transparent,
      child: Row(
        children: [
          Text('已展示 ${bangumiItems.length} 个结果'),
          const SizedBox(width: 8),
          IconButton(
              onPressed: () {
                bangumiItems.clear();
                tags.clear();
                setState(() {});
              },
              tooltip: "清除标签".tl,
              icon: const Icon(Icons.clear_all)),
          if (widget.tag != null && displayLabels)
            TextButton(
                onPressed: () {
                  tags.remove(widget.tag!);
                  displayLabels = false;
                  setState(() {});
                },
                child: Text(widget.tag!)),
          const Spacer(),
          IconButton(
              onPressed: () {
                useBriefMode = !useBriefMode;
                setState(() {});
              },
              tooltip: "布局切换".tl,
              icon: useBriefMode ? Icon(Icons.apps) : Icon(Icons.view_agenda)),
          PopupMenuButton<String>(
            icon: Row(
              children: [
                const Icon(Icons.sort, size: 20), // 排序图标
                const SizedBox(width: 4),
                Text(selectedOption), // 当前选中的文本
              ],
            ),
            onSelected: (String selected) async {
              setState(() {
                selectedOption = selected; // 更新选中的选项
              });
              // 这里可以添加排序逻辑
              final sortType = optionToSortType[selected]!;
              sort = sortType;
              bangumiItems.clear();
              bangumiItems = await Bangumi.bangumiPostSearch(keyword,
                  tags: tags, sort: sort);
              setState(() {});
            },
            itemBuilder: (BuildContext context) {
              return options.map((String option) {
                return PopupMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList();
            },
          ),
        ],
      ),
    );
  }

  Widget _sliverAppBar(BuildContext contextc) {
    return SliverAppBar(
      title: const Text("搜索"),
      // style: AppbarStyle.blur,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              // color: context.colorScheme.surface.toOpacity(0.22),
              padding: EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  hintText: '输入关键词...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: context.colorScheme.surface.toOpacity(0.22)),
        ),
      ),
      pinned: true,
      floating: true,
      elevation: 0,
      snap: true,
      // expandedHeight: 150, // 调整这个值以适应内容
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth // 设置最大宽度为800
              ),
          child: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _sliverAppBar(context),
                ..._buildTagCategories(),
                SliverToBoxAdapter(
                  child: _toolBoxWidget(),
                ),
              ];
            },
            body: _buildContentList(),
          ),
        ),
      ),
    );
  }
}

class TagCategory {
  final String title;
  final List<String> tags;

  TagCategory({required this.title, required this.tags});
}

class SliverGridDelegateWithBangumiItems extends SliverGridDelegate {
  SliverGridDelegateWithBangumiItems(this.useBriefMode);

  final bool useBriefMode;

  final double scale = 1.toDouble();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    if (useBriefMode) {
      return getBriefModeLayout(
        constraints,
        scale,
      );
    } else {
      return getDetailedModeLayout(
        constraints,
        scale,
      );
    }
  }

  SliverGridLayout getDetailedModeLayout(
      SliverConstraints constraints, double scale) {
    const minCrossAxisExtent = 360;
    final itemHeight = 192 * scale;
    int crossAxisCount =
        (constraints.crossAxisExtent / minCrossAxisExtent).floor();
    crossAxisCount = math.min(3, math.max(1, crossAxisCount)); // 限制1-3列
    return SliverGridRegularTileLayout(
        crossAxisCount: crossAxisCount,
        mainAxisStride: itemHeight,
        crossAxisStride: constraints.crossAxisExtent / crossAxisCount,
        childMainAxisExtent: itemHeight,
        childCrossAxisExtent: constraints.crossAxisExtent / crossAxisCount,
        reverseCrossAxis: false);
  }

  SliverGridLayout getBriefModeLayout(
      SliverConstraints constraints, double scale) {
    final maxCrossAxisExtent = 192.0 * scale;
    const childAspectRatio = 0.68;
    const crossAxisSpacing = 0.0;
    int crossAxisCount =
        (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing))
            .ceil();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = math.max(1, crossAxisCount);
    final double usableCrossAxisExtent = math.max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = childCrossAxisExtent / childAspectRatio;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) {
    if (oldDelegate is! SliverGridDelegateWithBangumiItems) return true;
    if (oldDelegate.scale != scale ||
        oldDelegate.useBriefMode != useBriefMode) {
      return true;
    }
    return false;
  }
}
