import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/utils/translations.dart';

import 'package:kostori/utils/utils.dart';
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

  bool _isLoading = true; // 新增加载状态标识

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday - 1;
    controller = TabController(
        vsync: this, length: getTabs().length, initialIndex: weekday);
    _initializeData(); // 修改初始化方法
  }

  // 新增初始化方法
  Future<void> _initializeData() async {
    try {
      await filterExistingBangumiItems();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 修改后的数据过滤方法
  Future<void> filterExistingBangumiItems() async {
    try {
      // 1. 获取所有番剧数据
      final allItems = BangumiManager().getWeeks([1, 2, 3, 4, 5, 6, 7]);
      final allIds = allItems.map((item) => item.id.toString()).toList();
      final existenceMap =
          await BangumiManager().checkWhetherDataExistsBatch(allIds);

      // 2. 创建7天的空列表（周一至周日）
      final newCalendar = List.generate(7, (_) => <BangumiItem>[]);

      // 3. 遍历所有番剧，按播出时间归类
      for (final item in allItems) {
        // 跳过不存在的番剧
        if (!existenceMap.containsKey(item.id.toString())) continue;

        // 获取播出时间（优先使用existenceMap中的时间）
        final airTimeStr = existenceMap[item.id.toString()] ?? item.airTime;
        if (airTimeStr == null) continue; // 没有时间则跳过

        try {
          final airTime = DateTime.parse(airTimeStr).toLocal();

          // 直接使用DateTime的weekday属性（1=周一，7=周日）
          final weekday = airTime.weekday;

          // 添加到对应的星期组（weekday-1转换为0-based索引）
          newCalendar[weekday - 1].add(item.copyWith(airTime: airTimeStr));
        } catch (e) {
          print('解析时间失败: ${item.id}, $airTimeStr');
        }
      }

      // 4. 按播出时间排序（00:00最早 → 23:59最晚）
      for (var dayList in newCalendar) {
        dayList.sort((a, b) {
          final timeA = a.airTime;
          final timeB = b.airTime;
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1; // 空时间排后面
          if (timeB == null) return -1;
          return _parseTime(timeA).compareTo(_parseTime(timeB));
        });
      }

      // 5. 过滤空日期
      final filteredCalendar =
          newCalendar.where((day) => day.isNotEmpty).toList();

      if (mounted) {
        setState(() => bangumiCalendar = filteredCalendar);
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
            if (didPop) return;
            context.pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text('Timetable'.tl),
              bottom: TabBar(
                controller: controller,
                tabs: getTabs(),
                isScrollable: true,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            body: _buildBody(orientation), // 修改body构建方式
          ),
        );
      });
    });
  }

  Widget _buildBody(Orientation orientation) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
      child: _isLoading
          ? _buildLoadingIndicator() // 加载状态
          : renderBody(orientation), // 原始内容
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 16),
          Text('正在加载时间表数据...', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
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
    final List<Widget> listViewList = [];
    final DateTime currentTime = DateTime.now().toLocal(); // 当前本地时间
    final String currentTimeStr =
        DateFormat('HH:mm').format(currentTime); // 当前时间（HH:mm）
    final int currentWeekday = currentTime.weekday; // 当前星期几（1=周一, 7=周日）

    for (int weekday = 1; weekday <= 7; weekday++) {
      final bangumiList = bangumiCalendar[weekday - 1]; // 获取对应星期几的列表
      if (bangumiList.isEmpty) continue;

      int lastPastIndex = -1;

      // 1. 预处理：找到最后一个早于当前时间的卡片索引
      for (int i = 0; i < bangumiList.length; i++) {
        final item = bangumiList[i];
        if (item.airTime == null) continue;

        try {
          // 提取时间部分（HH:mm）
          final itemTimeStr = _extractTimeFromISO(item.airTime!);
          if (itemTimeStr.compareTo(currentTimeStr) < 0) {
            lastPastIndex = i; // 更新为最后一个符合条件的索引
          }
        } catch (e) {
          print('时间解析错误: ${item.airTime}');
        }
      }

      // 2. 计算是否需要插入横线（仅在当前日期的 Tab 中插入）
      final bool shouldInsertDivider = weekday == currentWeekday;

      listViewList.add(
        CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  // 3. 插入横线逻辑
                  if (shouldInsertDivider && index == lastPastIndex + 1) {
                    return _buildCurrentTimeDivider(currentTime);
                  }

                  // 4. 调整卡片索引
                  final adjustedIndex =
                      shouldInsertDivider && index > lastPastIndex
                          ? index - 1
                          : index;

                  // 5. 边界检查
                  if (adjustedIndex >= bangumiList.length) return null;

                  return bangumiCalendarCard(
                      context, bangumiList[adjustedIndex]);
                },
                childCount: bangumiList.isEmpty
                    ? 0
                    : (shouldInsertDivider
                        ? bangumiList.length + 1
                        : bangumiList.length),
              ),
            ),
          ],
        ),
      );
    }
    return listViewList;
  }

