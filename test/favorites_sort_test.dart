import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/anime_type.dart';

const _type = AnimeType(12345);

Map<String, dynamic> _entry(
  String id,
  String name, {
  required int order,
  String? recent,
}) => {
  'id': id,
  'name': name,
  'author': '',
  'type': 12345,
  'tags': const [],
  'coverPath': '',
  'time': '2024-01-01 00:00:00',
  'viewMore': null,
  'folders': ['在看'],
  'orders': {'在看': order},
  if (recent != null) 'recentlyWatched': recent,
};

void main() {
  setUp(() => LocalFavoritesManager.cache = null);

  test('「最近观看」首次点击应为最新在前', () {
    const first = FavoriteSortType.recentlyWatchedDesc;
    const second = FavoriteSortType.recentlyWatchedAsc;

    expect(FavoriteSortType.nameAsc.toggled(first, second), first);
    expect(first.toggled(first, second), second);
    expect(second.toggled(first, second), first);
  });

  test('标记最近观看后，按最新在前应把条目提到首位', () {
    final manager = LocalFavoritesManager();
    manager.mergeFavoriteMaps([
      {
        'folderOrder': ['在看'],
      },
      _entry('a', 'A', order: 0, recent: '2024-05-01 00:00:00'),
      _entry('b', 'B', order: 1, recent: '2024-06-01 00:00:00'),
      _entry('c', 'C', order: 2, recent: '2024-07-01 00:00:00'),
    ]);

    expect(
      manager
          .getAllAnimes('在看', FavoriteSortType.recentlyWatchedDesc)
          .map((e) => e.id)
          .toList(),
      ['c', 'b', 'a'],
    );

    // 模拟 AnimeTile._onTap 标记最近观看
    manager.updateRecentlyWatched('a', _type);

    expect(
      manager
          .getAllAnimes('在看', FavoriteSortType.recentlyWatchedDesc)
          .map((e) => e.id)
          .toList(),
      ['a', 'c', 'b'],
    );
  });
}
