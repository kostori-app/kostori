import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kostori/pages/bangumi/bangumi_item.dart';

class LineChatPage extends StatefulWidget {
  const LineChatPage({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  State<LineChatPage> createState() => _LineChatPageState();
}

class _LineChatPageState extends State<LineChatPage> {
  List<Color> gradientColors = [
    AppColors.contentColorCyan,
    AppColors.contentColorBlue,
  ];

  bool showAvg = false;

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    Widget text;
    switch (value.toInt()) {
      case 0:
        text = const Text('1', style: style);
        break;
      case 1:
        text = const Text('2', style: style);
        break;
      case 2:
        text = const Text('3', style: style);
        break;
      case 3:
        text = const Text('4', style: style);
        break;
      case 4:
        text = const Text('5', style: style);
        break;
      case 5:
        text = const Text('6', style: style);
        break;
      case 6:
        text = const Text('7', style: style);
        break;
      case 7:
        text = const Text('8', style: style);
        break;
      case 8:
        text = const Text('9', style: style);
        break;
      case 9:
        text = const Text('10', style: style);
        break;
      default:
        text = const Text('', style: style);
        break;
    }

    return SideTitleWidget(
      meta: meta,
      child: text,
    );
  }

  double _calculateOptimalIntegerInterval(double maxValue) {
    // 确保至少有2个标签，最多10个标签
    final rawInterval = maxValue / 9; // 10个标签需要9个间隔
    final base = pow(10, (log(rawInterval) / ln10).floor()).toDouble();

    // 选择最接近的友好间隔（1,2,5,10的倍数）
    final candidates = [1 * base, 2 * base, 5 * base, 10 * base];
    final optimal = candidates.firstWhere(
        (interval) => (maxValue / interval).ceil() <= 10,
        orElse: () => 10 * base);

    return optimal;
  }

  // 新增方法：计算动态整数间隔
  double getYInterval(BangumiItem item) {
    final maxValue = item.total.toDouble() * 2 / 4;
    return _calculateOptimalIntegerInterval(maxValue);
  }

  // 将最大值对齐到间隔整数倍
  double _ceilToInterval(double value, double interval) {
    return (value / interval).ceil() * interval;
  }

  String _formatInteger(double value) {
    return value.toInt().toString();
  }

  // 动态计算左侧保留空间
  double _calculateLeftReservedSize(double maxY) {
    final maxLabel = _formatInteger(maxY);
    final textPainter = TextPainter(
      text: TextSpan(
        text: maxLabel,
        style: const TextStyle(fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    return textPainter.width;
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      // fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    return Text(_formatInteger(value), style: style, textAlign: TextAlign.left);
  }

  LineChartData mainData(BangumiItem bangumiItem) {
    final yInterval = getYInterval(bangumiItem);
    final rawMaxY = bangumiItem.total.toDouble() * 2 / 4;
    final maxY = _ceilToInterval(rawMaxY, yInterval);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: bangumiItem.total.toDouble() * 1 / 10,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: AppColors.mainGridLineColor,
            strokeWidth: 2,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: AppColors.mainGridLineColor,
            strokeWidth: 2,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d)),
      ),
      minX: 0,
      maxX: 9,
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: [
            FlSpot(0, bangumiItem.count!['1']!.toDouble()),
            FlSpot(1, bangumiItem.count!['2']!.toDouble()),
            FlSpot(2, bangumiItem.count!['3']!.toDouble()),
            FlSpot(3, bangumiItem.count!['4']!.toDouble()),
            FlSpot(4, bangumiItem.count!['5']!.toDouble()),
            FlSpot(5, bangumiItem.count!['6']!.toDouble()),
            FlSpot(6, bangumiItem.count!['7']!.toDouble()),
            FlSpot(7, bangumiItem.count!['8']!.toDouble()),
            FlSpot(8, bangumiItem.count!['9']!.toDouble()),
            FlSpot(9, bangumiItem.count!['10']!.toDouble()),
          ],
          isCurved: true,
          gradient: LinearGradient(
            colors: gradientColors,
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors
                  .map((color) => color.withValues(alpha: 0.3))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.70,
          child: Padding(
            padding: const EdgeInsets.only(
              right: 18,
              left: 12,
              top: 24,
              bottom: 12,
            ),
            child: LineChart(
              mainData(widget.bangumiItem),
            ),
          ),
        ),
      ],
    );
  }
}

class AppColors {
  static const contentColorCyan = Color(0xFF00FFFF); // 示例颜色
  static const contentColorBlue = Color(0xFF0000FF);

  static Color mainGridLineColor = Color(0x42A9A9A9).withAlpha(255); // 示例颜色
}
