library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/pages/search_result_page.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/init.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';

import '../../pages/category_animes_page.dart';

part 'category.dart';

part 'favorites.dart';

part 'models.dart';

part 'parser.dart';

class AnimeSourceManager with ChangeNotifier, Init {
  final List<AnimeSource> _sources = [];

  static AnimeSourceManager? _instance;

  AnimeSourceManager._create();

  factory AnimeSourceManager() => _instance ??= AnimeSourceManager._create();

  List<AnimeSource> all() => List.from(_sources);

  AnimeSource? find(String key) =>
      _sources.firstWhereOrNull((element) => element.key == key);

  AnimeSource? fromIntKey(int key) =>
      _sources.firstWhereOrNull((element) => element.key.hashCode == key);

  @override
  @protected
  Future<void> doInit() async {
    await JsEngine().ensureInit();
    final path = "${App.dataPath}/anime_source";
    if (!(await Directory(path).exists())) {
      Directory(path).create();
      return;
    }
    await for (var entity in Directory(path).list()) {
      if (entity is File && entity.path.endsWith(".js")) {
        try {
          var source = await AnimeSourceParser().parse(
            await entity.readAsString(),
            entity.absolute.path,
          );
          _sources.add(source);
        } catch (e, s) {
          Log.error("AnimeSource", "$e\n$s");
        }
      }
    }
  }

  Future reload() async {
    _sources.clear();
    JsEngine().runCode("AnimeSource.sources = {};");
    await doInit();
    notifyListeners();
  }

  void add(AnimeSource source) {
    _sources.add(source);
    notifyListeners();
  }

  void remove(String key) {
    _sources.removeWhere((element) => element.key == key);
    notifyListeners();
  }

  bool get isEmpty => _sources.isEmpty;

  /// Key is the source key, value is the version.
  final _availableUpdates = <String, String>{};

  void updateAvailableUpdates(Map<String, String> updates) {
    _availableUpdates.addAll(updates);
    notifyListeners();
  }

  Map<String, String> get availableUpdates => Map.from(_availableUpdates);

  void notifyStateChange() {
    notifyListeners();
  }
}

/// build Anime list, [Res.subData] should be maxPage or null if there is no limit.
typedef AnimeListBuilder = Future<Res<List<Anime>>> Function(int page);

/// build Anime list with next param, [Res.subData] should be next page param or null if there is no next page.
typedef AnimeListBuilderWithNext =
    Future<Res<List<Anime>>> Function(String? next);

typedef LoginFunction = Future<Res<bool>> Function(String, String);

typedef LoadAnimeFunc = Future<Res<AnimeDetails>> Function(String id);

typedef LoadAnimePagesFunc<T> = Future<T> Function(String id, String? ep);

typedef CommentsLoader =
    Future<Res<List<Comment>>> Function(
      String id,
      String? subId,
      int page,
      String? replyTo,
    );

typedef SendCommentFunc =
    Future<Res<bool>> Function(
      String id,
      String? subId,
      String content,
      String? replyTo,
    );

typedef GetImageLoadingConfigFunc =
    Future<Map<String, dynamic>> Function(
      String imageKey,
      String animeId,
      String epId,
    )?;

typedef GetThumbnailLoadingConfigFunc =
    Map<String, dynamic> Function(String imageKey)?;

typedef AnimeThumbnailLoader =
    Future<Res<List<String>>> Function(String animeId, String? next);

typedef LikeOrUnlikeAnimeFunc =
    Future<Res<bool>> Function(String animeId, bool isLiking);

/// [isLiking] is true if the user is liking the comment, false if unliking.
/// return the new likes count or null.
typedef LikeCommentFunc =
    Future<Res<int?>> Function(
      String animeId,
      String? subId,
      String commentId,
      bool isLiking,
    );

/// [isUp] is true if the user is upvoting the comment, false if downvoting.
/// return the new vote count or null.
typedef VoteCommentFunc =
    Future<Res<int?>> Function(
      String animeId,
      String? subId,
      String commentId,
      bool isUp,
      bool isCancel,
    );

typedef HandleClickTagEvent =
    Map<String, String> Function(String namespace, String tag);

/// [rating] is the rating value, 0-10. 1 represents 0.5 star.
typedef StarRatingFunc = Future<Res<bool>> Function(String animeId, int rating);

