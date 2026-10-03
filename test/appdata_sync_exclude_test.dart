import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    // syncData 末尾会写 appdata.json，测试里给它一个临时目录
    tempDir = Directory.systemTemp.createTempSync('kostori_sync_test');
    App.dataPath = tempDir.path;
  });

  // saveData 是异步落盘，测试结束时文件可能还被占用，删不掉也无所谓
  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('WebDAV同步排除项', () {
    tearDown(() {
      appdata.settings['enableNoProxyOverrides'] = true;
      appdata.settings['proxy'] = 'system';
    });

    test('远端的无代理覆盖总开关不会覆盖本机设置', () {
      appdata.settings['enableNoProxyOverrides'] = true;
      appdata.syncData({
        'settings': {'enableNoProxyOverrides': false},
      });
      expect(appdata.settings['enableNoProxyOverrides'], isTrue);
    });

    test('本机关闭时也不会被远端的默认值打开', () {
      appdata.settings['enableNoProxyOverrides'] = false;
      appdata.syncData({
        'settings': {'enableNoProxyOverrides': true},
      });
      expect(appdata.settings['enableNoProxyOverrides'], isFalse);
    });

    test('其余设置照常合并，排除列表里的旧键也不受影响', () {
      appdata.syncData({
        'settings': {'proxy': 'none', 'animeTileScale': 1.5},
      });
      expect(appdata.settings['proxy'], 'system', reason: 'proxy 本就在排除列表');
      expect(appdata.settings['animeTileScale'], 1.5);
    });

    test('syncableSettingsJson 剔除设备本地键', () {
      appdata.settings['enableNoProxyOverrides'] = false;
      appdata.settings['proxy'] = 'none';
      final out = appdata.syncableSettingsJson();
      expect(out.containsKey('enableNoProxyOverrides'), isFalse);
      expect(out.containsKey('proxy'), isFalse);
      expect(out.containsKey('webdav'), isFalse);
      expect(out.containsKey('animeTileScale'), isTrue);
    });

    test('两端本地键不同也不会让导出内容产生差异', () {
      appdata.settings['enableNoProxyOverrides'] = true;
      appdata.settings['proxy'] = 'system';
      appdata.settings['animeTileScale'] = 1.25;
      final a = appdata.syncableSettingsJson();

      appdata.settings['enableNoProxyOverrides'] = false;
      appdata.settings['proxy'] = 'none';
      final b = appdata.syncableSettingsJson();

      expect(b, equals(a));
    });
  });
}
