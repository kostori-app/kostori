import 'dart:convert';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:kostori/foundation/favorites.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:kostori/network/download.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/log.dart';

class LocalAnime with HistoryMixin implements Anime {
  @override
  final String id;

  @override
  final String title;

  @override
  final String subtitle;

  @override
  final List<String> tags;

  /// The name of the directory where the anime is stored
  final String directory;

  /// key: chapter id, value: chapter title
  ///
  /// chapter id is the name of the directory in `LocalManager.path/$directory`
  final Map<String, Map<String, String>>? episode;

  /// relative path to the cover image
  @override
  final String cover;

  final AnimeType animeType;

  final List<String> downloadedChapters;

  final DateTime createdAt;

  const LocalAnime({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.directory,
    required this.episode,
    required this.cover,
    required this.animeType,
    required this.downloadedChapters,
    required this.createdAt,
  });

  LocalAnime.fromRow(Row row)
      : id = row[0] as String,
        title = row[1] as String,
        subtitle = row[2] as String,
        tags = List.from(jsonDecode(row[3] as String)),
        directory = row[4] as String,
        episode = MapOrNull.from(jsonDecode(row[5] as String)),
        cover = row[6] as String,
        animeType = AnimeType(row[7] as int),
        downloadedChapters = List.from(jsonDecode(row[8] as String)),
        createdAt = DateTime.fromMillisecondsSinceEpoch(row[9] as int);

  File get coverFile => File(FilePath.join(
        LocalManager().path,
        directory,
        cover,
      ));

  @override
  String get description => "";

  @override
  String get sourceKey =>
      animeType == AnimeType.local ? "local" : animeType.sourceKey;

  @override
  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "cover": cover,
      "id": id,
      "subTitle": subtitle,
      "tags": tags,
      "description": description,
      "sourceKey": sourceKey,
    };
  }

  int? get maxPage => null;

  @override
  HistoryType get historyType => animeType;

  @override
  String? get subTitle => subtitle;

  @override
  String? get language => null;

  @override
  String? get favoriteId => null;

  @override
  double? get stars => null;
}

class LocalManager with ChangeNotifier {
  static LocalManager? _instance;

  LocalManager._();

  factory LocalManager() {
    return _instance ??= LocalManager._();
  }

  late Database _db;

  /// path to the directory where all the animes are stored
  late String path;

  Directory get directory => Directory(path);

  void _checkNoMedia() {
    if (App.isAndroid) {
      var file = File(FilePath.join(path, '.nomedia'));
      if (!file.existsSync()) {
        file.createSync();
      }
    }
  }

  // return error message if failed
  Future<String?> setNewPath(String newPath) async {
    var newDir = Directory(newPath);
    if (!await newDir.exists()) {
      return "Directory does not exist";
    }
    if (!await newDir.list().isEmpty) {
      return "Directory is not empty";
    }
    try {
      await copyDirectoryIsolate(
        Directory(path),
        newDir,
      );
      await File(FilePath.join(App.dataPath, 'local_path'))
          .writeAsString(newPath);
    } catch (e, s) {
      Log.error("IO", e, s);
      return e.toString();
    }
    await Directory(path).deleteIgnoreError(recursive: true);
    path = newPath;
    _checkNoMedia();
    return null;
  }

  Future<String> findDefaultPath() async {
    if (App.isAndroid) {
      var external = await getExternalStorageDirectories();
      if (external != null && external.isNotEmpty) {
        return FilePath.join(external.first.path, 'local');
      } else {
        return FilePath.join(App.dataPath, 'local');
      }
    } else if (App.isIOS) {
      var oldPath = FilePath.join(App.dataPath, 'local');
      if (Directory(oldPath).existsSync() &&
          Directory(oldPath).listSync().isNotEmpty) {
        return oldPath;
      } else {
        var directory = await getApplicationDocumentsDirectory();
        return FilePath.join(directory.path, 'local');
      }
    } else {
      return FilePath.join(App.dataPath, 'local');
    }
  }

  Future<void> _checkPathValidation() async {
    var testFile = File(FilePath.join(path, 'venera_test'));
    try {
      testFile.createSync();
      testFile.deleteSync();
    } catch (e) {
      Log.error("IO",
          "Failed to create test file in local path: $e\nUsing default path instead.");
      path = await findDefaultPath();
    }
  }

