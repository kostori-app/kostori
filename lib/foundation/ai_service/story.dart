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

/// 游戏状态：AI 每回合输出的结构化数值
class GameState {
  final List<StatBar> resources;
  final Map<String, int> attributes;
  final List<String> skills;
  final List<String> inventory;
  final List<QuestItem> quests;
  final String time;
  final String location;

  const GameState({
    this.resources = const [],
    this.attributes = const {},
    this.skills = const [],
    this.inventory = const [],
    this.quests = const [],
    this.time = '',
    this.location = '',
  });

  static const empty = GameState();

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
  };
}

/// 开局档案的一个设置项（类似 DnD 捏人）：单选 / 多选 / 自填文本
class StorySetupPart {
  final String key;
  final String title;

  /// single（单选） | multi（多选） | text（自填）
  final String type;

  final List<String> options;
  final bool required;
  final String hint;

  const StorySetupPart({
    required this.key,
    required this.title,
    this.type = 'single',
    this.options = const [],
    this.required = false,
    this.hint = '',
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
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'type': type,
    'options': options,
    'required': required,
    'hint': hint,
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
    "location": "地点"
  },
  "choices": ["选项A", "选项B", "选项C"]
}
```
规则：state 需给出当前完整状态；choices 提供 3-5 个可供玩家选择的行动。''');
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
    return Story(
      id: id ?? 'story_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      opening: _section(text, '开局') ?? '',
      systemPrompt: _section(text, '系统提示词') ?? '',
      worldBook: _section(text, '世界书') ?? '',
      choicesPrompt: _section(text, '后续建议提示词') ?? '',
      setup: setup,
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
    section('后续建议提示词', s.choicesPrompt);
    if (s.setup.isNotEmpty) {
      section('开局设置', jsonEncode([for (final p in s.setup) p.toJson()]));
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
