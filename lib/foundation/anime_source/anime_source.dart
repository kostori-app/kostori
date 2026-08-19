library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/pages/category_animes_page.dart';
import 'package:kostori/pages/search_result_page.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/init.dart';
import 'package:kostori/utils/io.dart';

part 'category.dart';

part 'models.dart';

part 'parser.dart';

class AnimeSourceManager with ChangeNotifier, Init {
  final List<AnimeSource> _sources = [];

  static AnimeSourceManager? _instance;

  AnimeSourceManager._create();

  factory AnimeSourceManager() => _instance ??= AnimeSourceManager._create();

  List<AnimeSource> all() => List.from(_sources);

  /// 仅返回启用的源（业务页面用）
  List<AnimeSource> enabledAll() =>
      _sources.where((s) => isEnabled(s.key)).toList();

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
          SourceLog.error("AnimeSource", "$e\n$s");
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
    // 移除源时同时清理其禁用标记
    final disabled = _disabledSources;
    if (disabled.remove(key)) {
      _saveDisabled(disabled);
    }
    notifyListeners();
  }

  bool get isEmpty => _sources.isEmpty;

  // ── 源开关 ─────────────────────────────────────────────────────────────

  static const _disabledKey = 'disabled_anime_sources';

  Set<String> get _disabledSources {
    final raw = appdata.implicitData[_disabledKey];
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  void _saveDisabled(Set<String> disabled) {
    appdata.implicitData[_disabledKey] = disabled.toList();
    appdata.writeImplicitData();
  }

  /// 源是否启用（默认启用）
  bool isEnabled(String key) => !_disabledSources.contains(key);

  /// 切换源开关
  void toggleSource(String key, bool enabled) {
    final disabled = _disabledSources;
    if (enabled) {
      disabled.remove(key);
    } else {
      disabled.add(key);
    }
    _saveDisabled(disabled);
    notifyListeners();
  }

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

/// 系列加载接口：部分源（emby/jellyfin 等的电影/合集类条目）没有分集，
/// 而是返回与剧集平行的系列列表。一个源只会存在剧集或系列之一。
/// [anime] 为加载完成的 AnimeDetails；返回的每条目复用 [Anime] 结构。
typedef SeriesLoader = Future<Res<List<Anime>>> Function(AnimeDetails anime);

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
    PageJumpTarget? Function(String namespace, String tag);

/// [rating] is the rating value, 0-10. 1 represents 0.5 star.
typedef StarRatingFunc = Future<Res<bool>> Function(String animeId, int rating);

/// 播放进度上报（源实现，如 emby/jellyfin 同步到服务端）。
/// [url] 为播放 URL，源从中提取条目 id；[playSessionId] 为源返回的会话 id。
typedef PlaybackProgressFunc = Future<dynamic> Function(
  String url,
  int positionMs,
  int durationMs,
  bool playing,
  String? playSessionId,
);

/// 播放停止上报（退出播放器时调用）。
typedef PlaybackStoppedFunc = Future<dynamic> Function(
  String url,
  int positionMs,
  String? playSessionId,
);

/// 通用源操作（favorite/delete/评论等），[action] 由源定义。
///
/// 源脚本实现 `anime.sourceAction(action, params)` 统一处理各类操作。
/// 已约定动作（源可按需实现）：
///
/// | action | params | 说明 |
/// |---|---|---|
/// | `favorite` | `{ id, favorite }` | 收藏/取消收藏（服务器） |
/// | `delete` | `{ id }` | 删除条目 |
/// | `markPlayed` | `{ id, played }` | 标记已播放/未播放 |
/// | `clearPlayback` | `{ id }` | 清除播放进度 |
/// | `rate` | `{ id, rating }` | 评分（0-10） |
/// | `sendComment` | `{ id, subId, content, replyTo }` | 发表评论 |
/// | `likeAnime` | `{ animeId, isLiking }` | 点赞/取消点赞番剧 |
/// | `likeComment` | `{ animeId, subId, commentId, isLiking }` | 点赞/取消点赞评论 |
/// | `voteComment` | `{ animeId, subId, commentId, isUp, isCancel }` | 投票评论 |
/// | `loadComments` | `{ id, subId, page, replyTo }` | 加载评论，返回 `{ comments, maxPage }` |
///
/// 返回：操作成功与否或数据（源自定义；失败可 throw 或返回 null）。
typedef SourceActionFunc = Future<dynamic> Function(
  String action,
  Map<String, dynamic> params,
);

class AnimeSource {
  static List<AnimeSource> all() => AnimeSourceManager().enabledAll();

  static List<AnimeSource> allSources() => AnimeSourceManager().all();

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

  /// Category animes data used to build a animes page with a category tag.
  final CategoryAnimesData? categoryAnimesData;

  /// Explore pages.
  final List<ExplorePageData> explorePages;

  /// Search page.
  final SearchPageData? searchPageData;

  /// 加载动漫信息的函数
  final LoadAnimeFunc? loadAnimeInfo;

  final AnimeThumbnailLoader? loadAnimeThumbnail;

  /// 加载动漫页面的函数
  final LoadAnimePagesFunc? loadAnimePages;

  /// 系列加载接口（剧集与系列一个源只会存在一种）
  final SeriesLoader? loadSeries;

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

  /// 播放进度上报（源实现）
  final PlaybackProgressFunc? playbackProgress;

  /// 播放停止上报
  final PlaybackStoppedFunc? playbackStopped;

  /// 通用源操作（favorite/delete 等）
  final SourceActionFunc? sourceAction;

  final Map<String, String>? httpHeaders;

  final Future<String> Function()? host;

  Future<void> loadData() async {
    var file = File("${App.dataPath}/anime_source/$key.data");
    if (await file.exists()) {
      data = Map.from(jsonDecode(await file.readAsString()));
    }
  }

  bool _isSaving = false;
  bool _haveWaitingTask = false;

  bool isBangumi = false;

  /// 搜索源分组。源脚本可在 data 中声明 `group`，否则按 isBangumi 推断。
  String get searchGroup =>
      (data['group'] as String?)?.trim().isNotEmpty == true
      ? (data['group'] as String).trim()
      : (isBangumi ? 'bangumi' : 'default');

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
      SourceLog.error("Failed to re-login", res.errorMessage ?? "Error");
    }
    return !res.error;
  }

  AnimeSource({
    required this.name,
    required this.key,
    required this.account,
    required this.categoryData,
    required this.categoryAnimesData,
    required this.explorePages,
    required this.searchPageData,
    required this.settings,
    required this.loadAnimeInfo,
    required this.loadAnimeThumbnail,
    required this.loadAnimePages,
    this.loadSeries,
    required this.getImageLoadingConfig,
    required this.getThumbnailLoadingConfig,
    required this.filePath,
    required this.url,
    required this.version,
    required this.commentsLoader,
    required this.sendCommentFunc,
    required this.likeOrUnlikeAnime,
    required this.voteCommentFunc,
    required this.likeCommentFunc,
    required this.idMatcher,
    required this.translations,
    required this.handleClickTagEvent,
    required this.linkHandler,
    required this.enableTagsSuggestions,
    required this.enableTagsTranslate,
    required this.starRatingFunc,
    this.playbackProgress,
    this.playbackStopped,
    this.sourceAction,
    required this.isBangumi,
    required this.host,
    required this.httpHeaders,
  });
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

