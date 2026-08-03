import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kostori/database/daos/ai_api_key_dao.dart';
import 'package:kostori/database/daos/ai_aux_settings_dao.dart';
import 'package:kostori/database/daos/ai_config_dao.dart';
import 'package:kostori/database/daos/ai_custom_provider_dao.dart';
import 'package:kostori/database/daos/ai_mcp_server_dao.dart';
import 'package:kostori/database/daos/ai_model_dao.dart';
import 'package:kostori/database/daos/ai_provider_stats_dao.dart';
import 'package:kostori/database/daos/ai_session_dao.dart';
import 'package:kostori/database/daos/ai_skill_dao.dart';
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

  /// 余额查询 URL（可自定义；为空表示使用内置默认查询）
  TextColumn get balanceUrl => text().nullable()();

  /// 余额结果 JSON key path（点号分隔，如 `data.balance`）
  TextColumn get balanceKey => text().nullable()();

  /// 接口格式：openai | openai_responses | gemini | claude；null 视为 openai
  TextColumn get apiFormat => text().nullable()();

  /// 自定义的"查询可用模型"接口地址；为空使用内置默认
  TextColumn get modelsUrl => text().nullable()();

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

  /// 关联的助手档案 id（AssistantProfile）
  TextColumn get profileId => text().nullable()();

  /// 使用的服务商
  TextColumn get provider => text()();

  /// 已压缩的旧上下文摘要
  TextColumn get compressedContent => text().nullable()();

  /// 会话启用的技能 keys（JSON 数组字符串）
  TextColumn get skillKeys => text().nullable()();

  /// 已生成的后续追问建议（JSON 数组字符串）
  TextColumn get followUps => text().nullable()();

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

  /// 用户消息附带的图片（data URL 的 JSON 数组），用于聊天界面展示
  TextColumn get inputImages => text().nullable()();

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

  /// 模型类型：chat / embedding / image / audio / rerank 等
  TextColumn get modelType => text().withDefault(const Constant('chat'))();

  /// 输入模态（逗号分隔）：text,image,audio,video
  TextColumn get inputModality => text().withDefault(const Constant('text'))();

  /// 输出模态（逗号分隔）：text,image,audio
  TextColumn get outputModality => text().withDefault(const Constant('text'))();

  /// 是否支持多模态（图片理解）
  BoolColumn get supportsVision =>
      boolean().withDefault(const Constant(true))();

  /// 是否支持工具调用（function calling）
  BoolColumn get supportsTools => boolean().withDefault(const Constant(true))();

  /// 是否支持推理（reasoning / thinking）
  BoolColumn get supportsReasoning =>
      boolean().withDefault(const Constant(false))();

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

/// 自定义服务商（OpenAI 兼容）
class AiCustomProviders extends Table {
  @override
  Set<Column> get primaryKey => {provider};

  /// 唯一 key，如 custom_xxx
  TextColumn get provider => text()();

  /// 展示名称
  TextColumn get name => text()();

  TextColumn get baseUrl => text()();

  TextColumn get defaultModel => text().nullable()();

  TextColumn get apiKey => text().nullable()();

  /// 接口格式：openai | openai_responses | gemini | claude；null 视为 openai
  TextColumn get apiFormat => text().nullable()();

  /// 自定义的"查询可用模型"接口地址；为空使用内置默认
  TextColumn get modelsUrl => text().nullable()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  /// 余额查询 URL（可自定义；为空表示使用内置默认查询）
  TextColumn get balanceUrl => text().nullable()();

  /// 余额结果 JSON key path（点号分隔，如 `data.balance`）
  TextColumn get balanceKey => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 技能（预设 System Prompt 包）
class AiSkills extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get key => text().unique()();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  TextColumn get systemPrompt => text()();

  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 应用级辅助任务模型设置（key-value：压缩 / 后续建议 / 自动标题）
class AiAuxSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// MCP 服务器配置
class AiMcpServers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  /// 'stdio' | 'http' | 'sse'
  TextColumn get transport => text().withDefault(const Constant('http'))();

  /// stdio: 可执行文件
  TextColumn get command => text().nullable()();

  /// stdio: JSON 数组参数
  TextColumn get args => text().nullable()();

  /// stdio: 环境变量 JSON
  TextColumn get env => text().nullable()();

  /// http/sse: 端点地址
  TextColumn get url => text().nullable()();

  /// http/sse: JSON 对象 headers
  TextColumn get headers => text().nullable()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
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
    AiCustomProviders,
    AiSkills,
    AiMcpServers,
    AiAuxSettings,
  ],
  daos: [
    AiApiKeyDao,
    AiSessionDao,
    AiTaskDao,
    AiConfigDao,
    AiModelDao,
    AiProviderStatsDao,
    AiCustomProviderDao,
    AiSkillDao,
    AiMcpServerDao,
    AiAuxSettingsDao,
  ],
)
class AiDatabase extends _$AiDatabase {
  static AiDatabase? _instance;

