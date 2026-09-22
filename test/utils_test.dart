import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/ai_service/character_lorebook.dart';
import 'package:kostori/foundation/ai_service/setting_library.dart';
import 'package:kostori/foundation/ai_service/story.dart';
import 'package:kostori/utils/utils.dart';

/// 生成一张 1x1 的合法 PNG，用于角色卡块写入测试
Uint8List _tinyPng() {
  int crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  List<int> u32(int v) => [
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ];

  List<int> chunk(String type, List<int> data) {
    final td = [...ascii.encode(type), ...data];
    return [...u32(data.length), ...td, ...u32(crc32(td))];
  }

  final idat = zlib.encode(<int>[0, 255, 255, 255]);
  final ihdr = <int>[0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0];
  return Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', ihdr),
    ...chunk('IDAT', idat),
    ...chunk('IEND', const []),
  ]);
}

/// 生成带指定文本块的 PNG（用于 iTXt / tEXt 测试）
Uint8List _tinyPngWithChunk(String type, List<int> chunkData) {
  int crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  List<int> u32(int v) => [
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ];

  List<int> chunk(String t, List<int> d) {
    final td = [...ascii.encode(t), ...d];
    return [...u32(d.length), ...td, ...u32(crc32(td))];
  }

  final idat = zlib.encode(<int>[0, 255, 255, 255]);
  final ihdr = <int>[0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0];
  return Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', ihdr),
    ...chunk(type, chunkData),
    ...chunk('IDAT', idat),
    ...chunk('IEND', const []),
  ]);
}

