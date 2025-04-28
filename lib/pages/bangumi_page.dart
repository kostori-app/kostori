import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/pages/bangumi/bangumi_item.dart';
import 'package:kostori/utils/translations.dart';

import 'bangumi_calendar_page.dart';

class BangumiPage extends StatefulWidget {
  const BangumiPage({super.key});

  @override
  State<BangumiPage> createState() => _BangumiPageState();
}

class _BangumiPageState extends State<BangumiPage> {
  @override
  Widget build(BuildContext context) {
    var widget = SmoothCustomScrollView(slivers: [
      SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
      const _Timetable(),
    ]);
    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
  }
}

class _Timetable extends StatefulWidget {
  const _Timetable();

  @override
  State<_Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<_Timetable> {
  late int count;

  List<BangumiItem> bangumiCalendar = [];

  late int weekday;

  @override
  void initState() {
    weekday = DateTime.now().weekday;
    // 异步加载数据
    filterExistingBangumiItems();
    BangumiManager().addListener(onHistoryChange);
    super.initState();
  }

  @override
  void dispose() {
    BangumiManager().removeListener(onHistoryChange);
    super.dispose();
  }

  Future<void> filterExistingBangumiItems() async {
    try {
      // 1. 获取当前星期几 (1=周一, 7=周日)
      final currentWeekday = DateTime.now().weekday;

      // 2. 获取所有番剧数据
      final allItems = BangumiManager().getWeeks([1, 2, 3, 4, 5, 6, 7]);
      final allIds = allItems.map((item) => item.id.toString()).toList();
      final existenceMap =
          await BangumiManager().checkWhetherDataExistsBatch(allIds);

      // 3. 过滤并处理今日番剧
      final todayItems = <BangumiItem>[];

      for (final item in allItems) {
        // 跳过不存在的番剧
        if (!existenceMap.containsKey(item.id.toString())) continue;

        // 获取播出时间（优先使用existenceMap中的时间）
        final airTimeStr = existenceMap[item.id.toString()] ?? item.airTime;
        if (airTimeStr == null) continue; // 没有时间则跳过

        try {
          final airTime = DateTime.parse(airTimeStr).toLocal();

          // 验证星期几是否匹配当前日
          if (airTime.weekday == currentWeekday) {
            todayItems.add(item.copyWith(airTime: airTimeStr));
          }
        } catch (e) {
          print('解析时间失败: ${item.id}, $airTimeStr');
        }
      }

      // 4. 按播出时间排序（00:00最早 → 23:59最晚）
      todayItems.sort((a, b) {
        final timeA = a.airTime;
        final timeB = b.airTime;
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1; // 空时间排后面
        if (timeB == null) return -1;
        return _parseTime(timeA).compareTo(_parseTime(timeB));
      });

      // 5. 更新状态
      if (mounted) {
        setState(() => bangumiCalendar = todayItems);
      }
    } catch (e) {
      print("Error processing bangumi calendar: $e");
      if (mounted) setState(() => bangumiCalendar = []);
    }
  }

// 辅助方法：解析时间用于排序
  DateTime _parseTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return DateTime(2000, 1, 1, dt.hour, dt.minute); // 仅比较时分
    } catch (e) {
      return DateTime(2000, 1, 1); // 解析失败默认值
    }
  }

  String getWeekdayString(int weekday) {
    const weekdays = [
      '周一时间表',
      '周二时间表',
      '周三时间表',
      '周四时间表',
      '周五时间表',
      '周六时间表',
      '周日时间表'
    ];
    return weekdays[weekday - 1];
  }

  void onHistoryChange() {
    setState(() {
      filterExistingBangumiItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
        child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.6,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                App.mainNavigatorKey?.currentContext
                    ?.to(() => BangumiCalendarPage());
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Center(
                        child: Text(getWeekdayString(weekday), style: ts.s18),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${bangumiCalendar.length}', style: ts.s12),
                      ),
                      const Spacer(),
                      const Icon(Icons.calendar_month),
                      SizedBox(
                        width: 10,
                      ),
                      Text('Timetable'.tl)
                    ],
                  ),
                ).paddingHorizontal(16),
                SizedBox(
                  height: 384,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: bangumiCalendar.length,
                    itemBuilder: (BuildContext context, int index) {
                      return BangumiCard(anime: bangumiCalendar[index])
                          .paddingHorizontal(8)
                          .paddingVertical(2);
                    },
                  ).paddingHorizontal(8).paddingVertical(16),
                ),
              ]),
            )));
  }
}
