// 番剧信息技能：查询观看历史 + 搜索番剧并跳转详情页。
// 这些技能读取软件本地数据（观看历史 / 收藏），供 AI 聊天调用。

import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/skills/skill.dart';

/// 依据 appdata 的 statsSelectors 判定该类型是否在统计/历史筛选范围内：
/// Bangumi 始终包含；其余需在可选来源中，且未被筛选器排除。
bool _isIncludedType(AnimeType type) {
  final existingTypes = AnimeSource.all()
      .map((a) => AnimeType.fromKey(a.name).value)
      .toSet();
  if (type.value == AnimeType.fromKey('bangumi').value) return true;
  if (!existingTypes.contains(type.value)) return false;
  final selectors = appdata.settings['statsSelectors'];
  if (selectors is! List || selectors.isEmpty) return true;
  return selectors.contains(type.value);
}

/// 查询收藏：按文件夹或名称查看收藏的番剧列表与数量
class QueryFavoritesSkill extends Skill {
  @override
  String get id => 'query_favorites';

  @override
  String get name => '查询收藏';

  @override
  String get description =>
      '查询用户在软件内的番剧收藏。可按名称搜索、查看某个文件夹或全部收藏的数量与列表。'
      '例如"我收藏了什么番"、"我的追番列表"、"在xxx文件夹里收藏了哪些"。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '按名称搜索收藏，可为空'},
      'folder': {'type': 'string', 'description': '收藏夹名称，可为空（空表示全部）'},
    },
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final name = (arguments['name'] as String? ?? '').trim();
    final folder = (arguments['folder'] as String? ?? '').trim();

    List<FavoriteItem> items;
    if (folder.isNotEmpty) {
      items = LocalFavoritesManager().getAllAnimes(folder);
    } else {
      items = LocalFavoritesManager().allAnimes();
    }
    if (name.isNotEmpty) {
      items = items.where((f) => f.name.contains(name)).toList();
    }
    if (items.isEmpty) {
      final scope = folder.isNotEmpty ? '文件夹"$folder"' : '全部收藏';
      final kw = name.isNotEmpty ? '与"$name"相关' : '';
      return '$scope$kw中没有找到番剧。';
    }
    final sb = StringBuffer();
    sb.writeln(
      '${folder.isNotEmpty ? '文件夹"$folder"' : '全部收藏'}共 ${items.length} 部：',
    );
    for (var i = 0; i < items.length && i < 20; i++) {
      final f = items[i];
      final folderTag = f is FavoriteItemWithFolderInfo ? '（${f.folder}）' : '';
      sb.writeln('${i + 1}. ${f.name}$folderTag');
    }
    if (items.length > 20) sb.writeln('…共 ${items.length} 部');
    return sb.toString();
  }
}

/// 查询观看统计：总观看时长 / 已看与收藏数 / 某部番或某天的观看情况
class QueryWatchStatsSkill extends Skill {
  @override
  String get id => 'query_watch_stats';

  @override
  String get name => '查询观看统计';

