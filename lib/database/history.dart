// ignore_for_file: collection_methods_unrelated_type

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/db_common.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/image_loader/inline_image.dart';
import 'package:kostori/i18n/strings.g.dart';

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
    // base64 封面换成 `inline:<hash>` 短引用，避免 history.db 被撑爆
    cover: Value(InlineImageStore.refOfBase64(cover)),
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
    'cover': InlineImageStore.refOfBase64(cover),
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

  /// 同 bangumiId 的其它来源进度更高时，展示其集数（同一部番跨来源对齐）
  int get displayEpisode {
    final aligned = HistoryManager().bestByBangumiId(bangumiId);
    final own = lastWatchEpisode ?? 0;
    if (aligned == null || aligned.id == id) return own;
    final other = aligned.lastWatchEpisode ?? 0;
    return other > own ? other : own;
  }

  @override
  String get description {
    String formatMs(int ms) {
      final d = Duration(milliseconds: ms);
      return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }

    final ep = displayEpisode;
    var res = '${type.animeSource?.name ?? t.unknown} | ';
    if (ep >= 1) {
      res += t.currentlySeenEp(ep: ep.toString());
    }
    if ((lastWatchTime ?? 0) >= 1) {
      if (ep >= 1) res += " | ";
      res += t.lastWatchTimeTime(time: formatMs(lastWatchTime ?? 0));
    }
    return res;
  }

  @override
  List<AnimeDescriptionLine>? get descriptionLines => null;

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

  Progress({
    required this.historyId,
    required this.type,
    required this.episode,
    required this.road,
    required this.progressInMilli,
    this.isCompleted = false,
    this.startTime,
    this.endTime,
  });

  /// 跨端同步用序列化（见 `utils/data.dart` 的 progress_merge.json）
  Map<String, dynamic> toJson() => {
    'historyId': historyId,
    'type': type.value,
    'episode': episode,
    'road': road,
    'progressInMilli': progressInMilli,
    'isCompleted': isCompleted,
    'startTime': startTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
  };

  static Progress fromJson(Map<String, dynamic> json) => Progress(
    historyId: json['historyId']?.toString() ?? '',
    type: HistoryType((json['type'] as num?)?.toInt() ?? 0),
    episode: (json['episode'] as num?)?.toInt() ?? 0,
    road: (json['road'] as num?)?.toInt() ?? 0,
    progressInMilli: (json['progressInMilli'] as num?)?.toInt() ?? 0,
    isCompleted: json['isCompleted'] == true,
    startTime: DateTime.tryParse(json['startTime']?.toString() ?? ''),
    endTime: DateTime.tryParse(json['endTime']?.toString() ?? ''),
  );

  /// 同一条进度（type + historyId + episode + road）的唯一键
  String get key => '${type.value}|$historyId|$episode|$road';

  /// 是否比 [other] 更新：结束时间更晚优先，都没有结束时间时比较观看进度
  bool isNewerThan(Progress other) {
    final end = endTime;
    final otherEnd = other.endTime;
    if (end != null && otherEnd != null) {
      final c = end.compareTo(otherEnd);
      if (c != 0) return c > 0;
    } else if (end != null) {
      return true;
    } else if (otherEnd != null) {
      return false;
    }
    return progressInMilli > other.progressInMilli;
  }

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

/// 个人页插件浏览/搜索历史（与播放历史同库，无条数上限）
class PluginEventTable extends Table {
  @override
  String get tableName => 'plugin_events';

  TextColumn get pluginKey => text().named('pluginKey')();

  /// open | search
  TextColumn get kind => text()();

  TextColumn get itemKey => text().named('itemKey')();

  TextColumn get title => text()();

  TextColumn get subtitle => text().withDefault(const Constant(''))();

  TextColumn get coverUrl => text().named('coverUrl').withDefault(const Constant(''))();

  /// 用于恢复原页的 JSON（page/params/item）
  TextColumn get extraJson =>
      text().named('extraJson').withDefault(const Constant('{}'))();

  IntColumn get createdAt => integer().named('createdAt')();

  @override
  Set<Column> get primaryKey => {pluginKey, kind, itemKey};
}

