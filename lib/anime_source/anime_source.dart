library anime_source;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:kostori/tools/extensions.dart';
import '../base.dart';
import '../components/components.dart';
import '../foundation/app.dart';
import '../foundation/history.dart';
import '../foundation/js_engine.dart';
import '../foundation/log.dart';
import '../network/base_anime.dart';
import '../network/res.dart';
import '../network/update.dart';
import 'built_in/girigirilove.dart';

part 'category.dart';

part 'parser.dart';

part 'favorites.dart';

typedef LoginFunction = Future<Res<bool>> Function(String, String);

typedef AnimeListBuilder = Future<Res<List<BaseAnime>>> Function(int page);

typedef LoadAnimeFunc = Future<Res<AnimeInfoData>> Function(String id);

typedef LoadAnimePagesFunc = Future<Res<List<String>>> Function(
    String id, String? ep);

typedef CommentsLoader = Future<Res<List<Comment>>> Function(
    String id, String? subId, int page, String? replyTo);

typedef SendCommentFunc = Future<Res<bool>> Function(
    String id, String? subId, String content, String? replyTo);

typedef GetImageLoadingConfigFunc = Map<String, dynamic> Function(
    String imageKey, String animeId, String epId)?;
typedef GetThumbnailLoadingConfigFunc = Map<String, dynamic> Function(
    String imageKey)?;

class AnimeSource {
  /// 内置的动漫源列表
  static final builtIn = [girigirilove]; // 这是一个内置的动漫源，包含了一个名为 girigirilove 的源

  /// 存储所有动漫源的列表
  static List<AnimeSource> sources = [];

// 根据 key 查找 AnimeSource 对象
  static AnimeSource? find(String key) =>
      sources.firstWhereOrNull((element) => element.key == key);
  // 返回具有匹配 key 的 AnimeSource 对象，找不到时返回 null

// 根据 int 类型的 key 查找 AnimeSource 对象
  static AnimeSource? fromIntKey(int key) =>
      sources.firstWhereOrNull((element) => element.key.hashCode == key);
  // 根据源的哈希值查找 AnimeSource 对象

  /// 初始化方法，用于加载内置源和外部源
  static Future<void> init() async {
    // 遍历所有内置源
    for (var source in builtInSources) {
      // 检查当前源是否启用
      if (appdata.appSettings.isAnimeSourceEnabled(source)) {
        try {
          // 找到对应的内置源并添加到 sources 列表中
          var s = builtIn.firstWhere((e) => e.key == source);
          sources.add(s);
          // 加载源的数据
          await s.loadData();
          // 如果有初始化数据的回调，则调用它
          s.initData?.call(s);
        } catch (e) {
          // 如果添加源时出错，记录错误日志
          log("$e", "AnimeSource", LogLevel.error);
        }
      } else {
        // 源未启用时的日志
        // print("源 '$source' 未启动.");
      }
    }

    // 设置存储源的目录路径
    final path = "${App.dataPath}/anime_source";
    // 检查目录是否存在
    if (!(await Directory(path).exists())) {
      // 如果不存在，则创建该目录
      Directory(path).create();
      return; // 目录创建后返回
    }
    // 遍历目录中的所有文件
    await for (var entity in Directory(path).list()) {
      if (entity is File && entity.path.endsWith(".js")) {
        // 检查是否为 JS 文件
        try {
          // 解析 JS 文件并添加到 sources 列表中
          var source = await AnimeSourceParser()
              .parse(await entity.readAsString(), entity.absolute.path);
          sources.add(source);
        } catch (e, s) {
          // 解析文件出错，记录错误日志
          log("$e\n$s", "AnimeSource", LogLevel.error);
          // print("Error parsing file '${entity.path}': $e");
        }
      }
    }
  }

  /// 重载所有源的方法
  static Future reload() async {
    sources.clear(); // 清空现有的 sources 列表
    JsEngine().runCode("AnimeSource.sources = {};"); // 重置 JavaScript 引擎中的源
    await init(); // 重新初始化源
  }

  /// 源的名称
  final String name;

  /// 源的唯一标识符
  final String key;

  /// 计算并返回源的整数键
  int get intKey {
    return key.hashCode; // 返回源 key 的哈希值作为整数键
  }

  /// 账户配置
  final AccountConfig? account;

  /// 用于构建静态分类标签页面的分类数据
  final CategoryData? categoryData;