  Future<void> init() async {
    _db = sqlite3.open(
      '${App.dataPath}/local.db',
    );
    _db.execute('''
      CREATE TABLE IF NOT EXISTS animes (
        id TEXT NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        tags TEXT NOT NULL,
        directory TEXT NOT NULL,
        episode TEXT NOT NULL,
        cover TEXT NOT NULL,
        anime_type INTEGER NOT NULL,
        downloadedChapters TEXT NOT NULL,
        created_at INTEGER,
        PRIMARY KEY (id, anime_type)
      );
    ''');
    if (File(FilePath.join(App.dataPath, 'local_path')).existsSync()) {
      path = File(FilePath.join(App.dataPath, 'local_path')).readAsStringSync();
      if (!directory.existsSync()) {
        path = await findDefaultPath();
      }
    } else {
      path = await findDefaultPath();
    }
    try {
      if (!directory.existsSync()) {
        await directory.create();
      }
    } catch (e, s) {
      Log.error("IO", "Failed to create local folder: $e", s);
    }
    _checkPathValidation();
    _checkNoMedia();
    restoreDownloadingTasks();
  }

  String findValidId(AnimeType type) {
    final res = _db.select(
      '''
      SELECT id FROM animes WHERE anime_type = ? 
      ORDER BY CAST(id AS INTEGER) DESC
      LIMIT 1;
      ''',
      [type.value],
    );
    if (res.isEmpty) {
      return '1';
    }
    return (int.parse((res.first[0])) + 1).toString();
  }

  Future<void> add(LocalAnime anime, [String? id]) async {
    var old = find(id ?? anime.id, anime.animeType);
    var downloaded = anime.downloadedChapters;
    if (old != null) {
      downloaded.addAll(old.downloadedChapters);
    }
    _db.execute(
      'INSERT OR REPLACE INTO animes VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
      [
        id ?? anime.id,
        anime.title,
        anime.subtitle,
        jsonEncode(anime.tags),
        anime.directory,
        jsonEncode(anime.episode),
        anime.cover,
        anime.animeType.value,
        jsonEncode(downloaded),
        anime.createdAt.millisecondsSinceEpoch,
      ],
    );
    notifyListeners();
  }

  void remove(String id, AnimeType animeType) async {
    _db.execute(
      'DELETE FROM animes WHERE id = ? AND anime_type = ?;',
      [id, animeType.value],
    );
    notifyListeners();
  }

  void removeAnime(LocalAnime anime) {
    remove(anime.id, anime.animeType);
    notifyListeners();
  }

  List<LocalAnime> getAnimes(LocalSortType sortType) {
    var res = _db.select('''
      SELECT * FROM animes
      ORDER BY 
        ${sortType.value == 'name' ? 'title' : 'created_at'} 
        ${sortType.value == 'time_asc' ? 'ASC' : 'DESC'}
      ;
    ''');
    return res.map((row) => LocalAnime.fromRow(row)).toList();
  }

  LocalAnime? find(String id, AnimeType animeType) {
    final res = _db.select(
      'SELECT * FROM animes WHERE id = ? AND anime_type = ?;',
      [id, animeType.value],
    );
    if (res.isEmpty) {
      return null;
    }
    return LocalAnime.fromRow(res.first);
  }

  @override
  void dispose() {
    super.dispose();
    _db.dispose();
  }

  List<LocalAnime> getRecent() {
    final res = _db.select('''
      SELECT * FROM animes
      ORDER BY created_at DESC
      LIMIT 20;
    ''');
    return res.map((row) => LocalAnime.fromRow(row)).toList();
  }

  int get count {
    final res = _db.select('''
      SELECT COUNT(*) FROM animes;
    ''');
    return res.first[0] as int;
  }

  LocalAnime? findByName(String name) {
    final res = _db.select('''
      SELECT * FROM animes 
      WHERE title = ? OR directory = ?;
    ''', [name, name]);
    if (res.isEmpty) {
      return null;
    }
    return LocalAnime.fromRow(res.first);
  }

  List<LocalAnime> search(String keyword) {
    final res = _db.select('''
      SELECT * FROM animes
      WHERE title LIKE ? OR tags LIKE ? OR subtitle LIKE ?
      ORDER BY created_at DESC;
    ''', ['%$keyword%', '%$keyword%', '%$keyword%']);
    return res.map((row) => LocalAnime.fromRow(row)).toList();
  }

