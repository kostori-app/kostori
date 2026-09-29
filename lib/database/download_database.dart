import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:kostori/database/db_common.dart';
import 'package:kostori/foundation/app.dart';
import 'package:path/path.dart' as p;

part 'download_database.g.dart';

/// 下载记录（完成的任务）。按 filePath 去重（同路径只留一条）。
@TableIndex(name: 'dl_rec_source', columns: {#sourceKey})
@TableIndex(name: 'dl_rec_anime', columns: {#animeId})
class DownloadRecordTable extends Table {
  @override
  String get tableName => 'download_record';

  TextColumn get filePath => text()();
  TextColumn get animeId => text().nullable()();
  TextColumn get sourceKey => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get episode => text().nullable()();
  TextColumn get episodeRaw => text().nullable()();
  TextColumn get resolution => text().nullable()();
  TextColumn get groupName => text().named('group_name').nullable()();
  IntColumn get totalBytes => integer().nullable()();
  TextColumn get time => text().nullable()();

  @override
  Set<Column> get primaryKey => {filePath};
}

/// 下载任务：整条 JSON 存一列（任务数相对少，读时一次性取出）。
class DownloadTaskTable extends Table {
  @override
  String get tableName => 'download_task';

  TextColumn get id => text()();
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 种子任务：整条 JSON 存一列。
class TorrentJobTable extends Table {
  @override
  String get tableName => 'torrent_job';

  TextColumn get id => text()();
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// BT 线路（内容级）。
class BtLineTable extends Table {
  @override
  String get tableName => 'bt_line';

  TextColumn get contentKey => text().named('content_key')();
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {contentKey};
}

/// BT 线的激活开关（内容级，存在即激活）。
class BtActiveTable extends Table {
  @override
  String get tableName => 'bt_active';

  TextColumn get contentKey => text().named('content_key')();

  @override
  Set<Column> get primaryKey => {contentKey};
}

/// 某一集的种子绑定。
class TorrentBindingTable extends Table {
  @override
  String get tableName => 'torrent_binding';

  TextColumn get key => text()();
  TextColumn get jobId => text().named('job_id')();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get label => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    DownloadRecordTable,
    DownloadTaskTable,
    TorrentJobTable,
    BtLineTable,
    BtActiveTable,
    TorrentBindingTable,
  ],
)
class DownloadDatabase extends _$DownloadDatabase {
  DownloadDatabase._() : super(openWalDb('download.db'));

  static final DownloadDatabase instance = DownloadDatabase._();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  // ── 下载记录 ────────────────────────────────────────────────────────────
  Future<void> upsertRecord(Map<String, dynamic> r) async {
    await into(downloadRecordTable).insertOnConflictUpdate(
      DownloadRecordTableCompanion.insert(
        filePath: r['filePath']?.toString() ?? '',
        animeId: Value(r['animeId']?.toString()),
        sourceKey: Value(r['sourceKey']?.toString()),
        title: Value(r['title']?.toString()),
        episode: Value(r['episode']?.toString()),
        episodeRaw: Value(r['episodeRaw']?.toString()),
        resolution: Value(r['resolution']?.toString()),
        groupName: Value(r['group']?.toString()),
        totalBytes: Value((r['totalBytes'] as num?)?.toInt()),
        time: Value(r['time']?.toString()),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> allRecords() async {
    final rows = await (select(
      downloadRecordTable,
    )..orderBy([(t) => OrderingTerm.desc(t.time)])).get();
    return rows.map(_recordToMap).toList();
  }

  Future<List<Map<String, dynamic>>> recordsForAnime(String animeId) async {
    final rows =
        await (select(downloadRecordTable)
              ..where((t) => t.animeId.equals(animeId))
              ..orderBy([(t) => OrderingTerm.desc(t.time)]))
            .get();
    return rows.map(_recordToMap).toList();
  }

  Future<List<Map<String, dynamic>>> recordsForSource(String sourceKey) async {
    final rows =
        await (select(downloadRecordTable)
              ..where((t) => t.sourceKey.equals(sourceKey))
              ..orderBy([(t) => OrderingTerm.desc(t.time)]))
            .get();
    return rows.map(_recordToMap).toList();
  }

  Future<void> deleteRecordByPath(String filePath) async {
    await (delete(
      downloadRecordTable,
    )..where((t) => t.filePath.equals(filePath))).go();
  }

  Future<void> updateRecordPath(
    String oldPath,
    String newPath, {
    String? group,
  }) async {
    await (update(
      downloadRecordTable,
    )..where((t) => t.filePath.equals(oldPath))).write(
      DownloadRecordTableCompanion(
        filePath: Value(newPath),
        groupName: group == null ? const Value.absent() : Value(group),
      ),
    );
  }

  /// 按 (animeId, episode, sourceKey) 删除记录（对应任务的移除）。
  Future<void> deleteRecordByEpisode({
    String? animeId,
    String? episode,
    String? sourceKey,
  }) async {
    await (delete(downloadRecordTable)..where(
          (t) =>
              _eq(t.animeId, animeId) &
              _eq(t.episode, episode) &
              _eq(t.sourceKey, sourceKey),
        ))
        .go();
  }

  static Expression<bool> _eq(Column<String> c, String? v) =>
      v == null ? c.isNull() : c.equals(v);

  /// 重命名记录：更新标题与文件路径。
  Future<void> updateRecordTitle(
    String filePath,
    String title,
    String newPath,
  ) async {
    await (update(
      downloadRecordTable,
    )..where((t) => t.filePath.equals(filePath))).write(
      DownloadRecordTableCompanion(
        title: Value(title),
        filePath: Value(newPath),
      ),
    );
  }

  /// 整表替换全部记录（分组重命名等批量场景）。
  Future<void> replaceAllRecords(List<Map<String, dynamic>> records) async {
    await transaction(() async {
      await delete(downloadRecordTable).go();
      for (final r in records) {
        await into(downloadRecordTable).insertOnConflictUpdate(
          DownloadRecordTableCompanion.insert(
            filePath: r['filePath']?.toString() ?? '',
            animeId: Value(r['animeId']?.toString()),
            sourceKey: Value(r['sourceKey']?.toString()),
            title: Value(r['title']?.toString()),
            episode: Value(r['episode']?.toString()),
            episodeRaw: Value(r['episodeRaw']?.toString()),
            resolution: Value(r['resolution']?.toString()),
            groupName: Value(r['group']?.toString()),
            totalBytes: Value((r['totalBytes'] as num?)?.toInt()),
            time: Value(r['time']?.toString()),
          ),
        );
      }
    });
  }

  Map<String, dynamic> _recordToMap(DownloadRecordTableData r) => {
    'animeId': r.animeId,
    'sourceKey': r.sourceKey,
    'title': r.title,
    'episode': r.episode,
    'episodeRaw': r.episodeRaw,
    'resolution': r.resolution,
    'group': r.groupName,
    'filePath': r.filePath,
    'totalBytes': r.totalBytes,
    'time': r.time,
  };

  // ── 下载任务 / 种子任务（整表替换） ─────────────────────────────────────
  Future<List<String>> loadTaskJson() async {
    final rows = await select(downloadTaskTable).get();
    return rows.map((r) => r.data).toList();
  }

  Future<void> saveTaskJson(List<String> jsons) async {
    await transaction(() async {
      await delete(downloadTaskTable).go();
      for (final j in jsons) {
        final id = (jsonDecode(j) as Map)['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        await into(downloadTaskTable).insertOnConflictUpdate(
          DownloadTaskTableCompanion.insert(id: id, data: j),
        );
      }
    });
  }

  Future<List<String>> loadJobJson() async {
    final rows = await select(torrentJobTable).get();
    return rows.map((r) => r.data).toList();
  }

  Future<void> saveJobJson(List<String> jsons) async {
    await transaction(() async {
      await delete(torrentJobTable).go();
      for (final j in jsons) {
        final id = (jsonDecode(j) as Map)['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        await into(torrentJobTable).insertOnConflictUpdate(
          TorrentJobTableCompanion.insert(id: id, data: j),
        );
      }
    });
  }

  // ── BT 线路 / 绑定 ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loadLines() async {
    final rows = await select(btLineTable).get();
    return {for (final r in rows) r.contentKey: jsonDecode(r.data) as dynamic};
  }

  Future<Map<String, dynamic>> loadActive() async {
    final rows = await select(btActiveTable).get();
    return {for (final r in rows) r.contentKey: true};
  }

  Future<Map<String, dynamic>> loadBindings() async {
    final rows = await select(torrentBindingTable).get();
    return {
      for (final r in rows)
        r.key: {
          'jobId': r.jobId,
          'filePath': r.filePath,
          'label': r.label ?? '',
        },
    };
  }

  Future<void> replaceLines(Map<String, dynamic> lines) async {
    await transaction(() async {
      await delete(btLineTable).go();
      for (final e in lines.entries) {
        await into(btLineTable).insert(
          BtLineTableCompanion.insert(
            contentKey: e.key,
            data: jsonEncode(e.value),
          ),
        );
      }
    });
  }

  Future<void> replaceActive(Map<String, dynamic> active) async {
    await transaction(() async {
      await delete(btActiveTable).go();
      for (final key in active.keys) {
        await into(btActiveTable)
            .insert(BtActiveTableCompanion.insert(contentKey: key));
      }
    });
  }

  Future<void> replaceBindings(Map<String, dynamic> bindings) async {
    await transaction(() async {
      await delete(torrentBindingTable).go();
      for (final e in bindings.entries) {
        final v = e.value;
        if (v is! Map) continue;
        await into(torrentBindingTable).insert(
          TorrentBindingTableCompanion.insert(
            key: e.key,
            jobId: v['jobId']?.toString() ?? '',
            filePath: v['filePath']?.toString() ?? '',
            label: Value(v['label']?.toString()),
          ),
        );
      }
    });
  }

  // ── JSON → DB 一次性迁移 ────────────────────────────────────────────────
  Future<void> migrateFromJson() async {
    try {
      // 记录
      final recFile = File(p.join(App.dataPath, 'download_records.json'));
      if (await recFile.exists()) {
        final empty = await (select(downloadRecordTable)..limit(1)).get();
        if (empty.isEmpty) {
          try {
            final list = jsonDecode(await recFile.readAsString()) as List;
            await transaction(() async {
              for (final e in list.whereType<Map>()) {
                await upsertRecord(Map<String, dynamic>.from(e));
              }
            });
          } catch (_) {}
        }
      }
      // 任务
      final taskFile = File(p.join(App.dataPath, 'download_tasks.json'));
      if (await taskFile.exists()) {
        final empty = await (select(downloadTaskTable)..limit(1)).get();
        if (empty.isEmpty) {
          try {
            final list = jsonDecode(await taskFile.readAsString()) as List;
            await saveTaskJson([for (final e in list) jsonEncode(e)]);
          } catch (_) {}
        }
      }
      // 种子任务
      final jobFile = File(p.join(App.dataPath, 'torrent_jobs.json'));
      if (await jobFile.exists()) {
        final empty = await (select(torrentJobTable)..limit(1)).get();
        if (empty.isEmpty) {
          try {
            final list = jsonDecode(await jobFile.readAsString()) as List;
            await saveJobJson([for (final e in list) jsonEncode(e)]);
          } catch (_) {}
        }
      }
      // BT 线路/绑定
      final bindFile = File(p.join(App.dataPath, 'torrent_bindings.json'));
      if (await bindFile.exists()) {
        final empty = await (select(btLineTable)..limit(1)).get();
        if (empty.isEmpty) {
          try {
            final m = jsonDecode(await bindFile.readAsString());
            if (m is Map) {
              if (m['lines'] is Map) {
                await replaceLines(
                  Map<String, dynamic>.from(m['lines'] as Map),
                );
              }
              if (m['active'] is Map) {
                await replaceActive(
                  Map<String, dynamic>.from(m['active'] as Map),
                );
              }
              if (m['bindings'] is Map) {
                await replaceBindings(
                  Map<String, dynamic>.from(m['bindings'] as Map),
                );
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
