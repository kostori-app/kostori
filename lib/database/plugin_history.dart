import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';
import 'package:path/path.dart' as p;

part 'plugin_history.g.dart';

class PluginEventTable extends Table {
  @override
  String get tableName => 'plugin_events';

  TextColumn get pluginKey => text()();

  /// open | search
  TextColumn get kind => text()();

  TextColumn get itemKey => text()();

  TextColumn get title => text()();

  TextColumn get subtitle => text().withDefault(const Constant(''))();

  TextColumn get coverUrl => text().withDefault(const Constant(''))();

  /// 用于恢复原页的 JSON（page/params/item）
  TextColumn get extraJson => text().withDefault(const Constant('{}'))();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {pluginKey, kind, itemKey};
}

@DriftDatabase(tables: [PluginEventTable])
class _PluginHistoryDb extends _$_PluginHistoryDb {
  _PluginHistoryDb() : super(_openConn());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

LazyDatabase _openConn() => LazyDatabase(() async {
  final file = File(p.join(App.dataPath, 'plugin_history.db'));
  return NativeDatabase.createInBackground(file);
});

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
}

/// 个人页插件浏览/搜索历史
class PluginHistoryManager with ChangeNotifier {
  static PluginHistoryManager? _instance;

  factory PluginHistoryManager() => _instance ??= PluginHistoryManager._();

  PluginHistoryManager._();

  _PluginHistoryDb? _db;

  Future<_PluginHistoryDb> _open() async {
    final db = _db ??= _PluginHistoryDb();
    return db;
  }

  PluginEventItem _rowToItem(PluginEventTableData row) => PluginEventItem(
    pluginKey: row.pluginKey,
    kind: row.kind,
    itemKey: row.itemKey,
    title: row.title,
    subtitle: row.subtitle,
    coverUrl: row.coverUrl,
    extraJson: row.extraJson,
    createdAt: row.createdAt,
  );

  Future<void> addEvent({
    required String pluginKey,
    required String kind,
    required String itemKey,
    required String title,
    String subtitle = '',
    String coverUrl = '',
    String extraJson = '{}',
  }) async {
    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.pluginEventTable).insertOnConflictUpdate(
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
    // 每类最多保留 200 条
    const cap = 200;
    final rows = await (db.select(db.pluginEventTable)
          ..where(
            (tbl) =>
                tbl.pluginKey.equals(pluginKey) & tbl.kind.equals(kind),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    if (rows.length > cap) {
      final ids = rows.skip(cap).map((r) => r.itemKey).toList();
      await (db.delete(db.pluginEventTable)
            ..where(
              (tbl) =>
                  tbl.pluginKey.equals(pluginKey) &
                  tbl.kind.equals(kind) &
                  tbl.itemKey.isIn(ids),
            ))
          .go();
    }
    notifyListeners();
  }

  Future<List<PluginEventItem>> listEvents(String pluginKey) async {
    final db = await _open();
    final rows = await (db.select(db.pluginEventTable)
          ..where((tbl) => tbl.pluginKey.equals(pluginKey))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_rowToItem).toList();
  }

  Future<void> clear(String pluginKey) async {
    final db = await _open();
    await (db.delete(db.pluginEventTable)
          ..where((tbl) => tbl.pluginKey.equals(pluginKey)))
        .go();
    notifyListeners();
  }
}
