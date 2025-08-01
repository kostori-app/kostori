part of 'anime_source.dart';

/// return true if ver1 > ver2
bool compareSemVer(String ver1, String ver2) {
  ver1 = ver1.replaceFirst("-", ".");
  ver2 = ver2.replaceFirst("-", ".");
  List<String> v1 = ver1.split('.');
  List<String> v2 = ver2.split('.');

  for (int i = 0; i < 3; i++) {
    int num1 = int.parse(v1[i]);
    int num2 = int.parse(v2[i]);

    if (num1 > num2) {
      return true;
    } else if (num1 < num2) {
      return false;
    }
  }

  var v14 = v1.elementAtOrNull(3);
  var v24 = v2.elementAtOrNull(3);

  if (v14 != v24) {
    if (v14 == null && v24 != "hotfix") {
      return true;
    } else if (v14 == null) {
      return false;
    }
    if (v24 == null) {
      if (v14 == "hotfix") {
        return true;
      }
      return false;
    }
    return v14.compareTo(v24) > 0;
  }

  return false;
}

class AnimeSourceParseException implements Exception {
  final String message;

  AnimeSourceParseException(this.message);

  @override
  String toString() {
    return message;
  }
}

class AnimeSourceParser {
  String? _key;

  String? _name;

  Future<AnimeSource> createAndParse(String js, String fileName) async {
    if (!fileName.endsWith("js")) {
      fileName = "$fileName.js";
    }
    var file = File(FilePath.join(App.dataPath, "anime_source", fileName));
    if (file.existsSync()) {
      int i = 0;
      while (file.existsSync()) {
        file = File(
          FilePath.join(
            App.dataPath,
            "anime_source",
            "${fileName.split('.').first}($i).js",
          ),
        );
        i++;
      }
    }
    await file.writeAsString(js);
    try {
      return await parse(js, file.path);
    } catch (e) {
      await file.delete();
      rethrow;
    }
  }

  Future<AnimeSource> parse(String js, String filePath) async {
    js = js.replaceAll("\r\n", "\n");
    var line1 = js
        .split('\n')
        .firstWhereOrNull((e) => e.trim().startsWith("class "));
    if (line1 == null ||
        !line1.startsWith("class ") ||
        !line1.contains("extends AnimeSource")) {
      throw AnimeSourceParseException("Invalid Content");
    }
    var className = line1.split("class")[1].split("extends AnimeSource").first;
    className = className.trim();
    JsEngine().runCode("""
      (() => {
        $js
        this['temp'] = new $className()
      }).call()
    """, className);
    _name =
        JsEngine().runCode("this['temp'].name") ??
        (throw AnimeSourceParseException('name is required'));
    var key =
        JsEngine().runCode("this['temp'].key") ??
        (throw AnimeSourceParseException('key is required'));
    var version =
        JsEngine().runCode("this['temp'].version") ??
        (throw AnimeSourceParseException('version is required'));
    var minAppVersion = JsEngine().runCode("this['temp'].minAppVersion");
    var url = JsEngine().runCode("this['temp'].url");
    if (minAppVersion != null) {
      if (compareSemVer(minAppVersion, App.version.split('-').first)) {
        throw AnimeSourceParseException(
          "minAppVersion @version is required".tlParams({
            "version": minAppVersion,
          }),
        );
      }
    }
    for (var source in AnimeSource.all()) {
      if (source.key == key) {
        throw AnimeSourceParseException("key($key) already exists");
      }
    }
    _key = key;
    _checkKeyValidation();

    JsEngine().runCode("""
      AnimeSource.sources.$_key = this['temp']; 
    """);

    var source = AnimeSource(
      _name!,
      key,
      _loadAccountConfig(),
      _loadCategoryData(),
      _loadCategoryAnimesData(),
      _loadFavoriteData(),
      _loadExploreData(),
      _loadSearchData(),
      _parseSettings(),
      _parseLoadAnimeFunc(),
      _parseThumbnailLoader(),
      _parseLoadAnimePagesFunc(),
      _parseImageLoadingConfigFunc(),
      _parseThumbnailLoadingConfigFunc(),
      filePath,
      url ?? "",
      version ?? "1.0.0",
      _parseCommentsLoader(),
      _parseSendCommentFunc(),
      _parseLikeFunc(),
      _parseVoteCommentFunc(),
      _parseLikeCommentFunc(),
      _parseIdMatch(),
      _parseTranslation(),
      _parseClickTagEvent(),
      _parseLinkHandler(),
      _getValue("search.enableTagsSuggestions") ?? false,
      _getValue("anime.enableTagsTranslate") ?? false,
      _parseStarRatingFunc(),
    );

    await source.loadData();

    if (_checkExists("init")) {
      Future.delayed(const Duration(milliseconds: 50), () {
        JsEngine().runCode("AnimeSource.sources.$_key.init()");
      });
    }

    return source;
  }

