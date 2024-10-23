import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:kostori/foundation/state_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import '../base.dart';
import '../network/base_anime.dart';
import '../network/girigirilove_network/ggl_image.dart';
import '../network/girigirilove_network/ggl_models.dart';
import '../network/webdav.dart';
import '../pages/favorites/main_favorites_page.dart';
import 'app.dart';
import 'log.dart';

String getCurTime() {
  return DateTime.now()
      .toIso8601String()
      .replaceFirst("T", " ")
      .substring(0, 19);
}

final class FavoriteType {
  final int key;

  const FavoriteType(this.key);

  static FavoriteType get girigililove => const FavoriteType(0);

  // static FavoriteType get ehentai => const FavoriteType(1);
  //
  // static FavoriteType get jm => const FavoriteType(2);
  //
  // static FavoriteType get hitomi => const FavoriteType(3);
  //
  // static FavoriteType get htManga => const FavoriteType(4);
  //
  // static FavoriteType get nhentai => const FavoriteType(6);

  // AnimeType get animeType {
  //   if (key >= 0 && key <= 6) {
  //     return AnimeType.values[key];
  //   }
  //   return AnimeType.other;
  // }

  // AnimeSource get animeSource {
  //   if (key <= 6) {
  //     var key = animeType.name.toLowerCase();
  //     return AnimeSource.find(key)!;
  //   }
  //   return AnimeSource.sources
  //           .firstWhereOrNull((element) => element.intKey == key) ??
  //       (throw "Anime Source Not Found");
  // }

  // String get name {
  //   if (animeType != AnimeType.other) {
  //     return animeType.name;
  //   } else {
  //     try {
  //       return animeSource.name;
  //     } catch (e) {
  //       return "**Unknown**";
  //     }
  //   }
  // }

