import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/utils/utils.dart';

/// "现在"固定为 2026-09-26（周六），剧集日期取自 bgm 真实接口（2026 夏季档）。
final DateTime _now = DateTime(2026, 9, 26, 12);
final int _currentWeek = Utils.getISOWeekNumber(_now).$2;

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 构造周更剧集：共 [count] 话，末话在 [lastDate]，sort 从 [firstSort] 递增。
List<EpisodeInfo> _weekly({
  required int count,
  required int firstSort,
  required DateTime lastDate,
}) {
  return List.generate(count, (i) {
    final d = lastDate.subtract(Duration(days: (count - 1 - i) * 7));
    final sort = firstSort + i;
    return EpisodeInfo(
      id: sort,
      sort: sort,
      ep: sort,
      comment: 0,
      type: 0,
      name: 'ep$sort',
      nameCn: '第$sort话',
      airDate: _fmt(d),
      duration: '',
      desc: '',
    );
  });
}

EpisodeResult? _resolve(
  List<EpisodeInfo> episodes, {
  required int seriesTotal,
  required int currentSort,
  String? officialEnd,
}) {
  final current = episodes.firstWhere((e) => e.sort == currentSort);
  return resolveEpisodeResult(
    type0Episodes: episodes,
    currentEpisode: current,
    seriesTotal: seriesTotal,
    now: _now,
    currentWeek: _currentWeek,
    officialEnd: officialEnd != null ? DateTime.parse(officialEnd) : null,
  );
}

