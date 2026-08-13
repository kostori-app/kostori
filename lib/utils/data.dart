import 'dart:convert';
import 'dart:isolate';

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/history_write_service.dart';
import 'package:kostori/database/search_history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/init.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/utils/io.dart';
import 'package:zip_flutter/zip_flutter.dart';

/// 原子替换目标文件：先备份旧文件为 .bak，再移动新文件到位，成功后删除备份。
/// 同分区 rename 是原子的，若中途崩溃，下次调用 [recoverStaleBackups] 可回滚。
/// 返回 true 表示替换成功。
bool _atomicReplace(String newPath, String targetPath) {
  final target = File(targetPath);
  final backup = File('$targetPath.bak');
  try {
    // 1. 旧文件 → 备份（若存在）
    if (target.existsSync()) {
      backup.deleteIfExistsSync();
      target.renameSync(backup.path);
    }
    // 2. 新文件 → 目标（rename 原子）
    File(newPath).renameSync(targetPath);
    // 3. 成功，删备份
    backup.deleteIfExistsSync();
    return true;
  } catch (e) {
    // 失败回滚：若目标缺失但备份存在，恢复备份
    if (!target.existsSync() && backup.existsSync()) {
      try {
        backup.renameSync(targetPath);
      } catch (_) {}
    }
    DebugLog.error('atomicReplace', '替换 $targetPath 失败：$e');
    return false;
  }
}

/// 启动时恢复上次同步中断遗留的 .bak 文件（崩溃兜底）。
/// 若目标文件缺失但 .bak 存在，说明上次替换中途崩溃，用备份恢复。
void recoverStaleBackups() {
  final dataPath = App.dataPath;
  for (final name in const [
    'history.db',
    'local_favorite.db',
    'bangumi.db',
    'stats.db',
    'search_history.db',
    'cookie.db',
    'ai_database.db',
  ]) {
    final target = File('$dataPath${Platform.pathSeparator}$name');
    final backup = File('$dataPath${Platform.pathSeparator}$name.bak');
    try {
      if (!target.existsSync() && backup.existsSync()) {
        backup.renameSync(target.path);
        DebugLog.info('recoverStaleBackups', '已从备份恢复 $name');
      } else if (backup.existsSync()) {
        // 目标与备份都存在，说明上次已替换成功但删备份失败，直接删备份
        backup.deleteIfExistsSync();
      }
    } catch (e) {
      DebugLog.error('recoverStaleBackups', '$name 恢复失败：$e');
    }
  }
}

