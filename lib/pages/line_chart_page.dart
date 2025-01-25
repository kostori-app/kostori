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

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      // fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    String text;
    switch (value.toInt()) {
      case 1:
        text = '1';
        break;
      case 5:
        text = '5';
        break;
      case 10:
        text = '10';
        break;
      case 15:
        text = '15';
        break;
      case 20:
        text = '20';
        break;
      case 40:
        text = '40';
        break;
      case 80:
        text = '80';
        break;
      case 160:
        text = '160';
        break;
      case 240:
        text = '240';
        break;
      case 320:
        text = '320';
        break;
      case 400:
        text = '400';
        break;
      case 480:
        text = '480';
        break;
      case 560:
        text = '560';
        break;
      default:
        return Container();
    }

    return Text(text, style: style, textAlign: TextAlign.left);
  }

  LineChartData mainData(BangumiItem bangumiItem) {
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
            interval: 1,
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
      maxY: bangumiItem.total.toDouble() * 2 / 4,
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
