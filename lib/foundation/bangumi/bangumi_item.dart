import 'dart:convert';

import 'package:kostori/foundation/bangumi/bangumi_tag.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/utils/utils.dart';
import 'package:sqlite3/sqlite3.dart';

class BangumiItem {
  int id;

  int type;

  String name;

  String nameCn;

  String summary;

  String airDate;

  int airWeekday;

  int rank;

  int total;

  int totalEpisodes;

  num score;

  String? airTime;

  Map<String, int>? count;

  Map<String, int>? collection;

  Map<String, String> images;

  List<BangumiTag> tags;

  List<String>? alias;

  EpisodeResult? extraInfo;

  BangumiItem({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.airWeekday,
    required this.rank,
    required this.total,
    required this.totalEpisodes,
    required this.score,
    this.count,
    this.collection,
    this.airTime,
    required this.images,
    required this.tags,
    this.alias,
    this.extraInfo,
  });

  BangumiItem.fromRow(Row row)
    : id = row["id"],
      type = row["type"],
      name = row["name"],
      nameCn = row["nameCn"],
      summary = row["summary"],
      airDate = row["airDate"],
      airWeekday = row["airWeekday"],
      rank = row["rank"],
      total = row["total"],
      totalEpisodes = row["totalEpisodes"] ?? 0,
      score = row["score"],
      // 转为 double
      count = row["count"] == null
          ? null
          : Map<String, int>.from(jsonDecode(row["count"])),
      // 转为 Map<String, int>
      collection = row["collection"] == null
          ? null
          : Map<String, int>.from(jsonDecode(row["collection"])),
      // 转为 Map<String, int>
      images = Map<String, String>.from(jsonDecode(row["images"])),
      // 转为 Map<String, String>
      tags = row["tags"] == null
          ? []
          : (row["tags"] is String)
          ? (json.decode(row["tags"]) as List)
                .map((tag) => BangumiTag.fromJson(tag))
                .toList()
          : (row["tags"]).map((tag) => BangumiTag.fromJson(tag)).toList()
                as List<BangumiTag>,
      alias = row['alias'] != null
          ? (json.decode(row['alias']) as List).cast<String>()
          : [];

  static String? extractDateFromInfo(String? info) {
    if (info == null || info.isEmpty) return null;

    // 使用正则表达式匹配 "XXXX年XX月XX日" 格式
    final dateRegex = RegExp(r'\d{4}年\d{1,2}月\d{1,2}日');
    final match = dateRegex.firstMatch(info);

    return match?.group(0); // 返回匹配到的第一个日期字符串
  }

