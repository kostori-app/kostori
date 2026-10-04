import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/utils/utils.dart';

/// レッツゴー怪奇組（bgm subject 595106）的真实数据，2026-10-04 取自
/// `GET /v0/subjects/595106` 与 `GET /v0/episodes?subject_id=595106`：
/// `eps=12`、`total_episodes=13`，type 0 共 12 话，末话 ep12 播出 2026-09-27。
/// 剧集接口回的 `total` 是 12（已播数），比条目的 `total_episodes` 少一。
final DateTime _now = DateTime(2026, 10, 4, 23);
final int _currentWeek = Utils.getISOWeekNumber(_now).$2;

/// 真实播出日（bgm 返回值，注意 ep11→ep12 之间断了一周），
/// 从 2026-07-05 起每周一。
const _airDates = [
  '2026-07-05',
  '2026-07-12',
  '2026-07-19',
  '2026-07-26',
  '2026-08-02',
  '2026-08-09',
  '2026-08-16',
  '2026-08-23',
  '2026-08-30',
  '2026-09-06',
  '2026-09-13',
  '2026-09-27',
];

List<EpisodeInfo> _eps() => List.generate(_airDates.length, (i) {
  return EpisodeInfo(
    id: i + 1,
    sort: i + 1,
    ep: i + 1,
    comment: 0,
    type: 0,
    name: 'ep${i + 1}',
    nameCn: '第${i + 1}话',
    airDate: _airDates[i],
    duration: '',
    desc: '',
  );
});

void main() {
  group('レッツゴー怪奇組 真实数据', () {
    final eps = _eps();

    test('末话 7 天前播出，不属于「停播」', () {
      // 说明 21 天新鲜度阈值不该误伤：它上周刚出过
      expect(eps.last.airDate, '2026-09-27');
      expect(_now.difference(DateTime(2026, 9, 27)).inDays, 7);
    });

    test('剧集接口 total=12（已播数）→ 判完结并从时间表剔除', () {
      final r = resolveEpisodeResult(
        type0Episodes: eps,
        currentEpisode: eps.last,
        seriesTotal: 12,
        now: _now,
        currentWeek: _currentWeek,
        officialEnd: null,
      );
      expect(r, isNotNull);
      expect(r!.isFinalEpisode, isTrue);
      expect(r.isFinished, isTrue);
      expect(r.shouldSkip, isTrue, reason: '必须从时间表剔除');
    });

    test('条目 total_episodes=13（计划集数）时不应误判完结', () {
      // 计划集数比已播数大是常态（还有 1 集没放），此时应保留在时间表
      final r = resolveEpisodeResult(
        type0Episodes: eps,
        currentEpisode: eps.last,
        seriesTotal: 13,
        now: _now,
        currentWeek: _currentWeek,
        officialEnd: null,
      );
      expect(r!.isFinished, isFalse);
      expect(r.shouldSkip, isFalse);
    });

    test('计划集数未知 + 末话停在 3 周前 → 仍能兜底剔除', () {
      final old = List.generate(12, (i) {
        final d = DateTime(2026, 6, 7).add(Duration(days: 7 * i));
        return EpisodeInfo(
          id: i + 1,
          sort: i + 1,
          ep: i + 1,
          comment: 0,
          type: 0,
          name: 'ep${i + 1}',
          nameCn: '',
          airDate:
              '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}',
          duration: '',
          desc: '',
        );
      });
      final r = resolveEpisodeResult(
        type0Episodes: old,
        currentEpisode: old.last,
        seriesTotal: 0,
        now: _now,
        currentWeek: _currentWeek,
        officialEnd: null,
      );
      expect(r!.isFinished, isTrue);
    });

    test('缓存 total 含特别篇时 seriesReachedEnd 必然为 false', () {
      // bangumi_AllEpInfo 缓存里 total=13（12 正片 + 1 特别篇），
      // 而最后一个 type=0 的 sort 是 12 —— 拿 total 当「已播完」判据永远不成立
      final cachedTotal = 13;
      final lastType0Sort = eps.where((e) => e.type == 0).last.sort;
      expect(cachedTotal > lastType0Sort, isTrue);
      final r = resolveEpisodeResult(
        type0Episodes: eps,
        currentEpisode: eps.last,
        seriesTotal: cachedTotal,
        now: _now,
        currentWeek: _currentWeek,
        officialEnd: null,
      );
      expect(r!.isFinished, isFalse, reason: '单靠 total 判不出来');
    });
  });

  group('hasEpisodeNearNow — 时间表本周是否该显示', () {
    test('末话 7 天前播出（怪奇組实况）→ 本周不显示', () {
      expect(BangumiUtils.hasEpisodeNearNow(_eps(), _now), isFalse);
    });

    test('周更正常播出 → 显示', () {
      // 末话 2026-10-01，3 天前
      final fresh = List.generate(12, (i) {
        final d = DateTime(2026, 7, 16).add(Duration(days: 7 * i));
        return EpisodeInfo(
          id: i + 1,
          sort: i + 1,
          ep: i + 1,
          comment: 0,
          type: 0,
          name: 'ep${i + 1}',
          nameCn: '',
          airDate:
              '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}',
          duration: '',
          desc: '',
        );
      });
      expect(fresh.last.airDate, '2026-10-01');
      expect(BangumiUtils.hasEpisodeNearNow(fresh, _now), isTrue);
    });

    test('未来几天待播的集也算本周显示', () {
      final upcoming = [
        EpisodeInfo(
          id: 99,
          sort: 99,
          ep: 99,
          comment: 0,
          type: 0,
          name: 'next',
          nameCn: '',
          airDate: '2026-10-06',
          duration: '',
          desc: '',
        ),
      ];
      expect(BangumiUtils.hasEpisodeNearNow(upcoming, _now), isTrue);
    });

    test('只有特别篇在附近也不算数', () {
      final specialOnly = [
        EpisodeInfo(
          id: 1,
          sort: 1,
          ep: 0,
          comment: 0,
          type: 1,
          name: '特別怪',
          nameCn: '',
          airDate: '2026-10-02',
          duration: '',
          desc: '',
        ),
      ];
      expect(BangumiUtils.hasEpisodeNearNow(specialOnly, _now), isFalse);
    });

    test('空列表 → 不显示', () {
      expect(BangumiUtils.hasEpisodeNearNow(const [], _now), isFalse);
    });
  });
}
