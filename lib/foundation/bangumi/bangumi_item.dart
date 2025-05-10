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

  Map<String, dynamic>? extraInfo; // 新增字段

  BangumiItem(
      {required this.id,
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
      this.extraInfo});

  BangumiItem.fromMap(Map<String, dynamic> map)
      : id = map["id"],
        type = map["type"],
        name = map["name"],
        nameCn = map["nameCn"],
        summary = map["summary"],
        airDate = map["airDate"],
        airWeekday = map["airWeekday"],
        rank = map["rank"],
        total = map["total"],
        totalEpisodes = map["totalEpisodes"],
        score = map["score"],
        // 转为 double
        count =
            map["count"] == null ? null : Map<String, int>.from(map["count"]),
        // 转为 Map<String, int>
        collection = map["collection"] == null
            ? null
            : Map<String, int>.from(map["collection"]),
        // 转为 Map<String, int>
        images = Map<String, String>.from(map["images"]),
        // 转为 Map<String, String>
        tags = (map["tags"])
            .map((tag) => BangumiTag.fromJson(tag))
            .toList(); // 转为 List<BangumiTag>

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
                    as List<BangumiTag>; // 转为 List<BangumiTag>

  factory BangumiItem.fromJson(Map<String, dynamic> json) {
    List list = json['tags'] ?? [];
    List<BangumiTag> tagList = list.map((i) => BangumiTag.fromJson(i)).toList();

    return BangumiItem(
      id: json['id'],
      type: json['type'] ?? 2,
      name: json['name'] ?? '',
      nameCn: (json['name_cn'] ?? '') == ''
          ? (json['name'] ?? '')
          : json['name_cn'],
      summary: json['summary'] ?? '',
      airDate: json['air_date'] ?? json['date'] ?? '',
      airWeekday: json['air_weekday'] ??
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
              "grid": ''
            },
      ),
      tags: tagList,
      totalEpisodes: json['total_episodes'] ?? 0,
      count: Map<String, int>.from(json['rating']?['count'] ?? {}),
      collection: Map<String, int>.from(json['collection'] ?? {}),
      // collection: Map<String, int>.from(json['collection']),
    );
  }

  BangumiItem copyWith(
      {int? id,
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
      Map<String, dynamic>? extraInfo}) {
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
      extraInfo: extraInfo ?? this.extraInfo,
    );
  }

  @override
  String toString() {
    return 'BangumiItem{id: $id, type: $type, name: $name, nameCn: $nameCn, summary: $summary, airDate: $airDate, airWeekday: $airWeekday, rank: $rank, total: $total, score: $score, totalEpisodes: $totalEpisodes, count: $count, collection: $collection, images: $images, tags: $tags}';
  }
}