  /// 用于构建带有分类标签的动漫页面的分类动漫数据
  final CategoryAnimesData? categoryAnimesData;

  /// 用于构建收藏页面的收藏数据
  final FavoriteData? favoriteData;

  /// 探索页面数据
  final List<ExplorePageData> explorePages;

  /// 搜索页面数据
  final SearchPageData? searchPageData;

  /// 设置项列表
  final List<SettingItem> settings;

  /// 加载动漫信息的函数
  final LoadAnimeFunc? loadAnimeInfo;

  /// 加载动漫页面的函数
  final LoadAnimePagesFunc? loadAnimePages;

  /// 获取图像加载配置的函数
  final Map<String, dynamic> Function(
      String imageKey, String animeId, String epId)? getImageLoadingConfig;

  /// 获取缩略图加载配置的函数
  final Map<String, dynamic> Function(String imageKey)?
      getThumbnailLoadingConfig;

  /// 用于匹配简要ID的正则表达式
  final String? matchBriefIdReg;

  // 存储额外的数据
  var data = <String, dynamic>{};

  /// 检查用户是否登录
  bool get isLogin => data["account"] != null;

  /// 文件路径
  final String filePath;

  /// URL 地址
  final String url;

  /// 版本号
  final String version;

  /// 加载评论的函数
  final CommentsLoader? commentsLoader;

  /// 发送评论的函数
  final SendCommentFunc? sendCommentFunc;

  /// 用于匹配 ID 的正则表达式
  final RegExp? idMatcher;

  /// 构建动漫页面的函数
  final Widget Function(BuildContext context, String id, String? cover)?
      animePageBuilder;

  /// 加载数据的方法
  Future<void> loadData() async {
    var file = File("${App.dataPath}/anime_source/$key.data");
    if (await file.exists()) {
      // 如果文件存在，则读取并解析 JSON 数据
      data = Map.from(jsonDecode(await file.readAsString()));
    }
  }

  /// 用于保存数据的状态
  bool _isSaving = false;
  bool _haveWaitingTask = false;

  /// 保存数据的方法
  Future<void> saveData() async {
    if (_haveWaitingTask) return; // 如果有等待的任务，则返回
    while (_isSaving) {
      _haveWaitingTask = true; // 设置等待任务标志
      await Future.delayed(const Duration(milliseconds: 20)); // 等待一段时间
      _haveWaitingTask = false; // 清除等待任务标志
    }
    _isSaving = true; // 开始保存数据
    var file = File("${App.dataPath}/anime_source/$key.data");
    if (!await file.exists()) {
      // 如果文件不存在，则创建文件
      await file.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(data)); // 将数据写入文件
    _isSaving = false; // 完成保存操作
  }

  /// 重新登录的方法
  Future<bool> reLogin() async {
    if (data["account"] == null) {
      return false; // 如果没有账户信息，则返回 false
    }
    final List accountData = data["account"];
    // 调用账户登录方法
    var res = await account!.login!(accountData[0], accountData[1]);
    if (res.error) {
      // 如果登录失败，记录错误日志
      Log.error("Failed to re-login", res.errorMessage ?? "Error");
    }
    return !res.error; // 返回登录是否成功
  }

  /// 初始化数据的回调函数
  final FutureOr<void> Function(AnimeSource source)? initData;

  /// 检查该源是否为内置源
  bool get isBuiltIn => filePath == 'built-in';

  /// 自定义动漫瓷砖构建器的回调函数
  final Widget Function(BuildContext, BaseAnime, List<AnimeTileMenuOption>?)?
      animeTileBuilderOverride;

