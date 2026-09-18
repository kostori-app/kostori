import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:path/path.dart' as p;

void main() {
  test('连接关闭后重开不会出现 drift 多实例告警', () async {
    final dir = Directory.systemTemp.createTempSync('kostori_cookie_test');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    final uri = Uri.parse('https://example.com/path');

    final messages = <String>[];
    final originalPrint = driftRuntimeOptions.debugPrint;
    driftRuntimeOptions.debugPrint = (msg) => messages.add(msg);
    addTearDown(() => driftRuntimeOptions.debugPrint = originalPrint);

    final jar = CookieJarSql(p.join(dir.path, 'cookie.db'));
    await jar.saveFromResponse(uri, [Cookie('k', 'v')]);
    expect(await jar.loadForRequestCookieHeader(uri), contains('k=v'));

    // 强制关闭连接，下一次操作会走「连接已关闭 → 重开」恢复路径
    await jar.close();
    expect(await jar.loadForRequestCookieHeader(uri), contains('k=v'));
    expect(await jar.loadForRequestCookieHeader(uri), contains('k=v'));

    await jar.close();

    final multi = messages.where((m) => m.contains('multiple times'));
    expect(multi, isEmpty);
  });
}
