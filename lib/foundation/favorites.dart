import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kostori/utils/tag_translation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/image_loader/local_favorite_image.dart';
import 'package:kostori/foundation/log.dart';

String _getTimeString(DateTime time) {
  return time.toIso8601String().replaceFirst("T", " ").substring(0, 19);
}

class FavoriteItem implements Anime {
  String name;
  String author;
  AnimeType type;
  @override
  List<String> tags;
  @override
  String id;
  String coverPath;
  late String time;

  FavoriteItem(
      {required this.id,
      required this.name,
      required this.coverPath,
      required this.author,
      required this.type,
      required this.tags,
      DateTime? favoriteTime}) {
    var t = favoriteTime ?? DateTime.now();
    time = _getTimeString(t);
  }

  FavoriteItem.fromRow(Row row)
      : name = row["name"],
        author = row["author"],
        type = AnimeType(row["type"]),
        tags = (row["tags"] as String).split(","),
        id = row["id"],
        coverPath = row["cover_path"],
        time = row["time"] {
    tags.remove("");
  }

  @override
  bool operator ==(Object other) {
    return other is FavoriteItem && other.id == id && other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode;

  @override
  String toString() {
    var s = "FavoriteItem: $name $author $coverPath $hashCode $tags";
    if (s.length > 100) {
      return s.substring(0, 100);
    }
    return s;
  }

  @override
  String get cover => coverPath;

  @override
  String get description {
    var time = this.time.substring(0, 10);
    return appdata.settings['animeDisplayMode'] == 'detailed'
        ? "$time | ${type == AnimeType.local ? 'local' : type.animeSource?.name ?? "Unknown"}"
        : "${type.animeSource?.name ?? "Unknown"} | $time";
  }

  @override
  String? get favoriteId => null;

  @override
  String? get language => null;

  int? get maxPage => null;

  @override
  String get sourceKey => type == AnimeType.local
      ? 'local'
      : type.animeSource?.key ?? "Unknown:${type.value}";

  @override
  double? get stars => null;

  @override
  String? get subtitle => author;

  @override
  String get title => name;

  @override
  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "author": author,
      "type": type.value,
      "tags": tags,
      "id": id,
      "coverPath": coverPath,
    };
  }

  static FavoriteItem fromJson(Map<String, dynamic> json) {
    var type = json["type"] as int;
    return FavoriteItem(
      id: json["id"] ?? json['target'],
      name: json["name"],
      author: json["author"],
      coverPath: json["coverPath"],
      type: AnimeType(type),
      tags: List<String>.from(json["tags"] ?? []),
    );
  }
}

class FavoriteItemWithFolderInfo extends FavoriteItem {
  String folder;

  FavoriteItemWithFolderInfo(FavoriteItem item, this.folder)
      : super(
          id: item.id,
          name: item.name,
          coverPath: item.coverPath,
          author: item.author,
          type: item.type,
          tags: item.tags,
        );
}

class LocalFavoritesManager with ChangeNotifier {
  factory LocalFavoritesManager() =>
      cache ?? (cache = LocalFavoritesManager._create());

  LocalFavoritesManager._create();

  static LocalFavoritesManager? cache;

  late Database _db;

  Future<void> init() async {
    _db = sqlite3.open("${App.dataPath}/local_favorite.db");
    _db.execute("""
      create table if not exists folder_order (
        folder_name text primary key,
        order_value int
      );
    """);
    _db.execute("""
      create table if not exists folder_sync (
        folder_name text primary key,
        source_key text,
        source_folder text
      );
    """);
    for (var folder in _getFolderNamesWithDB()) {
      var columns = _db.select("""
        pragma table_info("$folder");
      """);
      if (!columns.any((element) => element["name"] == "translated_tags")) {
        _db.execute("""
          alter table "$folder"
          add column translated_tags TEXT;
        """);
        var animes = getAllAnimes(folder);
        for (var anime in animes) {
          var translatedTags = _translateTags(anime.tags);
          _db.execute("""
            update "$folder"
            set translated_tags = ?
            where id == ? and type == ?;
          """, [translatedTags, anime.id, anime.type.value]);
        }
      } else {
        break;
      }
    }
  }

