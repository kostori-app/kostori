import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/bangumi/bangumi_item.dart';
import 'package:sqlite3/sqlite3.dart';

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
      create table if not exists bnagumi_calendar (
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
    } catch (e) {
      _db.execute('ROLLBACK'); // 如果发生错误，则回滚事务
      print("Error: $e");
    }
  }

  Future<void> addBnagumiCalendar(BangumiItem newItem) async {
    _db.execute("""
        insert or replace into bnagumi_calendar (
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

  Future<bool> checkWhetherDataExists(id) async {
    bool state = false;
    var res = _db.select("""
    select * from bangumi_data
    where sites LIKE ?
  """, ['%"bangumi","id":"$id"%']);
// 如果查询结果不为空，则表示存在该数据
    if (res.isNotEmpty) {
      state = true;
    }
    return state;
  }

  List<BangumiItem> getWeek(int week) {
    var res = _db.select("""
    select * from bnagumi_calendar
    where airWeekday = ?
    order by airWeekday DESC
  """, [week]);
    return res.map((element) => BangumiItem.fromRow(element)).toList();
  }

  void close() {
    _db.dispose();
  }
}
