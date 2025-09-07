import 'dart:convert';

import 'package:flutter/widgets.dart' show ChangeNotifier, debugPrint;
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/log.dart';
import 'package:sqlite3/sqlite3.dart';

enum AppPlatform {
  android("android"),
  ios("ios"),
  windows("windows"),
  macos("macos"),
  linux("linux"),
  web("web"),
  unknown('unknown');

  final String value;

  const AppPlatform(this.value);

  /// 从字符串反序列化成枚举
  static AppPlatform fromString(String value) {
    for (var platform in values) {
      if (platform.value == value) return platform;
    }
    return AppPlatform.android; // 默认值
  }

  static AppPlatform get current {
    if (App.isAndroid) return AppPlatform.android;
    if (App.isIOS) return AppPlatform.ios;
    if (App.isWindows) return AppPlatform.windows;
    if (App.isMacOS) return AppPlatform.macos;
    if (App.isLinux) return AppPlatform.linux;
    return AppPlatform.unknown;
  }
}

enum DailyEventType {
  comment,
  click,
  watch,
  rating,
  favorite;

  List<DailyEvent> getList(StatsDataImpl stats) {
    switch (this) {
      case DailyEventType.comment:
        return stats.comment;
      case DailyEventType.click:
        return stats.totalClickCount;
      case DailyEventType.watch:
        return stats.totalWatchDurations;
      case DailyEventType.rating:
        return stats.rating;
      case DailyEventType.favorite:
        return stats.favorite;
    }
  }
}

class TodayEventBundle {
  final StatsDataImpl statsData;
  final DailyEvent todayComment;
  final PlatformEventRecord commentRecord;
  final DailyEvent todayClick;
  final PlatformEventRecord clickRecord;
  final DailyEvent todayWatch;
  final PlatformEventRecord watchRecord;
  final DailyEvent todayRating;
  final PlatformEventRecord ratingRecord;
  final DailyEvent todayFavorite;
  final PlatformEventRecord favoriteRecord;

  TodayEventBundle({
    required this.statsData,
    required this.todayComment,
    required this.commentRecord,
    required this.todayClick,
    required this.clickRecord,
    required this.todayWatch,
    required this.watchRecord,
    required this.todayRating,
    required this.ratingRecord,
    required this.todayFavorite,
    required this.favoriteRecord,
  });
}

extension DateTimeFormat on DateTime {
  /// 格式化为 yyyy-MM-dd
  String get yyyymmdd {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// 格式化为 yyyy-MM-dd HH:mm:ss
  String get yyyymmddHHmmss {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')} '
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:'
        '${second.toString().padLeft(2, '0')}';
  }

  String get hhmmss {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:'
        '${second.toString().padLeft(2, '0')}';
  }
}

///收藏行为
enum FavoriteAction {
  add("add"),
  move("move"),
  remove("remove");

  final String value;

  const FavoriteAction(this.value);

  static FavoriteAction? fromString(String? value) {
    if (value == null) return null;
    return FavoriteAction.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError("Invalid FavoriteAction: $value"),
    );
  }
}

/// 收藏状态（类型枚举）
enum FavoriteType {
  wantWatch("wish"), // 想看
  watching("doing"), // 在看
  watched("collect"), // 已看
  paused("on hold"), // 搁置
  dropped("dropped"); // 抛弃

  final String value;

  const FavoriteType(this.value);

  static FavoriteType? fromString(String? value) {
    if (value == null) return null;
    return FavoriteType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError("Invalid FavoriteType: $value"),
    );
  }
}

class PlatformEventRecord {
  int value;
  AppPlatform? platform;
  String? comment;
  int? rating;
  DateTime? date;
  String? favorite;
  FavoriteType? favoriteType;
  FavoriteAction? favoriteAction;
  int? watchDuration;

  PlatformEventRecord({
    required this.value,
    this.platform,
    this.comment,
    this.rating,
    this.favorite,
    this.favoriteType,
    this.favoriteAction,
    this.watchDuration,
    String? dateStr,
  }) : date = dateStr != null ? _parseDate(dateStr) : null;

