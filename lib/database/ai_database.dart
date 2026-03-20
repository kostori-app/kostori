// 运行代码生成:
//   flutter pub run build_runner build --delete-conflicting-outputs

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kostori/database/daos/ai_api_key_dao.dart';
import 'package:kostori/database/daos/ai_config_dao.dart';
import 'package:kostori/database/daos/ai_provider_stats_dao.dart';
import 'package:kostori/database/daos/ai_task_dao.dart';
import 'package:kostori/foundation/app.dart';
import 'package:path/path.dart' as p;

part 'ai_database.g.dart';

// ═══════════════════════════════════════════════════════════
// 表定义
// ═══════════════════════════════════════════════════════════

/// API Key 存储表（加密存储真实密钥）
class AiApiKeys extends Table {
  /// 服务商唯一标识: 'siliconFlow' | 'doubao' | 'gemini'
  @override
  Set<Column> get primaryKey => {provider};

  TextColumn get provider => text()();

  TextColumn get apiKey => text()();

  /// 自定义 baseUrl（可为空，使用默认值）
  TextColumn get baseUrl => text().nullable()();

  /// 当前使用的模型名称
  TextColumn get model => text().nullable()();

  /// Key 是否启用
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  /// 最后更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// AI 任务记录表：翻译历史、侧写报告等
class AiTasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 任务类型: 'translation' | 'soul_profile' | 'anime_recommend'
  TextColumn get taskType => text().withLength(min: 1, max: 50)();

  /// 使用的服务商，外键关联 AiApiKeys.provider
  TextColumn get provider => text()();

  /// 输入内容：原文或番剧列表 ID
  TextColumn get inputContent => text()();

  /// AI 返回的结果（Markdown）
  TextColumn get outputContent => text()();

  /// 使用的模型名称
  TextColumn get modelName => text().nullable()();

  /// 消耗 Token 数量
  IntColumn get tokenConsumed => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// AI 配置与人格表：存放 System Prompt
class AiConfigs extends Table {
  @override
  Set<Column> get primaryKey => {configKey};

  /// 唯一键: 'translator_v1' | 'profile_expert'
  TextColumn get configKey => text()();

  /// System Prompt
  TextColumn get systemPrompt => text()();

  /// 创造力参数: 0.0 ~ 1.0
  RealColumn get temperature => real().withDefault(const Constant(0.7))();

  /// 备注
  TextColumn get memo => text().nullable()();
}

/// AI 服务状态表：记录 Key 的有效性与调用统计
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
  tables: [AiApiKeys, AiTasks, AiConfigs, AiProviderStats],
  daos: [AiApiKeyDao, AiTaskDao, AiConfigDao, AiProviderStatsDao],
)
class AiDatabase extends _$AiDatabase {
  static AiDatabase? _instance;

  static AiDatabase get instance => _instance ??= AiDatabase._();

  AiDatabase._() : super(_openConnection());

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
    _instance = AiDatabase._();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = File(p.join(App.dataPath, 'ai_database.db'));
    return NativeDatabase.createInBackground(file);
  });
}
