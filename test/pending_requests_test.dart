import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/pending_requests.dart';

void main() {
  group('PendingRequests', () {
    test('register/complete 正常配对', () async {
      final p = PendingRequests<String>();
      final a = p.register();
      final b = p.register();
      expect(a.id != b.id, isTrue);
      expect(p.length, 2);
      p.complete(a.id, 'x');
      expect(await a.future, 'x');
      expect(p.length, 1);
    });

    test('迟到/重复结算返回 false 且不抛', () async {
      final p = PendingRequests<String>();
      final a = p.register();
      expect(p.complete(a.id, 'x'), isTrue);
      expect(p.complete(a.id, 'y'), isFalse);
      expect(p.completeError(999, 'e'), isFalse);
      expect(await a.future, 'x');
      expect(p.isEmpty, isTrue);
    });

    test('completeError 透出异常', () async {
      final p = PendingRequests<String>();
      final a = p.register();
      p.completeError(a.id, StateError('boom'));
      await expectLater(a.future, throwsStateError);
    });

    test('超时删表项（不堆积孤儿）', () async {
      final p = PendingRequests<String>();
      final a = p.registerWithTimeout(
        const Duration(milliseconds: 20),
        () => TimeoutException('t', const Duration(milliseconds: 20)),
      );
      await expectLater(a.future, throwsA(isA<TimeoutException>()));
      expect(p.isEmpty, isTrue);
      // worker 晚回：找不到表项直接丢弃
      expect(p.complete(a.id, 'late'), isFalse);
    });

    test('settleAllError 一键结算全部', () async {
      final p = PendingRequests<String>();
      final a = p.register();
      final b = p.register();
      p.settleAllError(StateError('closed'));
      await expectLater(a.future, throwsStateError);
      await expectLater(b.future, throwsStateError);
      expect(p.isEmpty, isTrue);
    });
  });
}
