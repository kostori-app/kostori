import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';

/// Bangumi 1~10 分投票分布柱状图
class BangumiBarChartPage extends StatelessWidget {
  final BangumiItem bangumiItem;

  const BangumiBarChartPage({super.key, required this.bangumiItem});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final yInterval = _getYInterval(bangumiItem);
    final maxY = _ceilToInterval(
      bangumiItem.total.toDouble() * 2 / 3,
      yInterval,
    );

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          maxY: maxY > 0 ? maxY : 10,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: barTouchData(cs),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _bottomTitles,
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yInterval,
                reservedSize: 42,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          barGroups: _buildBarGroups(bangumiItem, cs),
        ),
      ),
    );
  }

  BarTouchData barTouchData(ColorScheme cs) => BarTouchData(
    enabled: true,
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => cs.surfaceContainerHighest,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tooltipMargin: 8,
      getTooltipItem:
          (
            BarChartGroupData group,
            int groupIndex,
            BarChartRodData rod,
            int rodIndex,
          ) => BarTooltipItem(
            rod.toY.round().toString(),
            TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
    ),
  );

  List<BarChartGroupData> _buildBarGroups(BangumiItem item, ColorScheme cs) {
    final gradient = LinearGradient(
      colors: [cs.primaryContainer, cs.primary],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
    final topGradient = LinearGradient(
      colors: [cs.tertiaryContainer, cs.tertiary],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
    final maxCount =
        item.count?.values.fold<int>(0, (a, b) => b > a ? b : a) ?? 0;

    return List.generate(10, (index) {
      final scoreKey = (index + 1).toString();
      final count = item.count?[scoreKey]?.toDouble() ?? 0.0;

      return BarChartGroupData(
        x: index,
        showingTooltipIndicators: [0],
        barRods: [
          BarChartRodData(
            toY: count,
            gradient: (count > 0 && count == maxCount) ? topGradient : gradient,
            width: 12,
            borderSide: BorderSide.none,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ],
      );
    });
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      space: 6,
      child: Text(
        '${value.toInt() + 1}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

/// 通用整数列表柱状图
class IntListBarChartPage extends StatelessWidget {
  final List<int> values;

  const IntListBarChartPage({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxValue = values.isEmpty ? 1.0 : values.reduce(max).toDouble();
    final yInterval = _calculateOptimalIntegerInterval(maxValue);
    final maxY = _ceilToInterval(maxValue + 1, yInterval);

    return AspectRatio(
      aspectRatio: 1.2,
      child: BarChart(
        BarChartData(
          maxY: maxY > 0 ? maxY : 1,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: barTouchData(cs),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _bottomTitles,
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yInterval,
                reservedSize: 42,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          barGroups: _buildBarGroups(values, cs),
        ),
      ),
    );
  }

  BarTouchData barTouchData(ColorScheme cs) => BarTouchData(
    enabled: true,
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => cs.surfaceContainerHighest,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tooltipMargin: 8,
      getTooltipItem:
          (
            BarChartGroupData group,
            int groupIndex,
            BarChartRodData rod,
            int rodIndex,
          ) => BarTooltipItem(
            rod.toY.round().toString(),
            TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
    ),
  );

  List<BarChartGroupData> _buildBarGroups(List<int> values, ColorScheme cs) {
    final gradient = LinearGradient(
      colors: [cs.primaryContainer, cs.primary],
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
      space: 6,
      child: Text(
        '${value.toInt() + 1}',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
