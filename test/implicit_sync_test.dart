import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/implicit_keys.dart';
import 'package:kostori/foundation/text_rule.dart';

void main() {
  group('mergeSyncedImplicit', () {
    setUp(() {
      appdata.implicitData = <String, dynamic>{};
    });

    test('远端条目生效、本地独有条目保留', () {
      appdata.implicitData[sourceTextRulesKey] = {
        'sourceA': ['r1'],
        'sourceB': ['r2'],
      };

      appdata.mergeSyncedImplicit({
        sourceTextRulesKey: {
          'sourceA': ['r9'],
          'sourceC': ['r3'],
        },
        downloadTitleFormatsKey: {'sourceA': '{title} - {episode}'},
      });

      expect(appdata.implicitData[sourceTextRulesKey], {
        'sourceA': ['r9'],
        'sourceB': ['r2'],
        'sourceC': ['r3'],
      });
      expect(appdata.implicitData[downloadTitleFormatsKey], {
        'sourceA': '{title} - {episode}',
      });
    });

    test('设备本地设置不参与同步', () {
      appdata.implicitData['downloadDir'] = '/local/path';
      appdata.mergeSyncedImplicit({
        'downloadDir': '/remote/path',
        sourceTextRulesKey: {'a': ['r1']},
      });
      expect(appdata.implicitData['downloadDir'], '/local/path');
    });

    test('远端没有的键不动本地值', () {
      appdata.implicitData[sourceDisplayModesKey] = {'s': 'masonry'};
      appdata.mergeSyncedImplicit({
        sourceTextRulesKey: {'s': ['r1']},
      });
      expect(appdata.implicitData[sourceDisplayModesKey], {'s': 'masonry'});
    });
  });

  group('TextRuleStore.apply', () {
    test('多条规则按列表顺序依次作用，后面的看到前面的结果', () {
      final rules = [
        TextRule(
          id: 'a',
          name: '去字幕组',
          steps: [const TextRuleStep(find: r'^\[[^\]]*\]\s*', replace: '')],
        ),
        TextRule(
          id: 'b',
          name: '小写画质',
          steps: [const TextRuleStep(find: '1080P', replace: '1080p')],
        ),
      ];
      expect(
        TextRuleStore.apply('[字幕组] 示例番剧 - 第01集 [1080P]', rules),
        '示例番剧 - 第01集 [1080p]',
      );
    });

    test('没有匹配到的步骤保持原样，非法正则被跳过', () {
      final rules = [
        TextRule(
          id: 'a',
          name: '不存在的匹配',
          steps: [const TextRuleStep(find: 'zzz', replace: 'y')],
        ),
      ];
      expect(TextRuleStore.apply('abc', rules), 'abc');

      final broken = [
        TextRule(
          id: 'b',
          name: '非法正则',
          steps: [const TextRuleStep(find: '([', replace: 'z')],
        ),
      ];
      expect(TextRuleStore.apply('abc', broken), 'abc');
    });
  });
}