  /// 校验并解析字符串，支持 yyyy-MM-dd 或 yyyy-MM-dd HH:mm:ss
  static DateTime _parseDate(String dateStr) {
    // yyyy-MM-dd HH:mm:ss
    final regexSecond = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');

    if (regexSecond.hasMatch(dateStr)) {
      // 替换空格为 T，兼容 DateTime.parse
      return DateTime.parse(dateStr.replaceFirst(' ', 'T'));
    } else {
      throw FormatException(
        'Invalid date format, expected yyyy-MM-dd HH:mm:ss',
      );
    }
  }

  /// 序列化成 JSON
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'value': value, 'platform': platform?.value};

    if (comment != null) {
      map['comment'] = comment;
    }
    if (rating != null) {
      map['rating'] = rating;
    }
    if (date != null) {
      // 固定输出 yyyy-MM-dd HH:mm:ss
      map['date'] =
          '${date!.year.toString().padLeft(4, '0')}-'
          '${date!.month.toString().padLeft(2, '0')}-'
          '${date!.day.toString().padLeft(2, '0')} '
          '${date!.hour.toString().padLeft(2, '0')}:'
          '${date!.minute.toString().padLeft(2, '0')}:'
          '${date!.second.toString().padLeft(2, '0')}';
    }
    if (favorite != null) map['favorite'] = favorite;
    if (favoriteType != null) map['favoriteType'] = favoriteType!.value;
    if (favoriteAction != null) map['favoriteAction'] = favoriteAction!.value;
    if (watchDuration != null) map['watchDuration'] = watchDuration;

    return map;
  }

  /// 从 JSON 反序列化
  factory PlatformEventRecord.fromJson(Map<String, dynamic> json) {
    return PlatformEventRecord(
      value: json['value'] as int,
      platform: json['platform'] != null
          ? AppPlatform.fromString(json['platform'] as String)
          : null,
      comment: json['comment'] as String?,
      rating: json['rating'] as int?,
      dateStr: json['date'] as String?,
      favorite: json['favorite'] as String?,
      favoriteType: json['favoriteType'] != null
          ? FavoriteType.fromString(json['favoriteType'] as String)
          : null,
      favoriteAction: json['favoriteAction'] != null
          ? FavoriteAction.fromString(json['favoriteAction'] as String)
          : null,
      watchDuration: json['watchDuration'] as int?,
    );
  }
}

class DailyEvent {
  DateTime date;
  List<PlatformEventRecord> platformEventRecords;

  DailyEvent({required String dateStr, required this.platformEventRecords})
    : date = _parseDate(dateStr);