  List<String> find(String id, AnimeType type) {
    var res = <String>[];
    for (var folder in folderNames) {
      var rows = _db.select("""
        select * from "$folder"
        where id == ? and type == ?;
      """, [id, type.value]);
      if (rows.isNotEmpty) {
        res.add(folder);
      }
    }
    return res;
  }

  Future<List<String>> findWithModel(FavoriteItem item) async {
    var res = <String>[];
    for (var folder in folderNames) {
      var rows = _db.select("""
        select * from "$folder"
        where id == ? and type == ?;
      """, [item.id, item.type.value]);
      if (rows.isNotEmpty) {
        res.add(folder);
      }
    }
    return res;
  }

  List<String> _getTablesWithDB() {
    final tables = _db
        .select("SELECT name FROM sqlite_master WHERE type='table';")
        .map((element) => element["name"] as String)
        .toList();
    return tables;
  }

  List<String> _getFolderNamesWithDB() {
    final folders = _getTablesWithDB();
    folders.remove('folder_sync');
    folders.remove('folder_order');
    var folderToOrder = <String, int>{};
    for (var folder in folders) {
      var res = _db.select("""
        select * from folder_order
        where folder_name == ?;
      """, [folder]);
      if (res.isNotEmpty) {
        folderToOrder[folder] = res.first["order_value"];
      } else {
        folderToOrder[folder] = 0;
      }
    }
    folders.sort((a, b) {
      return folderToOrder[a]! - folderToOrder[b]!;
    });
    return folders;
  }

  void updateOrder(List<String> folders) {
    for (int i = 0; i < folders.length; i++) {
      _db.execute("""
        insert or replace into folder_order (folder_name, order_value)
        values (?, ?);
      """, [folders[i], i]);
    }
    notifyListeners();
  }

  int count(String folderName) {
    return _db.select("""
      select count(*) as c
      from "$folderName"
    """).first["c"];
  }

  List<String> get folderNames => _getFolderNamesWithDB();

  int maxValue(String folder) {
    return _db.select("""
        SELECT MAX(display_order) AS max_value
        FROM "$folder";
      """).firstOrNull?["max_value"] ?? 0;
  }

  int minValue(String folder) {
    return _db.select("""
        SELECT MIN(display_order) AS min_value
        FROM "$folder";
      """).firstOrNull?["min_value"] ?? 0;
  }

  List<FavoriteItem> getAllAnimes(String folder) {
    if (folder == '默认') {
      folder = 'default';
    }
    var rows = _db.select("""
        select * from "$folder"
        ORDER BY display_order;
      """);
    return rows.map((element) => FavoriteItem.fromRow(element)).toList();
  }

  void addTagTo(String folder, String id, String tag) {
    _db.execute("""
      update "$folder"
      set tags = '$tag,' || tags
      where id == ?
    """, [id]);
    notifyListeners();
  }

  List<FavoriteItemWithFolderInfo> allAnimes() {
    var res = <FavoriteItemWithFolderInfo>[];
    for (final folder in folderNames) {
      var animes = _db.select("""
        select * from "$folder";
      """);
      res.addAll(animes.map((element) =>
          FavoriteItemWithFolderInfo(FavoriteItem.fromRow(element), folder)));
    }
    return res;
  }

  bool existsFolder(String name) {
    return folderNames.contains(name);
  }

  /// create a folder
  String createFolder(String name, [bool renameWhenInvalidName = false]) {
    if (name.isEmpty) {
      if (renameWhenInvalidName) {
        int i = 0;
        while (existsFolder(i.toString())) {
          i++;
        }
        name = i.toString();
      } else {
        throw "name is empty!";
      }
    }
    if (existsFolder(name)) {
      if (renameWhenInvalidName) {
        var prevName = name;
        int i = 0;
        while (existsFolder(i.toString())) {
          i++;
        }
        name = prevName + i.toString();
      } else {
        throw Exception("Folder is existing");
      }
    }
    _db.execute("""
      create table "$name"(
        id text,
        name TEXT,
        author TEXT,
        type int,
        tags TEXT,
        cover_path TEXT,
        time TEXT,
        display_order int,
        translated_tags TEXT,
        primary key (id, type)
      );
    """);
    notifyListeners();
    return name;
  }