void main() {
  group('resolveEpisodeResult — 真实档期数据', () {
    test('入间同学入魔了 第四季：24/24 集、末话今天 → 仍在播', () {
      final eps = _weekly(
        count: 24,
        firstSort: 1,
        lastDate: DateTime(2026, 9, 26),
      );
      final r = _resolve(eps, seriesTotal: 24, currentSort: 24);
      expect(r!.isFinalEpisode, isTrue);
      expect(r.isFinished, isFalse);
    });

    test('摩绪：26/26 集、末话今天 → 仍在播', () {
      final eps = _weekly(
        count: 26,
        firstSort: 1,
        lastDate: DateTime(2026, 9, 26),
      );
      final r = _resolve(eps, seriesTotal: 26, currentSort: 26);
      expect(r!.isFinished, isFalse);
    });

    test('小书痴 领主的养女：末话下周，本周第 23 话 → 仍在播', () {
      final eps = _weekly(
        count: 24,
        firstSort: 1,
        lastDate: DateTime(2026, 10, 3),
      );
      final r = _resolve(eps, seriesTotal: 24, currentSort: 23);
      expect(r!.isFinalEpisode, isFalse);
      expect(r.isFinished, isFalse);
    });

    test('骸骨骑士 第二季：12/12 集、末话 5 天前 → 已完结', () {
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: DateTime(2026, 9, 21),
      );
      final r = _resolve(eps, seriesTotal: 12, currentSort: 12);
      expect(r!.isFinished, isTrue);
    });

    test('地狱模式 第二季：13 集(sort 13-25)，末话昨天 → 宽限期内保留', () {
      final eps = _weekly(
        count: 13,
        firstSort: 13,
        lastDate: DateTime(2026, 9, 25),
      );
      final r = _resolve(eps, seriesTotal: 13, currentSort: 25);
      expect(r!.isFinalEpisode, isTrue);
      expect(r.isFinished, isFalse);
    });

    test('尼古喵喵：已播 12 集但总 13 集 → 未完结，保留', () {
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: DateTime(2026, 9, 24),
      );
      final r = _resolve(eps, seriesTotal: 13, currentSort: 12);
      expect(r!.isFinalEpisode, isTrue);
      expect(r.isFinished, isFalse);
    });

    test('梅比乌斯之尘：12/12 集、末话 2 天前 → 宽限期内保留', () {
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: DateTime(2026, 9, 24),
      );
      final r = _resolve(eps, seriesTotal: 12, currentSort: 12);
      expect(r!.isFinished, isFalse);
    });

    test('文豪野犬 汪！第二季：12/12 集、末话 9 天前 → 已完结', () {
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: DateTime(2026, 9, 17),
      );
      final r = _resolve(eps, seriesTotal: 12, currentSort: 12);
      expect(r!.isFinished, isTrue);
    });

    test('总话数未知时保守地不判完结', () {
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: DateTime(2026, 9, 17),
      );
      final r = _resolve(eps, seriesTotal: 0, currentSort: 12);
      expect(r!.isFinished, isFalse);
    });
  });

  group('resolveEpisodeResult — 官方 end 兜底', () {
    // 2026-06-07 完结，总话数未知，到 9 月底仍每天出现）。
    test('总话数未知 + 官方 end 已过 → 判完结', () {
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: DateTime(2026, 6, 7),
      );
      final r = _resolve(
        eps,
        seriesTotal: 0,
        currentSort: 12,
        officialEnd: '2026-06-07',
      );
      expect(r!.isFinished, isTrue);
      expect(r.shouldSkip, isTrue);
    });

    test('官方 end 在宽限期内 → 仍算在播', () {
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: _now.subtract(const Duration(days: 1)),
      );
      final r = _resolve(
        eps,
        seriesTotal: 0,
        currentSort: 12,
        officialEnd: _fmt(_now.subtract(const Duration(days: 1))),
      );
      expect(r!.isFinished, isFalse);
    });

    test('官方 end 在未来 → 不算完结', () {
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: DateTime(2026, 9, 17),
      );
      final r = _resolve(
        eps,
        seriesTotal: 0,
        currentSort: 12,
        officialEnd: _fmt(_now.add(const Duration(days: 30))),
      );
      expect(r!.isFinished, isFalse);
    });

    test('end 缺失但末话仍在 3 周内 → 仍在播', () {
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: _now.subtract(const Duration(days: 6)),
      );
      final r = _resolve(eps, seriesTotal: 0, currentSort: 12);
      expect(r!.isFinished, isFalse);
    });

    test('当前话不是末话时，官方 end 也不应判定完结', () {
      // 末话已出但 bgm 把「当前话」算成中间话，说明还有新集在路上
      final eps = _weekly(
        count: 12,
        firstSort: 1,
        lastDate: DateTime(2026, 6, 7),
      );
      final r = _resolve(
        eps,
        seriesTotal: 0,
        currentSort: 6,
        officialEnd: '2026-06-07',
      );
      expect(r!.isFinalEpisode, isFalse);
      expect(r.isFinished, isFalse);
    });
  });

  group('resolveEpisodeResult — 末话新鲜度兜底', () {
    // レッツゴー怪奇組：bangumi-data 的 end 是空的，总话数也拿不到，
    // 但 allepinfo 里末话停在 7 月中旬，到 9 月底已 3 个月没更新。
    test('end 缺失 + 总话数未知 + 末话超过 3 周 → 判完结', () {
      final eps = _weekly(
        count: 13,
        firstSort: 1,
        lastDate: DateTime(2026, 7, 19),
      );
      final r = _resolve(eps, seriesTotal: 0, currentSort: 13);
      expect(r!.isFinished, isTrue);
      expect(r.shouldSkip, isTrue);
    });

    test('末话在 3 周内 → 仍在播', () {
      final eps = _weekly(
        count: 13,
        firstSort: 1,
        lastDate: _now.subtract(const Duration(days: 5)),
      );
      final r = _resolve(eps, seriesTotal: 0, currentSort: 13);
      expect(r!.isFinished, isFalse);
    });

    test('总话数已知时不受新鲜度兜底影响（该判完结就完结）', () {
      final eps = _weekly(
        count: 13,
        firstSort: 1,
        lastDate: DateTime(2026, 7, 19),
      );
      final r = _resolve(eps, seriesTotal: 13, currentSort: 13);
      expect(r!.isFinished, isTrue);
    });

    test('总话数比末话还多（计划集数）且末话已停播 → 判完结', () {
      // 回归：新鲜度曾被 `seriesTotal <= 0` 挡住，而 total 一旦有值就失效，
      // 于是「末话停在 3 个月前、总数只填了一半」的条目永远留在时间表里
      final eps = _weekly(
        count: 13,
        firstSort: 1,
        lastDate: DateTime(2026, 7, 19),
      );
      final r = _resolve(eps, seriesTotal: 24, currentSort: 13);
      expect(r!.isFinished, isTrue);
      expect(r.shouldSkip, isTrue);
    });

    test('官方 end 存在时新鲜度不参与判定', () {
      final eps = _weekly(
        count: 13,
        firstSort: 1,
        lastDate: DateTime(2026, 7, 19),
      );
      final r = _resolve(
        eps,
        seriesTotal: 0,
        currentSort: 13,
        officialEnd: _fmt(_now.add(const Duration(days: 60))),
      );
      expect(r!.isFinished, isFalse, reason: '官方说未完结就以官方为准');
    });

    test('末话新鲜但总话数已满 → 判完结', () {
      final eps = _weekly(
        count: 13,
        firstSort: 1,
        lastDate: _now.subtract(const Duration(days: 10)),
      );
      final r = _resolve(eps, seriesTotal: 13, currentSort: 13);
      expect(r!.isFinished, isTrue);
    });

    test('兜底阈值与常量一致', () {
      expect(EpisodeResult.staleEpisodeDays, 21);
    });
  });

  group('EpisodeResult 完结时间边界（3 天宽限）', () {
    test('end 为当天 / 未来 → 未完结', () {
      expect(EpisodeResult.isFinishedDate(_now, _now), isFalse);
      expect(
        EpisodeResult.isFinishedDate(_now.add(const Duration(days: 2)), _now),
        isFalse,
      );
    });

    test('end 在宽限期内（0~3 天前）→ 未完结', () {
      for (var d = 0; d <= 3; d++) {
        final end = _now.subtract(Duration(days: d));
        expect(
          EpisodeResult.isFinishedDate(end, _now),
          isFalse,
          reason: '$d 天前',
        );
      }
    });

    test('end 超出宽限期（>=4 天前）→ 已完结', () {
      for (var d = 4; d <= 30; d++) {
        final end = _now.subtract(Duration(days: d));
        expect(
          EpisodeResult.isFinishedDate(end, _now),
          isTrue,
          reason: '$d 天前',
        );
      }
    });

    test('end 缺失 → 未完结', () {
      expect(EpisodeResult.isFinishedDate(null, _now), isFalse);
    });
  });
}
