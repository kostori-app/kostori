// lib/foundation/ai_service/role_management.dart
//
// 角色管理（扩展管理设置 - 区块 2）：
// 人格（persona / tone）已并入 AssistantProfile，本文件只承载两类"角色注入"：
// ① PromptInjection：可启用/停用、可排序、可指定注入位置的提示词注入片段。
// ② WorldBook：触发词驱动的世界书条目，命中用户消息时才注入。
// 二者均为全局（不分助手档案），经 buildSystemPrompt 管线拼入 system prompt。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';
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

  /// 旧版 shared_preferences key（用于一次性迁移）
  static const _legacyKey = 'prompt_injections';
  static const _legacySeededKey = 'prompt_injections_seeded_v1';
  static const _dirName = 'prompt_injections';

  List<PromptInjection> _items = [];
  bool _loaded = false;

  List<PromptInjection> get items => List.unmodifiable(_items);

  /// 目录（供选择性 WebDAV 同步）
  String get dirPath => '${App.dataPath}/$_dirName';

  /// 情景模块的提示词以代码常量为准；这些 id 的历史副本若未被修改则清理掉。
  static const _scenarioDefaults = <String, String>{
    kInjectionTranslator: aiTranslatePrompt,
    kInjectionSoulProfiler: soulProfilerSystemPrompt,
    kInjectionImageTag: imageTagSystemPrompt,
    kInjectionSummary: summarySystemPrompt,
  };

  Future<void> init() async {
    _items = [];
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await entity.readAsString());
          if (json is Map) {
            _items.add(PromptInjection.fromJson(json.cast<String, dynamic>()));
          }
        } catch (_) {}
      }
    } catch (_) {}
    await _migrateLegacy();
    // 清理未修改的内置情景注入副本（内容与代码常量一致才删，改过的保留）
    final removed = <String>[];
    _items.removeWhere((i) {
      final def = _scenarioDefaults[i.id];
      final hit = def != null && i.content.trim() == def.trim();
      if (hit) removed.add(i.id);
      return hit;
    });
    for (final id in removed) {
      _deleteFile(id);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _migrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is! Map) continue;
            final item = PromptInjection.fromJson(e.cast<String, dynamic>());
            if (_items.any((i) => i.id == item.id)) continue;
            _items.add(item);
            await _writeItem(item);
          }
        }
      } catch (_) {}
    }
    await prefs.remove(_legacyKey);
    await prefs.remove(_legacySeededKey);
  }

  Future<void> _writeItem(PromptInjection item) async {
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File(
      '$dirPath/${item.id}.json',
    ).writeAsString(jsonEncode(item.toJson()));
  }

  void _deleteFile(String id) {
    final f = File('$dirPath/$id.json');
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }

  /// 按 id 查找（无论是否启用，供情景模块引用）
  PromptInjection? findById(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// 确保已加载（供聊天管线等非 UI 场景使用）
  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  /// WebDAV 下载后重新加载
  Future<void> reload() async {
    _loaded = false;
    await init();
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
    await _writeItem(item);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _items.removeWhere((i) => i.id == id);
    _deleteFile(id);
    notifyListeners();
  }
}

/// 世界书条目（酒馆式进阶：分组 / 常驻 / 次级键 / 递归 / 位置 / sticky / 冷却）
class WorldBookEntry {
  final String id;
  final String name;

  /// 分组名（用于分类展示）
  final String group;

  /// 所属世界书（文件）ids：同一条目可属于多本（多对多归属）
  final List<String> bookIds;
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

  /// 注入位置：before_char（角色定义前）| after_char（角色定义后）|
  /// at_depth（按深度插入对话历史）
  final String position;

  /// at_depth 时的消息角色：system | user | assistant
  final String role;

  /// 绑定角色卡 id（空 = 不限制；非空时当前上下文需包含其中之一）
  final List<String> characterIds;

