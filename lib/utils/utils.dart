// ignore_for_file: non_constant_identifier_names

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:intl/intl.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../components/components.dart';
import '../foundation/app.dart';
import '../foundation/bangumi/bangumi_item.dart';
import 'io.dart';

class Utils {
  Utils._();

  static bool isDesktop() =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 850;

  static String dur2str(Duration duration) {
    return '${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(duration.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
  }

  static String durationToString(Duration duration) {
    String pad(int n) => n.toString().padLeft(2, '0');
    var hours = pad(duration.inHours % 24);
    var minutes = pad(duration.inMinutes % 60);
    var seconds = pad(duration.inSeconds % 60);
    if (hours == "00") {
      return "$minutes:$seconds";
    } else {
      return "$hours:$minutes:$seconds";
    }
  }

  static Future<String> getPlayerTempPath() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  static EpisodeInfo? findCurrentWeekEpisode(
      List<EpisodeInfo> allEpisodes, BangumiItem bangumiItem) {
    if (allEpisodes.isEmpty) return null;

    final now = DateTime.now();
    final currentWeek = getISOWeekNumber(now);
    final targetEpisodes = allEpisodes.where((e) => e.type == 0).toList();

    if (targetEpisodes.isEmpty) return null;

    // 获取番剧的标准播出时间
    String? bangumiDataAirTime =
        BangumiManager().findbangumiDataByID(bangumiItem.id);
    final bangumiAirTime = bangumiDataAirTime != null
        ? DateTime.tryParse(bangumiDataAirTime)?.toLocal()
        : null;

    // 判断是否需要调整周数（周一5点前属于上周）
    final shouldAdjustWeek = bangumiAirTime != null &&
        bangumiAirTime.weekday == DateTime.monday &&
        (bangumiAirTime.hour < 5);

    EpisodeInfo? currentWeekEpisode;
    EpisodeInfo? lastPastEpisode; // 现在会记录所有年份中最近的过去剧集
    bool foundCurrentWeekButNotAired = false;

    try {
      for (final ep in targetEpisodes) {
        try {
          final airDate = DateTime.parse(ep.airDate).toLocal();
          final (airYear, airWeekNum) = getISOWeekNumber(airDate);
          final (currentYear, currentWeekNum) = currentWeek;

          // 应用周数调整
          final adjustedWeekNum = shouldAdjustWeek
              ? (airWeekNum == 1 ? 52 : airWeekNum + 1)
              : airWeekNum;

          // 判断是否当前周但未播出
          if (airYear == currentYear && adjustedWeekNum == currentWeekNum) {
            if (airDate.isAfter(now)) {
              foundCurrentWeekButNotAired = true;
            } else {
              currentWeekEpisode ??= ep;
            }
          }

          // 记录所有年份中最接近当前日期的过去剧集
          if (airDate.isBefore(now)) {
            if (lastPastEpisode == null) {
              lastPastEpisode = ep;
            } else {
              final lastAirDate = DateTime.parse(lastPastEpisode.airDate);
              if (airDate.isAfter(lastAirDate)) {
                lastPastEpisode = ep;
              } else if (airDate.isAtSameMomentAs(lastAirDate)) {
                // 如果时间一样，优先取后面的项（即覆盖）
                lastPastEpisode = ep;
              }
            }
          }
        } catch (e) {
          // Log.addLog(LogLevel.warning, 'dateParse', '解析日期失败: ${ep.airDate}');
        }
      }

      // 优先级逻辑：
      // 1. 当前周已播出的剧集
      // 2. 如果当前周有剧集但未播出，返回最近的过去剧集（不限年份）
      // 3. 没有则返回null
      return currentWeekEpisode ??
          (foundCurrentWeekButNotAired ? lastPastEpisode : lastPastEpisode);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'findCurrentWeekEpisode', '$e\n$s');
      return null;
    }
  }

  static String getRandomUA() {
    final random = Random();
    String randomElement =
        userAgentsList[random.nextInt(userAgentsList.length)];
    return randomElement;
  }

  // 日期字符串转换为 weekday (eg: 2024-09-23 -> 1 (星期一))
  static int dateStringToWeekday(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return date.weekday;
    } catch (_) {
      return 1;
    }
  }

  // 格式化为 "yyyy-MM-dd"
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// 安全解析日期，支持以下格式：
  /// - null → 返回 null
  /// - "2099" → 解析为 2099-01-01
  /// - "2099-1" → 解析为 2099-01-01
  /// - "2099-1-20" → 解析为 2099-01-20
  /// - "2099-01-20" → 标准解析
  static DateTime? safeParseDate(String? dateStr) {
    if (dateStr == null) return null;

    try {
      // 支持中文格式，如 "2016年1月13日"
      final zhDateReg = RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日$');
      final zhMatch = zhDateReg.firstMatch(dateStr);
      if (zhMatch != null) {
        final year = int.parse(zhMatch.group(1)!);
        final month = int.parse(zhMatch.group(2)!);
        final day = int.parse(zhMatch.group(3)!);
        return DateTime(year, month, day);
      }

      // 处理纯年份（如 "2099"）
      if (RegExp(r'^\d{4}$').hasMatch(dateStr)) {
        return DateTime(int.parse(dateStr));
      }

      // 处理带分隔符的日期（兼容 - / 等分隔符 和不带前导零的数字）
      final parts = dateStr.split(RegExp(r'[-/]'));
      if (parts.isNotEmpty && parts.length <= 3) {
        final year = int.parse(parts[0]);
        final month = parts.length >= 2 ? int.parse(parts[1]) : 1;
        final day = parts.length >= 3 ? int.parse(parts[2]) : 1;
        return DateTime(year, month, day);
      }

      // 尝试标准解析（兜底）
      return DateTime.parse(dateStr).toLocal();
    } catch (e) {
      // Log.addLog(LogLevel.warning, 'parseDate', '日期解析失败: $dateStr\n$e');
      return null;
    }
  }

  /// 获取完整的 ISO 周信息 (year, weekNumber)
  /// 符合 ISO 8601 标准（周一到周日为一周，跨年周归属取决于周四所在的年份）
  static (int year, int week) getISOWeekNumber(DateTime date) {
    // 原始计算逻辑（优化版）
    final dayOfYear = int.parse(DateFormat("D").format(date));
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();

    // === 处理跨年周的特殊情况 ===
    DateTime thursday;

    // 计算本周的周四（ISO 标准以周四所在年份决定周归属）
    if (date.weekday <= DateTime.thursday) {
      thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    } else {
      thursday =
          date.subtract(Duration(days: date.weekday - DateTime.thursday));
    }

    // 如果计算的周数超出合理范围（1-53），调整年份
    if (weekNumber < 1) {
      // 属于前一年的最后一周（52或53周）
      final prevYearLastWeek =
          getISOWeekNumber(DateTime(date.year - 1, 12, 28) // 12月28日肯定在最后一周
              );
      return (date.year - 1, prevYearLastWeek.$2);
    } else if (weekNumber > 52) {
      // 检查是否真的有53周（某些年份有53周）
      final dec28 = DateTime(date.year, 12, 28);
      final weekOfDec28 =
          ((int.parse(DateFormat("D").format(dec28)) - dec28.weekday + 10) ~/
              7);

      if (weekNumber > weekOfDec28) {
        // 属于下一年的第一周
        return (date.year + 1, 1);
      }
    }

    // 正常情况返回
    return (thursday.year, weekNumber);
  }

  /// 获取标准格式的ISO周编号（如 "2023-W05"）
  static String getISOWeekString(DateTime date) {
    final (year, week) = getISOWeekNumber(date);
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  static String getRatingLabel(num score) {
    // 将评分四舍五入为整数
    int roundedScore = score.round();
    // 确保评分在 1 到 10 的范围内
    roundedScore = roundedScore.clamp(1, 10);

    // 返回对应的标签
    return ratingLabels[roundedScore] ?? '暂无';
  }

  // 时间显示，刚刚，x分钟前
  static String dateFormat(timeStamp, {formatType = 'list'}) {
    // 当前时间
    int time = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    // 对比
    int distance = (time - timeStamp).toInt();
    // 当前年日期
    String currentYearStr = 'MM月DD日 hh:mm';
    String lastYearStr = 'YY年MM月DD日 hh:mm';
    if (formatType == 'detail') {
      currentYearStr = 'MM-DD hh:mm';
      lastYearStr = 'YY-MM-DD hh:mm';
      return CustomStamp_str(
          timestamp: timeStamp,
          date: lastYearStr,
          toInt: false,
          formatType: formatType);
    }
    if (distance <= 60) {
      return '刚刚';
    } else if (distance <= 3600) {
      return '${(distance / 60).floor()}分钟前';
    } else if (distance <= 43200) {
      return '${(distance / 60 / 60).floor()}小时前';
    } else if (DateTime.fromMillisecondsSinceEpoch(time * 1000).year ==
        DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000).year) {
      return CustomStamp_str(
          timestamp: timeStamp,
          date: currentYearStr,
          toInt: false,
          formatType: formatType);
    } else {
      return CustomStamp_str(
          timestamp: timeStamp,
          date: lastYearStr,
          toInt: false,
          formatType: formatType);
    }
  }

  // 时间戳转时间
  static String CustomStamp_str(
      {int? timestamp, // 为空则显示当前时间
      String? date, // 显示格式，比如：'YY年MM月DD日 hh:mm:ss'
      bool toInt = true, // 去除0开头
      String? formatType}) {
    timestamp ??= (DateTime.now().millisecondsSinceEpoch / 1000).round();
    String timeStr =
        (DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)).toString();

    dynamic dateArr = timeStr.split(' ')[0];
    dynamic timeArr = timeStr.split(' ')[1];

    String YY = dateArr.split('-')[0];
    String MM = dateArr.split('-')[1];
    String DD = dateArr.split('-')[2];

    String hh = timeArr.split(':')[0];
    String mm = timeArr.split(':')[1];
    String ss = timeArr.split(':')[2];

    ss = ss.split('.')[0];

    // 去除0开头
    if (toInt) {
      MM = (int.parse(MM)).toString();
      DD = (int.parse(DD)).toString();
      hh = (int.parse(hh)).toString();
      mm = (int.parse(mm)).toString();
    }

    if (date == null) {
      return timeStr;
    }

    // if (formatType == 'list' && int.parse(DD) > DateTime.now().day - 2) {
    //   return '昨天';
    // }

    date = date
        .replaceAll('YY', YY)
        .replaceAll('MM', MM)
        .replaceAll('DD', DD)
        .replaceAll('hh', hh)
        .replaceAll('mm', mm)
        .replaceAll('ss', ss);
    if (int.parse(YY) == DateTime.now().year &&
        int.parse(MM) == DateTime.now().month) {
      // 当天
      if (int.parse(DD) == DateTime.now().day) {
        return '今天';
      }
    }
    return date;
  }

  static String buildShadersAbsolutePath(
      String baseDirectory, List<String> shaders) {
    List<String> absolutePaths = shaders.map((shader) {
      return path.join(baseDirectory, shader);
    }).toList();
    if (Platform.isWindows) {
      return absolutePaths.join(';');
    }
    return absolutePaths.join(':');
  }

  //时间转换HH:mm显示
  static Widget buildTimeIndicator(String? rawTime, dynamic sizes) {
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
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'Invalid time format', '$rawTime\n$e\n$s');
      return const SizedBox.shrink();
    }
  }

  //标准差
  static double getDeviation(
      dynamic total, List<dynamic> count, dynamic score) {
    if (total == 0 || count.isEmpty) return 0;

    final scores = count.reversed.toList(); // 反转评分列表（从10分到1分）
    return calculateSD(
        scores, double.parse(score.toString()), double.parse(total.toString()));
  }

  /// 计算标准差
  static double calculateSD(List<dynamic> scores, double score, double n) {
    double sd = 0;
    for (var i = 0; i < scores.length; i++) {
      final item = scores[i];
      if (item == 0) continue;
      sd += (10 - i - score) * (10 - i - score) * item;
    }
    return sqrt(sd / n);
  }

  /// 根据标准差数值返回争议程度的标签
  static String getDispute(double deviation) {
    if (deviation == 0) return '-';
    if (deviation < 1) return '异口同声';
    if (deviation < 1.15) return '基本一致';
    if (deviation < 1.3) return '略有分歧';
    if (deviation < 1.45) return '莫衷一是';
    if (deviation < 1.6) return '各执一词';
    if (deviation < 1.75) return '你死我活';
    return '厨黑大战';
  }

  static String readType(type) {
    switch (type) {
      case 0:
        return 'ep';
      case 1:
        return 'sp';
      case 2:
        return 'op';
      case 3:
        return 'ed';
      default:
        return '';
    }
  }

  static Future<void> saveLongImage(
      BuildContext context, Uint8List imageData) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      if (App.isAndroid) {
        final folder = await KostoriFolder.checkPermissionAndPrepareFolder();
        if (folder != null) {
          final file = File('${folder.path}/拼图_$timestamp.png');
          await file.writeAsBytes(imageData);

          // 调用弹窗/提示等
          showCenter(
            seconds: 1,
            icon: Gif(
              image: const AssetImage('assets/img/check.gif'),
              height: 80,
              fps: 120,
              color: Theme.of(context).colorScheme.primary,
              autostart: Autostart.once,
            ),
            message: '保存成功',
            context: context,
          );

          Log.addLog(LogLevel.info, '保存长图成功', file.path);
        } else {
          Log.addLog(LogLevel.error, '保存失败：权限或目录异常', '');
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final folderPath = '${directory.path}/Kostori';
        final folder = Directory(folderPath);
        if (!await folder.exists()) {
          await folder.create(recursive: true);
          Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
        } else {
          Log.addLog(LogLevel.info, '文件夹已存在', folderPath);
        }

        final filePath = '$folderPath/拼图_$timestamp.png';
        final file = File(filePath);
        await file.writeAsBytes(imageData);

        showCenter(
          seconds: 1,
          icon: Gif(
            image: const AssetImage('assets/img/check.gif'),
            height: 80,
            fps: 120,
            color: Theme.of(context).colorScheme.primary,
            autostart: Autostart.once,
          ),
          message: '保存成功',
          context: context,
        );

        Log.addLog(LogLevel.info, '保存长图成功', filePath);
      }
    } catch (e) {
      Log.addLog(LogLevel.error, '保存长图失败', '$e');
    }
  }
}

const List<String> userAgentsList = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36 Edg/127.0.0.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.1',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
];
