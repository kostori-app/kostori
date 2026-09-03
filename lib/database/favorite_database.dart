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
  int get schemaVersion => 1;

  /// 统一打开入口：与收藏旧库同一路径（local_favorite.db）
  factory FavoriteDatabase.open(String dbPath) {
    return FavoriteDatabase(
      NativeDatabase.createInBackground(File(dbPath)),
    );
  }

  static String defaultPath() => p.join(App.dataPath, 'local_favorite.db');
}
