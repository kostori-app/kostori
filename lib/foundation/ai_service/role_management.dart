// lib/foundation/ai_service/role_management.dart
//
// 角色管理（扩展管理设置 - 区块 2）：
// 人格（persona / tone）已并入 AssistantProfile，本文件只承载两类"角色注入"：
// ① PromptInjection：可启用/停用、可排序、可指定注入位置的提示词注入片段。
// ② WorldBook：触发词驱动的世界书条目，命中用户消息时才注入。
// 二者均为全局（不分助手档案），经 buildSystemPrompt 管线拼入 system prompt。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 四个"情景型提示词"注入的固定 id：
/// 它们本质上是提示词注入（单独为某情景服务，不能当助手用），
/// 已从助手档案中移除，作为提示词注入存在并被各情景模块（翻译/侧写/tag/总结）引用。
const kInjectionTranslator = 'inject_translator';
const kInjectionSoulProfiler = 'inject_soul_profiler';
const kInjectionImageTag = 'inject_image_tag';
const kInjectionSummary = 'inject_summary';

/// 提示词注入的位置（决定在 buildSystemPrompt 管线中的插入点）
enum PromptInjectionPosition {
  /// 人格注入之后（默认）
  afterPersonality,

  /// 自定义 systemPrompt 片段之后
  afterSystemPrompt,

  /// knowledge 背景知识之后
  afterKnowledge,

  /// 长期记忆之后（记忆未启用时等价于知识之后）
  afterMemory,

  /// 环境信息之后、工具清单之前
  beforeTools,
}

/// 提示词注入片段
class PromptInjection {
  final String id;
  final String name;
  final String content;
  final bool enabled;
  final PromptInjectionPosition position;
  final int sortOrder;

  const PromptInjection({
    required this.id,
    required this.name,
    this.content = '',
    this.enabled = true,
    this.position = PromptInjectionPosition.afterPersonality,
    this.sortOrder = 0,
  });