  @override
  String get description =>
      '查询番剧观看统计：总观看时长、看过的番剧数、收藏/喜欢数。'
      '可按番名（name）查询某部番的累计观看时长，或按日期（date，YYYY-MM-DD）查询某天的观看情况。'
      '例如"我总共看了多久的番"、"我看了多少部番"、"《XXX》我看了多久"。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '番剧名称，可为空'},
      'date': {'type': 'string', 'description': '日期（YYYY-MM-DD），可为空'},
    },
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final name = (arguments['name'] as String? ?? '').trim();
    final dateStr = (arguments['date'] as String? ?? '').trim();

    final manager = StatsManager();
    if (!manager.isInitialized) await manager.init();
    final all = await manager.getStatsAll();
    if (all.isEmpty) return '暂无观看统计数据。';

    if (name.isNotEmpty) {
      final matched = all.where((s) => (s.title ?? '').contains(name)).toList();
      if (matched.isEmpty) return '没有找到"$name"的观看统计数据。';
      final totalMs = _sumWatchMs(matched);
      final sb = StringBuffer();
      sb.writeln(
        '《$name》相关 ${matched.length} 条记录，累计观看 ${_fmtDuration(totalMs)}',
      );
      for (final s in matched) {
        sb.writeln('· ${s.title ?? '未知'}');
        final clicks = _sumRecords(s.totalClickCount);
        if (clicks > 0) sb.writeln('  累计点击 $clicks 次');
        final rating = _lastRating(s.rating);
        if (rating != null) sb.writeln('  评分 $rating');
        final comments = _commentCount(s.comment);
        if (comments > 0) sb.writeln('  评论 $comments 条');
        final fav = s.liked
            ? '已喜欢'
            : (_favoriteCount(s.favorite) > 0 ? '已收藏' : '');
        if (fav.isNotEmpty) sb.writeln('  $fav');
        final first = s.firstClickTime;
        final last = s.lastClickTime;
        if (first != null || last != null) {
          sb.writeln('  首次 ${_fmtDt(first)} · 最近 ${_fmtDt(last)}');
        }
      }
      return sb.toString();
    }

    if (dateStr.isNotEmpty) {
      final target = DateTime.tryParse(dateStr);
      if (target == null) return '日期格式应为 YYYY-MM-DD';
      var dayMs = 0;
      final titles = <String>[];
      for (final s in all) {
        for (final d in s.totalWatchDurations) {
          for (final r in d.platformEventRecords) {
            if (r.date != null &&
                r.date!.year == target.year &&
                r.date!.month == target.month &&
                r.date!.day == target.day) {
              dayMs += r.value;
              if (!titles.contains(s.title)) titles.add(s.title ?? '未知');
            }
          }
        }
      }
      if (dayMs == 0) return '$dateStr当天没有观看记录。';
      return '$dateStr观看时长 ${_fmtDuration(dayMs)}，涉及番剧：${titles.join('、')}';
    }

    final totalMs = _sumWatchMs(all);
    final liked = all.where((s) => s.liked).length;
    final sb = StringBuffer();
    sb.writeln('累计观看 ${_fmtDuration(totalMs)}');
    sb.writeln('看过 ${all.length} 条记录（按番剧可能合并）');
    sb.writeln('喜欢/收藏 $liked 部');
    return sb.toString();
  }

  static int _sumWatchMs(List<StatsDataImpl> stats) {
    var ms = 0;
    for (final s in stats) {
      for (final d in s.totalWatchDurations) {
        for (final r in d.platformEventRecords) {
          ms += r.value;
        }
      }
    }
    return ms;
  }

  static String _fmtDuration(int ms) {
    final totalMin = ms ~/ 60000;
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h > 0) return '$h 小时 $m 分钟';
    return '$m 分钟';
  }

  static int _sumRecords(List<DailyEvent> events) {
    var v = 0;
    for (final d in events) {
      for (final r in d.platformEventRecords) {
        v += r.value;
      }
    }
    return v;
  }

  static int? _lastRating(List<DailyEvent> events) {
    int? last;
    for (final d in events) {
      for (final r in d.platformEventRecords) {
        if (r.rating != null) last = r.rating;
      }
    }
    return last;
  }

  static int _commentCount(List<DailyEvent> events) {
    var c = 0;
    for (final d in events) {
      for (final r in d.platformEventRecords) {
        if (r.comment != null && r.comment!.isNotEmpty) c++;
      }
    }
    return c;
  }

  static int _favoriteCount(List<DailyEvent> events) {
    var c = 0;
    for (final d in events) {
      for (final r in d.platformEventRecords) {
        if (r.favorite != null ||
            r.favoriteType != null ||
            r.favoriteAction != null) {
          c++;
        }
      }
    }
    return c;
  }

  static String _fmtDt(DateTime? dt) {
    if (dt == null) return '无';
    return '${dt.year}-${dt.month}-${dt.day}';
  }
}

/// 查询观看历史：按时间范围返回该段时间看过的番剧
class QueryWatchHistorySkill extends Skill {
  @override
  String get id => 'query_watch_history';

  @override
  String get name => '查询观看历史';

