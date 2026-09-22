// AI 共创角色卡：头脑风暴 → 生成完整卡 → 用 <actions> 差分精修。
// 思路移植自 CarFrog（纯对话驱动的 ST 角色卡生成器），映射到本项目的 CharacterCard。

import 'dart:convert';

import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/ai_service/json_actions.dart';
import 'package:kostori/foundation/app.dart';

/// 目标语言（跟随应用界面语言）
String creatorLanguage() {
  final locale = App.locale;
  return switch (locale.languageCode) {
    'zh' => locale.countryCode == 'TW' ? '繁體中文' : '中文',
    'en' => 'English',
    'ja' => '日本語',
    'ko' => '한국어',
    _ => '中文',
  };
}

const cardBrainstormPrompt = '''
你是角色设计助手。用户想创建一张 SillyTavern 角色卡。

当前阶段：**头脑风暴 — 只讨论，不产出 JSON，也不写世界书**。

任务：
- 主动引导用户构思：名称、外貌、性格、背景、场景、说话风格、与用户的关系
- 一般 2~3 轮讨论即可收敛方向，讨论到位后提醒用户点击「生成角色卡」
- 绝对不要输出任何 JSON 或字段结构
''';

const cardGeneratePrompt = '''
你是角色卡生成助手。请根据之前的讨论，生成一张完整的 SillyTavern V2 角色卡。

## 输出结构（必须严格遵守）
依次输出两部分：

1. 以 `## 角色摘要` 为标题，用一段简洁文字概述：角色名、核心定位、性格关键词、外貌亮点、场景设定、说话风格（150~300 字，作为后续精修的上下文锚点）。

2. 以 `## 角色卡` 为标题，把完整 JSON 放进 ```json 代码块。JSON 结构：

```json
{
  "spec": "chara_card_v2",
  "spec_version": "2.0",
  "data": {
    "name": "角色名称（必填）",
    "description": "外貌与特征（必填）",
    "personality": "性格与行为倾向（必填）",
    "scenario": "场景设定（必填）",
    "first_mes": "角色的开场白（必填）",
    "mes_example": "示例对话（可选）",
    "alternate_greetings": ["替代开场白"],
    "tags": ["标签"],
    "creator": "",
    "character_version": "1.0",
    "creator_notes": "",
    "system_prompt": "",
    "post_history_instructions": ""
  }
}
```

## 注意
- 对话内容用中文引号“”或「」包裹，不要用英文双引号
- 不要生成世界书（character_book），后续精修阶段再加
- 必须先输出角色摘要，再输出角色卡 JSON
''';

const cardRefinePrompt = '''
你是角色卡精修助手，用户可对角色卡的任意字段提出修改要求。

## 输出规则
把修改指令放进 <actions> 标签，内容为 JSON 数组：

<actions>
[
  { "type": "set", "path": "data.name", "value": "新值" },
  { "type": "add", "path": "data.tags", "value": "新标签" },
  { "type": "remove", "path": "data.tags", "index": 2 }
]
</actions>

- set：设置字段值；add：向数组追加；remove：删除数组指定下标
- value 里的对话用中文引号“”或「」包裹，不要用英文双引号
- <actions> 之外可以附上简短说明；只输出需要变更的部分
''';

/// 从模型回复里解析角色卡（```json 围栏或首个平衡 JSON 块）
CharacterCard? parseCardJsonFromText(String text) {
  final candidates = <String>[];
  final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fenced != null) candidates.add(fenced.group(1)!);
  final first = text.indexOf('{');
  final last = text.lastIndexOf('}');
  if (first >= 0 && last > first) {
    candidates.add(text.substring(first, last + 1));
  }
  for (final raw in candidates) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is Map &&
          (decoded.containsKey('data') ||
              decoded.containsKey('name') ||
              decoded.containsKey('char_name'))) {
        final card = CharacterCard.fromSillyTavernJson(
          decoded.cast<String, dynamic>(),
        );
        if (card.name.trim().isNotEmpty) return card;
      }
    } catch (_) {}
  }
  return null;
}

/// 提取 `## 角色摘要` 段落
String? extractCardSummary(String text) {
  final m = RegExp(r'##\s*角色摘要\s*\n([\s\S]*?)(?=\n##|\z)').firstMatch(text);
  return m?.group(1)?.trim();
}

/// 把 `data.first_mes` 之类的路径归一化为本项目的字段名
String _normalizeCardPath(String path) {
  var p = path.trim();
  if (p.startsWith('data.')) p = p.substring(5);
  const alias = {
    'first_mes': 'firstMessage',
    'firstMessage': 'firstMessage',
    'mes_example': 'exampleDialogue',
    'exampleDialogue': 'exampleDialogue',
    'creator_notes': 'creatorNotes',
    'creatorNotes': 'creatorNotes',
    'system_prompt': 'systemPrompt',
    'systemPrompt': 'systemPrompt',
    'post_history_instructions': 'postHistoryInstructions',
    'postHistoryInstructions': 'postHistoryInstructions',
    'alternate_greetings': 'alternateGreetings',
    'alternateGreetings': 'alternateGreetings',
    'group_only_greetings': 'groupOnlyGreetings',
    'groupOnlyGreetings': 'groupOnlyGreetings',
    'character_version': 'version',
    'character_book.entries': 'bookEntries',
    'characterBook.entries': 'bookEntries',
  };
  return alias[p] ?? p;
}

