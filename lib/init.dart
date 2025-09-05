import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_saf/flutter_saf.dart';
import 'package:kostori/foundation/audio_service/smtc_manager_windows.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/settings/anime_source_settings.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/app_links.dart';
import 'package:kostori/utils/translations.dart';
import 'package:rhttp/rhttp.dart';

import 'foundation/anime_source/anime_source.dart';
import 'foundation/app.dart';
import 'foundation/appdata.dart';
import 'foundation/audio_service/audio_service_manager.dart';
import 'foundation/cache_manager.dart';
import 'foundation/js_engine.dart';
import 'foundation/log.dart';
import 'network/cookie_jar.dart';

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
    JsEngine().init().wait(),
    AnimeSourceManager().init().wait(),
  ];
  await Future.wait(futures);
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
  await Bangumi.getCalendarData();
  await Bangumi.checkBangumiData();
  await checkUpdateUi(true, true);
}

void checkUpdates() {
  _checkAppUpdates().wait();
}
