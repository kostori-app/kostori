import 'package:flutter/cupertino.dart';
import 'package:flutter_saf/flutter_saf.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi.dart';
import 'package:kostori/utils/app_links.dart';
import 'package:kostori/utils/tag_translation.dart';
import 'package:kostori/utils/translations.dart';
import 'package:rhttp/rhttp.dart';
import 'foundation/anime_source/anime_source.dart';
import 'foundation/app.dart';
import 'foundation/appdata.dart';
import 'foundation/cache_manager.dart';
import 'foundation/favorites.dart';
import 'foundation/history.dart';
import 'foundation/js_engine.dart';
import 'foundation/local.dart';
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
  await Rhttp.init();
  await SAFTaskWorker().init().wait();
  await AppTranslation.init().wait();
  await appdata.init().wait();
  await App.init().wait();
  await HistoryManager().init().wait();
  await BangumiManager().init().wait();
  await TagsTranslation.readData().wait();
  await LocalFavoritesManager().init().wait();
  SingleInstanceCookieJar("${App.dataPath}/cookie.db");
  await JsEngine().init().wait();
  await AnimeSource.init().wait();
  await LocalManager().init().wait();
  CacheManager().setLimitSize(appdata.settings['cacheSize']);
  if (App.isAndroid) {
    handleLinks();
  }
  FlutterError.onError = (details) {
    Log.error("Unhandled Exception", "${details.exception}\n${details.stack}");
  };
}
