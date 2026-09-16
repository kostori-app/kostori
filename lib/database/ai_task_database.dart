// AI 消息（会话消息）单独一个库：ai_tasks.db
// 体积最大，独立成库便于选择性同步（可跳过消息库，只同步设置/故事等）。

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/daos/ai_task_dao.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';
import 'package:path/path.dart' as p;

part 'ai_task_database.g.dart';

class AiTasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sessionId => text()();

  TextColumn get taskType => text().withLength(min: 1, max: 50)();

  TextColumn get role => text().withDefault(const Constant('user'))();

  TextColumn get inputContent => text()();

  /// 用户消息附带的图片（data URL 的 JSON 数组），用于聊天界面展示
  TextColumn get inputImages => text().nullable()();

  TextColumn get outputContent => text().nullable()();

  /// 多候选回复（JSON 字符串数组），outputContent 为当前选中项
  TextColumn get outputVariants => text().nullable()();

  /// 当前选中的候选下标
  IntColumn get variantIndex => integer().withDefault(const Constant(0))();

  TextColumn get thought => text().nullable()();

  TextColumn get provider => text()();

  TextColumn get modelName => text().nullable()();

  IntColumn get tokenConsumed => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [AiTasks], daos: [AiTaskDao])
class AiTaskDatabase extends _$AiTaskDatabase {
  static AiTaskDatabase? _instance;

  /// 库被重新打开（如导入 ai_tasks 分片后）时自增，
  /// 供页面重建消息流，避免仍订阅旧实例导致列表空白
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static AiTaskDatabase get instance => _instance ??= AiTaskDatabase._();

  AiTaskDatabase._() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  @override
  Future<void> close() async {
    await super.close();
    _instance = null;
  }

  static void init() {
    _instance = AiTaskDatabase._();
    revision.value++;
  }
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final file = File(p.join(App.dataPath, 'ai_tasks.db'));
  return NativeDatabase.createInBackground(
    file,
    setup: (db) {
      db.execute('PRAGMA journal_mode = WAL;');
      db.execute('PRAGMA synchronous = NORMAL;');
    },
  );
});

/// 把旧 ai_database.db 里的 ai_tasks 迁到独立库（一次性），并删除旧表。
///
/// 旧表由 drift 建表，列名是 snake_case（session_id / input_content ...），
/// 必须按 snake_case 取值；用驼峰键会全部落成默认值（数据看起来就"没了"）。
Future<void> migrateAiTasksToOwnDb() async {
  final src = AiDatabase.instance;
  final dst = AiTaskDatabase.instance;
  List<QueryRow> rows;
  try {
    rows = await src.customSelect('SELECT * FROM ai_tasks').get();
  } catch (_) {
    return; // 旧库没有 ai_tasks 表（已迁移或从未使用）
  }

  final dstCount =
      ((await dst
                  .customSelect('SELECT COUNT(*) AS c FROM ai_tasks')
                  .getSingle())
              .data['c']
          as num?)
          ?.toInt() ??
      0;

  if (rows.isNotEmpty && dstCount == 0) {
    await dst.batch((b) {
      for (final r in rows) {
        b.insert(dst.aiTasks, _legacyTask(r.data));
      }
    });
  }

  // 仅在数据确实已迁移后才删旧表，避免拷贝异常把旧数据删掉
  if (dstCount == 0 || dstCount >= rows.length) {
    try {
      await src.customStatement('DROP TABLE IF EXISTS ai_tasks');
    } catch (_) {}
    await compactAiDatabaseIfNeeded();
  } else {
    DebugLog.error(
      'migrateAiTasks',
      '目标库行数($dstCount)少于旧表(${rows.length})，保留旧表不删除',
    );
  }
}

/// 旧库一行 → 新库 companion（注意旧表列名是 snake_case）
AiTasksCompanion _legacyTask(Map<String, dynamic> d) {
  int? asInt(Object? v) => (v as num?)?.toInt();
  final createdAt = asInt(d['created_at']);
  return AiTasksCompanion.insert(
    sessionId: d['session_id']?.toString() ?? '',
    taskType: d['task_type']?.toString() ?? 'chat',
    role: Value(d['role']?.toString() ?? 'user'),
    inputContent: d['input_content']?.toString() ?? '',
    inputImages: Value(d['input_images']?.toString()),
    outputContent: Value(d['output_content']?.toString()),
    outputVariants: Value(d['output_variants']?.toString()),
    variantIndex: Value(asInt(d['variant_index']) ?? 0),
    thought: Value(d['thought']?.toString()),
    provider: d['provider']?.toString() ?? '',
    modelName: Value(d['model_name']?.toString()),
    tokenConsumed: Value(asInt(d['token_consumed']) ?? 0),
    // drift 的 dateTime() 以「秒」存储
    createdAt: createdAt == null
        ? const Value.absent()
        : Value(DateTime.fromMillisecondsSinceEpoch(createdAt * 1000)),
  );
}

/// 回收 ai_database.db 的空闲页：SQLite 删除表/行后不会自动缩小文件，
/// 需要 VACUUM 才会真正释放磁盘空间（消息库迁出后尤其明显）。
Future<void> compactAiDatabaseIfNeeded() async {
  try {
    final db = AiDatabase.instance;
    final row = await db.customSelect('PRAGMA freelist_count').getSingle();
    final values = row.data.values;
    final free = values.isEmpty ? 0 : (values.first as num?)?.toInt() ?? 0;
    if (free >= 64) {
      DebugLog.info(
        'compactAiDatabase',
        'VACUUM ai_database.db (free pages: $free)',
      );
      await db.customStatement('VACUUM');
    }
    // WAL 模式下 VACUUM 的结果留在 WAL 里，必须 checkpoint 才会把主文件
    // 截断到实际大小（否则删表后文件依然很大）
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  } catch (e, s) {
    DebugLog.error('compactAiDatabase', e, s);
  }
}
