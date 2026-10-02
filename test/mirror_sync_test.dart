import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/network/mirror_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('镜像配置同步', () {
    setUp(() => appdata.implicitData.clear());

    test('远端更新时间更新时覆盖本地镜像配置', () {
      appdata.implicitData['githubMirror'] = 'https://old.example/';
      appdata.implicitData[mirrorConfigUpdatedAtKey] = 100;

      final changed = importMirrorConfig({
        'githubMirror': 'https://new.example/',
        'bangumiMirror': 'https://bgm.example/',
        'updatedAt': 200,
      });
      expect(changed, isTrue);
      expect(appdata.implicitData['githubMirror'], 'https://new.example/');
      expect(appdata.implicitData['bangumiMirror'], 'https://bgm.example/');
      expect(appdata.implicitData[mirrorConfigUpdatedAtKey], 200);
    });

    test('远端更旧时不覆盖本地', () {
      appdata.implicitData['githubMirror'] = 'https://local.example/';
      appdata.implicitData[mirrorConfigUpdatedAtKey] = 300;

      expect(
        importMirrorConfig({
          'githubMirror': 'https://older.example/',
          'updatedAt': 200,
        }),
        isFalse,
      );
      expect(appdata.implicitData['githubMirror'], 'https://local.example/');
    });

    test('导出带上镜像列表、选择与更新时间', () {
      appdata.implicitData['githubMirrors'] = [
        {'name': 'gh', 'url': 'https://gh.example/', 'scope': 'all'},
      ];
      appdata.implicitData[mirrorConfigUpdatedAtKey] = 123;

      final exported = exportMirrorConfig();
      expect(exported['githubMirrors'], isA<List>());
      expect(exported['updatedAt'], 123);
    });

    test('markMirrorConfigChanged 刷新时间戳', () {
      appdata.implicitData[mirrorConfigUpdatedAtKey] = 0;
      markMirrorConfigChanged();
      expect(appdata.implicitData[mirrorConfigUpdatedAtKey], greaterThan(0));
    });
  });
}
