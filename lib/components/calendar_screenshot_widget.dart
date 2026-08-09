import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 番剧日历截图组件。
/// 用于生成可分享的日历图片（Bangumi 日历页的"保存图片"功能）。
class CalendarScreenshotWidget extends StatelessWidget {
  const CalendarScreenshotWidget({
    super.key,
    required this.bangumiCalendar,
    required this.captureTime,
  });

  /// 7 天（周一到周日）的番剧列表
  final List<List<BangumiItem>> bangumiCalendar;
  final DateTime captureTime;

  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _monthDayFormat = DateFormat('M月d日');

  String _weekdayName(int weekdayIndex) => switch (weekdayIndex) {
    0 => t.monday,
    1 => t.tuesday,
    2 => t.wednesday,
    3 => t.thursday,
    4 => t.friday,
    5 => t.saturday,
    6 => t.sunday,
    _ => '',
  };

  /// 安全解析播放时间（ISO 或 HH:mm），失败返回 null
  static String? _safeTimeOf(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw);
      return _timeFormat.format(dt.toLocal());
    } catch (_) {
      // 有些源给的是纯 "HH:mm" 文本
      if (raw.contains(':')) return raw.substring(0, 5);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 单日截图模式：只有一天有数据（"今日"视角）
    final isSingleDay = bangumiCalendar.where((d) => d.isNotEmpty).length == 1;
    final totalCount = bangumiCalendar.fold<int>(
      0,
      (sum, day) => sum + day.length,
    );
    final todayCount = bangumiCalendar[captureTime.weekday - 1].length;
    final activeDays = bangumiCalendar.where((d) => d.isNotEmpty).length;
    final todayIdx = captureTime.weekday - 1;
    final now = DateTime.now();
    final todayTime = _timeFormat.format(now);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 顶部标题栏 ──────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.calendar_month, size: 28, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                isSingleDay ? t.today : t.timetable,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (appdata.settings['bangumiDataVer'] != null)
                    Text(
                      'bangumi-data: ${appdata.settings['bangumiDataVer']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                  Text(
                    _dateTimeFormat.format(captureTime),
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── 统计卡片 ────────────────────────────────────────────────
          Row(
            children: [
              _StatCard(
                label: isSingleDay ? t.todayTotal : t.weekTotal,
                value: '$totalCount',
                icon: Icons.tv,
              ),
              const SizedBox(width: 12),
              if (!isSingleDay) ...[
                _StatCard(
                  label: t.todayBroadcast,
                  value: '$todayCount',
                  icon: Icons.today,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: t.broadcastDays,
                  value: '$activeDays',
                  icon: Icons.date_range,
                ),
              ] else
                _StatCard(
                  label: _monthDayFormat.format(captureTime),
                  value: _weekdayName(todayIdx),
                  icon: Icons.today,
                ),
            ],
          ),
          const SizedBox(height: 24),
          // ── 每天的列表 ──────────────────────────────────────────────
          ...List.generate(7, (weekdayIndex) {
            final dayList = bangumiCalendar[weekdayIndex];
            if (dayList.isEmpty) return const SizedBox();

            final isToday = weekdayIndex == todayIdx;
            // 计算今日已播过的条目索引（用于插入"当前时间"分割线）
            int lastPastIndex = -1;
            if (isToday) {
              for (int i = 0; i < dayList.length; i++) {
                final time = _safeTimeOf(dayList[i].airTime);
                if (time != null && time.compareTo(todayTime) < 0) {
                  lastPastIndex = i;
                }
              }
            }

            final weekday = captureTime.add(
              Duration(days: weekdayIndex - captureTime.weekday + 1),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DayHeader(
                  date: weekday,
                  weekdayName: _weekdayName(weekdayIndex),
                  count: dayList.length,
                  isToday: isToday,
                ),
                // 番剧列表（今日在当前位置插入时间分割线）
                ...List.generate(dayList.length + (isToday ? 1 : 0), (i) {
                  if (isToday && i == lastPastIndex + 1) {
                    return _NowDivider(time: todayTime);
                  }
                  final adjustedIndex = isToday && i > lastPastIndex
                      ? i - 1
                      : i;
                  if (adjustedIndex >= dayList.length) return const SizedBox();
                  return _ScreenshotBangumiRow(
                    bangumiItem: dayList[adjustedIndex],
                    isPast: isToday && adjustedIndex <= lastPastIndex,
                    showTimeDivider: false,
                  );
                }),
              ],
            );
          }),
          const Divider(height: 24),
          Center(
            child: Text(
              t.generatedBy(version: App.version),
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

/// 统计卡片
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
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
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

/// 每日日期标题（含星期、日期、条数徽章）
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.weekdayName,
    required this.count,
    required this.isToday,
  });

  final DateTime date;
  final String weekdayName;
  final int count;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = isToday ? colorScheme.onPrimaryContainer : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isToday
            ? colorScheme.primaryContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${date.month}月${date.day}日',
            style: TextStyle(fontWeight: FontWeight.bold, color: fg),
          ),
          const SizedBox(width: 8),
          Text(weekdayName, style: TextStyle(color: fg)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isToday
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: isToday
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前时间分割线（"现在"提示）
class _NowDivider extends StatelessWidget {
  const _NowDivider({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 14, color: primary),
          const SizedBox(width: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: Divider(color: primary, thickness: 1)),
        ],
      ),
    );
  }
}

/// 单条番剧行
class _ScreenshotBangumiRow extends StatelessWidget {
  const _ScreenshotBangumiRow({
    required this.bangumiItem,
    this.isPast = false,
    this.showTimeDivider = false,
  });

  final BangumiItem bangumiItem;
  final bool isPast;

  /// 与截图的"现在分割线"共存；保留参数以便未来行内细分
  final bool showTimeDivider;

  String get _episodeName {
    final cn = bangumiItem.extraInfo?.episodeNameCn;
    final name = bangumiItem.extraInfo?.episodeName ?? '';
    return (cn == null || cn.isEmpty) ? name : cn;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final airTime =
        CalendarScreenshotWidget._safeTimeOf(bangumiItem.airTime) ?? '--:--';
    // 已播出条目降低对比度，暗示"已播完"
    final opacity = isPast ? 0.55 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Padding(
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
                  color: colorScheme.primary,
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
                  bangumiItem.images['large'] ?? '',
                  sourceKey: 'bangumi',
                ),
                width: 36,
                height: 50,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stack) => Container(
                  width: 36,
                  height: 50,
                  color: colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.movie_outlined, size: 18),
                ),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.outline,
                      ),
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
      ),
    );
  }

  Widget _buildScore(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              color: colorScheme.primary,
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
                color: colorScheme.primary,
              ),
            ),
            RatingBarIndicator(
              itemCount: 5,
              rating: bangumiItem.score.toDouble() / 2,
              itemBuilder: (context, index) => const Icon(Icons.star_rounded),
              itemSize: 14,
            ),
            Text(
              t.tReviews(t: bangumiItem.total),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
