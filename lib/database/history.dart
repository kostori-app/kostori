// ignore_for_file: collection_methods_unrelated_type

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/utils/translations.dart';
import 'package:path/path.dart' as p;

part 'history.g.dart';

typedef HistoryType = AnimeType;

// ═══════════════════════════════════════════════════════════
// 数据类（不变）
// ═══════════════════════════════════════════════════════════

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
  int? lastWatchEpisode;
  int? lastWatchTime;
  int? lastRoad;
  int? allEpisode;
  int? bangumiId;
  @override
  final PageJumpTarget? viewMore;
  @override
  String id;
  Set<int> watchEpisode;

  History.fromModel({
    required HistoryMixin model,
    this.lastWatchEpisode = 0,
    this.lastWatchTime = 0,
    this.lastRoad = 0,
    this.allEpisode = 0,
    this.bangumiId,
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

  History.fromDrift(HistoryTableData r)
    : type = HistoryType(r.type),
      time = DateTime.fromMillisecondsSinceEpoch(r.time),
      title = r.title,
      subtitle = r.subtitle,
      cover = r.cover,
      lastWatchEpisode = r.lastWatchEpisode,
      lastWatchTime = r.lastWatchTime,
      lastRoad = r.lastRoad,
      allEpisode = r.allEpisode,
      id = r.id,
      watchEpisode = Set<int>.from(
        r.watchEpisode.split(',').where((e) => e.isNotEmpty).map(int.parse),
      ),
      bangumiId = r.bangumiId,
      viewMore = r.viewMore != null && r.viewMore!.isNotEmpty
          ? PageJumpTarget.fromJsonString(r.viewMore!)
          : null;

  HistoryTableCompanion toCompanion() => HistoryTableCompanion(
    id: Value(id),
    title: Value(title),
    subtitle: Value(subtitle),
    cover: Value(cover),
    time: Value(time.millisecondsSinceEpoch),
    type: Value(type.value),
    lastWatchEpisode: Value(lastWatchEpisode),
    lastWatchTime: Value(lastWatchTime),
    lastRoad: Value(lastRoad),
    allEpisode: Value(allEpisode),
    watchEpisode: Value(watchEpisode.join(',')),
    bangumiId: Value(bangumiId),
    viewMore: Value(
      viewMore is PageJumpTarget
          ? (viewMore as PageJumpTarget).toJsonString()
          : null,
    ),
  );

  @override
  String toString() =>
      'History{type: $type, time: $time, title: $title, id: $id, bangumiId: $bangumiId}';

  @override
  int get hashCode => Object.hash(id, type);

  @override
  bool operator ==(Object other) =>
      other is History && type == other.type && id == other.id;

  @override
  String get description {
    String formatMs(int ms) {
      final d = Duration(milliseconds: ms);
      return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }

    var res = '${type.animeSource?.name ?? "Unknown"} | ';
    if ((lastWatchEpisode ?? 0) >= 1) {
      res += "Currently seen @ep".tlParams({"ep": lastWatchEpisode ?? 0});
    }
    if ((lastWatchTime ?? 0) >= 1) {
      if ((lastWatchEpisode ?? 0) >= 1) res += " | ";
      res += "lastWatchTime @time".tlParams({
        "time": formatMs(lastWatchTime ?? 0),
      });
    }
    return res;
  }

  String formatLastWatchTime(int ms) {
    final total = ms ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
  Map<String, dynamic> toJson() => throw UnimplementedError();
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
  String get title => switch (this) {
    HistoryTimeGroup.today => "Today".tl,
    HistoryTimeGroup.yesterday => "Yesterday".tl,
    HistoryTimeGroup.last3Days => "Last 3 Days".tl,
    HistoryTimeGroup.last7Days => "Last 7 Days".tl,
    HistoryTimeGroup.last30Days => "Last 30 Days".tl,
    HistoryTimeGroup.last3Months => "Last 3 Months".tl,
    HistoryTimeGroup.last6Months => "Last 6 Months".tl,
    HistoryTimeGroup.thisYear => "This Year".tl,
    HistoryTimeGroup.older => "Older".tl,
  };

  int get order => switch (this) {
    HistoryTimeGroup.today => 0,
    HistoryTimeGroup.yesterday => 1,
    HistoryTimeGroup.last3Days => 2,
    HistoryTimeGroup.last7Days => 3,
    HistoryTimeGroup.last30Days => 4,
    HistoryTimeGroup.last3Months => 5,
    HistoryTimeGroup.last6Months => 6,
    HistoryTimeGroup.thisYear => 7,
    HistoryTimeGroup.older => 8,
  };
}

HistoryTimeGroup groupByTime(DateTime time) {
  final now = DateTime.now();
  final diff = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(time.year, time.month, time.day)).inDays;
  if (diff == 0) return HistoryTimeGroup.today;
  if (diff == 1) return HistoryTimeGroup.yesterday;
  if (diff <= 3) return HistoryTimeGroup.last3Days;
  if (diff <= 7) return HistoryTimeGroup.last7Days;
  if (diff <= 30) return HistoryTimeGroup.last30Days;
  if (diff <= 90) return HistoryTimeGroup.last3Months;
  if (diff <= 180) return HistoryTimeGroup.last6Months;
  if (time.year == now.year) return HistoryTimeGroup.thisYear;
  return HistoryTimeGroup.older;
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

  Progress.fromDrift(ProgressTableData r)
    : type = HistoryType(r.type),
      historyId = r.historyId,
      episode = r.episode,
      road = r.road,
      progressInMilli = r.progressInMilli,
      isCompleted = r.isCompleted,
      startTime = r.startTime != null ? DateTime.tryParse(r.startTime!) : null,
      endTime = r.endTime != null ? DateTime.tryParse(r.endTime!) : null;

  @override
  String toString() =>
      'Progress{type: $type, historyId: $historyId, episode: $episode, road: $road, '
      'progressInMilli: $progressInMilli, isCompleted: $isCompleted}';
}

// ═══════════════════════════════════════════════════════════
// 表定义（.named() 保持 camelCase 兼容旧数据库）
// ═══════════════════════════════════════════════════════════

class HistoryTable extends Table {
  @override
  String get tableName => 'history';

  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get subtitle => text()();

  TextColumn get cover => text()();

  IntColumn get time => integer()();

  IntColumn get type => integer()();

  IntColumn get lastWatchEpisode =>
      integer().named('lastWatchEpisode').nullable()();

  IntColumn get lastWatchTime => integer().named('lastWatchTime').nullable()();

  IntColumn get lastRoad => integer().named('lastRoad').nullable()();

  IntColumn get allEpisode => integer().named('allEpisode').nullable()();

  TextColumn get watchEpisode =>
      text().named('watchEpisode').withDefault(const Constant(''))();

  IntColumn get bangumiId => integer().named('bangumiId').nullable()();

  TextColumn get viewMore => text().named('viewMore').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProgressTable extends Table {
  @override
  String get tableName => 'progress';

  IntColumn get type => integer()();

  TextColumn get historyId => text().named('historyId')();

  IntColumn get episode => integer()();

  IntColumn get road => integer()();

  IntColumn get progressInMilli => integer().named('progressInMilli')();

  BoolColumn get isCompleted =>
      boolean().named('isCompleted').withDefault(const Constant(false))();

  TextColumn get startTime => text().named('startTime').nullable()();

  TextColumn get endTime => text().named('endTime').nullable()();

  @override
  Set<Column> get primaryKey => {type, episode, road, historyId};
}

// ═══════════════════════════════════════════════════════════
// 数据库
// ═══════════════════════════════════════════════════════════

@DriftDatabase(tables: [HistoryTable, ProgressTable])
class _HistoryDb extends _$_HistoryDb {
  _HistoryDb() : super(_openConn());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

LazyDatabase _openConn() => LazyDatabase(() async {
  final file = File(p.join(App.dataPath, 'history.db'));
  return NativeDatabase.createInBackground(file);
});

// ═══════════════════════════════════════════════════════════
// HistoryManager（单例）
// ═══════════════════════════════════════════════════════════

class HistoryManager with ChangeNotifier {
  static HistoryManager? _cache;

  HistoryManager._();

  factory HistoryManager() => _cache ??= HistoryManager._();

  late _HistoryDb _db;
  bool isInitialized = false;

  // 内存缓存（保持原有性能优化）
  Map<String, bool>? _cachedHistoryIds;
  final cachedHistories = <String, History>{};

  Future<void> init() async {
    if (isInitialized) return;
    _db = _HistoryDb();
    isInitialized = true;
    await _updateCache();
  }

  Future<void> close() async {
    await _db.close();
    _cache = null;
    isInitialized = false;
  }

  Future<void> reinit([Future<void> Function()? between]) async {
    if (isInitialized) {
      await _db.close();
      isInitialized = false;
      _cachedHistoryIds = null;
      cachedHistories.clear();
    }

    await between?.call();

    _db = _HistoryDb();
    isInitialized = true;
    await _updateCache();
    notifyListeners();
  }

  int get length => _cachedHistoryIds?.length ?? 0;

  // ─── 缓存 ──────────────────────────────────

  Future<void> _updateCache() async {
    final rows = await _db.select(_db.historyTable).get();
    _cachedHistoryIds = {};
    cachedHistories.clear();
    for (final r in rows) {
      final h = History.fromDrift(r);
      _cachedHistoryIds![h.id] = true;
      cachedHistories[h.id] = h;
    }
  }

  void updateCache() => _updateCache();

  // ─── 写入 ──────────────────────────────────

  Future<void> addHistory(History item) async {
    await _db.into(_db.historyTable).insertOnConflictUpdate(item.toCompanion());
    _cachedHistoryIds ??= {};
    _cachedHistoryIds![item.id] = true;
    cachedHistories[item.id] = item;
    cachedHistories.remove(cachedHistories.keys.first);
    notifyListeners();
  }

  Future<void> remove(String id, AnimeType type) async {
    await (_db.delete(_db.historyTable)..where((t) => t.id.equals(id))).go();
    await (_db.delete(
      _db.progressTable,
    )..where((t) => t.historyId.equals(id) & t.type.equals(type.value))).go();
    _cachedHistoryIds?.remove(id);
    cachedHistories.remove(id);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _db.delete(_db.historyTable).go();
    await _db.delete(_db.progressTable).go();
    _cachedHistoryIds = {};
    cachedHistories.clear();
    notifyListeners();
  }

  Future<void> clearProgress() async {
    await _db.delete(_db.progressTable).go();
    notifyListeners();
  }

  Future<void> clearUnfavoritedHistory() async {
    final rows = await (_db.selectOnly(
      _db.historyTable,
    )..addColumns([_db.historyTable.id, _db.historyTable.type])).get();
    await _db.transaction(() async {
      for (final row in rows) {
        final id = row.read(_db.historyTable.id)!;
        final type = AnimeType(row.read(_db.historyTable.type)!);
        if (!LocalFavoritesManager().isExist(id, type)) {
          await (_db.delete(
            _db.historyTable,
          )..where((t) => t.id.equals(id))).go();
          await (_db.delete(_db.progressTable)..where(
                (t) => t.historyId.equals(id) & t.type.equals(type.value),
              ))
              .go();
        }
      }
    });
    await _updateCache();
    notifyListeners();
  }

  Future<void> batchDeleteHistories(List<AnimeID> histories) async {
    if (histories.isEmpty) return;
    await _db.transaction(() async {
      for (final h in histories) {
        await (_db.delete(
          _db.historyTable,
        )..where((t) => t.id.equals(h.id))).go();
      }
    });
    await _updateCache();
    notifyListeners();
  }

  // ─── 查询 ──────────────────────────────────

  History? find(String id, AnimeType type) {
    if (_cachedHistoryIds == null) return null;
    if (!_cachedHistoryIds!.containsKey(id)) return null;
    if (cachedHistories.containsKey(id)) return cachedHistories[id];
    // 缓存没有，同步查 DB（Drift 不支持同步，改用 findAsync）
    return null; // 返回 null 让调用方用 findAsync
  }

  Future<History?> findAsync(String id, AnimeType type) async {
    final row =
        await (_db.select(_db.historyTable)
              ..where((t) => t.id.equals(id) & t.type.equals(type.value)))
            .getSingleOrNull();
    return row != null ? History.fromDrift(row) : null;
  }

  Future<List<History>> getAll() async {
    final rows = await (_db.select(
      _db.historyTable,
    )..orderBy([(t) => OrderingTerm.desc(t.time)])).get();
    return rows.map(History.fromDrift).toList();
  }

  Stream<List<History>> watchAll() {
    return (_db.select(_db.historyTable)
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .watch()
        .map((rows) => rows.map(History.fromDrift).toList());
  }

  Future<List<History>> getRecent() async {
    final rows =
        await (_db.select(_db.historyTable)
              ..orderBy([(t) => OrderingTerm.desc(t.time)])
              ..limit(20))
            .get();
    return rows.map(History.fromDrift).toList();
  }

  Future<int> count() async {
    final c = _db.historyTable.id.count();
    final q = _db.selectOnly(_db.historyTable)..addColumns([c]);
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  Future<List<History>> bangumiByIDFind(int id) async {
    final rows = await (_db.select(
      _db.historyTable,
    )..where((t) => t.bangumiId.equals(id))).get();
    return rows.map(History.fromDrift).toList();
  }
}

// ═══════════════════════════════════════════════════════════
// ProgressHelper
// ═══════════════════════════════════════════════════════════

extension ProgressHelper on HistoryManager {
  Future<void> addProgress(Progress prog, String historyId) async {
    await _db
        .into(_db.progressTable)
        .insertOnConflictUpdate(
          ProgressTableCompanion(
            type: Value(prog.type.value),
            historyId: Value(historyId),
            episode: Value(prog.episode),
            road: Value(prog.road),
            progressInMilli: Value(prog.progressInMilli),
            isCompleted: Value(prog.isCompleted),
            startTime: Value(prog.startTime?.toIso8601String()),
            endTime: Value(prog.endTime?.toIso8601String()),
          ),
        );
  }

  Future<bool> checkIfProgressExists({
    required String historyId,
    required AnimeType type,
    required int episode,
    required int road,
  }) async {
    final row =
        await (_db.select(_db.progressTable)..where(
              (t) =>
                  t.historyId.equals(historyId) &
                  t.type.equals(type.value) &
                  t.episode.equals(episode) &
                  t.road.equals(road),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Progress? progressFind(
    String historyId,
    AnimeType type,
    int episode,
    int road,
  ) {
    // 同步版：依赖调用方确保已缓存，或用 progressFindAsync
    return null;
  }

  Future<Progress?> progressFindAsync(
    String historyId,
    AnimeType type,
    int episode,
    int road,
  ) async {
    final row =
        await (_db.select(_db.progressTable)..where(
              (t) =>
                  t.historyId.equals(historyId) &
                  t.type.equals(type.value) &
                  t.episode.equals(episode) &
                  t.road.equals(road),
            ))
            .getSingleOrNull();
    return row != null ? Progress.fromDrift(row) : null;
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
    await (_db.update(_db.progressTable)..where(
          (t) =>
              t.historyId.equals(historyId) &
              t.type.equals(type.value) &
              t.episode.equals(episode) &
              t.road.equals(road),
        ))
        .write(
          ProgressTableCompanion(
            progressInMilli: progressInMilli != null
                ? Value(progressInMilli)
                : const Value.absent(),
            isCompleted: isCompleted != null
                ? Value(isCompleted)
                : const Value.absent(),
            startTime: startTime != null
                ? Value(startTime.toIso8601String())
                : const Value.absent(),
            endTime: endTime != null
                ? Value(endTime.toIso8601String())
                : const Value.absent(),
          ),
        );
  }
}

// ═══════════════════════════════════════════════════════════
// Riverpod
// ═══════════════════════════════════════════════════════════

final historyAllProvider =
    StreamNotifierProvider<HistoryAllNotifier, List<History>>(
      HistoryAllNotifier.new,
    );

class HistoryAllNotifier extends StreamNotifier<List<History>> {
  @override
  Stream<List<History>> build() async* {
    final manager = HistoryManager();
    if (!manager.isInitialized) await manager.init();
    yield* manager.watchAll();
  }
}
