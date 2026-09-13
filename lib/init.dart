import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_saf/flutter_saf.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/ai_task_database.dart';
import 'package:kostori/foundation/ai_service/assistant_profile.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/ai_service/plugin_module.dart';
import 'package:kostori/foundation/ai_service/ai_skill_store.dart';
import 'package:kostori/foundation/ai_service/role_management.dart';
import 'package:kostori/foundation/ai_service/setting_library.dart';
import 'package:kostori/foundation/ai_service/story.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/audio_service/audio_service_manager.dart';
import 'package:kostori/foundation/audio_service/smtc_manager_windows.dart';
import 'package:kostori/services/download/download_manager.dart';import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/text_rule.dart';
import 'package:kostori/foundation/me_plugin/me_plugin.dart';
import 'package:kostori/i18n/i18n_utils.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/skills/builtins/anime_info_skill.dart';
import 'package:kostori/skills/builtins/bangumi_skill.dart';
import 'package:kostori/skills/builtins/device_info_skill.dart';
import 'package:kostori/skills/builtins/log_skill.dart';
import 'package:kostori/skills/builtins/open_url_skill.dart';
import 'package:kostori/skills/builtins/recognize_anime_skill.dart';
import 'package:kostori/skills/builtins/time_skill.dart';
import 'package:kostori/skills/skill_registry.dart';
import 'package:kostori/utils/app_links.dart';
import 'package:kostori/utils/data.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/translations.dart';
import 'package:rhttp/rhttp.dart';
import 'package:shared_preferences/shared_preferences.dart';

final providerContainer = ProviderContainer();

extension _FutureInit<T> on Future<T> {
  /// Prevent unhandled exception
  ///
  /// A unhandled exception occurred in init() will cause the app to crash.
  Future<void> wait() async {
    try {
      await this;
    } catch (e, s) {
      Log.error("init", "$e\n$s");
    }
  }
}

Future<void> init() async {
  await App.init().wait();
  // 崩溃兜底：恢复上次同步中断遗留的 .bak 数据库（需在任何数据库打开之前）
  recoverStaleBackups();
  await SingleInstanceCookieJar.createInstance();
  var futures = [
    Rhttp.init(),
    App.initComponents(),
    SAFTaskWorker().init().wait(),
    AppTranslation.init().wait(),
    I18nUtils.init().wait(),
    JsEngine().init().wait(),
    AnimeSourceManager().init().wait(),
    MePagePluginManager().init().wait(),
  ];
  await Future.wait(futures);
  // 加载持久化的文本规则（history.db 的 text_rules 表）
  await TextRuleStore.load();
  SkillRegistry.instance.registerAll([
    OpenUrlSkill(),
    DeviceInfoSkill(),
    GetTimeSkill(),
    QueryWatchHistorySkill(),
    SearchAnimeSkill(),
    QueryFavoritesSkill(),
    QueryWatchStatsSkill(),
    SearchBangumiSkill(),
    QueryBangumiCharactersSkill(),
    SearchBangumiCharacterSkill(),
    SearchBangumiPersonSkill(),
    AnalyzeBangumiSkill(),
    QueryLogsSkill(),
    RecognizeAnimeSkill(),
  ]);
  await SkillRegistry.instance.syncMcp().wait();
  await AiSkillStore.instance.init().wait();
  await AiSkillStore.instance.migrateFromDb().wait();
  await AssistantProfileStore.instance.init().wait();
  await PromptInjectionStore.instance.init().wait();
  await WorldBookStore.instance.init().wait();
  await SettingLibraryStore.instance.init().wait();
  await PluginStore.instance.init().wait();
  // 角色卡 / 故事观 / 会话：文件化存储（同时完成旧 prefs 数据的迁移清理）
  await CharacterCardStore.instance.init().wait();
  await StoryStore.instance.init().wait();
  await StorySessionStore.instance.ensureLoaded().wait();
  await StoryCharacterStore.instance.ensureLoaded().wait();
  // 把旧版故事文件里内联的角色卡迁移到独立文件
  await StoryCharacterStore.instance.migrateFromStories().wait();
  await _cleanupStalePrefs();
  unawaited(_logPrefsSizes());
  await OpenAiProviderRegistry.refreshKeyFormats().wait();
  ApiKeyManager().init();
  CacheManager().setLimitSize(appdata.settings['cacheSize']);
  // 后台预热 AI 数据库：首次进入 AI 聊天页才建库（drift isolate 启动/建表）
  // 会卡住首帧，启动时异步触发一次查询提前完成
  unawaited(() async {
    try {
      await AiDatabase.instance.aiSessionDao.watchAllSessions().first;
      // 打开独立的消息库，并把旧的 ai_tasks 表迁移过来
      await AiTaskDatabase.instance.aiTaskDao.watchAll().first;
      await migrateAiTasksToOwnDb();
      // 已迁移过的旧库也压缩一次（迁移会提前返回，不会走到 VACUUM）
      await compactAiDatabaseIfNeeded();
    } catch (_) {}
  }());
  // 加载持久化的下载任务
  await DownloadManager.instance.init();
  // 启动即初始化数据同步（启用时自动首次下载，并监听数据变化自动上传）
  DataSync();
  _checkOldConfigs();
  if (App.isAndroid) {
    handleLinks();
    await AudioServiceManager().initializeHandler();
  }
  FlutterError.onError = (details) {
    Log.error("Unhandled Exception", "${details.exception}\n${details.stack}");
  };
  if (App.isWindows) {
    // Report to the monitor thread that the app is running
    // https://github.com/venera-app/venera/issues/343
    Timer.periodic(const Duration(seconds: 1), (_) {
      const methodChannel = MethodChannel('kostori/method_channel');
      methodChannel.invokeMethod("heartBeat");
    });
    await SMTCManagerWindows.instance.init();
  }
  providerContainer.read(bangumiManagerProvider);
}

