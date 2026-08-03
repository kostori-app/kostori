// Bangumi 查询技能：条目 / 角色 / 声优，支持跳转 bangumi 详情页。
// 通过 lib/network/bangumi.dart 的 Bangumi API 与 lib/database/bangumi.dart 缓存查询。

import 'dart:convert';

import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/character/character_casts_item.dart';
import 'package:kostori/foundation/bangumi/character/character_item.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/skills/skill.dart';

/// 序列化候选条目为 [BangumiItem.fromJson] 可重建的 JSON
Map<String, dynamic> _bangumiCardJson(BangumiItem it) => {
  'id': it.id,
  'type': it.type,
  'name': it.name,
  'name_cn': it.nameCn,
  'summary': it.summary,
  'air_date': it.airDate,
  'air_weekday': it.airWeekday,
  'rank': it.rank,
  'total': it.total,
  'total_episodes': it.totalEpisodes,
  'score': it.score,
  'images': it.images,
  'tags': it.tags.map((t) => {'name': t.name, 'count': t.count}).toList(),
  'collection': it.collection,
};

/// 候选卡片标记：UI 据此在消息中渲染 BangumiBriefCard 供用户选择跳转
String _bangumiCardsMarker(List<BangumiItem> items) {
  final list = items.take(10).map(_bangumiCardJson).toList();
  return '[KOSTORI_BANGUMI_CARDS]${jsonEncode(list)}[/KOSTORI_BANGUMI_CARDS]';
}

/// 角色/声优候选卡片标记：UI 据此在消息中渲染 BangumiCharacterCard 供用户选择跳转。
/// [isCharacter] 决定点击后进入角色页还是声优（人物）页。
String _characterCardsMarker(
  List<CharacterActor> items, {
  required bool isCharacter,
}) {
  final list = items.take(10).map((e) => e.toJson()).toList();
  return '[KOSTORI_CHARACTER_CARDS]${jsonEncode({'isCharacter': isCharacter, 'items': list})}[/KOSTORI_CHARACTER_CARDS]';
}

/// 将条目角色（CharacterItem）转为卡片所需的 CharacterActor（名字/头像/关系信息）
CharacterActor _actorFromCharacterItem(CharacterItem c) => CharacterActor(
  id: c.id,
  name: c.name,
  nameCN: c.name,
  comment: 0,
  type: c.type,
  nsfw: false,
  lock: false,
  info: c.relation,
  images: c.avator,
);

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
  String get name => '打开Bangumi详情';

  @override
  String get description =>
      '在 Bangumi 上搜索条目（动画/漫画/书籍/游戏等），返回名称、类型、排名与简介，并打开**Bangumi 详情页（BangumiInfoPage）**。'
      '当用户提到番剧名想查询条目信息、或明确要求"打开 / 跳转到 Bangumi"时调用。'
      '若用户要打开详情页，将 open 设为 true（区别于软件内番剧详情页 AnimePage）。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'keyword': {'type': 'string', 'description': '搜索关键词（番剧/条目名称）'},
      'open': {
        'type': 'boolean',
        'description': '是否打开第一个结果的 Bangumi 详情页（区别于软件内番剧详情页）',
      },
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
    // 多个候选（不确定）时附上卡片标记，UI 渲染 BangumiBriefCard 供用户选择跳转
    if (items.length >= 2) {
      sb.writeln(_bangumiCardsMarker(items));
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
    if (list.isNotEmpty) {
      sb.writeln(
        _characterCardsMarker(
          list.map(_actorFromCharacterItem).toList(),
          isCharacter: true,
        ),
      );
    }
    return sb.toString();
  }
}

/// 搜索角色（人物角色）
class SearchBangumiCharacterSkill extends Skill {
  @override
  String get id => 'search_bangumi_character';

  @override
  String get name => '搜索角色';

  @override
  String get description =>
      '在 Bangumi 上按名称搜索角色（动漫/游戏/书籍等作品中的角色人物），返回其名称与简介。'
      '当用户想查询某个角色、或询问"XX角色是谁"时调用。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '角色名称'},
    },
    'required': ['name'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final name = (arguments['name'] as String? ?? '').trim();
    if (name.isEmpty) throw SkillException('缺少搜索关键词');

    final list = await Bangumi.instance.postCharactersSearchByStringNext(
      keyword: name,
    );
    if (list.isEmpty) return '没有在 Bangumi 找到与"$name"相关的角色。';

    final sb = StringBuffer();
    sb.writeln('找到 ${list.length} 个相关角色：');
    for (var i = 0; i < list.length && i < 10; i++) {
      final c = list[i];
      final title = c.nameCN.isNotEmpty ? c.nameCN : c.name;
      sb.writeln('${i + 1}. $title');
    }
    if (list.isNotEmpty) {
      sb.writeln(_characterCardsMarker(list, isCharacter: true));
    }
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
    if (list.isNotEmpty) {
      sb.writeln(_characterCardsMarker(list, isCharacter: false));
    }
    return sb.toString();
  }
}

