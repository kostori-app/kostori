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
import 'package:kostori/i18n/strings.g.dart';
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

  /// 直接构造（用于后台 isolate 反序列化重建）
  History({
    required this.id,
    required this.type,
    DateTime? time,
    required this.title,
    required this.subtitle,
    required this.cover,
    this.lastWatchEpisode,
    this.lastWatchTime,
    this.lastRoad,
    this.allEpisode,
    this.bangumiId,
    Set<int>? watchEpisode,
    this.viewMore,
  }) : time = time ?? DateTime.now(),
       watchEpisode = watchEpisode ?? <int>{};

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

  /// 序列化为 JSON（用于 WebDAV 多端字段级合并）
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.value,
    'title': title,
    'subtitle': subtitle,
    'cover': cover,
    'time': time.millisecondsSinceEpoch,
    'lastWatchEpisode': lastWatchEpisode,
    'lastWatchTime': lastWatchTime,
    'lastRoad': lastRoad,
    'allEpisode': allEpisode,
    'bangumiId': bangumiId,
    'watchEpisode': watchEpisode.join(','),
    'viewMore': viewMore is PageJumpTarget
        ? (viewMore as PageJumpTarget).toJsonString()
        : null,
  };

  /// 从 JSON 反序列化（配合 WebDAV 多端字段级合并）
  factory History.fromJson(Map<String, dynamic> json) => History(
    id: json['id'] as String,
    type: AnimeType(json['type'] as int),
    time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    cover: json['cover'] as String? ?? '',
    lastWatchEpisode: json['lastWatchEpisode'] as int?,
    lastWatchTime: json['lastWatchTime'] as int?,
    lastRoad: json['lastRoad'] as int?,
    allEpisode: json['allEpisode'] as int?,
    bangumiId: json['bangumiId'] as int?,
    watchEpisode: Set<int>.from(
      (json['watchEpisode'] as String? ?? '')
          .split(',')
          .where((e) => e.isNotEmpty)
          .map(int.parse),
    ),
    viewMore:
        json['viewMore'] is String && (json['viewMore'] as String).isNotEmpty
        ? PageJumpTarget.fromJsonString(json['viewMore'] as String)
        : null,
  );

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

    var res = '${type.animeSource?.name ?? t.unknown} | ';
    if ((lastWatchEpisode ?? 0) >= 1) {
      res += t.currentlySeenEp(ep: (lastWatchEpisode ?? 0).toString());
    }
    if ((lastWatchTime ?? 0) >= 1) {
      if ((lastWatchEpisode ?? 0) >= 1) res += " | ";
      res += t.lastWatchTimeTime(time: formatMs(lastWatchTime ?? 0));
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
    HistoryTimeGroup.today => t.today,
    HistoryTimeGroup.yesterday => t.yesterday,
    HistoryTimeGroup.last3Days => t.last3Days,
    HistoryTimeGroup.last7Days => t.last7Days,
    HistoryTimeGroup.last30Days => t.last30Days,
    HistoryTimeGroup.last3Months => t.last3Months,
    HistoryTimeGroup.last6Months => t.last6Months,
    HistoryTimeGroup.thisYear => t.thisYear,
    HistoryTimeGroup.older => t.older,
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
  // 缓存全部历史（初始从数据库加载，之后增量更新）
  final cachedHistories = <String, History>{};

  // 上次时间变化通知的时间（时间变化每 30 秒通知一次，避免每秒重建卡顿）
  int _lastTimeNotify = 0;

  /// 更新内存缓存并通知。
  /// 集数变化立即通知（切集实时刷新）；时间变化每 30 秒通知一次，
  /// 避免每秒 notifyListeners 导致播放器/列表重建卡顿。
  void cacheHistory(History item) {
    final prev = cachedHistories[item.id];
    _cachedHistoryIds ??= {};
    _cachedHistoryIds![item.id] = true;
    cachedHistories.remove(item.id);
    cachedHistories[item.id] = item;
    if (prev == null) {
      notifyListeners();
      return;
    }
    final episodeChanged = prev.lastWatchEpisode != item.lastWatchEpisode;
    final timeChanged = prev.lastWatchTime != item.lastWatchTime;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (episodeChanged) {
      notifyListeners();
    } else if (timeChanged && now - _lastTimeNotify > 30000) {
      _lastTimeNotify = now;
      notifyListeners();
    }
  }

  Future<void> init() async {
    if (isInitialized) return;
    _db = _HistoryDb();
    isInitialized = true;
    // busy_timeout：多连接偶发写锁等待，避免立即 SQLITE_BUSY
    // （不使用 WAL，保持只在 history.db 单文件）
    try {
      await _db.customStatement('PRAGMA busy_timeout = 10000;');
    } catch (_) {}
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
    // 更新缓存条目并把它移到最新（LinkedHashMap 保持插入顺序）
    cachedHistories.remove(item.id);
    cachedHistories[item.id] = item;
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
    try {
      final row =
          await (_db.select(_db.historyTable)
                ..where((t) => t.id.equals(id) & t.type.equals(type.value)))
              .getSingleOrNull();
      return row != null ? History.fromDrift(row) : null;
    } catch (_) {
      // 连接可能正在重开（WebDAV 导入等），忽略该次查询
      return null;
    }
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

  /// 字段级合并：逐条与本地比对，`lastWatchTime` 较新者胜，其余字段一并采用。
  /// 用于 WebDAV 多端同步（不整库覆盖，避免各端改动互相丢失）。
  /// 性能：批量 insert，合并结束后仅通知一次，避免逐条 notify 导致 UI 反复重建。
  Future<void> mergeHistoryList(List<History> remote) async {
    if (remote.isEmpty) return;
    final local = await getAll();
    final localMap = {for (final h in local) h.id: h};

    // 先筛出需要写入的条目（远端较新或本地没有）
    final toWrite = <History>[];
    for (final r in remote) {
      final l = localMap[r.id];
      if (l == null || (r.lastWatchTime ?? 0) > (l.lastWatchTime ?? 0)) {
        toWrite.add(r);
      }
      // 本地较新或相等：保持本地
    }
    if (toWrite.isEmpty) return;

    // 批量写入（单事务，避免逐条 SQL）
    await _db.transaction(() async {
      await _db.batch((batch) {
        for (final h in toWrite) {
          batch.insert(
            _db.historyTable,
            h.toCompanion(),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
    // 合并后统一刷新缓存并通知一次
    await _updateCache();
    notifyListeners();
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
    // 读缓存（不查库）：避免每次查询与后台写入锁冲突导致卡顿
    yield _fromCache(manager);
    yield* Stream<void>.multi((controller) {
      void notify() {
        if (!controller.isClosed) controller.add(null);
      }

      manager.addListener(notify);
      controller.onCancel = () => manager.removeListener(notify);
    }).map((_) => _fromCache(manager));
  }

  List<History> _fromCache(HistoryManager manager) {
    final list = manager.cachedHistories.values.toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    return list;
  }
}
