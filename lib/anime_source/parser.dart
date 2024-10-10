part of anime_source;

class AnimeSourceParseException implements Exception {
  final String message;

  AnimeSourceParseException(this.message);

  @override
  String toString() {
    return message;
  }
}

class AnimeSourceParser {
  /// anime source key
  String? _key;

  String? _name;

  Future<AnimeSource> createAndParse(String js, String fileName) async {
    // 检查 fileName 是否以 ".js" 结尾，如果不是，则自动在末尾添加 ".js" 后缀。
    if (!fileName.endsWith("js")) {
      fileName = "$fileName.js";
    }

    // 创建一个 File 对象，路径为 App.dataPath/anime_source/，后跟文件名。
    var file = File("${App.dataPath}/anime_source/$fileName");

    // 检查文件是否已经存在，如果存在，则生成新的文件名以避免文件名冲突。
    if (file.existsSync()) {
      int i = 0;
      // 如果文件存在，循环检查同名文件，依次加上编号 (i) 直到找到不存在的文件名。
      while (file.existsSync()) {
        file = File("${App.dataPath}/anime_source/$fileName($i).js");
        i++;
      }
    }

    // 将传入的 JavaScript 代码内容写入新创建的文件中。
    await file.writeAsString(js);

    // 尝试解析该文件内容
    try {
      // 调用异步函数 parse，传入 JavaScript 代码和文件路径，解析并返回 AnimeSource 对象。
      return await parse(js, file.path);
    } catch (e) {
      // 如果解析过程中出现异常，删除该文件以避免保存无效数据。
      await file.delete();

      // 弹出一个提示信息，显示解析失败的原因。
      showToast(message: "解析配置文件失败: $e");

      // 抛出异常，以便调用者知道发生了错误。
      rethrow;
    }
  }

  Future<AnimeSource> parse(String js, String filePath) async {
    js = js.replaceAll("\r\n", "\n");
    var line1 =
        js.split('\n').firstWhereOrNull((element) => element.trim().isNotEmpty);

    if (line1 == null ||
        !line1.startsWith("class ") ||
        !line1.contains("extends AnimeSource")) {
      throw AnimeSourceParseException("Invalid Content");
    }

    var className =
        line1.split("class")[1].split("extends AnimeSource").first.trim();
    if (className.isEmpty) {
      throw AnimeSourceParseException("className cannot be empty");
    }

    // 确保 AnimeSource 已定义
    JsEngine().runCode(
        "if (typeof AnimeSource === 'undefined') throw new Error('AnimeSource is not defined');");

    try {
      // 使用 QuickJS 引擎执行 JavaScript 代码，创建一个临时实例
      JsEngine().runCode("""
          (() => { 
            $js 
            this['temp'] = new $className(); 
          }).call(); 
        """);
    } catch (e) {
      throw AnimeSourceParseException("Error while creating instance: $e");
    }

    // 从 JavaScript 创建的临时对象中提取属性 'name'
    _name = JsEngine().runCode("this['temp'].name") ??
        (throw AnimeSourceParseException('name is required'));
    // 提取属性 'key'
    var key = JsEngine().runCode("this['temp'].key") ??
        (throw AnimeSourceParseException('key is required'));
    // 提取属性 'version'
    var version = JsEngine().runCode("this['temp'].version") ??
        (throw AnimeSourceParseException('version is required'));
    // 提取可选属性 'minAppVersion'
    var minAppVersion = JsEngine().runCode("this['temp'].minAppVersion");
    // 提取可选属性 'url'
    var url = JsEngine().runCode("this['temp'].url");
    // 提取可选属性 'matchBriefIdRegex'，假设存在于 'anime' 对象中
    var matchBriefIdRegex =
        JsEngine().runCode("this['temp'].anime.matchBriefIdRegex");

    // 如果定义了最小应用版本要求，进行版本比较
    if (minAppVersion != null) {
      if (compareSemVer(minAppVersion, appVersion.split('-').first)) {
        throw AnimeSourceParseException(
            "minAppVersion $minAppVersion is required");
      }
    }

    // 检查 AnimeSource.sources 中是否已有相同的 key，确保唯一性
    for (var source in AnimeSource.sources) {
      if (source.key == key) {
        throw AnimeSourceParseException("key($key) already exists");
      }
    }

    // 赋值 key 并进行进一步验证
    _key = key;
    _checkKeyValidation();

    // 将临时对象添加到 AnimeSource.sources 中，使用 key 作为索引
    JsEngine().runCode("""
      AnimeSource.sources.$_key = this['temp']; 
    """);

    // 加载 AnimeSource 所需的各种配置和功能数据
    final account = _loadAccountConfig();
    final explorePageData = _loadExploreData();
    final categoryPageData = _loadCategoryData();
    final categoryAnimesData = _loadCategoryAnimesData();
    final searchData = _loadSearchData();
    final loadAnimeFunc = _parseLoadAnimeFunc();
    final loadAnimePagesFunc = _parseLoadAnimePagesFunc();
    final getImageLoadingConfigFunc = _parseImageLoadingConfigFunc();
    final getThumbnailLoadingConfigFunc = _parseThumbnailLoadingConfigFunc();
    final favoriteData = _loadFavoriteData();
    final commentsLoader = _parseCommentsLoader();
    final sendCommentFunc = _parseSendCommentFunc();

    // 创建 AnimeSource 对象，传入所有必要的参数/19
    var source = AnimeSource(
        _name!,
        // AnimeSource 的名称
        key,
        // 唯一标识符
        account,
        // 账户配置
        categoryPageData,
        // 分类页面数据
        categoryAnimesData,
        // 分类动漫数据
        favoriteData,
        // 收藏数据
        explorePageData,
        // 探索页面数据
        searchData,
        // 搜索数据
        [],
        // 额外的参数，当前为空列表
        loadAnimeFunc,
        // 加载动漫的函数
        loadAnimePagesFunc,
        // 加载动漫页面的函数
        getImageLoadingConfigFunc,
        // 获取图片加载配置的函数
        getThumbnailLoadingConfigFunc,
        // 获取缩略图加载配置的函数
        matchBriefIdRegex,
        // 匹配简要 ID 的正则表达式
        filePath,
        // 配置文件路径
        url ?? "",
        // 可选的 URL，默认空字符串
        version ?? "1.0.0",
        // 版本号，默认 "1.0.0"
        commentsLoader,
        // 加载评论的函数
        sendCommentFunc); // 发送评论的函数

    // 异步加载 AnimeSource 的数据
    await source.loadData();

    // 延迟 50 毫秒后，调用 AnimeSource 的 init 方法进行初始化
    Future.delayed(const Duration(milliseconds: 50), () {
      JsEngine().runCode("AnimeSource.sources.$_key.init()");
    });

    // 返回创建和初始化完成的 AnimeSource 对象
    return source;
  }

