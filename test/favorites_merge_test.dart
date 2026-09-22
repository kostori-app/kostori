import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/favorites.dart';

Map<String, dynamic> _remote(
  String id,
  String name, {
  required List<String> folders,
  Map<String, int>? orders,
  String? recentlyWatched,
}) => {
  'id': id,
  'name': name,
  'author': '',
  'type': 0,
  'tags': const [],
  'coverPath': '',
  'time': '2024-01-01 00:00:00',
  'viewMore': null,
  'folders': folders,
  'orders': orders ?? const <String, int>{},
  if (recentlyWatched != null) 'recentlyWatched': recentlyWatched,
};

void main() {
  setUp(() {
    // 每个用例用全新的内存管理器（不初始化 DB，落盘为空操作）
    LocalFavoritesManager.cache = null;
  });

  test('合并远端条目顺序与文件夹顺序', () {
    final manager = LocalFavoritesManager();

    // 先建立两个条目与文件夹
    manager.mergeFavoriteMaps([
      _remote('a', 'A', folders: ['在看'], orders: {'在看': 0}),
      _remote('b', 'B', folders: ['在看'], orders: {'在看': 1}),
      {
        'folderOrder': ['在看', '看完'],
      },
    ]);
    expect(manager.folderNames, ['在看', '看完']);
    expect(manager.getAllAnimes('在看').map((e) => e.id).toList(), ['a', 'b']);

    // 远端调整顺序后应生效
    manager.mergeFavoriteMaps([
      _remote('a', 'A', folders: ['在看'], orders: {'在看': 1}),
      _remote('b', 'B', folders: ['在看'], orders: {'在看': 0}),
    ]);
    expect(manager.getAllAnimes('在看').map((e) => e.id).toList(), ['b', 'a']);
  });

  test('最近观看时间取更新的一方，且不会被旧值回退', () {
    final manager = LocalFavoritesManager();
    manager.mergeFavoriteMaps([
      _remote(
        'a',
        'A',
        folders: ['在看'],
        recentlyWatched: '2024-06-01 00:00:00',
      ),
      _remote(
        'b',
        'B',
        folders: ['在看'],
        recentlyWatched: '2024-07-01 00:00:00',
      ),
    ]);

    expect(
      manager
          .getAllAnimes('在看', FavoriteSortType.recentlyWatchedDesc)
          .map((e) => e.id)
          .toList(),
      ['b', 'a'],
    );

    // 再合并一次更旧的值：本地更新的一方保持不变
    manager.mergeFavoriteMaps([
      _remote(
        'b',
        'B',
        folders: ['在看'],
        recentlyWatched: '2000-01-01 00:00:00',
      ),
    ]);
    expect(
      manager.getAllAnimes('在看', FavoriteSortType.recentlyWatchedDesc).first.id,
      'b',
    );
  });

  test('收藏时间在合并后不再被重置', () {
    final item = FavoriteItem.fromJson({
      'id': 'x',
      'name': 'X',
      'author': '',
      'type': 0,
      'tags': const [],
      'coverPath': '',
      'time': '2020-05-06 07:08:09',
    });
    expect(item.time, '2020-05-06 07:08:09');
  });
}
