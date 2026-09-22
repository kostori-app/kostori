import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/db_common.dart';

part 'search_history.g.dart';

class SearchHistoryTable extends Table {
  @override
  String get tableName => 'search_history';

  TextColumn get keyword => text()();

  IntColumn get useCount =>
      integer().named('useCount').withDefault(const Constant(1))();

  IntColumn get lastUsedAt => integer().named('lastUsedAt')();

  @override
  Set<Column> get primaryKey => {keyword};
}

@DriftDatabase(tables: [SearchHistoryTable])
class _SearchHistoryDb extends _$_SearchHistoryDb {
  _SearchHistoryDb() : super(_openConn());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

LazyDatabase _openConn() => openWalDb('search_history.db');

class SearchHistoryItem {
  final String keyword;
  final int useCount;
  final int lastUsedAt;

  const SearchHistoryItem({
    required this.keyword,
    required this.useCount,
    required this.lastUsedAt,
  });

  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'useCount': useCount,
    'lastUsedAt': lastUsedAt,
  };

  static SearchHistoryItem fromJson(Map<String, dynamic> json) =>
      SearchHistoryItem(
        keyword: json['keyword']?.toString() ?? '',
        useCount: (json['useCount'] as num?)?.toInt() ?? 0,
        lastUsedAt: (json['lastUsedAt'] as num?)?.toInt() ?? 0,
      );
}

class SearchHistoryManager with ChangeNotifier {
  static SearchHistoryManager? _cache;

  SearchHistoryManager._();

  factory SearchHistoryManager() => _cache ??= SearchHistoryManager._();

  late _SearchHistoryDb _db;
  bool isInitialized = false;

  Future<void> init() async {
    if (isInitialized) return;
    _db = _SearchHistoryDb();
    isInitialized = true;
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
    }

    await between?.call();

    _db = _SearchHistoryDb();
    isInitialized = true;
    notifyListeners();
  }

  Future<void> addSearch(String keyword) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customUpdate(
      '''
    INSERT INTO search_history (keyword, useCount, lastUsedAt)
    VALUES (?, 1, ?)
    ON CONFLICT(keyword) DO UPDATE SET
      useCount = useCount + 1,
      lastUsedAt = excluded.lastUsedAt
    ''',
      variables: [Variable.withString(keyword), Variable.withInt(now)],
      updates: {_db.searchHistoryTable},
    );
  }

  Stream<List<SearchHistoryItem>> watchAll({int? limit}) {
    final q = _db.select(_db.searchHistoryTable)
      ..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)]);
    if (limit != null) q.limit(limit);

    return q.watch().map((rows) {
      return rows
          .map(
            (r) => SearchHistoryItem(
              keyword: r.keyword,
              useCount: r.useCount,
              lastUsedAt: r.lastUsedAt,
            ),
          )
          .toList();
    });
  }

  /// 全部搜索记录（跨端同步用）
  Future<List<SearchHistoryItem>> all() async {
    final rows = await _db.select(_db.searchHistoryTable).get();
    return rows
        .map(
          (r) => SearchHistoryItem(
            keyword: r.keyword,
            useCount: r.useCount,
            lastUsedAt: r.lastUsedAt,
          ),
        )
        .toList();
  }

  /// 跨端合并：同名关键词取较大的使用次数与较新的时间
  Future<void> mergeSearchHistory(List<SearchHistoryItem> items) async {
    for (final e in items) {
      if (e.keyword.isEmpty) continue;
      await _db.customUpdate(
        '''
      INSERT INTO search_history (keyword, useCount, lastUsedAt)
      VALUES (?, ?, ?)
      ON CONFLICT(keyword) DO UPDATE SET
        useCount = MAX(useCount, excluded.useCount),
        lastUsedAt = MAX(lastUsedAt, excluded.lastUsedAt)
      ''',
        variables: [
          Variable.withString(e.keyword),
          Variable.withInt(e.useCount),
          Variable.withInt(e.lastUsedAt),
        ],
        updates: {_db.searchHistoryTable},
      );
    }
    notifyListeners();
  }

  /// 把 WAL 里的改动写回主库文件（整库导出/覆盖前调用）
  Future<void> checkpoint() => walCheckpoint(
    () => _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);'),
  );

  Future<void> deleteSearch(String keyword) async {
    await (_db.delete(
      _db.searchHistoryTable,
    )..where((t) => t.keyword.equals(keyword))).go();
  }

  Future<void> clearSearch() async {
    await _db.delete(_db.searchHistoryTable).go();
  }
}

final searchHistoryProvider =
    StreamNotifierProvider<SearchHistoryNotifier, List<SearchHistoryItem>>(
      SearchHistoryNotifier.new,
    );

class SearchHistoryNotifier extends StreamNotifier<List<SearchHistoryItem>> {
  @override
  Stream<List<SearchHistoryItem>> build() => SearchHistoryManager().watchAll();

  Future<void> add(String keyword) => SearchHistoryManager().addSearch(keyword);

  Future<void> delete(String keyword) =>
      SearchHistoryManager().deleteSearch(keyword);

  Future<void> clear() => SearchHistoryManager().clearSearch();
}