class AnimeSource {
  static List<AnimeSource> all() => AnimeSourceManager().all();

  static AnimeSource? find(String key) => AnimeSourceManager().find(key);

  static AnimeSource? fromIntKey(int key) =>
      AnimeSourceManager().fromIntKey(key);

  static bool get isEmpty => AnimeSourceManager().isEmpty;

  /// Name of this source.
  final String name;

  /// Identifier of this source.
  final String key;

  int get intKey {
    return key.hashCode;
  }

  /// Account config.
  final AccountConfig? account;

  /// Category data used to build a static category tags page.
  final CategoryData? categoryData;

  /// Category comics data used to build a comics page with a category tag.
  final CategoryAnimesData? categoryAnimesData;

  /// Favorite data used to build favorite page.
  final FavoriteData? favoriteData;

  /// Explore pages.
  final List<ExplorePageData> explorePages;

  /// Search page.
  final SearchPageData? searchPageData;

  /// 加载动漫信息的函数
  final LoadAnimeFunc? loadAnimeInfo;

  final AnimeThumbnailLoader? loadAnimeThumbnail;

  /// 加载动漫页面的函数
  final LoadAnimePagesFunc? loadAnimePages;

  final GetImageLoadingConfigFunc? getImageLoadingConfig;

  final Map<String, dynamic> Function(String imageKey)?
  getThumbnailLoadingConfig;

  var data = <String, dynamic>{};

  bool get isLogged => data["account"] != null;

  final String filePath;

  final String url;

  final String version;

  final CommentsLoader? commentsLoader;

  final SendCommentFunc? sendCommentFunc;

  final RegExp? idMatcher;

  final LikeOrUnlikeAnimeFunc? likeOrUnlikeAnime;

  final VoteCommentFunc? voteCommentFunc;

  final LikeCommentFunc? likeCommentFunc;

  final Map<String, Map<String, dynamic>>? settings;

  final Map<String, Map<String, String>>? translations;

  final HandleClickTagEvent? handleClickTagEvent;

  final LinkHandler? linkHandler;

  final bool enableTagsSuggestions;

  final bool enableTagsTranslate;

  final StarRatingFunc? starRatingFunc;

  Future<void> loadData() async {
    var file = File("${App.dataPath}/anime_source/$key.data");
    if (await file.exists()) {
      data = Map.from(jsonDecode(await file.readAsString()));
    }
  }

  bool _isSaving = false;
  bool _haveWaitingTask = false;

  Future<void> saveData() async {
    if (_haveWaitingTask) return;
    while (_isSaving) {
      _haveWaitingTask = true;
      await Future.delayed(const Duration(milliseconds: 20));
      _haveWaitingTask = false;
    }
    _isSaving = true; // 开始保存数据
    var file = File("${App.dataPath}/anime_source/$key.data");
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(data));
    _isSaving = false;
    DataSync().uploadData();
  }

  Future<bool> reLogin() async {
    if (data["account"] == null) {
      return false;
    }
    final List accountData = data["account"];
    var res = await account!.login!(accountData[0], accountData[1]);
    if (res.error) {
      Log.error("Failed to re-login", res.errorMessage ?? "Error");
    }
    return !res.error;
  }

  AnimeSource(
    this.name,
    this.key,
    this.account,
    this.categoryData,
    this.categoryAnimesData,
    this.favoriteData,
    this.explorePages,
    this.searchPageData,
    this.settings,
    this.loadAnimeInfo,
    this.loadAnimeThumbnail,
    this.loadAnimePages,
    this.getImageLoadingConfig,
    this.getThumbnailLoadingConfig,
    this.filePath,
    this.url,
    this.version,
    this.commentsLoader,
    this.sendCommentFunc,
    this.likeOrUnlikeAnime,
    this.voteCommentFunc,
    this.likeCommentFunc,
    this.idMatcher,
    this.translations,
    this.handleClickTagEvent,
    this.linkHandler,
    this.enableTagsSuggestions,
    this.enableTagsTranslate,
    this.starRatingFunc,
  );
}

class AccountConfig {
  final LoginFunction? login;

  final String? loginWebsite;

  final String? registerWebsite;

  final void Function() logout;

  final List<AccountInfoItem> infoItems;

  final bool Function(String url, String title)? checkLoginStatus;

  final void Function()? onLoginWithWebviewSuccess;