void main() {
  group('colorToHex / hexToColor', () {
    test('round trips ARGB', () {
      expect(Utils.colorToHex(const Color(0xFF123456)), '#FF123456');
      expect(Utils.hexToColor('#123456'), const Color(0xFF123456));
      expect(Utils.hexToColor('ff123456'), const Color(0xFF123456));
    });

    test('handles invalid input', () {
      expect(Utils.hexToColor(null), isNull);
      expect(Utils.hexToColor('not-a-color'), isNull);
    });
  });

  group('durationToString', () {
    test('omits hours when zero', () {
      expect(Utils.durationToString(const Duration(seconds: 5)), '00:05');
      expect(
        Utils.durationToString(const Duration(minutes: 3, seconds: 9)),
        '03:09',
      );
    });

    test('includes hours when present', () {
      expect(
        Utils.durationToString(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '01:02:03',
      );
    });
  });

  group('formatHMS', () {
    test('builds human readable parts', () {
      expect(Utils.formatHMS(0), '0s');
      expect(Utils.formatHMS(59), '59s');
      expect(Utils.formatHMS(60), '1m');
      expect(Utils.formatHMS(3661), '1h 1m 1s');
    });
  });

  group('date helpers', () {
    test('isSameWeek respects monday start', () {
      expect(
        Utils.isSameWeek(DateTime(2026, 9, 7), DateTime(2026, 9, 13)),
        isTrue,
      );
      expect(
        Utils.isSameWeek(DateTime(2026, 9, 6), DateTime(2026, 9, 7)),
        isFalse,
      );
    });

    test('month / quarter / half year / year', () {
      expect(
        Utils.isSameMonth(DateTime(2026, 1, 1), DateTime(2026, 1, 31)),
        isTrue,
      );
      expect(
        Utils.isSameMonth(DateTime(2026, 1, 1), DateTime(2026, 2, 1)),
        isFalse,
      );
      expect(
        Utils.isSameQuarter(DateTime(2026, 1, 1), DateTime(2026, 3, 31)),
        isTrue,
      );
      expect(
        Utils.isSameQuarter(DateTime(2026, 3, 31), DateTime(2026, 4, 1)),
        isFalse,
      );
      expect(
        Utils.isSameHalfYear(DateTime(2026, 1, 1), DateTime(2026, 6, 30)),
        isTrue,
      );
      expect(
        Utils.isSameHalfYear(DateTime(2026, 6, 30), DateTime(2026, 7, 1)),
        isFalse,
      );
      expect(
        Utils.isSameYear(DateTime(2026, 1, 1), DateTime(2026, 12, 31)),
        isTrue,
      );
      expect(
        Utils.isSameYear(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
        isFalse,
      );
    });
  });

  group('isHalfOverlap', () {
    test('compares character set overlap', () {
      expect(Utils.isHalfOverlap('abc', 'abd'), isTrue);
      expect(Utils.isHalfOverlap('abc', 'xyz'), isFalse);
      expect(Utils.isHalfOverlap('', 'abc'), isFalse);
    });
  });

  group('containsIllegalCharacters', () {
    test('detects illegal / emoji / inner dash', () {
      expect(Utils.containsIllegalCharacters('hello world'), isFalse);
      expect(Utils.containsIllegalCharacters('a_b'), isTrue);
      expect(Utils.containsIllegalCharacters('a-b'), isTrue);
      expect(Utils.containsIllegalCharacters('hello 😀'), isTrue);
    });
  });

  group('character card png', () {
    test('embeds chara chunk and parses it back', () {
      final card = CharacterCard(
        id: 'c1',
        name: '测试角色',
        description: '一个用于测试的角色',
        personality: '冷静',
        tags: const ['test', 'demo'],
      );
      final png = _tinyPng();
      final embedded = CharacterCard.embedCharaChunk(png, card.toCharaText());
      expect(embedded.length, greaterThan(png.length));

      final parsed = CharacterCard.fromPngBytes(embedded);
      expect(parsed, isNotNull);
      expect(parsed!.name, '测试角色');
      expect(parsed.description, '一个用于测试的角色');
      expect(parsed.personality, '冷静');
      expect(parsed.tags, ['test', 'demo']);
    });

    test('returns null for non-card png', () {
      expect(CharacterCard.fromPngBytes(_tinyPng()), isNull);
    });

    test('reads iTXt chara chunk', () {
      const card = CharacterCard(id: 'c3', name: 'Rin卡', description: 'iTXt');
      final data = <int>[
        ...ascii.encode('chara'),
        0,
        0, // compression flag
        0, // compression method
        0, // language tag terminator
        0, // translated keyword terminator
        ...utf8.encode(card.toCharaText()),
      ];
      final png = _tinyPngWithChunk('iTXt', data);
      final parsed = CharacterCard.fromPngBytes(png);
      expect(parsed, isNotNull);
      expect(parsed!.name, 'Rin卡');
      expect(parsed.description, 'iTXt');
    });

    test('unwraps character / char wrappers', () {
      final a = CharacterCard.fromSillyTavernJson({
        'character': {'name': '包裹', 'description': 'd'},
      });
      expect(a.name, '包裹');
      final b = CharacterCard.fromSillyTavernJson({
        'char': {'name': '变体', 'first_mes': 'hi'},
      });
      expect(b.name, '变体');
      expect(b.firstMessage, 'hi');
    });
  });

  group('character card spec versions', () {
    const card = CharacterCard(
      id: 'c2',
      name: 'V3角色',
      nickname: '小V',
      description: 'desc',
      source: ['https://example.com'],
      groupOnlyGreetings: ['群聊开场'],
      tags: ['a'],
      extensions: {'foo': 'bar'},
    );

    test('exports V3 by default and round-trips', () {
      final json = card.toSillyTavernJson();
      expect(json['spec'], 'chara_card_v3');
      expect(json['spec_version'], '3.0');
      final parsed = CharacterCard.fromSillyTavernJson(
        json.cast<String, dynamic>(),
      );
      expect(parsed.name, 'V3角色');
      expect(parsed.nickname, '小V');
      expect(parsed.source, ['https://example.com']);
      expect(parsed.groupOnlyGreetings, ['群聊开场']);
      expect(parsed.specVersion, '3.0');
      expect(parsed.extensions['foo'], 'bar');
    });

    test('exports V2 without V3-only fields', () {
      final json = card.toSillyTavernJson(spec: 2);
      expect(json['spec'], 'chara_card_v2');
      final data = json['data'] as Map<String, dynamic>;
      expect(data.containsKey('nickname'), isFalse);
      expect(data.containsKey('source'), isFalse);
      expect(data['name'], 'V3角色');
    });

    test('reads V1 flat cards', () {
      final parsed = CharacterCard.fromSillyTavernJson({
        'name': 'V1角色',
        'description': 'flat',
        'first_mes': 'hi',
      });
      expect(parsed.name, 'V1角色');
      expect(parsed.firstMessage, 'hi');
    });
  });

  group('character lorebook', () {
    CharacterLoreBook book() => CharacterLoreBook.fromMap({
      'scan_depth': 4,
      'token_budget': 500,
      'recursive_scanning': false,
      'entries': [
        {
          'keys': ['龙'],
          'content': '龙是古代生物。',
          'enabled': true,
          'insertion_order': 10,
        },
        {
          'keys': ['剑'],
          'secondary_keys': ['银'],
          'selective': true,
          'selective_logic': 3, // AND_ALL
          'content': '银剑克制龙。',
          'enabled': true,
          'insertion_order': 20,
        },
        {
          'keys': ['隐藏'],
          'secondary_keys': ['银'],
          'selective': true,
          'selective_logic': 2, // NOT_ANY
          'content': '未持银器。',
          'enabled': true,
          'insertion_order': 30,
        },
        {
          'keys': <String>[],
          'constant': true,
          'content': '常驻设定。',
          'enabled': true,
          'insertion_order': 0,
        },
      ],
    })!;

    List<String> contents(String text, {int turn = 1}) =>
        CharacterLorebookResolver.instance
            .resolve(book(), [text], cardId: 'x', turn: turn)
            .map((e) => e.content)
            .toList();

    test('constant entry always activates', () {
      expect(contents('无关'), contains('常驻设定。'));
    });

    test('primary key hit', () {
      expect(contents('一条龙出现'), contains('龙是古代生物。'));
    });

    test('selective AND_ALL requires all secondary keys', () {
      expect(contents('剑'), isNot(contains('银剑克制龙。')));
      expect(contents('剑 银'), contains('银剑克制龙。'));
    });

    test('selective NOT_ANY requires no secondary key', () {
      expect(contents('隐藏'), contains('未持银器。'));
      expect(contents('隐藏 银'), isNot(contains('未持银器。')));
    });

    test('orders by insertion_order', () {
      final list = contents('龙 剑 银');
      expect(list.indexOf('常驻设定。'), lessThan(list.indexOf('龙是古代生物。')));
    });
  });

  group('deviation helpers', () {
    test('calculateSD skips zero buckets', () {
      expect(Utils.calculateSD(List.filled(10, 0), 5, 1), 0);
    });

    test('getDispute labels', () {
      expect(Utils.getDispute(0), '-');
      expect(Utils.getDispute(0.5), '异口同声');
      expect(Utils.getDispute(2), '厨黑大战');
    });
  });

  group('story system prompt', () {
    test(
      'uses the declared resources and attributes in the output example',
      () {
        const story = Story(
          id: 't',
          name: 't',
          initialState: GameState(
            resources: [
              StatBar(name: '体力', cur: 100, max: 100),
              StatBar(name: '进食', cur: 80, max: 100),
            ],
            attributes: {'耐力': 7},
          ),
        );
        final prompt = story.buildSystemPrompt();
        expect(prompt.contains('"体力"'), isTrue);
        expect(prompt.contains('"进食"'), isTrue);
        expect(prompt.contains('"耐力"'), isTrue);
        // 不应再写死示例里的名称
        expect(prompt.contains('"生命"'), isFalse);
        expect(prompt.contains('"精神"'), isFalse);
      },
    );

    test('includes story-defined titles / job / facilities', () {
      const story = Story(
        id: 't',
        name: 't',
        titleMode: 'equipped',
        titles: [
          StoryTitle(
            key: 'brave',
            name: '勇者',
            effects: '力量+2',
            stackable: true,
          ),
        ],
        job: StoryJob(
          name: '游侠',
          levels: [StoryJobLevel(level: 1, name: '见习', bonus: '敏捷+1')],
        ),
        facilities: [StoryFacility(key: 'forge', name: '锻造台', maxLevel: 3)],
      );
      final prompt = story.buildSystemPrompt();
      expect(prompt.contains('勇者'), isTrue);
      expect(prompt.contains('游侠'), isTrue);
      expect(prompt.contains('锻造台'), isTrue);
      expect(prompt.contains('仅已佩戴'), isTrue);
    });
  });

  group('parseStoryFixedHints', () {
    test('extracts race / talent / mod / event entries', () {
      const wb = '''
【通用天赋（固定机制，必须照此执行）】
- **武器大师**：你擅长使用各种武器。智力检定 +4。
【MOD（改变世界规则）】
- **自定义**：设定你的游戏模组。
- **硬核生存**：硬核模式：所有属性检定时额外 -10。
- **界域之痕**：改变世界观：世界的外壳日益脆弱。
- **如影随形**：改变叙事：你被某个势力持续追踪。
- **低魔世界**：改变世界观：魔法变得极其稀有。
【世界大事件（固定内容，必须照此执行）】
- **旧日回响**（推荐等阶：凡铁 1 级）
  一封来自失落先祖的信函。
  主要人物（世界书关联角色）：寒·德雷克。
''';
      final h = parseStoryFixedHints(wb);
      expect(h['武器大师'], contains('智力检定 +4'));
      for (final m in ['硬核生存', '界域之痕', '如影随形', '低魔世界']) {
        expect(h[m], isNotNull, reason: m);
        expect(h[m]!.isNotEmpty, isTrue, reason: m);
      }
      expect(h['旧日回响'], contains('推荐等阶：凡铁 1 级'));
      expect(h['旧日回响'], contains('一封来自失落先祖的信函'));
    });
  });

  group('filterWorldBook', () {
    test('keeps selected entries and compresses the rest', () {
      const wb = '''
【种族（固定机制，必须照此执行）】
- **人类**：任选一项属性 +1。
- **精灵**：感知 +2。
- **矮人**：体质 +2。
【世界大事件（固定内容，必须照此执行）】
- **旧日回响**（推荐等阶：凡铁 1 级）
  一封来自失落先祖的信函。
- **七山矿乱**（推荐等阶：凡铁 5 级）
  七峰山脉的矿乱。
【常见势力】
- **树冠议会**：长寿种族的联合议事机构。
''';
      final f = filterWorldBook(wb, {
        'race': ['精灵'],
        'events': ['旧日回响'],
      });
      expect(f, contains('**精灵**'));
      expect(f, isNot(contains('**人类**：')));
      expect(f, contains('未启用，仅备查'));
      expect(f, contains('**旧日回响**'));
      expect(f, contains('一封来自失落先祖的信函'));
      expect(f, isNot(contains('七峰山脉的矿乱')));
      // 不受选择影响的章节原样保留
      expect(f, contains('**树冠议会**'));
    });

    test('empty selection returns the world book unchanged', () {
      const wb = '【种族】\n- **人类**：x\n';
      expect(filterWorldBook(wb, const {}), wb);
    });

    test('session setup survives json round trip', () {
      const s = StorySession(
        sessionId: 'x',
        state: GameState.empty,
        setup: {
          'race': ['精灵'],
          'talents': ['武器大师', '百炼之躯'],
        },
      );
      final back = StorySession.fromJson(s.toJson());
      expect(back.sessionId, 'x');
      expect(back.setup['race'], ['精灵']);
      expect(back.setup['talents'], ['武器大师', '百炼之躯']);
    });
  });

  group('story markdown round trip', () {
    test('titles / job / facilities survive export and import', () {
      const story = Story(
        id: 's',
        name: 'S',
        titleMode: 'equipped',
        titles: [
          StoryTitle(
            key: 'brave',
            name: '勇者',
            effects: '力量+2',
            stackable: true,
          ),
        ],
        job: StoryJob(
          name: '游侠',
          levels: [StoryJobLevel(level: 1, name: '见习', bonus: '敏捷+1')],
        ),
        facilities: [StoryFacility(key: 'forge', name: '锻造台', maxLevel: 3)],
      );
      final md = StoryStore.storyToMarkdown(story);
      final back = StoryStore.storyFromMarkdown(md, id: 's');
      expect(back.titleMode, 'equipped');
      expect(back.titles.single.key, 'brave');
      expect(back.titles.single.effects, '力量+2');
      expect(back.titles.single.stackable, isTrue);
      expect(back.job?.name, '游侠');
      expect(back.job?.levels.single.bonus, '敏捷+1');
      expect(back.facilities.single.key, 'forge');
      expect(back.facilities.single.maxLevel, 3);
    });

    test('panel groups survive export and import', () {
      const story = Story(
        id: 's',
        name: 'S',
        panels: [
          StoryPanel(title: '身体', source: 'resources', group: '状态'),
          StoryPanel(title: '物品', source: 'inventory', group: '物品'),
          StoryPanel(source: 'attributes'),
        ],
      );
      final md = StoryStore.storyToMarkdown(story);
      final back = StoryStore.storyFromMarkdown(md, id: 's');
      expect(back.panels.length, 3);
      expect(back.panels[0].title, '身体');
      expect(back.panels[0].group, '状态');
      expect(back.panels[1].source, 'inventory');
      expect(back.panels[1].group, '物品');
      expect(back.panels[2].group, '');
    });

    test('preset codex entries round trip', () {
      const story = Story(
        id: 's',
        name: 'S',
        codex: [
          StoryDefinition(
            kind: 'item',
            key: 'sword',
            name: '长剑',
            display: '一把剑',
            mechanics: '攻击+3',
          ),
        ],
      );
      final md = StoryStore.storyToMarkdown(story);
      final back = StoryStore.storyFromMarkdown(md, id: 's');
      expect(back.codex.single.kind, 'item');
      expect(back.codex.single.name, '长剑');
      expect(back.codex.single.mechanics, '攻击+3');
    });

    test('story dice library round trips', () {
      const story = Story(
        id: 's',
        name: 'S',
        dice: [StoryDice(name: '力量检定', dice: '1d20')],
      );
      final md = StoryStore.storyToMarkdown(story);
      final back = StoryStore.storyFromMarkdown(md, id: 's');
      expect(back.dice.single.name, '力量检定');
      expect(back.dice.single.dice, '1d20');
    });

    test('setting library ids round trip', () {
      const story = Story(id: 's', name: 'S', settingIds: ['set_1', 'set_2']);
      final md = StoryStore.storyToMarkdown(story);
      final back = StoryStore.storyFromMarkdown(md, id: 's');
      expect(back.settingIds, ['set_1', 'set_2']);
    });

    test('stable key and version round trip through markdown', () {
      const story = Story(
        id: 's',
        key: 'wasteland-survival',
        version: '1.0.0',
        name: 'S',
      );
      final md = StoryStore.storyToMarkdown(story);
      final back = StoryStore.storyFromMarkdown(md, id: 's');
      expect(back.key, 'wasteland-survival');
      expect(back.version, '1.0.0');
    });

    test('edit overlay survives re-importing the base', () {
      const base = Story(id: 's', key: 'k', name: '旧名', opening: '原开局');
      final edited = base.copyWith(name: '我的名字', systemPrompt: '我的提示词');
      final overlay = StoryStore.storyDiff(base, edited);
      expect(overlay.containsKey('name'), isTrue);
      expect(overlay.containsKey('systemPrompt'), isTrue);
      expect(overlay.containsKey('opening'), isFalse);

      const newBase = Story(
        id: 's',
        key: 'k',
        name: '旧名',
        opening: '新开局',
        worldBook: '新世界书',
      );
      final merged = StoryStore.storyMerge(newBase, overlay);
      expect(merged.name, '我的名字'); // 覆盖层优先
      expect(merged.systemPrompt, '我的提示词'); // 覆盖层保留
      expect(merged.opening, '新开局'); // 基底的新内容
      expect(merged.worldBook, '新世界书');
    });

    test('key/version always come from the base, never the overlay', () {
      const base = Story(id: 's', key: 'k', version: '1.0.0', name: 'S');
      final edited = Story(
        id: 's',
        key: '',
        version: '',
        name: 'S',
        opening: 'x',
      );
      final overlay = StoryStore.storyDiff(base, edited);
      expect(overlay.containsKey('key'), isFalse);
      expect(overlay.containsKey('version'), isFalse);

      // 即便旧覆盖层里残留了 key/version，也以基底为准
      final merged = StoryStore.storyMerge(base, {
        'opening': 'y',
        'key': '',
        'version': '',
      });
      expect(merged.key, 'k');
      expect(merged.version, '1.0.0');
      expect(merged.opening, 'y');
    });

    test('rollDice grades into four outcome tiers', () {
      final outcomes = {
        for (var i = 0; i < 400; i++) rollDice('1d20', dc: 10).outcome,
      };
      expect(outcomes.contains('success'), isTrue);
      expect(outcomes.contains('failure'), isTrue);
      expect(outcomes.contains('critSuccess'), isTrue);
      expect(outcomes.contains('critFailure'), isTrue);

      // 关闭大成功/大失败后只剩两档
      final plain = {
        for (var i = 0; i < 400; i++)
          rollDice('1d20', dc: 10, crits: false).outcome,
      };
      expect(plain.contains('critSuccess'), isFalse);
      expect(plain.contains('critFailure'), isFalse);
    });

    test('filterWorldBook supports 触发 annotations (progressive)', () {
      const wb =
          '【种族】\n'
          '- **精灵**（触发：精灵、elf）：精灵介绍\n'
          '- **兽人**（触发：兽人）：兽人介绍\n';
      final hit = filterWorldBook(wb, const {}, scanText: '我遇到一个 elf 斥候');
      expect(hit.contains('精灵介绍'), isTrue);
      expect(hit.contains('兽人介绍'), isFalse);
      // 无扫描文本时不裁剪（向后兼容）
      final all = filterWorldBook(wb, const {});
      expect(all.contains('精灵介绍'), isTrue);
      expect(all.contains('兽人介绍'), isTrue);
    });

    test('rollDice supports keep-high / keep-low notation', () {
      // 取高：总和只由最高的一颗决定
      final high = rollDice('2d20kh1', crits: false);
      expect(high.total, high.dice.reduce((a, b) => a > b ? a : b));
      // 取低：总和只由最低的一颗决定
      final low = rollDice('2d20kl1', crits: false);
      expect(low.total, low.dice.reduce((a, b) => a < b ? a : b));
      // 中文写法等价
      final cn = rollDice('2d20取低1', crits: false);
      expect(cn.total, cn.dice.reduce((a, b) => a < b ? a : b));
    });

    test('rollDice honours low-is-better direction', () {
      // 取低：总值 ≤ DC 为成功；掷 1 为大成功、掷最大点为大失败
      expect(
        rollDice(
          '1d20',
          modifier: -100,
          dc: 10,
          direction: 'low',
          crits: false,
        ).success,
        isTrue,
      );
      expect(
        rollDice(
          '1d20',
          modifier: 100,
          dc: 10,
          direction: 'low',
          crits: false,
        ).success,
        isFalse,
      );
    });

    test('mergeSettingLibrary merges codex/title/job/facility', () {
      const story = Story(id: 's', name: 'S');
      final merged = mergeSettingLibrary(story, const [
        SettingEntry(
          id: '1',
          type: SettingTypes.codex,
          name: '剑',
          payload: {
            'kind': 'item',
            'key': 'sword',
            'name': '剑',
            'mechanics': '攻击+3',
          },
        ),
        SettingEntry(
          id: '2',
          type: SettingTypes.title,
          name: '勇者',
          payload: {'key': 'hero', 'name': '勇者', 'effects': '力量+2'},
        ),
        SettingEntry(
          id: '3',
          type: SettingTypes.job,
          name: '游侠',
          payload: {'name': '游侠', 'levels': []},
        ),
        SettingEntry(
          id: '4',
          type: SettingTypes.facility,
          name: '锻造台',
          payload: {'key': 'forge', 'name': '锻造台', 'maxLevel': 3},
        ),
      ]);
      expect(merged.codex.single.name, '剑');
      expect(merged.titles.single.name, '勇者');
      expect(merged.job?.name, '游侠');
      expect(merged.facilities.single.name, '锻造台');
    });

    test('generation params round trip', () {
      const story = Story(
        id: 's',
        name: 'S',
        temperature: 0.8,
        topP: 0.9,
        maxTokens: 2048,
      );
      final md = StoryStore.storyToMarkdown(story);
      final back = StoryStore.storyFromMarkdown(md, id: 's');
      expect(back.temperature, 0.8);
      expect(back.topP, 0.9);
      expect(back.maxTokens, 2048);
    });

    test('death resources and mode round trip', () {
      const story = Story(
        id: 's',
        name: 'S',
        deathResources: ['生命', '精神'],
        deathMode: 'all',
      );
      final md = StoryStore.storyToMarkdown(story);
      final back = StoryStore.storyFromMarkdown(md, id: 's');
      expect(back.deathMode, 'all');
      expect(back.deathResources, ['生命', '精神']);
    });
  });
}