  void linkFolderToNetwork(String folder, String source, String networkFolder) {
    _db.execute("""
      insert or replace into folder_sync (folder_name, source_key, source_folder)
      values (?, ?, ?);
    """, [folder, source, networkFolder]);
  }

  bool isLinkedToNetworkFolder(
      String folder, String source, String networkFolder) {
    var res = _db.select("""
      select * from folder_sync
      where folder_name == ? and source_key == ? and source_folder == ?;
    """, [folder, source, networkFolder]);
    return res.isNotEmpty;
  }

  (String?, String?) findLinked(String folder) {
    var res = _db.select("""
      select * from folder_sync
      where folder_name == ?;
    """, [folder]);
    if (res.isEmpty) {
      return (null, null);
    }
    return (res.first["source_key"], res.first["source_folder"]);
  }

  bool animeExists(String folder, String id, AnimeType type) {
    var res = _db.select("""
      select * from "$folder"
      where id == ? and type == ?;
    """, [id, type.value]);
    return res.isNotEmpty;
  }

  FavoriteItem getAnime(String folder, String id, AnimeType type) {
    var res = _db.select("""
      select * from "$folder"
      where id == ? and type == ?;
    """, [id, type.value]);
    if (res.isEmpty) {
      throw Exception("Anime not found");
    }
    return FavoriteItem.fromRow(res.first);
  }

  String _translateTags(List<String> tags) {
    var res = <String>[];
    for (var tag in tags) {
      var translated = tag.translateTagsToCN;
      if (translated != tag) {
        res.add(translated);
      }
    }
    return res.join(",");
  }

  /// add anime to a folder
  ///
  /// This method will download cover to local, to avoid problems like changing url
  bool addAnime(String folder, FavoriteItem anime, [int? order]) {
    _modifiedAfterLastCache = true;
    if (!existsFolder(folder)) {
      throw Exception("Folder does not exists");
    }
    var res = _db.select("""
      select * from "$folder"
      where id == ? and type == ?;
    """, [anime.id, anime.type.value]);
    if (res.isNotEmpty) {
      return false;
    }
    var translatedTags = _translateTags(anime.tags);
    final params = [
      anime.id,
      anime.name,
      anime.author,
      anime.type.value,
      anime.tags.join(","),
      anime.coverPath,
      anime.time,
      translatedTags
    ];
    if (order != null) {
      _db.execute("""
        insert into "$folder" (id, name, author, type, tags, cover_path, time, translated_tags, display_order)
        values (?, ?, ?, ?, ?, ?, ?, ?, ?);
      """, [...params, order]);
    } else if (appdata.settings['newFavoriteAddTo'] == "end") {
      _db.execute("""
        insert into "$folder" (id, name, author, type, tags, cover_path, time, translated_tags, display_order)
        values (?, ?, ?, ?, ?, ?, ?, ?, ?);
      """, [...params, maxValue(folder) + 1]);
    } else {
      _db.execute("""
        insert into "$folder" (id, name, author, type, tags, cover_path, time, translated_tags, display_order)
        values (?, ?, ?, ?, ?, ?, ?, ?, ?);
      """, [...params, minValue(folder) - 1]);
    }
    notifyListeners();
    return true;
  }

  void moveFavorite(
      String sourceFolder, String targetFolder, String id, AnimeType type) {
    _modifiedAfterLastCache = true;

    if (!existsFolder(sourceFolder)) {
      throw Exception("Source folder does not exist");
    }
    if (!existsFolder(targetFolder)) {
      throw Exception("Target folder does not exist");
    }

    var res = _db.select("""
    select * from "$targetFolder"
    where id == ? and type == ?;
  """, [id, type.value]);

    if (res.isNotEmpty) {
      return;
    }

    _db.execute("""
      insert into "$targetFolder" (id, name, author, type, tags, cover_path, time, display_order)
      select id, name, author, type, tags, cover_path, time, ?
      from "$sourceFolder"
      where id == ? and type == ?;
    """, [minValue(targetFolder) - 1, id, type.value]);

    // 从源表删除该数据
    _db.execute("""
    delete from "$sourceFolder"
    where id == ? and type == ?;
  """, [id, type.value]);

    notifyListeners();
  }