  /// 绑定标签（标签取自角色卡；空 = 不限制；非空时需有交集）
  final List<String> tags;

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
    this.bookIds = const [],
    this.triggers = const [],
    this.secondaryKeys = const [],
    this.content = '',
    this.priority = 0,
    this.enabled = true,
    this.constant = false,
    this.recursive = false,
    this.position = 'after_char',
    this.role = 'system',
    this.characterIds = const [],
    this.tags = const [],
    this.depth = 4,
    this.sticky = 0,
    this.cooldown = 0,
  });

  /// 主所属世界书（兼容旧逻辑 / 界面判断）
  String get bookId => bookIds.isEmpty ? '' : bookIds.first;

  WorldBookEntry copyWith({
    String? name,
    String? group,
    List<String>? bookIds,
    List<String>? triggers,
    List<String>? secondaryKeys,
    String? content,
    int? priority,
    bool? enabled,
    bool? constant,
    bool? recursive,
    String? position,
    String? role,
    List<String>? characterIds,
    List<String>? tags,
    int? depth,
    int? sticky,
    int? cooldown,
  }) => WorldBookEntry(
    id: id,
    name: name ?? this.name,
    group: group ?? this.group,
    bookIds: bookIds ?? this.bookIds,
    triggers: triggers ?? this.triggers,
    secondaryKeys: secondaryKeys ?? this.secondaryKeys,
    content: content ?? this.content,
    priority: priority ?? this.priority,
    enabled: enabled ?? this.enabled,
    constant: constant ?? this.constant,
    recursive: recursive ?? this.recursive,
    position: position ?? this.position,
    role: role ?? this.role,
    characterIds: characterIds ?? this.characterIds,
    tags: tags ?? this.tags,
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
      bookIds: [
        ...strList(json['bookIds']),
        if (strList(json['bookIds']).isEmpty &&
            (json['bookId'] as String?)?.isNotEmpty == true)
          json['bookId'] as String,
      ],
      triggers: strList(json['triggers']),
      secondaryKeys: strList(json['secondaryKeys']),
      content: (json['content'] as String?) ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      enabled: (json['enabled'] as bool?) ?? true,
      constant: (json['constant'] as bool?) ?? false,
      recursive: (json['recursive'] as bool?) ?? false,
      // 兼容旧值 before / after
      position: switch (json['position'] as String?) {
        'before' => 'before_char',
        'after' || null => 'after_char',
        final p => p,
      },
      role: (json['role'] as String?) ?? 'system',
      characterIds: strList(json['characterIds']),
      tags: strList(json['tags']),
      depth: (json['depth'] as num?)?.toInt() ?? 4,
      sticky: (json['sticky'] as num?)?.toInt() ?? 0,
      cooldown: (json['cooldown'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'group': group,
    if (bookIds.isNotEmpty) 'bookIds': bookIds,
    if (bookId.isNotEmpty) 'bookId': bookId,
    'triggers': triggers,
    'secondaryKeys': secondaryKeys,
    'content': content,
    'priority': priority,
    'enabled': enabled,
    'constant': constant,
    'recursive': recursive,
    'position': position,
    'role': role,
    'characterIds': characterIds,
    'tags': tags,
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

  /// 绑定过滤：未绑定角色/标签时恒通过；绑定时需与当前上下文有交集
  bool matchesBinding(Set<String> boundCharacterIds, Set<String> boundTags) {
    if (characterIds.isEmpty && tags.isEmpty) return true;
    if (characterIds.any(boundCharacterIds.contains)) return true;
    final lower = boundTags.map((e) => e.toLowerCase()).toSet();
    return tags.any((t) => lower.contains(t.trim().toLowerCase()));
  }

  /// 是否命中（常驻条目恒真；需同时满足主键与次级键）
  bool hits(String text) {
    if (constant) return true;
    final lower = text.toLowerCase();
    return hitsPrimary(lower) && hitsSecondary(lower);
  }
}

/// 一本书（文件）：包含多条世界书条目
class WorldBookBook {
  final String id;
  final String name;
  final List<WorldBookEntry> entries;

  const WorldBookBook({
    required this.id,
    this.name = '',
    this.entries = const [],
  });

  factory WorldBookBook.fromJson(Map<String, dynamic> json) => WorldBookBook(
    id:
        json['id']?.toString() ??
        'book_${DateTime.now().millisecondsSinceEpoch}',
    name: json['name']?.toString() ?? '',
    entries: [
      for (final e in (json['entries'] as List? ?? const []))
        if (e is Map) WorldBookEntry.fromJson(e.cast<String, dynamic>()),
    ],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'entries': [for (final e in entries) e.toJson()],
  };
}

/// 世界书存储：`dataPath/world_book/<bookId>.json`（一本书一个文件、内含多条条目）
class WorldBookStore extends ChangeNotifier {
  static final WorldBookStore instance = WorldBookStore._();

  WorldBookStore._();

  /// 旧版 shared_preferences key（用于一次性迁移）
  static const _legacyKey = 'world_book_entries';
  static const _dirName = 'world_book';

  List<WorldBookBook> _books = [];
  bool _loaded = false;

  /// 所有条目（跨书去重：同一条目可属于多本，只返回一份）
  List<WorldBookEntry> get entries {
    final seen = <String>{};
    return [
      for (final b in _books)
        for (final e in b.entries)
          if (seen.add(e.id)) e,
    ];
  }

  /// 全部世界书
  List<WorldBookBook> get books => List.unmodifiable(_books);

  WorldBookBook? bookById(String id) {
    for (final b in _books) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// 目录（供选择性 WebDAV 同步）
  String get dirPath => '${App.dataPath}/$_dirName';

  Future<void> init() async {
    _books = [];
    final rawBooks = <WorldBookBook>[];
    final legacy = <WorldBookEntry>[];
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final decoded = jsonDecode(await entity.readAsString());
          if (decoded is! Map) continue;
          final map = decoded.cast<String, dynamic>();
          final fileName = entity.uri.pathSegments.last;
          final fileId = fileName.substring(0, fileName.length - 5);
          if (map['entries'] is List) {
            // 一本书（条目可能同时属于多本，文件间去重合并）
            final book = WorldBookBook.fromJson(map);
            rawBooks.add(WorldBookBook(id: fileId, name: book.name, entries: book.entries));
          } else {
            // 旧格式：一条一个文件
            legacy.add(WorldBookEntry.fromJson(map));
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 合并各文件里的同 id 条目：成员取并集（多对多归属）
    final merged = <String, WorldBookEntry>{};
    for (final b in rawBooks) {
      for (final e0 in b.entries) {
        final e = e0.bookIds.contains(b.id)
            ? e0
            : e0.copyWith(bookIds: [b.id, ...e0.bookIds]);
        final prev = merged[e.id];
        merged[e.id] = prev == null
            ? e
            : prev.copyWith(
                bookIds: {...prev.bookIds, ...e.bookIds}.toList(),
              );
      }
    }
    _books = [
      for (final b in rawBooks)
        WorldBookBook(
          id: b.id,
          name: b.name,
          entries: [
            for (final e in merged.values)
              if (e.bookIds.contains(b.id)) e,
          ],
        ),
    ];

    if (legacy.isNotEmpty) await _migrateLegacyEntries(legacy);
    await _migratePrefs();
    _loaded = true;
    notifyListeners();
  }

  /// 旧版「一条目一文件」→ 按分组合并成一本书
  Future<void> _migrateLegacyEntries(List<WorldBookEntry> legacy) async {
    final grouped = <String, List<WorldBookEntry>>{};
    for (final e in legacy) {
      grouped.putIfAbsent(e.group.trim(), () => []).add(e);
    }
    var i = 0;
    for (final group in grouped.entries) {
      final bookId = 'book_${DateTime.now().millisecondsSinceEpoch}_${i++}';
      final book = WorldBookBook(
        id: bookId,
        name: group.key.isEmpty ? '世界书' : group.key,
        entries: [for (final e in group.value) e.copyWith(bookIds: [bookId])],
      );
      _books.add(book);
      await _writeBook(book);
    }
    for (final e in legacy) {
      final f = File('$dirPath/${e.id}.json');
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// 旧版 shared_preferences 数据迁移
  Future<void> _migratePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final bookId = 'book_${DateTime.now().millisecondsSinceEpoch}';
        final entries = <WorldBookEntry>[];
        for (final e in decoded) {
          if (e is Map) {
            entries.add(
              WorldBookEntry.fromJson(
                e.cast<String, dynamic>(),
              ).copyWith(bookIds: [bookId]),
            );
          }
        }
        if (entries.isNotEmpty) {
          final book = WorldBookBook(
            id: bookId,
            name: '世界书',
            entries: entries,
          );
          _books.add(book);
          await _writeBook(book);
        }
      }
    } catch (_) {}
    await prefs.remove(_legacyKey);
  }

  Future<void> _writeBook(WorldBookBook book) async {
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File(
      '$dirPath/${book.id}.json',
    ).writeAsString(jsonEncode(book.toJson()));
  }

  void _deleteBookFile(String bookId) {
    final f = File('$dirPath/$bookId.json');
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  /// WebDAV 下载后重新加载
  Future<void> reload() async {
    _loaded = false;
    await init();
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
    return _resolve(entries.where((e) => e.enabled), text, turn: turn);
  }

  /// 按选择集命中用户消息的条目：ids 为空表示沿用全局启用项（向后兼容）
  Future<List<WorldBookEntry>> select(
    Set<String> ids,
    String text, {
    int turn = 0,
  }) async {
    await ensureLoaded();
    final pool = ids.isEmpty
        ? entries.where((e) => e.enabled)
        : entries.where((e) => ids.contains(e.id));
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
      entries.where((e) => ids.contains(e.id)),
      '',
      turn: turn,
      useTriggers: false,
    );
  }

  /// 新增 / 更新一条条目（可属于多本书）。
  /// [bookId] 指定时并入该书；[replaceBooks] 为 true 则把所属书整体替换为该本。
  Future<void> upsert(
    WorldBookEntry entry, {
    String? bookId,
    bool replaceBooks = false,
  }) async {
    await ensureLoaded();
    var ids = [...entry.bookIds];
    if (bookId != null && bookId.isNotEmpty) {
      if (ids.isEmpty || replaceBooks) {
        ids = [bookId];
      } else if (!ids.contains(bookId)) {
        ids = [...ids, bookId];
      }
    }
    // 未指定任何书：并入最后一本，没有则新建一本
    if (ids.isEmpty) {
      if (_books.isEmpty) {
        ids = [(await createBook(name: '世界书')).id];
      } else {
        ids = [_books.last.id];
      }
    }
    // 确保所属书都存在
    for (final id in ids) {
      if (bookById(id) == null) {
        _books.add(WorldBookBook(id: id, name: '世界书'));
        await _writeBook(_books.last);
      }
    }
    final e = entry.copyWith(bookIds: ids);
    // 受影响的书 = 原先含有该条目的书 + 新的所属书
    final affected = <String>{
      for (final b in _books)
        if (b.entries.any((x) => x.id == e.id)) b.id,
      ...ids,
    };
    // 从所有书中移除旧版本
    for (var i = 0; i < _books.length; i++) {
      final filtered = _books[i].entries.where((x) => x.id != e.id).toList();
      if (filtered.length != _books[i].entries.length) {
        _books[i] = WorldBookBook(
          id: _books[i].id,
          name: _books[i].name,
          entries: filtered,
        );
      }
    }
    // 加入每本所属书
    for (final id in ids) {
      final i = _books.indexWhere((b) => b.id == id);
      _books[i] = WorldBookBook(
        id: _books[i].id,
        name: _books[i].name,
        entries: [..._books[i].entries, e],
      );
    }
    for (final id in affected) {
      final i = _books.indexWhere((b) => b.id == id);
      if (i >= 0) await _writeBook(_books[i]);
    }
    notifyListeners();
  }

  /// 设置条目的所属分组（多选）
  Future<void> setBookIds(String entryId, List<String> bookIds) async {
    await ensureLoaded();
    WorldBookEntry? target;
    for (final e in entries) {
      if (e.id == entryId) {
        target = e;
        break;
      }
    }
    if (target == null) return;
    // 至少要属于一个分组；全部取消视为不修改（避免误删）
    if (bookIds.isEmpty) return;
    await upsert(target.copyWith(bookIds: bookIds), replaceBooks: true);
  }

  /// 写入一本书（新建 / 覆盖 / 重命名）；条目成员关系取并集，保留其在别组的归属
  Future<void> upsertBook(WorldBookBook book) async {
    await ensureLoaded();
    final idx = _books.indexWhere((b) => b.id == book.id);
    if (idx >= 0) {
      _books[idx] = WorldBookBook(
        id: book.id,
        name: book.name,
        entries: _books[idx].entries,
      );
    } else {
      _books.add(WorldBookBook(id: book.id, name: book.name));
    }
    for (final e in book.entries) {
      await upsert(e, bookId: book.id);
    }
    final i = _books.indexWhere((b) => b.id == book.id);
    if (i >= 0) await _writeBook(_books[i]);
    notifyListeners();
  }

  /// 新建一本空书
  Future<WorldBookBook> createBook({String name = ''}) async {
    await ensureLoaded();
    final book = WorldBookBook(
      id: 'book_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    _books.add(book);
    await _writeBook(book);
    notifyListeners();
    return book;
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    var changed = false;
    for (var i = 0; i < _books.length; i++) {
      final filtered = _books[i].entries.where((e) => e.id != id).toList();
      if (filtered.length == _books[i].entries.length) continue;
      _books[i] = WorldBookBook(
        id: _books[i].id,
        name: _books[i].name,
        entries: filtered,
      );
      await _writeBook(_books[i]);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> removeBook(String bookId) async {
    await ensureLoaded();
    final removed = bookById(bookId);
    _books.removeWhere((b) => b.id == bookId);
    _deleteBookFile(bookId);
    if (removed != null) {
      for (final e in removed.entries) {
        final remaining = e.bookIds.where((x) => x != bookId).toList();
        if (remaining.isEmpty) {
          // 仅属于本书 → 一并删除
          for (var i = 0; i < _books.length; i++) {
            final filtered = _books[i].entries
                .where((x) => x.id != e.id)
                .toList();
            if (filtered.length == _books[i].entries.length) continue;
            _books[i] = WorldBookBook(
              id: _books[i].id,
              name: _books[i].name,
              entries: filtered,
            );
            await _writeBook(_books[i]);
          }
        } else {
          // 仍属于其它书 → 去掉本书成员关系后更新
          final updated = e.copyWith(bookIds: remaining);
          for (var i = 0; i < _books.length; i++) {
            final at = _books[i].entries.indexWhere((x) => x.id == e.id);
            if (at < 0) continue;
            final list = [..._books[i].entries];
            list[at] = updated;
            _books[i] = WorldBookBook(
              id: _books[i].id,
              name: _books[i].name,
              entries: list,
            );
            await _writeBook(_books[i]);
          }
        }
      }
    }
    notifyListeners();
  }
}