  // 验证 _key 是否只包含字母、数字和下划线
  _checkKeyValidation() {
    // 仅允许数字和字母以及下划线
    if (!_key!.contains(RegExp(r"^[a-zA-Z0-9_]+$"))) {
      throw AnimeSourceParseException("key $_key is invalid");
    }
  }

  // 检查 AnimeSource.sources 中是否存在指定的 index 属性
  bool _checkExists(String index) {
    return JsEngine().runCode("AnimeSource.sources.$_key.$index !== null "
        "&& AnimeSource.sources.$_key.$index !== undefined");
  }

  // 获取 AnimeSource.sources 中指定 index 的值
  dynamic _getValue(String index) {
    return JsEngine().runCode("AnimeSource.sources.$_key.$index");
  }

  // 加载账户配置
  AccountConfig? _loadAccountConfig() {
    if (!_checkExists("account")) {
      return null;
    }

    // 定义一个异步的登录函数
    Future<Res<bool>> login(account, pwd) async {
      try {
        await JsEngine().runCode("""
          AnimeSource.sources.$_key.account.login(${jsonEncode(account)}, 
          ${jsonEncode(pwd)})
        """);
        // 查找并获取当前 AnimeSource
        var source =
            AnimeSource.sources.firstWhere((element) => element.key == _key);
        // 更新 source.data 中的账户信息
        source.data["account"] = <String>[account, pwd];
        source.saveData();
        return const Res(true);
      } catch (e, s) {
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString());
      }
    }

    // 定义一个注销函数
    void logout() {
      JsEngine().runCode("AnimeSource.sources.$_key.account.logout()");
    }

