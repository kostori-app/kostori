// lib/foundation/ai_service/assistant_profile.dart
//
// 助手档案（AssistantProfile）：可复用的角色设定包。
// 包含人设、语气、自定义系统提示、知识、技能、生成参数与行为偏好，
// 通过 [buildAssistantSystemPrompt] 按固定顺序组装出完整 System Prompt。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/role_management.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 生成参数（可空表示跟随服务商默认值）
class AssistantParams {
  final double? temperature;
  final double? topP;
  final int? maxTokens;

  const AssistantParams({this.temperature, this.topP, this.maxTokens});

  AssistantParams copyWith({
    double? temperature,
    double? topP,
    int? maxTokens,
  }) => AssistantParams(
    temperature: temperature ?? this.temperature,
    topP: topP ?? this.topP,
    maxTokens: maxTokens ?? this.maxTokens,
  );

  factory AssistantParams.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AssistantParams();
    return AssistantParams(
      temperature: (json['temperature'] as num?)?.toDouble(),
      topP: (json['topP'] as num?)?.toDouble(),
      maxTokens: (json['maxTokens'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (temperature != null) 'temperature': temperature,
    if (topP != null) 'topP': topP,
    if (maxTokens != null) 'maxTokens': maxTokens,
  };
}

/// 回复长度偏好
enum ReplyLength { short, normal, detailed }

/// 回复风格偏好（人格绑定功能之一）
class ReplyStylePrefs {
  final ReplyLength length;
  final bool useEmoji;
  final bool useMarkdown;
  final bool askBack;

  const ReplyStylePrefs({
    this.length = ReplyLength.normal,
    this.useEmoji = false,
    this.useMarkdown = true,
    this.askBack = false,
  });

  ReplyStylePrefs copyWith({
    ReplyLength? length,
    bool? useEmoji,
    bool? useMarkdown,
    bool? askBack,
  }) => ReplyStylePrefs(
    length: length ?? this.length,
    useEmoji: useEmoji ?? this.useEmoji,
    useMarkdown: useMarkdown ?? this.useMarkdown,
    askBack: askBack ?? this.askBack,
  );

  factory ReplyStylePrefs.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReplyStylePrefs();
    return ReplyStylePrefs(
      length:
          ReplyLength.values.asNameMap()[json['length']] ?? ReplyLength.normal,
      useEmoji: (json['useEmoji'] as bool?) ?? false,
      useMarkdown: (json['useMarkdown'] as bool?) ?? true,
      askBack: (json['askBack'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'length': length.name,
    'useEmoji': useEmoji,
    'useMarkdown': useMarkdown,
    'askBack': askBack,
  };
}

/// 对话示例（few-shot）：辅助模型模仿口吻
class ProfileExample {
  final String user;
  final String assistant;

  const ProfileExample({required this.user, required this.assistant});

  factory ProfileExample.fromJson(Map<String, dynamic> json) => ProfileExample(
    user: (json['user'] as String?) ?? '',
    assistant: (json['assistant'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {'user': user, 'assistant': assistant};
}

/// ③ 扩展管理设定：应用级可选模块开关与配置
class AssistantExtension {
  final String extensionId;
  final bool enabled;
  final Map<String, dynamic>? config;

  const AssistantExtension({
    required this.extensionId,
    this.enabled = true,
    this.config,
  });

  AssistantExtension copyWith({bool? enabled, Map<String, dynamic>? config}) =>
      AssistantExtension(
        extensionId: extensionId,
        enabled: enabled ?? this.enabled,
        config: config ?? this.config,
      );

  factory AssistantExtension.fromJson(Map<String, dynamic> json) =>
      AssistantExtension(
        extensionId: (json['extensionId'] as String?) ?? '',
        enabled: (json['enabled'] as bool?) ?? true,
        config: json['config'] is Map
            ? (json['config'] as Map).cast<String, dynamic>()
            : null,
      );

  Map<String, dynamic> toJson() => {
    'extensionId': extensionId,
    'enabled': enabled,
    if (config != null) 'config': config,
  };
}

/// ④ 记忆设定：是否启用长期记忆与条目上限
class MemorySettings {
  final bool enabled;
  final int maxEntries;

  const MemorySettings({this.enabled = false, this.maxEntries = 50});

  MemorySettings copyWith({bool? enabled, int? maxEntries}) => MemorySettings(
    enabled: enabled ?? this.enabled,
    maxEntries: maxEntries ?? this.maxEntries,
  );

  factory MemorySettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MemorySettings();
    return MemorySettings(
      enabled: (json['enabled'] as bool?) ?? false,
      maxEntries: (json['maxEntries'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'maxEntries': maxEntries,
  };
}

/// ⑤ 自定义请求设定：参数 + 接口覆盖（敏感信息不落明文）
class RequestSettings {
  final String? baseUrlOverride;
  final String? apiKeyOverride;
  final Map<String, String> customHeaders;
  final Map<String, dynamic> extraBodyFields;
  final List<String> stopSequences;

  const RequestSettings({
    this.baseUrlOverride,
    this.apiKeyOverride,
    this.customHeaders = const {},
    this.extraBodyFields = const {},
    this.stopSequences = const [],
  });

  RequestSettings copyWith({
    String? baseUrlOverride,
    String? apiKeyOverride,
    Map<String, String>? customHeaders,
    Map<String, dynamic>? extraBodyFields,
    List<String>? stopSequences,
  }) => RequestSettings(
    baseUrlOverride: baseUrlOverride ?? this.baseUrlOverride,
    apiKeyOverride: apiKeyOverride ?? this.apiKeyOverride,
    customHeaders: customHeaders ?? this.customHeaders,
    extraBodyFields: extraBodyFields ?? this.extraBodyFields,
    stopSequences: stopSequences ?? this.stopSequences,
  );

  factory RequestSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RequestSettings();
    return RequestSettings(
      baseUrlOverride:
          (json['baseUrlOverride'] as String?)?.trim().isNotEmpty == true
          ? (json['baseUrlOverride'] as String).trim()
          : null,
      apiKeyOverride:
          (json['apiKeyOverride'] as String?)?.trim().isNotEmpty == true
          ? (json['apiKeyOverride'] as String).trim()
          : null,
      customHeaders: json['customHeaders'] is Map
          ? (json['customHeaders'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : const {},
      extraBodyFields: json['extraBodyFields'] is Map
          ? (json['extraBodyFields'] as Map).cast<String, dynamic>()
          : const {},
      stopSequences: json['stopSequences'] is List
          ? (json['stopSequences'] as List).whereType<String>().toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (baseUrlOverride != null) 'baseUrlOverride': baseUrlOverride,
    if (apiKeyOverride != null) 'apiKeyOverride': apiKeyOverride,
    if (customHeaders.isNotEmpty) 'customHeaders': customHeaders,
    if (extraBodyFields.isNotEmpty) 'extraBodyFields': extraBodyFields,
    if (stopSequences.isNotEmpty) 'stopSequences': stopSequences,
  };
}

/// ⑥ MCP 设定：本助手绑定的 MCP 服务器列表
class McpBinding {
  final String id;
  final String name;
  final String serverUrl;
  final bool enabled;

  const McpBinding({
    required this.id,
    required this.name,
    this.serverUrl = '',
    this.enabled = true,
  });

  McpBinding copyWith({bool? enabled, String? serverUrl, String? name}) =>
      McpBinding(
        id: id,
        name: name ?? this.name,
        serverUrl: serverUrl ?? this.serverUrl,
        enabled: enabled ?? this.enabled,
      );

  factory McpBinding.fromJson(Map<String, dynamic> json) => McpBinding(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    serverUrl: (json['serverUrl'] as String?) ?? '',
    enabled: (json['enabled'] as bool?) ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'serverUrl': serverUrl,
    'enabled': enabled,
  };
}

/// 助手档案
class AssistantProfile {
  final String id;

  final String name;

  /// 展示用的 emoji 图标
  final String icon;

  /// 人设描述（角色是谁）
  final String persona;

  /// 语气 / 风格
  final String tone;

  /// 性格标签（多选，如 理性/幽默/毒舌/温柔）
  final List<String> personalityTags;

  /// 口头禅 / 常用语
  final List<String> catchphrases;

  /// 对话示例（few-shot）
  final List<ProfileExample> examples;

  /// 回复风格偏好
  final ReplyStylePrefs replyStyle;

  /// 自定义系统提示
  final String systemPrompt;

  /// 知识（多段）
  final List<String> knowledge;

  /// ⑦ 本地工具（内置工具链）开关集合；为空表示使用全部默认启用
  final Set<String> enabledSkillIds;

  /// 技能绑定：扩展管理（改造点 7）中导入/启用的技能 key 列表
  final List<String> skillIds;

  /// ③ 扩展管理设定：应用级可选模块
  final List<AssistantExtension> extensions;

  /// ④ 记忆设定
  final MemorySettings memory;

  /// ⑤ 自定义请求设定
  final RequestSettings request;

  /// ⑥ MCP 绑定列表
  final List<McpBinding> mcpServers;

  final AssistantParams params;

  /// 行为偏好（键值对，如 {concise: true, useMarkdown: true}）
  final Map<String, dynamic> behaviorPrefs;

  /// 有序提示片段（按顺序插入 System Prompt）
  final List<String> promptFragments;

  final bool isBuiltin;

  /// 系统预设档案（如"通用助手"）：不可删除，仅可编辑/复制
  final bool isPreset;

  const AssistantProfile({
    required this.id,
    required this.name,
    this.icon = '🤖',
    this.persona = '',
    this.tone = '',
    this.personalityTags = const [],
    this.catchphrases = const [],
    this.examples = const [],
    this.replyStyle = const ReplyStylePrefs(),
    this.systemPrompt = '',
    this.knowledge = const [],
    this.enabledSkillIds = const {},
    this.skillIds = const [],
    this.extensions = const [],
    this.memory = const MemorySettings(),
    this.request = const RequestSettings(),
    this.mcpServers = const [],
    this.params = const AssistantParams(),
    this.behaviorPrefs = const {},
    this.promptFragments = const [],
    this.isBuiltin = false,
    this.isPreset = false,
  });

  AssistantProfile copyWith({
    String? name,
    String? icon,
    String? persona,
    String? tone,
    List<String>? personalityTags,
    List<String>? catchphrases,
    List<ProfileExample>? examples,
    ReplyStylePrefs? replyStyle,
    String? systemPrompt,
    List<String>? knowledge,
    Set<String>? enabledSkillIds,
    List<String>? skillIds,
    List<AssistantExtension>? extensions,
    MemorySettings? memory,
    RequestSettings? request,
    List<McpBinding>? mcpServers,
    AssistantParams? params,
    Map<String, dynamic>? behaviorPrefs,
    List<String>? promptFragments,
  }) => AssistantProfile(
    id: id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    persona: persona ?? this.persona,
    tone: tone ?? this.tone,
    personalityTags: personalityTags ?? this.personalityTags,
    catchphrases: catchphrases ?? this.catchphrases,
    examples: examples ?? this.examples,
    replyStyle: replyStyle ?? this.replyStyle,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    knowledge: knowledge ?? this.knowledge,
    enabledSkillIds: enabledSkillIds ?? this.enabledSkillIds,
    skillIds: skillIds ?? this.skillIds,
    extensions: extensions ?? this.extensions,
    memory: memory ?? this.memory,
    request: request ?? this.request,
    mcpServers: mcpServers ?? this.mcpServers,
    params: params ?? this.params,
    behaviorPrefs: behaviorPrefs ?? this.behaviorPrefs,
    promptFragments: promptFragments ?? this.promptFragments,
    isBuiltin: isBuiltin,
    isPreset: isPreset,
  );

  factory AssistantProfile.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? v) =>
        (v is List ? v.whereType<String>().toList() : const <String>[]);
    List<dynamic> objList(Object? v) => (v is List ? v : const <dynamic>[]);
    return AssistantProfile(
      id:
          (json['id'] as String?) ??
          'p_${DateTime.now().millisecondsSinceEpoch}',
      name: (json['name'] as String?) ?? '未命名助手',
      icon: (json['icon'] as String?) ?? '🤖',
      persona: (json['persona'] as String?) ?? '',
      tone: (json['tone'] as String?) ?? '',
      personalityTags: strList(json['personalityTags']),
      catchphrases: strList(json['catchphrases']),
      examples: [
        for (final e in objList(json['examples']))
          if (e is Map) ProfileExample.fromJson(e.cast<String, dynamic>()),
      ],
      replyStyle: ReplyStylePrefs.fromJson(
        json['replyStyle'] is Map
            ? (json['replyStyle'] as Map).cast<String, dynamic>()
            : null,
      ),
      systemPrompt: (json['systemPrompt'] as String?) ?? '',
      knowledge: strList(json['knowledge']),
      enabledSkillIds: (json['enabledSkillIds'] is List
          ? (json['enabledSkillIds'] as List).whereType<String>().toSet()
          : const <String>{}),
      skillIds: strList(json['skillIds']),
      extensions: [
        for (final e in objList(json['extensions']))
          if (e is Map) AssistantExtension.fromJson(e.cast<String, dynamic>()),
      ],
      memory: MemorySettings.fromJson(
        json['memory'] is Map
            ? (json['memory'] as Map).cast<String, dynamic>()
            : null,
      ),
      request: RequestSettings.fromJson(
        json['request'] is Map
            ? (json['request'] as Map).cast<String, dynamic>()
            : null,
      ),
      mcpServers: [
        for (final e in objList(json['mcpServers']))
          if (e is Map) McpBinding.fromJson(e.cast<String, dynamic>()),
      ],
      params: AssistantParams.fromJson(
        json['params'] is Map
            ? (json['params'] as Map).cast<String, dynamic>()
            : null,
      ),
      behaviorPrefs: json['behaviorPrefs'] is Map
          ? (json['behaviorPrefs'] as Map).cast<String, dynamic>()
          : const {},
      promptFragments: strList(json['promptFragments']),
      isBuiltin: (json['isBuiltin'] as bool?) ?? false,
      isPreset: (json['isPreset'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'persona': persona,
    'tone': tone,
    'personalityTags': personalityTags,
    'catchphrases': catchphrases,
    'examples': [for (final e in examples) e.toJson()],
    'replyStyle': replyStyle.toJson(),
    'systemPrompt': systemPrompt,
    'knowledge': knowledge,
    'enabledSkillIds': enabledSkillIds.toList(),
    'skillIds': skillIds,
    'extensions': [for (final e in extensions) e.toJson()],
    'memory': memory.toJson(),
    'request': request.toJson(),
    'mcpServers': [for (final m in mcpServers) m.toJson()],
    'params': params.toJson(),
    'behaviorPrefs': behaviorPrefs,
    'promptFragments': promptFragments,
    'isBuiltin': isBuiltin,
    'isPreset': isPreset,
  };

  /// ③ 扩展管理：某模块是否启用。未显式配置时按默认启用处理。
  bool extensionEnabled(String id) {
    for (final e in extensions) {
      if (e.extensionId == id) return e.enabled;
    }
    return true;
  }
}

/// 基础层（系统默认基础提示词）：含占位符，请求前由 [replaceTemplateVars] 统一替换。
/// 改造点 8 修订 4："通用助手"的基础提示词是可见、可编辑的，
/// 预填于其 systemPrompt 字段；自定义助手默认不携带。
const kBaseSystemPrompt = '''
You are a helpful assistant, called assistant, based on model {{model_name}}.

## Info
- Time: {{cur_datetime}}
- Locale: {{locale}}
- Timezone: {{timezone}}
- Device Info: {{device_model}}
- System Version: {{system_version}}
- User Nickname: {{user_nickname}}

## Hint
- If the user does not specify a language, reply in the user's primary language.
- Remember to use Markdown syntax for formatting, and use latex for mathematical expressions.''';

/// 唯一默认模板："通用助手"。
/// 自带默认人格与完整的默认基础提示词（可见、预填、可编辑）；系统预设不可删除。
final AssistantProfile defaultProfile = AssistantProfile(
  id: 'assistant_default',
  name: '通用助手',
  icon: '🤖',
  persona: '你是一位友好、可靠的通用助手，乐于以清晰、有条理的方式帮助用户解决各类问题。',
  tone: '自然、亲切，避免生硬；根据场景适当调整正式或轻松的语气。',
  systemPrompt: kBaseSystemPrompt,
  enabledSkillIds: const {
    'open_url',
    'get_time',
    'get_device_info',
    'query_watch_history',
    'search_anime',
    'query_favorites',
    'query_watch_stats',
    'search_bangumi',
    'query_bangumi_characters',
    'search_bangumi_character',
    'search_bangumi_person',
    'analyze_bangumi',
    'query_logs',
    'recognize_anime',
  },
  params: const AssistantParams(),
  isBuiltin: true,
  isPreset: true,
);

/// 旧版内置预设 id（改造点 8 起删除预设模板，仅保留"通用助手"）
const _oldPresetIds = {'preset_code', 'preset_life', 'preset_writing'};

/// 助手档案存储：shared_preferences 持久化
class AssistantProfileStore extends ChangeNotifier {
  static final AssistantProfileStore instance = AssistantProfileStore._();

  AssistantProfileStore._();

  static const _kProfilesKey = 'assistant_profiles';
  static const _kActiveKey = 'assistant_active_profile';
  static const _kLegacyMigratedKey = 'assistant_profiles_legacy_migrated_v7';

  /// 四个情景型提示词（非助手）对应的旧 AiConfig key；
  /// 这类条目应从助手档案中清除，仅以提示词注入形式存在。
  static const _scenarioConfigKeys = {
    'ai_translator_v1',
    'soul_profiler_v1',
    'image_tag_v1',
    'summary_v1',
  };

  List<AssistantProfile> _profiles = [];
  String? _activeId;

  List<AssistantProfile> get profiles => List.unmodifiable(_profiles);

  String? get activeId => _activeId;

  AssistantProfile? get active => _find(_activeId);

  /// 按 id 查找档案；未找到返回 null
  AssistantProfile? find(String id) => _find(id);

  bool get isInitialized => _profiles.isNotEmpty;

  AssistantProfile? _find(String? id) {
    if (id == null) return null;
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfilesKey);
    if (raw == null || raw.isEmpty) {
      _profiles = [defaultProfile];
      _activeId = _profiles.first.id;
      await _save();
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _profiles = [
            for (final e in decoded)
              if (e is Map)
                AssistantProfile.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {
        _profiles = [defaultProfile];
      }
      if (_profiles.isEmpty) _profiles = [defaultProfile];
      _activeId = prefs.getString(_kActiveKey);
      if (_activeId == null || _find(_activeId) == null) {
        _activeId = _profiles.first.id;
      }
    }
    // 兼容迁移：旧"人格/角色管理"（AiConfig）数据导入为助手档案（仅执行一次）
    if (prefs.getBool(_kLegacyMigratedKey) != true) {
      try {
        await _importLegacyPersonas();
      } catch (_) {
        // 迁移失败不阻塞启动
      }
      await prefs.setBool(_kLegacyMigratedKey, true);
    }
    // 清除已误入助手档案的情景型提示词（含历史迁移产生的 legacy_* 条目）
    var before = _profiles.length;
    _profiles.removeWhere(
      (p) =>
          p.id.startsWith('legacy_') &&
          _scenarioConfigKeys.contains(p.id.substring('legacy_'.length)),
    );
    // 删除旧版预设模板（代码助手/生活管家/写作灵感），确保存在唯一默认模板"通用助手"
    _profiles.removeWhere((p) => _oldPresetIds.contains(p.id));
    if (!_profiles.any((p) => p.id == defaultProfile.id)) {
      _profiles.insert(0, defaultProfile);
    }
    if (_profiles.length != before) {
      if (_activeId == null || _find(_activeId) == null) {
        _activeId = _profiles.isEmpty ? null : _profiles.first.id;
      }
      await _save();
    }
    notifyListeners();
  }

  /// 把旧版"人格管理"（AiConfig：configKey/systemPrompt/memo）导入为助手档案。
  /// 系统内置的情景型提示词（翻译/侧写/tag/总结）不属于助手，跳过不导入。
  /// 旧会话仍保留 configKey 引用，服务层的兼容回退路径不受影响。
  Future<void> _importLegacyPersonas() async {
    final configs = await AiDatabase.instance.aiConfigDao.getAll();
    if (configs.isEmpty) return;
    final existingIds = _profiles.map((p) => p.id).toSet();
    var changed = false;
    for (final c in configs) {
      if (c.isSystem == true) continue;
      final prompt = c.systemPrompt.trim();
      if (prompt.isEmpty) continue;
      final id = 'legacy_${c.configKey}';
      if (existingIds.contains(id)) continue;
      final memo = c.memo?.trim() ?? '';
      _profiles.add(
        AssistantProfile(
          id: id,
          name: memo.isEmpty ? c.configKey : memo,
          icon: '🎭',
          systemPrompt: prompt,
          isBuiltin: c.isSystem == true,
        ),
      );
      existingIds.add(id);
      changed = true;
    }
    if (changed) await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kProfilesKey,
      jsonEncode([for (final p in _profiles) p.toJson()]),
    );
    if (_activeId != null) {
      await prefs.setString(_kActiveKey, _activeId!);
    }
  }

  Future<void> setActive(String id) async {
    if (_find(id) == null) return;
    _activeId = id;
    await _save();
    notifyListeners();
  }

  Future<void> upsert(AssistantProfile profile) async {
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      _profiles[idx] = profile;
    } else {
      _profiles.add(profile);
    }
    _activeId ??= profile.id;
    await _save();
    notifyListeners();
  }

  /// 删除档案；系统预设（isPreset）拒绝删除并返回 false
  Future<bool> remove(String id) async {
    final target = _find(id);
    if (target != null && target.isPreset) return false;
    _profiles.removeWhere((p) => p.id == id);
    if (_activeId == id) {
      _activeId = _profiles.isEmpty ? null : _profiles.first.id;
    }
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> resetDefaults() async {
    _profiles = [defaultProfile];
    _activeId = _profiles.first.id;
    await _save();
    notifyListeners();
  }

  /// 切换到指定助手（ProfileManager.switchTo）：
  /// 更新当前激活 → 同步本地工具/技能到运行时 → 持久化 → 刷新 UI。
  Future<void> switchTo(String id) async {
    final profile = _find(id);
    if (profile == null) return;
    _activeId = id;
    await _save();
    notifyListeners();
  }

  /// 复制为新档案（新 id，名称追加"副本"）。
  /// 复制"通用助手"等预设时清空其基础提示词（修订 4.4：副本以自行填写起步）。
  Future<AssistantProfile> copy(String id) async {
    final src = _find(id);
    if (src == null) return defaultProfile;
    final newId = 'copy_${src.id}_${DateTime.now().millisecondsSinceEpoch}';
    final profile = AssistantProfile(
      id: newId,
      name: '${src.name} 副本',
      icon: src.icon,
      persona: src.persona,
      tone: src.tone,
      personalityTags: src.personalityTags,
      catchphrases: src.catchphrases,
      examples: src.examples,
      replyStyle: src.replyStyle,
      systemPrompt: src.systemPrompt.trim() == kBaseSystemPrompt.trim()
          ? ''
          : src.systemPrompt,
      knowledge: src.knowledge,
      enabledSkillIds: src.enabledSkillIds,
      skillIds: src.skillIds,
      extensions: src.extensions,
      memory: src.memory,
      request: src.request,
      mcpServers: src.mcpServers,
      params: src.params,
      behaviorPrefs: src.behaviorPrefs,
      promptFragments: src.promptFragments,
      isBuiltin: false,
    );
    _profiles.add(profile);
    await _save();
    notifyListeners();
    return profile;
  }

  /// 导出档案为 JSON 字符串（用于分享/备份）
  String exportJson(String id) {
    final p = _find(id);
    if (p == null) return '';
    return const JsonEncoder.withIndent('  ').convert(p.toJson());
  }

  /// 从 JSON 导入档案；成功返回新档案，失败返回 null
  Future<AssistantProfile?> importJson(String json) async {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      var profile = AssistantProfile.fromJson(decoded);
      // 避免与现有档案 id 冲突
      if (_find(profile.id) != null) {
        profile = AssistantProfile(
          id: 'import_${DateTime.now().millisecondsSinceEpoch}',
          name: profile.name,
          icon: profile.icon,
          persona: profile.persona,
          tone: profile.tone,
          personalityTags: profile.personalityTags,
          catchphrases: profile.catchphrases,
          examples: profile.examples,
          replyStyle: profile.replyStyle,
          systemPrompt: profile.systemPrompt,
          knowledge: profile.knowledge,
          enabledSkillIds: profile.enabledSkillIds,
          skillIds: profile.skillIds,
          extensions: profile.extensions,
          memory: profile.memory,
          request: profile.request,
          mcpServers: profile.mcpServers,
          params: profile.params,
          behaviorPrefs: profile.behaviorPrefs,
          promptFragments: profile.promptFragments,
          isBuiltin: false,
        );
      }
      _profiles.add(profile);
      _activeId ??= profile.id;
      await _save();
      notifyListeners();
      return profile;
    } catch (_) {
      return null;
    }
  }
}

/// ④ 长期记忆存储：按助手档案 id 分库（shared_preferences）。
/// 记录用户偏好 / 常问话题 / 关键结论，在 System Prompt ⑥ 记忆段注入。
class AssistantMemoryStore extends ChangeNotifier {
  static final AssistantMemoryStore instance = AssistantMemoryStore._();

  AssistantMemoryStore._();

  static const _kPrefix = 'assistant_memory_v1_';

  final Map<String, List<String>> _cache = {};
  static String _key(String profileId) => '$_kPrefix$profileId';

  Future<List<String>> entriesFor(String profileId) async {
    if (_cache.containsKey(profileId)) return List.of(_cache[profileId]!);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(profileId));
    final list = (raw == null || raw.isEmpty)
        ? const <String>[]
        : raw.split('\u0001').where((e) => e.isNotEmpty).toList();
    _cache[profileId] = list;
    return List.of(list);
  }

  Future<void> _save(String profileId, List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(profileId), list.join('\u0001'));
    _cache[profileId] = list;
    notifyListeners();
  }

  Future<void> add(String profileId, String entry) async {
    final list = await entriesFor(profileId);
    final trimmed = entry.trim();
    if (trimmed.isEmpty) return;
    list.add(trimmed);
    final profile = AssistantProfileStore.instance.find(profileId);
    final max = profile?.memory.maxEntries ?? 50;
    if (list.length > max) {
      list.removeRange(0, list.length - max);
    }
    await _save(profileId, list);
  }

  Future<void> removeAt(String profileId, int index) async {
    final list = await entriesFor(profileId);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await _save(profileId, list);
  }

  Future<void> clear(String profileId) async {
    await _save(profileId, const []);
  }
}

const _kPrefLabels = {
  'concise': '简洁回复',
  'useMarkdown': '使用 Markdown 排版',
  'codeFirst': '代码优先',
  'actionable': '给出可执行建议',
};

/// 模板变量注册表：与 [replaceTemplateVars] 共用，供编辑页"占位符说明区"展示与一键插入。
const templateVarEntries = [
  (token: '{{cur_datetime}}', label: '当前时间'),
  (token: '{{user_nickname}}', label: '用户昵称'),
  (token: '{{model_name}}', label: '当前模型名'),
  (token: '{{locale}}', label: '语言'),
  (token: '{{timezone}}', label: '时区'),
  (token: '{{device_model}}', label: '设备型号'),
  (token: '{{system_version}}', label: '系统版本'),
  (token: '{{app_version}}', label: '应用版本'),
];

/// 当前用户昵称（与 {{user_nickname}} 占位符同源，勿另造名字）
String get currentUserNickname {
  final v = appdata.settings['userNickname'];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return '用户';
}

/// 模板变量取值（占位符 → 真实值）。
/// 未注册的占位符保持不变、不报错（由 [replaceTemplateVars] 保证）。
Map<String, String> templateVarValues({
  DateTime? now,
  String? modelName,
  String? userNickname,
}) {
  final time = now ?? DateTime.now();
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return {
    '{{cur_datetime}}': '${time.year}-${time.month}-${time.day} $hour:$minute',
    '{{model_name}}': modelName ?? 'deepseek-v4-flash',
    '{{locale}}': '中文 (中国)',
    '{{timezone}}': '中国标准时间',
    '{{device_model}}': _deviceModel(),
    '{{system_version}}': _systemVersion(),
    '{{user_nickname}}': (userNickname == null || userNickname.isEmpty)
        ? currentUserNickname
        : userNickname,
    '{{app_version}}': App.version,
  };
}

/// 发送请求前统一替换模板占位符；未注册变量保持原样。
String replaceTemplateVars(
  String text, {
  DateTime? now,
  String? modelName,
  String? userNickname,
}) {
  var result = text;
  templateVarValues(
    now: now,
    modelName: modelName,
    userNickname: userNickname,
  ).forEach((key, value) {
    result = result.replaceAll(key, value);
  });
  return result;
}

String _deviceModel() {
  if (App.isAndroid) return 'Android Device';
  if (App.isIOS) return 'iPhone';
  if (App.isWindows) return 'Windows PC';
  if (App.isMacOS) return 'Mac';
  if (App.isLinux) return 'Linux PC';
  return 'Unknown Device';
}

String _systemVersion() {
  if (App.isAndroid) return 'Android SDK';
  if (App.isIOS) return 'iOS';
  return App.version;
}

/// 组装 System Prompt 的主管线（改造点 8 修订）：
/// ① 基础提示词（档案 systemPrompt，含占位符；通用助手预填完整基础提示词）
/// → ② 人格注入（persona+tone+性格标签+口头禅+示例+回复风格）
/// → ③ 角色管理-提示词注入（按注入位置排序）→ ④ 有序提示片段
/// → ⑤ knowledge → ⑥ 长期记忆（memory 启用时）→ ⑦ 世界书命中条目（按 priority）
/// → ⑧ 当前时间/设备信息（占位符替换后的真实值）→ ⑨ 本地工具 + 技能 + MCP 工具清单。
///
/// [injections] / [worldBookHits] / [memoryEntries] 由调用方解析，空则自动省略。
String buildSystemPrompt({
  AssistantProfile? profile,
  String? userMessage,
  List<String>? availableSkills,
  List<PromptInjection>? injections,
  List<WorldBookEntry>? worldBookHits,
  List<String>? memoryEntries,
  DateTime? now,
  String? modelName,
}) {
  final parts = <String>[];

  // ① 基础提示词（通用助手预填 kBaseSystemPrompt；自定义助手可自行填写或留空）
  final base = profile?.systemPrompt.trim() ?? '';
  if (base.isNotEmpty) {
    parts.add(replaceTemplateVars(base, now: now, modelName: modelName));
  }

  // ② 人格注入
  parts.addAll(_personalityInjection(profile));

  // ③ 提示词注入（按 位置→排序号 分组插入）
  parts.addAll(
    _injectionsAt(PromptInjectionPosition.afterPersonality, injections),
  );

  // ④ 有序提示片段
  if (profile?.promptFragments.isNotEmpty == true) {
    final fragments = profile!.promptFragments
        .where((f) => f.trim().isNotEmpty)
        .toList();
    if (fragments.isNotEmpty) {
      final buf = StringBuffer('【提示】');
      for (var i = 0; i < fragments.length; i++) {
        buf.write('\n${i + 1}. ${fragments[i].trim()}');
      }
      parts.add(buf.toString());
    }
  }
  parts.addAll(
    _injectionsAt(PromptInjectionPosition.afterSystemPrompt, injections),
  );

  // ⑤ knowledge 背景知识
  if (profile?.knowledge.isNotEmpty == true) {
    parts.add(
      '【知识】\n${profile!.knowledge.where((k) => k.trim().isNotEmpty).join('\n')}',
    );
  }
  parts.addAll(
    _injectionsAt(PromptInjectionPosition.afterKnowledge, injections),
  );

  // ⑥ 长期记忆（memory 启用时）
  if (profile?.memory.enabled == true) {
    final memory = (memoryEntries ?? const <String>[])
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (memory.isNotEmpty) {
      parts.add('【长期记忆】\n${memory.join('\n')}');
    }
  }
  parts.addAll(_injectionsAt(PromptInjectionPosition.afterMemory, injections));

  // ⑦ 世界书命中条目（按 priority 降序）
  final hits = worldBookHits ?? const <WorldBookEntry>[];
  if (hits.isNotEmpty) {
    final buf = StringBuffer('【世界书】');
    var seq = 0;
    for (final e in hits) {
      if (e.content.trim().isEmpty) continue;
      seq++;
      buf.write('\n$seq. ${e.content.trim()}');
    }
    if (seq > 0) parts.add(buf.toString());
  }

  // ⑧ 当前时间 / 设备信息
  parts.add(_envBlock(now));

  // ③（续）工具清单前的注入片段
  parts.addAll(_injectionsAt(PromptInjectionPosition.beforeTools, injections));

  // ⑨ 本地工具 + MCP 工具清单
  final skills = (availableSkills ?? const <String>[])
      .where((s) => s.isNotEmpty)
      .toList();
  if (skills.isNotEmpty) {
    parts.add(
      '【可用技能】\n${skills.join('、')}\n'
      '需要时可主动调用以上技能来完成任务。',
    );
  }

  return parts.join('\n\n');
}

/// 旧版入口：仅按助手档案组装（用于编辑页预览等场景）
String buildAssistantSystemPrompt(
  AssistantProfile profile, {
  List<String>? availableSkills,
  DateTime? now,
}) {
  return buildSystemPrompt(
    profile: profile,
    availableSkills: availableSkills,
    now: now,
  );
}

/// ② 人格注入段：persona + tone + 性格标签 + 口头禅 + 回复风格 + 行为偏好 + 对话示例
List<String> _personalityInjection(AssistantProfile? profile) {
  if (profile == null) return const [];
  final out = <String>[];

  final persona = profile.persona.trim();
  final tone = profile.tone.trim();
  if (persona.isNotEmpty || tone.isNotEmpty) {
    final buf = StringBuffer('【角色设定】');
    if (persona.isNotEmpty) buf.write('\n$persona');
    if (tone.isNotEmpty) buf.write('\n$tone');
    out.add(buf.toString());
  }

  if (profile.personalityTags.isNotEmpty) {
    out.add('【性格标签】\n${profile.personalityTags.join('、')}');
  }

  if (profile.catchphrases.isNotEmpty) {
    final buf = StringBuffer('【口头禅】');
    for (final c in profile.catchphrases) {
      if (c.trim().isNotEmpty) buf.write('\n· ${c.trim()}');
    }
    if (buf.length > 4) out.add(buf.toString());
  }

  final rs = profile.replyStyle;
  final buf = StringBuffer('【回复风格】');
  final lengthLabel = switch (rs.length) {
    ReplyLength.short => '简短',
    ReplyLength.normal => '适中',
    ReplyLength.detailed => '详细',
  };
  buf.write('\n- 回复长度: $lengthLabel');
  if (rs.useEmoji) buf.write('\n- 适当使用 emoji 增强表达');
  if (rs.useMarkdown) buf.write('\n- 使用 Markdown 排版');
  if (rs.askBack) buf.write('\n- 结尾可反问用户以延续对话');
  out.add(buf.toString());

  if (profile.behaviorPrefs.isNotEmpty) {
    final buf = StringBuffer('【行为偏好】');
    profile.behaviorPrefs.forEach((key, value) {
      final label = _kPrefLabels[key] ?? key;
      buf.write('\n- $label: $value');
    });
    out.add(buf.toString());
  }

  if (profile.examples.isNotEmpty) {
    final buf = StringBuffer('【对话示例】');
    for (final e in profile.examples) {
      if (e.user.trim().isEmpty && e.assistant.trim().isEmpty) continue;
      buf.write('\n用户: ${e.user.trim()}');
      if (e.assistant.trim().isNotEmpty) {
        buf.write('\n助手: ${e.assistant.trim()}');
      }
    }
    if (buf.length > 5) out.add(buf.toString());
  }

  return out;
}

/// ③ 取出指定注入位置的启用片段
List<String> _injectionsAt(
  PromptInjectionPosition position,
  List<PromptInjection>? injections,
) {
  if (injections == null) return const [];
  return [
    for (final inj in injections)
      if (inj.position == position && inj.content.trim().isNotEmpty)
        '【提示词注入 · ${inj.name.trim()}】\n${inj.content.trim()}',
  ];
}

String _envBlock(DateTime? now) {
  final time = now ?? DateTime.now();
  final weekdays = const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final env = StringBuffer('【环境信息】');
  env.write(
    '\n- 当前时间: ${time.year}-${time.month}-${time.day} '
    '${time.hour}:${time.minute.toString().padLeft(2, '0')} '
    '（${weekdays[time.weekday - 1]}）',
  );
  env.write('\n- 平台: ${_platformName()}');
  return env.toString();
}

String _platformName() {
  if (App.isWindows) return 'Windows';
  if (App.isMacOS) return 'macOS';
  if (App.isLinux) return 'Linux';
  if (App.isAndroid) return 'Android';
  if (App.isIOS) return 'iOS';
  return '未知平台';
}
