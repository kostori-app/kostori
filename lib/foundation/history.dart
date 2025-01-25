import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/utils/translations.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';

typedef HistoryType = AnimeType;

abstract mixin class HistoryMixin {
  String get title;

  String? get subTitle;

  String get cover;

  String get id;

  HistoryType get historyType;
}

class History implements Anime {
  HistoryType type;

  DateTime time;

  @override
  String title;

  @override
  String subtitle;

  @override
  String cover;

  int lastWatchEpisode; // 上次观看番剧集数

  int lastWatchTime; // 上次观看时间

  int lastRoad; //上次播放列表

  int allEpisode; //全部集数

  int? bangumiId;

  @override
  String id;

  Set<int> watchEpisode;

  History.fromModel(
      {required HistoryMixin model,
      required this.lastWatchEpisode,
      required this.lastWatchTime,
      required this.lastRoad,
      required this.allEpisode,
      required this.bangumiId,
      Set<int>? watchEpisode,
      DateTime? time})
      : type = model.historyType,
        title = model.title,
        subtitle = model.subTitle ?? '',
        cover = model.cover,
        id = model.id,
        watchEpisode = watchEpisode ?? <int>{},
        time = time ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        "type": type.value,
        "time": time.millisecondsSinceEpoch,
        "title": title,
        "subtitle": subtitle,
        "cover": cover,
        "lastWatchEpisode ": lastWatchEpisode,
        "lastWatchTime": lastWatchTime,
        "lastRoad": lastRoad,
        "allEpisode": allEpisode,
        "id": id,
        "watchEpisode": watchEpisode.toList(),
      };

  History.fromMap(Map<String, dynamic> map)
      : type = HistoryType(map["type"]),
        time = DateTime.fromMillisecondsSinceEpoch(map["time"]),
        title = map["title"],
        subtitle = map["subtitle"],
        cover = map["cover"],
        lastWatchEpisode = map["lastWatchEpisode"],
        lastWatchTime = map["lastWatchTime"],
        lastRoad = map["lastRoad"],
        allEpisode = map["allEpisode"],
        id = map["id"],
        watchEpisode = Set<int>.from(
            (map["watchEpisode"] as List<dynamic>?)?.toSet() ?? const <int>{}),
        bangumiId = map["bangumiId"];

  @override
  String toString() {
    return 'History{type: $type, time: $time, title: $title, subtitle: $subtitle, cover: $cover, lastWatchEpisode : $lastWatchEpisode , id: $id, bangumiId: $bangumiId}';
  }

  History.fromRow(Row row)
      : type = HistoryType(row["type"]),
        time = DateTime.fromMillisecondsSinceEpoch(row["time"]),
        title = row["title"],
        subtitle = row["subtitle"],
        cover = row["cover"],
        lastWatchEpisode = row["lastWatchEpisode"],
        lastWatchTime = row["lastWatchTime"],
        lastRoad = row["lastRoad"],
        allEpisode = row["allEpisode"],
        id = row["id"],
        watchEpisode = Set<int>.from((row["watchEpisode"] as String)
            .split(',')
            .where((element) => element != "")
            .map((e) => int.parse(e))),
        bangumiId = row["bangumiId"];

  static Future<History> findOrCreate(
    HistoryMixin model, {
    int lastWatchEpisode = 0,
    int page = 0,
    int lastWatchTime = 0,
  }) async {
    var history = await HistoryManager().find(model.id, model.historyType);
    if (history != null) {
      return history;
    }
    history = History.fromModel(
        model: model,
        lastWatchEpisode: lastWatchEpisode,
        lastWatchTime: lastWatchTime,
        lastRoad: 1,
        allEpisode: 1,
        bangumiId: null);
    HistoryManager().addHistory(history);
    return history;
  }

  static Future<History> createIfNull(
      History? history, HistoryMixin model) async {
    if (history != null) {
      return history;
    }
    history = History.fromModel(
        model: model,
        lastWatchEpisode: 0,
        lastWatchTime: 0,
        lastRoad: 1,
        allEpisode: 1,
        bangumiId: null);
    HistoryManager().addHistory(history);
    return history;
  }

  @override
  int get hashCode => Object.hash(id, type);

  @override
  bool operator ==(Object other) {
    return other is History && type == other.type && id == other.id;
  }

  @override
  String get description {
    var res = "";
    if (lastWatchEpisode >= 1) {
      res += "Chapter @ep".tlParams({
        "ep": lastWatchEpisode,
      });
    }
    // if (page >= 1) {
    //   if (lastWatchEpisode >= 1) {
    //     res += " - ";
    //   }
    //   res += "Page @page".tlParams({
    //     "page": page,
    //   });
    // }
    return res;
  }

  @override
  String? get favoriteId => null;

  @override
  String? get language => null;

  @override
  String get sourceKey => type == AnimeType.local
      ? 'local'
      : type.animeSource?.key ?? "Unknown:${type.value}";

  @override
  double? get stars => null;

  @override
  List<String>? get tags => null;

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}

