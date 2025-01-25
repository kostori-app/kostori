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
    filterExistingBangumiItems(weekday);
    BangumiManager().addListener(onHistoryChange);
    super.initState();
  }

  @override
  void dispose() {
    BangumiManager().removeListener(onHistoryChange);
    super.dispose();
  }

  Future<void> filterExistingBangumiItems(int weekday) async {
    // 获取并筛选数据
    var filteredList = await Future.wait(
      BangumiManager().getWeek(weekday).map((item) async {
        bool exists = await BangumiManager().checkWhetherDataExists(item.id);
        return exists ? item : null;
      }),
    ).then((list) => list.whereType<BangumiItem>().toList());

    // 更新状态
    setState(() {
      bangumiCalendar = filteredList;
    });
  }

  void onHistoryChange() {
    setState(() {
      filterExistingBangumiItems(weekday);
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
                App.rootContext.to(() => BangumiCalendarPage());
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Center(
                        child: Text('Timetable'.tl, style: ts.s18),
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
                      const Icon(Icons.arrow_right),
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