/// 文本规则（下载标题筛选/组合；与播放历史同库）
class TextRuleTable extends Table {
  @override
  String get tableName => 'text_rules';

  TextColumn get id => text()();

  TextColumn get name => text()();

  /// 步骤 JSON（find/replace/caseSensitive 数组）
  TextColumn get stepsJson =>
      text().named('stepsJson').withDefault(const Constant('[]'))();

  /// 排序（越小越靠前，即应用顺序）
  IntColumn get sort => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer().named('createdAt')();

  /// 最后修改时间（多端合并用，新者胜）
  IntColumn get updatedAt =>
      integer().named('updatedAt').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 剪贴板/备忘录（与播放历史同库，随 history.db 同步）
class MemoTable extends Table {
  @override
  String get tableName => 'memos';

  TextColumn get id => text()();

  TextColumn get content => text()();

  IntColumn get createdAt => integer().named('createdAt')();

  IntColumn get updatedAt =>
      integer().named('updatedAt').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ═══════════════════════════════════════════════════════════
// 数据库
// ═══════════════════════════════════════════════════════════

@DriftDatabase(
  tables: [
    HistoryTable,
    ProgressTable,
    PluginEventTable,
    TextRuleTable,
    MemoTable,
  ],
)
class _HistoryDb extends _$_HistoryDb {
  _HistoryDb() : super(_openConn());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

/// 物理建表（v1 无迁移）：幂等，确保 history.db 里有 plugin_events 表
const String _createPluginEventsSql = '''
CREATE TABLE IF NOT EXISTS plugin_events (
  pluginKey TEXT NOT NULL,
  kind TEXT NOT NULL,
  itemKey TEXT NOT NULL,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL DEFAULT '',
  coverUrl TEXT NOT NULL DEFAULT '',
  extraJson TEXT NOT NULL DEFAULT '{}',
  createdAt INTEGER NOT NULL,
  PRIMARY KEY (pluginKey, kind, itemKey)
)
''';

/// 物理建表（v1 无迁移）：幂等，确保 history.db 里有 text_rules 表
const String _createTextRulesSql = '''
CREATE TABLE IF NOT EXISTS text_rules (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  stepsJson TEXT NOT NULL DEFAULT '[]',
  sort INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
)
''';

/// 老库补列（表已存在但无 updatedAt 时）；列已存在会抛错，忽略即可
const String _alterTextRulesUpdatedAtSql =
    'ALTER TABLE text_rules ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0';

/// 物理建表（v1 无迁移）：幂等，确保 history.db 里有 memos 表
const String _createMemosSql = '''
CREATE TABLE IF NOT EXISTS memos (
  id TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
)
''';

LazyDatabase _openConn() => openWalDb('history.db');

// ═══════════════════════════════════════════════════════════
// HistoryManager（单例）
// ═══════════════════════════════════════════════════════════

/// 个人页插件事件（浏览/搜索），持久化于 history.db 同库
class PluginEventItem {
  final String pluginKey;
  final String kind;
  final String itemKey;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String extraJson;
  final int createdAt;

  const PluginEventItem({
    required this.pluginKey,
    required this.kind,
    required this.itemKey,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.extraJson,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'pluginKey': pluginKey,
    'kind': kind,
    'itemKey': itemKey,
    'title': title,
    'subtitle': subtitle,
    'coverUrl': InlineImageStore.refOfBase64(coverUrl),
    'extraJson': extraJson,
    'createdAt': createdAt,
  };

  static PluginEventItem fromJson(Map<String, dynamic> m) => PluginEventItem(
    pluginKey: m['pluginKey']?.toString() ?? '',
    kind: m['kind']?.toString() ?? '',
    itemKey: m['itemKey']?.toString() ?? '',
    title: m['title']?.toString() ?? '',
    subtitle: m['subtitle']?.toString() ?? '',
    coverUrl: m['coverUrl']?.toString() ?? '',
    extraJson: m['extraJson']?.toString() ?? '{}',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
  );
}

class HistoryManager with ChangeNotifier {
  static HistoryManager? _cache;

