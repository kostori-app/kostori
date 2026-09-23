import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';

extension AppTranslation on String {
  /// Translate a string using specified anime source
  String ts(String sourceKey) {
    var animeSource = AnimeSource.find(sourceKey);
    if (animeSource == null || animeSource.translations == null) {
      return this;
    }
    var locale = App.locale;
    var lc = locale.languageCode;
    var cc = locale.countryCode;
    var key = "$lc${cc == null ? "" : "_$cc"}";
    return (animeSource.translations![key] ??
            animeSource.translations![lc])?[this] ??
        this;
  }
}
