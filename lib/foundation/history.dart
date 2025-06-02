// ignore_for_file: collection_methods_unrelated_type

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/utils/translations.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';

import 'favorites.dart';

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
      res += "Episode @ep".tlParams({
        "ep": lastWatchEpisode,
      });
    }
    if (lastWatchTime >= 1) {
      res += " ";
      res += formatLastWatchTime(lastWatchTime);
    }
    return res;
  }

  String formatLastWatchTime(int milliseconds) {
    // 将毫秒转换为秒
    int totalSeconds = milliseconds ~/ 1000;

    // 计算小时、分钟和秒
    int hours = totalSeconds ~/ 3600;
    int remainingSeconds = totalSeconds % 3600;
    int minutes = remainingSeconds ~/ 60;
    int seconds = remainingSeconds % 60;

    // 格式化输出
    if (hours > 0) {
      // 超过1小时：显示HH:MM:SS
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      // 不足1小时：显示MM:SS
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  String? get favoriteId => null;

  @override
  String? get language => null;

  @override
  String get sourceKey => type.animeSource?.key ?? "Unknown:${type.value}";

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

  /// Cache of history ids. Improve the performance of find operation.
  Map<String, bool>? _cachedHistoryIds;

  /// Cache records recently modified by the app. Improve the performance of listeners.
  final cachedHistories = <String, History>{};

  bool isInitialized = false;

  Future<void> init() async {
    if (isInitialized) {
      return;
    }
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

  static const _insertHistorySql = """
        insert or replace into history (id, title, subtitle, cover, time, type, lastWatchEpisode, lastWatchTime, lastRoad, allEpisode, watchEpisode, bangumiId)
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      """;

  static Future<void> _addHistoryAsync(int dbAddr, History newItem) {
    return Isolate.run(() {
      var db = sqlite3.fromPointer(ffi.Pointer.fromAddress(dbAddr));
      db.execute(_insertHistorySql, [
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
    });
  }

  bool _haveAsyncTask = false;

  /// Create a isolate to add history to prevent blocking the UI thread.
  Future<void> addHistoryAsync(History newItem) async {
    while (_haveAsyncTask) {
      await Future.delayed(Duration(milliseconds: 20));
    }

    _haveAsyncTask = true;
    await _addHistoryAsync(_db.handle.address, newItem);
    _haveAsyncTask = false;
    if (_cachedHistoryIds == null) {
      updateCache();
    } else {
      _cachedHistoryIds![newItem.id] = true;
    }
    cachedHistories[newItem.id] = newItem;
    if (cachedHistories.length > 10) {
      cachedHistories.remove(cachedHistories.keys.first);
    }
    notifyListeners();
  }

  /// add history. if exists, update time.
  ///
  /// This function would be called when user start reading.
  void addHistory(History newItem) {
    _db.execute(_insertHistorySql, [
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
    if (_cachedHistoryIds == null) {
      updateCache();
    } else {
      _cachedHistoryIds![newItem.id] = true;
    }
    cachedHistories[newItem.id] = newItem;
    if (cachedHistories.length > 10) {
      cachedHistories.remove(cachedHistories.keys.first);
    }
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
    _db.execute("delete from progress;");
    updateCache();
    notifyListeners();
  }

  void clearUnfavoritedHistory() {
    _db.execute('BEGIN TRANSACTION;');
    try {
      final idAndTypes = _db.select("""
      select id, type from history;
    """);
      for (var element in idAndTypes) {
        final id = element["id"] as String;
        final type = AnimeType(element["type"] as int);
        if (!LocalFavoritesManager().isExist(id, type)) {
          _db.execute("""
          delete from history
          where id == ? and type == ?;
        """, [id, type.value]);
          _db.execute("""
          delete from progress
          where id == ? and type == ?;
        """, [id, type.value]);
        }
      }
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
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

  List<History> bangumiByIDFind(int id) {
    final result = _db.select(
      'SELECT * FROM history WHERE bangumiId = ?',
      [id],
    );

    if (result.isEmpty) return [];

    // 转换所有结果行
    return result.map((row) => History.fromRow(row)).toList();
  }

  void updateCache() {
    _cachedHistoryIds = {};
    var res = _db.select("""
        select id from history;
      """);
    for (var element in res) {
      _cachedHistoryIds![element["id"] as String] = true;
    }
    for (var key in cachedHistories.keys.toList()) {
      if (!_cachedHistoryIds!.containsKey(key)) {
        cachedHistories.remove(key);
      }
    }
  }

  History? find(String id, AnimeType type) {
    if (_cachedHistoryIds == null) {
      updateCache();
    }
    if (!_cachedHistoryIds!.containsKey(id)) {
      return null;
    }
    if (cachedHistories.containsKey(id)) {
      return cachedHistories[id];
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
    isInitialized = false;
    _db.dispose();
  }

  void batchDeleteHistories(List<AnimeID> histories) {
    if (histories.isEmpty) return;
    _db.execute('BEGIN TRANSACTION;');
    try {
      for (var history in histories) {
        _db.execute("""
          delete from history
          where id == ? and type == ?;
        """, [history.id, history.type.value]);
      }
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
    updateCache();
    notifyListeners();
  }
}
