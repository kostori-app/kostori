import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kostori/database/daos/ai_api_key_dao.dart';
import 'package:kostori/database/daos/ai_config_dao.dart';
import 'package:kostori/database/daos/ai_model_dao.dart';
import 'package:kostori/database/daos/ai_provider_stats_dao.dart';
import 'package:kostori/database/daos/ai_session_dao.dart';
import 'package:kostori/database/daos/ai_task_dao.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:path/path.dart' as p;

part 'ai_database.g.dart';

// ═══════════════════════════════════════════════════════════
// 表定义
// ═══════════════════════════════════════════════════════════

class AiApiKeys extends Table {
  @override
  Set<Column> get primaryKey => {provider};

  TextColumn get provider => text()();

  TextColumn get apiKey => text()();

  TextColumn get baseUrl => text().nullable()();

  TextColumn get model => text().nullable()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 会话表：一次完整对话（含多轮消息）
class AiSessions extends Table {
  @override
  Set<Column> get primaryKey => {sessionId};

  /// UUID 或随机字符串
  TextColumn get sessionId => text()();

  /// 会话类型: 'chat' | 'soul_profile' | 'translation'
  TextColumn get type => text().withLength(min: 1, max: 20)();

  /// 会话标题
  TextColumn get title => text().withDefault(const Constant('新对话'))();

  /// 关联的 System Prompt 配置 key
  TextColumn get configKey => text().nullable()();

  /// 使用的服务商
  TextColumn get provider => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// AI 消息记录表：每一轮对话的单条消息
@TableIndex(name: 'tasks_session_idx', columns: {#sessionId})
class AiTasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sessionId => text()();

  TextColumn get taskType => text().withLength(min: 1, max: 50)();

  TextColumn get role => text().withDefault(const Constant('user'))();

  TextColumn get inputContent => text()();

  TextColumn get outputContent => text().nullable()();

  TextColumn get thought => text().nullable()();

  TextColumn get provider => text()();

  TextColumn get modelName => text().nullable()();

  IntColumn get tokenConsumed => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AiConfigs extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get configKey => text().unique()();

  TextColumn get systemPrompt => text()();

  RealColumn get temperature => real().withDefault(const Constant(0.7))();

  TextColumn get memo => text().nullable()();

  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
}

class AiModels extends Table {
  TextColumn get modelId => text()();

  TextColumn get provider => text()();

  TextColumn get label => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {provider, modelId};
}

class AiProviderStats extends Table {
  @override
  Set<Column> get primaryKey => {provider};

  TextColumn get provider => text()();

  BoolColumn get isValid => boolean().withDefault(const Constant(true))();

  DateTimeColumn get lastCheckAt => dateTime().nullable()();

  IntColumn get totalCalls => integer().withDefault(const Constant(0))();
}

// ═══════════════════════════════════════════════════════════
// 数据库
// ═══════════════════════════════════════════════════════════

@DriftDatabase(
  tables: [
    AiApiKeys,
    AiSessions,
    AiTasks,
    AiConfigs,
    AiModels,
    AiProviderStats,
  ],
  daos: [
    AiApiKeyDao,
    AiSessionDao,
    AiTaskDao,
    AiConfigDao,
    AiModelDao,
    AiProviderStatsDao,
  ],
)
class AiDatabase extends _$AiDatabase {
  static AiDatabase? _instance;

  static AiDatabase get instance => _instance ??= AiDatabase._();

  AiDatabase._() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 3) {
        // 原有逻辑不变
        await m.deleteTable(aiConfigs.actualTableName);
        await m.createTable(aiConfigs);
        await _ensureTableExists(m, aiModels);
        await _ensureTableExists(m, aiSessions);
        await _ensureTableExists(m, aiTasks);
        try {
          await m.addColumn(aiTasks, aiTasks.sessionId);
          await m.addColumn(aiTasks, aiTasks.role);
          await m.addColumn(aiTasks, aiTasks.thought);
        } catch (e) {
          //
        }
      }
      if (from < 4) {
        await m.addColumn(aiConfigs, aiConfigs.isSystem);
      }
    },
    beforeOpen: (details) async {
      await batch((batch) {
        batch.insertAll(aiConfigs, [
          AiConfigsCompanion.insert(
            id: const Value(1),
            configKey: 'ai_translator_v1',
            systemPrompt: aiTranslatePrompt,
            temperature: const Value(0.3),
            memo: const Value('专业母语译者'),
            isSystem: const Value(true),
          ),
          AiConfigsCompanion.insert(
            id: const Value(2),
            configKey: 'soul_profiler_v1',
            systemPrompt: soulProfilerSystemPrompt,
            temperature: const Value(0.85),
            memo: const Value('动漫灵魂侧写师'),
            isSystem: const Value(true),
          ),
          AiConfigsCompanion.insert(
            id: const Value(3),
            configKey: 'image_tag_v1',
            systemPrompt: imageTagSystemPrompt,
            temperature: const Value(0.8),
            memo: const Value('AI 绘画 Tag 生成'),
            isSystem: const Value(true),
          ),
          AiConfigsCompanion.insert(
            id: const Value(4),
            configKey: 'summary_v1',
            systemPrompt: summarySystemPrompt,
            temperature: const Value(0.7),
            memo: const Value('周月总结'),
            isSystem: const Value(true),
          ),
        ], mode: InsertMode.insertOrIgnore);
      });
    },
  );

  @override
  Future<void> close() async {
    await super.close();
    _instance = null;
  }

  Future<void> _ensureTableExists(Migrator m, TableInfo table) async {
    try {
      await customStatement('SELECT 1 FROM ${table.actualTableName} LIMIT 1');
    } catch (e) {
      await m.createTable(table);
    }
  }

  static void init() => _instance = AiDatabase._();
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final file = File(p.join(App.dataPath, 'ai_database.db'));
  return NativeDatabase.createInBackground(file);
});
