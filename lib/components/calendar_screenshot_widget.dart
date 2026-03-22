import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/utils/translations.dart';

class CalendarScreenshotWidget extends StatelessWidget {
  const CalendarScreenshotWidget({
    super.key,
    required this.bangumiCalendar,
    required this.captureTime,
  });

  final List<List<BangumiItem>> bangumiCalendar;
  final DateTime captureTime;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final isToday = bangumiCalendar.where((d) => d.isNotEmpty).length == 1;
    final totalCount = bangumiCalendar.fold<int>(
      0,
      (sum, day) => sum + day.length,
    );
    final todayCount = bangumiCalendar[captureTime.weekday - 1].length;
    final activeDays = bangumiCalendar.where((d) => d.isNotEmpty).length;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部标题栏
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 28),
              const SizedBox(width: 12),
              Text(
                isToday ? 'Today'.tl : 'Timetable'.tl,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Column(
                children: [
                  if (appdata.settings['bangumiDataVer'] != null)
                    Text(
                      'bangumi-data: ${appdata.settings['bangumiDataVer']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(captureTime),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 统计卡片
          Row(
            children: [
              _StatCard(
                label: isToday ? '今日总计' : '本周总计',
                value: '$totalCount',
                icon: Icons.tv,
              ),
              const SizedBox(width: 12),
              if (!isToday) ...[
                _StatCard(
                  label: '今日播出',
                  value: '$todayCount',
                  icon: Icons.today,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: '播出天数',
                  value: '$activeDays',
                  icon: Icons.date_range,
                ),
              ] else
                _StatCard(
                  label: DateFormat('MM月dd日').format(captureTime),
                  value: _weekdays[captureTime.weekday - 1].tl,
                  icon: Icons.today,
                ),
            ],
          ),
          const SizedBox(height: 24),
          // 每天的列表
          ...List.generate(7, (weekdayIndex) {
            final dayList = bangumiCalendar[weekdayIndex];
            if (dayList.isEmpty) return const SizedBox();

            final now = DateTime.now();
            final weekday = now.add(
              Duration(days: weekdayIndex - now.weekday + 1),
            );
            final isToday = weekdayIndex == captureTime.weekday - 1;
            final currentTimeStr = DateFormat('HH:mm').format(now);
            int lastPastIndex = -1;
            if (isToday) {
              for (int i = 0; i < dayList.length; i++) {
                final item = dayList[i];
                if (item.airTime == null) continue;
                try {
                  final t = DateFormat(
                    'HH:mm',
                  ).format(DateTime.parse(item.airTime!).toLocal());
                  if (t.compareTo(currentTimeStr) < 0) lastPastIndex = i;
                } catch (_) {}
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 日期标题
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${weekday.month}月${weekday.day}日',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _weekdays[weekdayIndex].tl,
                        style: TextStyle(
                          color: isToday
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${dayList.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 番剧列表
                ...List.generate(dayList.length + (isToday ? 1 : 0), (i) {
                  if (isToday && i == lastPastIndex + 1) {
                    // 当前时间分割线
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            currentTimeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).colorScheme.primary,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final adjustedIndex = isToday && i > lastPastIndex
                      ? i - 1
                      : i;
                  if (adjustedIndex >= dayList.length) return const SizedBox();
                  return _ScreenshotBangumiRow(
                    bangumiItem: dayList[adjustedIndex],
                  );
                }),
              ],
            );
          }),
          const Divider(height: 24),
          Center(
            child: Text(
              'Generated by Kostori v${App.version}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotBangumiRow extends StatelessWidget {
  const _ScreenshotBangumiRow({required this.bangumiItem});

  final BangumiItem bangumiItem;

  String get _episodeName {
    final cn = bangumiItem.extraInfo?.episodeNameCn;
    final name = bangumiItem.extraInfo?.episodeName ?? '';
    return (cn == null || cn.isEmpty) ? name : cn;
  }

  @override
  Widget build(BuildContext context) {
    final airTime = bangumiItem.airTime != null
        ? DateFormat(
            'HH:mm',
          ).format(DateTime.parse(bangumiItem.airTime!).toLocal())
        : '--:--';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // 时间
          SizedBox(
            width: 48,
            child: Text(
              airTime,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image(
              image: CachedImageProvider(
                bangumiItem.images['large']!,
                sourceKey: 'bangumi',
              ),
              width: 36,
              height: 50,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 12),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bangumiItem.nameCn.isNotEmpty
                      ? bangumiItem.nameCn
                      : bangumiItem.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (appdata.settings['calendarFetchEpisodes'] ?? false)
                  Text(
                    'EP ${bangumiItem.extraInfo?.episodeEp?.toCleanString() ?? '-'} $_episodeName',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // 评分
          _buildScore(context),
        ],
      ),
    );
  }

  Widget _buildScore(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (bangumiItem.total >= 20) ...[
          Text(
            '${bangumiItem.score}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '#${bangumiItem.rank}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            RatingBarIndicator(
              itemCount: 5,
              rating: bangumiItem.score.toDouble() / 2,
              itemBuilder: (context, index) => const Icon(Icons.star_rounded),
              itemSize: 14,
            ),
            Text(
              '@t reviews'.tlParams({'t': bangumiItem.total}),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
