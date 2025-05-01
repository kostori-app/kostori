import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/bangumi/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_item.dart';
import 'package:sqlite3/sqlite3.dart';

import 'log.dart';

class BangumiData {
  String? title;

  Map<String, dynamic>? titleTranslate;

  String? type;

  String? lang;

  String? officialSite;

  String? begin;

  String? broadcast;

  String? end;

  String? comment;

  List<dynamic>? sites;

  // 添加无参构造函数
  BangumiData();

  BangumiData.fromModel({
    this.title,
    this.titleTranslate,
    this.type,
    this.lang,
    this.officialSite,
    this.begin,
    this.broadcast,
    this.end,
    this.comment,
    this.sites,
  });

  Map<String, dynamic> toMap() => {
        "title": title,
        "titleTranslate": titleTranslate,
        "type": type,
        "lang": lang,
        "officialSite": officialSite,
        "begin": begin,
        "broadcast ": broadcast,
        "end": end,
        "comment": comment,
        "sites": sites
      };

  BangumiData.fromMap(Map<String, dynamic> map)
      : title = map["title"],
        titleTranslate = map["titleTranslate"],
        type = map["type"],
        lang = map["lang"],
        officialSite = map["officialSite"],
        begin = map["begin"],
        broadcast = map["broadcast "],
        end = map["end"],
        comment = map["comment"],
        sites = map["sites"];

  BangumiData.fromJson(Map<String, dynamic> json)
      : title = json["title"],
        titleTranslate = json["titleTranslate"],
        type = json["type"],
        lang = (json["lang"]),
        officialSite = json["officialSite"],
        begin = json["begin"],
        broadcast = json["broadcast"],
        end = json["end"],
        comment = json["comment"],
        sites = json["sites"];

  @override
  String toString() {
    return 'BangumiData{title: $title, titleTranslate: $titleTranslate, type: $type, lang: $lang, officialSite: $officialSite, begin : $begin , broadcast: $broadcast, end: $end, comment: $comment, sites: $sites}';
  }
}

class BnagumiCalendar {
  String? airDate;

  int? airWeekday;

  Map<String, int>? collection;

  Map<String, int>? count;

  int? id;

  Map<String, String>? images;

  String? name;

  String? nameCn;

  int? rank;

  num? score;

  String? summary;

  int? total;

  int? type;

  BnagumiCalendar();

  BnagumiCalendar.fromModel(
      {this.id,
      this.type,
      this.name,
      this.nameCn,
      this.summary,
      this.airDate,
      this.airWeekday,
      this.rank,
      this.total,
      this.score,
      this.count,
      this.collection,
      this.images});
}

class BangumiManager with ChangeNotifier {
  static BangumiManager? cache;

  BangumiManager.create();

  factory BangumiManager() =>
      cache == null ? (cache = BangumiManager.create()) : cache!;

  late Database _db;

  Future<void> init() async {
    _db = sqlite3.open("${App.dataPath}/bangumi.db");

    _db.execute("""
      create table if not exists bangumi_data (
        title text primary key,
        titleTranslate text,
        type text,
        lang text,
        officialSite text,
        begin text,
        broadcast text,
        end text,
        comment text,
        sites text
      );
    """);

    _db.execute("""
      create table if not exists bangumi_calendar (
        id INTEGER primary key,
        type int,
        name text,
        nameCn text,
        summary text,
        airDate text,
        airWeekday int,
        total int,
        count text,
        score NUMERIC,
        rank int,
        images text,
        collection text
      );
    """);

    _db.execute("""
      create table if not exists bangumi_binding (
        id INTEGER primary key,
        type int,
        name text,
        nameCn text,
        summary text,
        airDate text,
        airWeekday int,
        total int,
        totalEpisodes int,
        count text,
        score NUMERIC,
        rank int,
        images text,
        collection text,
        tags text
      );
    """);

    notifyListeners();
  }

  Future<void> addBangumiData(BangumiData newItem) async {
    _db.execute("""
        insert or replace into bangumi_data (
        title,
        titleTranslate,
        type,
        lang,
        officialSite,
        begin,
        broadcast,
        end,
        comment,
        sites
        )
        values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      """, [
      newItem.title,
      jsonEncode(newItem.titleTranslate),
      newItem.type,
      newItem.lang,
      newItem.officialSite,
      newItem.begin,
      newItem.broadcast,
      newItem.end,
      newItem.comment,
      jsonEncode(newItem.sites)
    ]);
    notifyListeners();
  }

