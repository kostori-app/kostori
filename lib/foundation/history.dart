// ignore_for_file: collection_methods_unrelated_type

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/utils/translations.dart';
import 'package:sqlite3/sqlite3.dart';

typedef HistoryType = AnimeType;

abstract mixin class HistoryMixin {
  String get title;

  String? get subTitle;

  String get cover;

  String get id;

  PageJumpTarget? get viewMore;

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
  final PageJumpTarget? viewMore;

  @override
  String id;

  Set<int> watchEpisode;

  History.fromModel({
    required HistoryMixin model,
    required this.lastWatchEpisode,
    required this.lastWatchTime,
    required this.lastRoad,
    required this.allEpisode,
    required this.bangumiId,
    Set<int>? watchEpisode,
    DateTime? time,
  }) : type = model.historyType,
       title = model.title,
       subtitle = model.subTitle ?? '',
       cover = model.cover,
       id = model.id,
       viewMore = model.viewMore,
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
    "viewMore": viewMore,
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
        (map["watchEpisode"] as List<dynamic>?)?.toSet() ?? const <int>{},
      ),
      bangumiId = map["bangumiId"],
      viewMore = map["viewMore"];

  @override
  String toString() {
    return 'History{type: $type, time: $time, title: $title, subtitle: $subtitle, cover: $cover, lastWatchEpisode : $lastWatchEpisode , id: $id, bangumiId: $bangumiId, viewMore:$viewMore}';
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
      watchEpisode = Set<int>.from(
        (row["watchEpisode"] as String)
            .split(',')
            .where((element) => element != "")
            .map((e) => int.parse(e)),
      ),
      bangumiId = row["bangumiId"],
      viewMore =
          row["viewMore"] != null && (row["viewMore"] as String).isNotEmpty
          ? PageJumpTarget.fromJsonString(row["viewMore"] as String)
          : null;

  @override
  int get hashCode => Object.hash(id, type);

  @override
  bool operator ==(Object other) {
    return other is History && type == other.type && id == other.id;
  }

  @override
  String get description {
    String formatMilliseconds(int milliseconds) {
      final duration = Duration(milliseconds: milliseconds);
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;

      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    var res = "";
    res += '${type.animeSource?.name ?? "Unknown"} | ';
    if ((lastWatchEpisode ?? 0) >= 1) {
      res += "Currently seen @ep".tlParams({"ep": lastWatchEpisode ?? 0});
    }
    if ((lastWatchTime ?? 0) >= 1) {
      if ((lastWatchEpisode ?? 0) >= 1) {
        res += " | ";
      }
      res += "lastWatchTime @time".tlParams({
        "time": formatMilliseconds(lastWatchTime ?? 0),
      });
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

enum HistoryTimeGroup {
  today,
  yesterday,
  last3Days,
  last7Days,
  last30Days,
  last3Months,
  last6Months,
  thisYear,
  older,
}

class HistoryGroup {
  final HistoryTimeGroup group;
  final List<History> items;
  final bool isExpanded;

  HistoryGroup({
    required this.group,
    required this.items,
    required this.isExpanded,
  });
}

extension HistoryTimeGroupExt on HistoryTimeGroup {
  String get title {
    switch (this) {
      case HistoryTimeGroup.today:
        return "Today".tl;
      case HistoryTimeGroup.yesterday:
        return "Yesterday".tl;
      case HistoryTimeGroup.last3Days:
        return "Last 3 Days".tl;
      case HistoryTimeGroup.last7Days:
        return "Last 7 Days".tl;
      case HistoryTimeGroup.last30Days:
        return "Last 30 Days".tl;
      case HistoryTimeGroup.last3Months:
        return "Last 3 Months".tl;
      case HistoryTimeGroup.last6Months:
        return "Last 6 Months".tl;
      case HistoryTimeGroup.thisYear:
        return "This Year".tl;
      case HistoryTimeGroup.older:
        return "Older".tl;
    }
  }

  int get order {
    switch (this) {
      case HistoryTimeGroup.today:
        return 0;
      case HistoryTimeGroup.yesterday:
        return 1;
      case HistoryTimeGroup.last3Days:
        return 2;
      case HistoryTimeGroup.last7Days:
        return 3;
      case HistoryTimeGroup.last30Days:
        return 4;
      case HistoryTimeGroup.last3Months:
        return 5;
      case HistoryTimeGroup.last6Months:
        return 6;
      case HistoryTimeGroup.thisYear:
        return 7;
      case HistoryTimeGroup.older:
        return 8;
    }
  }
}

HistoryTimeGroup groupByTime(DateTime time) {
  final now = DateTime.now();
  final itemDay = DateTime(time.year, time.month, time.day);
  final today = DateTime(now.year, now.month, now.day);

  final differenceInDays = today.difference(itemDay).inDays;

  if (differenceInDays == 0) {
    return HistoryTimeGroup.today;
  } else if (differenceInDays == 1) {
    return HistoryTimeGroup.yesterday;
  } else if (differenceInDays <= 3) {
    return HistoryTimeGroup.last3Days;
  } else if (differenceInDays <= 7) {
    return HistoryTimeGroup.last7Days;
  } else if (differenceInDays <= 30) {
    return HistoryTimeGroup.last30Days;
  } else if (differenceInDays <= 90) {
    return HistoryTimeGroup.last3Months;
  } else if (differenceInDays <= 180) {
    return HistoryTimeGroup.last6Months;
  } else if (time.year == now.year) {
    return HistoryTimeGroup.thisYear;
  } else {
    return HistoryTimeGroup.older;
  }
}

class Progress {
  String historyId;
  int episode;
  int road;
  int progressInMilli;
  HistoryType type;
  bool isCompleted;
  DateTime? startTime;
  DateTime? endTime;

  Progress.fromModel({
    required HistoryMixin model,
    required this.episode,
    required this.road,
    required this.progressInMilli,
    this.isCompleted = false,
    this.startTime,
    this.endTime,
  }) : type = model.historyType,
       historyId = model.id;

  Progress.fromRow(Map<String, Object?> row)
    : type = HistoryType(row['type'] as int),
      historyId = row['historyId'] as String,
      episode = row['episode'] as int,
      road = row['road'] as int,
      progressInMilli = row['progressInMilli'] as int,
      isCompleted = (row['isCompleted'] ?? 0) == 1,
      startTime = row['startTime'] != null
          ? DateTime.tryParse(row['startTime'] as String)
          : null,
      endTime = row['endTime'] != null
          ? DateTime.tryParse(row['endTime'] as String)
          : null;

  @override
  String toString() {
    return 'Progress{type: $type, historyId: $historyId, episode: $episode, road: $road, progressInMilli: $progressInMilli, '
        'isCompleted: $isCompleted, startTime: $startTime, endTime: $endTime}';
  }
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
          bangumiId int,
          viewMore text
        );
      """);

    _db.execute('''
        create table if not exists progress (
          type int,
          historyId text,
          episode int,
          road int,
          progressInMilli int,
          isCompleted int,
          startTime text,
          endTime text,
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
    if (!columns.any((element) => element["name"] == "viewMore")) {
      _db.execute("""
          alter table history
          add column viewMore text;
        """);
    }

    var progressColumns = _db.select("""
  pragma table_info("progress");
""");

    if (!progressColumns.any((element) => element["name"] == "isCompleted")) {
      _db.execute("""
    alter table progress
    add column isCompleted int default 0;
  """);
    }

    if (!progressColumns.any((element) => element["name"] == "startTime")) {
      _db.execute("""
    alter table progress
    add column startTime text;
  """);
    }

    if (!progressColumns.any((element) => element["name"] == "endTime")) {
      _db.execute("""
    alter table progress
    add column endTime text;
  """);
    }

    notifyListeners();
  }

  static const _insertHistorySql = """
        insert or replace into history (id, title, subtitle, cover, time, type, lastWatchEpisode, lastWatchTime, lastRoad, allEpisode, watchEpisode, bangumiId, viewMore)
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
        newItem.bangumiId,
        newItem.viewMore == null
            ? null
            : newItem.viewMore is PageJumpTarget
            ? (newItem.viewMore as PageJumpTarget).toJsonString()
            : newItem.viewMore,
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
      newItem.bangumiId,
      newItem.viewMore,
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

  void clearHistory() {
    _db.execute("delete from history;");
    _db.execute("delete from progress;");
    updateCache();
    notifyListeners();
  }

  void clearProgress() {
    _db.execute("delete from progress;");
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
          _db.execute(
            """
          delete from history
          where id == ? and type == ?;
        """,
            [id, type.value],
          );
          _db.execute(
            """
          delete from progress
          where id == ? and type == ?;
        """,
            [id, type.value],
          );
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
    _db.execute(
      """
      delete from history
      where id == ? and type == ?;
    """,
      [id, type.value],
    );
    _db.execute(
      """
      delete from progress
      where historyId == ? and type == ?;
    """,
      [id, type.value],
    );
    updateCache();
    notifyListeners();
  }

  List<History> bangumiByIDFind(int id) {
    final result = _db.select('SELECT * FROM history WHERE bangumiId = ?', [
      id,
    ]);

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

    var res = _db.select(
      """
      select * from history
      where id == ? and type == ?;
    """,
      [id, type.value],
    );
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
        _db.execute(
          """
          delete from history
          where id == ? and type == ?;
        """,
          [history.id, history.type.value],
        );
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

extension ProgressHelper on HistoryManager {
  Future<void> addProgress(Progress newProgress, String historyId) async {
    _db.execute(
      '''
    INSERT OR REPLACE INTO progress (
      type,
      historyId,
      episode,
      road,
      progressInMilli,
      isCompleted,
      startTime,
      endTime
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    ''',
      [
        newProgress.type.value,
        historyId,
        newProgress.episode,
        newProgress.road,
        newProgress.progressInMilli,
        newProgress.isCompleted,
        newProgress.startTime,
        newProgress.endTime,
      ],
    );
  }

  Future<bool> checkIfProgressExists({
    required String historyId,
    required AnimeType type,
    required int episode,
    required int road,
  }) async {
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

  Progress? progressFind(
    String historyId,
    AnimeType type,
    int episode,
    int road,
  ) {
    var res = _db.select(
      '''
    select * from progress
    where historyId == ? and type == ? and episode == ? and road == ?;
    ''',
      [historyId, type.value, episode, road],
    );
    if (res.isEmpty) {
      return null;
    }
    return Progress.fromRow(res.first);
  }

  Future<void> updateProgress({
    required String historyId,
    required AnimeType type,
    required int episode,
    required int road,
    int? progressInMilli,
    bool? isCompleted,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final updates = <String>[];
    final values = <dynamic>[];

    if (progressInMilli != null) {
      updates.add('progressInMilli = ?');
      values.add(progressInMilli);
    }

    if (isCompleted != null) {
      updates.add('isCompleted = ?');
      values.add(isCompleted ? 1 : 0);
    }

    if (startTime != null) {
      updates.add('startTime = ?');
      values.add(startTime.toIso8601String());
    }

    if (endTime != null) {
      updates.add('endTime = ?');
      values.add(endTime.toIso8601String());
    }

    if (updates.isEmpty) return;

    values.addAll([historyId, type.value, episode, road]);

    final sql =
        '''
    UPDATE progress
    SET ${updates.join(', ')}
    WHERE historyId = ? AND type = ? AND episode = ? AND road = ?;
  ''';

    _db.execute(sql, values);
  }
}
