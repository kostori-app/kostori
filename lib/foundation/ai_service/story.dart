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

  static List<Story> builtinStories() => [
    const Story(
      id: 'wasteland_survival',
      name: '废土求生',
      icon: '🏚️',
      description: '在一座废弃检查站中醒来，你没有工具、没有食物，必须活过第一夜。',
      opening: '雨声敲打着金属屋顶。你在一个废弃检查站的角落醒来，浑身湿冷，头痛欲裂。',
      systemPrompt:
          '你是一个硬核生存文字冒险的主持人(GM)。以第二人称叙事，描写真实、克制、有细节；'
          '资源稀缺，死亡是真实威胁。玩家可以自由输入任何行动。',
      worldBook:
          '时代：近未来废土。资源匮乏，变异生物与拾荒者横行。'
          '生存要点：体温、饮水、食物、伤口感染。夜晚危险。',
      choicesPrompt: '给出与当前处境紧密相关、各有利弊的选项，鼓励玩家权衡。',
      initialState: GameState(
        resources: [
          StatBar(name: '生命', cur: 100, max: 100),
          StatBar(name: '精神', cur: 100, max: 100),
          StatBar(name: '体力', cur: 100, max: 100),
          StatBar(name: '进食', cur: 100, max: 100),
        ],
        attributes: {'力量': 5, '敏捷': 5, '智力': 5, '魅力': 5},
        inventory: ['破旧外套 x1'],
        time: '第1天 清晨',
        location: '北境针叶林 · 废弃检查站',
      ),
    ),
    const Story(
      id: 'xianxia_cultivation',
      name: '仙途问道',
      icon: '⚔️',
      description: '你是一个刚入门的练气修士，机缘与危机并存。',
      opening: '晨钟响过三声，你自蒲团上睁开眼。今日是外门大比的第一天。',
      systemPrompt: '你是一个东方修仙文字冒险的主持人(GM)。文风古朴，注重境界、法宝、人情世故与因果。',
      worldBook: '境界：练气、筑基、金丹、元婴…… 灵气分金木水火土五行。',
      choicesPrompt: '选项应体现修仙世界的取舍：稳妥修炼、冒险寻宝、结交同门或树敌。',
      initialState: GameState(
        resources: [
          StatBar(name: '气血', cur: 100, max: 100),
          StatBar(name: '灵力', cur: 50, max: 100),
        ],
        attributes: {'根骨': 5, '悟性': 5, '身法': 5},
        skills: ['吐纳术 Lv1'],
        inventory: ['下品灵石 x3'],
        time: '入门第1日',
        location: '青云宗 · 外门',
      ),
    ),
  ];

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
    var changed = false;
    for (final b in builtinStories()) {
      if (!_stories.any((s) => s.id == b.id)) {
        _stories.insert(0, b);
        changed = true;
      }
    }
    if (changed) await _save();
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
    return Story(
      id: id ?? 'story_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      opening: _section(text, '开局') ?? '',
      systemPrompt: _section(text, '系统提示词') ?? '',
      worldBook: _section(text, '世界书') ?? '',
      choicesPrompt: _section(text, '后续建议提示词') ?? '',
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
