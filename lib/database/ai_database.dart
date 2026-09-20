import 'package:drift/drift.dart';
import 'package:kostori/database/daos/ai_api_key_dao.dart';
import 'package:kostori/database/daos/ai_aux_settings_dao.dart';
import 'package:kostori/database/daos/ai_custom_provider_dao.dart';
import 'package:kostori/database/daos/ai_mcp_server_dao.dart';
import 'package:kostori/database/daos/ai_model_dao.dart';
import 'package:kostori/database/daos/ai_provider_stats_dao.dart';
import 'package:kostori/database/daos/ai_session_dao.dart';
import 'package:kostori/database/daos/ai_skill_dao.dart';
import 'package:kostori/database/db_common.dart';

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

  /// 已压缩的旧上下文摘要（滚动摘要）
  TextColumn get compressedContent => text().nullable()();

  /// 已总结到的最后一条消息 id（滚动摘要用，null 表示尚未总结）
  IntColumn get summaryMessageId => integer().nullable()();

  /// 会话启用的技能 keys（JSON 数组字符串）
  TextColumn get skillKeys => text().nullable()();

  /// 已生成的后续追问建议（JSON 数组字符串）
  TextColumn get followUps => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// AI 消息记录表：每一轮对话的单条消息
@TableIndex(name: 'tasks_session_idx', columns: {#sessionId})
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
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 3) {
        // 原有逻辑不变
        await _ensureTableExists(m, aiModels);
        await _ensureTableExists(m, aiSessions);
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
      if (from < 14) {
        await _addColumnIfMissing(m, aiSessions, aiSessions.summaryMessageId);
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
      // 注：ai_tasks 已迁移到独立库 ai_tasks.db（见 AiTaskDatabase）
      if (from < 13) {
        // 移除遗留的 ai_configs 表（已被助手档案 / 提示词注入取代）
        try {
          await m.deleteTable('ai_configs');
        } catch (_) {}
      }
    },
  );

  @override
  Future<void> close() async {
    await super.close();
    _instance = null;
  }

  /// 导出可跨端合并的用户数据。
  ///
  /// 缓存类表（模型目录 `ai_models`、服务商校验统计 `ai_provider_stats`）
  /// 不导出：它们由各端自己查询/覆盖，混在一起反而会互相污染。
  Future<Map<String, dynamic>> exportMergeData() async => {
    'apiKeys': [for (final r in await select(aiApiKeys).get()) r.toJson()],
    'customProviders': [
      for (final r in await select(aiCustomProviders).get()) r.toJson(),
    ],
    'sessions': [for (final r in await select(aiSessions).get()) r.toJson()],
    'auxSettings': [
      for (final r in await select(aiAuxSettings).get()) r.toJson(),
    ],
    'mcpServers': [for (final r in await select(aiMcpServers).get()) r.toJson()],
  };

  /// 合并同步来的用户数据：同键取 `updatedAt` 较新的一方；
  /// 无时间戳的表（`ai_aux_settings`）本机优先，只补齐本机没有的键。
  /// MCP 服务器按 `name` 合并（自增 id 跨端没有意义，保留本机 id）。
  Future<void> mergeData(Map<String, dynamic> data) async {
    List<Map<String, dynamic>> rowsOf(String key) =>
        (data[key] as List?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        const [];

    await transaction(() async {
      // 服务商 API Key：provider 为主键
      final localApiKeys = {
        for (final r in await select(aiApiKeys).get()) r.provider: r,
      };
      for (final m in rowsOf('apiKeys')) {
        final r = AiApiKey.fromJson(m);
        final local = localApiKeys[r.provider];
        if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
          await into(aiApiKeys).insertOnConflictUpdate(r.toCompanion(true));
        }
      }

      // 自定义服务商：provider 为主键
      final localCustom = {
        for (final r in await select(aiCustomProviders).get()) r.provider: r,
      };
      for (final m in rowsOf('customProviders')) {
        final r = AiCustomProvider.fromJson(m);
        final local = localCustom[r.provider];
        if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
          await into(
            aiCustomProviders,
          ).insertOnConflictUpdate(r.toCompanion(true));
        }
      }

      // 会话元数据：sessionId 为主键
      final localSessions = {
        for (final r in await select(aiSessions).get()) r.sessionId: r,
      };
      for (final m in rowsOf('sessions')) {
        final r = AiSession.fromJson(m);
        final local = localSessions[r.sessionId];
        if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
          await into(aiSessions).insertOnConflictUpdate(r.toCompanion(true));
        }
      }

      // MCP 服务器：按 name 合并
      final localMcp = {
        for (final r in await select(aiMcpServers).get()) r.name: r,
      };
      for (final m in rowsOf('mcpServers')) {
        final r = AiMcpServer.fromJson(m);
        final local = localMcp[r.name];
        if (local == null) {
          await into(
            aiMcpServers,
          ).insert(r.toCompanion(true).copyWith(id: const Value.absent()));
        } else if (r.updatedAt.isAfter(local.updatedAt)) {
          await into(aiMcpServers).insertOnConflictUpdate(
            r.toCompanion(true).copyWith(id: Value(local.id)),
          );
        }
      }

      // 辅助任务模型设置：只补本机缺失
      final localAuxKeys = {
        for (final r in await select(aiAuxSettings).get()) r.key,
      };
      for (final m in rowsOf('auxSettings')) {
        final r = AiAuxSetting.fromJson(m);
        if (localAuxKeys.contains(r.key)) continue;
        await into(aiAuxSettings).insertOnConflictUpdate(r.toCompanion(true));
      }
    });
  }

  /// 把 WAL 里的改动写回主库文件（导出整库前调用）
  Future<void> checkpoint() =>
      walCheckpoint(() => customStatement('PRAGMA wal_checkpoint(TRUNCATE);'));

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

LazyDatabase _openConnection() => openWalDb('ai_database.db');