  _checkKeyValidation() {
    // 仅允许数字和字母以及下划线
    if (!_key!.contains(RegExp(r"^[a-zA-Z0-9_]+$"))) {
      throw AnimeSourceParseException("key $_key is invalid");
    }
  }

  bool _checkExists(String index) {
    return JsEngine().runCode(
      "AnimeSource.sources.$_key.$index !== null "
      "&& AnimeSource.sources.$_key.$index !== undefined",
    );
  }

  dynamic _getValue(String index) {
    return JsEngine().runCode("AnimeSource.sources.$_key.$index");
  }

  AccountConfig? _loadAccountConfig() {
    if (!_checkExists("account")) {
      return null;
    }

    Future<Res<bool>> Function(String account, String pwd)? login;

    if (_checkExists("account.login")) {
      login = (account, pwd) async {
        try {
          await JsEngine().runCode("""
          AnimeSource.sources.$_key.account.login(${jsonEncode(account)}, 
          ${jsonEncode(pwd)})
        """);
          var source = AnimeSource.find(_key!)!;
          source.data["account"] = <String>[account, pwd];
          source.saveData();
          return const Res(true);
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res.error(e.toString());
        }
      };
    }

    void logout() {
      JsEngine().runCode("AnimeSource.sources.$_key.account.logout()");
    }

    bool Function(String url, String title)? checkLoginStatus;

    void Function()? onLoginSuccess;

    if (_checkExists('account.loginWithWebview')) {
      checkLoginStatus = (url, title) {
        return JsEngine().runCode("""
            AnimeSource.sources.$_key.account.loginWithWebview.checkStatus(
              ${jsonEncode(url)}, ${jsonEncode(title)})
          """);
      };

      if (_checkExists('account.loginWithWebview.onLoginSuccess')) {
        onLoginSuccess = () {
          JsEngine().runCode("""
            AnimeSource.sources.$_key.account.loginWithWebview.onLoginSuccess()
          """);
        };
      }
    }

    Future<bool> Function(List<String>)? validateCookies;

    if (_checkExists('account.loginWithCookies?.validate')) {
      validateCookies = (cookies) async {
        try {
          var res = await JsEngine().runCode("""
            AnimeSource.sources.$_key.account.loginWithCookies.validate(${jsonEncode(cookies)})
          """);
          return res;
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return false;
        }
      };
    }

    return AccountConfig(
      login,
      _getValue("account.loginWithWebview?.url"),
      _getValue("account.registerWebsite"),
      logout,
      checkLoginStatus,
      onLoginSuccess,
      ListOrNull.from(_getValue("account.loginWithCookies?.fields")),
      validateCookies,
    );
  }