  final List<String>? cookieFields;

  final Future<bool> Function(List<String>)? validateCookies;

  const AccountConfig(
    this.login,
    this.loginWebsite,
    this.registerWebsite,
    this.logout,
    this.checkLoginStatus,
    this.onLoginWithWebviewSuccess,
    this.cookieFields,
    this.validateCookies,
  ) : infoItems = const [];
}

class AccountInfoItem {
  final String title;
  final String Function()? data;
  final void Function()? onTap;
  final WidgetBuilder? builder;

  AccountInfoItem({required this.title, this.data, this.onTap, this.builder});
}

class LoadImageRequest {
  String url;

  Map<String, String> headers;

  LoadImageRequest(this.url, this.headers);
}

class ExplorePageData {
  final String title;

  final ExplorePageType type;

  final AnimeListBuilder? loadPage;

  final AnimeListBuilderWithNext? loadNext;

  final Future<Res<List<ExplorePagePart>>> Function()? loadMultiPart;

  /// return a `List` contains `List<Anime>` or `ExplorePagePart`
  final Future<Res<List<Object>>> Function(int index)? loadMixed;

  ExplorePageData(
    this.title,
    this.type,
    this.loadPage,
    this.loadNext,
    this.loadMultiPart,
    this.loadMixed,
  );
}

class ExplorePagePart {
  final String title;

  final List<Anime> animes;

  /// If this is not null, the [ExplorePagePart] will show a button to jump to new page.
  ///
  /// Value of this field should match the following format:
  ///   - search:keyword
  ///   - category:categoryName
  ///
  /// End with `@`+`param` if the category has a parameter.
  final PageJumpTarget? viewMore;

  const ExplorePagePart(this.title, this.animes, this.viewMore);
}

class ExploreGridPart {
  final List<Anime> animes;

  const ExploreGridPart(this.animes);
}

enum ExplorePageType {
  multiPageAnimeList,
  singlePageWithMultiPart,
  mixed,
  override,
}

typedef SearchFunction =
    Future<Res<List<Anime>>> Function(
      String keyword,
      int page,
      List<String> searchOption,
    );

typedef SearchNextFunction =
    Future<Res<List<Anime>>> Function(
      String keyword,
      String? next,
      List<String> searchOption,
    );

class SearchPageData {
  /// If this is not null, the default value of search options will be first element.
  final List<SearchOptions>? searchOptions;

  final SearchFunction? loadPage;

  final SearchNextFunction? loadNext;

  const SearchPageData(this.searchOptions, this.loadPage, this.loadNext);
}

class SearchOptions {
  final LinkedHashMap<String, String> options;

  final String label;

  final String type;

  final String? defaultVal;

  const SearchOptions(this.options, this.label, this.type, this.defaultVal);

  String get defaultValue => defaultVal ?? options.keys.first;
}

typedef CategoryAnimesLoader =
    Future<Res<List<Anime>>> Function(
      String category,
      String? param,
      List<String> options,
      int page,
    );

class CategoryAnimesData {
  /// options
  final List<CategoryAnimesOptions> options;

  /// [category] is the one clicked by the user on the category page.
  ///
  /// if [BaseCategoryPart.categoryParams] is not null, [param] will be not null.
  ///
  /// [Res.subData] should be maxPage or null if there is no limit.
  final CategoryAnimesLoader load;

  final RankingData? rankingData;

  const CategoryAnimesData(this.options, this.load, {this.rankingData});
}

class RankingData {
  final Map<String, String> options;

  final Future<Res<List<Anime>>> Function(String option, int page)? load;

  final Future<Res<List<Anime>>> Function(String option, String? next)?
  loadWithNext;

  const RankingData(this.options, this.load, this.loadWithNext);
}

class CategoryAnimesOptions {
  /// Use a [LinkedHashMap] to describe an option list.
  /// key is for loading Animes, value is the name displayed on screen.
  /// Default value will be the first of the Map.
  final LinkedHashMap<String, String> options;

  /// If [notShowWhen] contains category's name, the option will not be shown.
  final List<String> notShowWhen;

  final List<String>? showWhen;

  const CategoryAnimesOptions(this.options, this.notShowWhen, this.showWhen);
}

class LinkHandler {
  final List<String> domains;

  final String? Function(String url) linkToId;

  const LinkHandler(this.domains, this.linkToId);
}