  @override
  String get description =>
      '查询用户在软件内的番剧观看历史。可按时间范围查询某段时间看了哪些番、看了几部，'
      '例如"这个月看了什么"、"上个月到本月看了几部番"。'
      'start_date / end_date 格式为 YYYY-MM-DD（如 2026-01-01），可只填其一，不填表示不限。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'start_date': {'type': 'string', 'description': '起始日期（YYYY-MM-DD），可为空'},
      'end_date': {'type': 'string', 'description': '结束日期（YYYY-MM-DD），可为空'},
    },
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final start = arguments['start_date'] as String?;
    final end = arguments['end_date'] as String?;
    final startDt = _parseDate(start);
    final endDt = _parseDate(end);
    final endInclusive = endDt?.add(const Duration(days: 1));

    final manager = HistoryManager();
    if (!manager.isInitialized) await manager.init();
    final all = await manager.getAll();
    // 遵循统计/历史筛选（statsSelectors）：只返回筛选范围内的来源
    final filteredAll = all.where((h) => _isIncludedType(h.type)).toList();
    final filtered = filteredAll.where((h) {
      if (startDt != null && h.time.isBefore(startDt)) return false;
      if (endInclusive != null && !h.time.isBefore(endInclusive)) return false;
      return true;
    }).toList();

    // 按标题去重（同一部番多集只算一部）
    final seen = <String>{};
    final items = <History>[];
    for (final h in filtered) {
      if (seen.add(h.title)) items.add(h);
    }

    if (items.isEmpty) {
      return '在${_rangeText(start, end)}内没有找到观看记录。';
    }
    final sb = StringBuffer();
    sb.writeln('${_rangeText(start, end)}共观看了 ${items.length} 部番剧：');
    for (var i = 0; i < items.length; i++) {
      final h = items[i];
      sb.writeln('${i + 1}. 《${h.title}》（${_fmtTime(h.time)}）');
    }
    return sb.toString();
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return DateTime.tryParse(s.trim());
  }

  static String _fmtTime(DateTime t) => '${t.year}-${t.month}-${t.day}';

  static String _rangeText(String? start, String? end) {
    if (start == null && end == null) return '全部时间';
    return '${start ?? '最早'} ~ ${end ?? '今天'}';
  }
}

/// 搜索番剧：在本地收藏 / 观看历史中按名称搜索，可打开详情页
class SearchAnimeSkill extends Skill {
  @override
  String get id => 'search_anime';

  @override
  String get name => '打开番剧详情';

  @override
  String get description =>
      '在软件内的本地数据（收藏、观看历史）中按名称搜索番剧，并打开**软件内番剧详情页（AnimePage）**。'
      '当用户提到一个番名、想查看或直接打开它时调用。'
      '若用户明确要求"打开 / 跳转 / 查看详情页"，将 open 设为 true，会打开软件内番剧详情页（区别于 Bangumi 页面）。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '番剧名称'},
      'open': {
        'type': 'boolean',
        'description': '是否打开软件内番剧详情页（AnimePage，区别于 Bangumi 页面）',
      },
    },
    'required': ['name'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final name = (arguments['name'] as String? ?? '').trim();
    final open = arguments['open'] == true;
    if (name.isEmpty) throw SkillException('缺少番剧名称');

    final results =
        <({String id, String sourceKey, String title, String? cover})>[];

    // 收藏
    try {
      for (final f in LocalFavoritesManager().allAnimes()) {
        if (f.name.contains(name)) {
          results.add((
            id: f.id,
            sourceKey: f.sourceKey,
            title: f.name,
            cover: f.coverPath,
          ));
        }
      }
    } catch (_) {}

    // 观看历史
    try {
      final manager = HistoryManager();
      if (!manager.isInitialized) await manager.init();
      for (final h in await manager.getAll()) {
        if (h.title.contains(name)) {
          if (!results.any((r) => r.title == h.title)) {
            results.add((
              id: h.id,
              sourceKey: h.sourceKey,
              title: h.title,
              cover: h.cover,
            ));
          }
        }
      }
    } catch (_) {}

    if (results.isEmpty) {
      return '没有在本地找到与"$name"相关的番剧。';
    }
    final sb = StringBuffer();
    sb.writeln('在本地找到 ${results.length} 个相关结果：');
    for (var i = 0; i < results.length && i < 10; i++) {
      sb.writeln('${i + 1}. ${results[i].title}');
    }
    if (open) {
      final first = results.first;
      final ctx = App.mainNavigatorKey?.currentContext;
      if (ctx != null) {
        try {
          ctx.to(
            () => AnimePage(
              id: first.id,
              sourceKey: first.sourceKey,
              cover: first.cover,
              title: first.title,
            ),
          );
          sb.writeln('已为你打开《${first.title}》的详情页。');
        } catch (_) {
          sb.writeln('（打开详情页失败，可手动搜索）');
        }
      } else {
        sb.writeln('（当前无法跳转页面）');
      }
    }
    return sb.toString();
  }
}