  /// 构造函数
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
      this.loadAnimePages,
      this.getImageLoadingConfig,
      this.getThumbnailLoadingConfig,
      this.matchBriefIdReg,
      this.filePath,
      this.url,
      this.version,
      this.commentsLoader,
      this.sendCommentFunc)
      : initData = null,
        animeTileBuilderOverride = null,
        idMatcher = null,
        animePageBuilder = null; // 初始化其他参数

  /// 命名构造函数，允许更灵活的初始化
  AnimeSource.named({
    required this.name,
    required this.key,
    this.account,
    this.categoryData,
    this.categoryAnimesData,
    this.favoriteData,
    this.explorePages = const [],
    this.searchPageData,
    this.settings = const [],
    this.loadAnimeInfo,
    this.loadAnimePages,
    this.getImageLoadingConfig,
    this.getThumbnailLoadingConfig,
    this.matchBriefIdReg,
    required this.filePath,
    this.url = '',
    this.version = '',
    this.commentsLoader,
    this.sendCommentFunc,
    this.initData,
    this.animeTileBuilderOverride,
    this.idMatcher,
    this.animePageBuilder,
  });

  /// 未知动漫源的构造函数
  AnimeSource.unknown(this.key)
      : name = "Unknown",
        account = null,
        categoryData = null,
        categoryAnimesData = null,
        favoriteData = null,
        explorePages = [],
        searchPageData = null,
        settings = [],
        loadAnimeInfo = null,
        loadAnimePages = null,
        getImageLoadingConfig = null,
        getThumbnailLoadingConfig = null,
        matchBriefIdReg = null,
        filePath = "",
        url = "",
        version = "",
        commentsLoader = null,
        sendCommentFunc = null,
        initData = null,
        animeTileBuilderOverride = null,
        idMatcher = null,
        animePageBuilder = null; // 初始化所有属性为默认值
}

/// 表示账户配置的类。
///
/// 包含用于登录、注销以及显示账户相关信息的功能和数据。
class AccountConfig {
  /// 登录函数，接收用户名和密码，返回一个包含登录结果的 [Future]。
  ///
  /// 如果未提供，则无法执行登录操作。
  final LoginFunction? login;

  /// 登录成功后的回调函数。
  ///
  /// 接收一个 [BuildContext] 参数，可以用于在登录后执行额外的操作，如导航到主页面。
  final FutureOr<void> Function(BuildContext)? onLogin;

  /// 登录网站的 URL。
  ///
  /// 用于在 UI 中提供跳转到登录页面的链接。
  final String? loginWebsite;

  /// 注册网站的 URL。
  ///
  /// 用于在 UI 中提供跳转到注册页面的链接。
  final String? registerWebsite;

  /// 注销函数，用于处理用户的注销操作。
  ///
  /// 无参数，无返回值。
  final void Function() logout;

  /// 是否允许重新登录。
  ///
  /// 如果设置为 `true`，当登录过期时，允许自动重新登录。
  final bool allowReLogin;

  /// 账户信息项的列表。
  ///
  /// 用于在 UI 中显示账户的详细信息，如用户名、邮箱等。
  final List<AccountInfoItem> infoItems;

  /// 默认构造函数。
  ///
  /// 初始化登录函数、登录网站、注册网站和注销函数。
  /// 默认允许重新登录，并且账户信息项为空列表。
  const AccountConfig(
      this.login, this.loginWebsite, this.registerWebsite, this.logout,
      {this.onLogin})
      : allowReLogin = true,
        infoItems = const [];

  /// 命名构造函数，允许更灵活地初始化账户配置。
  ///
  /// 可选参数包括登录函数、登录网站、注册网站、注销函数、登录回调、
  /// 是否允许重新登录以及账户信息项。
  const AccountConfig.named({
    this.login,
    this.loginWebsite,
    this.registerWebsite,
    required this.logout,
    this.onLogin,
    this.allowReLogin = true,
    this.infoItems = const [],
  });
}

/// 表示账户信息项的类。
///
/// 用于在 UI 中显示账户的特定信息，如用户名、邮箱等。
class AccountInfoItem {
  /// 信息项的标题。
  ///
  /// 例如，“用户名”、“邮箱”等。
  final String title;

  /// 获取信息项数据的函数。
  ///
  /// 返回一个 `String`，表示信息项的具体内容。如果未提供，则信息项将不显示数据。
  final String Function()? data;

  /// 信息项被点击时的回调函数。
  ///
  /// 如果提供，则当用户点击信息项时执行此函数。
  final void Function()? onTap;

  /// 构建信息项的自定义 Widget 的构建器函数。
  ///
  /// 如果提供，则使用此构建器函数来自定义信息项的显示方式。
  final WidgetBuilder? builder;

  /// 构造函数，初始化账户信息项。
  ///
  /// [title] 是必需的，用于显示信息项的标题。
  /// 其他参数均为可选，用于提供数据获取、点击事件处理和自定义构建逻辑。
  AccountInfoItem({required this.title, this.data, this.onTap, this.builder});
}

/// 表示加载图像请求的类。
///
/// 包含图像的 URL 和相关的 HTTP 头部信息。
class LoadImageRequest {
  /// 图像的 URL 地址。
  final String url;