class Progress {
  String historyId;
  int episode;
  int road;
  int progressInMilli;
  HistoryType type;

  Progress.fromModel({
    required HistoryMixin model,
    required this.episode,
    required this.road,
    required this.progressInMilli,
  })  : type = model.historyType,
        historyId = model.id;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'historyId': historyId,
      'episode': episode,
      'road': road,
      'progressInMilli': progressInMilli,
    };
  }

  Progress.fromMap(Map<String, dynamic> map)
      : type = HistoryType(map['type']),
        historyId = map['historyId'],
        episode = map['episode'],
        road = map['road'],
        progressInMilli = map['progressInMilli'];

  @override
  String toString() {
    return 'Progress{type: $type, historyId: $historyId, episode: $episode, road: $road, progressInMilli: $progressInMilli}';
  }

  Progress.fromRow(Row row)
      : type = HistoryType(row['type']),
        historyId = row['historyId'],
        episode = row['episode'],
        road = row['road'],
        progressInMilli = row['progressInMilli'];
}

class HistoryManager with ChangeNotifier {
  static HistoryManager? cache;

  HistoryManager.create();

  factory HistoryManager() =>
      cache == null ? (cache = HistoryManager.create()) : cache!;

  late Database _db;

  int get length => _db.select("select count(*) from history;").first[0] as int;

  Map<String, bool>? _cachedHistory;

  Future<void> tryUpdateDb() async {
    var file = File("${App.dataPath}/history_temp.db");
    if (!file.existsSync()) {
      Log.addLog(
          LogLevel.info, "HistoryManager.tryUpdateDb", "db file not exist");
      return;
    }
    var db = sqlite3.open(file.path);
    var newHistory0 = db.select("""
      select * from history
      order by time DESC;
    """);
    var newHistory =
        newHistory0.map((element) => History.fromRow(element)).toList();
    if (file.existsSync()) {
      var skips = 0;
      for (var history in newHistory) {
        if (findSync(history.id, history.type) == null) {
          addHistory(history);
          Log.addLog(
              LogLevel.info, "HistoryManager", "merge history ${history.id}");
        } else {
          skips++;
        }
      }
      Log.addLog(LogLevel.info, "HistoryManager",
          "merge history, skipped $skips, added ${newHistory.length - skips}");
    }
    db.dispose();
    file.deleteSync();
  }

  Future<void> init() async {
    _db = sqlite3.open("${App.dataPath}/history.db");

    _db.execute("""
        create table if not exists history  (
          id text primary key,
          title text,
          subtitle text,
          cover text,
          time int,
          type int,
          lastWatchEpisode int,
          lastWatchTime int,
          lastRoad int,
          allEpisode int,
          watchEpisode text,
          bangumiId int
        );
      """);

    _db.execute('''
  CREATE TABLE IF NOT EXISTS progress (
    type int,
    historyId TEXT,
    episode INT,
    road INT,
    progressInMilli INT,
    PRIMARY KEY (type, episode, road, historyId),
    FOREIGN KEY (historyId) REFERENCES History(id)
  );
''');

    var columns = _db.select("""
        pragma table_info("history");
      """);
    if (!columns.any((element) => element["name"] == "bangumiId")) {
      _db.execute("""
          alter table history
          add column bangumiId int;
        """);
    }

    notifyListeners();
  }

