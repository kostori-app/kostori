import 'dart:convert';
import 'dart:isolate';

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/search_history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/init.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/utils/io.dart';
import 'package:zip_flutter/zip_flutter.dart';

Future<File> exportAppData() async {
  var time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  var cacheFilePath = FilePath.join(App.cachePath, '$time.kostori');
  var cacheFile = File(cacheFilePath);
  var dataPath = App.dataPath;
  if (await cacheFile.exists()) {
    await cacheFile.delete();
  }
  await Isolate.run(() {
    var zipFile = ZipFile.open(cacheFilePath);
    var historyFile = FilePath.join(dataPath, "history.db");
    var localFavoriteFile = FilePath.join(dataPath, "local_favorite.db");
    var bangumiFile = FilePath.join(dataPath, "bangumi.db");
    var statsFile = FilePath.join(dataPath, "stats.db");
    var searchHistoryFile = FilePath.join(dataPath, "search_history.db");
    var appdata = FilePath.join(dataPath, "appdata.json");
    var cookies = FilePath.join(dataPath, "cookie.db");
    var aiDatabase = FilePath.join(dataPath, "ai_database.db");
    zipFile.addFile("history.db", historyFile);
    zipFile.addFile("local_favorite.db", localFavoriteFile);
    zipFile.addFile("bangumi.db", bangumiFile);
    zipFile.addFile("stats.db", statsFile);
    zipFile.addFile("search_history.db", searchHistoryFile);
    zipFile.addFile("appdata.json", appdata);
    zipFile.addFile("cookie.db", cookies);
    zipFile.addFile("ai_database.db", aiDatabase);
    for (var file in Directory(
      FilePath.join(dataPath, "anime_source"),
    ).listSync()) {
      if (file is File) {
        zipFile.addFile("anime_source/${file.name}", file.path);
      }
    }
    zipFile.close();
  });
  return cacheFile;
}

Future<void> importAppData(File file, [bool checkVersion = false]) async {
  var cacheDirPath = FilePath.join(App.cachePath, 'temp_data');
  var cacheDir = Directory(cacheDirPath);
  if (cacheDir.existsSync()) {
    cacheDir.deleteSync(recursive: true);
  }
  cacheDir.createSync();
  try {
    await Isolate.run(() {
      ZipFile.openAndExtract(file.path, cacheDirPath);
    });
    var historyFile = cacheDir.joinFile("history.db");
    var localFavoriteFile = cacheDir.joinFile("local_favorite.db");
    var bangumiFile = cacheDir.joinFile("bangumi.db");
    var statsFile = cacheDir.joinFile("stats.db");
    var searchHistoryFile = cacheDir.joinFile("search_history.db");
    var appdataFile = cacheDir.joinFile("appdata.json");
    var cookieFile = cacheDir.joinFile("cookie.db");
    if (checkVersion && appdataFile.existsSync()) {
      var data = jsonDecode(await appdataFile.readAsString());
      var version = data["settings"]["dataVersion"];
      if (version is int && version <= appdata.settings["dataVersion"]) {
        return;
      }
    }
    if (await historyFile.exists()) {
      await HistoryManager().reinit(() async {
        File(FilePath.join(App.dataPath, "history.db")).deleteIfExistsSync();
        historyFile.renameSync(FilePath.join(App.dataPath, "history.db"));
      });
      providerContainer.invalidate(historyAllProvider);
    }
    if (await localFavoriteFile.exists()) {
      LocalFavoritesManager().close();
      File(
        FilePath.join(App.dataPath, "local_favorite.db"),
      ).deleteIfExistsSync();
      localFavoriteFile.renameSync(
        FilePath.join(App.dataPath, "local_favorite.db"),
      );
      LocalFavoritesManager().init();
    }
    if (await bangumiFile.exists()) {
      await providerContainer.read(bangumiManagerProvider).reinit(() async {
        File(FilePath.join(App.dataPath, "bangumi.db")).deleteIfExistsSync();
        bangumiFile.renameSync(FilePath.join(App.dataPath, "bangumi.db"));
      });
    }
    if (await statsFile.exists()) {
      await StatsManager().reinit(() async {
        File(FilePath.join(App.dataPath, "stats.db")).deleteIfExistsSync();
        statsFile.renameSync(FilePath.join(App.dataPath, "stats.db"));
      });
    }
    if (await searchHistoryFile.exists()) {
      await SearchHistoryManager().reinit(() async {
        File(
          FilePath.join(App.dataPath, "search_history.db"),
        ).deleteIfExistsSync();
        searchHistoryFile.renameSync(
          FilePath.join(App.dataPath, "search_history.db"),
        );
      });
    }
    if (await appdataFile.exists()) {
      var content = await appdataFile.readAsString();
      var data = jsonDecode(content);
      appdata.syncData(data);
    }
    if (await cookieFile.exists()) {
      await SingleInstanceCookieJar.instance?.dispose();
      SingleInstanceCookieJar.instance = null;
      File(FilePath.join(App.dataPath, "cookie.db")).deleteIfExistsSync();
      cookieFile.renameSync(FilePath.join(App.dataPath, "cookie.db"));
      SingleInstanceCookieJar.instance = SingleInstanceCookieJar(
        FilePath.join(App.dataPath, "cookie.db"),
      );
    }
    var aiFile = cacheDir.joinFile("ai_database.db");
    if (await aiFile.exists()) {
      await AiDatabase.instance.close();
      File(FilePath.join(App.dataPath, "ai_database.db")).deleteIfExistsSync();
      aiFile.renameSync(FilePath.join(App.dataPath, "ai_database.db"));
      AiDatabase.init();
    }
    var animeSourceDir = FilePath.join(cacheDirPath, "anime_source");
    if (Directory(animeSourceDir).existsSync()) {
      Directory(
        FilePath.join(App.dataPath, "anime_source"),
      ).deleteIfExistsSync(recursive: true);
      Directory(FilePath.join(App.dataPath, "anime_source")).createSync();
      for (var file in Directory(animeSourceDir).listSync()) {
        if (file is File) {
          var targetFile = FilePath.join(
            App.dataPath,
            "anime_source",
            file.name,
          );
          await file.copy(targetFile);
        }
      }
      await AnimeSourceManager().reload();
    }
  } finally {
    cacheDir.deleteIgnoreError(recursive: true);
  }
}