  /// HTTP 请求的头部信息。
  ///
  /// 通常用于携带认证信息或其他必要的头部字段。
  final Map<String, String> headers;

  /// 构造函数，初始化图像加载请求。
  ///
  /// [url] 是图像的 URL 地址。
  /// [headers] 是 HTTP 请求的头部信息。
  LoadImageRequest(this.url, this.headers);
}

/// 表示探索页面数据的类。
///
/// 包含用于构建不同类型探索页面的加载函数和配置。
class ExplorePageData {
  /// 探索页面的标题。
  final String title;

  /// 探索页面的类型。
  final ExplorePageType type;

  /// 用于加载单页动漫列表的函数。
  ///
  /// 接收一个页面编号，返回一个包含动漫列表的 [Future]。
  final AnimeListBuilder? loadPage;

  /// 用于加载多部分探索页面的函数。
  ///
  /// 返回一个包含多个 [ExplorePagePart] 的 [Future]。
  final Future<Res<List<ExplorePagePart>>> Function()? loadMultiPart;

  /// 用于加载混合类型数据的函数。
  ///
  /// 返回一个包含 `List<BaseAnime>` 或 `ExplorePagePart` 的 `List<Object>` 的 [Future]。
  final Future<Res<List<Object>>> Function(int index)? loadMixed;

  /// 覆盖默认页面构建逻辑的 Widget 构建器函数。
  ///
  /// 如果提供，则使用此构建器函数来构建自定义页面。
  final WidgetBuilder? overridePageBuilder;

  /// 构造函数，初始化探索页面数据。
  ///
  /// 主要用于不需要混合类型数据或自定义页面构建逻辑的探索页面。
  ExplorePageData(this.title, this.type, this.loadPage, this.loadMultiPart)
      : loadMixed = null,
        overridePageBuilder = null;

  /// 命名构造函数，允许更灵活地初始化探索页面数据。
  ///
  /// 可选参数包括加载单页、多部分、混合数据的函数，以及自定义页面构建器。
  ExplorePageData.named({
    required this.title,
    required this.type,
    this.loadPage,
    this.loadMultiPart,
    this.loadMixed,
    this.overridePageBuilder,
  });
}

class ExplorePagePart {
  final String title;

  final List<BaseAnime> animes;

  /// If this is not null, the [ExplorePagePart] will show a button to jump to new page.
  ///
  /// Value of this field should match the following format:
  ///   - search:keyword
  ///   - category:categoryName
  ///
  /// End with `@`+`param` if the category has a parameter.
  final String? viewMore;

  const ExplorePagePart(this.title, this.animes, this.viewMore);
}

/// ExplorePageType 枚举表示不同的探索页面类型。
///
/// - `multiPageAnimeList`：多页的动画列表。
/// - `singlePageWithMultiPart`：单页包含多个部分内容。
/// - `mixed`：包含混合类型内容的页面（如动画和漫画混合）。
/// - `override`：用于自定义页面显示的重写类型。
enum ExplorePageType {
  multiPageAnimeList,
  singlePageWithMultiPart,
  mixed,
  override,
}

/// AnimeInfoData 类存储有关某个动画的信息，
/// 它包含了动画的基本数据以及一些可选的扩展信息。
///
/// 该类还实现了 HistoryMixin，支持历史记录的功能。
class AnimeInfoData with HistoryMixin {
  /// 动画的标题。
  @override
  final String title;

  /// 动画的副标题，可能为 `null`。
  @override
  final String? subTitle;

  /// 动画封面图片的 URL 地址。
  @override
  final String cover;

  /// 动画的描述，可能为 `null`。
  final String? description;

  /// 动画的标签，每个标签包含多个字符串列表。
  final Map<String, List<String>> tags;

  /// 动画的章节信息，键为章节 ID，值为章节名称，可能为 `null`。
  final Map<String, String>? chapters;

  /// 动画的缩略图列表，可能为 `null`。
  final List<String>? thumbnails;

  /// 用于加载指定章节缩略图的函数，接受章节 ID 和页码作为参数，返回包含图片 URL 的结果，可能为 `null`。
  final Future<Res<List<String>>> Function(String id, int page)?
      thumbnailLoader;

  /// 动画缩略图的最大页数。
  final int thumbnailMaxPage;

  /// 推荐的相关动画，可能为 `null`。
  final List<BaseAnime>? suggestions;

