import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kostori/foundation/app.dart';
import 'package:path/path.dart' as p;

part 'favorite_database.g.dart';

/// 收藏分组元数据（替代旧 folder_order + 每分组动态表）。
/// 对外仍以 [name] 为身份，内部用稳定 [id] 作为 favorite_items 的外键。
class FavoriteFolders extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().unique()();

  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 收藏条目单表：一行为"某分组里的某部番"。
/// 同一部番可出现在多个分组（PK = folderId,id,type），
/// display_order 表示组内顺序（非全局）。
@DataClassName('FavoriteItemRow')
class FavoriteItems extends Table {
  TextColumn get folderId => text().references(
    FavoriteFolders,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get author => text().nullable()();

  IntColumn get type => integer()();

  TextColumn get tags => text().nullable()();

  TextColumn get coverPath => text().nullable()();

  TextColumn get time => text().nullable()();

  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  TextColumn get recentlyWatched => text().nullable()();

  TextColumn get viewMore => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {folderId, id, type};
}

@DriftDatabase(tables: [FavoriteFolders, FavoriteItems])
class FavoriteDatabase extends _$FavoriteDatabase {
  FavoriteDatabase(super.e);

  @override
  int get schemaVersion => 2;

  /// 统一打开入口：与收藏旧库同一路径（local_favorite.db）
  factory FavoriteDatabase.open(String dbPath) {
    return FavoriteDatabase(
      NativeDatabase.createInBackground(File(dbPath)),
    );
  }

  static String defaultPath() => p.join(App.dataPath, 'local_favorite.db');

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _migrateLegacyMultiTableSchema();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createAll();
        // 幂等：若还有遗留多表结构则补搬（通常是 v1 drift 空壳库/中断场景）
        await _migrateLegacyMultiTableSchema();
      }
    },
    beforeOpen: (details) async {
      // 兼容旧库可能打开的外键/文件损坏容错等
    },
  );

  /// 旧版（重构前）结构：每个分组是一张 "$folder" 动态表 + folder_order +
  /// folder_sync。首次用 drift 打开同一文件时，把这些数据无损搬进新表，
  /// 然后删除旧表。folder 内部 id 沿用分组名（对外身份本就是名字串）。
  Future<void> _migrateLegacyMultiTableSchema() async {
    final tables = (await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    ).get())
        .map((r) => r.read<String>('name'))
        .toList();
    final own = {'favorite_folders', 'favorite_items'};
    final legacyFolders = tables
        .where((n) => !own.contains(n) && n != 'folder_order' && n != 'folder_sync')
        .toList();
    if (legacyFolders.isEmpty) return;

    // 分组顺序：folder_order(folder_name PK, order_value)；缺失按名称排序
    var order = <String, int>{};
    try {
      final rows = await customSelect(
        'SELECT folder_name, order_value FROM folder_order',
      ).get();
      order = {
        for (final r in rows)
          r.read<String>('folder_name'): r.read<int>('order_value'),
      };
    } catch (_) {}

    for (var i = 0; i < legacyFolders.length; i++) {
      final name = legacyFolders[i];
      final sortOrder = order[name] ?? i;
      await into(favoriteFolders).insertOnConflictUpdate(
        FavoriteFoldersCompanion.insert(
          id: name,
          name: name,
          sortOrder: sortOrder,
        ),
      );
    }

    for (final name in legacyFolders) {
      final rows = await customSelect('SELECT * FROM "${_escape(name)}"').get();
      for (final r in rows) {
        final d = r.data;
        await into(favoriteItems).insertOnConflictUpdate(
          FavoriteItemsCompanion.insert(
            folderId: name,
            id: (d['id'] ?? '').toString(),
            name: (d['name'] ?? '').toString(),
            author: Value(d['author']?.toString()),
            type: (d['type'] as num?)?.toInt() ?? 0,
            tags: Value(d['tags']?.toString()),
            coverPath: Value(d['cover_path']?.toString()),
            time: Value(d['time']?.toString()),
            displayOrder: Value((d['display_order'] as num?)?.toInt() ?? 0),
            recentlyWatched: Value(d['recently_watched']?.toString()),
            viewMore: Value(d['viewMore']?.toString()),
          ),
        );
      }
    }

    // 数据搬完才删旧表（同文件内联执行，任一步失败不会走到这里）
    for (final name in legacyFolders) {
      await customStatement('DROP TABLE IF EXISTS "${_escape(name)}"');
    }
    await customStatement('DROP TABLE IF EXISTS folder_order');
    await customStatement('DROP TABLE IF EXISTS folder_sync');
  }

  static String _escape(String name) => name.replaceAll('"', '""');
}
