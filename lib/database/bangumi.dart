import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/bangumi_tag.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/log.dart';
import 'package:path/path.dart' as p;

part 'bangumi.g.dart';

// ═══════════════════════════════════════════════════════════
// 数据类
// ═══════════════════════════════════════════════════════════

/// bangumi_data 表条目的基础信息（用于补全日历）
class BangumiDataBasic {
  final String title;
  final String? titleTranslate;
  final String? begin;
  final String? end;

  const BangumiDataBasic({
    required this.title,
    this.titleTranslate,
    this.begin,
    this.end,
  });
}

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

  BangumiData.fromJson(Map<String, dynamic> json)
    : title = json["title"],
      titleTranslate = json["titleTranslate"],
      type = json["type"],
      lang = json["lang"],
      officialSite = json["officialSite"],
      begin = json["begin"],
      broadcast = json["broadcast"],
      end = json["end"],
      comment = json["comment"],
      sites = json["sites"];

  Map<String, dynamic> toMap() => {
    "title": title,
    "titleTranslate": titleTranslate,
    "type": type,
    "lang": lang,
    "officialSite": officialSite,
    "begin": begin,
    "broadcast": broadcast,
    "end": end,
    "comment": comment,
    "sites": sites,
  };
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

  BnagumiCalendar.fromModel({
    this.id,
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
    this.images,
  });
}

// ═══════════════════════════════════════════════════════════
// 表定义
// ═══════════════════════════════════════════════════════════

class BangumiDataTable extends Table {
  @override
  String get tableName => 'bangumi_data';

  TextColumn get title => text()();

  TextColumn get titleTranslate => text().named('titleTranslate').nullable()();

  TextColumn get type => text().nullable()();

  TextColumn get lang => text().nullable()();

  TextColumn get officialSite => text().named('officialSite').nullable()();

  TextColumn get begin => text().nullable()();

  TextColumn get broadcast => text().nullable()();

  TextColumn get end => text().nullable()();

  TextColumn get comment => text().nullable()();

  TextColumn get sites => text().nullable()();

  @override
  Set<Column> get primaryKey => {title};
}

class BangumiCalendarTable extends Table {
  @override
  String get tableName => 'bangumi_calendar';

  IntColumn get id => integer()();

  IntColumn get type => integer().nullable()();

  TextColumn get name => text().nullable()();

  TextColumn get nameCn => text().named('nameCn').nullable()();

  TextColumn get summary => text().nullable()();

  TextColumn get airDate => text().named('airDate').nullable()();

  IntColumn get airWeekday => integer().named('airWeekday').nullable()();

  IntColumn get total => integer().nullable()();

  TextColumn get count => text().nullable()();

  RealColumn get score => real().nullable()();

  IntColumn get rank => integer().nullable()();

  TextColumn get images => text().nullable()();