  /// 校验并解析字符串，必须 yyyy-MM-dd
  static DateTime _parseDate(String dateStr) {
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(dateStr)) {
      throw FormatException('Invalid date format, expected yyyy-MM-dd');
    }
    return DateTime.parse(dateStr);
  }

  /// 从 JSON 反序列化
  factory DailyEvent.fromJson(Map<String, dynamic> json) => DailyEvent(
    dateStr: json['date'] as String,
    platformEventRecords: (json['platformEventRecords'] as List)
        .map((e) => PlatformEventRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// 转成 JSON
  Map<String, dynamic> toJson() => {
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'platformEventRecords': platformEventRecords
        .map((e) => e.toJson())
        .toList(),
  };
}

abstract class StatsData {
  ///唯一的id
  String get id;

  ///显示的标题
  String? get title;

  ///用于显示的封面图
  String? get cover;

  ///绑定的bangumi条目id
  int? get bangumiId;

  ///渠道名
  int get type;

  /// 点赞状态
  bool get liked;

  ///是否是bangumi来源
  bool get isBangumi;

  /// 评论内容
  List<DailyEvent> get comment;

  /// 用户点击次数
  List<DailyEvent> get totalClickCount;

  /// 最初点击时间
  DateTime? get firstClickTime;

  /// 最近一次点击时间
  DateTime? get lastClickTime;

  /// 观看时长
  List<DailyEvent> get totalWatchDurations;

  ///评分
  List<DailyEvent> get rating;

  ///收藏
  List<DailyEvent> get favorite;
}

class StatsDataImpl implements StatsData {
  @override
  final String id;
  @override
  String? title;
  @override
  String? cover;
  @override
  int? bangumiId;
  @override
  final int type;
  @override
  bool liked;
  @override
  bool isBangumi;
  @override
  List<DailyEvent> comment;
  @override
  List<DailyEvent> totalClickCount;
  @override
  DateTime? firstClickTime;
  @override
  DateTime? lastClickTime;
  @override
  List<DailyEvent> totalWatchDurations;
  @override
  List<DailyEvent> rating;
  @override
  List<DailyEvent> favorite;

  StatsDataImpl({
    required this.id,
    this.title,
    this.cover,
    this.bangumiId,
    required this.type,
    this.liked = false,
    this.isBangumi = false,
    List<DailyEvent>? comment,
    List<DailyEvent>? totalClickCount,
    this.firstClickTime,
    this.lastClickTime,
    List<DailyEvent>? totalWatchDurations,
    List<DailyEvent>? rating,
    List<DailyEvent>? favorite,
  }) : comment = comment ?? [],
       totalClickCount = totalClickCount ?? [],
       totalWatchDurations = totalWatchDurations ?? [],
       rating = rating ?? [],
       favorite = favorite ?? [];

  /// 从数据库行创建实例
  factory StatsDataImpl.fromRow(Map<String, Object?> row) {
    List<DailyEvent> parseList(String? jsonStr) {
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => DailyEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return StatsDataImpl(
      id: row['id'] as String,
      title: row['title'] as String?,
      cover: row['cover'] as String?,
      bangumiId: row['bangumiId'] as int?,
      type: row['type'] as int,
      liked: (row['liked'] as int?) == 1,
      isBangumi: (row['isBangumi'] as int?) == 1,
      comment: parseList(row['comment'] as String?),
      totalClickCount: parseList(row['totalClickCount'] as String?),
      totalWatchDurations: parseList(row['totalWatchDurations'] as String?),
      rating: parseList(row['rating'] as String?),
      favorite: parseList(row['favorite'] as String?),
      firstClickTime: row['firstClickTime'] != null
          ? DateTime.parse(row['firstClickTime'] as String)
          : null,
      lastClickTime: row['lastClickTime'] != null
          ? DateTime.parse(row['lastClickTime'] as String)
          : null,
    );
  }

  /// 从 Map/JSON 创建实例
  factory StatsDataImpl.fromMap(Map<String, dynamic> map) {
    List<DailyEvent> parseList(List<dynamic>? list) {
      if (list == null) return [];
      return list
          .map((e) => DailyEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return StatsDataImpl(
      id: map['id'] as String,
      title: map['title'] as String?,
      cover: map['cover'] as String?,
      bangumiId: map['bangumiId'] as int?,
      type: map['type'] as int,
      liked: map['liked'] as bool? ?? false,
      isBangumi: map['isBangumi'] as bool? ?? false,
      comment: parseList(map['comment'] as List<dynamic>?),
      totalClickCount: parseList(map['totalClickCount'] as List<dynamic>?),
      totalWatchDurations: parseList(
        map['totalWatchDurations'] as List<dynamic>?,
      ),
      rating: parseList(map['rating'] as List<dynamic>?),
      favorite: parseList(map['favorite'] as List<dynamic>?),
      firstClickTime: map['firstClickTime'] != null
          ? DateTime.parse(map['firstClickTime'] as String)
          : null,
      lastClickTime: map['lastClickTime'] != null
          ? DateTime.parse(map['lastClickTime'] as String)
          : null,
    );
  }

  /// 转 Map/JSON
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'cover': cover,
    'bangumiId': bangumiId,
    'type': type,
    'liked': liked,
    'isBangumi': isBangumi,
    'comment': jsonEncode(comment.map((e) => e.toJson()).toList()),
    'totalClickCount': jsonEncode(
      totalClickCount.map((e) => e.toJson()).toList(),
    ),
    'totalWatchDurations': jsonEncode(
      totalWatchDurations.map((e) => e.toJson()).toList(),
    ),
    'rating': rating.isNotEmpty
        ? jsonEncode(rating.map((e) => e.toJson()).toList())
        : null,
    'favorite': favorite.isNotEmpty
        ? jsonEncode(favorite.map((e) => e.toJson()).toList())
        : null,
    'firstClickTime': firstClickTime?.toIso8601String(),
    'lastClickTime': lastClickTime?.toIso8601String(),
  };

  @override
  String toString() {
    return 'StatsDataImpl('
        'id: $id, '
        'title: $title, '
        'cover: $cover, '
        'bangumiId: $bangumiId, '
        'type: $type, '
        'liked: $liked, '
        'isBangumi: $isBangumi, '
        'firstClickTime: $firstClickTime, '
        'lastClickTime: $lastClickTime, '
        'commentCount: ${comment.length}, '
        'totalClickCount: ${totalClickCount.length}, '
        'totalWatchDurations: ${totalWatchDurations.length}, '
        'ratingCount: ${rating.length}, '
        'favorite: ${favorite.length}'
        ')';
  }
}

class StatsManager with ChangeNotifier {
  static StatsManager? cache;

  StatsManager.create();

  factory StatsManager() =>
      cache == null ? (cache = StatsManager.create()) : cache!;

  late Database _db;

  bool isInitialized = false;

  Future<void> init() async {
    if (isInitialized) {
      return;
    }
    _db = sqlite3.open("${App.dataPath}/stats.db");

    _db.execute("""
      create table if not exists stats (
        id text primary key,
        title text,
        cover text,
        bangumiId int,
        type int,
        liked int,
        comment text,
        totalClickCount text,
        firstClickTime text,
        lastClickTime text,
        totalWatchDurations text,
        rating text,
        favorite text,
        isBangumi int
      );
    """);

    //   var columns = _db.select("""
    //       pragma table_info("stats");
    //     """);
    //   if (!columns.any((element) => element["name"] == "isBangumi")) {
    //     _db.execute("""
    //   alter table stats
    //   add column isBangumi integer not null default 0;
    // """);
    //   }

    notifyListeners();
  }

  StatsDataImpl createStatsData({
    required String id,
    String? title,
    String? cover,
    int? bangumiId,
    bool? isBangumi,
    required int type,
  }) {
    final now = DateTime.now();
    return StatsDataImpl(
      id: id,
      title: title,
      cover: cover,
      bangumiId: bangumiId,
      type: type,
      liked: false,
      isBangumi: isBangumi ?? false,
      comment: [],
      totalClickCount: [],
      firstClickTime: now,
      lastClickTime: now,
      totalWatchDurations: [],
      rating: [],
      favorite: [],
    );
  }

  static const _insertStatsSql = """
      insert or replace into stats (
        id,
        title,
        cover,
        bangumiId,
        type,
        liked,
        comment,
        totalClickCount,
        firstClickTime,
        lastClickTime,
        totalWatchDurations,
        rating,
        favorite,
        isBangumi
      )
      values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """;

  Future<void> addStats(StatsData newItem) async {
    _modifiedAfterLastCache = true;
    _db.execute(_insertStatsSql, [
      newItem.id,
      newItem.title,
      newItem.cover,
      newItem.bangumiId,
      newItem.type,
      newItem.liked ? 1 : 0,
      jsonEncode(newItem.comment.map((e) => e.toJson()).toList()),
      jsonEncode(newItem.totalClickCount.map((e) => e.toJson()).toList()),
      newItem.firstClickTime?.toIso8601String(),
      newItem.lastClickTime?.toIso8601String(),
      jsonEncode(newItem.totalWatchDurations.map((e) => e.toJson()).toList()),
      jsonEncode(newItem.rating.map((e) => e.toJson()).toList()),
      jsonEncode(newItem.favorite.map((e) => e.toJson()).toList()),
      newItem.isBangumi ? 1 : 0,
    ]);

    notifyListeners();
  }

  StatsDataImpl? getStatsByIdAndType({required String id, required int type}) {
    final ResultSet result = _db.select(
      'SELECT * FROM stats WHERE id == ? AND type == ?;',
      [id, type],
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;

    return StatsDataImpl.fromRow(row);
  }

  List<StatsDataImpl> getStatsAll() {
    final result = _db.select("SELECT * FROM stats");
    if (result.isEmpty) return [];
    final selectors = appdata.settings['statsSelectors'];
    if (selectors == null || selectors == []) {
      return result.map((row) {
        return StatsDataImpl.fromRow(row);
      }).toList();
    } else {
      final selectorList = List<int>.from(selectors);

      return result
          .map((row) => StatsDataImpl.fromRow(row))
          .where((stats) => !selectorList.contains(stats.type))
          .toList();
    }
  }

  Future<Map<DateTime, List<StatsDataImpl>>> getEventMap() async {
    final allStats = getStatsAll();
    final map = <DateTime, List<StatsDataImpl>>{};

    for (var stats in allStats) {
      final allEvents = <DailyEvent>[];
      allEvents.addAll(stats.comment);
      allEvents.addAll(stats.totalClickCount);
      allEvents.addAll(stats.totalWatchDurations);
      allEvents.addAll(stats.rating);
      allEvents.addAll(stats.favorite);

      final uniqueDates = allEvents.map((e) => e.date).toSet();

      for (var date in uniqueDates) {
        map.putIfAbsent(date, () => []).add(stats);
      }
    }

    return map;
  }

  ///更新喜欢事件
  Future<void> updateStatsLiked(String id, int type, bool liked) async {
    _db.execute("update stats set liked = ? where id = ? and type = ?", [
      liked ? 1 : 0,
      id,
      type,
    ]);

    notifyListeners();
  }

  ///更新bangumiId
  Future<void> updateStatsBangumiId(String id, int type, int? bangumiId) async {
    if (bangumiId == null) return;
    _db.execute("update stats set bangumiId = ? where id = ? and type = ?", [
      bangumiId,
      id,
      type,
    ]);

    notifyListeners();
  }

  ///更新观看事件
  Future<void> updateStatsWatch({
    required String id,
    required int type,
    required List<DailyEvent> totalWatchDurations,
  }) async {
    try {
      _db.execute(
        "update stats set totalWatchDurations = ? where id = ? and type = ?",
        [
          jsonEncode(totalWatchDurations.map((e) => e.toJson()).toList()),
          id,
          type,
        ],
      );
      notifyListeners();
    } catch (e) {
      Log.addLog(LogLevel.error, 'updateStatsWatch', e.toString());
    }
  }

  ///更新收藏事件
  Future<void> updateStatsFavorite({
    required String id,
    required int type,
    required List<DailyEvent> favorite,
  }) async {
    try {
      _db.execute("update stats set favorite = ? where id = ? and type = ?", [
        jsonEncode(favorite.map((e) => e.toJson()).toList()),
        id,
        type,
      ]);
      notifyListeners();
    } catch (e) {
      Log.addLog(LogLevel.error, 'updateStatsFavorite', e.toString());
    }
  }

  /// 同时更新评分和评论
  Future<void> updateStatsRatingAndComment(
    String id,
    int type, {
    List<DailyEvent>? rating,
    List<DailyEvent>? comment,
  }) async {
    final updates = <String>[];
    final values = <dynamic>[];

    if (rating != null) {
      updates.add("rating = ?");
      values.add(jsonEncode(rating.map((e) => e.toJson()).toList()));
    }

    if (comment != null) {
      updates.add("comment = ?");
      values.add(jsonEncode(comment.map((e) => e.toJson()).toList()));
    }

    if (updates.isEmpty) return;

    final sql =
        "UPDATE stats SET ${updates.join(', ')} WHERE id = ? AND type = ?";
    values.addAll([id, type]);

    _db.execute(sql, values);
    notifyListeners();
  }

  ///获取除传入项外同个bangumiId一个时间之前的所有观看时间总和
  int getOtherBangumiTotalWatch({
    required StatsDataImpl current,
    required DateTime time,
  }) {
    final allStats = getStatsAll();
    int total = 0;

    final compareTime = time.toUtc();

    for (var stats in allStats) {
      if (stats.bangumiId == current.bangumiId &&
          (stats.id != current.id || stats.type != current.type)) {
        for (var daily in stats.totalWatchDurations) {
          for (var record in daily.platformEventRecords) {
            if (record.date != null) {
              final recordTime = record.date!.toUtc();
              if (recordTime.isBefore(compareTime)) {
                total += record.value;
                debugPrint(
                  'Adding ${record.value} from ${stats.id} on ${record.date}',
                );
              } else {
                debugPrint(
                  'Skipping ${record.value} from ${stats.id} on ${record.date}',
                );
              }
            }
          }
        }
      }
    }

    debugPrint('Total watch duration for other bangumi: $total');
    return total;
  }

  String? getLatestComment({required StatsDataImpl current}) {
    final allStats = getStatsAll();

    String? latestComment;
    DateTime? latestDate;

    for (var stats in allStats) {
      if (stats.bangumiId == current.bangumiId &&
          (stats.id != current.id || stats.type != current.type)) {
        for (var daily in stats.comment) {
          for (var record in daily.platformEventRecords) {
            if (record.comment != null &&
                record.comment!.isNotEmpty &&
                record.date != null) {
              if (latestDate == null || record.date!.isAfter(latestDate)) {
                latestDate = record.date!;
                latestComment = record.comment!;
              }
            }
          }
        }
      }
    }

    return latestComment;
  }

  int? getLatestRating({required StatsDataImpl current}) {
    final allStats = getStatsAll();

    int? latestRating;
    DateTime? latestDate;

    for (var stats in allStats) {
      if (stats.bangumiId == current.bangumiId &&
          (stats.id != current.id || stats.type != current.type)) {
        for (var daily in stats.rating) {
          for (var record in daily.platformEventRecords) {
            if (record.rating != null && record.date != null) {
              if (latestDate == null || record.date!.isAfter(latestDate)) {
                latestDate = record.date!;
                latestRating = record.rating!;
              }
            }
          }
        }
      }
    }

    return latestRating;
  }

  final _cachedStatsIds = <String, bool>{};

  bool _modifiedAfterLastCache = true;

  bool isExist(String id, AnimeType type) {
    if (_modifiedAfterLastCache) {
      _cacheStatsIds();
    }
    return _cachedStatsIds.containsKey("$id@${type.value}");
  }

  void _cacheStatsIds() {
    _modifiedAfterLastCache = false;
    _cachedStatsIds.clear();
    var rows = _db.select("""
        select id, type from stats;
      """);
    for (var row in rows) {
      _cachedStatsIds["${row["id"]}@${row["type"]}"] = true;
    }
  }

  void close() {
    _db.dispose();
  }
}

extension StatsHelper on StatsManager {
  /// 获取指定 animeId/sourceKey 对应的统计，并保证今天的平台记录存在
  (StatsDataImpl, DailyEvent, PlatformEventRecord)
  getOrCreateTodayPlatformRecord({
    required String id,
    required int type,
    required DailyEventType targetType,
  }) {
    final statsDataImpl = (getStatsByIdAndType(id: id, type: type))!;
    final todayStr = DateTime.now().yyyymmdd;

    // 获取目标类型的列表
    final targetList = targetType.getList(statsDataImpl);

    // 获取当天 DailyEvent（click/watch）或最新 DailyEvent（comment/rating）
    DailyEvent getTargetDailyEvent() {
      if (targetType == DailyEventType.comment ||
          targetType == DailyEventType.rating) {
        if (targetList.isEmpty) {
          final newEvent = DailyEvent(
            dateStr: todayStr,
            platformEventRecords: [],
          );
          targetList.add(newEvent);
          return newEvent;
        } else {
          return targetList.last;
        }
      } else {
        return targetList.firstWhere(
          (e) => e.date.yyyymmdd == todayStr,
          orElse: () {
            final newEvent = DailyEvent(
              dateStr: todayStr,
              platformEventRecords: [],
            );
            targetList.add(newEvent);
            return newEvent;
          },
        );
      }
    }

    // 获取当天平台记录，如果不存在就创建
    PlatformEventRecord getOrCreatePlatformRecord(
      DailyEvent todayEvent,
      DailyEventType targetType,
    ) {
      // 如果是 comment 或 rating，只取最新，不创建
      if (targetType == DailyEventType.comment ||
          targetType == DailyEventType.rating) {
        if (todayEvent.platformEventRecords.isEmpty) {
          final now = DateTime.now();
          final newRecord = PlatformEventRecord(
            value: 0,
            platform: AppPlatform.current,
            comment: targetType == DailyEventType.comment ? '' : null,
            rating: targetType == DailyEventType.rating ? 0 : null,
            favorite: targetType == DailyEventType.favorite ? '' : null,
            favoriteType: null,
            favoriteAction: null,
            dateStr: now.yyyymmddHHmmss,
          );
          todayEvent.platformEventRecords.add(newRecord);
          return newRecord;
        }
        // 取 date 最新的
        return todayEvent.platformEventRecords.reduce((a, b) {
          final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ad.isAfter(bd) ? a : b;
        });
      }

      // 其他类型（click / watch）：如果不存在则创建
      return todayEvent.platformEventRecords.firstWhere(
        (p) => p.platform == AppPlatform.current,
        orElse: () {
          final now = DateTime.now();
          final newRecord = PlatformEventRecord(
            value: 0,
            platform: AppPlatform.current,
            comment: null,
            rating: null,
            favorite: null,
            favoriteType: null,
            favoriteAction: null,
            dateStr: now.yyyymmddHHmmss,
          );
          todayEvent.platformEventRecords.add(newRecord);
          return newRecord;
        },
      );
    }

    final todayRecord = getTargetDailyEvent();
    final platformRecord = getOrCreatePlatformRecord(todayRecord, targetType);

    return (statsDataImpl, todayRecord, platformRecord);
  }

  ///初始化全部
  TodayEventBundle getOrCreateTodayEvents({
    required String id,
    required int type,
  }) {
    final statsData = (getStatsByIdAndType(id: id, type: type))!;
    final todayStr = DateTime.now().yyyymmdd;

    DailyEvent getOrCreateDailyEvent(List<DailyEvent> list) {
      return list.firstWhere(
        (e) => e.date.yyyymmdd == todayStr,
        orElse: () {
          final newEvent = DailyEvent(
            dateStr: todayStr,
            platformEventRecords: [],
          );
          list.add(newEvent);
          return newEvent;
        },
      );
    }

    PlatformEventRecord getOrCreatePlatformRecord(DailyEvent event) {
      return event.platformEventRecords.firstWhere(
        (p) => p.platform == AppPlatform.current,
        orElse: () {
          final now = DateTime.now();
          final newRecord = PlatformEventRecord(
            value: 0,
            platform: AppPlatform.current,
            comment: null,
            rating: null,
            favorite: null,
            favoriteType: null,
            favoriteAction: null,
            dateStr: now.yyyymmddHHmmss,
          );
          event.platformEventRecords.add(newRecord);
          return newRecord;
        },
      );
    }

    DailyEvent getLatestOrCreateDailyEvent(List<DailyEvent> list) {
      if (list.isNotEmpty) {
        return list.last;
      } else {
        final todayStr = DateTime.now().yyyymmdd;
        final newEvent = DailyEvent(
          dateStr: todayStr,
          platformEventRecords: [],
        );
        list.add(newEvent);
        return newEvent;
      }
    }

    PlatformEventRecord getLatestPlatformRecord(
      DailyEvent event, {
      bool initComment = false,
      bool initRating = false,
      bool initFavorite = false,
    }) {
      if (event.platformEventRecords.isNotEmpty) {
        // 取 date 最新的记录
        return event.platformEventRecords.reduce((a, b) {
          final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ad.isAfter(bd) ? a : b;
        });
      } else {
        // 列表为空时才创建（精确到秒）
        final now = DateTime.now();
        final newRecord = PlatformEventRecord(
          value: 0,
          platform: AppPlatform.current,
          comment: initComment ? '' : null,
          rating: initRating ? 0 : null,
          favorite: initFavorite ? '' : null,
          favoriteType: null,
          favoriteAction: null,
          dateStr: now.yyyymmddHHmmss,
        );
        event.platformEventRecords.add(newRecord);
        return newRecord;
      }
    }

    // click / watch
    final todayClick = getOrCreateDailyEvent(statsData.totalClickCount);
    final clickRecord = getOrCreatePlatformRecord(todayClick);

    final todayWatch = getOrCreateDailyEvent(statsData.totalWatchDurations);
    final watchRecord = getOrCreatePlatformRecord(todayWatch);

    // comment / rating
    final todayComment = getLatestOrCreateDailyEvent(statsData.comment);
    final commentRecord = getLatestPlatformRecord(
      todayComment,
      initComment: true,
    );

    final todayRating = getLatestOrCreateDailyEvent(statsData.rating);
    final ratingRecord = getLatestPlatformRecord(todayRating, initRating: true);

    final todayFavorite = getLatestOrCreateDailyEvent(statsData.favorite);
    final favoriteRecord = getLatestPlatformRecord(
      todayFavorite,
      initFavorite: true,
    );

    return TodayEventBundle(
      statsData: statsData,
      todayComment: todayComment,
      commentRecord: commentRecord,
      todayClick: todayClick,
      clickRecord: clickRecord,
      todayWatch: todayWatch,
      watchRecord: watchRecord,
      todayRating: todayRating,
      ratingRecord: ratingRecord,
      todayFavorite: todayFavorite,
      favoriteRecord: favoriteRecord,
    );
  }

  void addFavoriteRecord({
    required String id,
    required int type,
    required String folder,
    required FavoriteAction action,
  }) {
    final manager = StatsManager();

    if (!manager.isExist(id, AnimeType(type))) {
      try {
        final history = HistoryManager().find(id, AnimeType(type));
        final favorite = LocalFavoritesManager().findAnime(id, AnimeType(type));
        if (history != null) {
          manager.addStats(
            manager.createStatsData(
              id: id,
              title: history.title,
              cover: history.cover,
              type: type,
            ),
          );
        } else if (favorite != null) {
          manager.addStats(
            manager.createStatsData(
              id: id,
              title: favorite.title,
              cover: favorite.cover,
              type: type,
            ),
          );
        } else {
          manager.addStats(manager.createStatsData(id: id, type: type));
        }
      } catch (e) {
        Log.addLog(LogLevel.error, 'addStats', e.toString());
      }
    }

    final (statsDataImpl, todayFavorite, _) = manager
        .getOrCreateTodayPlatformRecord(
          id: id,
          type: type,
          targetType: DailyEventType.favorite,
        );

    final newFavoriteRecord = PlatformEventRecord(
      value: 0,
      platform: AppPlatform.current,
      favorite: folder,
      dateStr: DateTime.now().yyyymmddHHmmss,
      favoriteAction: action,
    );

    todayFavorite.platformEventRecords.add(newFavoriteRecord);
    todayFavorite.platformEventRecords.removeWhere(
      (p) =>
          p.favoriteAction == null &&
          p.favorite == null &&
          p.favoriteType == null,
    );

    manager.updateStatsFavorite(
      id: id,
      type: type,
      favorite: statsDataImpl.favorite,
    );
  }
}
