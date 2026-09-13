// AI 冒险（AI 扮演）核心数据：
// 故事（Story）= 整合好的世界书 + 设定 + 提示词 + 开局引导 + 后续建议提示词；
// 游戏状态（GameState）= AI 每回合输出的结构化数值，用于状态面板展示。
// 支持 .md 导入/导出。

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
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

  /// 任务链：所属链名（空 = 独立任务）
  final String chain;

  /// 当前阶段 / 总阶段（0 表示不分阶段）
  final int stage;
  final int totalStages;

  /// active | done | failed
  final String status;

  const QuestItem({
    required this.title,
    this.desc = '',
    this.progress = 0,
    this.chain = '',
    this.stage = 0,
    this.totalStages = 0,
    this.status = 'active',
  });

  factory QuestItem.fromJson(dynamic v) {
    if (v is Map) {
      return QuestItem(
        title: v['title']?.toString() ?? '',
        desc: v['desc']?.toString() ?? '',
        progress: (v['progress'] as num?)?.toInt() ?? 0,
        chain: v['chain']?.toString() ?? '',
        stage: (v['stage'] as num?)?.toInt() ?? 0,
        totalStages: (v['totalStages'] as num?)?.toInt() ?? 0,
        status: normalizeStatus(v['status']),
      );
    }
    return QuestItem(title: v.toString());
  }

  /// 归一化模型输出的状态写法（done/completed/已完成… → done）
  static String normalizeStatus(Object? v) {
    final s = v?.toString().trim().toLowerCase() ?? '';
    const done = {
      'done',
      'completed',
      'complete',
      'finished',
      'success',
      '已完成',
      '完成',
      '已结束',
      '成功',
    };
    const failed = {
      'failed',
      'fail',
      'failure',
      '已失败',
      '失败',
    };
    if (done.contains(s)) return 'done';
    if (failed.contains(s)) return 'failed';
    return 'active';
  }

  /// 进度条占比：已完成 → 满；分阶段 → stage/totalStages；否则 progress/100
  double get progressFraction {
    if (status == 'done') return 1;
    if (totalStages > 0) return (stage / totalStages).clamp(0.0, 1.0);
    return (progress / 100).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'desc': desc,
    'progress': progress,
    if (chain.isNotEmpty) 'chain': chain,
    if (stage > 0) 'stage': stage,
    if (totalStages > 0) 'totalStages': totalStages,
    if (status != 'active') 'status': status,
  };
}

/// 战斗单位（敌人 / 同伴）
class Combatant {
  final String name;
  final int hp;
  final int maxHp;
  final String note;

  const Combatant({
    required this.name,
    this.hp = 0,
    this.maxHp = 0,
    this.note = '',
  });

  factory Combatant.fromJson(dynamic v) {
    if (v is Map) {
      return Combatant(
        name: v['name']?.toString() ?? '',
        hp: (v['hp'] as num?)?.toInt() ?? 0,
        maxHp: (v['maxHp'] as num?)?.toInt() ?? 0,
        note: v['note']?.toString() ?? '',
      );
    }
    return Combatant(name: v.toString());
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'hp': hp,
    'maxHp': maxHp,
    if (note.isNotEmpty) 'note': note,
  };
}

/// 战斗状态（简单回合制）
class CombatState {
  final bool active;
  final int round;
  final List<Combatant> enemies;
  final String note;

  const CombatState({
    this.active = false,
    this.round = 1,
    this.enemies = const [],
    this.note = '',
  });

  static const idle = CombatState();

  factory CombatState.fromJson(Map<String, dynamic> json) => CombatState(
    active: json['active'] as bool? ?? false,
    round: (json['round'] as num?)?.toInt() ?? 1,
    enemies: [
      for (final e in (json['enemies'] as List? ?? const []))
        Combatant.fromJson(e),
    ],
    note: json['note']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'active': active,
    'round': round,
    'enemies': [for (final e in enemies) e.toJson()],
    if (note.isNotEmpty) 'note': note,
  };
}

/// 故事成就定义
class StoryAchievement {
  final String key;
  final String name;
  final String description;

  const StoryAchievement({
    required this.key,
    required this.name,
    this.description = '',
  });