  /// 动画的来源标识符，用于区分不同平台的数据。
  final String sourceKey;

  /// 动画的唯一 ID。
  final String animeId;

  /// 动画是否被用户标记为收藏，可能为 `null`。
  final bool? isFavorite;

  /// 动画的子 ID，可能用于区分同一系列的不同部分，可能为 `null`。
  final String? subId;

  /// 构造函数，接收动画的各种属性，并设置默认值。
  const AnimeInfoData(
      this.title,
      this.subTitle,
      this.cover,
      this.description,
      this.tags,
      this.chapters,
      this.thumbnails,
      this.thumbnailLoader,
      this.thumbnailMaxPage,
      this.suggestions,
      this.sourceKey,
      this.animeId,
      {this.isFavorite,
      this.subId});

  /// 将当前对象转换为 JSON 格式，方便序列化或存储。
  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "subTitle": subTitle,
      "cover": cover,
      "description": description,
      "tags": tags,
      "chapters": chapters,
      "sourceKey": sourceKey,
      "animeId": animeId,
      "isFavorite": isFavorite,
      "subId": subId,
    };
  }

  /// 从 JSON 数据生成 `tags` 的辅助函数。
  static Map<String, List<String>> _generateMap(Map<String, dynamic> map) {
    var res = <String, List<String>>{};
    map.forEach((key, value) {
      res[key] = List<String>.from(value);
    });
    return res;
  }

  /// 从 JSON 数据反序列化为 `AnimeInfoData` 对象。
  AnimeInfoData.fromJson(Map<String, dynamic> json)
      : title = json["title"],
        subTitle = json["subTitle"],
        cover = json["cover"],
        description = json["description"],
        tags = _generateMap(json["tags"]),
        chapters = Map<String, String>.from(json["chapters"]),
        sourceKey = json["sourceKey"],
        animeId = json["animeId"],
        thumbnails = null,
        thumbnailLoader = null,
        thumbnailMaxPage = 0,
        suggestions = null,
        isFavorite = json["isFavorite"],
        subId = json["subId"];

  /// 返回历史记录类型，基于 `sourceKey` 生成唯一的哈希值。
  @override
  HistoryType get historyType => HistoryType(sourceKey.hashCode);

  /// 返回动画的目标标识符，用于历史记录中。
  @override
  String get target => animeId;
}

/// `CategoryAnimesLoader` 是一个函数类型定义，
/// 用于加载特定类别的动画数据。
/// - [category]：被用户点击的类别。
/// - [param]：类别的额外参数，可能为 `null`。
/// - [options]：加载动画时的选项列表。
/// - [page]：当前请求的页码。
/// - 返回一个 `Future`，其中包含 `Res` 对象，
/// 该对象封装了 `List<BaseAnime>`，表示动画列表。
typedef CategoryAnimesLoader = Future<Res<List<BaseAnime>>> Function(
    String category, String? param, List<String> options, int page);

/// `CategoryAnimesData` 类包含有关类别页面的加载逻辑和选项。
class CategoryAnimesData {
  /// 动画类别的加载选项列表。
  final List<CategoryAnimesOptions> options;

  /// 加载指定类别的动画数据的函数。
  final CategoryAnimesLoader load;

  /// 排行榜数据，可能为 `null`。
  final RankingData? rankingData;

  /// 构造函数，初始化类别选项和加载函数。
  const CategoryAnimesData(this.options, this.load, {this.rankingData});

  /// 命名构造函数，提供默认值。
  const CategoryAnimesData.named({
    this.options = const [],
    required this.load,
    this.rankingData,
  });
}

/// `SearchFunction` 是一个函数类型定义，
/// 用于根据关键字搜索动画数据。
/// - [keyword]：搜索的关键词。
/// - [page]：当前请求的页码。
/// - [searchOption]：搜索选项列表。
/// - 返回一个 `Future`，其中包含 `Res` 对象，
/// 该对象封装了 `List<BaseAnime>`，表示搜索结果。
typedef SearchFunction = Future<Res<List<BaseAnime>>> Function(
    String keyword, int page, List<String> searchOption);

/// `SearchPageData` 类定义了搜索页面的数据结构和逻辑。
class SearchPageData {
  /// 搜索选项的列表，若非 `null`，默认选项为列表中的第一个元素。
  final List<SearchOptions>? searchOptions;

