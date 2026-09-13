import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/ai_service/character_lorebook.dart';
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
    137, 80, 78, 71, 13, 10, 26, 10,
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
    137, 80, 78, 71, 13, 10, 26, 10,
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
      expect(Utils.isSameMonth(DateTime(2026, 1, 1), DateTime(2026, 1, 31)), isTrue);
      expect(Utils.isSameMonth(DateTime(2026, 1, 1), DateTime(2026, 2, 1)), isFalse);
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
      expect(Utils.isSameYear(DateTime(2026, 1, 1), DateTime(2026, 12, 31)), isTrue);
      expect(Utils.isSameYear(DateTime(2026, 12, 31), DateTime(2027, 1, 1)), isFalse);
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
      final embedded = CharacterCard.embedCharaChunk(
        png,
        card.toCharaText(),
      );
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

    List<String> contents(String text, {int turn = 1}) => CharacterLorebookResolver
        .instance
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
      expect(
        list.indexOf('常驻设定。'),
        lessThan(list.indexOf('龙是古代生物。')),
      );
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
}