  PromptInjection copyWith({
    String? name,
    String? content,
    bool? enabled,
    PromptInjectionPosition? position,
    int? sortOrder,
  }) => PromptInjection(
    id: id,
    name: name ?? this.name,
    content: content ?? this.content,
    enabled: enabled ?? this.enabled,
    position: position ?? this.position,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  factory PromptInjection.fromJson(Map<String, dynamic> json) {
    return PromptInjection(
      id:
          (json['id'] as String?) ??
          'inject_${DateTime.now().millisecondsSinceEpoch}',
      name: (json['name'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      enabled: (json['enabled'] as bool?) ?? true,
      position:
          PromptInjectionPosition.values.asNameMap()[json['position']] ??
          PromptInjectionPosition.afterPersonality,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'enabled': enabled,
    'position': position.name,
    'sortOrder': sortOrder,
  };
}

/// 提示词注入存储：shared_preferences 持久化
class PromptInjectionStore extends ChangeNotifier {
  static final PromptInjectionStore instance = PromptInjectionStore._();

  PromptInjectionStore._();

  static const _kKey = 'prompt_injections';
  static const _kSeededKey = 'prompt_injections_seeded_v1';

  List<PromptInjection> _items = [];
  bool _loaded = false;

  List<PromptInjection> get items => List.unmodifiable(_items);

  /// 情景型提示词注入的内置定义（仅首次启动时灌入一次，之后可自由编辑/删除）
  static const _scenarioInjections = [
    (id: kInjectionTranslator, name: '专业母语译者', prompt: aiTranslatePrompt),
    (
      id: kInjectionSoulProfiler,
      name: '动漫灵魂侧写师',
      prompt: soulProfilerSystemPrompt,
    ),
    (
      id: kInjectionImageTag,
      name: 'AI 绘画 Tag 生成',
      prompt: imageTagSystemPrompt,
    ),
    (id: kInjectionSummary, name: '周月总结', prompt: summarySystemPrompt),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) {
      _items = [];
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items = [
            for (final e in decoded)
              if (e is Map) PromptInjection.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {
        _items = [];
      }
    }
    _loaded = true;
    if (prefs.getBool(_kSeededKey) != true) {
      var changed = false;
      for (final s in _scenarioInjections) {
        if (_items.any((i) => i.id == s.id)) continue;
        _items.add(
          PromptInjection(
            id: s.id,
            name: s.name,
            content: s.prompt,
            position: PromptInjectionPosition.afterSystemPrompt,
            enabled: false,
          ),
        );
        changed = true;
      }
      if (changed) await _save();
      await prefs.setBool(_kSeededKey, true);
    }
    notifyListeners();
  }

  /// 按 id 查找（无论是否启用，供情景模块引用）
  PromptInjection? findById(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode([for (final i in _items) i.toJson()]),
    );
  }

  /// 确保已加载（供聊天管线等非 UI 场景使用）
  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  /// 启用的注入片段，按（位置, 排序号）升序
  Future<List<PromptInjection>> enabledSorted() async {
    await ensureLoaded();
    final list = _items.where((i) => i.enabled).toList()
      ..sort((a, b) {
        final byPos = a.position.index.compareTo(b.position.index);
        return byPos != 0 ? byPos : a.sortOrder.compareTo(b.sortOrder);
      });
    return list;
  }

  Future<void> upsert(PromptInjection item) async {
    await ensureLoaded();
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.add(item);
    }
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _items.removeWhere((i) => i.id == id);
    await _save();
    notifyListeners();
  }
}

/// 世界书条目
class WorldBookEntry {
  final String id;
  final String name;
  final List<String> triggers;
  final String content;
  final int priority;
  final bool enabled;

  const WorldBookEntry({
    required this.id,
    required this.name,
    this.triggers = const [],
    this.content = '',
    this.priority = 0,
    this.enabled = true,
  });

  WorldBookEntry copyWith({
    String? name,
    List<String>? triggers,
    String? content,
    int? priority,
    bool? enabled,
  }) => WorldBookEntry(
    id: id,
    name: name ?? this.name,
    triggers: triggers ?? this.triggers,
    content: content ?? this.content,
    priority: priority ?? this.priority,
    enabled: enabled ?? this.enabled,
  );

  factory WorldBookEntry.fromJson(Map<String, dynamic> json) {
    final triggersRaw = json['triggers'];
    return WorldBookEntry(
      id:
          (json['id'] as String?) ??
          'wb_${DateTime.now().millisecondsSinceEpoch}',
      name: (json['name'] as String?) ?? '',
      triggers: triggersRaw is List
          ? triggersRaw.whereType<String>().toList()
          : const <String>[],
      content: (json['content'] as String?) ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'triggers': triggers,
    'content': content,
    'priority': priority,
    'enabled': enabled,
  };

  /// 用户消息是否命中任一触发词（不区分大小写；中文直接包含匹配）
  bool hits(String text) {
    final lower = text.toLowerCase();
    for (final t in triggers) {
      final trimmed = t.trim();
      if (trimmed.isEmpty) continue;
      if (lower.contains(trimmed.toLowerCase())) return true;
    }
    return false;
  }
}

/// 世界书存储：shared_preferences 持久化
class WorldBookStore extends ChangeNotifier {
  static final WorldBookStore instance = WorldBookStore._();

  WorldBookStore._();

  static const _kKey = 'world_book_entries';

  List<WorldBookEntry> _entries = [];
  bool _loaded = false;

  List<WorldBookEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) {
      _entries = [];
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries = [
            for (final e in decoded)
              if (e is Map) WorldBookEntry.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {
        _entries = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode([for (final e in _entries) e.toJson()]),
    );
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  /// 命中用户消息的启用条目，按 priority 降序（大者优先）
  Future<List<WorldBookEntry>> hits(String text) async {
    await ensureLoaded();
    final list = _entries.where((e) => e.enabled && e.hits(text)).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  Future<void> upsert(WorldBookEntry entry) async {
    await ensureLoaded();
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _entries[idx] = entry;
    } else {
      _entries.add(entry);
    }
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _entries.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }
}
