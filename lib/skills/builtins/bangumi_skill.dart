// Bangumi 查询技能：条目 / 角色 / 声优，支持跳转 bangumi 详情页。
// 通过 lib/network/bangumi.dart 的 Bangumi API 与 lib/database/bangumi.dart 缓存查询。

import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/skills/skill.dart';

/// 打开 bangumi 条目详情页
void _openBangumiPage(BangumiItem item) {
  final ctx = App.mainNavigatorKey?.currentContext;
  if (ctx == null) return;
  try {
    ctx.to(() => BangumiInfoPage(bangumiItem: item));
  } catch (_) {}
}

/// 查询 Bangumi 条目（番剧/动画/书籍等）
class SearchBangumiSkill extends Skill {
  @override
  String get id => 'search_bangumi';

  @override
  String get name => '查询Bangumi条目';

  @override
  String get description =>
      '在 Bangumi 上搜索条目（动画/漫画/书籍/游戏等），返回名称、类型、排名与简介。'
      '当用户提到番剧名想查询条目信息、或明确要求"打开 / 跳转到 Bangumi"时调用。'
      '若用户要打开详情页，将 open 设为 true。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'keyword': {'type': 'string', 'description': '搜索关键词（番剧/条目名称）'},
      'open': {'type': 'boolean', 'description': '是否打开第一个结果的 Bangumi 详情页'},
    },
    'required': ['keyword'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final keyword = (arguments['keyword'] as String? ?? '').trim();
    final open = arguments['open'] == true;
    if (keyword.isEmpty) throw SkillException('缺少搜索关键词');

    List<BangumiItem> items;
    try {
      items = await Bangumi.instance.bangumiPostSearch(keyword);
    } catch (_) {
      items = await Bangumi.instance.combinedBangumiSearch(keyword);
    }
    if (items.isEmpty) return '没有在 Bangumi 找到与"$keyword"相关的条目。';

    final sb = StringBuffer();
    sb.writeln('在 Bangumi 找到 ${items.length} 个相关条目：');
    for (var i = 0; i < items.length && i < 8; i++) {
      final it = items[i];
      final title = it.nameCn.isNotEmpty ? it.nameCn : it.name;
      final rank = it.rank > 0 ? '（排名 ${it.rank}）' : '';
      sb.writeln('${i + 1}. $title$rank');
    }
    if (items.length > 8) sb.writeln('…共 ${items.length} 个');
    if (open) {
      _openBangumiPage(items.first);
      final title = items.first.nameCn.isNotEmpty
          ? items.first.nameCn
          : items.first.name;
      sb.writeln('已为你打开《$title》的 Bangumi 页面。');
    }
    return sb.toString();
  }
}

/// 查询某部 Bangumi 条目的角色与声优
class QueryBangumiCharactersSkill extends Skill {
  @override
  String get id => 'query_bangumi_characters';

  @override
  String get name => '查询Bangumi角色';

  @override
  String get description =>
      '查询某部 Bangumi 条目的角色列表及其配音声优。'
      '输入条目名称（name）或条目 id（id）。例如"《XXX》有哪些角色"。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '条目名称，可与 id 二选一'},
      'id': {'type': 'integer', 'description': 'Bangumi 条目 id，可与 name 二选一'},
    },
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final name = (arguments['name'] as String? ?? '').trim();
    final id = arguments['id'];
    int? subjectId = id is int ? id : null;

    if (subjectId == null && name.isNotEmpty) {
      final items = await Bangumi.instance.bangumiPostSearch(name);
      if (items.isEmpty) return '没有找到"$name"对应的条目。';
      subjectId = items.first.id;
    }
    if (subjectId == null) throw SkillException('需要提供条目名称或 id');

    final response = await Bangumi.instance.getCharatersByID(subjectId);
    final list = response.characterList;
    if (list.isEmpty) return '该条目暂无角色数据。';

    final sb = StringBuffer();
    sb.writeln('共 ${list.length} 个角色：');
    for (var i = 0; i < list.length && i < 20; i++) {
      final c = list[i];
      final relation = c.relation.isNotEmpty ? '（${c.relation}）' : '';
      final actors = c.actorList
          .map((a) => a.name)
          .where((n) => n.isNotEmpty)
          .join('、');
      sb.write('${i + 1}. ${c.name}$relation');
      if (actors.isNotEmpty) sb.write(' —— CV: $actors');
      sb.writeln();
    }
    if (list.length > 20) sb.writeln('…共 ${list.length} 个角色');
    return sb.toString();
  }
}

/// 搜索声优（人物）
class SearchBangumiPersonSkill extends Skill {
  @override
  String get id => 'search_bangumi_person';

  @override
  String get name => '搜索声优';

  @override
  String get description =>
      '在 Bangumi 上按名称搜索声优（配音演员/制作人员等人物），返回其名称与简介。'
      '例如"XXX是谁配音的"、"搜索声优 花泽香菜"。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '声优/人物名称'},
    },
    'required': ['name'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final name = (arguments['name'] as String? ?? '').trim();
    if (name.isEmpty) throw SkillException('缺少搜索关键词');

    final list = await Bangumi.instance.postPersonsSearchByStringNext(
      keyword: name,
    );
    if (list.isEmpty) return '没有在 Bangumi 找到与"$name"相关的人物。';

    final sb = StringBuffer();
    sb.writeln('找到 ${list.length} 个相关人物：');
    for (var i = 0; i < list.length && i < 10; i++) {
      final p = list[i];
      final title = p.nameCN.isNotEmpty ? p.nameCN : p.name;
      sb.writeln('${i + 1}. $title');
    }
    return sb.toString();
  }
}
