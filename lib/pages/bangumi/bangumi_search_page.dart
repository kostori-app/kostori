import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/utils/translations.dart';

import 'package:kostori/components/bangumi_widget.dart';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/utils/utils.dart';

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

  String airDate = '';
  String endDate = '';

  final List<String> options = [
    '最佳匹配',
    '最高排名',
    '最高收藏',
    '最高评分',
  ];

  String selectedOption = '最高排名'; // 当前选中的选项
  final Map<String, String> optionToSortType = {
    '最佳匹配': 'match',
    '最高排名': 'rank',
    '最高收藏': 'heat',
    '最高评分': 'score',
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

  Future<List<BangumiItem>> bangumiSearch() async {
    return Bangumi.bangumiPostSearch(keyword,
        tags: tags, sort: sort, airDate: airDate, endDate: endDate);
  }

  Future<void> _loadinitial() async {
    setState(() {
      _isLoading = true;
    });
    final newItems = await bangumiSearch();
    bangumiItems = newItems;
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        bangumiItems.length >= 20) {
      setState(() {
        _isLoading = true;
      });
      final result = await Bangumi.bangumiPostSearch(keyword,
          tags: tags,
          offset: bangumiItems.length,
          sort: sort,
          airDate: airDate,
          endDate: endDate);
      bangumiItems.addAll(result);
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 构建所有标签分类
// 在State类中添加以下变量
  int selectedCountForCategory(TagCategory category) {
    return tags.where((tag) => category.tags.contains(tag)).length;
  }

  final categories = [
    TagCategory(title: '类型', tags: type),
    TagCategory(title: '背景', tags: background),
    TagCategory(title: '角色', tags: role),
    TagCategory(title: '情感', tags: emotional),
    TagCategory(title: '来源', tags: source),
    TagCategory(title: '受众', tags: audience),
    TagCategory(title: '分类', tags: classification),
  ];

// 分类选择栏
  List<Widget> _buildTagCategories() {
    return [
      SliverToBoxAdapter(
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final selectedCount = selectedCountForCategory(category);

              return Padding(
                padding: EdgeInsets.only(left: index == 0 ? 16 : 0, right: 16),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.title),
                      if (selectedCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$selectedCount',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  selected: selectedCount > 0,
                  onSelected: (_) => _showTagSelectionDialog(context, category),
                  selectedColor:
                      Theme.of(context).colorScheme.primary.toOpacity(0.1),
                  labelStyle: TextStyle(
                    color: selectedCount > 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selectedCount > 0
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .toOpacity(0.72)
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

// 标签选择对话框
  void _showTagSelectionDialog(BuildContext context, TagCategory category) {
    final currentSelected =
        List<String>.from(tags.where((tag) => category.tags.contains(tag)));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
                insetPadding: const EdgeInsets.all(24),
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      constraints:
                          BoxConstraints(maxWidth: 500, maxHeight: 600),
                      decoration: BoxDecoration(
                        color: context.colorScheme.surface.toOpacity(0.22),
                        borderRadius: BorderRadius.circular(24), // 👈 设置圆角半径
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 标题栏
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Text('选择${category.title}',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const Spacer(),
                                IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.pop(context)),
                              ],
                            ),
                          ),
                          // 标签区
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: category.tags.map((tag) {
                                  final isSelected =
                                      currentSelected.contains(tag);
                                  return InputChip(
                                    backgroundColor:
                                        Colors.black.toOpacity(0.5),
                                    shape: StadiumBorder(
                                      side: BorderSide(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .toOpacity(0.72)
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withAlpha(4),
                                      ),
                                    ),
                                    label: Text(tag),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          if (!currentSelected.contains(tag)) {
                                            currentSelected.add(tag);
                                          }
                                        } else {
                                          currentSelected.remove(tag);
                                        }
                                      });
                                    },
                                    selectedColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .toOpacity(0.22),
                                    checkmarkColor: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .toOpacity(0.72)
                                        : Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withAlpha(4),
                                    showCheckmark: true,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          // 操作栏
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () =>
                                      setState(() => currentSelected.clear()),
                                  child: const Text('清空'),
                                ),
                                const Spacer(),
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('取消')),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    _updateSelectedTags(
                                        category, currentSelected);
                                    Navigator.pop(context);
                                  },
                                  child: Text('确认 (${currentSelected.length})'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
          },
        );
      },
    );
  }

  void _updateSelectedTags(
      TagCategory category, List<String> selectedTagsInCategory) async {
    setState(() {
      // 先把这个分类原来选中的标签从tags中移除
      tags.removeWhere((tag) => category.tags.contains(tag));
      // 再把最新选中的标签加进去
      tags.addAll(selectedTagsInCategory);
    });
    setState(() {
      _isLoading = true;
      bangumiItems.clear();
    });
    final newItems = await bangumiSearch();
    bangumiItems = newItems;
    setState(() {
      _isLoading = false;
    });
  }

  void _showAddTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.toOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    // filled: true,
                    fillColor: Theme.of(context).cardColor,
                    hintText: '输入关键词...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onSubmitted: (value) async {
                    setState(() {
                      tags.add(value);
                      _isLoading = true;
                      bangumiItems.clear();
                    });
                    context.pop();
                    final newItems = await bangumiSearch();
                    bangumiItems = newItems;
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 内容列表（根据选中标签过滤）
  Widget _buildContentListSliver() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return useBriefMode
              ? BangumiWidget.buildBriefMode(
                  context, bangumiItems[index], 'search')
              : BangumiWidget.buildDetailedMode(
                  context, bangumiItems[index], 'search');
        },
        childCount: bangumiItems.length,
      ),
      gridDelegate: SliverGridDelegateWithBangumiItems(useBriefMode),
    );
  }

  void _showAirEndDateDialog(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime? air = Utils.safeParseDate(airDate);
    DateTime? end = Utils.safeParseDate(endDate);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStates) {
            Future<void> pickDate(bool isAirDate) async {
              DateTime initial = isAirDate ? (air ?? now) : (end ?? now);
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(now.year - 50),
                lastDate: DateTime(now.year + 30),
              );
              if (picked != null) {
                setStates(() {
                  if (isAirDate) {
                    air = picked;
                  } else {
                    end = picked;
                  }
                });
              }
            }

            String formatDate(DateTime? date) {
              if (date == null) return "未选择";
              return "${date.year.toString().padLeft(4, '0')}-"
                  "${date.month.toString().padLeft(2, '0')}-"
                  "${date.day.toString().padLeft(2, '0')}";
            }

            return AlertDialog(
              title: Text("选择日期"),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text("开始日期"),
                      subtitle: Text(formatDate(air)),
                      trailing: Icon(Icons.date_range),
                      onTap: () => pickDate(true),
                    ),
                    ListTile(
                      title: Text("结束日期"),
                      subtitle: Text(formatDate(end)),
                      trailing: Icon(Icons.date_range),
                      onTap: () => pickDate(false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setStates(() {
                      air = null;
                      end = null;
                    });
                  },
                  child: Text("清除日期"),
                ),
                // const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("取消"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (air == null && end == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("请选择日期")),
                      );
                      return;
                    }

                    if (air != null && end != null && end!.isBefore(air!)) {
                      context.showMessage(message: '结束日期不能早于起始日期');
                      return;
                    }

                    airDate = air != null ? formatDate(air) : '';
                    endDate = end != null ? formatDate(end) : '';

                    Log.addLog(LogLevel.info, 'pickDate',
                        "Air Date: $airDate, End Date: $endDate");

                    Navigator.pop(context);
                    bangumiItems.clear();
                    final newItems = await bangumiSearch();
                    bangumiItems = newItems;

                    setState(() {});
                  },
                  child: Text("确认"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _toolBoxWidget(BuildContext context) {
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
                airDate = '';
                endDate = '';
                setState(() {});
              },
              tooltip: "清除标签".tl,
              icon: const Icon(Icons.clear_all)),
          IconButton(
              onPressed: () {
                _showAddTagDialog(context);
              },
              icon: const Icon(Icons.add)),
          const Spacer(),
          IconButton(
              onPressed: () {
                _showAirEndDateDialog(context);
              },
              tooltip: "选择时间".tl,
              icon: Icon(Icons.calendar_today)),
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
              setState(() {
                _isLoading = true;
              });
              bangumiItems = await bangumiSearch();
              setState(() {
                _isLoading = false;
              });
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

  Widget _sliverAppBar(BuildContext context) {
    return SliverAppBar(
      title: const Text("搜索"),
      // style: AppbarStyle.blur,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: context.colorScheme.surface.toOpacity(0.22),
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
                onSubmitted: (value) async {
                  keyword = value;
                  setState(() {
                    _isLoading = true;
                  });
                  final newItems = await bangumiSearch();
                  bangumiItems = newItems;
                  setState(() {
                    _isLoading = false;
                  });
                },
                // onChanged: (value) => searchQuery = value,
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
              color: Theme.of(context).colorScheme.surface.toOpacity(0.22)),
        ),
      ),
      pinned: true,
      floating: true,
      elevation: 0,
      snap: true,
      // expandedHeight: 150, // 调整这个值以适应内容
    );
  }

  Widget _tagsWidget(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: tags.map((tag) {
          return ActionChip(
            label: Text(tag),
            onPressed: () async {
              setState(() {
                tags.remove(tag);
                _isLoading = true;
                bangumiItems.clear();
              });
              final newItems = await bangumiSearch();
              bangumiItems = newItems;
              setState(() {
                _isLoading = false;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.toOpacity(0.72),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dataTagsWidget(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            if (airDate.isNotEmpty)
              ActionChip(
                avatar:
                    Icon(Icons.calendar_today, size: 16, color: Colors.green),
                label: Text(airDate),
                onPressed: () async {
                  airDate = '';
                  bangumiItems.clear();
                  final newItems = await bangumiSearch();
                  bangumiItems = newItems;
                  setState(() {});
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.green.toOpacity(0.6)),
                ),
                backgroundColor: Colors.green.toOpacity(0.1),
                labelStyle: TextStyle(color: Colors.green),
              ),
            if (endDate.isNotEmpty)
              ActionChip(
                avatar:
                    Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                label: Text(endDate),
                onPressed: () async {
                  endDate = '';
                  bangumiItems.clear();
                  final newItems = await bangumiSearch();
                  bangumiItems = newItems;
                  setState(() {});
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.blue.toOpacity(0.6)),
                ),
                backgroundColor: Colors.blue.toOpacity(0.1),
                labelStyle: TextStyle(color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
        child: const Icon(Icons.arrow_upward),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _sliverAppBar(context),
              ..._buildTagCategories(),
              if (tags.isNotEmpty)
                SliverToBoxAdapter(
                  child: _tagsWidget(context),
                ),
              if (airDate.isNotEmpty || endDate.isNotEmpty)
                _dataTagsWidget(context),
              SliverToBoxAdapter(child: _toolBoxWidget(context)),
              _buildContentListSliver(),
              if (_isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: MiscComponents.placeholder(
                          context, 40, 40, Colors.transparent),
                    ),
                  ),
                ),
            ],
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
