import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/utils/utils.dart';

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