Future<File> exportAppData() async {
  var time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  var cacheFilePath = FilePath.join(App.cachePath, '$time.kostori');
  var cacheFile = File(cacheFilePath);
  var dataPath = App.dataPath;
  if (await cacheFile.exists()) {
    await cacheFile.delete();
  }
  // 暂停后台历史写入，保证复制的 history.db 完整一致
  HistoryWriteService.pause();
  // 额外导出字段级合并数据（逐条 JSON），供多端合并而非整库覆盖
  var historyMergeFile = FilePath.join(App.cachePath, 'history_merge.json');
  var favoritesMergeFile = FilePath.join(App.cachePath, 'favorites_merge.json');
  var statsMergeFile = FilePath.join(App.cachePath, 'stats_merge.json');
  try {
    final histories = await HistoryManager().getAll();
    // 序列化（jsonEncode 大列表耗时，放入 isolate 避免阻塞 UI）
    final jsonStr = await Isolate.run(() {
      return jsonEncode(histories.map((h) => h.toJson()).toList());
    });
    await File(historyMergeFile).writeAsString(jsonStr);
  } catch (e) {
    DebugLog.error('exportAppData', 'history_merge.json 导出失败：$e');
  }
  try {
    final favorites = LocalFavoritesManager().getAllFavoriteItemsForMerge();
    final jsonStr = await Isolate.run(() {
      return jsonEncode(favorites.map((f) => f.toMergeJson()).toList());
    });
    await File(favoritesMergeFile).writeAsString(jsonStr);
  } catch (e) {
    DebugLog.error('exportAppData', 'favorites_merge.json 导出失败：$e');
  }
  try {
    final stats = await StatsManager().getStatsAll();
    final jsonStr = await Isolate.run(() {
      return jsonEncode(stats.map((s) => s.toMergeJson()).toList());
    });
    await File(statsMergeFile).writeAsString(jsonStr);
  } catch (e) {
    DebugLog.error('exportAppData', 'stats_merge.json 导出失败：$e');
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
    final hmf = File(historyMergeFile);
    if (hmf.existsSync()) {
      zipFile.addFile("history_merge.json", historyMergeFile);
    }
    final fmf = File(favoritesMergeFile);
    if (fmf.existsSync()) {
      zipFile.addFile("favorites_merge.json", favoritesMergeFile);
    }
    final smf = File(statsMergeFile);
    if (smf.existsSync()) {
      zipFile.addFile("stats_merge.json", statsMergeFile);
    }
    for (var file in Directory(
      FilePath.join(dataPath, "anime_source"),
    ).listSync()) {
      if (file is File) {
        zipFile.addFile("anime_source/${file.name}", file.path);
      }
    }
    zipFile.close();
  });
  HistoryWriteService.resume();
  File(historyMergeFile).deleteIgnoreError();
  File(favoritesMergeFile).deleteIgnoreError();
  File(statsMergeFile).deleteIgnoreError();
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
    DebugLog.info('importAppData', '开始导入数据');
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
      DebugLog.info('importAppData', '检查数据版本');
    }
    // 字段级合并优先：若有 history_merge.json，逐条按 lastWatchTime 合并，
    // 保留两端各自新增/更新的历史，不整库覆盖
    final mergeFile = cacheDir.joinFile("history_merge.json");
    var mergedHistory = false;
    if (await mergeFile.exists()) {
      try {
        final list = jsonDecode(await mergeFile.readAsString());
        if (list is List) {
          final histories = list
              .whereType<Map>()
              .map((m) => History.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          HistoryWriteService.pause();
          await HistoryManager().mergeHistoryList(histories);
          HistoryWriteService.resume();
          mergedHistory = true;
          providerContainer.invalidate(historyAllProvider);
        }
      } catch (e) {
        DebugLog.error('importAppData', 'history 字段级合并失败：$e');
      }
    }
    if (!mergedHistory && await historyFile.exists()) {
      // 旧版导出（无 history_merge.json）→ 回退整库覆盖（原子替换 + 备份）
      DebugLog.info('importAppData', '开始导入historyFile（整库覆盖）');
      HistoryWriteService.pause();
      HistoryWriteService.closeConnection();
      await HistoryManager().reinit(() async {
        _atomicReplace(
          historyFile.path,
          FilePath.join(App.dataPath, "history.db"),
        );
      });
      providerContainer.invalidate(historyAllProvider);
      HistoryWriteService.resume();
    }
    // 收藏字段级合并优先：并集合并，保留两端各自收藏
    final favoritesMergeFile = cacheDir.joinFile("favorites_merge.json");
    var mergedFavorites = false;
    if (await favoritesMergeFile.exists()) {
      try {
        final list = jsonDecode(await favoritesMergeFile.readAsString());
        if (list is List) {
          final items = list
              .whereType<Map>()
              .map((m) => FavoriteItem.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          LocalFavoritesManager().mergeFavoriteList(items);
          mergedFavorites = true;
        }
      } catch (e) {
        DebugLog.error('importAppData', 'favorites 字段级合并失败：$e');
      }
    }
    if (!mergedFavorites && await localFavoriteFile.exists()) {
      DebugLog.info('importAppData', '开始导入localFavoriteFile（整库覆盖）');
      LocalFavoritesManager().close();
      _atomicReplace(
        localFavoriteFile.path,
        FilePath.join(App.dataPath, "local_favorite.db"),
      );
      LocalFavoritesManager().init();
    }
    if (await bangumiFile.exists()) {
      DebugLog.info('importAppData', '开始导入bangumiFile');
      providerContainer.invalidate(bangumiInitProvider);
      await providerContainer.read(bangumiManagerProvider).reinit(() async {
        _atomicReplace(
          bangumiFile.path,
          FilePath.join(App.dataPath, "bangumi.db"),
        );
      });
      providerContainer.invalidate(bangumiInitProvider);
    }
    // 评分字段级合并优先：逐条合并 DailyEvent 列表
    final statsMergeFile = cacheDir.joinFile("stats_merge.json");
    var mergedStats = false;
    if (await statsMergeFile.exists()) {
      try {
        final list = jsonDecode(await statsMergeFile.readAsString());
        if (list is List) {
          final items = list
              .whereType<Map>()
              .map(
                (m) =>
                    StatsDataImpl.fromMergeJson(Map<String, dynamic>.from(m)),
              )
              .toList();
          await StatsManager().mergeStatsList(items);
          mergedStats = true;
        }
      } catch (e) {
        DebugLog.error('importAppData', 'stats 字段级合并失败：$e');
      }
    }
    if (!mergedStats && await statsFile.exists()) {
      DebugLog.info('importAppData', '开始导入statsFile（整库覆盖）');
      await StatsManager().reinit(() async {
        _atomicReplace(statsFile.path, FilePath.join(App.dataPath, "stats.db"));
      });
    }
    if (await searchHistoryFile.exists()) {
      DebugLog.info('importAppData', '开始导入searchHistoryFile');
      await SearchHistoryManager().reinit(() async {
        _atomicReplace(
          searchHistoryFile.path,
          FilePath.join(App.dataPath, "search_history.db"),
        );
      });
    }
    if (await appdataFile.exists()) {
      DebugLog.info('importAppData', '开始导入appdataFile');
      var content = await appdataFile.readAsString();
      var data = jsonDecode(content);
      appdata.syncData(data);
    }
    if (await cookieFile.exists()) {
      DebugLog.info('importAppData', '开始导入cookieFile');
      await SingleInstanceCookieJar.instance?.dispose();
      SingleInstanceCookieJar.instance = null;
      _atomicReplace(cookieFile.path, FilePath.join(App.dataPath, "cookie.db"));
      SingleInstanceCookieJar.instance = SingleInstanceCookieJar(
        FilePath.join(App.dataPath, "cookie.db"),
      );
    }
    var aiFile = cacheDir.joinFile("ai_database.db");
    if (await aiFile.exists()) {
      DebugLog.info('importAppData', '开始导入aiFile');
      await AiDatabase.instance.close();
      _atomicReplace(
        aiFile.path,
        FilePath.join(App.dataPath, "ai_database.db"),
      );
      AiDatabase.init();
    }
    var animeSourceDir = FilePath.join(cacheDirPath, "anime_source");
    if (Directory(animeSourceDir).existsSync()) {
      DebugLog.info('importAppData', '开始导入animeSource');
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
  } catch (e) {
    DebugLog.error('importAppData', '$e');
  } finally {
    cacheDir.deleteIgnoreError(recursive: true);
  }
}