// 从 ISO 8601 时间中提取时间部分（HH:mm）
  String _extractTimeFromISO(String isoTime) {
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      return DateFormat('HH:mm').format(dateTime); // 提取并格式化时间部分
    } catch (e) {
      print('时间解析失败: $isoTime');
      return '00:00'; // 默认值
    }
  }

// 构建当前时间分割线
  Widget _buildCurrentTimeDivider(DateTime currentTime) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 动态计算尺寸
        final iconSize = constraints.maxWidth * 0.06; // 图标大小（基于父容器宽度）
        final textSize = constraints.maxWidth * 0.07; // 文本大小（基于父容器宽度）
        final dividerThickness = constraints.maxWidth * 0.005; // 分割线厚度（基于父容器宽度）

        return Padding(
          padding:
              const EdgeInsets.only(top: 0, left: 24, right: 24, bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: iconSize,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  DateFormat('HH:mm').format(currentTime),
                  style: TextStyle(
                    fontSize: textSize,
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Theme.of(context).colorScheme.tertiary,
                  thickness: dividerThickness,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget bangumiCalendarCard(BuildContext context, BangumiItem bangumiItem) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, left: 24, right: 24, bottom: 12),
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final height = outerConstraints.maxWidth * 8 / 16;
          return SizedBox(
            height: height,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final imageHeight = constraints.maxWidth * 6 / 16;
                  return SizedBox(
                    child:
                        _buildTimeIndicator(bangumiItem.airTime, imageHeight),
                  );
                }),
                LayoutBuilder(builder: (context, constraints) {
                  final imageHeight = constraints.maxWidth * 6 / 16;
                  final imageWidth = imageHeight * 0.72;
                  return SizedBox(
                    height: imageHeight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 图片部分
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            bangumiItem.images['large']!,
                            width: imageWidth,
                            height: imageHeight,
                            fit: BoxFit.cover,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // 信息部分
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题
                              Text(
                                bangumiItem.nameCn,
                                style: TextStyle(
                                  fontSize: imageWidth * 0.12,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bangumiItem.name,
                                style: TextStyle(
                                  fontSize: imageWidth * 0.08,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              // 评分信息
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          imageWidth * 1 / 16),
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
                                            fontSize: imageWidth * 1 / 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(4.0), // 可选，设置内边距
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          imageWidth * 1 / 16), // 设置圆角半径
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                            .toOpacity(0.72),
                                        width: 4.0, // 设置边框宽度
                                      ),
                                    ),
                                    child: Text(
                                        Utils.getRatingLabel(bangumiItem.score),
                                        style: TextStyle(
                                            fontSize: imageWidth * 1 / 10,
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
                                    itemSize: imageWidth * 1 / 10,
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Text('( ${bangumiItem.total} 人评)',
                                      style: TextStyle(
                                        fontSize: imageWidth * 1 / 10,
                                      ))
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // 时间显示组件
  Widget _buildTimeIndicator(String? rawTime, dynamic sizes) {
    if (rawTime == null || rawTime.isEmpty) return const SizedBox.shrink();

    try {
      final dateTime = DateTime.parse(rawTime).toLocal();
      final timeFormat = DateFormat('HH:mm');
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 4),
        child: Row(
          children: [
            SizedBox(
              width: 16,
            ),
            Text(
              timeFormat.format(dateTime),
              style: TextStyle(
                fontSize: sizes! * 2 / 14,
                // color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            )
          ],
        ),
      );
    } catch (e) {
      print('Invalid time format: $rawTime');
      return const SizedBox.shrink();
    }
  }
}
