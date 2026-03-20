import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/app.dart';
import 'package:path/path.dart' as p;

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

LazyDatabase _openConn() => LazyDatabase(() async {
  final file = File(p.join(App.dataPath, 'search_history.db'));
  return NativeDatabase.createInBackground(file);
});

class SearchHistoryItem {
  final String keyword;
  final int useCount;
  final int lastUsedAt;

  const SearchHistoryItem({
    required this.keyword,
    required this.useCount,
    required this.lastUsedAt,
  });
}

class SearchHistoryManager {
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

  void close() {
    _db.close();
    _cache = null;
    isInitialized = false;
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
      print('watchAll emitted: ${rows.length} items');
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