  TextColumn get collection => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class BangumiBindingTable extends Table {
  @override
  String get tableName => 'bangumi_binding';

  IntColumn get id => integer()();

  IntColumn get type => integer().nullable()();

  TextColumn get name => text().nullable()();

  TextColumn get nameCn => text().named('nameCn').nullable()();

  TextColumn get summary => text().nullable()();

  TextColumn get airDate => text().named('airDate').nullable()();

  IntColumn get airWeekday => integer().named('airWeekday').nullable()();

  IntColumn get total => integer().nullable()();

  IntColumn get totalEpisodes => integer().named('totalEpisodes').nullable()();

  TextColumn get count => text().nullable()();

  RealColumn get score => real().nullable()();

  IntColumn get rank => integer().nullable()();

  TextColumn get images => text().nullable()();

  TextColumn get collection => text().nullable()();

  TextColumn get tags => text().nullable()();

  TextColumn get alias => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class BangumiAllEpInfoTable extends Table {
  @override
  String get tableName => 'bangumi_AllEpInfo';

  IntColumn get id => integer()();

  TextColumn get data => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ═══════════════════════════════════════════════════════════
// 数据库
// ═══════════════════════════════════════════════════════════

@DriftDatabase(
  tables: [
    BangumiDataTable,
    BangumiCalendarTable,
    BangumiBindingTable,
    BangumiAllEpInfoTable,
  ],
)
class _BangumiDb extends _$_BangumiDb {
  _BangumiDb() : super(_openConn());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

LazyDatabase _openConn() => LazyDatabase(() async {
  final file = File(p.join(App.dataPath, 'bangumi.db'));
  return NativeDatabase.createInBackground(
    file,
    setup: (db) {
      // WAL + NORMAL：异常中断（杀进程/崩溃/强制退出）时大幅降低
      // 数据库损坏（disk image malformed）概率
      db.execute('PRAGMA journal_mode = WAL;');
      db.execute('PRAGMA synchronous = NORMAL;');
    },
  );
});

// ═══════════════════════════════════════════════════════════
// 辅助：Drift 行 → BangumiItem
// ═══════════════════════════════════════════════════════════

BangumiItem _calendarRowToItem(BangumiCalendarTableData r) => BangumiItem(
  id: r.id,
  type: r.type ?? 0,
  name: r.name ?? '',
  nameCn: r.nameCn ?? '',
  summary: r.summary ?? '',
  airDate: r.airDate ?? '2077',
  airWeekday: r.airWeekday ?? 0,
  rank: r.rank ?? 0,
  total: r.total ?? 0,
  totalEpisodes: 0,
  score: r.score ?? 0.0,
  images: r.images != null
      ? Map<String, String>.from(jsonDecode(r.images!))
      : {},
  tags: [],
  count: r.count != null ? Map<String, int>.from(jsonDecode(r.count!)) : null,
  collection: r.collection != null
      ? Map<String, int>.from(jsonDecode(r.collection!))
      : null,
);

BangumiItem _bindingRowToItem(BangumiBindingTableData r) => BangumiItem(
  id: r.id,
  type: r.type ?? 0,
  name: r.name ?? '',
  nameCn: r.nameCn ?? '',
  summary: r.summary ?? '',
  airDate: r.airDate ?? '2077',
  airWeekday: r.airWeekday ?? 0,
  rank: r.rank ?? 0,
  total: r.total ?? 0,
  totalEpisodes: r.totalEpisodes ?? 0,
  score: r.score ?? 0.0,
  images: r.images != null
      ? Map<String, String>.from(jsonDecode(r.images!))
      : {},
  tags: r.tags != null
      ? (jsonDecode(r.tags!) as List)
            .map((e) => BangumiTag.fromJson(e))
            .toList()
      : [],
  alias: r.alias != null ? (jsonDecode(r.alias!) as List).cast<String>() : [],
  count: r.count != null ? Map<String, int>.from(jsonDecode(r.count!)) : null,
  collection: r.collection != null
      ? Map<String, int>.from(jsonDecode(r.collection!))
      : null,
);

// ═══════════════════════════════════════════════════════════
// BangumiManager（单例）
// ═══════════════════════════════════════════════════════════

class BangumiManager with ChangeNotifier {
  BangumiManager._();

  static final BangumiManager instance = BangumiManager._();

  late _BangumiDb _db;
  bool isInitialized = false;

  /// 在途数据库操作计数；close/reinit 前等待归零，
  /// 避免数据导入关库打断在途查询（"database disk image is malformed"）
  int _busy = 0;

  /// 防止并发触发多次重建损坏表
  bool _allEpRepairing = false;

  Future<void> _waitIdle() async {
    while (_busy > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<T> _guard<T>(Future<T> Function() op) {
    _busy++;
    try {
      return Future.sync(op).whenComplete(() => _busy--);
    } catch (_) {
      _busy--;
      rethrow;
    }
  }

  Future<void> init() async {
    if (isInitialized) return;
    _db = _BangumiDb();
    isInitialized = true;
  }

  Future<void> close() async {
    await _waitIdle();
    await _db.close();
    isInitialized = false;
  }

  Future<void> reinit([Future<void> Function()? between]) async {
    await _waitIdle();
    if (isInitialized) {
      await _db.close();
      isInitialized = false;
    }

    await between?.call();

    _db = _BangumiDb();
    isInitialized = true;
    notifyListeners();
  }

  // ─── bangumi_data ──────────────────────────

  Future<void> addBangumiData(BangumiData item) {
    return _guard(() async {
      try {
        await _db
            .into(_db.bangumiDataTable)
            .insertOnConflictUpdate(
              BangumiDataTableCompanion.insert(
                title: item.title ?? '',
                titleTranslate: Value(
                  item.titleTranslate != null
                      ? jsonEncode(item.titleTranslate)
                      : null,
                ),
                type: Value(item.type),
                lang: Value(item.lang),
                officialSite: Value(item.officialSite),
                begin: Value(item.begin),
                broadcast: Value(item.broadcast),
                end: Value(item.end),
                comment: Value(item.comment),
                sites: Value(
                  item.sites != null ? jsonEncode(item.sites) : null,
                ),
              ),
            );
      } catch (e, s) {
        DebugLog.error('addBangumiData', 'title=${item.title} error=$e\n$s');
      }
    });
  }

  Future<void> batchAddBangumiData(List<BangumiData> list) {
    return _guard(() async {
      DebugLog.info('batchAddBangumiData', 'start, list.length=${list.length}');
      try {
        await _db.transaction(() async {
          for (int i = 0; i < list.length; i++) {
            await addBangumiData(list[i]);
            if (i % 50 == 0) {
              DebugLog.info(
                'batchAddBangumiData',
                'progress $i/${list.length}',
              );
            }
          }
        });
        DebugLog.info('batchAddBangumiData', 'done, inserted=${list.length}');
        final count = await _db
            .customSelect(
              'SELECT COUNT(*) as cnt FROM bangumi_data',
              readsFrom: {_db.bangumiDataTable},
            )
            .getSingle();
        DebugLog.info(
          'batchAddBangumiData',
          'db count after insert=${count.read<int>('cnt')}',
        );
      } catch (e, s) {
        DebugLog.error('batchAddBangumiData', 'error=$e\n$s');
      }
    });
  }

  Future<String?> findbangumiDataByID(int id) {
    return _guard(() async {
      final rows = await _db
          .customSelect(
            "SELECT sites, begin FROM bangumi_data WHERE sites LIKE ?",
            variables: [Variable.withString('%"bangumi","id":"$id"%')],
            readsFrom: {_db.bangumiDataTable},
          )
          .get();
      if (rows.isEmpty) return null;
      return rows.first.read<String?>('begin');
    });
  }

  Future<Map<String, BangumiDataEntry>> checkWhetherDataExistsBatch(
    List<String> ids,
  ) {
    return _guard(() async {
      DebugLog.info(
        'checkWhetherDataExistsBatch',
        'start, ids.length=${ids.length}',
      );
      if (ids.isEmpty) return <String, BangumiDataEntry>{};

      // 查询前先看数据库总数
      final count = await _db
          .customSelect(
            'SELECT COUNT(*) as cnt FROM bangumi_data',
            readsFrom: {_db.bangumiDataTable},
          )
          .getSingle();
      DebugLog.info(
        'checkWhetherDataExistsBatch',
        'total db rows=${count.read<int>('cnt')}',
      );

      final conditions = List.generate(
        ids.length,
        (_) => 'sites LIKE ?',
      ).join(' OR ');
      final patterns = ids
          .map((id) => Variable.withString('%"bangumi","id":"$id"%'))
          .toList();

      final rows = await _db
          .customSelect(
            'SELECT sites, begin, end FROM bangumi_data WHERE $conditions',
            variables: patterns,
            readsFrom: {_db.bangumiDataTable},
          )
          .get();

      DebugLog.info(
        'checkWhetherDataExistsBatch',
        'matched rows=${rows.length}',
      );

      final result = <String, BangumiDataEntry>{};
      for (final row in rows) {
        try {
          final sites = jsonDecode(row.read<String>('sites')) as List;
          final begin = row.read<String?>('begin');
          final end = row.read<String?>('end');
          for (final site in sites.cast<Map>()) {
            if (site['site'] == 'bangumi') {
              result[site['id'].toString()] = BangumiDataEntry(
                begin: begin,
                end: end,
              );
            }
          }
        } catch (e) {
          DebugLog.error('checkWhetherDataExistsBatch', 'parse error: $e');
        }
      }

      DebugLog.info(
        'checkWhetherDataExistsBatch',
        'result size=${result.length}',
      );
      return result;
    });
  }

  Future<bool> checkWhetherDataExists(String id) async {
    final map = await checkWhetherDataExistsBatch([id]);
    return map.containsKey(id);
  }

  /// 读取 bangumi_data 表中所有含 bangumi 站点的条目（id → 基础信息）。
  /// 用于补全日历：日历接口只覆盖当季，这里能拿到更全的条目。
  Future<Map<int, BangumiDataBasic>> getAllBangumiDataEntries() {
    return _guard(() async {
      final result = <int, BangumiDataBasic>{};
      final rows = await _db.select(_db.bangumiDataTable).get();
      for (final row in rows) {
        final sitesRaw = row.sites;
        if (sitesRaw == null || sitesRaw.isEmpty) continue;
        try {
          final sites = jsonDecode(sitesRaw) as List;
          for (final site in sites.cast<Map>()) {
            if (site['site'] == 'bangumi') {
              final id = int.tryParse(site['id'].toString());
              if (id != null) {
                result[id] = BangumiDataBasic(
                  title: row.title,
                  titleTranslate: row.titleTranslate,
                  begin: row.begin,
                  end: row.end,
                );
              }
            }
          }
        } catch (e) {
          DebugLog.error('getAllBangumiDataEntries', 'parse error: $e');
        }
      }
      return result;
    });
  }

  Future<void> clearBangumiData() {
    return _guard(() async {
      await _db.delete(_db.bangumiDataTable).go();
    });
  }

  // ─── bangumi_calendar ──────────────────────

  Future<void> addBangumiCalendar(BangumiItem item) {
    return _guard(() async {
      await _db
          .into(_db.bangumiCalendarTable)
          .insertOnConflictUpdate(
            BangumiCalendarTableCompanion(
              id: Value(item.id),
              type: Value(item.type),
              name: Value(item.name),
              nameCn: Value(item.nameCn),
              summary: Value(item.summary),
              airDate: Value(item.airDate),
              airWeekday: Value(item.airWeekday),
              total: Value(item.total),
              count: Value(item.count != null ? jsonEncode(item.count) : null),
              score: Value(item.score.toDouble()),
              rank: Value(item.rank),
              images: Value(jsonEncode(item.images)),
              collection: Value(
                item.collection != null ? jsonEncode(item.collection) : null,
              ),
            ),
          );
    });
  }

  Future<void> batchAddBangumiCalendar(List<BangumiItem> items) {
    return _guard(() async {
      try {
        await _db.transaction(() async {
          for (final item in items) {
            await addBangumiCalendar(item);
          }
        });
        DebugLog.info('batchAddBangumiCalendar', items.length.toString());
      } catch (e, stack) {
        DebugLog.info('batchAddBangumiCalendar', e.toString());
        DebugLog.info('batchAddBangumiCalendar', stack.toString());
      }
    });
  }

  Future<List<BangumiItem>> getWeeks(List<int> weeks) {
    return _guard(() async {
      if (weeks.isEmpty) return <BangumiItem>[];
      final rows =
          await (_db.select(_db.bangumiCalendarTable)
                ..where((t) => t.airWeekday.isIn(weeks))
                ..orderBy([(t) => OrderingTerm.desc(t.airWeekday)]))
              .get();
      return rows.map(_calendarRowToItem).toList();
    });
  }

  Future<List<BangumiItem>> getWeek(int week) => getWeeks([week]);

  Future<void> clearBangumiCalendar() {
    return _guard(() async {
      await _db.delete(_db.bangumiCalendarTable).go();
    });
  }

  // ─── bangumi_binding ───────────────────────

  Future<void> addBangumiBinding(BangumiItem item) {
    return _guard(() async {
      await _db
          .into(_db.bangumiBindingTable)
          .insertOnConflictUpdate(
            BangumiBindingTableCompanion(
              id: Value(item.id),
              type: Value(item.type),
              name: Value(item.name),
              nameCn: Value(item.nameCn),
              summary: Value(item.summary),
              airDate: Value(item.airDate),
              airWeekday: Value(item.airWeekday),
              total: Value(item.total),
              totalEpisodes: Value(item.totalEpisodes),
              count: Value(item.count != null ? jsonEncode(item.count) : null),
              score: Value(item.score.toDouble()),
              rank: Value(item.rank),
              images: Value(jsonEncode(item.images)),
              collection: Value(
                item.collection != null ? jsonEncode(item.collection) : null,
              ),
              tags: Value(
                jsonEncode(item.tags.map((t) => t.toJson()).toList()),
              ),
              alias: Value(jsonEncode(item.alias)),
            ),
          );
    });
  }

  Future<BangumiItem?> findBinding(int id) {
    return _guard(() async {
      final row = await (_db.select(
        _db.bangumiBindingTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : _bindingRowToItem(row);
    });
  }

  Future<BangumiItem?> getBangumiItem(int id) {
    return _guard(() async {
      final row = await (_db.select(
        _db.bangumiBindingTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row != null ? _bindingRowToItem(row) : null;
    });
  }

  Future<List<BangumiItem>> getBindAll() {
    return _guard(() async {
      final rows = await (_db.select(
        _db.bangumiBindingTable,
      )..orderBy([(t) => OrderingTerm.desc(t.id)])).get();
      return rows.map(_bindingRowToItem).toList();
    });
  }

  Stream<List<BangumiItem>> watchBindAll() {
    return (_db.select(_db.bangumiBindingTable)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .watch()
        .map((rows) => rows.map(_bindingRowToItem).toList());
  }

  // ─── bangumi_AllEpInfo ─────────────────────

  Future<void> addBangumiAllEpInfo(int bangumiId, dynamic data) {
    return _guard(() async {
      await _db
          .into(_db.bangumiAllEpInfoTable)
          .insertOnConflictUpdate(
            BangumiAllEpInfoTableCompanion(
              id: Value(bangumiId),
              data: Value(jsonEncode(data)),
            ),
          );
    });
  }

  Future<List<EpisodeInfo>> allEpInfoFind(int id) {
    return _guard(() async {
      try {
        final row = await (_db.select(
          _db.bangumiAllEpInfoTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();

        DebugLog.info(
          'allEpInfoFind',
          'id=$id, row=${row == null ? 'null' : 'found'}, data=${row?.data == null ? 'null' : 'length:${row!.data!.length}'}',
        );

        if (row?.data == null) {
          DebugLog.info(
            'allEpInfoFind',
            'id=$id → row or data is null, returning []',
          );
          return <EpisodeInfo>[];
        }

        try {
          final list = jsonDecode(row!.data!) as List;
          DebugLog.info(
            'allEpInfoFind',
            'id=$id → decoded ${list.length} episodes',
          );
          return list.map((e) => EpisodeInfo.fromJson(e)).toList();
        } catch (e, s) {
          DebugLog.error(
            'allEpInfoFind',
            'id=$id → jsonDecode failed: $e\n$s',
          );
          return <EpisodeInfo>[];
        }
      } catch (e, s) {
        // 数据库损坏（disk image malformed）：只重建损坏的表恢复，
        // 不整库删除；重建后该表的缓存清空，重新从 bangumi 拉取。
        // 注意：库经 drift remote（isolate）执行，传回的异常可能被包装成
        // 非 SqliteException，故同时用 message 判断
        final msg = e.toString();
        final isMalformed =
            (e is SqliteException && e.resultCode == 11) ||
            msg.contains('malformed') ||
            msg.contains('code 11');
        if (isMalformed) {
          await _repairAllEpInfoTable();
        }
        Log.error('allEpInfoFind', '读取失败 id=$id: $e\n$s');
        return <EpisodeInfo>[];
      }
    });
  }

  /// 重建损坏的 bangumi_AllEpInfo 表（disk image malformed 时调用）。
  /// 只重建该表，保留其余数据；重建失败（文件损坏严重）时自动整库重建兜底
  Future<void> _repairAllEpInfoTable() async {
    if (_allEpRepairing) return;
    _allEpRepairing = true;
    try {
      final table = _db.bangumiAllEpInfoTable;
      await _db.customStatement('DROP TABLE IF EXISTS "${table.tableName}"');
      final migrator = Migrator(_db);
      await migrator.createTable(table);
      // 重开连接：清空 drift 缓存的 prepared statement（保留数据）。
      // 注意不能用 reinit()——重建由 _guard 内的查询触发，_waitIdle 会死锁
      await _reopenDb();
      DebugLog.info('allEpInfoFind', '已重建 ${table.tableName} 表');
    } catch (e, s) {
      Log.error(
        'allEpInfoFind',
        '重建 ${_db.bangumiAllEpInfoTable.tableName} 失败，尝试整库重建: $e\n$s',
      );
      await _rebuildDatabase();
    } finally {
      _allEpRepairing = false;
    }
  }

  /// 整库重建：删除 bangumi.db 文件并重新初始化（表级重建失败时的兜底）。
  /// 不走 reinit（它先 _waitIdle，重建由在途查询触发时会死锁），直接关连
  Future<void> _rebuildDatabase() async {
    try {
      await _db.close();
      isInitialized = false;
      final f = File(p.join(App.dataPath, 'bangumi.db'));
      if (await f.exists()) await f.delete();
      await _openFreshDb();
      DebugLog.info('allEpInfoFind', '已重建整个 bangumi 数据库');
    } catch (e, s) {
      Log.error('allEpInfoFind', '整库重建失败: $e\n$s');
      // 确保连接仍可恢复，避免后续查询全部失效
      if (!isInitialized) {
        try {
          await _openFreshDb();
        } catch (_) {}
      }
    }
  }

  /// 关闭旧连接并打开新连接（保留数据文件）
  Future<void> _reopenDb() async {
    await _db.close();
    isInitialized = false;
    await _openFreshDb();
  }

  Future<void> _openFreshDb() async {
    _db = _BangumiDb();
    isInitialized = true;
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════
// Riverpod
// ═══════════════════════════════════════════════════════════

final bangumiManagerProvider = Provider<BangumiManager>((ref) {
  return BangumiManager.instance;
});

final bangumiInitProvider = FutureProvider<BangumiManager>((ref) async {
  final manager = ref.watch(bangumiManagerProvider);
  if (!manager.isInitialized) {
    await manager.init();
  }
  return manager;
});

final bangumiBindAllProvider =
    StreamNotifierProvider<BangumiBindAllNotifier, List<BangumiItem>>(
      BangumiBindAllNotifier.new,
    );

class BangumiBindAllNotifier extends StreamNotifier<List<BangumiItem>> {
  @override
  Stream<List<BangumiItem>> build() {
    final initAsync = ref.watch(bangumiInitProvider);
    return initAsync.when(
      data: (manager) => manager.watchBindAll(),
      loading: () => const Stream.empty(),
      error: (err, stack) => Stream.error(err, stack),
    );
  }
}
