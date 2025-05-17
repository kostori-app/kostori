import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';

import 'package:kostori/foundation/consts.dart';

import '../../components/misc_components.dart';
import '../../foundation/bangumi/bangumi_item.dart';
import '../../network/bangumi.dart';

class BangumiSearchPage extends StatefulWidget {
  const BangumiSearchPage({super.key, this.tag});

  final String? tag;

  @override
  State<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

class _BangumiSearchPageState extends State<BangumiSearchPage> {
  List<String> tags = [];
  List<BangumiItem> bangumiItems = [];

  String keyword = '';

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
                  final screenWidth = MediaQuery.of(context).size.width;
                  // 计算可用宽度（减去标题和间距）
                  final availableWidth =
                      screenWidth - 16 * 2 - 60 - 8; // padding + title + gap

                  final tagWidgets = category.tags.map((tag) {
                    final isSelected = tags.contains(tag);
                    return ChoiceChip(
                      label: Text(tag, style: TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (selected) async {
                        selected ? tags.add(tag) : tags.remove(tag);
                        bangumiItems.clear();
                        bangumiItems = await Bangumi.bangumiPostSearch(keyword,
                            tags: tags);
                        setState(() {});
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
                    averageTagWidth: 80, // 平均标签宽度，可根据实际情况调整
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
                                  maxWidth: MediaQuery.of(context).size.width,
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
    final displayText =
        tags.isEmpty ? "未选择标签，显示全部内容" : "已选择标签: ${tags.join(', ')}";

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: bangumiItems.length,
      itemBuilder: (context, index) {
        return _buildDetailedMode(context, bangumiItems[index]);
      },
    );
  }

  Widget _buildDetailedMode(BuildContext context, BangumiItem bangumiItem) {
    return LayoutBuilder(builder: (context, constrains) {
      final height = constrains.maxHeight - 16;

      Widget image = Container(
        width: height * 0.68,
        height: 200,
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
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                MiscComponents.placeholder(context, 200, 200),
          ),
        ),
      );

      return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
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
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
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
                child: Container(
                    color: context.colorScheme.surface.toOpacity(0.22)),
              ),
            ),
            pinned: true,
            floating: true,
            elevation: 0,
            snap: true,
            // expandedHeight: 150, // 调整这个值以适应内容
          ),
          ..._buildTagCategories(),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: MediaQuery.of(context).size.width - 30,
              color: Colors.transparent,
              child: Row(
                children: [
                  Text('已展示 ${bangumiItems.length} 个结果'),
                  const Spacer(),
                  Text('占位')
                ],
              ),
            ),
          ),
        ];
      },
      body: _buildContentList(),
    ));
  }
}

class TagCategory {
  final String title;
  final List<String> tags;

  TagCategory({required this.title, required this.tags});
}