  Future<void> addBulkBangumiData(List<BangumiData> bangumiDataList) async {
    try {
      // 开始事务
      _db.execute('BEGIN TRANSACTION');

      final stmt = _db.prepare('''
      INSERT OR REPLACE INTO bangumi_data (
        title,
        titleTranslate,
        type,
        lang,
        officialSite,
        begin,
        broadcast,
        end,
        comment,
        sites
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');

      // 批量插入
      for (var bangumiData in bangumiDataList) {
        stmt.execute([
          bangumiData.title,
          jsonEncode(bangumiData.titleTranslate),
          bangumiData.type,
          bangumiData.lang,
          bangumiData.officialSite,
          bangumiData.begin,
          bangumiData.broadcast,
          bangumiData.end,
          bangumiData.comment,
          jsonEncode(bangumiData.sites),
        ]);
      }

      // 提交事务
      _db.execute('COMMIT');

      stmt.dispose(); // 释放statement
    } catch (e, s) {
      _db.execute('ROLLBACK'); // 如果发生错误，则回滚事务
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
  }

  Future<void> addBnagumiCalendar(BangumiItem newItem) async {
    _db.execute("""
        insert or replace into bangumi_calendar (
        id,
        type,
        name,
        nameCn,
        summary,
        airDate,
        airWeekday,
        total,
        count,
        score,
        rank,
        images,
        collection
        )
        values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      """, [
      newItem.id,
      newItem.type,
      newItem.name,
      newItem.nameCn,
      newItem.summary,
      newItem.airDate,
      newItem.airWeekday,
      newItem.total,
      jsonEncode(newItem.count),
      newItem.score,
      newItem.rank,
      jsonEncode(newItem.images),
      jsonEncode(newItem.collection)
    ]);

    notifyListeners();
  }

  Future<void> addBnagumiBinding(BangumiItem newItem) async {
    _db.execute("""
        insert or replace into bangumi_binding (
        id,
        type,
        name,
        nameCn,
        summary,
        airDate,
        airWeekday,
        total,
        totalEpisodes,
        count,
        score,
        rank,
        images,
        collection,
        tags
        )
        values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      """, [
      newItem.id,
      newItem.type,
      newItem.name,
      newItem.nameCn,
      newItem.summary,
      newItem.airDate,
      newItem.airWeekday,
      newItem.total,
      newItem.totalEpisodes,
      jsonEncode(newItem.count),
      newItem.score,
      newItem.rank,
      jsonEncode(newItem.images),
      jsonEncode(newItem.collection),
      jsonEncode(newItem.tags)
    ]);

    notifyListeners();
  }

  Future<BangumiItem?> bindFind(int id) async {
    var res = _db.select("""
      select * from bangumi_binding
      where id == ?;
    """, [id]);
    if (res.isEmpty) {
      await Bangumi.getBangumiInfoBind(id);
      res = _db.select("""
      select * from bangumi_binding
      where id == ?;
    """, [id]);
      if (res.isEmpty) {
        return null;
      }
    }
    return BangumiItem.fromRow(res.first);
  }

  // 修改后的存在性检查方法（返回包含存在状态和时间的 Map）
  Future<Map<String, String?>> checkWhetherDataExistsBatch(
      List<String> ids) async {
    if (ids.isEmpty) return {};

    final conditions =
        List.generate(ids.length, (_) => 'sites LIKE ?').join(' OR ');
    final patterns = ids.map((id) => '%"bangumi","id":"$id"%').toList();

    // 同时查询 sites 和 begin 列
    final result = _db.select(
        'SELECT sites, begin FROM bangumi_data WHERE $conditions', patterns);

    final existenceMap = <String, String?>{};
    for (final row in result) {
      final sites = jsonDecode(row['sites'] as String) as List;
      final beginTime = row['begin']?.toString(); // 获取 begin 列

      // 遍历所有匹配的站点
      for (final site in sites.cast<Map>()) {
        if (site['site'] == 'bangumi') {
          final id = site['id'].toString();
          existenceMap[id] = beginTime; // 关联 ID 和 begin 时间
        }
      }
    }

    return existenceMap;
  }

  // 修改后的单ID检查方法
  Future<bool> checkWhetherDataExists(String id) async {
    final existenceMap = await checkWhetherDataExistsBatch([id]);

    // 检查映射中是否包含该ID，且值不为null（根据实际需求选择条件）
    return existenceMap.containsKey(id); // 仅检查ID存在性
    // 或 existenceMap[id] != null // 同时要求存在begin数据
  }

  // 支持批量周数查询
  List<BangumiItem> getWeeks(List<int> weeks) {
    if (weeks.isEmpty) return [];

    final placeholders = List.filled(weeks.length, '?').join(',');
    final res = _db.select("""
    SELECT * FROM bangumi_calendar
    WHERE airWeekday IN ($placeholders)
    ORDER BY airWeekday DESC
  """, weeks);

    return res.map(BangumiItem.fromRow).toList();
  }

  List<BangumiItem> getWeek(int week) => getWeeks([week]);

  void clearBangumiData() {
    _db.execute("delete from bangumi_data;");
    notifyListeners();
  }

  void clearBnagumiCalendar() {
    _db.execute("delete from bangumi_calendar;");
    notifyListeners();
  }

  void close() {
    _db.dispose();
  }
}