  factory StoryAchievement.fromJson(Map<String, dynamic> json) =>
      StoryAchievement(
        key: json['key']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'description': description,
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

/// 故事变量：AI 可读写，并可在提示词里用 {{var:名称}} 引用
class StoryVariable {
  final String name;
  final String value;
  final String description;

  /// number | text | enum
  final String type;

  /// 数值范围（type=number）
  final int? min;
  final int? max;
  final String unit;

  /// 枚举可选值（type=enum）
  final List<String> options;

  const StoryVariable({
    required this.name,
    this.value = '',
    this.description = '',
    this.type = 'text',
    this.min,
    this.max,
    this.unit = '',
    this.options = const [],
  });

  factory StoryVariable.fromJson(Map<String, dynamic> json) => StoryVariable(
    name: json['name']?.toString() ?? '',
    value: json['value']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    type: json['type']?.toString() ?? 'text',
    min: (json['min'] as num?)?.toInt(),
    max: (json['max'] as num?)?.toInt(),
    unit: json['unit']?.toString() ?? '',
    options: (json['options'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'description': description,
    'type': type,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (unit.isNotEmpty) 'unit': unit,
    if (options.isNotEmpty) 'options': options,
  };

  /// 按声明约束归一化单个值
  String normalize(String raw) {
    switch (type) {
      case 'number':
        final n = int.tryParse(raw.replaceAll(RegExp(r'[^0-9\-]'), ''));
        if (n == null) return value;
        var v = n;
        if (min != null && v < min!) v = min!;
        if (max != null && v > max!) v = max!;
        return '$v';
      case 'enum':
        if (options.isEmpty) return raw;
        if (options.contains(raw)) return raw;
        for (final o in options) {
          if (raw.contains(o)) return o;
        }
        return options.first;
      default:
        return raw;
    }
  }
}

/// 按变量声明约束归一化整份变量表
Map<String, String> normalizeVariables(
  Map<String, String> values,
  List<StoryVariable> declared,
) {
  if (declared.isEmpty) return values;
  final byName = {for (final v in declared) v.name: v};
  return {
    for (final e in values.entries)
      e.key: byName[e.key]?.normalize(e.value) ?? e.value,
  };
}

/// 变量增量：set 直接赋值，delta 数值增减（事件溯源用）
class VarOp {
  final String name;
  final String? set;
  final int? delta;

  const VarOp({required this.name, this.set, this.delta});

  factory VarOp.fromJson(dynamic v) {
    if (v is! Map) return VarOp(name: v.toString());
    final name = (v['name'] ?? v['key'] ?? '').toString();
    final set = v['set'] ?? v['value'];
    return VarOp(
      name: name,
      set: set?.toString(),
      delta: (v['delta'] as num?)?.toInt(),
    );
  }
}

/// 把变量增量叠加到现有变量表
Map<String, String> applyVarOps(
  Map<String, String> vars,
  List<VarOp> ops,
) {
  final out = Map<String, String>.from(vars);
  for (final op in ops) {
    if (op.name.trim().isEmpty) continue;
    if (op.set != null) {
      out[op.name] = op.set!;
      continue;
    }
    if (op.delta != null) {
      final cur = int.tryParse(out[op.name] ?? '') ?? 0;
      out[op.name] = '${cur + op.delta!}';
    }
  }
  return out;
}

/// 正则替换规则：按阶段生效 + 可限定消息深度窗口
class StoryRegex {
  final String name;
  final String pattern;
  final String replacement;
  final bool enabled;

  /// 生效阶段：display（AI 输出显示）| send（用户输入发送前）| both
  final String phase;
  final bool caseSensitive;
  final bool multiLine;

  /// 深度窗口（相对最新消息的距离，0 表示不限）
  final int minDepth;
  final int maxDepth;

  const StoryRegex({
    required this.name,
    required this.pattern,
    this.replacement = '',
    this.enabled = true,
    this.phase = 'display',
    this.caseSensitive = true,
    this.multiLine = false,
    this.minDepth = 0,
    this.maxDepth = 0,
  });

  static String _phaseOf(Object? phase, Object? legacyTarget) {
    final p = phase?.toString();
    if (p == 'display' || p == 'send' || p == 'both') return p!;
    return switch (legacyTarget?.toString()) {
      'user' => 'send',
      'both' => 'both',
      _ => 'display',
    };
  }

  factory StoryRegex.fromJson(Map<String, dynamic> json) => StoryRegex(
    name: json['name']?.toString() ?? '',
    pattern: json['pattern']?.toString() ?? '',
    replacement: json['replacement']?.toString() ?? '',
    enabled: json['enabled'] as bool? ?? true,
    phase: _phaseOf(json['phase'], json['target']),
    caseSensitive: json['caseSensitive'] as bool? ?? true,
    multiLine: json['multiLine'] as bool? ?? false,
    minDepth: (json['minDepth'] as num?)?.toInt() ?? 0,
    maxDepth: (json['maxDepth'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'pattern': pattern,
    'replacement': replacement,
    'enabled': enabled,
    'phase': phase,
    'caseSensitive': caseSensitive,
    'multiLine': multiLine,
    'minDepth': minDepth,
    'maxDepth': maxDepth,
  };
}

/// 用变量值替换 {{var:名称}}（未定义时原样保留）
String replaceStoryVars(String text, Map<String, String> vars) {
  if (vars.isEmpty || !text.contains('{{')) return text;
  return text.replaceAllMapped(
    RegExp(r'\{\{\s*var:\s*([^}]+?)\s*\}\}'),
    (m) {
      final key = m.group(1)!.trim();
      return vars.containsKey(key) ? vars[key]! : m.group(0)!;
    },
  );
}

/// 按阶段对文本做正则替换；[depth] 为相对最新消息的距离（-1 表示未知，跳过深度过滤）
String applyStoryRegex(
  String text,
  List<StoryRegex> rules,
  String phase, {
  int depth = -1,
}) {
  var result = text;
  for (final r in rules) {
    if (!r.enabled || r.pattern.isEmpty) continue;
    if (r.phase != 'both' && r.phase != phase) continue;
    if (depth >= 0) {
      if (r.minDepth > 0 && depth < r.minDepth) continue;
      if (r.maxDepth > 0 && depth > r.maxDepth) continue;
    }
    try {
      final re = RegExp(
        r.pattern,
        caseSensitive: r.caseSensitive,
        multiLine: r.multiLine,
      );
      result = result.replaceAll(re, r.replacement);
    } catch (_) {
      // 非法正则忽略
    }
  }
  return result;
}

/// 叙事片段：旁白 / 角色（用于消息分区渲染）
class StorySegment {
  /// narration | npc
  final String type;
  final String name;
  final String text;

  const StorySegment({
    required this.type,
    this.name = '',
    required this.text,
  });
}

/// 玩家 persona（用户本人）：仅描述"你是谁"，AI 不得扮演
class StoryPersona {
  final String name;
  final String avatar;
  final String description;

  const StoryPersona({
    this.name = '',
    this.avatar = '🧑',
    this.description = '',
  });

  bool get isEmpty =>
      name.trim().isEmpty && description.trim().isEmpty;

  factory StoryPersona.fromJson(Map<String, dynamic> json) => StoryPersona(
    name: json['name']?.toString() ?? '',
    avatar: json['avatar']?.toString() ?? '🧑',
    description: json['description']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatar': avatar,
    'description': description,
  };
}

/// 面板分区：由故事自定义（标题 / 数据源 / 图标），空则用默认分区
class StoryPanel {
  final String title;

  /// resources | attributes | skills | inventory | quests | codex
  final String source;

  /// source=codex 时按 kind 过滤（空 = 全部）
  final String kind;
  final String icon;

  const StoryPanel({
    this.title = '',
    this.source = 'attributes',
    this.kind = '',
    this.icon = '',
  });

  factory StoryPanel.fromJson(Map<String, dynamic> json) => StoryPanel(
    title: json['title']?.toString() ?? '',
    source: json['source']?.toString() ?? 'attributes',
    kind: json['kind']?.toString() ?? '',
    icon: json['icon']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'source': source,
    if (kind.isNotEmpty) 'kind': kind,
    if (icon.isNotEmpty) 'icon': icon,
  };
}

/// 检定请求：由 AI 声明、项目负责掷骰（避免模型自编点数）
class StoryCheck {
  final String label;

  /// 骰子记法，如 1d20 / 2d6
  final String dice;
  final int modifier;
  final int? dc;
  final String reason;

  const StoryCheck({
    required this.label,
    this.dice = '1d20',
    this.modifier = 0,
    this.dc,
    this.reason = '',
  });

  factory StoryCheck.fromJson(Map<String, dynamic> json) => StoryCheck(
    label: (json['label'] ?? json['skill'] ?? json['name'] ?? '').toString(),
    dice: json['dice']?.toString() ?? '1d20',
    modifier: (json['modifier'] as num?)?.toInt() ?? 0,
    dc: (json['dc'] as num?)?.toInt(),
    reason: json['reason']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'dice': dice,
    'modifier': modifier,
    if (dc != null) 'dc': dc,
    'reason': reason,
  };

  /// 展示用记法：1d20+3 vs DC 12
  String get notation {
    final mod = modifier > 0
        ? '+$modifier'
        : modifier < 0
        ? '$modifier'
        : '';
    return '$dice$mod${dc != null ? ' vs DC $dc' : ''}';
  }
}

/// 掷骰结果
class DiceRoll {
  final String notation;
  final List<int> dice;
  final int sides;
  final int modifier;
  final int total;
  final int? dc;
  final bool? success;

  const DiceRoll({
    required this.notation,
    required this.dice,
    required this.sides,
    required this.modifier,
    required this.total,
    this.dc,
    this.success,
  });

  /// 明细：1d20(15) + 3 = 18 ≥ 12 → 成功
  String get detail {
    final buf = StringBuffer(notation.split(' ').first);
    buf.write('(${dice.join(', ')})');
    if (modifier > 0) {
      buf.write(' + $modifier');
    } else if (modifier < 0) {
      buf.write(' - ${-modifier}');
    }
    buf.write(' = $total');
    if (dc != null) {
      buf.write(' ${success == true ? '≥' : '<'} $dc');
      buf.write(' → ${success == true ? t.diceSuccess : t.diceFailure}');
    }
    return buf.toString();
  }
}

/// 解析并掷骰（记法形如 NdM；不合法时回退为 1d20）
DiceRoll rollDice(String notation, {int modifier = 0, int? dc}) {
  final m = RegExp(r'(\d*)\s*[dD]\s*(\d+)').firstMatch(notation);
  final count = (m == null ? 1 : (int.tryParse(m.group(1) ?? '') ?? 1)).clamp(1, 100);
  final sides = (m == null ? 20 : (int.tryParse(m.group(2) ?? '') ?? 20)).clamp(2, 1000);
  final rng = math.Random();
  final dice = [for (var i = 0; i < count; i++) 1 + rng.nextInt(sides)];
  final total = dice.fold(0, (a, b) => a + b) + modifier;
  return DiceRoll(
    notation: notation,
    dice: dice,
    sides: sides,
    modifier: modifier,
    total: total,
    dc: dc,
    success: dc == null ? null : total >= dc,
  );
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

/// 在场角色的运行状态（数值条 / 属性 / 技能 / 携带 / 好感度 / 姿态）
class NpcState {
  final String name;
  final List<StatBar> resources;
  final Map<String, int> attributes;
  final List<String> skills;
  final List<String> inventory;

  /// 好感度（对玩家的态度）
  final int affinity;

  /// 姿态 / 当前状态描述
  final String status;

  const NpcState({
    required this.name,
    this.resources = const [],
    this.attributes = const {},
    this.skills = const [],
    this.inventory = const [],
    this.affinity = 0,
    this.status = '',
  });

  NpcState copyWith({
    String? name,
    List<StatBar>? resources,
    Map<String, int>? attributes,
    List<String>? skills,
    List<String>? inventory,
    int? affinity,
    String? status,
  }) => NpcState(
    name: name ?? this.name,
    resources: resources ?? this.resources,
    attributes: attributes ?? this.attributes,
    skills: skills ?? this.skills,
    inventory: inventory ?? this.inventory,
    affinity: affinity ?? this.affinity,
    status: status ?? this.status,
  );

  factory NpcState.fromJson(Map<String, dynamic> json) {
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
        if (e.value is num) {
          attributes[e.key.toString()] = (e.value as num).toInt();
        }
      }
    }
    return NpcState(
      name: json['name']?.toString() ?? '',
      resources: resources,
      attributes: attributes,
      skills:
          (json['skills'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      inventory:
          (json['inventory'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      affinity: (json['affinity'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (resources.isNotEmpty)
      'resources': {for (final r in resources) r.name: r.toJson()},
    if (attributes.isNotEmpty) 'attributes': attributes,
    if (skills.isNotEmpty) 'skills': skills,
    if (inventory.isNotEmpty) 'inventory': inventory,
    'affinity': affinity,
    if (status.isNotEmpty) 'status': status,
  };
}

/// 称号定义（故事设定）：可叠加，带 buff/debuff 效果
class StoryTitle {
  final String key;
  final String name;
  final String description;

  /// 效果文本（如「力量 +2；命中 +10%」），GM 判定时参考
  final String effects;

  /// 是否可叠加（同称号可叠层，效果按层数放大）
  final bool stackable;

  const StoryTitle({
    required this.key,
    required this.name,
    this.description = '',
    this.effects = '',
    this.stackable = false,
  });

  factory StoryTitle.fromJson(Map<String, dynamic> json) => StoryTitle(
    key: json['key']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    effects: json['effects']?.toString() ?? '',
    stackable: json['stackable'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'description': description,
    'effects': effects,
    'stackable': stackable,
  };
}

/// 职业等级定义
class StoryJobLevel {
  final int level;
  final String name;
  final String bonus;

  const StoryJobLevel({required this.level, this.name = '', this.bonus = ''});

  factory StoryJobLevel.fromJson(Map<String, dynamic> json) => StoryJobLevel(
    level: (json['level'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    bonus: json['bonus']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'level': level,
    'name': name,
    'bonus': bonus,
  };
}

/// 职业定义（故事设定，可选）
class StoryJob {
  final String name;
  final String description;
  final List<StoryJobLevel> levels;

  const StoryJob({
    this.name = '',
    this.description = '',
    this.levels = const [],
  });

  bool get isEmpty => name.trim().isEmpty && levels.isEmpty;

  factory StoryJob.fromJson(Map<String, dynamic> json) => StoryJob(
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    levels: (json['levels'] is List)
        ? [
            for (final e in json['levels'] as List)
              if (e is Map) StoryJobLevel.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'levels': [for (final l in levels) l.toJson()],
  };
}

/// 据点设施定义（故事设定，可选）
class StoryFacility {
  final String key;
  final String name;
  final String description;
  final int maxLevel;

  const StoryFacility({
    required this.key,
    required this.name,
    this.description = '',
    this.maxLevel = 1,
  });

  factory StoryFacility.fromJson(Map<String, dynamic> json) => StoryFacility(
    key: json['key']?.toString() ?? json['name']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    maxLevel:
        (json['maxLevel'] as num?)?.toInt() ??
        (json['max_level'] as num?)?.toInt() ??
        1,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'description': description,
    'maxLevel': maxLevel,
  };
}

/// 已获得称号（运行状态）
class TitleState {
  final String key;
  final int stacks;
  final bool equipped;

  const TitleState({
    required this.key,
    this.stacks = 1,
    this.equipped = false,
  });

  TitleState copyWith({int? stacks, bool? equipped}) => TitleState(
    key: key,
    stacks: stacks ?? this.stacks,
    equipped: equipped ?? this.equipped,
  );

  factory TitleState.fromJson(Map<String, dynamic> json) => TitleState(
    key: json['key']?.toString() ?? json['name']?.toString() ?? '',
    stacks: (json['stacks'] as num?)?.toInt() ?? 1,
    equipped: json['equipped'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'stacks': stacks,
    if (equipped) 'equipped': true,
  };
}

/// 状态效果 / 加成（运行状态）：buff / debuff，可叠层、有时限
class EffectState {
  final String name;

  /// buff | debuff
  final String kind;
  final int stacks;

  /// 剩余回合（0 = 永久 / 直到移除）
  final int remaining;
  final String description;

  const EffectState({
    required this.name,
    this.kind = 'buff',
    this.stacks = 1,
    this.remaining = 0,
    this.description = '',
  });

  factory EffectState.fromJson(Map<String, dynamic> json) => EffectState(
    name: json['name']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'buff',
    stacks: (json['stacks'] as num?)?.toInt() ?? 1,
    remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    description: json['description']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'stacks': stacks,
    'remaining': remaining,
    if (description.isNotEmpty) 'description': description,
  };
}

/// 职业 / 等级（运行状态）
class JobState {
  final String name;
  final int level;
  final int exp;

  const JobState({this.name = '', this.level = 1, this.exp = 0});

  bool get isEmpty => name.trim().isEmpty;

  factory JobState.fromJson(Map<String, dynamic> json) => JobState(
    name: json['name']?.toString() ?? '',
    level: (json['level'] as num?)?.toInt() ?? 1,
    exp: (json['exp'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'level': level,
    'exp': exp,
  };
}

/// 据点设施（运行状态）
class FacilityState {
  final String key;
  final int level;
  final String status;

  const FacilityState({required this.key, this.level = 0, this.status = ''});

  factory FacilityState.fromJson(Map<String, dynamic> json) => FacilityState(
    key: json['key']?.toString() ?? json['name']?.toString() ?? '',
    level: (json['level'] as num?)?.toInt() ?? 0,
    status: json['status']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'level': level,
    if (status.isNotEmpty) 'status': status,
  };
}

/// 据点（运行状态）：设施 + 物质 + 仓储储备
class BaseState {
  final List<FacilityState> facilities;
  final Map<String, int> materials;
  final Map<String, int> storage;

  const BaseState({
    this.facilities = const [],
    this.materials = const {},
    this.storage = const {},
  });

  bool get isEmpty =>
      facilities.isEmpty && materials.isEmpty && storage.isEmpty;

  static Map<String, int> _intMap(dynamic v) {
    final out = <String, int>{};
    if (v is Map) {
      for (final e in v.entries) {
        final value = e.value;
        out[e.key.toString()] = value is num
            ? value.toInt()
            : (int.tryParse(value?.toString() ?? '') ?? 0);
      }
    }
    return out;
  }

  factory BaseState.fromJson(Map<String, dynamic> json) => BaseState(
    facilities: (json['facilities'] is List)
        ? [
            for (final e in json['facilities'] as List)
              if (e is Map) FacilityState.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    materials: _intMap(json['materials']),
    storage: _intMap(json['storage']),
  );

  Map<String, dynamic> toJson() => {
    if (facilities.isNotEmpty)
      'facilities': [for (final f in facilities) f.toJson()],
    if (materials.isNotEmpty) 'materials': materials,
    if (storage.isNotEmpty) 'storage': storage,
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

  /// 是否已游戏结束（致命资源归零）
  final bool gameOver;

  /// 故事变量（AI 可读写，提示词里可用 {{var:名称}} 引用）
  final Map<String, String> variables;

  /// 当前在场的角色名（多角色同场）
  final List<String> present;

  /// 在场角色的运行状态（血量 / 好感度等）
  final List<NpcState> npcs;

  /// 已获得称号（含叠加层数）
  final List<TitleState> titles;

  /// 当前状态效果 / 加成（buff / debuff）
  final List<EffectState> effects;

  /// 职业 / 等级
  final JobState job;

  /// 据点（设施 / 物质 / 仓储）
  final BaseState base;

  /// 已装备的物品名（其 codex 机制生效）
  final List<String> equipped;

  /// 战斗状态
  final CombatState combat;

  /// 已解锁的成就 key
  final List<String> achievements;

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
    this.gameOver = false,
    this.variables = const {},
    this.present = const [],
    this.npcs = const [],
    this.titles = const [],
    this.effects = const [],
    this.job = const JobState(),
    this.base = const BaseState(),
    this.equipped = const [],
    this.combat = CombatState.idle,
    this.achievements = const [],
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
    bool? gameOver,
    Map<String, String>? variables,
    List<String>? present,
    List<NpcState>? npcs,
    List<TitleState>? titles,
    List<EffectState>? effects,
    JobState? job,
    BaseState? base,
    List<String>? equipped,
    CombatState? combat,
    List<String>? achievements,
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
    gameOver: gameOver ?? this.gameOver,
    variables: variables ?? this.variables,
    present: present ?? this.present,
    npcs: npcs ?? this.npcs,
    titles: titles ?? this.titles,
    effects: effects ?? this.effects,
    job: job ?? this.job,
    base: base ?? this.base,
    equipped: equipped ?? this.equipped,
    combat: combat ?? this.combat,
    achievements: achievements ?? this.achievements,
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
    // 过滤模型偶尔塞进清单的“整句”（如「修lepink取得…。」），只保留条目名
    List<String> strs(dynamic v) {
      if (v is! List) return const [];
      final out = <String>[];
      for (final e in v) {
        final s = e.toString().trim();
        if (s.isEmpty || s.length > 30) continue;
        if (RegExp(r'[。！？；，：]').hasMatch(s)) continue;
        out.add(s);
      }
      return out;
    }

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
      gameOver: json['gameOver'] as bool? ?? false,
      variables: json['variables'] is Map
          ? {
              for (final e in (json['variables'] as Map).entries)
                e.key.toString(): e.value?.toString() ?? '',
            }
          : const {},
      present: (json['present'] as List?)?.whereType<String>().toList() ?? const [],
      npcs: (json['npcs'] is List)
          ? [
              for (final e in json['npcs'] as List)
                if (e is Map)
                  NpcState.fromJson(e.cast<String, dynamic>()),
            ]
          : const [],
      titles: (json['titles'] is List)
          ? [
              for (final e in json['titles'] as List)
                if (e is Map) TitleState.fromJson(e.cast<String, dynamic>()),
            ]
          : const [],
      effects: (json['effects'] is List)
          ? [
              for (final e in json['effects'] as List)
                if (e is Map) EffectState.fromJson(e.cast<String, dynamic>()),
            ]
          : const [],
      job: json['job'] is Map
          ? JobState.fromJson((json['job'] as Map).cast<String, dynamic>())
          : const JobState(),
      base: json['base'] is Map
          ? BaseState.fromJson((json['base'] as Map).cast<String, dynamic>())
          : const BaseState(),
      equipped: strs(json['equipped']),
      combat: json['combat'] is Map
          ? CombatState.fromJson((json['combat'] as Map).cast<String, dynamic>())
          : CombatState.idle,
      achievements:
          (json['achievements'] as List?)?.whereType<String>().toList() ??
          const [],
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
    'gameOver': gameOver,
    'variables': variables,
    'present': present,
    if (npcs.isNotEmpty) 'npcs': [for (final n in npcs) n.toJson()],
    if (titles.isNotEmpty) 'titles': [for (final x in titles) x.toJson()],
    if (effects.isNotEmpty) 'effects': [for (final x in effects) x.toJson()],
    if (!job.isEmpty) 'job': job.toJson(),
    if (!base.isEmpty) 'base': base.toJson(),
    'equipped': equipped,
    'combat': combat.toJson(),
    'achievements': achievements,
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

  /// 稳定标识（作者定义，如 `## 标识`）：导入时用它判断是否同一个故事，
  /// 避免不同故事重名被误判为"更新"。
  final String key;
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

  /// 从设定库（词条/称号/职业/据点）中选择的条目 id
  final List<String> settingIds;

  /// 自定义面板分区（为空表示使用默认分区）
  final List<StoryPanel> panels;

  /// 致命资源：这些资源归零即游戏结束（为空则不判定）
  final List<String> deathResources;

  /// 致命资源判定方式：
  /// any = 任意一个归零即结束（单个/多个任一）；all = 全部归零才结束
  final String deathMode;

  /// 故事角色（多角色同场，复用角色卡模型）
  final List<CharacterCard> characters;

  /// 故事变量声明（初值与说明）
  final List<StoryVariable> variables;

  /// 正则替换规则（对 AI 输出 / 用户输入后处理）
  final List<StoryRegex> regexes;

  /// 成就定义（AI 解锁）
  final List<StoryAchievement> achievements;

  /// 预置词条定义（物品/特质/种族/技能/天赋/身体），开局即已知
  final List<StoryDefinition> codex;

  /// 称号定义（AI 授予）
  final List<StoryTitle> titles;

  /// 称号生效方式：all（全部生效） | equipped（仅佩戴的生效）
  final String titleMode;

  /// 职业 / 等级定义（可选）
  final StoryJob? job;

  /// 据点设施定义（可选）
  final List<StoryFacility> facilities;

  /// 生成参数（可空表示跟随服务商默认值）
  final double? temperature;
  final double? topP;
  final int? maxTokens;

  /// 玩家 persona（用户本人，AI 不扮演）
  final StoryPersona persona;

  /// 默认面板分区（详情面板未自定义时使用）
  static const defaultPanels = <StoryPanel>[
    StoryPanel(source: 'resources'),
    StoryPanel(source: 'attributes'),
    StoryPanel(source: 'skills'),
    StoryPanel(source: 'inventory'),
    StoryPanel(source: 'quests'),
    StoryPanel(source: 'effects'),
    StoryPanel(source: 'titles'),
    StoryPanel(source: 'job'),
    StoryPanel(source: 'base'),
    StoryPanel(source: 'codex'),
  ];

  final GameState initialState;
  final bool isBuiltin;

  const Story({
    required this.id,
    this.key = '',
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
    this.settingIds = const [],
    this.panels = const [],
    this.deathResources = const [],
    this.deathMode = 'any',
    this.characters = const [],
    this.variables = const [],
    this.regexes = const [],
    this.achievements = const [],
    this.codex = const [],
    this.titles = const [],
    this.titleMode = 'all',
    this.job,
    this.facilities = const [],
    this.temperature,
    this.topP,
    this.maxTokens,
    this.persona = const StoryPersona(),
    this.initialState = GameState.empty,
    this.isBuiltin = false,
  });

  Story copyWith({
    String? id,
    String? key,
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
    List<String>? settingIds,
    List<StoryPanel>? panels,
    List<String>? deathResources,
    String? deathMode,
    List<CharacterCard>? characters,
    List<StoryVariable>? variables,
    List<StoryRegex>? regexes,
    List<StoryAchievement>? achievements,
    List<StoryDefinition>? codex,
    List<StoryTitle>? titles,
    String? titleMode,
    StoryJob? job,
    List<StoryFacility>? facilities,
    double? temperature,
    double? topP,
    int? maxTokens,
    StoryPersona? persona,
    GameState? initialState,
  }) => Story(
    id: id ?? this.id,
    key: key ?? this.key,
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
    settingIds: settingIds ?? this.settingIds,
    panels: panels ?? this.panels,
    deathResources: deathResources ?? this.deathResources,
    deathMode: deathMode ?? this.deathMode,
    characters: characters ?? this.characters,
    variables: variables ?? this.variables,
    regexes: regexes ?? this.regexes,
    achievements: achievements ?? this.achievements,
    codex: codex ?? this.codex,
    titles: titles ?? this.titles,
    titleMode: titleMode ?? this.titleMode,
    job: job ?? this.job,
    facilities: facilities ?? this.facilities,
    temperature: temperature ?? this.temperature,
    topP: topP ?? this.topP,
    maxTokens: maxTokens ?? this.maxTokens,
    persona: persona ?? this.persona,
    initialState: initialState ?? this.initialState,
    isBuiltin: isBuiltin,
  );

  factory Story.fromJson(Map<String, dynamic> json) => Story(
    id: (json['id'] as String?) ?? 'story_${DateTime.now().millisecondsSinceEpoch}',
    key: (json['key'] as String?) ?? '',
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
    settingIds: (json['settingIds'] as List?)?.whereType<String>().toList() ??
        const [],
    panels: json['panels'] is List
        ? [
            for (final e in json['panels'] as List)
              if (e is Map) StoryPanel.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    deathResources:
        (json['deathResources'] as List?)?.whereType<String>().toList() ??
        const [],
    deathMode: json['deathMode']?.toString() ?? 'any',
    characters: json['characters'] is List
        ? [
            for (final e in json['characters'] as List)
              if (e is Map) CharacterCard.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    variables: json['variables'] is List
        ? [
            for (final e in json['variables'] as List)
              if (e is Map) StoryVariable.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    regexes: json['regexes'] is List
        ? [
            for (final e in json['regexes'] as List)
              if (e is Map) StoryRegex.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    achievements: json['achievements'] is List
        ? [
            for (final e in json['achievements'] as List)
              if (e is Map) StoryAchievement.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    codex: json['codex'] is List
        ? [
            for (final e in json['codex'] as List)
              if (e is Map) StoryDefinition.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    titles: json['titles'] is List
        ? [
            for (final e in json['titles'] as List)
              if (e is Map) StoryTitle.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    titleMode: json['titleMode']?.toString() ?? 'all',
    job: json['job'] is Map
        ? StoryJob.fromJson((json['job'] as Map).cast<String, dynamic>())
        : null,
    facilities: json['facilities'] is List
        ? [
            for (final e in json['facilities'] as List)
              if (e is Map) StoryFacility.fromJson(e.cast<String, dynamic>()),
          ]
        : const [],
    temperature: (json['temperature'] as num?)?.toDouble(),
    topP: (json['topP'] as num?)?.toDouble(),
    maxTokens: (json['maxTokens'] as num?)?.toInt(),
    persona: json['persona'] is Map
        ? StoryPersona.fromJson((json['persona'] as Map).cast<String, dynamic>())
        : const StoryPersona(),
    initialState: json['initialState'] is Map
        ? GameState.fromJson((json['initialState'] as Map).cast<String, dynamic>())
        : GameState.empty,
    isBuiltin: (json['isBuiltin'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
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
    'settingIds': settingIds,
    'panels': [for (final p in panels) p.toJson()],
    'deathResources': deathResources,
    'deathMode': deathMode,
    'characters': [for (final c in characters) c.toJson()],
    'variables': [for (final v in variables) v.toJson()],
    'regexes': [for (final r in regexes) r.toJson()],
    'achievements': [for (final a in achievements) a.toJson()],
    'codex': [for (final d in codex) d.toJson()],
    'titles': [for (final x in titles) x.toJson()],
    'titleMode': titleMode,
    if (job != null) 'job': job!.toJson(),
    'facilities': [for (final f in facilities) f.toJson()],
    if (temperature != null) 'temperature': temperature,
    if (topP != null) 'topP': topP,
    if (maxTokens != null) 'maxTokens': maxTokens,
    'persona': persona.toJson(),
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
    if (titles.isNotEmpty) {
      buf.writeln('【称号（只能授予下列 key，获得时把 key 加入 state.titles）】');
      for (final x in titles) {
        buf.write('- ${x.key}：${x.name}');
        if (x.effects.trim().isNotEmpty) buf.write('（效果：${x.effects.trim()}）');
        if (x.stackable) buf.write('（可叠加）');
        buf.writeln();
      }
      buf.writeln(
        '称号生效方式：${titleMode == 'equipped' ? '仅已佩戴(equipped)的称号生效' : '全部已获得称号叠加生效'}',
      );
      buf.writeln();
    }
    if (codex.isNotEmpty) {
      buf.writeln('【预置词条（已知设定，可直接引用；玩家已拥有则相应出现在 inventory/skills 中）】');
      for (final d in codex) {
        buf.write('- [${d.kind}] ${d.name}');
        final desc = d.mechanics.isNotEmpty ? d.mechanics : d.display;
        if (desc.trim().isNotEmpty) buf.write('：${desc.trim()}');
        buf.writeln();
      }
      buf.writeln();
    }
    final jb = job;
    if (jb != null && !jb.isEmpty) {
      buf.writeln('【职业：${jb.name}】${jb.description}');
      for (final l in jb.levels) {
        buf.writeln('- Lv.${l.level} ${l.name}：${l.bonus}');
      }
      buf.writeln();
    }
    if (facilities.isNotEmpty) {
      buf.writeln('【据点设施（只能使用下列 key）】');
      for (final f in facilities) {
        buf.writeln(
          '- ${f.key}：${f.name}（最高 ${f.maxLevel} 级）'
          '${f.description.trim().isEmpty ? '' : ' ${f.description.trim()}'}',
        );
      }
      buf.writeln();
    }
    // 输出示例按故事实际定义的资源 / 属性生成，避免写死名称误导模型
    final resExample = initialState.resources.isEmpty
        ? '{"资源名": {"cur": 100, "max": 100}}'
        : '{${initialState.resources.map((r) => '"${r.name}": {"cur": ${r.cur}, "max": ${r.max}}').join(', ')}}';
    final attrExample = initialState.attributes.isEmpty
        ? '{"属性名": 5}'
        : '{${initialState.attributes.entries.map((e) => '"${e.key}": ${e.value}').join(', ')}}';
    buf.writeln('''
【输出格式要求】
每次回复必须严格分为两部分：
1. 先以第二人称描写场景、行动结果与对话（叙事正文，可用 Markdown）。
   角色（NPC）的发言与动作请用标记包裹：〖角色：角色名〗该角色的对白与动作〖/角色〗；
   标记之外的正文为旁白，旁白不要加任何标记。多个角色依次用标记分段。
   提示 / 须知 / 系统提醒一类的内容，必须用 Markdown 引用块单独成段（该行以 `> ` 开头），例如：
   > 提示：此处可放系统提示 / 须知 / 环境警告等。
   不要用加粗或普通段落代替引用块；普通旁白不要加 `>`。
2. 正文结束后，另起一行输出一个 JSON 代码块，且只输出这一个代码块，不要添加其它说明：
```json
{
  "state": {
    "resources": $resExample,
    "attributes": $attrExample,
    "skills": ["技能名"],
    "inventory": ["物品 x1"],
    "quests": [{"title": "任务", "desc": "描述", "progress": 0, "chain": "主线", "stage": 1, "totalStages": 3, "status": "active"}],
    "equipped": ["已装备物品名"],
    "combat": {"active": true, "round": 1, "enemies": [{"name": "敌人", "hp": 8, "maxHp": 10, "note": "状态"}]},
    "achievements": ["已解锁成就key"],
    "time": "第1天 08:00",
    "location": "地点",
    "codex": [{"kind":"item|race|trait|talent|skill","key":"唯一键","name":"名称","display":"给玩家看的表面描述","mechanics":"给GM看的机制/数值，后续必须严格遵守"}],
    "situation": "当前局势/所在环境的简述（可选，展示在局势页签）",
    "varOps": [{"name": "变量名", "delta": 5}, {"name": "变量名2", "set": "取值"}],
    "present": ["在场角色名"],
    "npcs": [{"name":"角色名","resources":{"资源名":{"cur":100,"max":100}},"attributes":{"属性名":5},"skills":["技能"],"inventory":["物品 x1"],"affinity":0,"status":"姿态/状态"}],
    "titles": [{"key":"称号key","stacks":1,"equipped":true}],
    "effects": [{"name":"状态名","kind":"buff|debuff","stacks":1,"remaining":3,"description":"效果"}],
    "job": {"name":"职业名","level":1,"exp":0},
    "base": {"facilities":[{"key":"设施key","level":1,"status":""}],"materials":{"物质名":10},"storage":{"储备名":5}}
  },
  "events": [{"type":"location|damage|heal|item|quest|dice|info","title":"标题","text":"内容","value":0,"success":true}],
  "choices": ["选项A", "选项B", "选项C"],
  "check": {"label":"检定名","dice":"1d20","modifier":0,"dc":12,"reason":"原因"}
}
```
规则：
- state 需给出当前完整状态；codex 记录出现或已有的道具/种族/特质/天赋等设定，display 面向玩家，mechanics 供你后续严格遵守，避免自相矛盾。
- events 列出本回合的关键事件（进入地区 / 受伤掉血 / 获得道具 / 完成任务等），会单独高亮展示。
- choices 提供 3-5 个可供玩家选择的行动：每条不超过 15 个字，动词开头，只写行动本身，不要解释、后果或括号补充。
- **道具/技能/能力必须登记**：任何新出现的物品、技能或能力，都要在本回合的 codex 里给出对应条目（kind 用 item/skill/race/trait/talent/body），并提供 display（玩家可见）与 mechanics（机制数值）。未登记却出现在 inventory/skills 里的内容视为不合理，系统会提示补全。
- **inventory/equipped/skills 只写名称**：这些数组里每一项都必须是简短的条目名（可带「x数量」，如「瓶盖 x23」），**不要写动作、句子或叙述**（例如「穿上雨披」「取得号码牌，与钥匙吻合。」都是错误写法）；物品的说明写进对应 codex 的 display/mechanics。
- **身体/状态词条**：损伤、体温、感染、疲劳等生理状态用 codex 的 kind=body 登记，会归入「身体」栏。
- **称号**：获得称号时把其 key 加入 titles（可带 stacks 层数、equipped 是否佩戴）；只能使用故事预定义的称号 key。
- **状态效果**：用 effects 记录当前 buff/debuff（name、kind=buff|debuff、stacks 层数、remaining 剩余回合、description）；remaining 减到 0 即移除。
- **职业/等级**：用 job 记录职业 name、等级 level、经验 exp；升级规则按故事设定。
- **据点**：用 base 记录设施 facilities（key/level/status）、物质 materials、仓储 storage（均为键值对）。
- **变量**：用 varOps 记录本回合变量的变化（只写变化的项）：数值增减用 delta，其它用 set 赋值；键名须与已声明变量一致，并遵守其类型/范围/取值。没有变化时给空数组。
- **在场角色**：present 必须每回合给出当前场景中实际出场的角色名（对应角色设定），无人在场时给空数组；角色随剧情逐个进出，不要一次性让所有角色登场。
- **角色状态**：npcs 给出在场角色的运行状态：resources（生命等数值条）、attributes（属性）、skills（技能）、inventory（携带）、affinity（对玩家的好感度）、status（姿态/状态描述）。角色并非无敌，受伤、消耗、好感变化都要反映在 npcs 里；不在场可省略。
- **装备**：equipped 列出当前已装备的物品（必须在 inventory 中）；装备的 codex 机制生效，未装备则不生效。
- **战斗**：进入战斗时给出 combat（active=true、round、敌人血量），战斗结束设 active=false；回合推进由玩家发起。
- **任务链**：同一 chain 的任务构成任务链，用 stage/totalStages 标记阶段。status 只能取 active / done / failed 三者之一（不要写 completed 等其它写法）；标记为 done 时必须同时把 stage 设为 totalStages、progress 设为 100，避免出现「1/2 却已完成」这种矛盾。
- **成就**：解锁成就时把其 key 加入 achievements；只能使用故事预定义的成就 key，不要自创。
- **需要判定成败时不要自己编点数**：正文写到行动尝试为止，输出 check 声明检定（骰子记法 / 修正 / 难度 DC），由系统掷骰后玩家会告知结果，你再据此描述结果。不需要检定时省略 check。''');
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

  /// 旧版 shared_preferences key（用于一次性迁移）
  static const _legacyKey = 'ai_stories';
  static const _dirName = 'stories';

  List<Story> _stories = [];
  bool _loaded = false;

  /// 每个故事的"基底"（最近一次导入 / 新建的内容）。
  /// 应用内的编辑以覆盖层形式叠加在基底之上：重新导入同 key / 同名故事时
  /// 只替换基底，覆盖层（用户的改动）保留并优先。
  final Map<String, Story> _bases = {};

  String _basePath(String id) => '$dirPath/$id.base.json';

  List<Story> get stories => List.unmodifiable(_stories);

  /// 故事目录（供 WebDAV 同步）
  String get dirPath => '${App.dataPath}/$_dirName';

  Future<void> init() async {
    _stories = [];
    _bases.clear();
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.md')) continue;
        try {
          final text = await entity.readAsString();
          final name = entity.uri.pathSegments.last;
          final id = name.endsWith('.md')
              ? name.substring(0, name.length - 3)
              : name;
          _stories.add(storyFromMarkdown(text, id: id));
        } catch (_) {}
      }
      for (final s in _stories) {
        final f = File(_basePath(s.id));
        if (!f.existsSync()) continue;
        try {
          final decoded = jsonDecode(await f.readAsString());
          if (decoded is Map) {
            _bases[s.id] = Story.fromJson(decoded.cast<String, dynamic>());
          }
        } catch (_) {}
      }
    } catch (_) {}
    await _migrateLegacy();
    _loaded = true;
    notifyListeners();
  }

  /// 旧版 prefs 数据迁移到 .md 文件
  Future<void> _migrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final e in decoded) {
          if (e is! Map) continue;
          final story = Story.fromJson(e.cast<String, dynamic>());
          if (_stories.any((s) => s.id == story.id)) continue;
          await _writeStory(story);
          _stories.add(story);
        }
      }
    } catch (_) {}
    await prefs.remove(_legacyKey);
  }

  Future<void> _writeStory(Story story) async {
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File('$dirPath/${story.id}.md').writeAsString(storyToMarkdown(story));
  }

  Future<void> _writeBase(Story story) async {
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File(_basePath(story.id)).writeAsString(jsonEncode(story.toJson()));
  }

  /// 全字段 JSON（toJson 会省略 null 字段，这里补齐便于做差集）
  static Map<String, dynamic> storyJsonFull(Story s) {
    final j = s.toJson();
    j['job'] = s.job?.toJson();
    j['temperature'] = s.temperature;
    j['topP'] = s.topP;
    j['maxTokens'] = s.maxTokens;
    return j;
  }

  /// 覆盖层 = 编辑后相对基底的差异字段
  static Map<String, dynamic> storyDiff(Story base, Story effective) {
    final b = storyJsonFull(base);
    final e = storyJsonFull(effective);
    final out = <String, dynamic>{};
    for (final k in e.keys) {
      if (jsonEncode(e[k]) != jsonEncode(b[k])) out[k] = e[k];
    }
    return out;
  }

  /// 把覆盖层叠加到基底上（覆盖层优先）
  static Story storyMerge(Story base, Map<String, dynamic> overlay) {
    if (overlay.isEmpty) return base;
    final json = {...storyJsonFull(base), ...overlay};
    json['id'] = base.id;
    return Story.fromJson(json);
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

  /// 保存故事。
  /// [asBase] = true：导入/新建的基底，整体替换基底，但保留已有覆盖层；
  /// 否则：编辑器里的编辑，只更新覆盖层（基底不变）。
  Future<void> upsert(Story story, {bool asBase = false}) async {
    await ensureLoaded();
    final id = story.id;
    Story effective;
    if (asBase) {
      final oldBase = _bases[id];
      final oldEffective = find(id);
      final overlay = (oldBase != null && oldEffective != null)
          ? storyDiff(oldBase, oldEffective)
          : const <String, dynamic>{};
      effective = storyMerge(story, overlay);
      _bases[id] = story;
      await _writeBase(story);
    } else {
      // 首次保存（尚无基底）时把当前内容作为基底，之后编辑才产生覆盖层
      if (_bases[id] == null) {
        _bases[id] = story;
        await _writeBase(story);
      }
      effective = story;
    }
    await _writeStory(effective);
    final idx = _stories.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      _stories[idx] = effective;
    } else {
      _stories.add(effective);
    }
    notifyListeners();
  }

  Future<bool> remove(String id) async {
    await ensureLoaded();
    final s = find(id);
    if (s != null && s.isBuiltin) return false;
    for (final path in ['$dirPath/$id.md', _basePath(id)]) {
      final f = File(path);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    _bases.remove(id);
    _stories.removeWhere((s) => s.id == id);
    notifyListeners();
    return true;
  }

  /// WebDAV 下载后重新加载
  Future<void> reload() async {
    _loaded = false;
    await init();
  }

  /// 从 .md 文本解析故事
  static Story storyFromMarkdown(String text, {String? id}) {
    final name = _firstHeading(text) ?? t.unnamedStory;
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
    List<T> mapList<T>(String section, T Function(Map<String, dynamic>) f) {
      final raw = _section(text, section);
      if (raw == null) return <T>[];
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return [
            for (final e in decoded)
              if (e is Map) f(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {}
      return <T>[];
    }
    final panels = mapList('面板', StoryPanel.fromJson);
    // 致命资源：列表（默认 any）或对象 {mode, resources}
    var deathRes = (mode: 'any', resources: <String>[]);
    final deathText = _section(text, '致命资源');
    if (deathText != null && deathText.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(deathText.trim());
        if (decoded is List) {
          deathRes = (
            mode: 'any',
            resources: decoded.whereType<String>().toList(),
          );
        } else if (decoded is Map) {
          deathRes = (
            mode: decoded['mode']?.toString() ?? 'any',
            resources:
                (decoded['resources'] as List?)?.whereType<String>().toList() ??
                const [],
          );
        }
      } catch (_) {}
    }
    // 称号：{mode, titles:[...]} 或直接是 titles 列表
    var titleMode = 'all';
    var titleDefs = <StoryTitle>[];
    final titleText = _section(text, '称号');
    if (titleText != null && titleText.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(titleText.trim());
        if (decoded is List) {
          titleDefs = [
            for (final e in decoded)
              if (e is Map) StoryTitle.fromJson(e.cast<String, dynamic>()),
          ];
        } else if (decoded is Map) {
          titleMode = decoded['mode']?.toString() ?? 'all';
          final list = decoded['titles'];
          if (list is List) {
            titleDefs = [
              for (final e in list)
                if (e is Map) StoryTitle.fromJson(e.cast<String, dynamic>()),
            ];
          }
        }
      } catch (_) {}
    }
    double? genTemp;
    double? genTopP;
    int? genMaxTokens;
    final genText = _section(text, '生成参数');
    if (genText != null && genText.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(genText.trim());
        if (decoded is Map) {
          genTemp = (decoded['temperature'] as num?)?.toDouble();
          genTopP = (decoded['topP'] as num?)?.toDouble();
          genMaxTokens = (decoded['maxTokens'] as num?)?.toInt();
        }
      } catch (_) {}
    }
    StoryJob? jobDef;
    final jobText = _section(text, '职业');
    if (jobText != null && jobText.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(jobText.trim());
        if (decoded is Map) {
          jobDef = StoryJob.fromJson(decoded.cast<String, dynamic>());
        }
      } catch (_) {}
    }
    var persona = const StoryPersona();
    final personaText = _section(text, '玩家角色');
    if (personaText != null) {
      try {
        final decoded = jsonDecode(personaText);
        if (decoded is Map) {
          persona = StoryPersona.fromJson(decoded.cast<String, dynamic>());
        }
      } catch (_) {}
    }
    return Story(
      id: id ?? 'story_${DateTime.now().millisecondsSinceEpoch}',
      key: _section(text, '标识')?.trim() ?? '',
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
      settingIds: idList('设定库'),
      panels: panels,
      deathResources: deathRes.resources,
      deathMode: deathRes.mode,
      characters: mapList('角色', CharacterCard.fromJson),
      variables: mapList('变量', StoryVariable.fromJson),
      regexes: mapList('正则', StoryRegex.fromJson),
      achievements: mapList('成就', StoryAchievement.fromJson),
      codex: mapList('词条', StoryDefinition.fromJson),
      titles: titleDefs,
      titleMode: titleMode,
      job: jobDef,
      facilities: mapList('据点', StoryFacility.fromJson),
      temperature: genTemp,
      topP: genTopP,
      maxTokens: genMaxTokens,
      persona: persona,
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
    if (s.key.isNotEmpty) {
      buf.writeln('## 标识');
      buf.writeln(s.key.trim());
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
    if (s.settingIds.isNotEmpty) {
      section('设定库', jsonEncode(s.settingIds));
    }
    if (s.panels.isNotEmpty) {
      section('面板', jsonEncode([for (final p in s.panels) p.toJson()]));
    }
    if (s.deathResources.isNotEmpty) {
      section(
        '致命资源',
        jsonEncode({'mode': s.deathMode, 'resources': s.deathResources}),
      );
    }
    // 角色卡不写入故事文件（存于 story_characters/<id>.json，见 StoryCharacterStore）
    if (s.variables.isNotEmpty) {
      section('变量', jsonEncode([for (final v in s.variables) v.toJson()]));
    }
    if (s.regexes.isNotEmpty) {
      section('正则', jsonEncode([for (final r in s.regexes) r.toJson()]));
    }
    if (s.achievements.isNotEmpty) {
      section('成就', jsonEncode([for (final a in s.achievements) a.toJson()]));
    }
    if (s.codex.isNotEmpty) {
      section('词条', jsonEncode([for (final d in s.codex) d.toJson()]));
    }
    if (s.titles.isNotEmpty) {
      section(
        '称号',
        jsonEncode({
          'mode': s.titleMode,
          'titles': [for (final x in s.titles) x.toJson()],
        }),
      );
    }
    if (s.job != null && !s.job!.isEmpty) {
      section('职业', jsonEncode(s.job!.toJson()));
    }
    if (s.facilities.isNotEmpty) {
      section('据点', jsonEncode([for (final f in s.facilities) f.toJson()]));
    }
    if (s.temperature != null || s.topP != null || s.maxTokens != null) {
      section(
        '生成参数',
        jsonEncode({
          if (s.temperature != null) 'temperature': s.temperature,
          if (s.topP != null) 'topP': s.topP,
          if (s.maxTokens != null) 'maxTokens': s.maxTokens,
        }),
      );
    }
    if (!s.persona.isEmpty) {
      section('玩家角色', jsonEncode(s.persona.toJson()));
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

/// 会话存储：storyId -> StorySession，存放于 `dataPath/story_sessions/` 的独立文件
class StorySessionStore extends ChangeNotifier {
  static final StorySessionStore instance = StorySessionStore._();

  StorySessionStore._();

  /// 旧版 shared_preferences key（用于一次性迁移）
  static const _legacyKey = 'ai_story_sessions';
  static const _dirName = 'story_sessions';

  Map<String, StorySession> _sessions = {};
  bool _loaded = false;

  String get dirPath => '${App.dataPath}/$_dirName';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _sessions = {};
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await entity.readAsString());
          if (json is! Map) continue;
          final name = entity.uri.pathSegments.last;
          final id = name.substring(0, name.length - 5);
          _sessions[id] = StorySession.fromJson(json.cast<String, dynamic>());
        } catch (_) {}
      }
    } catch (_) {}
    await _migrateLegacy();
    _loaded = true;
  }

  /// 旧版 prefs 数据迁移到文件
  Future<void> _migrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final e in decoded.entries) {
          if (e.value is! Map) continue;
          final id = e.key.toString();
          if (_sessions.containsKey(id)) continue;
          final session = StorySession.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          );
          _sessions[id] = session;
          await _writeSession(id, session);
        }
      }
    } catch (_) {}
    await prefs.remove(_legacyKey);
  }

  Future<void> _writeSession(String storyId, StorySession session) async {
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File(
      '$dirPath/$storyId.json',
    ).writeAsString(jsonEncode(session.toJson()));
  }

  /// 已存档的 storyId 列表（供选择性同步）
  List<String> get storyIds => _sessions.keys.toList();

  StorySession? get(String storyId) => _sessions[storyId];

  Future<void> put(String storyId, StorySession session) async {
    await ensureLoaded();
    _sessions[storyId] = session;
    await _writeSession(storyId, session);
    notifyListeners();
  }

  Future<void> clear(String storyId) async {
    await ensureLoaded();
    _sessions.remove(storyId);
    final f = File('$dirPath/$storyId.json');
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    notifyListeners();
  }

  /// WebDAV 下载后重新加载
  Future<void> reload() async {
    _loaded = false;
    await ensureLoaded();
  }
}

/// 故事角色卡存储：`story_characters/<storyId>.json`
/// 与故事 `.md` 分离——App 内添加的角色卡不再写进故事文件，
/// 避免撑大文件、影响故事版本升级与后续改动。
class StoryCharacterStore extends ChangeNotifier {
  static final StoryCharacterStore instance = StoryCharacterStore._();

  StoryCharacterStore._();

  static const _dirName = 'story_characters';

  final Map<String, List<CharacterCard>> _cards = {};
  bool _loaded = false;

  String get dirPath => '${App.dataPath}/$_dirName';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _cards.clear();
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await entity.readAsString());
          if (json is! List) continue;
          final name = entity.uri.pathSegments.last;
          final id = name.substring(0, name.length - 5);
          _cards[id] = [
            for (final e in json)
              if (e is Map) CharacterCard.fromJson(e.cast<String, dynamic>()),
          ];
        } catch (_) {}
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  /// 已存角色卡的故事 id（供选择性同步）
  List<String> get storyIds => _cards.keys.toList();

  List<CharacterCard> get(String storyId) =>
      List.unmodifiable(_cards[storyId] ?? const <CharacterCard>[]);

  Future<void> put(String storyId, List<CharacterCard> cards) async {
    await ensureLoaded();
    if (cards.isEmpty) {
      await clear(storyId);
      return;
    }
    _cards[storyId] = List.of(cards);
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File('$dirPath/$storyId.json').writeAsString(
      jsonEncode([for (final c in cards) c.toJson()]),
    );
    notifyListeners();
  }

  Future<void> clear(String storyId) async {
    await ensureLoaded();
    _cards.remove(storyId);
    final f = File('$dirPath/$storyId.json');
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> reload() async {
    _loaded = false;
    await ensureLoaded();
  }

  /// 把故事 `.md` 里内联的角色卡迁移到独立文件（一次性）
  Future<void> migrateFromStories() async {
    await ensureLoaded();
    for (final story in StoryStore.instance.stories) {
      if (story.characters.isEmpty) continue;
      if ((_cards[story.id] ?? const []).isNotEmpty) continue;
      await put(story.id, story.characters);
      await StoryStore.instance.upsert(
        story.copyWith(characters: const []),
      );
    }
  }
}
