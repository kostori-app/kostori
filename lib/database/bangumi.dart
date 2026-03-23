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
  return NativeDatabase.createInBackground(file);
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

  Future<void> init() async {
    if (isInitialized) return;
    _db = _BangumiDb();
    isInitialized = true;
  }

  Future<void> close() async {
    await _db.close();
    isInitialized = false;
  }

  // ─── bangumi_data ──────────────────────────

  Future<void> addBangumiData(BangumiData item) async {
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
              sites: Value(item.sites != null ? jsonEncode(item.sites) : null),
            ),
          );
    } catch (e, s) {
      DebugLog.error('addBangumiData', 'title=${item.title} error=$e\n$s');
    }
  }

  Future<void> batchAddBangumiData(List<BangumiData> list) async {
    DebugLog.info('batchAddBangumiData', 'start, list.length=${list.length}');
    try {
      await _db.transaction(() async {
        for (int i = 0; i < list.length; i++) {
          await addBangumiData(list[i]);
          if (i % 50 == 0) {
            DebugLog.info('batchAddBangumiData', 'progress $i/${list.length}');
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
  }

  Future<String?> findbangumiDataByID(int id) async {
    final rows = await _db
        .customSelect(
          "SELECT sites, begin FROM bangumi_data WHERE sites LIKE ?",
          variables: [Variable.withString('%"bangumi","id":"$id"%')],
          readsFrom: {_db.bangumiDataTable},
        )
        .get();
    if (rows.isEmpty) return null;
    return rows.first.read<String?>('begin');
  }

  Future<Map<String, BangumiDataEntry>> checkWhetherDataExistsBatch(
    List<String> ids,
  ) async {
    DebugLog.info(
      'checkWhetherDataExistsBatch',
      'start, ids.length=${ids.length}',
    );
    if (ids.isEmpty) return {};

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

    DebugLog.info('checkWhetherDataExistsBatch', 'matched rows=${rows.length}');

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
  }

  Future<bool> checkWhetherDataExists(String id) async {
    final map = await checkWhetherDataExistsBatch([id]);
    return map.containsKey(id);
  }

  Future<void> clearBangumiData() async {
    await _db.delete(_db.bangumiDataTable).go();
  }

  // ─── bangumi_calendar ──────────────────────

  Future<void> addBangumiCalendar(BangumiItem item) async {
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
  }

  Future<void> batchAddBangumiCalendar(List<BangumiItem> items) async {
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
  }

  Future<List<BangumiItem>> getWeeks(List<int> weeks) async {
    if (weeks.isEmpty) return [];
    final rows =
        await (_db.select(_db.bangumiCalendarTable)
              ..where((t) => t.airWeekday.isIn(weeks))
              ..orderBy([(t) => OrderingTerm.desc(t.airWeekday)]))
            .get();
    return rows.map(_calendarRowToItem).toList();
  }

  Future<List<BangumiItem>> getWeek(int week) => getWeeks([week]);

  Future<void> clearBangumiCalendar() async {
    await _db.delete(_db.bangumiCalendarTable).go();
  }

  // ─── bangumi_binding ───────────────────────

  Future<void> addBangumiBinding(BangumiItem item) async {
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
            tags: Value(jsonEncode(item.tags.map((t) => t.toJson()).toList())),
            alias: Value(jsonEncode(item.alias)),
          ),
        );
  }

  Future<BangumiItem?> findBinding(int id) async {
    final row = await (_db.select(
      _db.bangumiBindingTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _bindingRowToItem(row);
  }

  Future<BangumiItem?> getBangumiItem(int id) async {
    final row = await (_db.select(
      _db.bangumiBindingTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row != null ? _bindingRowToItem(row) : null;
  }

  Future<List<BangumiItem>> getBindAll() async {
    final rows = await (_db.select(
      _db.bangumiBindingTable,
    )..orderBy([(t) => OrderingTerm.desc(t.id)])).get();
    return rows.map(_bindingRowToItem).toList();
  }

  Stream<List<BangumiItem>> watchBindAll() {
    return (_db.select(_db.bangumiBindingTable)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .watch()
        .map((rows) => rows.map(_bindingRowToItem).toList());
  }

  // ─── bangumi_AllEpInfo ─────────────────────

  Future<void> addBangumiAllEpInfo(int bangumiId, dynamic data) async {
    await _db
        .into(_db.bangumiAllEpInfoTable)
        .insertOnConflictUpdate(
          BangumiAllEpInfoTableCompanion(
            id: Value(bangumiId),
            data: Value(jsonEncode(data)),
          ),
        );
  }

  Future<List<EpisodeInfo>> allEpInfoFind(int id) async {
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
      return [];
    }

    try {
      final list = jsonDecode(row!.data!) as List;
      DebugLog.info(
        'allEpInfoFind',
        'id=$id → decoded ${list.length} episodes',
      );
      return list.map((e) => EpisodeInfo.fromJson(e)).toList();
    } catch (e, s) {
      DebugLog.error('allEpInfoFind', 'id=$id → jsonDecode failed: $e\n$s');
      return [];
    }
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
