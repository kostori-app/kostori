import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/search_history.dart';
import 'package:kostori/foundation/text_rule.dart';

void main() {
  group('SourceLocalConfig（存在番源 data 文件里的配置）', () {
    test('规则 id 列表：空列表会清除该键', () {
      final data = <String, dynamic>{};
      expect(SourceLocalConfig.ruleIdsIn(data), isEmpty);

      SourceLocalConfig.setRuleIdsIn(data, ['a', 'b']);
      expect(data['textRuleIds'], ['a', 'b']);
      expect(SourceLocalConfig.ruleIdsIn(data), ['a', 'b']);

      SourceLocalConfig.setRuleIdsIn(data, []);
      expect(data.containsKey('textRuleIds'), isFalse);
    });

    test('下载标题格式：空白视为未设置', () {
      final data = <String, dynamic>{};
      expect(SourceLocalConfig.titleFormatIn(data), '');

      SourceLocalConfig.setTitleFormatIn(data, '  {title} - {episode} ');
      expect(SourceLocalConfig.titleFormatIn(data), '{title} - {episode}');

      SourceLocalConfig.setTitleFormatIn(data, '   ');
      expect(data.containsKey('downloadTitleFormat'), isFalse);
    });

    test('写入时不破坏源数据里的其它键', () {
      final data = <String, dynamic>{
        'account': ['user', 'pass'],
      };
      SourceLocalConfig.setRuleIdsIn(data, ['r1']);
      expect(data['account'], ['user', 'pass']);
      expect(data['textRuleIds'], ['r1']);
    });
  });

  group('SearchHistoryItem', () {
    test('json 往返', () {
      const item = SearchHistoryItem(
        keyword: '关键词',
        useCount: 3,
        lastUsedAt: 1712345678,
      );
      final back = SearchHistoryItem.fromJson(item.toJson());
      expect(back.keyword, '关键词');
      expect(back.useCount, 3);
      expect(back.lastUsedAt, 1712345678);
    });

    test('字段缺失时用默认值', () {
      final back = SearchHistoryItem.fromJson(const {});
      expect(back.keyword, '');
      expect(back.useCount, 0);
      expect(back.lastUsedAt, 0);
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