  /// add history. if exists, update time.
  ///
  /// This function would be called when user start reading.
  Future<void> addHistory(History newItem) async {
    _db.execute("""
        insert or replace into history (
        id,
        title,
        subtitle,
        cover,
        time,
        type,
        lastWatchEpisode,
        lastWatchTime,
        lastRoad,
        allEpisode,
        watchEpisode,
        bangumiId
        )
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      """, [
      newItem.id,
      newItem.title,
      newItem.subtitle,
      newItem.cover,
      newItem.time.millisecondsSinceEpoch,
      newItem.type.value,
      newItem.lastWatchEpisode,
      newItem.lastWatchTime,
      newItem.lastRoad,
      newItem.allEpisode,
      newItem.watchEpisode.join(','),
      newItem.bangumiId
    ]);
    updateCache();
    notifyListeners();
  }

  Future<void> addProgress(Progress newProgress, String historyId) async {
    _db.execute(
      '''
    INSERT OR REPLACE INTO progress (
      type,
      historyId,
      episode,
      road,
      progressInMilli
    ) VALUES (?, ?, ?, ?, ?);
    ''',
      [
        newProgress.type.value, // Progress 的类型 (如 episode, episode2, episode3)
        historyId, // 引用的 History ID
        newProgress.episode, // 集数
        newProgress.road, // 路径
        newProgress.progressInMilli, // 进度存储为毫秒数
      ],
    );

    updateCache(); // 更新缓存
    notifyListeners(); // 通知监听器
  }

  Future<bool> checkIfProgressExists(
      String historyId, AnimeType type, int episode, int road) async {
    final result = _db.select(
      '''
    SELECT COUNT(*) as count
    FROM progress
    WHERE historyId = ? AND type = ? AND episode = ? AND road = ?;
    ''',
      [historyId, type.value, episode, road],
    );

    // 如果查询结果中返回的 count 大于 0，说明该历史记录已经存在
    return result.isNotEmpty && (result.first['count'] as int) > 0;
  }

  void clearHistory() {
    _db.execute("delete from history;");
    updateCache();
    notifyListeners();
  }

  void remove(String id, AnimeType type) async {
    _db.execute("""
      delete from history
      where id == ? and type == ?;
    """, [id, type.value]);
    updateCache();
    notifyListeners();
  }

  Future<History?> find(String id, AnimeType type) async {
    return findSync(id, type);
  }

  Future<Progress?> progressFind(
      String historyId, AnimeType type, int episode, int road) async {
    var res = _db.select('''
    select * from progress
    where historyId == ? and type == ? and episode == ? and road == ?;
    ''', [historyId, type.value, episode, road]);
    if (res.isEmpty) {
      return null;
    }
    return Progress.fromRow(res.first);
  }

  void updateCache() {
    _cachedHistory = {};
    var res = _db.select("""
        select * from history;
      """);
    for (var element in res) {
      _cachedHistory![element["id"] as String] = true;
    }
  }

  History? findSync(String id, AnimeType type) {
    if (_cachedHistory == null) {
      updateCache();
    }
    if (!_cachedHistory!.containsKey(id)) {
      return null;
    }

    var res = _db.select("""
      select * from history
      where id == ? and type == ?;
    """, [id, type.value]);
    if (res.isEmpty) {
      return null;
    }
    return History.fromRow(res.first);
  }

  List<History> getAll() {
    var res = _db.select("""
      select * from history
      order by time DESC;
    """);
    return res.map((element) => History.fromRow(element)).toList();
  }

  /// 获取最近观看的番剧
  List<History> getRecent() {
    var res = _db.select("""
      select * from history
      order by time DESC
      limit 20;
    """);
    return res.map((element) => History.fromRow(element)).toList();
  }

  /// 获取历史记录的数量
  int count() {
    var res = _db.select("""
      select count(*) from history;
    """);
    return res.first[0] as int;
  }

  void close() {
    _db.dispose();
  }
}
