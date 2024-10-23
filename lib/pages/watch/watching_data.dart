part of kostori_watcher;

abstract class WatchingData {
  WatchingData();

  String get title;

  String get id;

  AnimeType get type;

  String get sourceKey;

  bool get hasEp;

  Map<String, String>? get eps;

  String get favoriteId => id;

  FavoriteType get favoriteType;

  Future<String> loadEp(int ep) async {
    return await loadEpNetwork(ep);
  }

  String buildImageKey(int ep, int page, String url) => url;

  Future<String> loadEpNetwork(int ep);
}

class GglWatchingData extends WatchingData {
  @override
  final String title;

  @override
  final String id;

  int? commentsLength;

  static Map<String, String> generateMap(
      List<String> epIds, List<String> epNames) {
    if (epIds.length == epNames.length) {
      return Map.fromIterables(epIds, epNames);
    } else {
      return Map.fromIterables(
          epIds, List.generate(epIds.length, (index) => "第${index + 1}章"));
    }
  }

  GglWatchingData(this.title, this.id, List<String> epIds, List<String> epNames)
      : eps = generateMap(epIds, epNames);

  @override
  bool get hasEp => true;

  @override
  String get sourceKey => "girigirilove";

  @override
  AnimeType get type => AnimeType.girigirilove;

  @override
  Future<String> loadEpNetwork(int ep) async {
    var res = await GGLNetwork()
        .parsePlayLink(eps.keys.elementAtOrNull(ep - 1) ?? id);
    return res;
  }

  @override
  final Map<String, String> eps;

  @override
  FavoriteType get favoriteType => FavoriteType.girigililove;
}

class CustomWatchingData extends WatchingData {
  CustomWatchingData(this.id, this.title, this.source, this.eps);

  final AnimeSource? source;

  // @override
  // String get downloadId => DownloadManager().generateId(sourceKey, id);

  @override
  final Map<String, String>? eps;

  @override
  bool get hasEp => eps != null;

  @override
  String id;

  @override
  final String title;

  @override
  Future<String> loadEpNetwork(int ep) async {
    var res = await GGLNetwork()
        .parsePlayLink(eps?.keys.elementAtOrNull(ep - 1) ?? id);
    return res;
  }

  // @override
  // Stream<DownloadProgress> loadImageNetwork(int ep, int page, String url) {
  //   return ImageManager().getCustomImage(
  //       url,
  //       id,
  //       eps?.keys.elementAtOrNull(ep-1) ?? id,
  //       sourceKey
  //   );
  // }

  @override
  String get sourceKey => source?.key ?? "";

  @override
  AnimeType get type => AnimeType.other;

  @override
  String buildImageKey(int ep, int page, String url) =>
      "$sourceKey$id${eps!.keys.elementAtOrNull(ep - 1) ?? id}$url";

  @override
  FavoriteType get favoriteType => FavoriteType(source!.intKey);
}
