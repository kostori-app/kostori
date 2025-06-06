import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';

class AppColors {
  static const contentColorCyan = Color(0xFF00FFFF); // 示例颜色
  static const contentColorBlue = Color(0xFF0000FF);

  static Color mainGridLineColor = Color(0x42A9A9A9).withAlpha(255); // 示例颜色
}

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
    // 处理无效输入
    if (maxValue <= 0 || maxValue.isInfinite || maxValue.isNaN) {
      return 1.0;
    }

    // 计算初始间隔（确保不为零或负）
    final rawInterval = (maxValue / 15).clamp(1e-10, double.infinity);
    final logValue = log(rawInterval) / ln10;
    final exponent = logValue.floor();
    final base = pow(10, exponent).toDouble();

    // 候选友好间隔
    final candidates = [1 * base, 2 * base, 5 * base, 10 * base, 15 * base];

    // 选择最优间隔
    return candidates.firstWhere(
      (interval) => interval > 0 && (maxValue / interval).ceil() <= 15,
      orElse: () => 15 * base,
    );
  }

  // 新增方法：计算动态整数间隔
  double getYInterval(BangumiItem item) {
    final maxValue = item.total.toDouble() * 2 / 3;
    return _calculateOptimalIntegerInterval(maxValue);
  }

  // 将最大值对齐到间隔整数倍
  double _ceilToInterval(double value, double interval) {
    return (value / interval).ceil() * interval;
  }

  String _formatInteger(double value) {
    return value.toInt().toString();
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
    final rawMaxY = bangumiItem.total.toDouble() * 2 / 3;
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
          isCurved: false,
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

class BangumiBarChartPage extends StatelessWidget {
  final BangumiItem bangumiItem;

  const BangumiBarChartPage({super.key, required this.bangumiItem});

  @override
  Widget build(BuildContext context) {
    final yInterval = _getYInterval(bangumiItem);
    final maxY =
        _ceilToInterval((bangumiItem.total.toDouble() * 2 / 3), yInterval);

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: barTouchData,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _bottomTitles,
                reservedSize: 28,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true),
          barGroups: _buildBarGroups(bangumiItem),
        ),
      ),
    );
  }

  BarTouchData get barTouchData => BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => Colors.transparent,
          tooltipPadding: EdgeInsets.zero,
          tooltipMargin: 8,
          getTooltipItem: (
            BarChartGroupData group,
            int groupIndex,
            BarChartRodData rod,
            int rodIndex,
          ) {
            return BarTooltipItem(
              rod.toY.round().toString(),
              const TextStyle(
                color: AppColors.contentColorCyan,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      );

  List<BarChartGroupData> _buildBarGroups(BangumiItem item) {
    final gradient = LinearGradient(
      colors: [Colors.tealAccent, Colors.blueAccent],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );

    return List.generate(10, (index) {
      final scoreKey = (index + 1).toString();
      final count = item.count?[scoreKey]?.toDouble() ?? 0.0;

      return BarChartGroupData(
        x: index,
        showingTooltipIndicators: [0],
        barRods: [
          BarChartRodData(
            toY: count,
            gradient: gradient,
            width: 9,
            borderSide: BorderSide.none,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
          ),
        ],
      );
    });
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text('${value.toInt() + 1}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  double _getYInterval(BangumiItem item) {
    final maxValue = item.total.toDouble() * 2 / 3;
    return _calculateOptimalIntegerInterval(maxValue);
  }

  double _calculateOptimalIntegerInterval(double maxValue) {
    if (maxValue <= 0 || maxValue.isNaN || maxValue.isInfinite) return 1.0;
    final rawInterval = (maxValue / 15).clamp(1e-10, double.infinity);
    final exponent = (log(rawInterval) / ln10).floor();
    final base = pow(10, exponent).toDouble();
    final candidates = [1, 2, 5, 10, 15].map((m) => m * base).toList();

    return candidates.firstWhere((i) => (maxValue / i).ceil() <= 15,
        orElse: () => 15 * base);
  }

  double _ceilToInterval(double value, double interval) {
    return (value / interval).ceil() * interval;
  }
}
