// AI 冒险（AI 扮演）核心数据：
// 故事（Story）= 整合好的世界书 + 设定 + 提示词 + 开局引导 + 后续建议提示词；
// 游戏状态（GameState）= AI 每回合输出的结构化数值，用于状态面板展示。
// 支持 .md 导入/导出。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单项数值条（如 生命 100/100）
class StatBar {
  final String name;
  final int cur;
  final int max;

  const StatBar({required this.name, required this.cur, required this.max});

  factory StatBar.fromJson(String name, dynamic v) {
    if (v is Map) {
      return StatBar(
        name: name,
        cur: (v['cur'] as num?)?.toInt() ?? 0,
        max: (v['max'] as num?)?.toInt() ?? 0,
      );
    }
    if (v is num) return StatBar(name: name, cur: v.toInt(), max: v.toInt());
    return StatBar(name: name, cur: 0, max: 0);
  }

  Map<String, dynamic> toJson() => {'cur': cur, 'max': max};

  StatBar copyWith({int? cur, int? max}) =>
      StatBar(name: name, cur: cur ?? this.cur, max: max ?? this.max);
}

class QuestItem {
  final String title;
  final String desc;
  final int progress; // 0..100

  const QuestItem({required this.title, this.desc = '', this.progress = 0});

  factory QuestItem.fromJson(dynamic v) {
    if (v is Map) {
      return QuestItem(
        title: v['title']?.toString() ?? '',
        desc: v['desc']?.toString() ?? '',
        progress: (v['progress'] as num?)?.toInt() ?? 0,
      );
    }
    return QuestItem(title: v.toString());
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'desc': desc,
    'progress': progress,
  };
}

/// 本回合发生的特殊事件（用于单独高亮渲染）
class StoryEvent {
  /// location | damage | heal | item | quest | dice | info
  final String type;
  final String title;
  final String text;
  final int? value;

  /// dice：是否为成功检定
  final bool? success;

  const StoryEvent({
    required this.type,
    this.title = '',
    this.text = '',
    this.value,
    this.success,
  });

  factory StoryEvent.fromJson(dynamic v) {
    if (v is Map) {
      return StoryEvent(
        type: v['type']?.toString() ?? 'info',
        title: v['title']?.toString() ?? '',
        text: (v['text'] ?? v['desc'] ?? '').toString(),
        value: (v['value'] as num?)?.toInt(),
        success: v['success'] as bool?,
      );
    }
    return StoryEvent(type: 'info', text: v.toString());
  }
}

/// 故事自定义操作（「更多」菜单里的按钮），点击后把 prompt 作为指令发送
class StoryAction {
  final String label;
  final String prompt;

  /// 图标名（见 _storyActionIcon 映射）
  final String icon;

  const StoryAction({
    required this.label,
    required this.prompt,
    this.icon = '',
  });

  factory StoryAction.fromJson(Map<String, dynamic> json) => StoryAction(
    label: json['label']?.toString() ?? '',
    prompt: json['prompt']?.toString() ?? json['label']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'prompt': prompt,
    'icon': icon,
  };
}

/// 设定条目（道具 / 种族 / 特质 / 天赋等）：一层给玩家看，一层给 AI 看
class StoryDefinition {
  final String kind; // item | race | trait | talent | skill | ...
  final String key;
  final String name;

  /// 给玩家看的表面描述
  final String display;

  /// 给 AI 看的机制说明（注入 system prompt，避免模型自相矛盾）
  final String mechanics;

  const StoryDefinition({
    required this.kind,
    required this.key,
    required this.name,
    this.display = '',
    this.mechanics = '',
  });

  factory StoryDefinition.fromJson(Map<String, dynamic> json) =>
      StoryDefinition(
        kind: json['kind']?.toString() ?? 'info',
        key: json['key']?.toString() ?? json['name']?.toString() ?? '',
        name: json['name']?.toString() ?? json['key']?.toString() ?? '',
        display: json['display']?.toString() ?? '',
        mechanics: json['mechanics']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'key': key,
    'name': name,
    'display': display,
    'mechanics': mechanics,
  };
}

/// 游戏状态：AI 每回合输出的结构化数值
class GameState {
  final List<StatBar> resources;
  final Map<String, int> attributes;
  final List<String> skills;
  final List<String> inventory;
  final List<QuestItem> quests;
  final String time;
  final String location;

