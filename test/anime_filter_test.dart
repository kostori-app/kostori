import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/anime_filter.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';

Anime _anime({
  String title = '',
  String id = '1',
  String? subtitle,
  List<String>? tags,
  String description = '',
  String language = '',
}) => Anime(title, '', id, subtitle, tags, description, 'src', language, null);

void main() {
  test('关键词匹配卡片展示数据（标题/副标题/标签/简介/语言，忽略大小写）', () {
    final a = _anime(
      title: '进击的巨人',
      subtitle: 'Attack on Titan',
      tags: ['热血', 'Action'],
      description: '人类最后的堡垒',
      language: 'ja',
    );
    expect(const AnimeFilter(keyword: '巨人').matches(a), isTrue);
    expect(const AnimeFilter(keyword: 'attack').matches(a), isTrue);
    expect(const AnimeFilter(keyword: '热血').matches(a), isTrue);
    expect(const AnimeFilter(keyword: '堡垒').matches(a), isTrue);
    expect(const AnimeFilter(keyword: 'JA').matches(a), isTrue);
    expect(const AnimeFilter(keyword: '不存在').matches(a), isFalse);
  });

  test('未设置条件时 apply 原样返回；设置关键词时过滤', () {
    final list = [_anime(title: 'A', id: '1'), _anime(title: 'B', id: '2')];
    expect(identical(AnimeFilter.apply(list, null), list), isTrue);
    expect(
      identical(AnimeFilter.apply(list, const AnimeFilter()), list),
      isTrue,
    );

    final out = AnimeFilter.apply(list, const AnimeFilter(keyword: 'B'));
    expect(out.length, 1);
    expect(out.first.title, 'B');
  });

  test('isActive：仅空白关键词不算生效', () {
    expect(const AnimeFilter().isActive, isFalse);
    expect(const AnimeFilter(keyword: '   ').isActive, isFalse);
    expect(const AnimeFilter(keyword: 'x').isActive, isTrue);
    expect(const AnimeFilter(favorite: AnimeFilterMode.only).isActive, isTrue);
    expect(
      const AnimeFilter(history: AnimeFilterMode.exclude).isActive,
      isTrue,
    );
    expect(const AnimeFilter(download: AnimeFilterMode.only).isActive, isTrue);
    expect(const AnimeFilter(subtitle: AnimeFilterMode.only).isActive, isTrue);
  });

  test('三态条件：only / exclude 分别要求有 / 没有对应字段', () {
    final withSubtitle = _anime(id: '1', subtitle: '副标题');
    final withoutSubtitle = _anime(id: '2');

    expect(
      const AnimeFilter(subtitle: AnimeFilterMode.only).matches(withSubtitle),
      isTrue,
    );
    expect(
      const AnimeFilter(subtitle: AnimeFilterMode.only)
          .matches(withoutSubtitle),
      isFalse,
    );
    expect(
      const AnimeFilter(subtitle: AnimeFilterMode.exclude)
          .matches(withoutSubtitle),
      isTrue,
    );
    expect(
      const AnimeFilter(subtitle: AnimeFilterMode.exclude)
          .matches(withSubtitle),
      isFalse,
    );
    // any 不过滤
    expect(const AnimeFilter().matches(withoutSubtitle), isTrue);
  });
}
