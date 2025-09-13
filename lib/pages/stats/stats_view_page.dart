import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/translations.dart';
import 'package:word_cloud/word_cloud_data.dart';
import 'package:word_cloud/word_cloud_shape.dart';
import 'package:word_cloud/word_cloud_view.dart';

class StatsViewPage extends StatefulWidget {
  const StatsViewPage({super.key});

  @override
  State<StatsViewPage> createState() => _StatsViewPageState();
}

class _StatsViewPageState extends State<StatsViewPage> {
  Map<String, int> ratingMap = {};
  List<int> ratingList = [];
  double average = 0;
  double stdDev = 0;
  int totalCount = 0;
  bool showWordCloud = false;
  List<Map<String, dynamic>> wordCloudData = [];

  @override
  void initState() {
    super.initState();
    ratingMap = StatsManager().getLatestRatingsCountMap();
    ratingList = List.generate(10, (index) {
      return ratingMap[(index + 1).toString()] ?? 0;
    });
    _calculateStats();
    _loadWordCloudData();
  }

  void _calculateStats() {
    totalCount = ratingList.reduce((a, b) => a + b);

    if (totalCount > 0) {
      // 平均分
      int weightedSum = 0;
      for (int i = 0; i < ratingList.length; i++) {
        weightedSum += ratingList[i] * (i + 1);
      }
      average = weightedSum / totalCount;
      // 标准差
      double varianceSum = 0;
      for (int i = 0; i < ratingList.length; i++) {
        varianceSum += ratingList[i] * pow((i + 1) - average, 2);
      }
      stdDev = sqrt(varianceSum / totalCount);
    }
  }

  // 加载词云数据
  Future<void> _loadWordCloudData() async {
    final allStats = StatsManager().getStatsAll();

    final Map<int, List<StatsDataImpl>> groupedByBangumiId = {};

    for (final stat in allStats) {
      if (stat.bangumiId != null) {
        groupedByBangumiId.putIfAbsent(stat.bangumiId!, () => []).add(stat);
      }
    }

    final Map<String, int> tagCounts = {};
    final Set<int> processedBangumiIds = {};

    for (final entry in groupedByBangumiId.entries) {
      final bangumiId = entry.key;
      final statsList = entry.value;

      final hasLiked = statsList.any((stat) => stat.liked);

      if (hasLiked && !processedBangumiIds.contains(bangumiId)) {
        processedBangumiIds.add(bangumiId);

        final bangumiItem = BangumiManager().getBangumiItem(bangumiId);
        if (bangumiItem != null) {
          for (final tag in bangumiItem.tags) {
            tagCounts.update(tag.name, (value) => value + 1, ifAbsent: () => 1);
          }
        }
      }
    }

    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      wordCloudData = sortedTags
          .map((entry) => {'word': entry.key, 'value': entry.value.toDouble()})
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Center(
                  child: Text(
                    !showWordCloud ? '统计图表'.tl : '标签词云'.tl,
                    style: ts.s18,
                  ),
                ),
                if (showWordCloud)
                  Button.icon(
                    size: 18,
                    icon: const Icon(Icons.help_outline),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return ContentDialog(
                            title: "Help".tl,
                            content: Text(
                              '被标记为喜欢的条目并且数据库内绑定bangumiId后才会被统计',
                            ).paddingHorizontal(16).fixWidth(double.infinity),
                            actions: [
                              Button.filled(
                                onPressed: context.pop,
                                child: Text("OK".tl),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    showWordCloud ? Icons.bar_chart : Icons.wb_cloudy_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      showWordCloud = !showWordCloud;
                    });
                  },
                  tooltip: showWordCloud ? '切换统计图表'.tl : '切换标签词云'.tl,
                ),
              ],
            ),
          ).paddingHorizontal(16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: buildViewWidget(context),
          ),
        ],
      ),
    );
  }

  Widget buildViewWidget(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 850;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SizeTransition(
            sizeFactor: curvedAnimation,
            axis: Axis.vertical,
            axisAlignment: 0,
            child: child,
          ),
        );
      },
      child: showWordCloud
          ? wordCloudData.isEmpty
                ? Center(key: const ValueKey('empty'), child: Text('暂无标签数据'.tl))
                : ClipRect(
                    key: const ValueKey('wordcloud'),
                    child: ResponsiveWordCloud(wordCloudData: wordCloudData),
                  )
          : KeyedSubtree(
              key: const ValueKey('chart'),
              child: isWide ? _buildWideLayout() : _buildNormalLayout(),
            ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildStatsCards()),
        const SizedBox(width: 16),
        Expanded(child: _buildChart()),
      ],
    );
  }

  Widget _buildNormalLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildStatsCards(), const SizedBox(height: 12), _buildChart()],
    );
  }

  Widget _buildStatsCards() {
    const int itemsPerRow = 3;
    const double cardHeight = 80;
    const double spacing = 8;

    List<Widget> cardList = List.generate(6, (index) {
      Widget content;
      switch (index) {
        case 0:
          content = Text('收藏: ${LocalFavoritesManager().totalAnimes}');
          break;
        case 1:
          content = Text(
            '完成: ${appdata.settings['FavoriteTypeCollect'] != 'none' ? LocalFavoritesManager().folderAnimes(appdata.settings['FavoriteTypeCollect']) : '0'}',
          );
          break;
        case 2:
          content = Text(
            '完成率: ${appdata.settings['FavoriteTypeCollect'] != 'none' ? '${(LocalFavoritesManager().folderAnimes(appdata.settings['FavoriteTypeCollect']) / LocalFavoritesManager().totalAnimes * 100).toStringAsFixed(1)}%' : '0%'}',
          );
          break;
        case 3:
          content = Text('平均分: ${average.toStringAsFixed(2)}');
          break;
        case 4:
          content = Text('标准差: ${stdDev.toStringAsFixed(2)}');
          break;
        case 5:
          content = Text('评分数: $totalCount');
          break;
        default:
          content = const Text('默认');
      }

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Center(child: content),
      );
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - (itemsPerRow - 1) * spacing) / itemsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cardList.map((card) {
            return SizedBox(width: cardWidth, height: cardHeight, child: card);
          }).toList(),
        );
      },
    );
  }

  Widget _buildChart() {
    return SizedBox(
      height: 300,
      child: IntListBarChartPage(values: ratingList),
    );
  }
}

class ResponsiveWordCloud extends StatefulWidget {
  final List<Map<String, dynamic>> wordCloudData;

  const ResponsiveWordCloud({super.key, required this.wordCloudData});

  @override
  State<ResponsiveWordCloud> createState() => _ResponsiveWordCloudState();
}

class _ResponsiveWordCloudState extends State<ResponsiveWordCloud> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return WordCloudView(
          data: WordCloudData(data: widget.wordCloudData),
          mapwidth: constraints.maxWidth,
          mapheight: 300,
          mintextsize: 12,
          maxtextsize: 38,
          colorlist: standardColorMap.keys.toList(),
          shape: WordCloudCircle(radius: constraints.maxWidth - 200),
        );
      },
    );
  }
}
