import 'dart:convert';
import 'dart:isolate';

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/ai_task_database.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/history_write_service.dart';
import 'package:kostori/database/search_history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/ai_service/ai_skill_store.dart';
import 'package:kostori/foundation/ai_service/assistant_profile.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/ai_service/group_chat.dart';
import 'package:kostori/foundation/ai_service/role_management.dart';
import 'package:kostori/foundation/ai_service/setting_library.dart';
import 'package:kostori/foundation/ai_service/story.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/me_plugin/me_plugin.dart';
import 'package:kostori/foundation/text_rule.dart';
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
    'ai_tasks.db',
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
  var pluginHistoryMergeFile = FilePath.join(App.cachePath, 'plugin_history_merge.json');
  var textRulesMergeFile = FilePath.join(App.cachePath, 'text_rules_merge.json');
  var progressMergeFile = FilePath.join(App.cachePath, 'progress_merge.json');
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
    final events = await HistoryManager().getAllPluginEvents();
    final jsonStr = await Isolate.run(() {
      return jsonEncode(events.map((e) => e.toJson()).toList());
    });
    await File(pluginHistoryMergeFile).writeAsString(jsonStr);
  } catch (e) {
    DebugLog.error('exportAppData', 'plugin_history_merge.json 导出失败：$e');
  }
  try {
    final rules = await HistoryManager().getTextRules();
    final jsonStr = await Isolate.run(() {
      return jsonEncode(rules);
    });
    await File(textRulesMergeFile).writeAsString(jsonStr);
  } catch (e) {
    DebugLog.error('exportAppData', 'text_rules_merge.json 导出失败：$e');
  }
  try {
    final progress = await HistoryManager().getAllProgress();
    final jsonStr = await Isolate.run(() {
      return jsonEncode(progress.map((p) => p.toJson()).toList());
    });
    await File(progressMergeFile).writeAsString(jsonStr);
  } catch (e) {
    DebugLog.error('exportAppData', 'progress_merge.json 导出失败：$e');
  }
  var assistantMergeFile = FilePath.join(App.cachePath, 'assistant_merge.json');
  try {
    final payload = {
      'profiles': AssistantProfileStore.instance.exportMergeData(),
      'memory': AssistantMemoryStore.instance.exportMergeData(),
    };
    final jsonStr = await Isolate.run(() => jsonEncode(payload));
    await File(assistantMergeFile).writeAsString(jsonStr);
  } catch (e) {
    DebugLog.error('exportAppData', 'assistant_merge.json 导出失败：$e');
  }
  var sourceConfigMergeFile = FilePath.join(
    App.cachePath,
    'source_config_merge.json',
  );
  try {
    final jsonStr = await Isolate.run(
      () => jsonEncode(AnimeSourceManager().exportSourceConfig()),
    );
    await File(sourceConfigMergeFile).writeAsString(jsonStr);
  } catch (e) {
    DebugLog.error('exportAppData', 'source_config_merge.json 导出失败：$e');
  }
  try {
    final favorites = LocalFavoritesManager().getAllFavoriteMergeMaps();
    final jsonStr = await Isolate.run(() {
      return jsonEncode(favorites);
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
    final aiTasksDb = FilePath.join(dataPath, "ai_tasks.db");
    if (File(aiTasksDb).existsSync()) {
      zipFile.addFile("ai_tasks.db", aiTasksDb);
    }
    final hmf = File(historyMergeFile);
    if (hmf.existsSync()) {
      zipFile.addFile("history_merge.json", historyMergeFile);
    }
    final phmf = File(pluginHistoryMergeFile);
    if (phmf.existsSync()) {
      zipFile.addFile("plugin_history_merge.json", pluginHistoryMergeFile);
    }
    final trmf = File(textRulesMergeFile);
    if (trmf.existsSync()) {
      zipFile.addFile("text_rules_merge.json", textRulesMergeFile);
    }
    final pmf = File(progressMergeFile);
    if (pmf.existsSync()) {
      zipFile.addFile("progress_merge.json", progressMergeFile);
    }
    final amf = File(assistantMergeFile);
    if (amf.existsSync()) {
      zipFile.addFile("assistant_merge.json", assistantMergeFile);
    }
    final scmf = File(sourceConfigMergeFile);
    if (scmf.existsSync()) {
      zipFile.addFile("source_config_merge.json", sourceConfigMergeFile);
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
    final pluginsDir = FilePath.join(dataPath, mePluginsDirName);
    if (Directory(pluginsDir).existsSync()) {
      for (var file in Directory(pluginsDir).listSync()) {
        if (file is File) {
          zipFile.addFile("$mePluginsDirName/${file.name}", file.path);
        }
      }
    }
    // 角色卡 / 故事观 / 存档 / 提示词注入 / 世界书 / 设定库 / 故事角色卡
    for (final dirName in const [
      'character_cards',
      'stories',
      'story_sessions',
      'prompt_injections',
      'world_info',
      'group_chats',
      'setting_library',
      'story_characters',
      'ai_skills',
    ]) {
      final dir = FilePath.join(dataPath, dirName);
      if (Directory(dir).existsSync()) {
        for (var file in Directory(dir).listSync()) {
          if (file is File) {
            zipFile.addFile('$dirName/${file.name}', file.path);
          }
        }
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

// ─────────────────────────────────────────────
// 分部分同步：每个部分一个独立 zip，远端独立文件夹
// ─────────────────────────────────────────────

class SyncPart {
  final String key;
  final String dir;
  final String name;

  /// 是否参与整包自动同步；false 时只在选择性同步里手动上传/下载
  final bool autoSync;
  const SyncPart(this.key, this.dir, this.name, {this.autoSync = true});
}

const syncParts = <SyncPart>[
  SyncPart('ai', 'db/ai_database', 'ai_database'),
  SyncPart('ai_tasks', 'db/ai_tasks', 'ai_tasks', autoSync: false),
  SyncPart('history', 'db/history', 'history'),
  SyncPart('favorites', 'db/favorites', 'favorites'),
  SyncPart('stats', 'db/stats', 'stats'),
  SyncPart('bangumi', 'db/bangumi', 'bangumi'),
  SyncPart('search', 'db/search_history', 'search_history'),
  SyncPart('cookies', 'db/cookies', 'cookies'),
  SyncPart('data', 'data', 'data'),
];

/// 生成某部分需要的字段级合并文件
Future<void> _writeMergeFilesFor(String key) async {
  Future<void> write(String path, Object data) async {
    try {
      await File(path).writeAsString(await Isolate.run(() => jsonEncode(data)));
    } catch (e) {
      DebugLog.error('exportPart', '$path 导出失败：$e');
    }
  }

  if (key == 'ai') {
    // 只合并用户数据（Key / 自定义服务商 / 会话元数据 / MCP / 辅助设置），
    // 模型目录与服务商统计属于各端缓存，不参与同步
    final ai = AiDatabase.instance;
    await ai.checkpoint();
    await write(
      FilePath.join(App.cachePath, 'ai_merge.json'),
      await ai.exportMergeData(),
    );
  } else if (key == 'ai_tasks') {
    final tasks = AiTaskDatabase.instance;
    await tasks.checkpoint();
    await write(
      FilePath.join(App.cachePath, 'ai_task_merge.json'),
      (await tasks.exportMergeData()).map((e) => e.toJson()).toList(),
    );
  } else if (key == 'history') {
    // 先 checkpoint：旧版导入依赖整库副本时也能拿到最新数据
    await HistoryManager().checkpoint();
    await write(
      FilePath.join(App.cachePath, 'history_merge.json'),
      (await HistoryManager().getAll()).map((h) => h.toJson()).toList(),
    );
    await write(
      FilePath.join(App.cachePath, 'plugin_history_merge.json'),
      (await HistoryManager().getAllPluginEvents()).map((e) => e.toJson()).toList(),
    );
    await write(
      FilePath.join(App.cachePath, 'text_rules_merge.json'),
      await HistoryManager().getTextRules(),
    );
    // 观看进度（progress 表）：整库覆盖时不会生效（合并优先），单独导出合并
    await write(
      FilePath.join(App.cachePath, 'progress_merge.json'),
      (await HistoryManager().getAllProgress()).map((p) => p.toJson()).toList(),
    );
  } else if (key == 'favorites') {
    await write(
      FilePath.join(App.cachePath, 'favorites_merge.json'),
      LocalFavoritesManager().getAllFavoriteMergeMaps(),
    );
  } else if (key == 'stats') {
    await StatsManager().checkpoint();
    await write(
      FilePath.join(App.cachePath, 'stats_merge.json'),
      // 用未过滤的全量记录导出：已卸载源的统计也要能同步过去
      (await StatsManager().getStatsAllRaw())
          .map((s) => s.toMergeJson())
          .toList(),
    );
  } else if (key == 'bangumi') {
    // 绑定条目是用户手动建立的，整库覆盖会丢；bangumi 资料/日历/分集信息
    // 都是服务端缓存，各端自己维护即可
    final manager = providerContainer.read(bangumiManagerProvider);
    await manager.checkpoint();
    await write(
      FilePath.join(App.cachePath, 'bangumi_merge.json'),
      (await manager.getAllBindings()).map((e) => e.toJson()).toList(),
    );
  } else if (key == 'search') {
    final rows = await SearchHistoryManager().all();
    // 先 checkpoint，保证旧版依赖的 search_history.db 里也是最新数据
    await SearchHistoryManager().checkpoint();
    await write(
      FilePath.join(App.cachePath, 'search_merge.json'),
      rows.map((e) => e.toJson()).toList(),
    );
  } else if (key == 'cookies') {
    final jar = SingleInstanceCookieJar.instance;
    if (jar != null) {
      await jar.checkpoint();
      await write(
        FilePath.join(App.cachePath, 'cookie_merge.json'),
        (await jar.allRows()).map((e) => e.toJson()).toList(),
      );
    }
  } else if (key == 'data') {
    // 助手档案与长期记忆存在 shared_preferences 里，不在任何目录/DB 中，
    // 单独导出成合并文件
    await write(FilePath.join(App.cachePath, 'assistant_merge.json'), {
      'profiles': AssistantProfileStore.instance.exportMergeData(),
      'memory': AssistantMemoryStore.instance.exportMergeData(),
    });
    // 番源启用/禁用：存在 implicitData（默认不同步），单独导出合并文件
    await write(
      FilePath.join(App.cachePath, 'source_config_merge.json'),
      AnimeSourceManager().exportSourceConfig(),
    );
  }
}

/// 某部分包含的本地文件（archive 内名 → 本地路径）
List<(String, String)> _partEntries(String key) {
  final dp = App.dataPath;
  final out = <(String, String)>[];
  void add(String name, String path) {
    if (File(path).existsSync()) out.add((name, path));
  }

  void addDir(String archiveDir, String localDir) {
    final d = Directory(localDir);
    if (!d.existsSync()) return;
    for (final f in d.listSync()) {
      if (f is File) {
        out.add(('$archiveDir/${f.uri.pathSegments.last}', f.path));
      }
    }
  }

  if (key == 'ai') {
    add('ai_database.db', FilePath.join(dp, 'ai_database.db'));
    add('ai_merge.json', FilePath.join(App.cachePath, 'ai_merge.json'));
  } else if (key == 'ai_tasks') {
    add('ai_tasks.db', FilePath.join(dp, 'ai_tasks.db'));
    add(
      'ai_task_merge.json',
      FilePath.join(App.cachePath, 'ai_task_merge.json'),
    );
  } else if (key == 'history') {
    add('history.db', FilePath.join(dp, 'history.db'));
    add(
      'history_merge.json',
      FilePath.join(App.cachePath, 'history_merge.json'),
    );
    add(
      'plugin_history_merge.json',
      FilePath.join(App.cachePath, 'plugin_history_merge.json'),
    );
    add(
      'text_rules_merge.json',
      FilePath.join(App.cachePath, 'text_rules_merge.json'),
    );
    add(
      'progress_merge.json',
      FilePath.join(App.cachePath, 'progress_merge.json'),
    );
  } else if (key == 'favorites') {
    add('local_favorite.db', FilePath.join(dp, 'local_favorite.db'));
    add(
      'favorites_merge.json',
      FilePath.join(App.cachePath, 'favorites_merge.json'),
    );
  } else if (key == 'stats') {
    add('stats.db', FilePath.join(dp, 'stats.db'));
    add('stats_merge.json', FilePath.join(App.cachePath, 'stats_merge.json'));
  } else if (key == 'bangumi') {
    add('bangumi.db', FilePath.join(dp, 'bangumi.db'));
    add('bangumi_merge.json', FilePath.join(App.cachePath, 'bangumi_merge.json'));
  } else if (key == 'search') {
    add('search_history.db', FilePath.join(dp, 'search_history.db'));
    add(
      'search_merge.json',
      FilePath.join(App.cachePath, 'search_merge.json'),
    );
  } else if (key == 'cookies') {
    add('cookie.db', FilePath.join(dp, 'cookie.db'));
    add('cookie_merge.json', FilePath.join(App.cachePath, 'cookie_merge.json'));
  } else if (key == 'data') {
    // 故事 / 角色卡 / 存档 / 世界书 / 设定库 / 技能等走「选择性同步」，
    // 不放进整包，避免重复与体积膨胀。注意：番源/插件的本地配置（勾选的
    // 文本规则、下载标题格式）都存在它们自己的 `<key>.data` 里，随本部分的
    // anime_source / plugins 目录一起同步，implicitData 仍不参与同步。
    add('appdata.json', FilePath.join(dp, 'appdata.json'));
    add(
      'assistant_merge.json',
      FilePath.join(App.cachePath, 'assistant_merge.json'),
    );
    add(
      'source_config_merge.json',
      FilePath.join(App.cachePath, 'source_config_merge.json'),
    );
    addDir('anime_source', FilePath.join(dp, 'anime_source'));
    addDir(mePluginsDirName, FilePath.join(dp, mePluginsDirName));
  }
  return out;
}

/// 生成某部分需要的合并文件（上传/计算哈希前调用一次）
Future<void> prepareSyncPart(String key) => _writeMergeFilesFor(key);

/// 导出单个部分为独立 zip（调用前先 [prepareSyncPart]）
Future<File> exportPart(String key) async {
  final entries = _partEntries(key);
  final dir = Directory(FilePath.join(App.cachePath, 'sync_part'));
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  final zipPath = FilePath.join(dir.path, '$key.kostori');
  HistoryWriteService.pause();
  try {
    await Isolate.run(() {
      final zip = ZipFile.open(zipPath);
      for (final e in entries) {
        zip.addFile(e.$1, e.$2);
      }
      zip.close();
    });
  } finally {
    HistoryWriteService.resume();
  }
  return File(zipPath);
}

/// 某部分内容的哈希（内容不变则无需重新上传）
Future<String> partContentHash(String key) async {
  final entries = _partEntries(key);
  return Isolate.run(() {
    var hash = 0xcbf29ce484222325;
    void mix(List<int> bytes) {
      for (final b in bytes) {
        hash ^= b;
        hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
      }
    }

    for (final e in entries) {
      mix(utf8.encode(e.$1));
      final bytes = File(e.$2).readAsBytesSync();
      mix([
        bytes.length & 0xff,
        (bytes.length >> 8) & 0xff,
        (bytes.length >> 16) & 0xff,
        (bytes.length >> 24) & 0xff,
      ]);
      mix(bytes);
    }
    return hash.toRadixString(16);
  });
}

Future<void> importAppData(File file) async {
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
    await _applyImportedData(cacheDirPath);
  } catch (e) {
    DebugLog.error('importAppData', '$e');
  } finally {
    cacheDir.deleteIgnoreError(recursive: true);
  }
}

/// 从已解压目录应用导入（缺失的部分自动跳过）——整包与分部分导入共用
Future<void> _applyImportedData(String cacheDirPath) async {
  final cacheDir = Directory(cacheDirPath);
  var historyFile = cacheDir.joinFile("history.db");
    var localFavoriteFile = cacheDir.joinFile("local_favorite.db");
    var bangumiFile = cacheDir.joinFile("bangumi.db");
    var statsFile = cacheDir.joinFile("stats.db");
    var searchHistoryFile = cacheDir.joinFile("search_history.db");
    var appdataFile = cacheDir.joinFile("appdata.json");
    var cookieFile = cacheDir.joinFile("cookie.db");
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
    // 插件事件（浏览/搜索）字段级合并：插件事件独立于主历史表
    final pluginMergeFile = cacheDir.joinFile("plugin_history_merge.json");
    if (await pluginMergeFile.exists()) {
      try {
        final list = jsonDecode(await pluginMergeFile.readAsString());
        if (list is List) {
          final events = list
              .whereType<Map>()
              .map((m) =>
                  PluginEventItem.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          HistoryWriteService.pause();
          await HistoryManager().mergePluginEvents(events);
          HistoryWriteService.resume();
        }
      } catch (e) {
        DebugLog.error('importAppData', 'plugin_history 字段级合并失败：$e');
      }
    }
    // 文本规则字段级合并（history.db 的 text_rules 表）
    final textRulesMergeFile = cacheDir.joinFile("text_rules_merge.json");
    if (await textRulesMergeFile.exists()) {
      try {
        final list = jsonDecode(await textRulesMergeFile.readAsString());
        if (list is List) {
          HistoryWriteService.pause();
          await HistoryManager().mergeTextRules(
            list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList(),
          );
          HistoryWriteService.resume();
          await TextRuleStore.reload();
        }
      } catch (e) {
        DebugLog.error('importAppData', 'text_rules 字段级合并失败：$e');
      }
    }
    // 观看进度字段级合并（history.db 的 progress 表）：放在历史合并之后，
    // 保证远端新增的历史条目先就位
    final progressMergeFile = cacheDir.joinFile("progress_merge.json");
    if (await progressMergeFile.exists()) {
      try {
        final list = jsonDecode(await progressMergeFile.readAsString());
        if (list is List) {
          HistoryWriteService.pause();
          await HistoryManager().mergeProgressList(
            list
                .whereType<Map>()
                .map((m) => Progress.fromJson(Map<String, dynamic>.from(m)))
                .toList(),
          );
          HistoryWriteService.resume();
        }
      } catch (e) {
        DebugLog.error('importAppData', 'progress 字段级合并失败：$e');
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
          final items = list.whereType<Map>().toList();
          LocalFavoritesManager().mergeFavoriteMaps(items);
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
    // 绑定字段级合并优先：只补齐本机缺少的绑定，资料/日历缓存保留本机
    final bangumiMergeFile = cacheDir.joinFile("bangumi_merge.json");
    var mergedBangumi = false;
    if (await bangumiMergeFile.exists()) {
      try {
        final list = jsonDecode(await bangumiMergeFile.readAsString());
        if (list is List) {
          final manager = providerContainer.read(bangumiManagerProvider);
          await manager.init();
          await manager.mergeBindings(
            list
                .whereType<Map>()
                .map(
                  (m) => BangumiBindingTableData.fromJson(
                    Map<String, dynamic>.from(m),
                  ),
                )
                .toList(),
          );
          mergedBangumi = true;
        }
      } catch (e) {
        DebugLog.error('importAppData', 'bangumi 字段级合并失败：$e');
      }
    }
    if (!mergedBangumi && await bangumiFile.exists()) {
      DebugLog.info('importAppData', '开始导入bangumiFile（整库覆盖）');
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
    // 搜索历史字段级合并优先：按关键词取较大的使用次数与较新的时间，
    // 两边各自的搜索记录都不会丢（search_history.db 是 WAL 库，整库拷贝
    // 可能拿到还没 checkpoint 的旧数据，所以不再依赖整库覆盖）
    final searchMergeFile = cacheDir.joinFile("search_merge.json");
    var mergedSearch = false;
    if (await searchMergeFile.exists()) {
      try {
        final list = jsonDecode(await searchMergeFile.readAsString());
        if (list is List) {
          await SearchHistoryManager().mergeSearchHistory(
            list
                .whereType<Map>()
                .map((m) => SearchHistoryItem.fromJson(Map<String, dynamic>.from(m)))
                .toList(),
          );
          mergedSearch = true;
        }
      } catch (e) {
        DebugLog.error('importAppData', 'search 字段级合并失败：$e');
      }
    }
    if (!mergedSearch && await searchHistoryFile.exists()) {
      // 旧版导出（无 search_merge.json）→ 整库覆盖（原子替换 + 备份）
      DebugLog.info('importAppData', '开始导入searchHistoryFile（整库覆盖）');
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
    // 助手档案 / 长期记忆：按 id 增量合并（本机已有的保留本机版本）
    final assistantMergeFile = cacheDir.joinFile("assistant_merge.json");
    if (await assistantMergeFile.exists()) {
      try {
        final data = jsonDecode(await assistantMergeFile.readAsString());
        if (data is Map) {
          await AssistantProfileStore.instance.mergeData(
            (data['profiles'] as List?)
                    ?.whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList() ??
                const [],
          );
          final memory = data['memory'];
          if (memory is Map) {
            await AssistantMemoryStore.instance.mergeData(
              Map<String, dynamic>.from(memory),
            );
          }
        }
      } catch (e) {
        DebugLog.error('importAppData', 'assistant 字段级合并失败：$e');
      }
    }
    // 番源启用/禁用：新者胜（旧包无此文件时跳过，本地不动）
    final sourceConfigMergeFile = cacheDir.joinFile("source_config_merge.json");
    if (await sourceConfigMergeFile.exists()) {
      try {
        final data = jsonDecode(await sourceConfigMergeFile.readAsString());
        if (data is Map) {
          if (AnimeSourceManager().importSourceConfig(
            Map<String, dynamic>.from(data),
          )) {
            DebugLog.info('importAppData', '已同步番源启用状态');
          }
        }
      } catch (e) {
        DebugLog.error('importAppData', 'source_config 字段级合并失败：$e');
      }
    }
    // Cookie 字段级合并优先：补齐本机没有的、以及过期时间更晚的 Cookie，
    // 避免用另一端的登录态整库覆盖本机
    final cookieMergeFile = cacheDir.joinFile("cookie_merge.json");
    var mergedCookies = false;
    if (await cookieMergeFile.exists()) {
      try {
        final list = jsonDecode(await cookieMergeFile.readAsString());
        if (list is List) {
          final jar =
              SingleInstanceCookieJar.instance ??
              await SingleInstanceCookieJar.createInstance();
          await jar.mergeCookies(
            list
                .whereType<Map>()
                .map((m) => CookiesTableData.fromJson(Map<String, dynamic>.from(m)))
                .toList(),
          );
          mergedCookies = true;
        }
      } catch (e) {
        DebugLog.error('importAppData', 'cookie 字段级合并失败：$e');
      }
    }
    if (!mergedCookies && await cookieFile.exists()) {
      DebugLog.info('importAppData', '开始导入cookieFile（整库覆盖）');
      // 关连接 → 替换文件 → 同一实例重新打开：
      // 不新建实例，避免共用同一 db 文件时出现 drift 多实例告警/竞态
      final jar = SingleInstanceCookieJar.instance;
      await jar?.close();
      _atomicReplace(cookieFile.path, FilePath.join(App.dataPath, "cookie.db"));
      if (jar != null) {
        await jar.reopen();
      } else {
        await SingleInstanceCookieJar.createInstance();
      }
    }
    // AI 配置字段级合并优先：只合并用户数据，模型目录等缓存保留本机
    var aiFile = cacheDir.joinFile("ai_database.db");
    final aiMergeFile = cacheDir.joinFile("ai_merge.json");
    var mergedAi = false;
    if (await aiMergeFile.exists()) {
      try {
        final data = jsonDecode(await aiMergeFile.readAsString());
        if (data is Map) {
          await AiDatabase.instance.mergeData(Map<String, dynamic>.from(data));
          mergedAi = true;
        }
      } catch (e) {
        DebugLog.error('importAppData', 'ai 字段级合并失败：$e');
      }
    }
    if (!mergedAi && await aiFile.exists()) {
      DebugLog.info('importAppData', '开始导入aiFile（整库覆盖）');
      await AiDatabase.instance.close();
      _atomicReplace(
        aiFile.path,
        FilePath.join(App.dataPath, "ai_database.db"),
      );
      AiDatabase.init();
    }
    // AI 消息字段级合并优先：按内容判重后增量插入，不覆盖本机聊天记录
    var aiTasksFile = cacheDir.joinFile("ai_tasks.db");
    final aiTaskMergeFile = cacheDir.joinFile("ai_task_merge.json");
    var mergedAiTasks = false;
    if (await aiTaskMergeFile.exists()) {
      try {
        final list = jsonDecode(await aiTaskMergeFile.readAsString());
        if (list is List) {
          await AiTaskDatabase.instance.mergeData(
            list
                .whereType<Map>()
                .map((m) => AiTask.fromJson(Map<String, dynamic>.from(m)))
                .toList(),
          );
          mergedAiTasks = true;
        }
      } catch (e) {
        DebugLog.error('importAppData', 'ai_tasks 字段级合并失败：$e');
      }
    }
    if (!mergedAiTasks && await aiTasksFile.exists()) {
      DebugLog.info('importAppData', '开始导入aiTasksFile（整库覆盖）');
      await AiTaskDatabase.instance.close();
      _atomicReplace(
        aiTasksFile.path,
        FilePath.join(App.dataPath, "ai_tasks.db"),
      );
      AiTaskDatabase.init();
    }
    var animeSourceDir = FilePath.join(cacheDirPath, "anime_source");
    if (Directory(animeSourceDir).existsSync()) {
      DebugLog.info('importAppData', '开始导入animeSource');
      // 按文件覆盖，不删除本机独有的源/数据：另一端没有的源往往只是
      // 该端没装，直接整目录删除会把本机的源连同登录数据一起清掉
      Directory(FilePath.join(App.dataPath, "anime_source")).createSync(
        recursive: true,
      );
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
    var pluginsDir = FilePath.join(cacheDirPath, mePluginsDirName);
    if (Directory(pluginsDir).existsSync()) {
      DebugLog.info('importAppData', '开始导入mePlugins');
      // 同 animeSource：只覆盖同名文件，保留本机独有的插件与登录数据
      Directory(FilePath.join(App.dataPath, mePluginsDirName)).createSync(
        recursive: true,
      );
      for (var file in Directory(pluginsDir).listSync()) {
        if (file is File) {
          var targetFile = FilePath.join(
            App.dataPath,
            mePluginsDirName,
            file.name,
          );
          await file.copy(targetFile);
        }
      }
      await MePagePluginManager().reload();
    }
    // 角色卡 / 故事观 / 存档 / 提示词注入 / 世界书 / 设定库 / 故事角色卡
    for (final dirName in const [
      'character_cards',
      'stories',
      'story_sessions',
      'prompt_injections',
      'world_info',
      'group_chats',
      'setting_library',
      'story_characters',
      'ai_skills',
    ]) {
      final src = FilePath.join(cacheDirPath, dirName);
      if (!Directory(src).existsSync()) continue;
      final dest = FilePath.join(App.dataPath, dirName);
      Directory(dest).createSync(recursive: true);
      for (var file in Directory(src).listSync()) {
        if (file is File) {
          await file.copy(FilePath.join(dest, file.name));
        }
      }
    }
    // 旧备份中的 world_book 目录名兼容：并入 world_info
    final legacyWorldDir = FilePath.join(cacheDirPath, 'world_book');
    if (Directory(legacyWorldDir).existsSync()) {
      final dest = FilePath.join(App.dataPath, 'world_info');
      Directory(dest).createSync(recursive: true);
      for (var file in Directory(legacyWorldDir).listSync()) {
        if (file is File) {
          await file.copy(FilePath.join(dest, file.name));
        }
      }
    }
    // 上面这些目录都可能是从这里导入的，全部重新加载，避免界面/逻辑仍用旧缓存
    await CharacterCardStore.instance.reload();
    await StoryStore.instance.reload();
    await StorySessionStore.instance.reload();
    await PromptInjectionStore.instance.reload();
    await WorldBookStore.instance.reload();
    await GroupChatStore.instance.reload();
    await SettingLibraryStore.instance.reload();
    await StoryCharacterStore.instance.reload();
    await AiSkillStore.instance.reload();
}

/// 导入单个部分（分部分同步）
Future<void> importPart(File file) async {
  final cacheDirPath = FilePath.join(App.cachePath, 'temp_part');
  final cacheDir = Directory(cacheDirPath);
  if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  cacheDir.createSync(recursive: true);
  try {
    await Isolate.run(() => ZipFile.openAndExtract(file.path, cacheDirPath));
    await _applyImportedData(cacheDirPath);
  } catch (e) {
    DebugLog.error('importPart', '$e');
  } finally {
    cacheDir.deleteIgnoreError(recursive: true);
  }
}
