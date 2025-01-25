import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi.dart';

import '../utils/utils.dart';
import 'bangumi/bangumi_item.dart';

class BangumiCalendarPage extends StatefulWidget {
  const BangumiCalendarPage({super.key});

  @override
  State<BangumiCalendarPage> createState() => _BangumiCalendarPageState();
}

class _BangumiCalendarPageState extends State<BangumiCalendarPage>
    with SingleTickerProviderStateMixin {
  TabController? controller;

  List<List<BangumiItem>> bangumiCalendar = [];

  @override
  void initState() {
    int weekday = DateTime.now().weekday - 1;
    controller = TabController(
        vsync: this, length: getTabs().length, initialIndex: weekday);
    getTabs();
    filterExistingBangumiItems();
    super.initState();
  }

  Future<void> filterExistingBangumiItems() async {
    List<List<BangumiItem>> filteredWeek = [];

    for (int weekday = 1; weekday <= 7; weekday++) {
      // 获取当天的Bangumi列表
      List<BangumiItem> dayList = BangumiManager().getWeek(weekday);

      // 使用 Future.wait 来并发检查每个 item 是否存在
      var filteredDay = await Future.wait(
        dayList.map((item) async {
          bool exists = await BangumiManager().checkWhetherDataExists(item.id);
          return exists ? item : null; // 返回 null 表示该项不在数据库中
        }),
      ).then((list) => list.whereType<BangumiItem>().toList()); // 移除 null 项

      // 只将非空列表添加到 filteredWeek
      if (filteredDay.isNotEmpty) {
        filteredWeek.add(filteredDay);
      }
    }

    // 更新状态，设置过滤后的数据
    setState(() {
      bangumiCalendar = filteredWeek;
    });
  }

  /// 星期列表
  List<Tab> tabs = const <Tab>[];

  // 获取当前日期并生成星期和日期标签
  List<Tab> getTabs() {
    DateTime currentDate = DateTime.now();
    List<Tab> tabs = [];
    for (int i = 0; i < 7; i++) {
      DateTime weekday = currentDate
          .add(Duration(days: i - currentDate.weekday + 1)); // 当前周的日期
      String formattedDate = '${weekday.month}月${weekday.day}日'; // 格式化日期
      String dayOfWeek = '';

      switch (weekday.weekday) {
        case 1:
          dayOfWeek = '周一';
          break;
        case 2:
          dayOfWeek = '周二';
          break;
        case 3:
          dayOfWeek = '周三';
          break;
        case 4:
          dayOfWeek = '周四';
          break;
        case 5:
          dayOfWeek = '周五';
          break;
        case 6:
          dayOfWeek = '周六';
          break;
        case 7:
          dayOfWeek = '周日';
          break;
      }

      tabs.add(
        Tab(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formattedDate,
                style: TextStyle(fontWeight: FontWeight.bold), // 日期样式
              ),
              Text(
                dayOfWeek,
                style: TextStyle(fontWeight: FontWeight.normal), // 星期样式
              ),
            ],
          ),
        ),
      );
    }
    return tabs;
  }

  /// 今天
  int get today => DateTime.now().weekday - 1;

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      return Observer(builder: (context) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) {
              return;
            }
            context.pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text('新番时间表'),
              bottom: TabBar(
                controller: controller,
                tabs: getTabs(),
                isScrollable: true,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            body: Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
                child: renderBody(orientation)),
          ),
        );
      });
    });
  }

  Widget renderBody(Orientation orientation) {
    if (bangumiCalendar.isNotEmpty) {
      return TabBarView(
        controller: controller,
        children: contentList(bangumiCalendar, orientation),
      );
    } else {
      return const Center(
        child: Text('数据还没有更新 (´;ω;`)'),
      );
    }
  }

  List<Widget> contentList(
      List<List<BangumiItem>> bangumiCalendar, Orientation orientation) {
    List<Widget> listViewList = [];

    for (var bangumiList in bangumiCalendar) {
      listViewList.add(
        CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  return bangumiList.isNotEmpty
                      ? bangumiCalendarCard(context, bangumiList[index])
                      : null;
                },
                childCount: bangumiList.isNotEmpty ? bangumiList.length : 10,
              ),
            ),
          ],
        ),
      );
    }
    return listViewList;
  }

  Widget bangumiCalendarCard(BuildContext context, BangumiItem bangumiItem) {
    return Padding(
      padding: EdgeInsets.only(top: 24, left: 24, right: 24),
      child: LayoutBuilder(builder: (context, constrains) {
        double height = constrains.maxWidth * (App.isDesktop ? 6 / 16 : 6 / 16);
        double width = height * 0.72;
        return Container(
          height: height,
          width: width,
          padding: EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12), // 设置圆角半径
                child: Image.network(
                  bangumiItem.images['large']!,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(
                width: 20,
              ),
              Expanded(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bangumiItem.nameCn,
                    style: TextStyle(
                        fontSize: width * 1.5 / 10,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(bangumiItem.name,
                      style: TextStyle(fontSize: width * 1 / 10)),
                  Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(width * 1 / 16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .toOpacity(0.72),
                            width: 4.0, // 设置边框宽度
                          ),
                        ),
                        child: Text('#${bangumiItem.rank}',
                            style: TextStyle(
                                fontSize: width * 1 / 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      Container(
                        padding: EdgeInsets.all(4.0), // 可选，设置内边距
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(width * 1 / 16), // 设置圆角半径
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .toOpacity(0.72),
                            width: 4.0, // 设置边框宽度
                          ),
                        ),
                        child: Text(Utils.getRatingLabel(bangumiItem.score),
                            style: TextStyle(
                                fontSize: width * 1 / 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      RatingBarIndicator(
                        itemCount: 5,
                        rating: bangumiItem.score.toDouble() / 2,
                        itemBuilder: (context, index) => const Icon(
                          Icons.star_rounded,
                        ),
                        itemSize: width * 1 / 10,
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      Text('( ${bangumiItem.total} 人评)',
                          style: TextStyle(
                            fontSize: width * 1 / 10,
                          ))
                    ],
                  ),
                ],
              ))
            ],
          ),
        );
      }),
    );
  }
}