  /// 兼容名称字段为字符串或多语言 Map（如 {"zh-hans":["穹顶下的魔女"]}）
  static String _nameString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) {
      // 优先取简体中文
      for (final key in ['zh-hans', 'zh-Hans', 'zh-CN', 'zh_cn', 'zhHans']) {
        final val = v[key];
        if (val is String && val.isNotEmpty) return val;
        if (val is List && val.isNotEmpty && val.first is String) {
          return val.first as String;
        }
        if (val is Map) {
          final nested = _nameString(val);
          if (nested.isNotEmpty) return nested;
        }
      }
      // 兜底：任一非空字符串值（递归处理嵌套 Map）
      for (final val in v.values) {
        if (val is String && val.isNotEmpty) return val;
        if (val is List && val.isNotEmpty && val.first is String) {
          return val.first as String;
        }
        if (val is Map) {
          final nested = _nameString(val);
          if (nested.isNotEmpty) return nested;
        }
      }
      // 完全取不到可读名称时返回空串，避免把原始 JSON 当标题展示
      return '';
    }
    return v.toString();
  }

  factory BangumiItem.fromJson(Map<String, dynamic> json) {
    List<String> parseBangumiAliases(Map<String, dynamic> jsonData) {
      if (jsonData.containsKey('infobox') && jsonData['infobox'] is List) {
        final List<dynamic> infobox = jsonData['infobox'];
        for (var item in infobox) {
          if (item is Map<String, dynamic> && item['key'] == '别名') {
            final dynamic value = item['value'];
            if (value is List) {
              return value
                  .map<String>((element) {
                    if (element is Map<String, dynamic> &&
                        element.containsKey('v')) {
                      return element['v'].toString();
                    }
                    return '';
                  })
                  .where((alias) => alias.isNotEmpty)
                  .toList();
            }
          }
        }
      }
      return [];
    }

    List list = json['tags'] ?? [];
    List<BangumiTag> tagList = list.map((i) => BangumiTag.fromJson(i)).toList();
    List<String> bangumiAlias = parseBangumiAliases(json);

    return BangumiItem(
      id: json['id'],
      type: json['type'] ?? 2,
      name: _nameString(json['name']),
      nameCn: _nameString(json['name_cn'] ?? json['nameCN']) == ''
          ? _nameString(json['name'])
          : _nameString(json['name_cn'] ?? json['nameCN']),
      summary: json['summary'] ?? '',
      airDate:
          json['air_date'] ??
          json['date'] ??
          json['airtime']?['date'] ??
          extractDateFromInfo(json['info']) ??
          '2077',
      airWeekday:
          json['air_weekday'] ??
          (json['date'] == null ? 1 : Utils.dateStringToWeekday(json['date'])),
      // 修改这一行，使用安全访问操作符检查 json['rating']
      rank: json['rating']?['rank'] ?? json['rank'] ?? 0,
      total: json['rating']?['total'] ?? json['total'] ?? 0,
      score: json['rating']?['score'] ?? json['score'] ?? 0.0,
      images: Map<String, String>.from(
        json['images'] ??
            {
              "large": json['image'] ?? '',
              "common": '',
              "medium": '',
              "small": '',
              "grid": '',
            },
      ),
      tags: tagList,
      alias: bangumiAlias,
      totalEpisodes: json['total_episodes'] ?? json['eps'] ?? 0,
      count: (() {
        final rawCount = json['rating']?['count'];
        if (rawCount is Map) {
          return rawCount.map(
            (key, value) => MapEntry(key.toString(), value as int),
          );
        } else if (rawCount is List) {
          return {
            for (int i = 0; i < rawCount.length; i++)
              '${i + 1}': rawCount[i] as int,
          };
        } else {
          return <String, int>{};
        }
      })(),
      collection: Map<String, int>.from(json['collection'] ?? {}),
      // collection: Map<String, int>.from(json['collection']),
    );
  }

  BangumiItem copyWith({
    int? id,
    String? nameCn,
    String? name,
    Map<String, String>? images,
    int? rank,
    double? score,
    int? total,
    int? airWeekday,
    String? airTime,
    int? type,
    String? summary,
    String? airDate,
    int? totalEpisodes,
    List<BangumiTag>? tags,
    List<String>? alias,
    EpisodeResult? extraInfo,
  }) {
    return BangumiItem(
      id: id ?? this.id,
      nameCn: nameCn ?? this.nameCn,
      name: name ?? this.name,
      images: images ?? this.images,
      rank: rank ?? this.rank,
      score: score ?? this.score,
      total: total ?? this.total,
      airWeekday: airWeekday ?? this.airWeekday,
      airTime: airTime ?? this.airTime,
      type: type ?? this.type,
      summary: summary ?? this.summary,
      airDate: airDate ?? this.airDate,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      tags: tags ?? this.tags,
      alias: alias ?? this.alias,
      extraInfo: extraInfo ?? this.extraInfo,
    );
  }

  @override
  String toString() {
    return 'BangumiItem{id: $id, type: $type, name: $name, nameCn: $nameCn, summary: $summary, airDate: $airDate, airWeekday: $airWeekday, rank: $rank, total: $total, score: $score, totalEpisodes: $totalEpisodes, count: $count, collection: $collection, images: $images, tags: $tags, alias: $alias}';
  }

  /// 卡片列表封面：优先 large 高清档（medium 太糊看不清），API 缺该档时逐级回退
  String get cardImage {
    for (final k in const ['large', 'common', 'medium', 'small', 'grid']) {
      final u = images[k];
      if (u != null && u.isNotEmpty) return u;
    }
    return '';
  }
}

class EpisodeResult {
  final String? episodeAirdate;
  final String? episodeName;
  final String? episodeNameCn;
  final double? episodeEp;
  final bool isCurrentWeek;
  final bool isFinalEpisode;
  final bool hasNextEpisodes;

  /// 是否已完结（应从时间表剔除），播出后仍保留 [finishGraceDays] 天。
  final bool isFinished;

  const EpisodeResult({
    this.episodeAirdate,
    this.episodeName,
    this.episodeNameCn,
    this.episodeEp,
    required this.isCurrentWeek,
    required this.isFinalEpisode,
    required this.hasNextEpisodes,
    required this.isFinished,
  });

  /// 刚完结后仍保留的天数（按自然日）。
  static const int finishGraceDays = 3;

  /// end 与总话数都拿不到时，末话距今超过这么多天即视为早已完结。
  static const int staleEpisodeDays = 21;

  /// 完结日是否已超出宽限期。
  static bool isFinishedDate(DateTime? date, DateTime now) {
    if (date == null) return false;
    final day = DateTime(date.year, date.month, date.day);
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: finishGraceDays));
    return day.isBefore(cutoff);
  }

  /// 无剧集信息时根据 end 字段判断是否完结。
  factory EpisodeResult.fromEndDate(String? endDateStr) {
    final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
    final hasEnded = isFinishedDate(endDate, DateTime.now());
    return EpisodeResult(
      isCurrentWeek: !hasEnded,
      isFinalEpisode: hasEnded,
      hasNextEpisodes: !hasEnded,
      isFinished: hasEnded,
    );
  }

  bool get shouldSkip => isFinished;
}