  static AiDatabase get instance => _instance ??= AiDatabase._();

  AiDatabase._() : super(_openConnection());

  @override
  int get schemaVersion => 11;

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
      if (from < 5) {
        await _ensureTableExists(m, aiCustomProviders);
        try {
          await m.addColumn(aiCustomProviders, aiCustomProviders.defaultModel);
        } catch (e) {
          //
        }
        await _ensureTableExists(m, aiSkills);
        await _ensureTableExists(m, aiMcpServers);
        await m.addColumn(aiSessions, aiSessions.compressedContent);
        await m.addColumn(aiSessions, aiSessions.skillKeys);
      }
      if (from < 6) {
        // 余额查询：内置/自定义服务商均可配置查询地址与结果字段
        await _addColumnIfMissing(m, aiApiKeys, aiApiKeys.balanceUrl);
        await _addColumnIfMissing(m, aiApiKeys, aiApiKeys.balanceKey);
        await _addColumnIfMissing(
          m,
          aiCustomProviders,
          aiCustomProviders.balanceUrl,
        );
        await _addColumnIfMissing(
          m,
          aiCustomProviders,
          aiCustomProviders.balanceKey,
        );
        // 模型级能力标记（视觉 / 工具）
        await _addColumnIfMissing(m, aiModels, aiModels.supportsVision);
        await _addColumnIfMissing(m, aiModels, aiModels.supportsTools);
        // 将自定义服务商的 provider 级能力标记平铺到其默认模型
        try {
          await m.database.customStatement('''
            INSERT OR REPLACE INTO ai_models
              (model_id, provider, label, is_active, supports_vision, supports_tools)
            SELECT default_model, provider, default_model, 1,
                   supports_vision, supports_tools
            FROM ai_custom_providers
            WHERE default_model IS NOT NULL
          ''');
        } catch (e) {
          // 老库可能缺少 supports_* 列，忽略即可
        }
      }
      if (from < 7) {
        // 会话后续追问建议 + 应用级辅助任务模型设置
        await _addColumnIfMissing(m, aiSessions, aiSessions.followUps);
        await _ensureTableExists(m, aiAuxSettings);
      }
      if (from < 8) {
        // 助手档案：会话关联的档案 id
        await _addColumnIfMissing(m, aiSessions, aiSessions.profileId);
      }
      if (from < 9) {
        // 自定义服务商接口格式 + 自定义模型列表接口 + 模型类型/模态/能力
        await _addColumnIfMissing(m, aiApiKeys, aiApiKeys.modelsUrl);
        await _addColumnIfMissing(m, aiApiKeys, aiApiKeys.apiFormat);
        await _addColumnIfMissing(
          m,
          aiCustomProviders,
          aiCustomProviders.apiFormat,
        );
        await _addColumnIfMissing(
          m,
          aiCustomProviders,
          aiCustomProviders.modelsUrl,
        );
        await _addColumnIfMissing(m, aiModels, aiModels.modelType);
        await _addColumnIfMissing(m, aiModels, aiModels.inputModality);
        await _addColumnIfMissing(m, aiModels, aiModels.outputModality);
        await _addColumnIfMissing(m, aiModels, aiModels.supportsReasoning);
      }
      // v10：幂等修复 v9 列（部分库因历史原因缺列，确保列存在）
      if (from < 10) {
        await _addColumnIfMissing(m, aiApiKeys, aiApiKeys.modelsUrl);
        await _addColumnIfMissing(m, aiApiKeys, aiApiKeys.apiFormat);
        await _addColumnIfMissing(
          m,
          aiCustomProviders,
          aiCustomProviders.apiFormat,
        );
        await _addColumnIfMissing(
          m,
          aiCustomProviders,
          aiCustomProviders.modelsUrl,
        );
        await _addColumnIfMissing(m, aiModels, aiModels.modelType);
        await _addColumnIfMissing(m, aiModels, aiModels.inputModality);
        await _addColumnIfMissing(m, aiModels, aiModels.outputModality);
        await _addColumnIfMissing(m, aiModels, aiModels.supportsReasoning);
      }
      if (from < 11) {
        // 用户消息附带图片（聊天界面展示）
        await _addColumnIfMissing(m, aiTasks, aiTasks.inputImages);
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
        ], mode: InsertMode.insertOrReplace);
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

  /// 列不存在时才添加，避免重复执行迁移报错
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final rows = await m.database
        .customSelect('PRAGMA table_info(${table.actualTableName})')
        .get();
    final exists = rows.any((row) => row.data['name'] == column.name);
    if (!exists) {
      await m.addColumn(table, column);
    }
  }

  static void init() => _instance = AiDatabase._();
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final file = File(p.join(App.dataPath, 'ai_database.db'));
  return NativeDatabase.createInBackground(file);
});