const _listFields = {
  'tags',
  'alternateGreetings',
  'groupOnlyGreetings',
  'source',
};

List<String> _asStrList(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

/// 应用精修差分，返回新的角色卡
CharacterCard applyCardActions(CharacterCard card, List<JsonAction> actions) {
  var c = card;
  for (final a in actions) {
    final key = _normalizeCardPath(a.path);
    try {
      if (key == 'bookEntries') {
        c = _applyBookEntries(c, a);
      } else if (_listFields.contains(key)) {
        c = _applyListField(c, key, a);
      } else {
        c = _applyScalarField(c, key, a);
      }
    } catch (_) {
      // 单条指令失败不影响其它字段
    }
  }
  return c;
}

CharacterCard _applyScalarField(CharacterCard c, String key, JsonAction a) {
  if (a.type == 'remove') return c;
  final v = a.value?.toString() ?? '';
  return switch (key) {
    'name' => c.copyWith(name: v),
    'description' => c.copyWith(description: v),
    'personality' => c.copyWith(personality: v),
    'scenario' => c.copyWith(scenario: v),
    'firstMessage' => c.copyWith(firstMessage: v),
    'exampleDialogue' => c.copyWith(exampleDialogue: v),
    'creatorNotes' => c.copyWith(creatorNotes: v),
    'systemPrompt' => c.copyWith(systemPrompt: v),
    'postHistoryInstructions' => c.copyWith(postHistoryInstructions: v),
    'creator' => c.copyWith(creator: v),
    'version' => c.copyWith(version: v),
    'nickname' => c.copyWith(nickname: v),
    _ => c,
  };
}

CharacterCard _applyListField(CharacterCard c, String key, JsonAction a) {
  final current = switch (key) {
    'tags' => c.tags,
    'alternateGreetings' => c.alternateGreetings,
    'groupOnlyGreetings' => c.groupOnlyGreetings,
    'source' => c.source,
    _ => const <String>[],
  };
  var list = [...current];
  switch (a.type) {
    case 'set':
      if (a.index != null && a.index! >= 0 && a.index! < list.length) {
        list[a.index!] = a.value?.toString() ?? '';
      } else if (a.value is List) {
        list = _asStrList(a.value);
      }
    case 'add':
      final v = a.value?.toString() ?? '';
      if (v.isNotEmpty && !list.contains(v)) list.add(v);
    case 'remove':
      final i = a.index ?? -1;
      if (i >= 0 && i < list.length) list.removeAt(i);
  }
  return switch (key) {
    'tags' => c.copyWith(tags: list),
    'alternateGreetings' => c.copyWith(alternateGreetings: list),
    'groupOnlyGreetings' => c.copyWith(groupOnlyGreetings: list),
    'source' => c.copyWith(source: list),
    _ => c,
  };
}

CharacterCard _applyBookEntries(CharacterCard c, JsonAction a) {
  final book = <String, dynamic>{...?c.characterBook};
  final entries = [
    for (final e in (book['entries'] as List? ?? const []))
      if (e is Map) e.cast<String, dynamic>() else <String, dynamic>{},
  ];
  switch (a.type) {
    case 'set':
      final v = a.value;
      if (a.index != null && a.index! >= 0 && a.index! < entries.length) {
        if (v is Map) entries[a.index!] = v.cast<String, dynamic>();
      } else if (v is List) {
        entries
          ..clear()
          ..addAll([
            for (final e in v)
              if (e is Map) e.cast<String, dynamic>(),
          ]);
      }
    case 'add':
      if (a.value is Map) {
        entries.add((a.value as Map).cast<String, dynamic>());
      }
    case 'remove':
      final i = a.index ?? -1;
      if (i >= 0 && i < entries.length) entries.removeAt(i);
  }
  book['entries'] = entries;
  return c.copyWith(characterBook: book);
}

/// 精修阶段的系统提示词：注入当前卡 + 摘要 + 精修规则
String buildCardRefineSystemPrompt(
  CharacterCard card, {
  String? summary,
  String extra = cardRefinePrompt,
}) {
  final buf = StringBuffer('当前角色卡数据（JSON）：\n');
  buf.writeln(
    const JsonEncoder.withIndent('  ').convert(card.toSillyTavernJson(spec: 2)),
  );
  if (summary != null && summary.trim().isNotEmpty) {
    buf.writeln('\n角色摘要：\n${summary.trim()}');
  }
  buf.writeln('\n$extra');
  return buf.toString();
}

/// 生成阶段的用户指令
const cardGenerateInstruction = '请根据我们的讨论，生成完整的角色摘要与角色卡 JSON。';
