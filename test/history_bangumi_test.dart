import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/history.dart';

History _entry({
  required String id,
  required int episode,
  required int bangumiId,
  int time = 0,
  int allEpisode = 24,
}) => History(
  id: id,
  type: HistoryType(0),
  title: id,
  subtitle: '',
  cover: '',
  lastWatchEpisode: episode,
  lastWatchTime: time,
  allEpisode: allEpisode,
  bangumiId: bangumiId,
);

void main() {
  test('同 bangumiId 取集数最高的条目，两条都显示该集数', () {
    final manager = HistoryManager();
    manager.cacheHistory(_entry(id: 'a', episode: 13, bangumiId: 100));
    manager.cacheHistory(_entry(id: 'b', episode: 12, bangumiId: 100));

    expect(manager.bestByBangumiId(100)!.id, 'a');

    final a = manager.find('a', HistoryType(0))!;
    final b = manager.find('b', HistoryType(0))!;
    expect(a.displayEpisode, 13);
    expect(b.displayEpisode, 13);
    expect(manager.alignedHistory(b).id, 'a');
  });

  test('集数相同时按观看时间更新的一方', () {
    final manager = HistoryManager();
    manager.cacheHistory(
      _entry(id: 'a', episode: 13, bangumiId: 100, time: 100),
    );
    manager.cacheHistory(
      _entry(id: 'b', episode: 13, bangumiId: 100, time: 200),
    );
    expect(manager.bestByBangumiId(100)!.id, 'b');
  });

  test('不同 bangumiId 互不影响', () {
    final manager = HistoryManager();
    manager.cacheHistory(_entry(id: 'p', episode: 13, bangumiId: 300));
    manager.cacheHistory(_entry(id: 'q', episode: 2, bangumiId: 400));
    expect(manager.bestByBangumiId(300)!.id, 'p');
    expect(manager.bestByBangumiId(400)!.id, 'q');
    expect(manager.find('q', HistoryType(0))!.displayEpisode, 2);
  });
}