  /// delete a folder
  void deleteFolder(String name) {
    _modifiedAfterLastCache = true;
    _db.execute("""
      drop table "$name";
    """);
    _db.execute("""
      delete from folder_order
      where folder_name == ?;
    """, [name]);
    notifyListeners();
  }

  void deleteAnime(String folder, FavoriteItem anime) {
    _modifiedAfterLastCache = true;
    deleteAnimeWithId(folder, anime.id, anime.type);
  }

  void deleteAnimeWithId(String folder, String id, AnimeType type) {
    _modifiedAfterLastCache = true;
    LocalFavoriteImageProvider.delete(id, type.value);
    _db.execute("""
      delete from "$folder"
      where id == ? and type == ?;
    """, [id, type.value]);
    notifyListeners();
  }

  Future<int> removeInvalid() async {
    int count = 0;
    await Future.microtask(() {
      var all = allAnimes();
      for (var c in all) {
        var animeSource = c.type.animeSource;
        if ((c.type == AnimeType.local) ||
            (c.type != AnimeType.local && animeSource == null)) {
          deleteAnimeWithId(c.folder, c.id, c.type);
          count++;
        }
      }
    });
    return count;
  }

  Future<void> clearAll() async {
    _db.dispose();
    File("${App.dataPath}/local_favorite.db").deleteSync();
    await init();
  }

  void reorder(List<FavoriteItem> newFolder, String folder) async {
    if (!existsFolder(folder)) {
      throw Exception("Failed to reorder: folder not found");
    }
    deleteFolder(folder);
    createFolder(folder);
    for (int i = 0; i < newFolder.length; i++) {
      addAnime(folder, newFolder[i], i);
    }
    notifyListeners();
  }

  void rename(String before, String after) {
    if (folderNames.contains(after)) {
      throw "Name already exists!";
    }
    if (after.contains('"')) {
      throw "Invalid name";
    }
    _db.execute("""
      ALTER TABLE "$before"
      RENAME TO "$after";
    """);
    _db.execute("""
      update folder_order
      set folder_name = ?
      where folder_name == ?;
    """, [after, before]);
    _db.execute("""
      update folder_sync
      set folder_name = ?
      where folder_name == ?;
    """, [after, before]);
    notifyListeners();
  }

  void onReadEnd(String id, AnimeType type) async {
    _modifiedAfterLastCache = true;
    for (final folder in folderNames) {
      var rows = _db.select("""
        select * from "$folder"
        where id == ? and type == ?;
      """, [id, type.value]);
      if (rows.isNotEmpty) {
        var newTime = DateTime.now()
            .toIso8601String()
            .replaceFirst("T", " ")
            .substring(0, 19);
        String updateLocationSql = "";
        if (appdata.settings['moveFavoriteAfterRead'] == "end") {
          int maxValue = _db.select("""
            SELECT MAX(display_order) AS max_value
            FROM "$folder";
          """).firstOrNull?["max_value"] ?? 0;
          updateLocationSql = "display_order = ${maxValue + 1},";
        } else if (appdata.settings['moveFavoriteAfterRead'] == "start") {
          int minValue = _db.select("""
            SELECT MIN(display_order) AS min_value
            FROM "$folder";
          """).firstOrNull?["min_value"] ?? 0;
          updateLocationSql = "display_order = ${minValue - 1},";
        }
        _db.execute("""
            UPDATE "$folder"
            SET 
              $updateLocationSql
              time = ?
            WHERE id == ?;
          """, [newTime, id]);
      }
    }
    notifyListeners();
  }