/// 分析一部 Bangumi 条目：综合评分 / 收藏状态 / 评分分布 / 评论与吐槽
class AnalyzeBangumiSkill extends Skill {
  static const _collectionLabels = {
    'wish': '想看',
    'doing': '在看',
    'collect': '看过',
    'on_hold': '搁置',
    'dropped': '抛弃',
  };

  @override
  String get id => 'analyze_bangumi';

  @override
  String get name => '分析Bangumi条目';

  @override
  String get description =>
      '综合分析一部 Bangumi 条目：评分与排名、评分人数与星级分布、'
      '想看/在看/看过/搁置/抛弃的收藏数、标签、简介、热门评论与吐槽。'
      '当用户想"分析 / 评价 / 了解风评"一部番时调用，输入条目名称。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '条目名称（番剧/动画名称）'},
    },
    'required': ['name'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final name = (arguments['name'] as String? ?? '').trim();
    if (name.isEmpty) throw SkillException('缺少条目名称');

    // 1. 搜索条目
    List<BangumiItem> items;
    try {
      items = await Bangumi.instance.bangumiPostSearch(name);
    } catch (_) {
      items = await Bangumi.instance.combinedBangumiSearch(name);
    }
    if (items.isEmpty) return '没有在 Bangumi 找到"$name"对应条目。';
    final subjectId = items.first.id;
    final title = items.first.nameCn.isNotEmpty
        ? items.first.nameCn
        : items.first.name;

    final sb = StringBuffer();
    sb.writeln('《$title》 Bangumi 分析：');

    // 2. 条目信息（评分 / 收藏 / 标签 / 简介）
    BangumiItem? info;
    try {
      info = await Bangumi.instance.getBangumiInfoByID(subjectId);
    } catch (_) {}
    if (info != null) {
      sb.writeln(
        '· 评分：${info.score.toStringAsFixed(1)} 分'
        '（${info.total} 人评分，排名第 ${info.rank}）',
      );
      // 星级分布
      if (info.count != null && info.count!.isNotEmpty) {
        final stars = info.count!.entries.toList()
          ..sort((a, b) => int.parse(b.key).compareTo(int.parse(a.key)));
        final dist = stars
            .take(5)
            .map((e) => '${e.key}★${e.value}人')
            .join(' / ');
        sb.writeln('· 评分分布：$dist');
      }
      // 收藏状态
      if (info.collection != null && info.collection!.isNotEmpty) {
        final parts = info.collection!.entries
            .where((e) => e.value > 0)
            .map((e) => '${_collectionLabels[e.key] ?? e.key} ${e.value}')
            .toList();
        if (parts.isNotEmpty) {
          final total = info.collection!.values.fold<int>(0, (a, b) => a + b);
          sb.writeln('· 收藏：${parts.join(' / ')}（共 $total）');
        }
      }
      if (info.totalEpisodes > 0) {
        sb.writeln('· 集数：${info.totalEpisodes} 集 · 开播：${info.airDate}');
      }
      if (info.tags.isNotEmpty) {
        sb.writeln('· 标签：${info.tags.take(10).map((t) => t.name).join('、')}');
      }
      if (info.summary.trim().isNotEmpty) {
        var summary = info.summary.trim().replaceAll('\n', ' ');
        if (summary.length > 300) {
          summary = '${summary.substring(0, 300)}...';
        }
        sb.writeln('· 简介：$summary');
      }
    }

    // 3. 热门评论
    try {
      final comments = await Bangumi.instance.getBangumiCommentsByID(subjectId);
      if (comments.commentList.isNotEmpty) {
        sb.writeln('· 热门评论：');
        for (final c in comments.commentList.take(3)) {
          final user = c.user.nickname;
          var text = c.comment.comment.replaceAll('\n', ' ').trim();
          if (text.length > 120) text = '${text.substring(0, 120)}...';
          if (text.isNotEmpty) sb.writeln('  $user：$text');
        }
      }
    } catch (_) {}

    // 4. 吐槽（长评）
    try {
      final reviews = await Bangumi.instance.getReviewsByID(subjectId);
      if (reviews.reviewsList.isNotEmpty) {
        sb.writeln('· 热门吐槽：');
        for (final r in reviews.reviewsList.take(3)) {
          final user = r.user.nickname;
          var summary = r.entry.summary.replaceAll('\n', ' ').trim();
          if (summary.length > 120) {
            summary = '${summary.substring(0, 120)}...';
          }
          final titleText = r.entry.title.isNotEmpty
              ? '《${r.entry.title}》'
              : '';
          sb.writeln('  $user$titleText（回复 ${r.entry.replies}）$summary');
        }
      }
    } catch (_) {}

    return sb.toString();
  }
}
