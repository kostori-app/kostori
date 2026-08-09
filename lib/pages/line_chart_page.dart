import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';

class AppColors {
  static const contentColorCyan = Color(0xFF00FFFF);
  static const contentColorBlue = Color(0xFF0000FF);

  static Color mainGridLineColor = Color(0x42A9A9A9).withAlpha(255);
}

class BangumiBarChartPage extends StatelessWidget {
  final BangumiItem bangumiItem;

  const BangumiBarChartPage({super.key, required this.bangumiItem});

  @override
  Widget build(BuildContext context) {
    final yInterval = _getYInterval(bangumiItem);
    final maxY = _ceilToInterval(
      (bangumiItem.total.toDouble() * 2 / 3),
      yInterval,
    );

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
      getTooltipItem:
          (
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
      child: Text(
        '${value.toInt() + 1}',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
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

    return candidates.firstWhere(
      (i) => (maxValue / i).ceil() <= 15,
      orElse: () => 15 * base,
    );
  }

  double _ceilToInterval(double value, double interval) {
    return (value / interval).ceil() * interval;
  }
}

class IntListBarChartPage extends StatelessWidget {
  final List<int> values;

  const IntListBarChartPage({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 1.0 : values.reduce(max).toDouble();
    final yInterval = _calculateOptimalIntegerInterval(maxValue);
    final maxY = _ceilToInterval(maxValue + 1, yInterval);

    return AspectRatio(
      aspectRatio: 1.2,
      child: BarChart(
        BarChartData(
          maxY: maxY > 0 ? maxY : 1,
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
          barGroups: _buildBarGroups(values),
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
      getTooltipItem:
          (
            BarChartGroupData group,
            int groupIndex,
            BarChartRodData rod,
            int rodIndex,
          ) {
            return BarTooltipItem(
              rod.toY.round().toString(),
              const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
            );
          },
    ),
  );

  List<BarChartGroupData> _buildBarGroups(List<int> values) {
    final gradient = const LinearGradient(
      colors: [Colors.tealAccent, Colors.blueAccent],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );

    return List.generate(values.length, (index) {
      final count = values[index].toDouble();
      return BarChartGroupData(
        x: index,
        showingTooltipIndicators: [0],
        barRods: [
          BarChartRodData(
            toY: count,
            gradient: gradient,
            width: 12,
            borderSide: BorderSide.none,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(
        '${value.toInt() + 1}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  double _calculateOptimalIntegerInterval(double maxValue) {
    if (maxValue <= 0 || maxValue.isNaN || maxValue.isInfinite) return 1.0;
    final rawInterval = (maxValue / 10).clamp(1e-10, double.infinity); // 每10格
    final exponent = (log(rawInterval) / ln10).floor();
    final base = pow(10, exponent).toDouble();
    final candidates = [1, 2, 5, 10, 15].map((m) => m * base).toList();
    return candidates.firstWhere(
      (i) => (maxValue / i).ceil() <= 10,
      orElse: () => 10 * base,
    );
  }

  double _ceilToInterval(double value, double interval) {
    return (value / interval).ceil() * interval;
  }
}
