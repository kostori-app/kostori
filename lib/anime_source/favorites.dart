part of anime_source;

typedef AddOrDelFavFunc = Future<Res<bool>> Function(
    String animeId, String folderId, bool isAdding);

class FavoriteData {
  final String key;

  final String title;

  final bool multiFolder;

  final Future<Res<List<BaseAnime>>> Function(int page, [String? folder])
      loadAnime;

  /// key-id, value-name
  ///
  /// if comicId is not null, Res.subData is the folders that the comic is in
  final Future<Res<Map<String, String>>> Function([String? animeId])?
      loadFolders;

  /// A value of null disables this feature
  final Future<Res<bool>> Function(String key)? deleteFolder;

  /// A value of null disables this feature
  final Future<Res<bool>> Function(String name)? addFolder;

  /// A value of null disables this feature
  final String? allFavoritesId;

  final AddOrDelFavFunc? addOrDelFavorite;

  const FavoriteData(
      {required this.key,
      required this.title,
      required this.multiFolder,
      required this.loadAnime,
      this.loadFolders,
      this.deleteFolder,
      this.addFolder,
      this.allFavoritesId,
      this.addOrDelFavorite});
}

FavoriteData getFavoriteData(String key) {
  var source = AnimeSource.find(key) ?? (throw "Unknown source key: $key");
  return source.favoriteData!;
}

FavoriteData? getFavoriteDataOrNull(String key) {
  var source = AnimeSource.find(key);
  return source?.favoriteData;
}
