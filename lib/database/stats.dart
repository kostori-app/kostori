import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/utils/ext.dart';
import 'package:path/path.dart' as p;

part 'stats.g.dart';

// ═══════════════════════════════════════════════════════════
// 枚举 / 数据类（不变）
// ═══════════════════════════════════════════════════════════

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

  static AppPlatform fromString(String value) {
    for (var platform in values) {
      if (platform.value == value) return platform;
    }
    return AppPlatform.android;
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
  String get yyyymmdd =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  String get yyyymmddHHmmss =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')} '
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:'
      '${second.toString().padLeft(2, '0')}';

  String get hhmmss =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:'
      '${second.toString().padLeft(2, '0')}';
}

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

enum FavoriteType {
  wantWatch("wish"),
  watching("doing"),
  watched("collect"),
  paused("on hold"),
  dropped("dropped");

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

  static DateTime _parseDate(String dateStr) {
    final regexSecond = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');
    if (regexSecond.hasMatch(dateStr)) {
      return DateTime.parse(dateStr.replaceFirst(' ', 'T'));
    } else {
      throw FormatException(
        'Invalid date format, expected yyyy-MM-dd HH:mm:ss',
      );
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'value': value, 'platform': platform?.value};
    if (comment != null) map['comment'] = comment;
    if (rating != null) map['rating'] = rating;
    if (date != null) {
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

  static DateTime _parseDate(String dateStr) {
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(dateStr)) {
      throw FormatException('Invalid date format, expected yyyy-MM-dd');
    }
    return DateTime.parse(dateStr);
  }

  factory DailyEvent.fromJson(Map<String, dynamic> json) => DailyEvent(
    dateStr: json['date'] as String,
    platformEventRecords: (json['platformEventRecords'] as List)
        .map((e) => PlatformEventRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

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
  String get id;

  String? get title;

  String? get cover;

  int? get bangumiId;

  int get type;

  bool get liked;

  bool get isBangumi;

  List<DailyEvent> get comment;

  List<DailyEvent> get totalClickCount;

  DateTime? get firstClickTime;

  DateTime? get lastClickTime;

  List<DailyEvent> get totalWatchDurations;

  List<DailyEvent> get rating;

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

  static List<DailyEvent> _parseList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => DailyEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 从 Drift 生成的数据行创建实例
  factory StatsDataImpl.fromDrift(StatsTableData row) {
    return StatsDataImpl(
      id: row.id,
      title: row.title,
      cover: row.cover,
      bangumiId: row.bangumiId,
      type: row.type,
      liked: row.liked,
      isBangumi: row.isBangumi,
      comment: _parseList(row.comment),
      totalClickCount: _parseList(row.totalClickCount),
      totalWatchDurations: _parseList(row.totalWatchDurations),
      rating: _parseList(row.rating),
      favorite: _parseList(row.favorite),
      firstClickTime: row.firstClickTime != null
          ? DateTime.parse(row.firstClickTime!)
          : null,
      lastClickTime: row.lastClickTime != null
          ? DateTime.parse(row.lastClickTime!)
          : null,
    );
  }

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
  String toString() =>
      'StatsDataImpl(id: $id, title: $title, type: $type, '
      'liked: $liked, isBangumi: $isBangumi)';
}

// ═══════════════════════════════════════════════════════════
// Drift 表定义（列名用 .named() 保持 camelCase，兼容旧数据库）
// ═══════════════════════════════════════════════════════════

class StatsTable extends Table {
  @override
  String get tableName => 'stats';

  TextColumn get id => text()();

  TextColumn get title => text().nullable()();

  TextColumn get cover => text().nullable()();

  IntColumn get bangumiId => integer().named('bangumiId').nullable()();

  IntColumn get type => integer()();

  BoolColumn get liked =>
      boolean().named('liked').withDefault(const Constant(false))();

  BoolColumn get isBangumi =>
      boolean().named('isBangumi').withDefault(const Constant(false))();

  TextColumn get comment => text().named('comment').nullable()();

  TextColumn get totalClickCount =>
      text().named('totalClickCount').nullable()();

  TextColumn get firstClickTime => text().named('firstClickTime').nullable()();

  TextColumn get lastClickTime => text().named('lastClickTime').nullable()();

  TextColumn get totalWatchDurations =>
      text().named('totalWatchDurations').nullable()();

  TextColumn get rating => text().named('rating').nullable()();

  TextColumn get favorite => text().named('favorite').nullable()();

  @override
  Set<Column> get primaryKey => {id, type};
}

// ═══════════════════════════════════════════════════════════
// 数据库
// ═══════════════════════════════════════════════════════════

@DriftDatabase(tables: [StatsTable])
class _StatsDb extends _$_StatsDb {
  _StatsDb() : super(_openConn());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

LazyDatabase _openConn() => LazyDatabase(() async {
  final file = File(p.join(App.dataPath, 'stats.db'));
  return NativeDatabase.createInBackground(file);
});

// ═══════════════════════════════════════════════════════════
// StatsManager
// ═══════════════════════════════════════════════════════════

class StatsManager {
  static StatsManager? _cache;

  StatsManager._();

  factory StatsManager() => _cache ??= StatsManager._();

  late _StatsDb _db;
  bool isInitialized = false;

  final _cachedStatsIds = <String, bool>{};
  bool _modifiedAfterLastCache = true;

  Future<void> init() async {
    if (isInitialized) return;
    _db = _StatsDb();
    isInitialized = true;
  }

  void close() {
    _db.close();
    _cache = null;
    isInitialized = false;
  }

  // ─── 工具 ──────────────────────────────────

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
      firstClickTime: now,
      lastClickTime: now,
    );
  }

  StatsTableCompanion _toCompanion(StatsData s) => StatsTableCompanion.insert(
    id: s.id,
    type: s.type,
    title: Value(s.title),
    cover: Value(s.cover),
    bangumiId: Value(s.bangumiId),
    liked: Value(s.liked),
    isBangumi: Value(s.isBangumi),
    comment: Value(jsonEncode(s.comment.map((e) => e.toJson()).toList())),
    totalClickCount: Value(
      jsonEncode(s.totalClickCount.map((e) => e.toJson()).toList()),
    ),
    totalWatchDurations: Value(
      jsonEncode(s.totalWatchDurations.map((e) => e.toJson()).toList()),
    ),
    rating: Value(
      s.rating.isNotEmpty
          ? jsonEncode(s.rating.map((e) => e.toJson()).toList())
          : null,
    ),
    favorite: Value(
      s.favorite.isNotEmpty
          ? jsonEncode(s.favorite.map((e) => e.toJson()).toList())
          : null,
    ),
    firstClickTime: Value(s.firstClickTime?.toIso8601String()),
    lastClickTime: Value(s.lastClickTime?.toIso8601String()),
  );

  // ─── 写入 ──────────────────────────────────

  Future<void> addStats(StatsData newItem) async {
    _modifiedAfterLastCache = true;
    final c = _toCompanion(newItem);
    await _db.customInsert(
      '''INSERT OR REPLACE INTO stats
       (id, title, cover, bangumiId, type, liked, isBangumi, comment,
        totalClickCount, firstClickTime, lastClickTime,
        totalWatchDurations, rating, favorite)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      variables: [
        Variable(c.id.value),
        Variable(c.title.value),
        Variable(c.cover.value),
        Variable(c.bangumiId.value),
        Variable(c.type.value),
        Variable(c.liked.value),
        Variable(c.isBangumi.value),
        Variable(c.comment.value),
        Variable(c.totalClickCount.value),
        Variable(c.firstClickTime.value),
        Variable(c.lastClickTime.value),
        Variable(c.totalWatchDurations.value),
        Variable(c.rating.value),
        Variable(c.favorite.value),
      ],
      updates: {_db.statsTable},
    );
  }

  Future<void> updateStats({
    required String id,
    required int type,
    bool? liked,
    int? bangumiId,
    List<DailyEvent>? totalWatchDurations,
    List<DailyEvent>? favorite,
    List<DailyEvent>? rating,
    List<DailyEvent>? comment,
  }) async {
    final companion = StatsTableCompanion(
      liked: liked != null ? Value(liked) : const Value.absent(),
      bangumiId: bangumiId != null ? Value(bangumiId) : const Value.absent(),
      totalWatchDurations: totalWatchDurations != null
          ? Value(
              jsonEncode(totalWatchDurations.map((e) => e.toJson()).toList()),
            )
          : const Value.absent(),
      favorite: favorite != null
          ? Value(jsonEncode(favorite.map((e) => e.toJson()).toList()))
          : const Value.absent(),
      rating: rating != null
          ? Value(jsonEncode(rating.map((e) => e.toJson()).toList()))
          : const Value.absent(),
      comment: comment != null
          ? Value(jsonEncode(comment.map((e) => e.toJson()).toList()))
          : const Value.absent(),
    );

    await (_db.update(
      _db.statsTable,
    )..where((t) => t.id.equals(id) & t.type.equals(type))).write(companion);
  }

  Future<void> updateGroupLiked({
    required String id,
    required int type,
    required bool targetLiked,
  }) async {
    final current = await getStatsByIdAndType(id: id, type: type);
    if (current == null) return;

    if (targetLiked) {
      await (_db.update(_db.statsTable)
            ..where((t) => t.id.equals(id) & t.type.equals(type)))
          .write(const StatsTableCompanion(liked: Value(true)));
    } else {
      if (current.bangumiId != null) {
        await (_db.update(_db.statsTable)
              ..where((t) => t.bangumiId.equals(current.bangumiId!)))
            .write(const StatsTableCompanion(liked: Value(false)));
      } else {
        await (_db.update(_db.statsTable)
              ..where((t) => t.id.equals(id) & t.type.equals(type)))
            .write(const StatsTableCompanion(liked: Value(false)));
      }
    }
  }

  // ─── 查询 ──────────────────────────────────

  Future<StatsDataImpl?> getStatsByIdAndType({
    required String id,
    required int type,
  }) async {
    final row = await (_db.select(
      _db.statsTable,
    )..where((t) => t.id.equals(id) & t.type.equals(type))).getSingleOrNull();
    return row != null ? StatsDataImpl.fromDrift(row) : null;
  }

  Future<List<StatsDataImpl>> getStatsAll() async {
    final rows = await _db.select(_db.statsTable).get();
    final all = rows.map(StatsDataImpl.fromDrift).toList();
    final selectors = appdata.settings['statsSelectors'];
    if (selectors == null || (selectors as List).isEmpty) return all;
    final selectorList = List<int>.from(selectors);
    return all.where((s) => !selectorList.contains(s.type)).toList();
  }

  Stream<List<StatsDataImpl>> watchAll() {
    return _db
        .select(_db.statsTable)
        .watch()
        .map((rows) => rows.map(StatsDataImpl.fromDrift).toList());
  }

  Future<bool> getGroupLikedStatus({
    required String id,
    required int type,
  }) async {
    final item = await getStatsByIdAndType(id: id, type: type);
    if (item == null) return false;
    if (item.liked) return true;
    if (item.bangumiId != null) {
      final count =
          await (_db.select(_db.statsTable)..where(
                (t) =>
                    t.bangumiId.equals(item.bangumiId!) &
                    t.id.equals(id).not() &
                    t.liked.equals(true),
              ))
              .get();
      return count.isNotEmpty;
    }
    return false;
  }

  Future<Map<DateTime, List<StatsDataImpl>>> getEventMap() async {
    final allStats = await getStatsAll();
    final map = <DateTime, List<StatsDataImpl>>{};
    for (var stats in allStats) {
      final allEvents = <DailyEvent>[
        ...stats.comment,
        ...stats.totalClickCount,
        ...stats.totalWatchDurations,
        ...stats.rating,
        ...stats.favorite,
      ];
      for (var date in allEvents.map((e) => e.date).toSet()) {
        map.putIfAbsent(date, () => []).add(stats);
      }
    }
    return map;
  }

  int getOtherBangumiTotalWatch({
    required StatsDataImpl current,
    required DateTime time,
  }) {
    // 同步版本：调用方需确保已有缓存数据，或改为 async
    throw UnimplementedError('Use getOtherBangumiTotalWatchAsync instead');
  }

  Future<int> getOtherBangumiTotalWatchAsync({
    required StatsDataImpl current,
    required DateTime time,
  }) async {
    final allStats = await getStatsAll();
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
              }
            }
          }
        }
      }
    }
    return total;
  }

  Future<String?> getLatestComment({required StatsDataImpl current}) async {
    final allStats = await getStatsAll();
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

  Future<Map<int, List<int>>> getRatingsWithBangumiIds() async {
    final allStats = await getStatsAll();
    final int bangumiKey = 'bangumi'.hashCode;
    final Map<int?, List<StatsDataImpl>> groups = {};
    for (final s in allStats) {
      groups.putIfAbsent(s.bangumiId, () => []).add(s);
    }
    final Map<int, Set<int>> resultSet = {for (var i = 1; i <= 10; i++) i: {}};
    for (final entry in groups.entries) {
      final bangumiId = entry.key;
      if (bangumiId == null) continue;
      final statsList = entry.value;
      int? rating;
      final bangumiStat = statsList.firstWhereOrNull(
        (s) => s.type == bangumiKey,
      );
      if (bangumiStat != null) {
        rating = _getLatestRatingFromStats(bangumiStat);
      } else {
        for (final s in statsList) {
          rating = _getLatestRatingFromStats(s);
          if (rating != null) break;
        }
      }
      if (rating != null && rating >= 1 && rating <= 10) {
        resultSet[rating]!.add(bangumiId);
      }
    }
    return resultSet.map((k, v) => MapEntry(k, v.toList()));
  }

  int? _getLatestRatingFromStats(StatsDataImpl stats) {
    DateTime? latestDate;
    int? latestRating;
    for (final daily in stats.rating) {
      for (final record in daily.platformEventRecords) {
        if (record.rating != null && record.date != null) {
          if (latestDate == null || record.date!.isAfter(latestDate)) {
            latestDate = record.date!;
            latestRating = record.rating;
          }
        }
      }
    }
    return latestRating;
  }

  Future<bool> isExistAsync(String id, AnimeType type) async {
    if (_modifiedAfterLastCache) await _cacheStatsIds();
    return _cachedStatsIds.containsKey("$id@${type.value}");
  }

  bool isExist(String id, AnimeType type) {
    // 同步版：依赖缓存，需确保 _cacheStatsIds 已执行
    return _cachedStatsIds.containsKey("$id@${type.value}");
  }

  Future<void> _cacheStatsIds() async {
    _modifiedAfterLastCache = false;
    _cachedStatsIds.clear();
    final rows = await (_db.selectOnly(
      _db.statsTable,
    )..addColumns([_db.statsTable.id, _db.statsTable.type])).get();
    for (final row in rows) {
      final id = row.read(_db.statsTable.id);
      final type = row.read(_db.statsTable.type);
      if (id != null && type != null) {
        _cachedStatsIds["$id@$type"] = true;
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// StatsHelper extension（不变，仅把同步 DB 调用改为 async）
// ═══════════════════════════════════════════════════════════

extension StatsHelper on StatsManager {
  Future<(StatsDataImpl, DailyEvent, PlatformEventRecord)>
  getOrCreateTodayPlatformRecord({
    required String id,
    required int type,
    required DailyEventType targetType,
  }) async {
    final statsDataImpl = (await getStatsByIdAndType(id: id, type: type))!;
    final todayStr = DateTime.now().yyyymmdd;
    final targetList = targetType.getList(statsDataImpl);

    DailyEvent getTargetDailyEvent() {
      if (targetType == DailyEventType.comment ||
          targetType == DailyEventType.rating) {
        if (targetList.isEmpty) {
          final e = DailyEvent(dateStr: todayStr, platformEventRecords: []);
          targetList.add(e);
          return e;
        }
        return targetList.last;
      } else {
        return targetList.firstWhere(
          (e) => e.date.yyyymmdd == todayStr,
          orElse: () {
            final e = DailyEvent(dateStr: todayStr, platformEventRecords: []);
            targetList.add(e);
            return e;
          },
        );
      }
    }

    PlatformEventRecord getOrCreatePlatformRecord(DailyEvent todayEvent) {
      if (targetType == DailyEventType.comment ||
          targetType == DailyEventType.rating) {
        if (todayEvent.platformEventRecords.isEmpty) {
          final now = DateTime.now();
          final r = PlatformEventRecord(
            value: 0,
            platform: AppPlatform.current,
            comment: targetType == DailyEventType.comment ? '' : null,
            rating: targetType == DailyEventType.rating ? 0 : null,
            dateStr: now.yyyymmddHHmmss,
          );
          todayEvent.platformEventRecords.add(r);
          return r;
        }
        return todayEvent.platformEventRecords.reduce((a, b) {
          final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ad.isAfter(bd) ? a : b;
        });
      }
      return todayEvent.platformEventRecords.firstWhere(
        (p) => p.platform == AppPlatform.current,
        orElse: () {
          final now = DateTime.now();
          final r = PlatformEventRecord(
            value: 0,
            platform: AppPlatform.current,
            dateStr: now.yyyymmddHHmmss,
          );
          todayEvent.platformEventRecords.add(r);
          return r;
        },
      );
    }

    final todayRecord = getTargetDailyEvent();
    final platformRecord = getOrCreatePlatformRecord(todayRecord);
    return (statsDataImpl, todayRecord, platformRecord);
  }

  TodayEventBundle getOrCreateTodayEvents({required StatsDataImpl statsData}) {
    final todayStr = DateTime.now().yyyymmdd;

    DailyEvent getOrCreate(List<DailyEvent> list) => list.firstWhere(
      (e) => e.date.yyyymmdd == todayStr,
      orElse: () {
        final e = DailyEvent(dateStr: todayStr, platformEventRecords: []);
        list.add(e);
        return e;
      },
    );

    DailyEvent getLatestOrCreate(List<DailyEvent> list) {
      if (list.isNotEmpty) return list.last;
      final e = DailyEvent(dateStr: todayStr, platformEventRecords: []);
      list.add(e);
      return e;
    }

    PlatformEventRecord getOrCreateRecord(DailyEvent event) =>
        event.platformEventRecords.firstWhere(
          (p) => p.platform == AppPlatform.current,
          orElse: () {
            final r = PlatformEventRecord(
              value: 0,
              platform: AppPlatform.current,
              dateStr: DateTime.now().yyyymmddHHmmss,
            );
            event.platformEventRecords.add(r);
            return r;
          },
        );

    PlatformEventRecord getLatestRecord(
      DailyEvent event, {
      bool initComment = false,
      bool initRating = false,
      bool initFavorite = false,
    }) {
      if (event.platformEventRecords.isNotEmpty) {
        return event.platformEventRecords.reduce((a, b) {
          final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ad.isAfter(bd) ? a : b;
        });
      }
      final r = PlatformEventRecord(
        value: 0,
        platform: AppPlatform.current,
        comment: initComment ? '' : null,
        rating: initRating ? 0 : null,
        favorite: initFavorite ? '' : null,
        dateStr: DateTime.now().yyyymmddHHmmss,
      );
      event.platformEventRecords.add(r);
      return r;
    }

    final todayClick = getOrCreate(statsData.totalClickCount);
    final todayWatch = getOrCreate(statsData.totalWatchDurations);
    final todayComment = getLatestOrCreate(statsData.comment);
    final todayRating = getLatestOrCreate(statsData.rating);
    final todayFavorite = getLatestOrCreate(statsData.favorite);

    return TodayEventBundle(
      statsData: statsData,
      todayComment: todayComment,
      commentRecord: getLatestRecord(todayComment, initComment: true),
      todayClick: todayClick,
      clickRecord: getOrCreateRecord(todayClick),
      todayWatch: todayWatch,
      watchRecord: getOrCreateRecord(todayWatch),
      todayRating: todayRating,
      ratingRecord: getLatestRecord(todayRating, initRating: true),
      todayFavorite: todayFavorite,
      favoriteRecord: getLatestRecord(todayFavorite, initFavorite: true),
    );
  }

  Future<void> addFavoriteRecord({
    required String id,
    required int type,
    required String folder,
    required FavoriteAction action,
  }) async {
    final manager = StatsManager();
    if (!manager.isExist(id, AnimeType(type))) {
      try {
        final history = HistoryManager().find(id, AnimeType(type));
        final favorite = LocalFavoritesManager().findAnime(id, AnimeType(type));
        if (history != null) {
          await manager.addStats(
            manager.createStatsData(
              id: id,
              title: history.title,
              cover: history.cover,
              type: type,
            ),
          );
        } else if (favorite != null) {
          await manager.addStats(
            manager.createStatsData(
              id: id,
              title: favorite.title,
              cover: favorite.cover,
              type: type,
            ),
          );
        } else {
          await manager.addStats(manager.createStatsData(id: id, type: type));
        }
      } catch (e) {
        StatsLog.error('addFavoriteRecord', e.toString());
      }
    }

    final (statsDataImpl, todayFavorite, _) = await manager
        .getOrCreateTodayPlatformRecord(
          id: id,
          type: type,
          targetType: DailyEventType.favorite,
        );

    todayFavorite.platformEventRecords
      ..add(
        PlatformEventRecord(
          value: 0,
          platform: AppPlatform.current,
          favorite: folder,
          favoriteAction: action,
          dateStr: DateTime.now().yyyymmddHHmmss,
        ),
      )
      ..removeWhere(
        (p) =>
            p.favoriteAction == null &&
            p.favorite == null &&
            p.favoriteType == null,
      );

    await manager.updateStats(
      id: id,
      type: type,
      favorite: statsDataImpl.favorite,
    );
  }

  Future<TodayEventBundle?> getOrCreateBangumiStats({
    required StatsDataImpl statsDataImpl,
  }) async {
    if (statsDataImpl.bangumiId == null) return null;
    final bangumiItem = await BangumiManager().getBangumiItem(
      statsDataImpl.bangumiId!,
    );
    if (bangumiItem == null) return null;

    final bangumiType = AnimeType('bangumi'.hashCode);
    if (!isExist(bangumiItem.id.toString(), bangumiType)) {
      try {
        await addStats(
          createStatsData(
            id: bangumiItem.id.toString(),
            title: bangumiItem.nameCn.isNotEmpty
                ? bangumiItem.nameCn
                : bangumiItem.name,
            cover: bangumiItem.images['large'],
            type: 'bangumi'.hashCode,
            bangumiId: bangumiItem.id,
            isBangumi: true,
          ),
        );
      } catch (e, s) {
        StatsLog.error('getOrCreateBangumiStats', '$e\n$s');
        return null;
      }
    }

    final data = await getStatsByIdAndType(
      id: bangumiItem.id.toString(),
      type: 'bangumi'.hashCode,
    );
    if (data == null) return null;
    return getOrCreateTodayEvents(statsData: data);
  }
}

// ═══════════════════════════════════════════════════════════
// Riverpod
// ═══════════════════════════════════════════════════════════

final statsAllProvider =
    StreamNotifierProvider<StatsAllNotifier, List<StatsDataImpl>>(
      StatsAllNotifier.new,
    );

class StatsAllNotifier extends StreamNotifier<List<StatsDataImpl>> {
  @override
  Stream<List<StatsDataImpl>> build() async* {
    final manager = StatsManager();
    await manager.init();
    yield* manager.watchAll();
  }
}