  /// 自定义搜索选项的构建器，用户可以用它自定义界面。
  final Widget Function(BuildContext, List<String> initialValues,
      void Function(List<String>))? customOptionsBuilder;

  /// 自定义搜索结果的构建器，可以覆盖默认的搜索结果显示。
  final Widget Function(String keyword, List<String> options)?
      overrideSearchResultBuilder;

  /// 加载搜索结果的函数。
  final SearchFunction? loadPage;

  /// 是否启用语言过滤功能。
  final bool enableLanguageFilter;

  /// 是否启用标签建议功能。
  final bool enableTagsSuggestions;

  /// 构造函数，初始化搜索选项和加载逻辑。
  const SearchPageData(this.searchOptions, this.loadPage)
      : enableLanguageFilter = false,
        customOptionsBuilder = null,
        overrideSearchResultBuilder = null,
        enableTagsSuggestions = false;

  /// 命名构造函数，允许自定义搜索页面的各项功能。
  const SearchPageData.named({
    this.searchOptions,
    this.loadPage,
    this.enableLanguageFilter = false,
    this.customOptionsBuilder,
    this.overrideSearchResultBuilder,
    this.enableTagsSuggestions = false,
  });
}

/// `SearchOptions` 类表示一个搜索选项，
/// 其中包含选项名称及其对应的值。
class SearchOptions {
  /// 使用 `LinkedHashMap` 存储选项，键为选项值，值为显示在界面上的文本。
  final LinkedHashMap<String, String> options;

  /// 选项的标签，用于描述该选项的用途。
  final String label;

  /// 获取默认值，默认为选项列表中的第一个值。
  String get defaultValue => options.keys.first;

  /// 构造函数，初始化选项和标签。
  const SearchOptions(this.options, this.label);

  /// 命名构造函数，用于提供详细配置。
  const SearchOptions.named({required this.options, required this.label});
}

/// `SettingItem` 类表示设置页面中的一项设置。
class SettingItem {
  /// 设置项的名称。
  final String name;

  /// 设置项的图标名称。
  final String iconName;

  /// 设置项的类型，可以是开关、选择器或输入框。
  final SettingType type;

  /// 设置项的选项列表，可能为 `null`。
  final List<String>? options;

  /// 构造函数，初始化设置项的属性。
  const SettingItem(this.name, this.iconName, this.type, this.options);
}

/// `SettingType` 枚举表示设置项的类型。
enum SettingType {
  switcher, // 开关
  selector, // 选择器
  input, // 输入框
}

/// `RankingData` 类定义了排行榜页面的数据和加载逻辑。
class RankingData {
  /// 排行榜选项，键为选项值，值为显示的文本。
  final Map<String, String> options;

  /// 加载指定排行榜数据的函数。
  final Future<Res<List<BaseAnime>>> Function(String option, int page) load;

  /// 构造函数，初始化排行榜数据。
  const RankingData(this.options, this.load);

  /// 命名构造函数，用于更详细的配置。
  const RankingData.named({
    required this.options,
    required this.load,
  });
}

/// `CategoryAnimesOptions` 类表示类别页面中的选项列表。
class CategoryAnimesOptions {
  /// 使用 `LinkedHashMap` 描述选项列表，键为选项值，值为显示文本。
  final LinkedHashMap<String, String> options;

  /// `notShowWhen` 包含类别名称时，选项将不显示。
  final List<String> notShowWhen;

  /// `showWhen` 包含类别名称时，选项将显示，可能为 `null`。
  final List<String>? showWhen;

  /// 构造函数，初始化选项、显示和隐藏条件。
  const CategoryAnimesOptions(this.options, this.notShowWhen, this.showWhen);

  /// 命名构造函数，用于详细配置。
  const CategoryAnimesOptions.named({
    required this.options,
    this.notShowWhen = const [],
    this.showWhen,
  });
}

/// `Comment` 类表示一条评论的数据结构。
class Comment {
  /// 评论用户的名称。
  final String userName;

  /// 用户的头像 URL，可能为 `null`。
  final String? avatar;

  /// 评论的内容。
  final String content;

  /// 评论的时间，可能为 `null`。
  final String? time;

  /// 评论的回复数量，可能为 `null`。
  final int? replyCount;

  /// 评论的 ID，可能为 `null`。
  final String? id;

  /// 构造函数，初始化评论的属性。
  const Comment(this.userName, this.avatar, this.content, this.time,
      this.replyCount, this.id);
}