  List<FavoriteItem> searchInFolder(String folder, String keyword) {
    var keywordList = keyword.split(" ");
    keyword = keywordList.first;
    keyword = "%$keyword%";
    var res = _db.select("""
      SELECT * FROM "$folder" 
      WHERE name LIKE ? OR author LIKE ? OR tags LIKE ? OR translated_tags LIKE ?;
    """, [keyword, keyword, keyword, keyword]);
    var animes = res.map((e) => FavoriteItem.fromRow(e)).toList();
    bool test(FavoriteItem anime, String keyword) {
      if (anime.name.contains(keyword)) {
        return true;
      } else if (anime.author.contains(keyword)) {
        return true;
      } else if (anime.tags.any((element) => element.contains(keyword))) {
        return true;
      }
      return false;
    }

    for (var i = 1; i < keywordList.length; i++) {
      animes =
          animes.where((element) => test(element, keywordList[i])).toList();
    }
    return animes;
  }

  List<FavoriteItemWithFolderInfo> search(String keyword) {
    var keywordList = keyword.split(" ");
    keyword = keywordList.first;
    var animes = <FavoriteItemWithFolderInfo>[];
    for (var table in folderNames) {
      keyword = "%$keyword%";
      var res = _db.select("""
        SELECT * FROM "$table" 
        WHERE name LIKE ? OR author LIKE ? OR tags LIKE ? OR translated_tags LIKE ?;
      """, [keyword, keyword, keyword, keyword]);
      for (var anime in res) {
        animes.add(
            FavoriteItemWithFolderInfo(FavoriteItem.fromRow(anime), table));
      }
      if (animes.length > 200) {
        break;
      }
    }

    bool test(FavoriteItemWithFolderInfo anime, String keyword) {
      if (anime.name.contains(keyword)) {
        return true;
      } else if (anime.author.contains(keyword)) {
        return true;
      } else if (anime.tags.any((element) => element.contains(keyword))) {
        return true;
      }
      return false;
    }

    for (var i = 1; i < keywordList.length; i++) {
      animes =
          animes.where((element) => test(element, keywordList[i])).toList();
    }

    return animes;
  }

  void editTags(String id, String folder, List<String> tags) {
    _db.execute("""
        update "$folder"
        set tags = ?
        where id == ?;
      """, [tags.join(","), id]);
    notifyListeners();
  }

  final _cachedFavoritedIds = <String, bool>{};

  bool isExist(String id, AnimeType type) {
    if (_modifiedAfterLastCache) {
      _cacheFavoritedIds();
    }
    return _cachedFavoritedIds.containsKey("$id@${type.value}");
  }

  bool _modifiedAfterLastCache = true;

  void _cacheFavoritedIds() {
    _modifiedAfterLastCache = false;
    _cachedFavoritedIds.clear();
    for (var folder in folderNames) {
      var rows = _db.select("""
        select id, type from "$folder";
      """);
      for (var row in rows) {
        _cachedFavoritedIds["${row["id"]}@${row["type"]}"] = true;
      }
    }
  }

  void updateInfo(String folder, FavoriteItem anime) {
    _db.execute("""
      update "$folder"
      set name = ?, author = ?, cover_path = ?, tags = ?
      where id == ? and type == ?;
    """, [
      anime.name,
      anime.author,
      anime.coverPath,
      anime.tags.join(","),
      anime.id,
      anime.type.value
    ]);
    notifyListeners();
  }

  String folderToJson(String folder) {
    var res = _db.select("""
      select * from "$folder";
    """);
    return jsonEncode({
      "info": "Generated by Kostori",
      "name": folder,
      "animes": res.map((e) => FavoriteItem.fromRow(e).toJson()).toList(),
    });
  }

  void fromJson(String json) {
    var data = jsonDecode(json);
    var folder = data["name"];
    if (folder == null || folder is! String) {
      throw "Invalid data";
    }
    if (existsFolder(folder)) {
      int i = 0;
      while (existsFolder("$folder($i)")) {
        i++;
      }
      folder = "$folder($i)";
    }
    createFolder(folder);
    for (var anime in data["animes"]) {
      try {
        addAnime(folder, FavoriteItem.fromJson(anime));
      } catch (e) {
        Log.error("Import Data", e.toString());
      }
    }
  }

  void close() {
    _db.dispose();
  }
}
