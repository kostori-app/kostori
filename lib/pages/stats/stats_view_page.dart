import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/translations.dart';

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

  @override
  void initState() {
    super.initState();
    ratingMap = StatsManager().getLatestRatingsCountMap();
    ratingList = List.generate(10, (index) {
      return ratingMap[(index + 1).toString()] ?? 0;
    });
    _calculateStats();
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

  Widget buildViewWidget(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 850;

    Widget buildCards() {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
          child: Center(child: content),
        );
      });

      return LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth =
              (constraints.maxWidth - (itemsPerRow - 1) * spacing) /
              itemsPerRow;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: cardList.map((card) {
              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: card,
              );
            }).toList(),
          );
        },
      );
    }

    Widget chart = SizedBox(
      height: isWide ? 300 : 240,
      child: IntListBarChartPage(values: ratingList),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: buildCards()),
          const SizedBox(width: 16),
          Expanded(child: chart),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [buildCards(), const SizedBox(height: 12), chart],
      );
    }
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
                Center(child: Text('统计图表'.tl, style: ts.s18)),

                const SizedBox(width: 10),
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
}
