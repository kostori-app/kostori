import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/js_engine.dart';

void main() {
  group('jsBytesOf', () {
    test('Uint8List / List 直接归一化', () {
      expect(jsBytesOf(Uint8List.fromList([1, 2, 3])), [1, 2, 3]);
      expect(jsBytesOf(<dynamic>[1, 2, 3]), [1, 2, 3]);
      expect(jsBytesOf(<dynamic>[1.9, 2.1]), [1, 2]);
    });

    test('flutter_qjs 桥接成 Map 时按数字下标取字节', () {
      // Uint8Array 有时会变成 {0:..,1:..} 的 Map（可能带附加字段）
      expect(jsBytesOf({'0': 1, '1': 2, '2': 3}), [1, 2, 3]);
      expect(jsBytesOf({0: 1, 1: 2, 'byteLength': 2}), [1, 2]);
      expect(jsBytesOf(<dynamic, dynamic>{}), isNull);
      // 下标不连续 → 不是字节数组
      expect(jsBytesOf({'0': 1, '3': 4}), isNull);
    });

    test('非字节数据返回 null', () {
      expect(jsBytesOf(null), isNull);
      expect(jsBytesOf('abc'), isNull);
      expect(jsBytesOf({'a': 'b'}), isNull);
      expect(jsBytesOf(<dynamic>[1, 'a']), isNull);
    });
  });
}
