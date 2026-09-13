import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
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