    // 创建并返回 AccountConfig 对象，包含登录、注销功能及相关网站信息
    return AccountConfig(login, _getValue("account.login.website"),
        _getValue("account.registerWebsite"), logout);
  }

  // 加载探索页面数据
  List<ExplorePageData> _loadExploreData() {
    // 检查 AnimeSource.sources[_key] 是否存在 "explore" 属性
    if (!_checkExists("explore")) {
      // 如果不存在，返回空的探索页面数据列表
      return const [];
    }

    // 获取探索页面的数量
    var length = JsEngine().runCode("AnimeSource.sources.$_key.explore.length");

    // 创建一个空的列表，用于存储探索页面数据
    var pages = <ExplorePageData>[];

    // 遍历每一个探索页面
    for (int i = 0; i < length; i++) {
      // 获取当前探索页面的标题
      final String title = _getValue("explore[$i].title");

      // 获取当前探索页面的类型
      final String type = _getValue("explore[$i].type");

      // 定义加载多部分数据的函数，默认为 null
      Future<Res<List<ExplorePagePart>>> Function()? loadMultiPart;

      // 定义加载页面数据的函数，默认为 null
      Future<Res<List<BaseAnime>>> Function(int page)? loadPage;

      // 根据探索页面的类型，定义不同的加载函数
      if (type == "singlePageWithMultiPart") {
        // 如果类型是单页多部分
        loadMultiPart = () async {
          try {
            // 运行 JavaScript 代码，调用 explore[i].load 方法，获取多部分数据
            var res = await JsEngine()
                .runCode("AnimeSource.sources.$_key.explore[$i].load()");

            // 将结果转换为 ExplorePagePart 列表
            return Res(List.from(res.keys
                .map((e) => ExplorePagePart(
                    e,
                    (res[e] as List)
                        .map<CustomAnime>((e) => CustomAnime.fromJson(e, _key!))
                        .toList(),
                    null))
                .toList()));
          } catch (e, s) {
            // 如果发生异常，记录错误日志
            log("$e\n$s", "Data Analysis", LogLevel.error);

            // 返回错误结果
            return Res.error(e.toString());
          }
        };
      } else if (type == "multiPageAnimeList") {
        // 如果类型是多页动漫列表
        loadPage = (int page) async {
          try {
            // 运行 JavaScript 代码，调用 explore[i].load(page) 方法，获取指定页的数据
            var res = await JsEngine().runCode(
                "AnimeSource.sources.$_key.explore[$i].load(${jsonEncode(page)})");

            // 将结果转换为 CustomAnime 列表，并获取最大页数
            return Res(
                List.generate(
                    res["animes"].length,
                    (index) =>
                        CustomAnime.fromJson(res["animes"][index], _key!)),
                subData: res["maxPage"]);
          } catch (e, s) {
            // 如果发生异常，记录错误日志
            log("$e\n$s", "Network", LogLevel.error);

            // 返回错误结果
            return Res.error(e.toString());
          }
        };
      }

      // 根据探索页面类型，创建 ExplorePageData 对象并添加到 pages 列表中
      pages.add(ExplorePageData(
          title, // 探索页面的标题
          switch (type) {
            "singlePageWithMultiPart" =>
              ExplorePageType.singlePageWithMultiPart, // 单页多部分类型
            "multiPageAnimeList" =>
              ExplorePageType.multiPageAnimeList, // 多页动漫列表类型
            _ => throw AnimeSourceParseException(
                "Unknown explore page type $type") // 未知类型，抛出异常
          },
          loadPage, // 加载页面数据的函数
          loadMultiPart // 加载多部分数据的函数
          ));
    }

    // 返回加载完成的探索页面数据列表
    return pages;
  }

  /// 从存储中加载类别数据。
  ///
  /// 返回一个 [CategoryData] 对象，如果无法找到标题，则返回 null。
  CategoryData? _loadCategoryData() {
    // 从存储中获取类别文档
    var doc = _getValue("category");

    // 如果文档没有标题，返回 null
    if (doc?["title"] == null) {
      return null;
    }

    // 提取标题和是否启用排名页面的标志
    final String title = doc["title"];
    final bool? enableRankingPage = doc["enableRankingPage"];

    // 用于存储类别部分的列表
    var categoryParts = <BaseCategoryPart>[];

    // 遍历文档中的类别部分
    for (var c in doc["parts"]) {
      // 提取类别部分的名称、类型、标签和项类型
      final String name = c["name"];
      final String type = c["type"];
      final List<String> tags = List.from(c["categories"]);
      final String itemType = c["itemType"];
      final List<String>? categoryParams =
          c["categoryParams"] == null ? null : List.from(c["categoryParams"]);

      // 根据类型创建相应的类别部分对象并添加到列表中
      if (type == "fixed") {
        categoryParts
            .add(FixedCategoryPart(name, tags, itemType, categoryParams));
      } else if (type == "random") {
        categoryParts.add(
            RandomCategoryPart(name, tags, c["randomNumber"] ?? 1, itemType));
      }
    }

    // 返回包含类别数据的对象
    return CategoryData(
        title: title,
        categories: categoryParts,
        enableRankingPage: enableRankingPage ?? false,
        key: title);
  }

  /// 从存储中加载类别动画数据。
  ///
  /// 返回一个 [CategoryAnimesData] 对象，如果类别动画未找到则返回 null。
  CategoryAnimesData? _loadCategoryAnimesData() {
    // 检查类别动画是否存在，如果不存在则返回 null
    if (!_checkExists("categoryAnimes")) return null;

    // 用于存储类别动画选项的列表
    var options = <CategoryAnimesOptions>[];

    // 遍历类别动画选项列表
    for (var element in _getValue("categoryAnimes.optionList")) {
      LinkedHashMap<String, String> map = LinkedHashMap<String, String>();

      // 提取选项中的键值对
      for (var option in element["options"]) {
        if (option.isEmpty || !option.contains("-")) {
          continue; // 跳过空选项或格式不正确的选项
        }
        var split = option.split("-");
        var key = split.removeAt(0); // 提取键
        var value = split.join("-"); // 提取值
        map[key] = value; // 将键值对添加到映射中
      }

      // 创建类别动画选项对象并添加到列表中
      options.add(CategoryAnimesOptions(
          map,
          List.from(element["notShowWhen"] ?? []),
          element["showWhen"] == null ? null : List.from(element["showWhen"])));
    }

    RankingData? rankingData;

    // 检查类别动画的排名数据
    if (_checkExists("categoryAnimes.ranking")) {
      var options = <String, String>{};

      // 提取排名选项中的键值对
      for (var option in _getValue("categoryAnimes.ranking.options")) {
        if (option.isEmpty || !option.contains("-")) {
          continue; // 跳过空选项或格式不正确的选项
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        options[key] = value; // 将键值对添加到映射中
      }

      // 创建排名数据对象
      rankingData = RankingData(options, (option, page) async {
        try {
          // 调用 JavaScript 引擎执行代码并获取排名数据
          var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.categoryAnimes.ranking.load(
            ${jsonEncode(option)}, ${jsonEncode(page)})
        """);

          // 返回成功结果
          return Res(
              List.generate(res["animes"].length,
                  (index) => CustomAnime.fromJson(res["animes"][index], _key!)),
              subData: res["maxPage"]);
        } catch (e, s) {
          // 捕获异常并记录错误
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString()); // 返回错误结果
        }
      });
    }

    // 返回类别动画数据对象
    return CategoryAnimesData(options, (category, param, options, page) async {
      try {
        // 调用 JavaScript 引擎执行代码并获取动画数据
        var res = await JsEngine().runCode("""
        AnimeSource.sources.$_key.categoryAnimes.load(
          ${jsonEncode(category)}, 
          ${jsonEncode(param)}, 
          ${jsonEncode(options)}, 
          ${jsonEncode(page)}
        )
      """);

        // 返回成功结果
        return Res(
            List.generate(res["animes"].length,
                (index) => CustomAnime.fromJson(res["animes"][index], _key!)),
            subData: res["maxPage"]);
      } catch (e, s) {
        // 捕获异常并记录错误
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString()); // 返回错误结果
      }
    }, rankingData: rankingData);
  }

  /// 从存储中加载搜索页面数据。
  ///
  /// 返回一个 [SearchPageData] 对象，如果搜索数据未找到则返回 null。
  SearchPageData? _loadSearchData() {
    // 检查搜索数据是否存在，如果不存在则返回 null
    if (!_checkExists("search")) return null;

    // 用于存储搜索选项的列表
    var options = <SearchOptions>[];

    // 遍历搜索选项列表
    for (var element in _getValue("search.optionList") ?? []) {
      LinkedHashMap<String, String> map = LinkedHashMap<String, String>();

      // 提取选项中的键值对
      for (var option in element["options"]) {
        if (option.isEmpty || !option.contains("-")) {
          continue; // 跳过空选项或格式不正确的选项
        }
        var split = option.split("-");
        var key = split.removeAt(0); // 提取键
        var value = split.join("-"); // 提取值
        map[key] = value; // 将键值对添加到映射中
      }

      // 创建搜索选项对象并添加到列表中
      options.add(SearchOptions(map, element["label"]));
    }

    // 返回包含搜索选项的数据对象
    return SearchPageData(options, (keyword, page, searchOption) async {
      try {
        // 调用 JavaScript 引擎执行代码并获取搜索结果
        var res = await JsEngine().runCode("""
        AnimeSource.sources.$_key.search.load(
          ${jsonEncode(keyword)}, ${jsonEncode(searchOption)}, ${jsonEncode(page)})
      """);

        // 返回成功结果
        return Res(
            List.generate(res["animes"].length,
                (index) => CustomAnime.fromJson(res["animes"][index], _key!)),
            subData: res["maxPage"]);
      } catch (e, s) {
        // 捕获异常并记录错误
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString()); // 返回错误结果
      }
    });
  }

  /// 解析加载动画信息的函数。
  ///
  /// 返回一个 [LoadAnimeFunc] 类型的异步函数，用于加载动画信息。
  LoadAnimeFunc? _parseLoadAnimeFunc() {
    return (id) async {
      try {
        // 调用 JavaScript 引擎执行代码并获取动画信息
        var res = await JsEngine().runCode("""
        AnimeSource.sources.$_key.anime.loadInfo(${jsonEncode(id)})
      """);

        // 提取标签信息
        var tags = <String, List<String>>{};
        (res["tags"] as Map<String, dynamic>?)
            ?.forEach((key, value) => tags[key] = List.from(value ?? const []));

        // 返回成功结果
        return Res(AnimeInfoData(
          res["title"],
          res["subTitle"],
          res["cover"],
          res["description"],
          tags,
          res["chapters"] == null ? null : Map.from(res["chapters"]),
          ListOrNull.from(res["thumbnails"]),
          null,
          res["thumbnailMaxPage"] ?? 1,
          (res["recommend"] as List?)
              ?.map((e) => CustomAnime.fromJson(e, _key!))
              .toList(),
          _key!,
          id,
          isFavorite: res["isFavorite"],
          subId: res["subId"],
        ));
      } catch (e, s) {
        // 捕获异常并记录错误
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString()); // 返回错误结果
      }
    };
  }

  /// 解析加载动画集数的函数。
  ///
  /// 返回一个 [LoadAnimePagesFunc] 类型的异步函数，用于加载动画集数。
  LoadAnimePagesFunc? _parseLoadAnimePagesFunc() {
    return (id, ep) async {
      try {
        // 调用 JavaScript 引擎执行代码并获取动画集数信息
        var res = await JsEngine().runCode("""
        AnimeSource.sources.$_key.anime.loadEp(${jsonEncode(id)}, ${jsonEncode(ep)})
      """);

        // 返回成功结果
        return Res(List.from(res["images"]));
      } catch (e, s) {
        // 捕获异常并记录错误
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString()); // 返回错误结果
      }
    };
  }

  /// 从存储中加载用户的收藏数据。
  ///
  /// 返回一个 [FavoriteData] 对象，如果收藏数据未找到则返回 null。
  FavoriteData? _loadFavoriteData() {
    // 检查收藏数据是否存在，如果不存在则返回 null
    if (!_checkExists("favorites")) return null;

    // 获取是否启用多文件夹功能的标志
    final bool multiFolder = _getValue("favorites.multiFolder");

    // 定义一个用于重试的函数
    Future<Res<T>> retryZone<T>(Future<Res<T>> Function() func) async {
      // 检查用户是否登录，如果未登录则返回错误
      if (!AnimeSource.find(_key!)!.isLogin) {
        return const Res.error("Not login");
      }

      // 调用传入的函数并获取结果
      var res = await func();

      // 检查结果是否有错误，并处理登录过期的情况
      if (res.error && res.errorMessage!.contains("Login expired")) {
        var reLoginRes = await AnimeSource.find(_key!)!.reLogin(); // 尝试重新登录
        if (!reLoginRes) {
          return const Res.error("Login expired and re-login failed");
        } else {
          return func(); // 重新调用函数以获取结果
        }
      }

      return res; // 返回结果
    }

    /// 添加或删除收藏夹中的动画。
    ///
    /// [animeId] 是动画的唯一标识符。
    /// [folderId] 是收藏夹的唯一标识符。
    /// [isAdding] 为 true 表示添加到收藏夹，为 false 表示从收藏夹中删除。
    Future<Res<bool>> addOrDelFavFunc(animeId, folderId, isAdding) async {
      // 定义一个内部函数，处理添加或删除收藏的逻辑
      Future<Res<bool>> func() async {
        try {
          // 调用 JavaScript 引擎执行代码以添加或删除收藏
          await JsEngine().runCode("""
        AnimeSource.sources.$_key.favorites.addOrDelFavorite(
          ${jsonEncode(animeId)}, ${jsonEncode(folderId)}, ${jsonEncode(isAdding)})
      """);
          return const Res(true); // 返回成功结果
        } catch (e, s) {
          // 捕获异常并记录错误
          log("$e\n$s", "Network", LogLevel.error);
          return Res<bool>.error(e.toString()); // 返回错误结果
        }
      }

      // 使用重试机制执行函数
      return retryZone(func);
    }

    /// 加载指定页面的动画列表。
    ///
    /// [page] 是要加载的页码，
    /// [folder] 是可选的收藏夹标识符，默认加载所有动画。
    Future<Res<List<BaseAnime>>> loadAnime(int page, [String? folder]) async {
      // 定义一个内部函数，处理加载动画的逻辑
      Future<Res<List<BaseAnime>>> func() async {
        try {
          // 调用 JavaScript 引擎执行代码以加载动画列表
          var res = await JsEngine().runCode("""
        AnimeSource.sources.$_key.favorites.loadAnimes(
          ${jsonEncode(page)}, ${jsonEncode(folder)})
      """);
          // 返回成功结果
          return Res(
              List.generate(res["animes"].length,
                  (index) => CustomAnime.fromJson(res["animes"][index], _key!)),
              subData: res["maxPage"]);
        } catch (e, s) {
          // 捕获异常并记录错误
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString()); // 返回错误结果
        }
      }

      // 使用重试机制执行函数
      return retryZone(func);
    }

    // 可选功能：加载收藏夹的函数，默认为 null
    Future<Res<Map<String, String>>> Function([String? animeId])? loadFolders;

    // 可选功能：添加收藏夹的函数，默认为 null
    Future<Res<bool>> Function(String name)? addFolder;

    // 可选功能：删除收藏夹的函数，默认为 null
    Future<Res<bool>> Function(String key)? deleteFolder;

    // 检查是否启用多文件夹功能
    if (multiFolder) {
      // 加载收藏夹的实现
      loadFolders = ([String? animeId]) async {
        Future<Res<Map<String, String>>> func() async {
          try {
            // 调用 JavaScript 引擎执行代码以加载收藏夹
            var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.favorites.loadFolders(${jsonEncode(animeId)})
        """);
            List<String>? subData;
            if (res["favorited"] != null) {
              subData = List.from(res["favorited"]); // 获取已收藏的动画
            }
            return Res(Map.from(res["folders"]),
                subData: subData); // 返回收藏夹和已收藏的动画
          } catch (e, s) {
            // 捕获异常并记录错误
            log("$e\n$s", "Network", LogLevel.error);
            return Res.error(e.toString()); // 返回错误结果
          }
        }

        // 使用重试机制执行函数
        return retryZone(func);
      };

      // 添加收藏夹的实现
      addFolder = (name) async {
        try {
          // 调用 JavaScript 引擎执行代码以添加收藏夹
          await JsEngine().runCode("""
        AnimeSource.sources.$_key.favorites.addFolder(${jsonEncode(name)})
      """);
          return const Res(true); // 返回成功结果
        } catch (e, s) {
          // 捕获异常并记录错误
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString()); // 返回错误结果
        }
      };

      // 删除收藏夹的实现
      deleteFolder = (key) async {
        try {
          // 调用 JavaScript 引擎执行代码以删除收藏夹
          await JsEngine().runCode("""
        AnimeSource.sources.$_key.favorites.deleteFolder(${jsonEncode(key)})
      """);
          return const Res(true); // 返回成功结果
        } catch (e, s) {
          // 捕获异常并记录错误
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString()); // 返回错误结果
        }
      };
    }

    // 创建并返回收藏数据对象
    return FavoriteData(
      key: _key!,
      title: _name!,
      multiFolder: multiFolder,
      loadAnime: loadAnime,
      loadFolders: loadFolders,
      addFolder: addFolder,
      deleteFolder: deleteFolder,
      addOrDelFavorite: addOrDelFavFunc,
    );
  }

  /// 解析并返回加载评论的功能。
  ///
  /// [id] 是动画的唯一标识符。
  /// [subId] 是子动画的唯一标识符。
  /// [page] 是要加载的评论页码。
  /// [replyTo] 是回复的评论 ID。
  CommentsLoader? _parseCommentsLoader() {
    // 检查是否存在加载评论的功能
    if (!_checkExists("anime.loadComments")) return null;

    // 返回一个加载评论的异步函数
    return (id, subId, page, replyTo) async {
      try {
        // 调用 JavaScript 引擎执行代码以加载评论
        var res = await JsEngine().runCode("""
        AnimeSource.sources.$_key.anime.loadComments(
          ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(page)}, ${jsonEncode(replyTo)})
      """);
        // 处理并返回评论数据
        return Res(
            (res["comments"] as List)
                .map((e) => Comment(e["userName"], e["avatar"], e["content"],
                    e["time"], e["replyCount"], e["id"].toString()))
                .toList(),
            subData: res["maxPage"]); // 返回最大页数
      } catch (e, s) {
        // 捕获异常并记录错误
        log("$e\n$s", "Network", LogLevel.error);
        return Res.error(e.toString()); // 返回错误结果
      }
    };
  }

  /// 解析并返回发送评论的功能。
  ///
  /// [id] 是动画的唯一标识符。
  /// [subId] 是子动画的唯一标识符。
  /// [content] 是评论内容。
  /// [replyTo] 是回复的评论 ID。
  SendCommentFunc? _parseSendCommentFunc() {
    // 检查是否存在发送评论的功能
    if (!_checkExists("anime.sendComment")) return null;

    // 返回一个发送评论的异步函数
    return (id, subId, content, replyTo) async {
      Future<Res<bool>> func() async {
        try {
          // 调用 JavaScript 引擎执行代码以发送评论
          await JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.sendComment(
            ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(content)}, ${jsonEncode(replyTo)})
        """);
          return const Res(true); // 返回成功结果
        } catch (e, s) {
          // 捕获异常并记录错误
          log("$e\n$s", "Network", LogLevel.error);
          return Res.error(e.toString()); // 返回错误结果
        }
      }

      // 执行发送评论的功能
      var res = await func();
      // 检查是否出现登录过期的错误
      if (res.error && res.errorMessage!.contains("Login expired")) {
        // 尝试重新登录
        var reLoginRes = await AnimeSource.find(_key!)!.reLogin();
        if (!reLoginRes) {
          return const Res.error("Login expired and re-login failed"); // 返回错误结果
        } else {
          return func(); // 重新发送评论
        }
      }
      return res; // 返回结果
    };
  }

  /// 解析并返回获取图像加载配置的功能。
  ///
  /// [imageKey] 是图像的唯一标识符。
  /// [animeId] 是动画的唯一标识符。
  /// [ep] 是集数标识符。
  GetImageLoadingConfigFunc? _parseImageLoadingConfigFunc() {
    // 检查是否存在获取图像加载配置的功能
    if (!_checkExists("anime.onImageLoad")) {
      return null;
    }
    // 返回一个获取图像加载配置的函数
    return (imageKey, animeId, ep) {
      return JsEngine().runCode("""
        AnimeSource.sources.$_key.anime.onImageLoad(
          ${jsonEncode(imageKey)}, ${jsonEncode(animeId)}, ${jsonEncode(ep)})
    """) as Map<String, dynamic>; // 返回配置
    };
  }

  /// 解析并返回获取缩略图加载配置的功能。
  ///
  /// [imageKey] 是缩略图的唯一标识符。
  GetThumbnailLoadingConfigFunc? _parseThumbnailLoadingConfigFunc() {
    // 检查是否存在获取缩略图加载配置的功能
    if (!_checkExists("anime.onThumbnailLoad")) {
      return null;
    }
    // 返回一个获取缩略图加载配置的函数
    return (imageKey) {
      var res = JsEngine().runCode("""
        AnimeSource.sources.$_key.anime.onThumbnailLoad(${jsonEncode(imageKey)})
    """);
      // 检查返回的数据类型是否有效
      if (res is! Map) {
        Log.error("Network", "function onThumbnailLoad return invalid data");
        throw "function onThumbnailLoad return invalid data"; // 抛出异常
      }
      return res as Map<String, dynamic>; // 返回配置
    };
  }
}