/// 清理历史遗留、当前代码已不再使用的 shared_preferences 键
Future<void> _cleanupStalePrefs() async {
  const stale = {
    'ai_role_play',
    'implicitData',
    'search',
    'firstUse',
    'blockingKeyword',
    'favoriteTags',
  };
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final key in stale) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
        DebugLog.info('Prefs', 'removed stale key: $key');
      }
    }
  } catch (_) {}
}

/// 记录 shared_preferences 中体积最大的键（诊断用，迁移后确认是否瘦身）
Future<void> _logPrefsSizes() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final entries = <(String, int)>[];
    for (final k in prefs.getKeys()) {
      final v = prefs.get(k);
      entries.add((k, v is String ? v.length : v.toString().length));
    }
    entries.sort((a, b) => b.$2.compareTo(a.$2));
    final top = entries
        .take(10)
        .map((e) => '${e.$1}=${(e.$2 / 1024).toStringAsFixed(0)}KB')
        .join(', ');
    DebugLog.info('Prefs', 'largest keys: $top');
  } catch (_) {}
}

void _checkOldConfigs() {
  if (appdata.settings['searchSources'] == null) {
    appdata.settings['searchSources'] = AnimeSource.all()
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
  }

  if (appdata.implicitData['webdavAutoSync'] == null) {
    var webdavConfig = appdata.settings['webdav'];
    if (webdavConfig is List &&
        webdavConfig.length == 3 &&
        webdavConfig.whereType<String>().length == 3) {
      appdata.implicitData['webdavAutoSync'] = true;
    } else {
      appdata.implicitData['webdavAutoSync'] = false;
    }
    appdata.writeImplicitData();
  }
}

Future<void> _checkAppUpdates() async {
  AnimeSourceSettings.checkAnimeSourceUpdate();
  await Bangumi.instance.getCalendarData();
  await Bangumi.instance.checkBangumiData();
  if (appdata.settings['checkUpdateOnStart']) {
    await checkUpdateUi(false, true);
  }
}

void checkUpdates() {
  _checkAppUpdates().wait();
}