  @override
  bool operator ==(Object other) {
    return other is FavoriteType && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

class FavoriteItem {
  String name;
  String author;
  FavoriteType type;
  List<String> tags;
  String target;
  String coverPath;
  String time = getCurTime();

  // bool get available {
  //   if (type.key <= 6 && type.key >= 0) {
  //     return true;
  //   }
  //   return AnimeSource.sources
  //           .firstWhereOrNull((element) => element.intKey == type.key) !=
  //       null;
  // }

  // String toDownloadId() {
  //   try {
  //     return switch (type.animeType) {
  //       AnimeType.picacg => target,
  //       AnimeType.ehentai => getGalleryId(target),
  //       AnimeType.jm => "jm$target",
  //       AnimeType.hitomi => RegExp(r"\d+(?=\.html)").hasMatch(target)
  //           ? "hitomi${RegExp(r"\d+(?=\.html)").firstMatch(target)?[0]}"
  //           : target,
  //       AnimeType.htManga => "ht$target",
  //       AnimeType.nhentai => "nhentai$target",
  //       _ => DownloadManager().generateId(type.animeSource.key, target)
  //     };
  //   } catch (e) {
  //     return "**Invalid ID**";
  //   }
  // }

  FavoriteItem({
    required this.target,
    required this.name,
    required this.coverPath,
    required this.author,
    required this.type,
    required this.tags,
  });

  // FavoriteItem.fromPicacg(AnimeItemBrief anime)
  //     : name = anime.title,
  //       author = anime.author,
  //       type = FavoriteType.picacg,
  //       tags = anime.tags,
  //       target = anime.id,
  //       coverPath = anime.path;
  //
  // FavoriteItem.fromEhentai(EhGalleryBrief anime)
  //     : name = anime.title,
  //       author = anime.uploader,
  //       type = FavoriteType.ehentai,
  //       tags = anime.tags,
  //       target = anime.link,
  //       coverPath = anime.coverPath;
  //
  FavoriteItem.fromGglAnime(GglAnimeBrief anime)
      : name = anime.name,
        author = anime.subName,
        type = FavoriteType.girigililove,
        tags = [],
        target = anime.id,
        coverPath = getGglCoverUrl(anime.dataSrc);
  //
  // FavoriteItem.fromHitomi(HitomiAnimeBrief anime)
  //     : name = anime.name,
  //       author = anime.artist,
  //       type = FavoriteType.hitomi,
  //       tags = List.generate(
  //           anime.tagList.length, (index) => anime.tagList[index].name),
  //       target = anime.link,
  //       coverPath = anime.cover;
  //
  // FavoriteItem.fromHtanime(HtAnimeBrief anime)
  //     : name = anime.name,
  //       author = "${anime.pages}Pages",
  //       type = FavoriteType.htManga,
  //       tags = [],
  //       target = anime.id,
  //       coverPath = anime.image;
  //
  // FavoriteItem.fromNhentai(NhentaiAnimeBrief anime)
  //     : name = anime.title,
  //       author = "",
  //       type = FavoriteType.nhentai,
  //       tags = anime.tags,
  //       target = anime.id,
  //       coverPath = anime.cover;
  //
  FavoriteItem.custom(CustomAnime anime)
      : name = anime.title,
        author = anime.subTitle,
        type = FavoriteType(anime.sourceKey.hashCode),
        tags = anime.tags,
        target = anime.id,
        coverPath = anime.cover;

  Map<String, dynamic> toJson() => {
        "name": name,
        "author": author,
        "type": type.key,
        "tags": tags,
        "target": target,
        "coverPath": coverPath,
        "time": time
      };

  FavoriteItem.fromJson(Map<String, dynamic> json)
      : name = json["name"],
        author = json["author"],
        type = FavoriteType(json["type"]),
        tags = List<String>.from(json["tags"]),
        target = json["target"],
        coverPath = json["coverPath"],
        time = json["time"];

  FavoriteItem.fromRow(Row row)
      : name = row["name"],
        author = row["author"],
        type = FavoriteType(row["type"]),
        tags = (row["tags"] as String).split(","),
        target = row["target"],
        coverPath = row["cover_path"],
        time = row["time"] {
    tags.remove("");
  }

  // factory FavoriteItem.fromBaseAnime(BaseAnime anime) {
  //   if (anime is AnimeItemBrief) {
  //     return FavoriteItem.fromPicacg(anime);
  //   } else if (anime is EhGalleryBrief) {
  //     return FavoriteItem.fromEhentai(anime);
  //   } else if (anime is JmAnimeBrief) {
  //     return FavoriteItem.fromJmAnime(anime);
  //   } else if (anime is HtAnimeBrief) {
  //     return FavoriteItem.fromHtanime(anime);
  //   } else if (anime is NhentaiAnimeBrief) {
  //     return FavoriteItem.fromNhentai(anime);
  //   } else if (anime is CustomAnime) {
  //     return FavoriteItem.custom(anime);
  //   }
  //   throw UnimplementedError();
  // }

  @override
  bool operator ==(Object other) {
    return other is FavoriteItem &&
        other.target == target &&
        other.type == type;
  }

  @override
  int get hashCode => target.hashCode ^ type.hashCode;

  @override
  String toString() {
    var s = "FavoriteItem: $name $author $coverPath $hashCode $tags";
    if (s.length > 100) {
      return s.substring(0, 100);
    }
    return s;
  }
}

class FavoriteItemWithFolderInfo {
  FavoriteItem anime;
  String folder;

  FavoriteItemWithFolderInfo(this.anime, this.folder);

  @override
  bool operator ==(Object other) {
    return other is FavoriteItemWithFolderInfo &&
        other.anime == anime &&
        other.folder == folder;
  }

  @override
  int get hashCode => anime.hashCode ^ folder.hashCode;
}

class FolderSync {
  String folderName;
  String time = getCurTime();
  String key;
  String syncData; // 内容是 json, 存一下选中的文件夹 folderId
  FolderSync(this.folderName, this.key, this.syncData);

  Map<String, dynamic> get syncDataObj => jsonDecode(syncData);
}

extension SQL on String {
  String get toParam => replaceAll('\'', "''").replaceAll('"', "\"\"");
}

class LocalFavoritesManager {
  factory LocalFavoritesManager() =>
      cache ?? (cache = LocalFavoritesManager._create());

  LocalFavoritesManager._create();

  static LocalFavoritesManager? cache;

  late Database _db;

  Future<void> init() async {
    _db = sqlite3.open("${App.dataPath}/local_favorite.db");
    _checkAndCreate();
    await readData();
  }

  void _checkAndCreate() async {
    final tables = _getTablesWithDB();
    if (!tables.contains('folder_sync')) {
      _db.execute("""
      create table folder_sync (
        folder_name text primary key,
        time TEXT,
        key TEXT,
        sync_data TEXT
      );
    """);
    }
    if (!tables.contains('folder_order')) {
      _db.execute("""
      create table folder_order (
        folder_name text primary key,
        order_value int
      );
    """);
    }
    tables.remove('folder_sync');
    tables.remove('folder_order');
    if (tables.isEmpty) return;
    var testTable = tables.first;
    // 检查type是否是主键
    var res = _db.select("""
      PRAGMA table_info("$testTable");
    """);
    bool shouldUpdate = false;
    for (var row in res) {
      if (row["name"] == "type" && row["pk"] == 0) {
        shouldUpdate = true;
        break;
      }
    }
    if (shouldUpdate) {
      for (var table in tables) {
        var tempName = "${table}_dw5d8g2_temp";
        _db.execute("""
          CREATE TABLE "$tempName" AS SELECT * FROM "$table";
          DROP TABLE "$table";
          CREATE TABLE "$table" (
            target text,
            name TEXT,
            author TEXT,
            type int,
            tags TEXT,
            cover_path TEXT,
            time TEXT,
            display_order int,
            primary key (target, type)
          );
          INSERT INTO "$table" SELECT * FROM "$tempName";
          DROP TABLE "$tempName";
        """);
      }
    }
  }

  // void updateUI() {
  //   Future.microtask(
  //       () => StateController.findOrNull(tag: "me page")?.update());
  //   Future.microtask(
  //       () => StateController.findOrNull<FavoritesPageController>()?.update());
  // }

  Future<List<String>> find(String target, FavoriteType type) async {
    var res = <String>[];
    for (var folder in folderNames) {
      var rows = _db.select("""
        select * from "$folder"
        where target == ? and type == ?;
      """, [target, type.key]);
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
        where target == ? and type == ?;
      """, [item.target, item.type.key]);
      if (rows.isNotEmpty) {
        res.add(folder);
      }
    }
    return res;
  }

  Future<void> saveData() async {
    Webdav.uploadData();
  }

  /// read data from json file or temp db.
  ///
  /// This function will delete current database, then create a new one, finally
  /// import data.
  Future<void> readData() async {
    var file = File("${App.dataPath}/localFavorite");
    if (file.existsSync()) {
      Map<String, List<FavoriteItem>> allAnimes = {};
      try {
        var data = (const JsonDecoder().convert(file.readAsStringSync()))
            as Map<String, dynamic>;

        for (var key in data.keys.toList()) {
          Set<FavoriteItem> animes = {};
          for (var anime in data[key]!) {
            animes.add(FavoriteItem.fromJson(anime));
          }
          if (allAnimes.containsKey(key)) {
            animes.addAll(allAnimes[key]!);
          }
          allAnimes[key] = animes.toList();
        }

        await clearAll();

        for (var folder in allAnimes.keys) {
          createFolder(folder, true);
          var animes = allAnimes[folder]!;
          for (int i = 0; i < animes.length; i++) {
            addAnime(folder, animes[i]);
          }
        }
      } catch (e, s) {
        LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
      } finally {
        file.deleteSync();
      }
    } else if ((file = File("${App.dataPath}/local_favorite_temp.db"))
        .existsSync()) {
      var tmp_db = sqlite3.open(file.path);

      final folders = tmp_db
          .select("SELECT name FROM sqlite_master WHERE type='table';")
          .map((element) => element["name"] as String)
          .toList();
      folders.remove('folder_sync');
      folders.remove('folder_order');
      LogManager.addLog(LogLevel.info, "LocalFavoritesManager.readData",
          "read folders from local database $folders");
      var folderToOrder = <String, int>{};
      for (var folder in folders) {
        var res = tmp_db.select("""
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
      var res = <FavoriteItemWithFolderInfo>[];
      for (final folder in folders) {
        var animes = tmp_db.select("""
        select * from "$folder";
      """);
        LogManager.addLog(LogLevel.info, "LocalFavoritesManager.readData",
            "read $folder gets ${animes.length} animes");
        res.addAll(animes.map((element) =>
            FavoriteItemWithFolderInfo(FavoriteItem.fromRow(element), folder)));
      }
      var skips = 0;
      for (var anime in res) {
        if (!folderNames.contains(anime.folder)) {
          createFolder(anime.folder);
        }
        if (!animeExists(
            anime.folder, anime.anime.target, anime.anime.type.key)) {
          addAnime(anime.folder, anime.anime);
          LogManager.addLog(LogLevel.info, "LocalFavoritesManager",
              "add anime ${anime.anime.target} to ${anime.folder}");
        } else {
          skips++;
        }
      }
      LogManager.addLog(LogLevel.info, "LocalFavoritesManager",
          "skipped $skips animes, total ${res.length}");
      tmp_db.dispose();
      file.deleteSync();
    } else {
      LogManager.addLog(LogLevel.info, "LocalFavoritesManager",
          "no local favorites db file found");
    }
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

  void updateOrder(Map<String, int> order) {
    for (var folder in order.keys) {
      _db.execute("""
        insert or replace into folder_order (folder_name, order_value)
        values (?, ?);
      """, [folder, order[folder]]);
    }
  }

  List<FolderSync> _getFolderSyncWithDB() {
    return _db
        .select("SELECT * FROM folder_sync")
        .map((element) => FolderSync(
            element['folder_name'], element['key'], element['sync_data']))
        .toList();
  }

  void updateFolderSyncTime(FolderSync folderSync) {
    _db.execute("""
      update folder_sync
      set time = ?
      where folder_name == ?
    """, [folderSync.time, folderSync.folderName]);
  }

  void insertFolderSync(FolderSync folderSync) {
    // 注意 syncData 不能用 toParam, 否则会没法 jsonDecode
    _db.execute("""
        insert into folder_sync (folder_name, time, key, sync_data)
        values ('${folderSync.folderName.toParam}', '${folderSync.time.toParam}', '${folderSync.key.toParam}', 
          '${folderSync.syncData}');
      """);
  }

  int count(String folderName) {
    return _db.select("""
      select count(*) as c
      from "$folderName"
    """).first["c"];
  }

  List<String> get folderNames => _getFolderNamesWithDB();

  List<FolderSync> get folderSync => _getFolderSyncWithDB();

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
    var rows = _db.select("""
        select * from "$folder"
        ORDER BY display_order;
      """);
    return rows.map((element) => FavoriteItem.fromRow(element)).toList();
  }

  void addTagTo(String folder, String target, String tag) {
    _db.execute("""
      update "$folder"
      set tags = '$tag,' || tags
      where target == '${target.toParam}'
    """);
    saveData();
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

  /// create a folder
  String createFolder(String name, [bool renameWhenInvalidName = false]) {
    if (name.isEmpty) {
      if (renameWhenInvalidName) {
        int i = 0;
        while (folderNames.contains(i.toString())) {
          i++;
        }
        name = i.toString();
      } else {
        throw "name is empty!";
      }
    }
    if (folderNames.contains(name)) {
      if (renameWhenInvalidName) {
        var prevName = name;
        int i = 0;
        while (folderNames.contains(i.toString())) {
          i++;
        }
        name = prevName + i.toString();
      } else {
        throw Exception("Folder is existing");
      }
    }
    _db.execute("""
      create table "$name"(
        target text,
        name TEXT,
        author TEXT,
        type int,
        tags TEXT,
        cover_path TEXT,
        time TEXT,
        display_order int,
        primary key (target, type)
      );
    """);
    saveData();
    return name;
  }

  bool animeExists(String folder, String target, int type) {
    var res = _db.select("""
      select * from "$folder"
      where target == ? and type == ?;
    """, [target, type]);
    return res.isNotEmpty;
  }

  FavoriteItem getAnime(String folder, String target, FavoriteType type) {
    var res = _db.select("""
      select * from "$folder"
      where target == ? and type == ?;
    """, [target, type.key]);
    if (res.isEmpty) {
      throw Exception("Anime not found");
    }
    return FavoriteItem.fromRow(res.first);
  }

  /// add anime to a folder
  ///
  /// This method will download cover to local, to avoid problems like changing url
  void addAnime(String folder, FavoriteItem anime, [int? order]) async {
    _modifiedAfterLastCache = true;
    if (!folderNames.contains(folder)) {
      throw Exception("Folder does not exists");
    }
    var res = _db.select("""
      select * from "$folder"
      where target == '${anime.target}';
    """);
    if (res.isNotEmpty) {
      return;
    }
    if (order != null) {
      _db.execute("""
        insert into "$folder" (target, name, author, type, tags, cover_path, time, display_order)
        values ('${anime.target.toParam}', '${anime.name.toParam}', '${anime.author.toParam}', ${anime.type.key}, 
          '${anime.tags.join(',').toParam}', '${anime.coverPath.toParam}', '${anime.time.toParam}', $order);
      """);
    } else if (appdata.settings[53] == "0") {
      _db.execute("""
        insert into "$folder" (target, name, author, type, tags, cover_path, time, display_order)
        values ('${anime.target.toParam}', '${anime.name.toParam}', '${anime.author.toParam}', ${anime.type.key}, 
          '${anime.tags.join(',').toParam}', '${anime.coverPath.toParam}', '${anime.time.toParam}', ${maxValue(folder) + 1});
      """);
    } else {
      _db.execute("""
        insert into "$folder" (target, name, author, type, tags, cover_path, time, display_order)
        values ('${anime.target.toParam}', '${anime.name.toParam}', '${anime.author.toParam}', ${anime.type.key}, 
          '${anime.tags.join(',').toParam}', '${anime.coverPath.toParam}', '${anime.time.toParam}', ${minValue(folder) - 1});
      """);
    }
    // updateUI();
    saveData();
    // try {
    //   var file =
    //       (await (ImageManager().getImage(anime.coverPath)).last).getFile();
    //   var path =
    //       "${(await getApplicationSupportDirectory()).path}${pathSep}favoritesCover";
    //   var directory = Directory(path);
    //   if (!directory.existsSync()) {
    //     directory.createSync();
    //   }
    //   var hash =
    //       md5.convert(const Utf8Encoder().convert(anime.coverPath)).toString();
    //   file.copySync("$path$pathSep$hash.jpg");
    // } catch (e) {
    //   //忽略
    // }
  }

  // get anime cover
  Future<File> getCover(FavoriteItem item) async {
    var path = "${App.dataPath}/favoritesCover";
    var hash =
        md5.convert(const Utf8Encoder().convert(item.coverPath)).toString();
    var file = File("$path/$hash.jpg");
    if (file.existsSync()) {
      return file;
    }
    // if (item.coverPath.startsWith("file://")) {
    //   var data = DownloadManager()
    //       .getCover(item.coverPath.replaceFirst("file://", ""));
    //   file.createSync(recursive: true);
    //   file.writeAsBytesSync(data.readAsBytesSync());
    //   return file;
    // }
    try {
      // if (EhNetwork().cookiesStr == "") {
      //   await EhNetwork().getCookies(false);
      // }
      // var res = await (ImageManager().getImage(item.coverPath, {
      //   if (item.type == FavoriteType.ehentai) "cookie": EhNetwork().cookiesStr,
      //   if (item.type == FavoriteType.hitomi) "Referer": "https://hitomi.la/"
      // }).last);
      // file.createSync(recursive: true);
      // file.writeAsBytesSync(res.getFile().readAsBytesSync());
      return file;
    } catch (e) {
      await Future.delayed(const Duration(seconds: 5));
      rethrow;
    }
  }

  /// delete a folder
  void deleteFolder(String name) {
    _modifiedAfterLastCache = true;
    _db.execute("""
      delete from folder_sync where folder_name == ?;
    """, [name]);
    _db.execute("""
      drop table "$name";
    """);
  }

  void checkAndDeleteCover(FavoriteItem item) async {
    if ((await find(item.target, item.type)).isEmpty) {
      (await getCover(item)).deleteSync();
    }
  }

  void deleteAnime(String folder, FavoriteItem anime) {
    _modifiedAfterLastCache = true;
    deleteAnimeWithTarget(folder, anime.target, anime.type);
    checkAndDeleteCover(anime);
  }

  void deleteAnimeWithTarget(String folder, String target, FavoriteType type) {
    _modifiedAfterLastCache = true;
    _db.execute("""
      delete from "$folder"
      where target == ? and type == ?;
    """, [target, type.key]);
    saveData();
  }

  Future<void> clearAll() async {
    _db.dispose();
    File("${App.dataPath}/local_favorite.db").deleteSync();
    await init();
    saveData();
  }

  void reorder(List<FavoriteItem> newFolder, String folder) async {
    if (!folderNames.contains(folder)) {
      throw Exception("Failed to reorder: folder not found");
    }
    deleteFolder(folder);
    createFolder(folder);
    for (int i = 0; i < newFolder.length; i++) {
      addAnime(folder, newFolder[i], i);
    }
    // updateUI();
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
    if (folderSync.isNotEmpty) {
      _db.execute("""
      UPDATE folder_sync
      set folder_name = ?
      where folder_name == ?
    """, [after, before]);
    }
    saveData();
  }

  void onReadEnd(String target, FavoriteType type) async {
    _modifiedAfterLastCache = true;
    bool isModified = false;
    for (final folder in folderNames) {
      var rows = _db.select("""
        select * from "$folder"
        where target == ? and type == ?;
      """, [target, type.key]);
      if (rows.isNotEmpty) {
        isModified = true;
        var newTime = DateTime.now()
            .toIso8601String()
            .replaceFirst("T", " ")
            .substring(0, 19);
        String updateLocationSql = "";
        if (appdata.settings[54] == "1") {
          int maxValue = _db.select("""
            SELECT MAX(display_order) AS max_value
            FROM "$folder";
          """).firstOrNull?["max_value"] ?? 0;
          updateLocationSql = "display_order = ${maxValue + 1},";
        } else if (appdata.settings[54] == "2") {
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
              time = '$newTime'
            WHERE target == '${target.toParam}';
          """);
      }
    }
    if (isModified) {
      // updateUI();
    }
    saveData();
  }

  String folderToJsonString(String folderName) {
    var data = <String, dynamic>{};
    data["info"] = "Generated by PicaAnime.";
    data["website"] = "https://github.com/wgh136/PicaAnime";
    data["name"] = folderName;
    var animes = _db
        .select("select * from \"$folderName\";")
        .map((element) => FavoriteItem.fromRow(element).toJson())
        .toList();
    data["animes"] = animes;
    return const JsonEncoder().convert(data);
  }

  (bool, String) loadFolderData(String dataString) {
    try {
      var data =
          const JsonDecoder().convert(dataString) as Map<String, dynamic>;
      final name_ = data["name"] as String;
      var name = name_;
      int i = 0;
      while (folderNames.contains(name)) {
        name = name_ + i.toString();
        i++;
      }
      createFolder(name);
      for (var json in data["animes"]) {
        addAnime(name, FavoriteItem.fromJson(json));
      }
      return (false, "");
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "IO", "Failed to load data.\n$e\n$s");
      return (true, e.toString());
    }
  }

  List<FavoriteItemWithFolderInfo> search(String keyword) {
    var keywordList = keyword.split(" ");
    keyword = keywordList.first;
    var animes = <FavoriteItemWithFolderInfo>[];
    for (var table in folderNames) {
      keyword = "%$keyword%";
      var res = _db.select("""
        SELECT * FROM "$table" 
        WHERE name LIKE ? OR author LIKE ? OR tags LIKE ?;
      """, [keyword, keyword, keyword]);
      for (var anime in res) {
        animes.add(
            FavoriteItemWithFolderInfo(FavoriteItem.fromRow(anime), table));
      }
      if (animes.length > 200) {
        break;
      }
    }

    bool test(FavoriteItemWithFolderInfo anime, String keyword) {
      if (anime.anime.name.contains(keyword)) {
        return true;
      } else if (anime.anime.author.contains(keyword)) {
        return true;
      } else if (anime.anime.tags.any((element) => element.contains(keyword))) {
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

  void editTags(String target, String folder, List<String> tags) {
    _db.execute("""
        update "$folder"
        set tags = '${tags.join(",")}'
        where target == '${target.toParam}';
      """);
  }

  final _cachedFavoritedTargets = <String, bool>{};

  bool isExist(String target) {
    if (_modifiedAfterLastCache) {
      _cacheFavoritedTargets();
    }
    return _cachedFavoritedTargets.containsKey(target);
  }

  bool _modifiedAfterLastCache = true;

  void _cacheFavoritedTargets() {
    _modifiedAfterLastCache = false;
    _cachedFavoritedTargets.clear();
    for (var folder in folderNames) {
      var res = _db.select("""
        select target from "$folder";
      """);
      for (var row in res) {
        _cachedFavoritedTargets[row["target"]] = true;
      }
    }
  }

  void updateInfo(String folder, FavoriteItem anime) {
    _db.execute("""
      update "$folder"
      set name = ?, author = ?, cover_path = ?, tags = ?
      where target == ? and type == ?;
    """, [
      anime.name,
      anime.author,
      anime.coverPath,
      anime.tags.join(","),
      anime.target,
      anime.type.key
    ]);
  }
}
