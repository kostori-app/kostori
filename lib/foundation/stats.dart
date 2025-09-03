import 'dart:convert';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:sqlite3/sqlite3.dart';

import 'anime_type.dart';
import 'app.dart';

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
  rating;

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
  });
}

extension DateTimeFormat on DateTime {
  String get yyyymmdd {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }
}

class PlatformEventRecord {
  int value;
  AppPlatform? platform;
  String? comment;
  int? rating;

  PlatformEventRecord({
    required this.value,
    this.platform,
    this.comment,
    this.rating,
  });

  /// 序列化成
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'value': value, 'platform': platform?.value};

    if (comment != null) {
      map['comment'] = comment;
    }
    if (rating != null) {
      map['rating'] = rating;
    }

    return map;
  }

  /// 从 JSON 反序列化
  factory PlatformEventRecord.fromJson(Map<String, dynamic> json) {
    return PlatformEventRecord(
      value: json['value'] as int,
      platform: json['platform'] != null
          ? AppPlatform.fromString(json['platform'] as String)
          : null,
      comment: json['comment'] != null ? json['comment'] as String : null,
      rating: json['rating'] != null ? json['rating'] as int : null,
    );
  }

  @override
  String toString() =>
      'PlatformEventRecord(value: $value, platform: ${platform?.value}, comment: $comment, rating: $rating)';
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

  StatsDataImpl({
    required this.id,
    this.title,
    this.cover,
    this.bangumiId,
    required this.type,
    this.liked = false,
    List<DailyEvent>? comment,
    List<DailyEvent>? totalClickCount,
    this.firstClickTime,
    this.lastClickTime,
    List<DailyEvent>? totalWatchDurations,
    List<DailyEvent>? rating,
  }) : comment = comment ?? [],
       totalClickCount = totalClickCount ?? [],
       totalWatchDurations = totalWatchDurations ?? [],
       rating = rating ?? [];

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
      comment: parseList(row['comment'] as String?),
      totalClickCount: parseList(row['totalClickCount'] as String?),
      totalWatchDurations: parseList(row['totalWatchDurations'] as String?),
      rating: parseList(row['rating'] as String?),
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
      comment: parseList(map['comment'] as List<dynamic>?),
      totalClickCount: parseList(map['totalClickCount'] as List<dynamic>?),
      totalWatchDurations: parseList(
        map['totalWatchDurations'] as List<dynamic>?,
      ),
      rating: parseList(map['rating'] as List<dynamic>?),
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
    'firstClickTime': firstClickTime?.toIso8601String(),
    'lastClickTime': lastClickTime?.toIso8601String(),
  };

  @override
  String toString() {
    return 'StatsDataImpl(id: $id, title: $title, type: $type, liked: $liked, firstClickTime: $firstClickTime, lastClickTime: $lastClickTime, ratingCount: ${rating.length})';
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
        rating text
      );
    """);

    notifyListeners();
  }

  StatsDataImpl createStatsData({
    required String id,
    required String? title,
    required String? cover,
    int? bangumiId,
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
      comment: [],
      totalClickCount: [],
      firstClickTime: now,
      lastClickTime: now,
      totalWatchDurations: [],
      rating: [],
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
        rating
      )
      values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
    ]);

    notifyListeners();
  }

  Future<StatsDataImpl?> getStatsByIdAndType({
    required String id,
    required int type,
  }) async {
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

  Future<List<StatsDataImpl>> getStatsAll() async {
    final result = _db.select("SELECT * FROM stats");
    if (result.isEmpty) return [];

    return result.map((row) {
      return StatsDataImpl.fromRow(row);
    }).toList();
  }

  Future<void> updateStatsLiked(String id, int type, bool liked) async {
    _db.execute("update stats set liked = ? where id = ? and type = ?", [
      liked ? 1 : 0,
      id,
      type,
    ]);

    notifyListeners();
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
  Future<(StatsDataImpl, DailyEvent, PlatformEventRecord)>
  getOrCreateTodayPlatformRecord({
    required String id,
    required int type,
    required DailyEventType targetType,
  }) async {
    final statsDataImpl = (await getStatsByIdAndType(id: id, type: type))!;

    final todayStr = DateTime.now().yyyymmdd;

    // 直接用 enum 的扩展方法获取列表
    final targetList = targetType.getList(statsDataImpl);

    // 找到今天的记录，如果没有就创建
    final todayRecord = targetList.firstWhere(
      (c) => c.date.yyyymmdd == todayStr,
      orElse: () {
        final newEvent = DailyEvent(
          dateStr: todayStr,
          platformEventRecords: [],
        );
        targetList.add(newEvent);
        return newEvent;
      },
    );

    // 找到当前平台的记录，如果没有就创建
    PlatformEventRecord getOrCreatePlatformRecord(
      DailyEvent todayEvent,
      DailyEventType type,
    ) {
      return todayEvent.platformEventRecords.firstWhere(
        (p) => p.platform == AppPlatform.current,
        orElse: () {
          final newRecord = PlatformEventRecord(
            value: 0,
            platform: AppPlatform.current,
            comment: (type == DailyEventType.comment) ? '' : null,
            rating: (type == DailyEventType.rating) ? 0 : null,
          );
          todayEvent.platformEventRecords.add(newRecord);
          return newRecord;
        },
      );
    }

    return (
      statsDataImpl,
      todayRecord,
      getOrCreatePlatformRecord(todayRecord, targetType),
    );
  }

  ///初始化全部
  Future<TodayEventBundle> getOrCreateTodayEvents({
    required String id,
    required int type,
  }) async {
    final statsData = (await getStatsByIdAndType(id: id, type: type))!;

    final todayStr = DateTime.now().yyyymmdd;

    DailyEvent getOrCreate(DailyEventType typeEnum) {
      final list = typeEnum.getList(statsData);
      final todayEvent = list.firstWhere(
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
      return todayEvent;
    }

    PlatformEventRecord getOrCreatePlatform(
      DailyEvent todayEvent, {
      bool initComment = false,
      bool initRating = false,
    }) {
      return todayEvent.platformEventRecords.firstWhere(
        (p) => p.platform == AppPlatform.current,
        orElse: () {
          final newRecord = PlatformEventRecord(
            value: 0,
            platform: AppPlatform.current,
            comment: initComment ? '' : null,
            rating: initRating ? 0 : null,
          );
          todayEvent.platformEventRecords.add(newRecord);
          return newRecord;
        },
      );
    }

    final todayComment = getOrCreate(DailyEventType.comment);
    final commentRecord = getOrCreatePlatform(todayComment, initComment: true);

    final todayClick = getOrCreate(DailyEventType.click);
    final clickRecord = getOrCreatePlatform(todayClick);

    final todayWatch = getOrCreate(DailyEventType.watch);
    final watchRecord = getOrCreatePlatform(todayWatch);

    final todayRating = getOrCreate(DailyEventType.rating);
    final ratingRecord = getOrCreatePlatform(todayRating, initRating: true);

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
    );
  }
}
