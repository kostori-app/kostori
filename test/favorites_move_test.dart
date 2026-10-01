import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/anime_type.dart';

const _type = AnimeType(12345);

Map<String, dynamic> _entry(
  String id,
  String name,
  List<String> folders, {
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
  'folders': folders,
  'orders': {for (final f in folders) f: 0},
  if (recent != null) 'recentlyWatched': recent,
};

FavoriteItem _item(String id, String name) => FavoriteItem(
  id: id,
  name: name,
  coverPath: '',
  author: '',
  type: _type,
  tags: const [],
  favoriteTime: DateTime(2024, 1, 1),
);

List<String> _ids(LocalFavoritesManager m, String folder) =>
    m.getAllAnimes(folder).map((e) => e.id).toList();

String? _recentOf(LocalFavoritesManager m, String id) =>
    m.getAllFavoriteMergeMaps().firstWhere(
          (e) => e['id'] == id,
        )['recentlyWatched']
        as String?;

void main() {
  setUp(() => LocalFavoritesManager.cache = null);

  test('移动到多个目标时每个目标都要拿到条目', () {
    final manager = LocalFavoritesManager();
    manager.mergeFavoriteMaps([
      {
        'folderOrder': ['来源', '目标A', '目标B'],
      },
      _entry('x', 'X', ['来源']),
    ]);

    manager.batchMoveFavorites('来源', ['目标A', '目标B'], [_item('x', 'X')]);

    expect(_ids(manager, '目标A'), ['x']);
    expect(_ids(manager, '目标B'), ['x']);
    expect(_ids(manager, '来源'), isEmpty);
  });

  test('移动保留 recentlyWatched', () {
    final manager = LocalFavoritesManager();
    manager.mergeFavoriteMaps([
      {
        'folderOrder': ['来源', '目标'],
      },
      _entry('x', 'X', ['来源'], recent: '2024-05-01 10:00:00'),
    ]);

    manager.batchMoveFavorites('来源', ['目标'], [_item('x', 'X')]);

    expect(_recentOf(manager, 'x'), '2024-05-01 10:00:00');
  });

  test('目标已存在同一条目时不产生副本', () {
    final manager = LocalFavoritesManager();
    manager.mergeFavoriteMaps([
      {
        'folderOrder': ['来源', '目标'],
      },
      _entry('x', 'X', ['来源']),
    ]);

    manager.batchCopyFavorites('来源', '目标', [_item('x', 'X')]);
    expect(_ids(manager, '目标'), ['x']);

    manager.batchMoveFavorites('来源', ['目标'], [_item('x', 'X')]);

    expect(_ids(manager, '目标'), ['x'], reason: '不应产生副本');
    expect(_ids(manager, '来源'), isEmpty);
  });

  test('目标列表含来源自身时不产生副本', () {
    final manager = LocalFavoritesManager();
    manager.mergeFavoriteMaps([
      {
        'folderOrder': ['来源', '目标'],
      },
      _entry('x', 'X', ['来源']),
    ]);

    manager.batchMoveFavorites('来源', ['来源', '目标'], [_item('x', 'X')]);

    expect(_ids(manager, '来源'), isEmpty);
    expect(_ids(manager, '目标'), ['x']);
  });
}