  Future<List<String>> getImages(String id, AnimeType type, Object ep) async {
    if (ep is! String && ep is! int) {
      throw "Invalid ep";
    }
    var anime = find(id, type) ?? (throw "anime Not Found");
    var directory = Directory(FilePath.join(path, anime.directory));
    if (anime.episode != null) {
      var cid =
          ep is int ? anime.episode!.keys.elementAt(ep - 1) : (ep as String);
      directory = Directory(FilePath.join(directory.path, cid));
    }
    var files = <File>[];
    await for (var entity in directory.list()) {
      if (entity is File) {
        if (entity.absolute.path.replaceFirst(path, '').substring(1) ==
            anime.cover) {
          continue;
        }
        //Hidden file in some file system
        if (entity.name.startsWith('.')) {
          continue;
        }
        files.add(entity);
      }
    }
    files.sort((a, b) {
      var ai = int.tryParse(a.name.split('.').first);
      var bi = int.tryParse(b.name.split('.').first);
      if (ai != null && bi != null) {
        return ai.compareTo(bi);
      }
      return a.name.compareTo(b.name);
    });
    return files.map((e) => "file://${e.path}").toList();
  }

  bool isDownloaded(String id, AnimeType type, [int? ep]) {
    var anime = find(id, type);
    if (anime == null) return false;
    if (anime.episode == null) return true;
    return anime.downloadedChapters
        .contains(anime.episode!.keys.elementAt(ep! - 1));
  }

  List<DownloadTask> downloadingTasks = [];

  bool isDownloading(String id, AnimeType type) {
    return downloadingTasks
        .any((element) => element.id == id && element.animeType == type);
  }

  Future<Directory> findValidDirectory(
      String id, AnimeType type, String name) async {
    var anime = find(id, type);
    if (anime != null) {
      return Directory(FilePath.join(path, anime.directory));
    }
    var dir = findValidDirectoryName(path, name);
    return Directory(FilePath.join(path, dir)).create().then((value) => value);
  }

  void completeTask(DownloadTask task) {
    add(task.toLocalAnime());
    downloadingTasks.remove(task);
    notifyListeners();
    saveCurrentDownloadingTasks();
    downloadingTasks.firstOrNull?.resume();
  }

  void removeTask(DownloadTask task) {
    downloadingTasks.remove(task);
    notifyListeners();
    saveCurrentDownloadingTasks();
  }

  void moveToFirst(DownloadTask task) {
    if (downloadingTasks.first != task) {
      var shouldResume = !downloadingTasks.first.isPaused;
      downloadingTasks.first.pause();
      downloadingTasks.remove(task);
      downloadingTasks.insert(0, task);
      notifyListeners();
      saveCurrentDownloadingTasks();
      if (shouldResume) {
        downloadingTasks.first.resume();
      }
    }
  }

  Future<void> saveCurrentDownloadingTasks() async {
    var tasks = downloadingTasks.map((e) => e.toJson()).toList();
    await File(FilePath.join(App.dataPath, 'downloading_tasks.json'))
        .writeAsString(jsonEncode(tasks));
  }

  void restoreDownloadingTasks() {
    var file = File(FilePath.join(App.dataPath, 'downloading_tasks.json'));
    if (file.existsSync()) {
      try {
        var tasks = jsonDecode(file.readAsStringSync());
        for (var e in tasks) {
          var task = DownloadTask.fromJson(e);
          if (task != null) {
            downloadingTasks.add(task);
          }
        }
      } catch (e) {
        file.delete();
        Log.error("LocalManager", "Failed to restore downloading tasks: $e");
      }
    }
  }

  void addTask(DownloadTask task) {
    downloadingTasks.add(task);
    notifyListeners();
    saveCurrentDownloadingTasks();
    downloadingTasks.first.resume();
  }

  void deleteAnime(LocalAnime c, [bool removeFileOnDisk = true]) {
    if (removeFileOnDisk) {
      var dir = Directory(FilePath.join(path, c.directory));
      dir.deleteIgnoreError(recursive: true);
    }
    //Deleting a local comic means that it's nolonger available, thus both favorite and history should be deleted.
    if (HistoryManager().findSync(c.id, c.animeType) != null) {
      HistoryManager().remove(c.id, c.animeType);
    }
    assert(c.animeType == AnimeType.local);
    var folders = LocalFavoritesManager().find(c.id, c.animeType);
    for (var f in folders) {
      LocalFavoritesManager().deleteAnimeWithId(f, c.id, c.animeType);
    }
    remove(c.id, c.animeType);
    notifyListeners();
  }
}

enum LocalSortType {
  name("name"),
  timeAsc("time_asc"),
  timeDesc("time_desc");

  final String value;

  const LocalSortType(this.value);

  static LocalSortType fromString(String value) {
    for (var type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return name;
  }
}