/// 根据剧集信息判断当前话与完结状态。[seriesTotal] 为系列总话数（未知传 0）。
/// bgm 剧集列表常只到已播出的最新一话，故须末话集数达到总话数才算完结。
/// [officialEnd] 为 bangumi-data 的官方完结日；与总话数、末话新鲜度同为完结依据。
EpisodeResult? resolveEpisodeResult({
  required List<EpisodeInfo> type0Episodes,
  required EpisodeInfo? currentEpisode,
  required int seriesTotal,
  required DateTime now,
  required int currentWeek,
  DateTime? officialEnd,
}) {
  if (type0Episodes.isEmpty) return null;
  final currentEp = currentEpisode;
  if (currentEp == null) return null;

  final airTime = Utils.safeParseDate(currentEp.airDate);
  if (airTime == null) return null;

  final finalEpisode = type0Episodes.reduce((a, b) => a.sort >= b.sort ? a : b);

  final airWeek = Utils.getISOWeekNumber(airTime).$2;
  final isCurrentWeek = currentWeek == airWeek;

  final isFinalEpisode = currentEp.sort == finalEpisode.sort;
  final finalAirDate = Utils.safeParseDate(finalEpisode.airDate);

  final seriesReachedEnd = seriesTotal > 0 && finalEpisode.sort >= seriesTotal;

  // 总话数拿不到时 seriesReachedEnd 恒为 false，已完结的番会一直留在
  // 时间表里；官方 end 与末话新鲜度是另外两个依据
  final endedByOfficialDate = EpisodeResult.isFinishedDate(officialEnd, now);

  // end 与总话数都没有时看末话新鲜度：周更连续 3 周没出新区间基本可判定
  // 已完结（或休刊）
  final staleByEpisodes =
      seriesTotal <= 0 &&
      officialEnd == null &&
      finalAirDate != null &&
      now.difference(
            DateTime(finalAirDate.year, finalAirDate.month, finalAirDate.day),
          ) >
          const Duration(days: EpisodeResult.staleEpisodeDays);

  final isFinished =
      isFinalEpisode &&
      (seriesReachedEnd || endedByOfficialDate || staleByEpisodes) &&
      EpisodeResult.isFinishedDate(finalAirDate, now);

  return EpisodeResult(
    episodeAirdate: currentEp.airDate,
    episodeName: currentEp.name,
    episodeNameCn: currentEp.nameCn,
    episodeEp: currentEp.sort.toDouble(),
    isCurrentWeek: isCurrentWeek,
    isFinalEpisode: isFinalEpisode,
    hasNextEpisodes: currentEp.sort < finalEpisode.sort,
    isFinished: isFinished,
  );
}

class BangumiDataEntry {
  final String? begin;
  final String? end;
  const BangumiDataEntry({this.begin, this.end});
}

/// 播出时刻工具：把 `airTime` 归一到北京时间的挂钟时刻，日历页与截图共用
abstract final class BangumiAirTime {
  /// 无头容器时区通常是 UTC，而 bangumi 时间戳带 Z 或 +08:00 偏移，
  /// 直接 `toLocal()` 会整体偏 8 小时，深夜档还会排到前一天。
  static const _bjOffset = Duration(hours: 8);

  /// 解析为北京挂钟时刻，支持深夜番 `25:00` 进位到次日
  static DateTime? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final t = DateTime.tryParse(raw);
    if (t != null) return t.isUtc ? _wallClock(t) : t;
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[T\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(raw);
    if (m == null) return null;
    return DateTime(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
      int.parse(m[4]!),
      int.parse(m[5]!),
      int.parse(m[6] ?? '0'),
    );
  }

  /// 任意时刻 → 北京挂钟值
  static DateTime toBeijing(DateTime dt) => _wallClock(dt.toUtc());

  /// `HH:mm` 文本，取不到返回 null
  static String? hhmm(String? raw) {
    final dt = parse(raw);
    return dt == null
        ? null
        : '${dt.hour.toString().padLeft(2, '0')}:'
              '${dt.minute.toString().padLeft(2, '0')}';
  }

  /// 当日分钟数，无数据返回最大值以便排到末尾
  static int sortKey(String? raw) {
    final dt = parse(raw);
    if (dt == null) return 24 * 60;
    return dt.hour * 60 + dt.minute;
  }

  static DateTime _wallClock(DateTime utc) {
    final bj = utc.toUtc().add(_bjOffset);
    return DateTime(bj.year, bj.month, bj.day, bj.hour, bj.minute);
  }
}

extension NumDisplayExtension on num {
  String toCleanString() {
    return this % 1 == 0 ? toInt().toString() : toString();
  }
}
