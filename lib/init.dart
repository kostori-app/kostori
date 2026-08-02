import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_saf/flutter_saf.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/foundation/ai_service/assistant_profile.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/ai_service/plugin_module.dart';
import 'package:kostori/foundation/ai_service/role_management.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/audio_service/audio_service_manager.dart';
import 'package:kostori/foundation/audio_service/smtc_manager_windows.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/i18n_utils.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/skills/builtins/anime_info_skill.dart';
import 'package:kostori/skills/builtins/bangumi_skill.dart';
import 'package:kostori/skills/builtins/device_info_skill.dart';
import 'package:kostori/skills/builtins/log_skill.dart';
import 'package:kostori/skills/builtins/open_url_skill.dart';
import 'package:kostori/skills/builtins/time_skill.dart';
import 'package:kostori/skills/skill_registry.dart';
import 'package:kostori/utils/app_links.dart';
import 'package:kostori/utils/translations.dart';
import 'package:rhttp/rhttp.dart';

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
  await SingleInstanceCookieJar.createInstance();
  var futures = [
    Rhttp.init(),
    App.initComponents(),
    SAFTaskWorker().init().wait(),
    AppTranslation.init().wait(),
    I18nUtils.init().wait(),
    JsEngine().init().wait(),
    AnimeSourceManager().init().wait(),
  ];
  await Future.wait(futures);
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
    SearchBangumiPersonSkill(),
    QueryLogsSkill(),
  ]);
  await SkillRegistry.instance.syncMcp().wait();
  await AssistantProfileStore.instance.init().wait();
  await PromptInjectionStore.instance.init().wait();
  await WorldBookStore.instance.init().wait();
  await PluginStore.instance.init().wait();
  await OpenAiProviderRegistry.refreshKeyFormats().wait();
  ApiKeyManager().init();
  CacheManager().setLimitSize(appdata.settings['cacheSize']);
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