  List<ExplorePageData> _loadExploreData() {
    if (!_checkExists("explore")) {
      return const [];
    }
    var length = JsEngine().runCode("AnimeSource.sources.$_key.explore.length");
    var pages = <ExplorePageData>[];
    for (int i = 0; i < length; i++) {
      final String title = _getValue("explore[$i].title");
      final String type = _getValue("explore[$i].type");
      Future<Res<List<ExplorePagePart>>> Function()? loadMultiPart;
      Future<Res<List<Anime>>> Function(int page)? loadPage;
      Future<Res<List<Anime>>> Function(String? next)? loadNext;
      Future<Res<List<Object>>> Function(int index)? loadMixed;
      if (type == "singlePageWithMultiPart") {
        loadMultiPart = () async {
          try {
            var res = await JsEngine().runCode(
              "AnimeSource.sources.$_key.explore[$i].load()",
            );
            return Res(
              List.from(
                res.keys
                    .map(
                      (e) => ExplorePagePart(
                        e,
                        (res[e] as List)
                            .map<Anime>((e) => Anime.fromJson(e, _key!))
                            .toList(),
                        null,
                      ),
                    )
                    .toList(),
              ),
            );
          } catch (e, s) {
            Log.error("Data Analysis", "$e\n$s");
            return Res.error(e.toString());
          }
        };
      } else if (type == "multiPageAnimeList") {
        if (_checkExists("explore[$i].load")) {
          loadPage = (int page) async {
            try {
              var res = await JsEngine().runCode(
                "AnimeSource.sources.$_key.explore[$i].load(${jsonEncode(page)})",
              );
              return Res(
                List.generate(
                  res["animes"].length,
                  (index) => Anime.fromJson(res["animes"][index], _key!),
                ),
                subData: res["maxPage"],
              );
            } catch (e, s) {
              Log.error("Network", "$e\n$s");
              return Res.error(e.toString());
            }
          };
        } else {
          loadNext = (next) async {
            try {
              var res = await JsEngine().runCode(
                "AnimeSource.sources.$_key.explore[$i].loadNext(${jsonEncode(next)})",
              );
              return Res(
                List.generate(
                  res["animes"].length,
                  (index) => Anime.fromJson(res["animes"][index], _key!),
                ),
                subData: res["next"],
              );
            } catch (e, s) {
              Log.error("Network", "$e\n$s");
              return Res.error(e.toString());
            }
          };
        }
      } else if (type == "multiPartPage") {
        loadMultiPart = () async {
          try {
            var res = await JsEngine().runCode(
              "AnimeSource.sources.$_key.explore[$i].load()",
            );
            return Res(
              List.from(
                (res as List).map((e) {
                  return ExplorePagePart(
                    e['title'],
                    (e['animes'] as List).map((e) {
                      return Anime.fromJson(e, _key!);
                    }).toList(),
                    PageJumpTarget.parse(_key!, e['viewMore']),
                  );
                }),
              ),
            );
          } catch (e, s) {
            Log.error("Data Analysis", "$e\n$s");
            return Res.error(e.toString());
          }
        };
      } else if (type == 'mixed') {
        loadMixed = (index) async {
          try {
            var res = await JsEngine().runCode(
              "AnimeSource.sources.$_key.explore[$i].load(${jsonEncode(index)})",
            );
            var list = <Object>[];
            for (var data in (res['data'] as List)) {
              if (data is List) {
                list.add(data.map((e) => Anime.fromJson(e, _key!)).toList());
              } else if (data is Map) {
                list.add(
                  ExplorePagePart(
                    data['title'],
                    (data['animes'] as List).map((e) {
                      return Anime.fromJson(e, _key!);
                    }).toList(),
                    data['viewMore'],
                  ),
                );
              }
            }
            return Res(list, subData: res['maxPage']);
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        };
      }
      pages.add(
        ExplorePageData(
          title,
          switch (type) {
            "singlePageWithMultiPart" =>
              ExplorePageType.singlePageWithMultiPart,
            "multiPartPage" => ExplorePageType.singlePageWithMultiPart,
            "multiPageAnimeList" => ExplorePageType.multiPageAnimeList,
            "mixed" => ExplorePageType.mixed,
            _ => throw AnimeSourceParseException(
              "Unknown explore page type $type",
            ),
          },
          loadPage,
          loadNext,
          loadMultiPart,
          loadMixed,
        ),
      );
    }
    return pages;
  }

  CategoryData? _loadCategoryData() {
    var doc = _getValue("category");

    if (doc?["title"] == null) {
      return null;
    }

    final String title = doc["title"];
    final bool? enableRankingPage = doc["enableRankingPage"];

    var categoryParts = <BaseCategoryPart>[];

    for (var c in doc["parts"]) {
      final String name = c["name"];
      final String type = c["type"];
      final List<String> tags = List.from(c["categories"]);
      final String itemType = c["itemType"];
      List<String>? categoryParams = ListOrNull.from(c["categoryParams"]);
      final String? groupParam = c["groupParam"];
      if (groupParam != null) {
        categoryParams = List.filled(tags.length, groupParam);
      }
      if (type == "fixed") {
        categoryParts.add(
          FixedCategoryPart(name, tags, itemType, categoryParams),
        );
      } else if (type == "random") {
        categoryParts.add(
          RandomCategoryPart(name, tags, c["randomNumber"] ?? 1, itemType),
        );
      }
    }

    return CategoryData(
      title: title,
      categories: categoryParts,
      enableRankingPage: enableRankingPage ?? false,
      key: title,
    );
  }

  CategoryAnimesData? _loadCategoryAnimesData() {
    if (!_checkExists("categoryAnimes")) return null;
    var options = <CategoryAnimesOptions>[];
    for (var element in _getValue("categoryAnimes.optionList") ?? []) {
      LinkedHashMap<String, String> map = LinkedHashMap<String, String>();
      for (var option in element["options"]) {
        if (option.isEmpty || !option.contains("-")) {
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        map[key] = value;
      }
      options.add(
        CategoryAnimesOptions(
          map,
          List.from(element["notShowWhen"] ?? []),
          element["showWhen"] == null ? null : List.from(element["showWhen"]),
        ),
      );
    }
    RankingData? rankingData;
    if (_checkExists("categoryAnimes.ranking")) {
      var options = <String, String>{};
      for (var option in _getValue("categoryAnimes.ranking.options")) {
        if (option.isEmpty || !option.contains("-")) {
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        options[key] = value;
      }
      Future<Res<List<Anime>>> Function(String option, int page)? load;
      Future<Res<List<Anime>>> Function(String option, String? next)?
      loadWithNext;
      if (_checkExists("categoryAnimes.ranking.load")) {
        load = (option, page) async {
          try {
            var res = await JsEngine().runCode("""
            AnimeSource.sources.$_key.categoryAnimes.ranking.load(
              ${jsonEncode(option)}, ${jsonEncode(page)})
          """);
            return Res(
              List.generate(
                res["animes"].length,
                (index) => Anime.fromJson(res["animes"][index], _key!),
              ),
              subData: res["maxPage"],
            );
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        };
      } else {
        loadWithNext = (option, next) async {
          try {
            var res = await JsEngine().runCode("""
            AnimeSource.sources.$_key.categoryAnimes.ranking.loadWithNext(
              ${jsonEncode(option)}, ${jsonEncode(next)})
          """);
            return Res(
              List.generate(
                res["animes"].length,
                (index) => Anime.fromJson(res["animes"][index], _key!),
              ),
              subData: res["next"],
            );
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        };
      }
      rankingData = RankingData(options, load, loadWithNext);
    }
    return CategoryAnimesData(options, (category, param, options, page) async {
      try {
        var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.categoryAnimes.load(
            ${jsonEncode(category)}, 
            ${jsonEncode(param)}, 
            ${jsonEncode(options)}, 
            ${jsonEncode(page)}
          )
        """);
        return Res(
          List.generate(
            res["animes"].length,
            (index) => Anime.fromJson(res["animes"][index], _key!),
          ),
          subData: res["maxPage"],
        );
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    }, rankingData: rankingData);
  }

  SearchPageData? _loadSearchData() {
    if (!_checkExists("search")) return null;
    var options = <SearchOptions>[];
    for (var element in _getValue("search.optionList") ?? []) {
      LinkedHashMap<String, String> map = LinkedHashMap<String, String>();
      for (var option in element["options"]) {
        if (option.isEmpty || !option.contains("-")) {
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        map[key] = value;
      }
      options.add(
        SearchOptions(
          map,
          element["label"],
          element['type'] ?? 'select',
          element['default'] == null ? null : jsonEncode(element['default']),
        ),
      );
    }

    SearchFunction? loadPage;

    SearchNextFunction? loadNext;

    if (_checkExists('search.load')) {
      loadPage = (keyword, page, searchOption) async {
        try {
          var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.search.load(
            ${jsonEncode(keyword)}, ${jsonEncode(searchOption)}, ${jsonEncode(page)})
        """);
          return Res(
            List.generate(
              res["animes"].length,
              (index) => Anime.fromJson(res["animes"][index], _key!),
            ),
            subData: res["maxPage"],
          );
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res.error(e.toString());
        }
      };
    } else {
      loadNext = (keyword, next, searchOption) async {
        try {
          var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.search.loadNext(
            ${jsonEncode(keyword)}, ${jsonEncode(searchOption)}, ${jsonEncode(next)})
        """);
          return Res(
            List.generate(
              res["animes"].length,
              (index) => Anime.fromJson(res["animes"][index], _key!),
            ),
            subData: res["next"],
          );
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res.error(e.toString());
        }
      };
    }

    return SearchPageData(options, loadPage, loadNext);
  }

  LoadAnimeFunc? _parseLoadAnimeFunc() {
    return (id) async {
      try {
        var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.loadInfo(${jsonEncode(id)})
        """);
        if (res is! Map<String, dynamic>) throw "Invalid data";
        res['animeId'] = id;
        res['sourceKey'] = _key;
        return Res(AnimeDetails.fromJson(res));
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  LoadAnimePagesFunc? _parseLoadAnimePagesFunc() {
    return (id, ep) async {
      try {
        var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.loadEp(${jsonEncode(id)}, ${jsonEncode(ep)})
        """);
        return res;
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  FavoriteData? _loadFavoriteData() {
    if (!_checkExists("favorites")) return null;

    final bool multiFolder = _getValue("favorites.multiFolder");
    final bool? isOldToNewSort = _getValue("favorites.isOldToNewSort");

    Future<Res<T>> retryZone<T>(Future<Res<T>> Function() func) async {
      if (!AnimeSource.find(_key!)!.isLogged) {
        return const Res.error("Not login");
      }
      var res = await func();
      if (res.error && res.errorMessage!.contains("Login expired")) {
        var reLoginRes = await AnimeSource.find(_key!)!.reLogin();
        if (!reLoginRes) {
          return const Res.error("Login expired and re-login failed");
        } else {
          return func();
        }
      }
      return res;
    }

    Future<Res<bool>> addOrDelFavFunc(
      String animeId,
      String folderId,
      bool isAdding,
      String? favId,
    ) async {
      func() async {
        try {
          await JsEngine().runCode("""
            AnimeSource.sources.$_key.favorites.addOrDelFavorite(
              ${jsonEncode(animeId)}, ${jsonEncode(folderId)}, ${jsonEncode(isAdding)})
          """);
          return const Res(true);
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res<bool>.error(e.toString());
        }
      }

      return retryZone(func);
    }

    Future<Res<List<Anime>>> Function(int page, [String? folder])? loadAnime;

    Future<Res<List<Anime>>> Function(String? next, [String? folder])? loadNext;

    if (_checkExists("favorites.loadAnimes")) {
      loadAnime = (int page, [String? folder]) async {
        Future<Res<List<Anime>>> func() async {
          try {
            var res = await JsEngine().runCode("""
            AnimeSource.sources.$_key.favorites.loadAnimes(
              ${jsonEncode(page)}, ${jsonEncode(folder)})
          """);
            return Res(
              List.generate(
                res["animes"].length,
                (index) => Anime.fromJson(res["animes"][index], _key!),
              ),
              subData: res["maxPage"],
            );
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        }

        return retryZone(func);
      };
    }

    if (_checkExists("favorites.loadNext")) {
      loadNext = (String? next, [String? folder]) async {
        Future<Res<List<Anime>>> func() async {
          try {
            var res = await JsEngine().runCode("""
            AnimeSource.sources.$_key.favorites.loadNext(
              ${jsonEncode(next)}, ${jsonEncode(folder)})
          """);
            return Res(
              List.generate(
                res["animes"].length,
                (index) => Anime.fromJson(res["animes"][index], _key!),
              ),
              subData: res["next"],
            );
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        }

        return retryZone(func);
      };
    }

    Future<Res<Map<String, String>>> Function([String? animeId])? loadFolders;

    Future<Res<bool>> Function(String name)? addFolder;

    Future<Res<bool>> Function(String key)? deleteFolder;

    if (multiFolder) {
      loadFolders = ([String? animeId]) async {
        Future<Res<Map<String, String>>> func() async {
          try {
            var res = await JsEngine().runCode("""
            AnimeSource.sources.$_key.favorites.loadFolders(${jsonEncode(animeId)})
          """);
            List<String>? subData;
            if (res["favorited"] != null) {
              subData = List.from(res["favorited"]);
            }
            return Res(Map.from(res["folders"]), subData: subData);
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        }

        return retryZone(func);
      };
      if (_checkExists("favorites.addFolder")) {
        addFolder = (name) async {
          try {
            await JsEngine().runCode("""
            AnimeSource.sources.$_key.favorites.addFolder(${jsonEncode(name)})
          """);
            return const Res(true);
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        };
      }
      if (_checkExists("favorites.deleteFolder")) {
        deleteFolder = (key) async {
          try {
            await JsEngine().runCode("""
            AnimeSource.sources.$_key.favorites.deleteFolder(${jsonEncode(key)})
          """);
            return const Res(true);
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        };
      }
    }

    return FavoriteData(
      key: _key!,
      title: _name!,
      multiFolder: multiFolder,
      loadAnime: loadAnime,
      loadNext: loadNext,
      loadFolders: loadFolders,
      addFolder: addFolder,
      deleteFolder: deleteFolder,
      addOrDelFavorite: addOrDelFavFunc,
      isOldToNewSort: isOldToNewSort,
    );
  }

  CommentsLoader? _parseCommentsLoader() {
    if (!_checkExists("anime.loadComments")) return null;
    return (id, subId, page, replyTo) async {
      try {
        var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.loadComments(
            ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(page)}, ${jsonEncode(replyTo)})
        """);
        return Res(
          (res["comments"] as List).map((e) => Comment.fromJson(e)).toList(),
          subData: res["maxPage"],
        );
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  SendCommentFunc? _parseSendCommentFunc() {
    if (!_checkExists("anime.sendComment")) return null;
    return (id, subId, content, replyTo) async {
      Future<Res<bool>> func() async {
        try {
          await JsEngine().runCode("""
            AnimeSource.sources.$_key.anime.sendComment(
              ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(content)}, ${jsonEncode(replyTo)})
          """);
          return const Res(true);
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res.error(e.toString());
        }
      }

      var res = await func();
      if (res.error && res.errorMessage!.contains("Login expired")) {
        var reLoginRes = await AnimeSource.find(_key!)!.reLogin();
        if (!reLoginRes) {
          return const Res.error("Login expired and re-login failed");
        } else {
          return func();
        }
      }
      return res;
    };
  }

  GetImageLoadingConfigFunc? _parseImageLoadingConfigFunc() {
    if (!_checkExists("anime.onImageLoad")) {
      return null;
    }
    return (imageKey, animeId, ep) async {
      var res = JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.onImageLoad(
            ${jsonEncode(imageKey)}, ${jsonEncode(animeId)}, ${jsonEncode(ep)})
        """);
      if (res is Future) {
        return await res;
      }
      return res;
    };
  }

  GetThumbnailLoadingConfigFunc? _parseThumbnailLoadingConfigFunc() {
    if (!_checkExists("anime.onThumbnailLoad")) {
      return null;
    }
    return (imageKey) {
      var res = JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.onThumbnailLoad(${jsonEncode(imageKey)})
        """);
      if (res is! Map) {
        Log.error("Network", "function onThumbnailLoad return invalid data");
        throw "function onThumbnailLoad return invalid data";
      }
      return res as Map<String, dynamic>;
    };
  }

  AnimeThumbnailLoader? _parseThumbnailLoader() {
    if (!_checkExists("anime.loadThumbnails")) {
      return null;
    }
    return (id, next) async {
      try {
        var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.loadThumbnails(${jsonEncode(id)}, ${jsonEncode(next)})
        """);
        return Res(List<String>.from(res['thumbnails']), subData: res['next']);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  LikeOrUnlikeAnimeFunc? _parseLikeFunc() {
    if (!_checkExists("anime.likeAnime")) {
      return null;
    }
    return (id, isLiking) async {
      try {
        await JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.likeAnime(${jsonEncode(id)}, ${jsonEncode(isLiking)})
        """);
        return const Res(true);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  VoteCommentFunc? _parseVoteCommentFunc() {
    if (!_checkExists("anime.voteComment")) {
      return null;
    }
    return (id, subId, commentId, isUp, isCancel) async {
      try {
        var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.voteComment(${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(commentId)}, ${jsonEncode(isUp)}, ${jsonEncode(isCancel)})
        """);
        return Res(res is num ? res.toInt() : 0);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  LikeCommentFunc? _parseLikeCommentFunc() {
    if (!_checkExists("anime.likeComment")) {
      return null;
    }
    return (id, subId, commentId, isLiking) async {
      try {
        var res = await JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.likeComment(${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(commentId)}, ${jsonEncode(isLiking)})
        """);
        return Res(res is num ? res.toInt() : 0);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  Map<String, Map<String, dynamic>> _parseSettings() {
    var value = _getValue("settings");
    if (value is Map) {
      var newMap = <String, Map<String, dynamic>>{};
      for (var e in value.entries) {
        if (e.key is! String) {
          continue;
        }
        var v = <String, dynamic>{};
        for (var e2 in e.value.entries) {
          if (e2.key is! String) {
            continue;
          }
          var v2 = e2.value;
          if (v2 is JSInvokable) {
            v2 = JSAutoFreeFunction(v2);
          }
          v[e2.key] = v2;
        }
        newMap[e.key] = v;
      }
      return newMap;
    }
    return {};
  }

  RegExp? _parseIdMatch() {
    if (!_checkExists("anime.idMatch")) {
      return null;
    }
    return RegExp(_getValue("anime.idMatch"));
  }

  Map<String, Map<String, String>>? _parseTranslation() {
    if (!_checkExists("translation")) {
      return null;
    }
    var data = _getValue("translation");
    var res = <String, Map<String, String>>{};
    for (var e in data.entries) {
      res[e.key] = Map<String, String>.from(e.value);
    }
    return res;
  }

  HandleClickTagEvent? _parseClickTagEvent() {
    if (!_checkExists("anime.onClickTag")) {
      return null;
    }
    return (namespace, tag) {
      var res = JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.onClickTag(${jsonEncode(namespace)}, ${jsonEncode(tag)})
        """);
      var r = Map<String, String?>.from(res);
      r.removeWhere((key, value) => value == null);
      return Map.from(r);
    };
  }

  LinkHandler? _parseLinkHandler() {
    if (!_checkExists("anime.link")) {
      return null;
    }
    List<String> domains = List.from(_getValue("anime.link.domains"));
    linkToId(String link) {
      var res = JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.link.linkToId(${jsonEncode(link)})
        """);
      return res as String?;
    }

    return LinkHandler(domains, linkToId);
  }

  StarRatingFunc? _parseStarRatingFunc() {
    if (!_checkExists("anime.starRating")) {
      return null;
    }
    return (id, rating) async {
      try {
        await JsEngine().runCode("""
          AnimeSource.sources.$_key.anime.starRating(${jsonEncode(id)}, ${jsonEncode(rating)})
        """);
        return const Res(true);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }
}