  HistoryManager._();

  factory HistoryManager() => _cache ??= HistoryManager._();

  late _HistoryDb _db;
  bool isInitialized = false;

  /// 在途数据库操作计数；close/reinit 前等待归零，
  /// 避免数据导入/后台关闭连接时打断在途查询（原生 sqlite3_step 崩溃）
  int _busy = 0;

  Future<void> _waitIdle() async {
    while (_busy > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<T> _guard<T>(Future<T> Function() op) {
    _busy++;
    return Future.sync(op).whenComplete(() => _busy--);
  }

  // 内存缓存（保持原有性能优化）
  Map<String, bool>? _cachedHistoryIds;
  // 缓存全部历史（初始从数据库加载，之后增量更新）
  final cachedHistories = <String, History>{};

  // bangumiId → 集数最高（并列取时间更新）的那条历史，
  // 用于「同一部番不同来源」的显示与续看对齐
  final Map<int, History> _bangumiBest = {};

  /// a 是否比 b 更“新”：集数优先，其次观看时间
  static bool _betterHistory(History a, History b) {
    final ea = a.lastWatchEpisode ?? 0;
    final eb = b.lastWatchEpisode ?? 0;
    if (ea != eb) return ea > eb;
    return (a.lastWatchTime ?? 0) > (b.lastWatchTime ?? 0);
  }

  void _rebuildBangumiBest() {
    _bangumiBest.clear();
    for (final h in cachedHistories.values) {
      final id = h.bangumiId;
      if (id == null || id <= 0) continue;
      final best = _bangumiBest[id];
      if (best == null || _betterHistory(h, best)) _bangumiBest[id] = h;
    }
  }

  /// 同一 bangumiId 的条目里集数最高的那条（没有则返回 null）
  History? bestByBangumiId(int? bangumiId) {
    if (bangumiId == null || bangumiId <= 0) return null;
    return _bangumiBest[bangumiId];
  }

  /// 该条目在当前 bangumi 分组里应当用于展示的历史（集数取同组最高）
  History alignedHistory(History h) {
    final best = bestByBangumiId(h.bangumiId);
    if (best == null) return h;
    return _betterHistory(best, h) ? best : h;
  }

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
    _rebuildBangumiBest();
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

  Future<void> init() => _guard(() async {
    if (isInitialized) return;
    _db = _HistoryDb();
    isInitialized = true;
    // busy_timeout：多连接偶发写锁等待，避免立即 SQLITE_BUSY。
    // 失败也无妨（旧驱动不支持该 PRAGMA），故意静默。
    try {
      await _db.customStatement('PRAGMA busy_timeout = 10000;');
      // ignore: empty_catches
    } catch (_) {}
    await _updateCache();
  });

  Future<void> close() async {
    await _waitIdle();
    await _db.close();
    _cache = null;
    isInitialized = false;
  }

  /// 把 WAL 里的改动写回主库文件（导出整库副本前调用）
  Future<void> checkpoint() => walCheckpoint(
    () => _guard(
      () => _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);'),
    ),
  );

  Future<void> reinit([Future<void> Function()? between]) async {
    await _waitIdle();
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

  Future<void> _updateCache() => _guard(() async {
    final rows = await _db.select(_db.historyTable).get();
    _cachedHistoryIds = {};
    cachedHistories.clear();
    for (final r in rows) {
      final h = History.fromDrift(r);
      _cachedHistoryIds![h.id] = true;
      cachedHistories[h.id] = h;
    }
    _rebuildBangumiBest();
  });

  void updateCache() => _updateCache();

  // ─── 写入 ──────────────────────────────────

  Future<void> addHistory(History item) => _guard(() async {
    await _db.into(_db.historyTable).insertOnConflictUpdate(item.toCompanion());
    _cachedHistoryIds ??= {};
    _cachedHistoryIds![item.id] = true;
    // 更新缓存条目并把它移到最新（LinkedHashMap 保持插入顺序）
    cachedHistories.remove(item.id);
    cachedHistories[item.id] = item;
    _rebuildBangumiBest();
    notifyListeners();
  });

  /// 静默刷新已存条目的封面/标题（列表再次刷到该条目时调用）：
  /// 仅字段确实变化时写库并通知；无变化返回 false，不打扰 UI
  bool refreshStored(
    String id,
    AnimeType type, {
    String? cover,
    String? title,
  }) {
    try {
      final h = find(id, type);
      if (h == null) return false;
      var changed = false;
      if (cover != null && cover.isNotEmpty && h.cover != cover) {
        h.cover = cover;
        changed = true;
      }
      if (title != null && title.isNotEmpty && h.title != title) {
        h.title = title;
        changed = true;
      }
      if (changed) unawaited(addHistory(h));
      return changed;
    } catch (_) {
      return false;
    }
  }

  Future<void> remove(String id, AnimeType type) => _guard(() async {
    await (_db.delete(_db.historyTable)..where((t) => t.id.equals(id))).go();
    await (_db.delete(
      _db.progressTable,
    )..where((t) => t.historyId.equals(id) & t.type.equals(type.value))).go();
    _cachedHistoryIds?.remove(id);
    cachedHistories.remove(id);
    _rebuildBangumiBest();
    notifyListeners();
  });

  Future<void> clearHistory() => _guard(() async {
    await _db.delete(_db.historyTable).go();
    await _db.delete(_db.progressTable).go();
    _cachedHistoryIds = {};
    cachedHistories.clear();
    _rebuildBangumiBest();
    notifyListeners();
  });

  Future<void> clearProgress() => _guard(() async {
    await _db.delete(_db.progressTable).go();
    notifyListeners();
  });

  Future<void> clearUnfavoritedHistory() => _guard(() async {
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
  });

  Future<void> batchDeleteHistories(List<AnimeID> histories) => _guard(() async {
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
  });

  // ─── 查询 ──────────────────────────────────

  History? find(String id, AnimeType type) {
    if (_cachedHistoryIds == null) return null;
    if (!_cachedHistoryIds!.containsKey(id)) return null;
    if (cachedHistories.containsKey(id)) return cachedHistories[id];
    // 缓存没有，同步查 DB（Drift 不支持同步，改用 findAsync）
    return null; // 返回 null 让调用方用 findAsync
  }

  Future<History?> findAsync(String id, AnimeType type) => _guard(() async {
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
  });

  Future<List<History>> getAll() => _guard(() async {
    final rows = await (_db.select(
      _db.historyTable,
    )..orderBy([(t) => OrderingTerm.desc(t.time)])).get();
    return rows.map(History.fromDrift).toList();
  });

  Stream<List<History>> watchAll() {
    return (_db.select(_db.historyTable)
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .watch()
        .map((rows) => rows.map(History.fromDrift).toList());
  }

  Future<List<History>> getRecent() => _guard(() async {
    final rows =
        await (_db.select(_db.historyTable)
              ..orderBy([(t) => OrderingTerm.desc(t.time)])
              ..limit(20))
            .get();
    return rows.map(History.fromDrift).toList();
  });

  Future<int> count() => _guard(() async {
    final c = _db.historyTable.id.count();
    final q = _db.selectOnly(_db.historyTable)..addColumns([c]);
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  });

  Future<List<History>> bangumiByIDFind(int id) => _guard(() async {
    final rows = await (_db.select(
      _db.historyTable,
    )..where((t) => t.bangumiId.equals(id))).get();
    return rows.map(History.fromDrift).toList();
  });

  /// 字段级合并：逐条与本地比对，`lastWatchTime` 较新者胜，其余字段一并采用。
  /// 用于 WebDAV 多端同步（不整库覆盖，避免各端改动互相丢失）。
  /// 性能：批量 insert，合并结束后仅通知一次，避免逐条 notify 导致 UI 反复重建。
  Future<void> mergeHistoryList(List<History> remote) => _guard(() async {
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

    // 远端为该端全量快照：删除"本地有但远端没有"的条目（另一端已删除），
    // 否则同步后已删除的历史会重新出现
    final remoteIds = remote.map((h) => h.id).toSet();
    final toDelete = local.where((h) => !remoteIds.contains(h.id)).toList();

    if (toWrite.isEmpty && toDelete.isEmpty) return;

    await _db.transaction(() async {
      if (toDelete.isNotEmpty) {
        await _db.batch((batch) {
          for (final h in toDelete) {
            batch.deleteWhere(
              _db.historyTable,
              (tbl) => tbl.id.equals(h.id),
            );
            // 级联删除该历史关联的进度记录，避免残留
            batch.deleteWhere(
              _db.progressTable,
              (tbl) => tbl.historyId.equals(h.id),
            );
          }
        });
      }
      if (toWrite.isNotEmpty) {
        await _db.batch((batch) {
          for (final h in toWrite) {
            batch.insert(
              _db.historyTable,
              h.toCompanion(),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      }
    });
    // 合并后统一刷新缓存并通知一次
    await _updateCache();
    notifyListeners();
  });

  /// 全部观看进度（跨端同步导出用）
  Future<List<Progress>> getAllProgress() => _guard(() async {
    final rows = await _db.select(_db.progressTable).get();
    return rows.map(Progress.fromDrift).toList();
  });

  /// 字段级合并观看进度：同一条（type/historyId/episode/road）取「结束时间更晚、
  /// 否则观看进度更大」的一条，`isCompleted` 取两端或。
  ///
  /// 用于跨端同步：只做增量合并，不删除本地条目（历史被删时的进度清理由
  /// [mergeHistoryList] 级联完成）。
  Future<void> mergeProgressList(List<Progress> remote) => _guard(() async {
    if (remote.isEmpty) return;
    final localRows = await _db.select(_db.progressTable).get();
    final localMap = <String, Progress>{};
    for (final row in localRows) {
      final p = Progress.fromDrift(row);
      localMap[p.key] = p;
    }

    final toWrite = <Progress>[];
    for (final r in remote) {
      final local = localMap[r.key];
      if (local == null) {
        toWrite.add(r);
        continue;
      }
      final winner = r.isNewerThan(local) ? r : local;
      toWrite.add(
        Progress(
          historyId: winner.historyId,
          type: winner.type,
          episode: winner.episode,
          road: winner.road,
          progressInMilli: winner.progressInMilli,
          // 任一端标记看完即视为看完，避免回退成未完成
          isCompleted: local.isCompleted || r.isCompleted,
          startTime: winner.startTime,
          endTime: winner.endTime,
        ),
      );
    }
    if (toWrite.isEmpty) return;

    await _db.batch((batch) {
      for (final p in toWrite) {
        batch.insert(
          _db.progressTable,
          ProgressTableCompanion(
            type: Value(p.type.value),
            historyId: Value(p.historyId),
            episode: Value(p.episode),
            road: Value(p.road),
            progressInMilli: Value(p.progressInMilli),
            isCompleted: Value(p.isCompleted),
            startTime: Value(p.startTime?.toIso8601String()),
            endTime: Value(p.endTime?.toIso8601String()),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    notifyListeners();
  });
}

// ═══════════════════════════════════════════════════════════
// ProgressHelper
// ═══════════════════════════════════════════════════════════

extension ProgressHelper on HistoryManager {
  Future<void> addProgress(Progress prog, String historyId) => _guard(() async {
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
  });

  Future<bool> checkIfProgressExists({
    required String historyId,
    required AnimeType type,
    required int episode,
    required int road,
  }) => _guard(() async {
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
  });

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
  ) => _guard(() async {
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
  });

  Future<void> updateProgress({
    required String historyId,
    required AnimeType type,
    required int episode,
    required int road,
    int? progressInMilli,
    bool? isCompleted,
    DateTime? startTime,
    DateTime? endTime,
  }) => _guard(() async {
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
  });

  Future<void> _ensureDb() => _guard(() async {
    if (!isInitialized) await init();
    // 幂等建表/加列：已存在时抛错是正常路径，故意静默
    try {
      await _db.customStatement(_createPluginEventsSql);
      await _db.customStatement(_createTextRulesSql);
      await _db.customStatement(_createMemosSql);
      // ignore: empty_catches
    } catch (_) {}
    try {
      await _db.customStatement(_alterTextRulesUpdatedAtSql);
      // ignore: empty_catches
    } catch (_) {}
  });

  /// 记录插件事件（浏览/搜索），history.db 同库、无条数上限
  Future<void> addPluginEvent({
    required String pluginKey,
    required String kind,
    required String itemKey,
    required String title,
    String subtitle = '',
    String coverUrl = '',
    String extraJson = '{}',
  }) => _guard(() async {
    await _ensureDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.pluginEventTable).insertOnConflictUpdate(
      PluginEventTableCompanion.insert(
        pluginKey: pluginKey,
        kind: kind,
        itemKey: itemKey,
        title: title,
        subtitle: Value(subtitle),
        coverUrl: Value(coverUrl),
        extraJson: Value(extraJson),
        createdAt: now,
      ),
    );
  });

  Future<List<PluginEventItem>> listPluginEvents(String pluginKey) =>
      _guard(() async {
        await _ensureDb();
        final rows = await (_db.select(_db.pluginEventTable)
              ..where((t) => t.pluginKey.equals(pluginKey))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
        return rows
            .map(
              (r) => PluginEventItem(
                pluginKey: r.pluginKey,
                kind: r.kind,
                itemKey: r.itemKey,
                title: r.title,
                subtitle: r.subtitle,
                coverUrl: r.coverUrl,
                extraJson: r.extraJson,
                createdAt: r.createdAt,
              ),
            )
            .toList();
      });

  /// 全量插件事件（供多端同步导出）
  Future<List<PluginEventItem>> getAllPluginEvents() => _guard(() async {
    await _ensureDb();
    final rows = await (_db.select(_db.pluginEventTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows
        .map(
          (r) => PluginEventItem(
            pluginKey: r.pluginKey,
            kind: r.kind,
            itemKey: r.itemKey,
            title: r.title,
            subtitle: r.subtitle,
            coverUrl: r.coverUrl,
            extraJson: r.extraJson,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  });

  /// 字段级合并插件事件（WebDAV 多端）：按 (pluginKey,kind,itemKey) 主键，
  /// createdAt 较新者胜或本地缺失则写入。
  Future<void> mergePluginEvents(List<PluginEventItem> remote) =>
      _guard(() async {
        if (remote.isEmpty) return;
        await _ensureDb();
        final local = await getAllPluginEvents();
        final localMap = {
          for (final e in local)
            '${e.pluginKey}\u0000${e.kind}\u0000${e.itemKey}': e,
        };
        final ops = <PluginEventTableCompanion>[];
        for (final r in remote) {
          final key = '${r.pluginKey}\u0000${r.kind}\u0000${r.itemKey}';
          final l = localMap[key];
          if (l != null && l.createdAt >= r.createdAt) continue;
          ops.add(
            PluginEventTableCompanion.insert(
              pluginKey: r.pluginKey,
              kind: r.kind,
              itemKey: r.itemKey,
              title: r.title,
              subtitle: Value(r.subtitle),
              // base64 封面同样只存短引用
              coverUrl: Value(InlineImageStore.refOfBase64(r.coverUrl)),
              extraJson: Value(r.extraJson),
              createdAt: r.createdAt,
            ),
          );
        }
        if (ops.isEmpty) return;
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(_db.pluginEventTable, ops),
        );
      });

  Future<void> clearPluginEvents(String pluginKey) => _guard(() async {
    await _ensureDb();
    await (_db.delete(_db.pluginEventTable)
          ..where((t) => t.pluginKey.equals(pluginKey)))
        .go();
  });

  /// 读取全部文本规则（按 sort 升序，即应用顺序）
  Future<List<Map<String, dynamic>>> getTextRules() => _guard(() async {
    await _ensureDb();
    final rows =
        await (_db.select(_db.textRuleTable)
              ..orderBy([(t) => OrderingTerm.asc(t.sort)]))
            .get();
    return rows
        .map(
          (r) => {
            'id': r.id,
            'name': r.name,
            'stepsJson': r.stepsJson,
            'sort': r.sort,
            'createdAt': r.createdAt,
            'updatedAt': r.updatedAt,
          },
        )
        .toList();
  });

  /// 覆盖写入全部文本规则（按传入顺序保存 sort）
  Future<void> replaceTextRules(List<Map<String, dynamic>> rules) =>
      _guard(() async {
        await _ensureDb();
        await _db.transaction(() async {
          await _db.delete(_db.textRuleTable).go();
          var i = 0;
          for (final r in rules) {
            final id = r['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            await _db
                .into(_db.textRuleTable)
                .insert(
                  TextRuleTableCompanion.insert(
                    id: id,
                    name: r['name']?.toString() ?? '',
                    stepsJson: Value(r['stepsJson']?.toString() ?? '[]'),
                    sort: Value(i),
                    createdAt:
                        (r['createdAt'] as num?)?.toInt() ??
                        DateTime.now().millisecondsSinceEpoch,
                    updatedAt: Value(
                      (r['updatedAt'] as num?)?.toInt() ??
                          DateTime.now().millisecondsSinceEpoch,
                    ),
                  ),
                );
            i++;
          }
        });
      });

  /// 字段级合并文本规则（多端同步）：按 id，updatedAt 较新者胜；单边存在则并入。
  /// 注意：删除不会跨端传播（无墓碑），本地删除的规则若远端仍有会再被合并回来。
  Future<void> mergeTextRules(List<Map<String, dynamic>> remote) =>
      _guard(() async {
        if (remote.isEmpty) return;
        await _ensureDb();
        final local = await getTextRules();
        final localMap = {for (final e in local) e['id']?.toString() ?? '': e};
        await _db.transaction(() async {
          var sort = local.length;
          for (final r in remote) {
            final id = r['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            final l = localMap[id];
            final remoteUpdated = (r['updatedAt'] as num?)?.toInt() ?? 0;
            final localUpdated = (l?['updatedAt'] as num?)?.toInt() ?? 0;
            if (l != null && localUpdated >= remoteUpdated) continue;
            final companion = TextRuleTableCompanion.insert(
              id: id,
              name: r['name']?.toString() ?? '',
              stepsJson: Value(r['stepsJson']?.toString() ?? '[]'),
              sort: Value(
                l != null ? ((l['sort'] as num?)?.toInt() ?? sort) : sort,
              ),
              createdAt:
                  (r['createdAt'] as num?)?.toInt() ??
                  (l?['createdAt'] as num?)?.toInt() ??
                  DateTime.now().millisecondsSinceEpoch,
              updatedAt: Value(remoteUpdated),
            );
            await _db
                .into(_db.textRuleTable)
                .insertOnConflictUpdate(companion);
            sort++;
          }
        });
      });

  // ─── 剪贴板/备忘录 ─────────────────────────────

  /// 全部备忘（按更新时间倒序）
  Future<List<Map<String, dynamic>>> getMemos() => _guard(() async {
    await _ensureDb();
    final rows =
        await (_db.select(_db.memoTable)
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    return rows
        .map(
          (r) => {
            'id': r.id,
            'content': r.content,
            'createdAt': r.createdAt,
            'updatedAt': r.updatedAt,
          },
        )
        .toList();
  });

  /// 新增一条备忘，返回 id
  Future<String> addMemo(String content) => _guard(() async {
    await _ensureDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = '${now}_${content.hashCode}';
    await _db
        .into(_db.memoTable)
        .insert(
          MemoTableCompanion.insert(
            id: id,
            content: content,
            createdAt: now,
            updatedAt: Value(now),
          ),
        );
    return id;
  });

  /// 更新备忘内容（updatedAt 同步刷新，用于排序与多端合并）
  Future<void> updateMemo(String id, String content) => _guard(() async {
    await _ensureDb();
    await (_db.update(_db.memoTable)..where((t) => t.id.equals(id))).write(
      MemoTableCompanion(
        content: Value(content),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  });

  /// 删除一条备忘
  Future<void> deleteMemo(String id) => _guard(() async {
    await _ensureDb();
    await (_db.delete(_db.memoTable)..where((t) => t.id.equals(id))).go();
  });
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
