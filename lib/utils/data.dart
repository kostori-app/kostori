import 'dart:convert';
import 'dart:isolate';

import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:zip_flutter/zip_flutter.dart';

import 'io.dart';

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
    var appdata = FilePath.join(dataPath, "appdata.json");
    var cookies = FilePath.join(dataPath, "cookie.db");
    zipFile.addFile("history.db", historyFile);
    zipFile.addFile("local_favorite.db", localFavoriteFile);
    zipFile.addFile("bangumi.db", bangumiFile);
    zipFile.addFile("appdata.json", appdata);
    zipFile.addFile("cookie.db", cookies);
    for (var file
        in Directory(FilePath.join(dataPath, "anime_source")).listSync()) {
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
      HistoryManager().close();
      File(FilePath.join(App.dataPath, "history.db")).deleteIfExistsSync();
      historyFile.renameSync(FilePath.join(App.dataPath, "history.db"));
      HistoryManager().init();
    }
    if (await localFavoriteFile.exists()) {
      LocalFavoritesManager().close();
      File(FilePath.join(App.dataPath, "local_favorite.db"))
          .deleteIfExistsSync();
      localFavoriteFile
          .renameSync(FilePath.join(App.dataPath, "local_favorite.db"));
      LocalFavoritesManager().init();
    }
    if (await bangumiFile.exists()) {
      BangumiManager().close();
      File(FilePath.join(App.dataPath, "bangumi.db")).deleteIfExistsSync();
      bangumiFile.renameSync(FilePath.join(App.dataPath, "bangumi.db"));
      BangumiManager().init();
    }
    if (await appdataFile.exists()) {
      var content = await appdataFile.readAsString();
      var data = jsonDecode(content);
      appdata.syncData(data);
    }
    if (await cookieFile.exists()) {
      SingleInstanceCookieJar.instance?.dispose();
      File(FilePath.join(App.dataPath, "cookie.db")).deleteIfExistsSync();
      cookieFile.renameSync(FilePath.join(App.dataPath, "cookie.db"));
      SingleInstanceCookieJar.instance =
          SingleInstanceCookieJar(FilePath.join(App.dataPath, "cookie.db"))
            ..init();
    }
    var animeSourceDir = FilePath.join(cacheDirPath, "anime_source");
    if (Directory(animeSourceDir).existsSync()) {
      Directory(FilePath.join(App.dataPath, "anime_source"))
          .deleteIfExistsSync(recursive: true);
      Directory(FilePath.join(App.dataPath, "anime_source")).createSync();
      for (var file in Directory(animeSourceDir).listSync()) {
        if (file is File) {
          var targetFile =
              FilePath.join(App.dataPath, "anime_source", file.name);
          await file.copy(targetFile);
        }
      }
      await AnimeSourceManager().reload();
    }
  } finally {
    cacheDir.deleteIgnoreError(recursive: true);
  }
}