typedef CategoryOptionsLoader =
    Future<Res<List<CategoryAnimesOptions>>> Function(
      String category,
      String? param,
    );

class CategoryAnimesData {
  /// options
  final List<CategoryAnimesOptions>? options;

  final CategoryOptionsLoader? optionsLoader;

  /// [category] is the one clicked by the user on the category page.
  ///
  /// if [BaseCategoryPart.categoryParams] is not null, [param] will be not null.
  ///
  /// [Res.subData] should be maxPage or null if there is no limit.
  final CategoryAnimesLoader load;

  final RankingData? rankingData;

  const CategoryAnimesData({
    this.options,
    this.optionsLoader,
    required this.load,
    this.rankingData,
  });
}

class RankingData {
  final Map<String, String> options;

  final Future<Res<List<Anime>>> Function(String option, int page)? load;

  final Future<Res<List<Anime>>> Function(String option, String? next)?
  loadWithNext;

  const RankingData(this.options, this.load, this.loadWithNext);
}

class CategoryAnimesOptions {
  final String label;

  /// Use a [LinkedHashMap] to describe an option list.
  /// key is for loading Animes, value is the name displayed on screen.
  /// Default value will be the first of the Map.
  final LinkedHashMap<String, String> options;

  /// If [notShowWhen] contains category's name, the option will not be shown.
  final List<String> notShowWhen;

  final List<String>? showWhen;

  const CategoryAnimesOptions(
    this.label,
    this.options,
    this.notShowWhen,
    this.showWhen,
  );
}

class LinkHandler {
  final List<String> domains;

  final String? Function(String url) linkToId;

  const LinkHandler(this.domains, this.linkToId);
}