  /// 设定图鉴（道具/种族/特质/天赋等），持久化并注入 AI 提示词
  final List<StoryDefinition> codex;

  /// 动态局势（由 AI 每回合可选输出，展示在「局势」页签）
  final String situation;

  const GameState({
    this.resources = const [],
    this.attributes = const {},
    this.skills = const [],
    this.inventory = const [],
    this.quests = const [],
    this.time = '',
    this.location = '',
    this.codex = const [],
    this.situation = '',
  });

  static const empty = GameState();

  GameState copyWith({
    List<StatBar>? resources,
    Map<String, int>? attributes,
    List<String>? skills,
    List<String>? inventory,
    List<QuestItem>? quests,
    String? time,
    String? location,
    List<StoryDefinition>? codex,
    String? situation,
  }) => GameState(
    resources: resources ?? this.resources,
    attributes: attributes ?? this.attributes,
    skills: skills ?? this.skills,
    inventory: inventory ?? this.inventory,
    quests: quests ?? this.quests,
    time: time ?? this.time,
    location: location ?? this.location,
    codex: codex ?? this.codex,
    situation: situation ?? this.situation,
  );

  factory GameState.fromJson(Map<String, dynamic> json) {
    final resources = <StatBar>[];
    final rawRes = json['resources'];
    if (rawRes is Map) {
      for (final e in rawRes.entries) {
        resources.add(StatBar.fromJson(e.key.toString(), e.value));
      }
    }
    final attributes = <String, int>{};
    final rawAttr = json['attributes'];
    if (rawAttr is Map) {
      for (final e in rawAttr.entries) {
        if (e.value is num) attributes[e.key.toString()] = (e.value as num).toInt();
      }
    }
    List<String> strs(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    return GameState(
      resources: resources,
      attributes: attributes,
      skills: strs(json['skills']),
      inventory: strs(json['inventory']),
      quests:
          (json['quests'] is List)
          ? (json['quests'] as List).map(QuestItem.fromJson).toList()
          : const [],
      time: json['time']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      codex:
          (json['codex'] is List)
          ? [
              for (final e in json['codex'] as List)
                if (e is Map)
                  StoryDefinition.fromJson(e.cast<String, dynamic>()),
            ]
          : const [],
      situation: json['situation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'resources': {for (final r in resources) r.name: r.toJson()},
    'attributes': attributes,
    'skills': skills,
    'inventory': inventory,
    'quests': [for (final q in quests) q.toJson()],
    'time': time,
    'location': location,
    'codex': [for (final d in codex) d.toJson()],
    'situation': situation,
  };
}

/// 开局档案的一个设置项（类似 DnD 捏人）：单选 / 多选 / 自填 / 数值
class StorySetupPart {
  final String key;
  final String title;

  /// single（单选） | multi（多选） | text（自填） | number（数值）
  final String type;

  final List<String> options;
  final bool required;
  final String hint;

  /// 分组标题（同组展示在一起）
  final String group;

  /// number 类型的取值范围与默认值
  final int? min;
  final int? max;
  final int? value;

  /// 所在分组的可分配点数池（组内取第一个非空；null = 不限制）
  final int? pool;

  const StorySetupPart({
    required this.key,
    required this.title,
    this.type = 'single',
    this.options = const [],
    this.required = false,
    this.hint = '',
    this.group = '',
    this.min,
    this.max,
    this.value,
    this.pool,
  });

  factory StorySetupPart.fromJson(Map<String, dynamic> json) => StorySetupPart(
    key: json['key']?.toString() ?? '',
    title: json['title']?.toString() ?? json['key']?.toString() ?? '',
    type: json['type']?.toString() ?? 'single',
    options:
        (json['options'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    required: json['required'] as bool? ?? false,
    hint: json['hint']?.toString() ?? '',
    group: json['group']?.toString() ?? '',
    min: (json['min'] as num?)?.toInt(),
    max: (json['max'] as num?)?.toInt(),
    value: (json['value'] as num?)?.toInt(),
    pool: (json['pool'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'type': type,
    'options': options,
    'required': required,
    'hint': hint,
    'group': group,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (value != null) 'value': value,
    if (pool != null) 'pool': pool,
  };
}

/// 故事：整合好的世界书 + 设定 + 提示词 + 开局 + 后续建议提示词
class Story {
  final String id;
  final String name;
  final String icon;
  final String description;
  final String opening;
  final String systemPrompt;
  final String worldBook;

  /// 后续建议（选项）生成提示词，可自定义（DnD 风格引导）
  final String choicesPrompt;

  /// 开局档案设置项（开局只做一次；为空则直接开始）
  final List<StorySetupPart> setup;

  /// 故事背景 / 局势（展示在「局势」页签）
  final String situation;

  /// 故事自定义操作（「更多」菜单里的按钮）
  final List<StoryAction> actions;

  /// 从世界书库中选择注入的条目（为空表示不注入库条目）
  final List<String> worldBookIds;

  /// 从提示词注入库中选择的条目（为空表示不注入库条目）
  final List<String> injectionIds;

  final GameState initialState;
  final bool isBuiltin;

  const Story({
    required this.id,
    required this.name,
    this.icon = '📖',
    this.description = '',
    this.opening = '',
    this.systemPrompt = '',
    this.worldBook = '',
    this.choicesPrompt = '',
    this.setup = const [],
    this.situation = '',
    this.actions = const [],
    this.worldBookIds = const [],
    this.injectionIds = const [],
    this.initialState = GameState.empty,
    this.isBuiltin = false,
  });

  Story copyWith({
    String? name,
    String? icon,
    String? description,
    String? opening,
    String? systemPrompt,
    String? worldBook,
    String? choicesPrompt,
    List<StorySetupPart>? setup,
    String? situation,
    List<StoryAction>? actions,
    List<String>? worldBookIds,
    List<String>? injectionIds,
    GameState? initialState,
  }) => Story(
    id: id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    description: description ?? this.description,
    opening: opening ?? this.opening,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    worldBook: worldBook ?? this.worldBook,
    choicesPrompt: choicesPrompt ?? this.choicesPrompt,
    setup: setup ?? this.setup,
    situation: situation ?? this.situation,
    actions: actions ?? this.actions,
    worldBookIds: worldBookIds ?? this.worldBookIds,
    injectionIds: injectionIds ?? this.injectionIds,
    initialState: initialState ?? this.initialState,
    isBuiltin: isBuiltin,
  );

  factory Story.fromJson(Map<String, dynamic> json) => Story(
    id: (json['id'] as String?) ?? 'story_${DateTime.now().millisecondsSinceEpoch}',
    name: (json['name'] as String?) ?? '',
    icon: (json['icon'] as String?) ?? '📖',
    description: (json['description'] as String?) ?? '',
    opening: (json['opening'] as String?) ?? '',
    systemPrompt: (json['systemPrompt'] as String?) ?? '',
    worldBook: (json['worldBook'] as String?) ?? '',
    choicesPrompt: (json['choicesPrompt'] as String?) ?? '',
    setup: json['setup'] is List
        ? [
            for (final e in json['setup'] as List)
              if (e is Map) StorySetupPart.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    situation: (json['situation'] as String?) ?? '',
    actions: json['actions'] is List
        ? [
            for (final e in json['actions'] as List)
              if (e is Map) StoryAction.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    worldBookIds: (json['worldBookIds'] as List?)?.whereType<String>().toList() ??
        const [],
    injectionIds: (json['injectionIds'] as List?)?.whereType<String>().toList() ??
        const [],
    initialState: json['initialState'] is Map
        ? GameState.fromJson((json['initialState'] as Map).cast<String, dynamic>())
        : GameState.empty,
    isBuiltin: (json['isBuiltin'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'description': description,
    'opening': opening,
    'systemPrompt': systemPrompt,
    'worldBook': worldBook,
    'choicesPrompt': choicesPrompt,
    'setup': [for (final p in setup) p.toJson()],
    'situation': situation,
    'actions': [for (final a in actions) a.toJson()],
    'worldBookIds': worldBookIds,
    'injectionIds': injectionIds,
    'initialState': initialState.toJson(),
    'isBuiltin': isBuiltin,
  };

  /// 拼出完整 GM 系统提示词（世界书 + 提示词 + 输出格式 + 建议提示词）
  String buildSystemPrompt() {
    final buf = StringBuffer();
    if (worldBook.trim().isNotEmpty) {
      buf.writeln('【世界书 / 设定】');
      buf.writeln(worldBook.trim());
      buf.writeln();
    }
    if (systemPrompt.trim().isNotEmpty) {
      buf.writeln(systemPrompt.trim());
      buf.writeln();
    }
    buf.writeln('''
【输出格式要求】
每次回复必须严格分为两部分：
1. 先以第二人称描写场景、行动结果与对话（叙事正文，可用 Markdown）。
2. 正文结束后，另起一行输出一个 JSON 代码块，且只输出这一个代码块，不要添加其它说明：
```json
{
  "state": {
    "resources": { "生命": {"cur": 100, "max": 100}, "精神": {"cur": 100, "max": 100} },
    "attributes": { "力量": 5, "敏捷": 5, "智力": 5 },
    "skills": ["技能名"],
    "inventory": ["物品 x1"],
    "quests": [{"title": "任务", "desc": "描述", "progress": 0}],
    "time": "第1天 08:00",
    "location": "地点",
    "codex": [{"kind":"item|race|trait|talent|skill","key":"唯一键","name":"名称","display":"给玩家看的表面描述","mechanics":"给GM看的机制/数值，后续必须严格遵守"}],
    "situation": "当前局势/所在环境的简述（可选，展示在局势页签）"
  },
  "events": [{"type":"location|damage|heal|item|quest|dice|info","title":"标题","text":"内容","value":0,"success":true}],
  "choices": ["选项A", "选项B", "选项C"]
}
```
规则：
- state 需给出当前完整状态；codex 记录出现或已有的道具/种族/特质/天赋等设定，display 面向玩家，mechanics 供你后续严格遵守，避免自相矛盾。
- events 列出本回合的关键事件（进入地区 / 受伤掉血 / 获得道具 / 完成任务 / 检定等），会单独高亮展示。需要检定时用 type=dice，并在 text 里写明「N d M + 修正 = 结果 vs DC」及 success。
- choices 提供 3-5 个可供玩家选择的行动。''');
    if (choicesPrompt.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('【后续建议要求】');
      buf.writeln(choicesPrompt.trim());
    }
    return buf.toString();
  }
}

/// 故事存储：内置故事 + 用户自定义，shared_preferences 持久化
class StoryStore extends ChangeNotifier {
  static final StoryStore instance = StoryStore._();

  StoryStore._();

  static const _kKey = 'ai_stories';

  List<Story> _stories = [];
  bool _loaded = false;

  List<Story> get stories => List.unmodifiable(_stories);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    _stories = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _stories = [
            for (final e in decoded)
              if (e is Map) Story.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {
        _stories = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  Story? find(String id) {
    for (final s in _stories) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode([for (final s in _stories) s.toJson()]),
    );
  }

  Future<void> upsert(Story story) async {
    await ensureLoaded();
    final idx = _stories.indexWhere((s) => s.id == story.id);
    if (idx >= 0) {
      _stories[idx] = story;
    } else {
      _stories.add(story);
    }
    await _save();
    notifyListeners();
  }

  Future<bool> remove(String id) async {
    await ensureLoaded();
    final s = find(id);
    if (s != null && s.isBuiltin) return false;
    _stories.removeWhere((s) => s.id == id);
    await _save();
    notifyListeners();
    return true;
  }

  /// 从 .md 文本解析故事
  static Story storyFromMarkdown(String text, {String? id}) {
    final name = _firstHeading(text) ?? '未命名故事';
    final description = _quoteLine(text) ?? '';
    var initialState = GameState.empty;
    final stateText = _section(text, '初始状态');
    if (stateText != null) {
      try {
        final decoded = jsonDecode(stateText);
        if (decoded is Map) {
          initialState = GameState.fromJson(decoded.cast<String, dynamic>());
        }
      } catch (_) {}
    }
    var setup = <StorySetupPart>[];
    final setupText = _section(text, '开局设置');
    if (setupText != null) {
      try {
        final decoded = jsonDecode(setupText);
        if (decoded is List) {
          setup = [
            for (final e in decoded)
              if (e is Map) StorySetupPart.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {}
    }
    var actions = <StoryAction>[];
    final actionsText = _section(text, '操作');
    if (actionsText != null) {
      try {
        final decoded = jsonDecode(actionsText);
        if (decoded is List) {
          actions = [
            for (final e in decoded)
              if (e is Map) StoryAction.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {}
    }
    List<String> idList(String section) {
      final raw = _section(text, section);
      if (raw == null) return const [];
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.whereType<String>().toList();
      } catch (_) {}
      return const [];
    }
    return Story(
      id: id ?? 'story_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      opening: _section(text, '开局') ?? '',
      systemPrompt: _section(text, '系统提示词') ?? '',
      worldBook: _section(text, '世界书') ?? '',
      choicesPrompt: _section(text, '后续建议提示词') ?? '',
      setup: setup,
      situation: _section(text, '局势') ?? '',
      actions: actions,
      worldBookIds: idList('世界书库'),
      injectionIds: idList('提示词库'),
      initialState: initialState,
    );
  }

  static String storyToMarkdown(Story s) {
    final buf = StringBuffer();
    buf.writeln('# ${s.name}');
    buf.writeln();
    if (s.description.isNotEmpty) {
      buf.writeln('> ${s.description}');
      buf.writeln();
    }
    void section(String title, String content) {
      buf.writeln('## $title');
      buf.writeln(content.trim());
      buf.writeln();
    }

    section('开局', s.opening);
    section('系统提示词', s.systemPrompt);
    section('世界书', s.worldBook);
    if (s.situation.isNotEmpty) section('局势', s.situation);
    section('后续建议提示词', s.choicesPrompt);
    if (s.setup.isNotEmpty) {
      section('开局设置', jsonEncode([for (final p in s.setup) p.toJson()]));
    }
    if (s.actions.isNotEmpty) {
      section('操作', jsonEncode([for (final a in s.actions) a.toJson()]));
    }
    if (s.worldBookIds.isNotEmpty) {
      section('世界书库', jsonEncode(s.worldBookIds));
    }
    if (s.injectionIds.isNotEmpty) {
      section('提示词库', jsonEncode(s.injectionIds));
    }
    section('初始状态', jsonEncode(s.initialState.toJson()));
    return buf.toString();
  }

  static String? _firstHeading(String text) {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.startsWith('# ')) return t.substring(2).trim();
    }
    return null;
  }

  static String? _quoteLine(String text) {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.startsWith('> ')) return t.substring(2).trim();
    }
    return null;
  }

  static String? _section(String text, String title) {
    final lines = text.split('\n');
    final buf = StringBuffer();
    var inSection = false;
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('## ')) {
        if (inSection) break;
        inSection = t.substring(3).trim() == title;
        continue;
      }
      if (inSection) buf.writeln(line);
    }
    final out = buf.toString().trim();
    return out.isEmpty ? null : out;
  }
}

/// 单个故事的游戏会话状态（对话复用 AI 会话表，这里只存状态与关联）
class StorySession {
  final String sessionId;
  final GameState state;

  const StorySession({required this.sessionId, required this.state});

  factory StorySession.fromJson(Map<String, dynamic> json) => StorySession(
    sessionId: json['sessionId']?.toString() ?? '',
    state: json['state'] is Map
        ? GameState.fromJson((json['state'] as Map).cast<String, dynamic>())
        : GameState.empty,
  );

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'state': state.toJson(),
  };
}

/// 会话存储：storyId -> StorySession，shared_preferences 持久化
class StorySessionStore extends ChangeNotifier {
  static final StorySessionStore instance = StorySessionStore._();

  StorySessionStore._();

  static const _kKey = 'ai_story_sessions';

  Map<String, StorySession> _sessions = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _sessions = {
            for (final e in decoded.entries)
              if (e.value is Map)
                e.key.toString(): StorySession.fromJson(
                  (e.value as Map).cast<String, dynamic>(),
                ),
          };
        }
      } catch (_) {
        _sessions = {};
      }
    }
    _loaded = true;
  }

  StorySession? get(String storyId) => _sessions[storyId];

  Future<void> put(String storyId, StorySession session) async {
    await ensureLoaded();
    _sessions[storyId] = session;
    await _save();
    notifyListeners();
  }

  Future<void> clear(String storyId) async {
    await ensureLoaded();
    _sessions.remove(storyId);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode({
        for (final e in _sessions.entries) e.key: e.value.toJson(),
      }),
    );
  }
}
