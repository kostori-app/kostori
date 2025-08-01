import 'dart:convert';

import 'package:kostori/utils/utils.dart';
import 'package:sqlite3/sqlite3.dart';

import 'bangumi_tag.dart';

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

  Map<String, dynamic>? extraInfo; // 新增字段

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
      name: json['name'] ?? '',
      nameCn: (json['name_cn'] ?? json['nameCN'] ?? '') == ''
          ? (json['name'] ?? '')
          : json['name_cn'] ?? json['nameCN'],
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
    Map<String, dynamic>? extraInfo,
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
}
