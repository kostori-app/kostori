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
    return _sorted(_items.where((i) => i.enabled));
  }

  /// 按选择集返回注入片段：ids 为空表示沿用全局启用项（向后兼容）
  Future<List<PromptInjection>> select(Set<String> ids) async {
    if (ids.isEmpty) return enabledSorted();
    await ensureLoaded();
    return _sorted(_items.where((i) => ids.contains(i.id)));
  }

  /// 只返回选择集内的注入片段（ids 为空则不注入任何片段）
  Future<List<PromptInjection>> selectExact(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    await ensureLoaded();
    return _sorted(_items.where((i) => ids.contains(i.id)));
  }

  static List<PromptInjection> _sorted(Iterable<PromptInjection> source) {
    return source.toList()
      ..sort((a, b) {
        final byPos = a.position.index.compareTo(b.position.index);
        return byPos != 0 ? byPos : a.sortOrder.compareTo(b.sortOrder);
      });
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

/// 世界书条目（酒馆式进阶：分组 / 常驻 / 次级键 / 递归 / 位置 / sticky / 冷却）
class WorldBookEntry {
  final String id;
  final String name;

  /// 分组名（用于分类展示）
  final String group;
  final List<String> triggers;

  /// 次级键：全部命中才算触发（AND，留空则忽略）
  final List<String> secondaryKeys;
  final String content;
  final int priority;
  final bool enabled;

  /// 常驻：无视触发词始终注入
  final bool constant;

  /// 递归：其内容可再次触发其它条目
  final bool recursive;

  /// 注入位置：before | after（相对系统提示词正文）
  final String position;

  /// 注入深度（越小越靠近末尾，仅影响同一位置内的排序）
  final int depth;

  /// 触发后保持注入的回合数（0 = 不保持）
  final int sticky;

  /// 触发后冷却的回合数（0 = 无冷却）
  final int cooldown;

  const WorldBookEntry({
    required this.id,
    required this.name,
    this.group = '',
    this.triggers = const [],
    this.secondaryKeys = const [],
    this.content = '',
    this.priority = 0,
    this.enabled = true,
    this.constant = false,
    this.recursive = false,
    this.position = 'after',
    this.depth = 4,
    this.sticky = 0,
    this.cooldown = 0,
  });

  WorldBookEntry copyWith({
    String? name,
    String? group,
    List<String>? triggers,
    List<String>? secondaryKeys,
    String? content,
    int? priority,
    bool? enabled,
    bool? constant,
    bool? recursive,
    String? position,
    int? depth,
    int? sticky,
    int? cooldown,
  }) => WorldBookEntry(
    id: id,
    name: name ?? this.name,
    group: group ?? this.group,
    triggers: triggers ?? this.triggers,
    secondaryKeys: secondaryKeys ?? this.secondaryKeys,
    content: content ?? this.content,
    priority: priority ?? this.priority,
    enabled: enabled ?? this.enabled,
    constant: constant ?? this.constant,
    recursive: recursive ?? this.recursive,
    position: position ?? this.position,
    depth: depth ?? this.depth,
    sticky: sticky ?? this.sticky,
    cooldown: cooldown ?? this.cooldown,
  );

  factory WorldBookEntry.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? v) =>
        v is List ? v.whereType<String>().toList() : const <String>[];
    return WorldBookEntry(
      id:
          (json['id'] as String?) ??
          'wb_${DateTime.now().millisecondsSinceEpoch}',
      name: (json['name'] as String?) ?? '',
      group: (json['group'] as String?) ?? '',
      triggers: strList(json['triggers']),
      secondaryKeys: strList(json['secondaryKeys']),
      content: (json['content'] as String?) ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      enabled: (json['enabled'] as bool?) ?? true,
      constant: (json['constant'] as bool?) ?? false,
      recursive: (json['recursive'] as bool?) ?? false,
      position: (json['position'] as String?) ?? 'after',
      depth: (json['depth'] as num?)?.toInt() ?? 4,
      sticky: (json['sticky'] as num?)?.toInt() ?? 0,
      cooldown: (json['cooldown'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'group': group,
    'triggers': triggers,
    'secondaryKeys': secondaryKeys,
    'content': content,
    'priority': priority,
    'enabled': enabled,
    'constant': constant,
    'recursive': recursive,
    'position': position,
    'depth': depth,
    'sticky': sticky,
    'cooldown': cooldown,
  };

  /// 主键是否命中（不区分大小写；中文直接包含匹配）
  bool hitsPrimary(String lowerText) {
    for (final t in triggers) {
      final trimmed = t.trim();
      if (trimmed.isEmpty) continue;
      if (lowerText.contains(trimmed.toLowerCase())) return true;
    }
    return false;
  }

  /// 次级键是否全部命中（为空视为通过）
  bool hitsSecondary(String lowerText) {
    for (final t in secondaryKeys) {
      final trimmed = t.trim();
      if (trimmed.isEmpty) continue;
      if (!lowerText.contains(trimmed.toLowerCase())) return false;
    }
    return true;
  }

  /// 是否命中（常驻条目恒真；需同时满足主键与次级键）
  bool hits(String text) {
    if (constant) return true;
    final lower = text.toLowerCase();
    return hitsPrimary(lower) && hitsSecondary(lower);
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

  /// 触发状态：entryId -> 保持/冷却到的回合
  final Map<String, int> _stickyUntil = {};
  final Map<String, int> _cooldownUntil = {};

  /// 解析命中条目（常驻 / sticky / 冷却 / 递归）
  List<WorldBookEntry> _resolve(
    Iterable<WorldBookEntry> pool,
    String text, {
    required int turn,
    bool useTriggers = true,
    int maxRecursive = 3,
  }) {
    final selected = <WorldBookEntry>[];
    final selectedIds = <String>{};

    void activate(WorldBookEntry e) {
      selected.add(e);
      selectedIds.add(e.id);
      if (e.sticky > 0) _stickyUntil[e.id] = turn + e.sticky;
      if (e.cooldown > 0) {
        _cooldownUntil[e.id] = turn + e.sticky + e.cooldown;
      }
    }

    final ordered = pool.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final e in ordered) {
      if (selectedIds.contains(e.id)) continue;
      if (!useTriggers) {
        activate(e);
        continue;
      }
      final cooling = _cooldownUntil[e.id];
      if (cooling != null && turn < cooling) continue;
      final stickyUntil = _stickyUntil[e.id];
      final sticky = stickyUntil != null && turn < stickyUntil;
      if (e.hits(text) || sticky) activate(e);
    }

    // 递归：用已注入内容继续扫描，触发更多条目
    if (useTriggers && maxRecursive > 0) {
      for (var depth = 0; depth < maxRecursive; depth++) {
        final haystack = selected
            .where((e) => e.recursive)
            .map((e) => e.content)
            .join('\n');
        if (haystack.isEmpty) break;
        final before = selected.length;
        for (final e in ordered) {
          if (selectedIds.contains(e.id)) continue;
          final cooling = _cooldownUntil[e.id];
          if (cooling != null && turn < cooling) continue;
          if (e.hits(haystack)) activate(e);
        }
        if (selected.length == before) break;
      }
    }

    selected.sort((a, b) {
      final byPos = a.position.compareTo(b.position);
      if (byPos != 0) return byPos;
      final byDepth = a.depth.compareTo(b.depth);
      if (byDepth != 0) return byDepth;
      return b.priority.compareTo(a.priority);
    });
    return selected;
  }

  /// 命中用户消息的启用条目，按位置/深度/优先级排序
  Future<List<WorldBookEntry>> hits(String text, {int turn = 0}) async {
    await ensureLoaded();
    return _resolve(_entries.where((e) => e.enabled), text, turn: turn);
  }

  /// 按选择集命中用户消息的条目：ids 为空表示沿用全局启用项（向后兼容）
  Future<List<WorldBookEntry>> select(
    Set<String> ids,
    String text, {
    int turn = 0,
  }) async {
    await ensureLoaded();
    final pool = ids.isEmpty
        ? _entries.where((e) => e.enabled)
        : _entries.where((e) => ids.contains(e.id));
    return _resolve(pool, text, turn: turn);
  }

  /// 只返回选择集内的条目且不做触发词匹配（供故事等显式选择场景）
  Future<List<WorldBookEntry>> selectAll(
    Set<String> ids, {
    int turn = 0,
  }) async {
    if (ids.isEmpty) return const [];
    await ensureLoaded();
    return _resolve(
      _entries.where((e) => ids.contains(e.id)),
      '',
      turn: turn,
      useTriggers: false,
    );
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
