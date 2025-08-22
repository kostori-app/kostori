part of 'anime_source.dart';

class Comment {
  final String userName;
  final String? avatar;
  final String content;
  final String? time;
  final int? replyCount;
  final String? id;
  int? score;
  final bool? isLiked;
  int? voteStatus; // 1: upvote, -1: downvote, 0: none

  static String? parseTime(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      if (value < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(
          value * 1000,
        ).toString().substring(0, 19);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(
          value,
        ).toString().substring(0, 19);
      }
    }
    return value.toString();
  }

  Comment.fromJson(Map<String, dynamic> json)
    : userName = json["userName"],
      avatar = json["avatar"],
      content = json["content"],
      time = parseTime(json["time"]),
      replyCount = json["replyCount"],
      id = json["id"].toString(),
      score = json["score"],
      isLiked = json["isLiked"],
      voteStatus = json["voteStatus"];
}

class Anime {
  final String title;

  final String cover;

  final String id;

  final String? subtitle;

  final List<String>? tags;

  final String description;

  final String sourceKey;

  final String? language;

  final String? favoriteId;

  /// 0-5
  final double? stars;

  final PageJumpTarget? viewMore;

  const Anime(
    this.title,
    this.cover,
    this.id,
    this.subtitle,
    this.tags,
    this.description,
    this.sourceKey,
    this.language,
    this.viewMore,
  ) : favoriteId = null,
      stars = null;

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "cover": cover,
      "id": id,
      "subtitle": subtitle,
      "tags": tags,
      "description": description,
      "sourceKey": sourceKey,
      "language": language,
      "favoriteId": favoriteId,
      "viewMore": viewMore,
    };
  }

  Anime.fromJson(Map<String, dynamic> json, this.sourceKey)
    : title = json["title"],
      subtitle = json["subtitle"] ?? "",
      cover = json["cover"],
      id = json["id"],
      tags = List<String>.from(json["tags"] ?? []),
      description = json["description"] ?? "",
      language = json["language"],
      favoriteId = json["favoriteId"],
      stars = (json["stars"] as num?)?.toDouble(),
      viewMore = PageJumpTarget.parse(sourceKey, json["viewMore"]);

  @override
  bool operator ==(Object other) {
    if (other is! Anime) return false;
    return other.id == id && other.sourceKey == sourceKey;
  }

  @override
  int get hashCode => id.hashCode ^ sourceKey.hashCode;

  @override
  toString() => "$sourceKey@$id";
}

class AnimeID {
  final AnimeType type;

  final String id;

  const AnimeID(this.type, this.id);

  @override
  bool operator ==(Object other) {
    if (other is! AnimeID) return false;
    return other.type == type && other.id == id;
  }

  @override
  int get hashCode => type.hashCode ^ id.hashCode;

  @override
  String toString() => "$type@$id";
}

class AnimeDetails with HistoryMixin {
  @override
  final String title;

  @override
  final String? subTitle;

  @override
  final String cover;

  final String? description;

  final Map<String, List<String>> tags;

  /// id-name
  // final Map<String, String>? episode;

  final Map<String, Map<String, String>>? episode;

  final List<String>? thumbnails;

  final List<Anime>? recommend;

  final String sourceKey;

  final String animeId;

  final bool? isFavorite;

  final String? subId;

  final bool? isLiked;

  final int? likesCount;

  final int? commentsCount;

  final String? uploader;

  final String? uploadTime;

  final String? updateTime;

  final String? url;

  final double? stars;

  static Map<String, List<String>> _generateMap(Map<dynamic, dynamic> map) {
    var res = <String, List<String>>{};
    map.forEach((key, value) {
      if (value is List) {
        res[key] = List<String>.from(value);
      }
    });
    return res;
  }

  static Map<String, Map<String, String>> _generateNestedMap(
    Map<dynamic, dynamic> map,
  ) {
    var res = <String, Map<String, String>>{};
    map.forEach((key, value) {
      res[key] = Map<String, String>.from(value as Map<dynamic, dynamic>);
    });
    return res;
  }

  AnimeDetails.fromJson(Map<String, dynamic> json)
    : title = json["title"],
      subTitle = json["subtitle"],
      cover = json["cover"],
      description = json["description"],
      tags = _generateMap(json["tags"]),
      episode = _generateNestedMap(json["episode"]),
      sourceKey = json["sourceKey"],
      animeId = json["animeId"],
      thumbnails = ListOrNull.from(json["thumbnails"]),
      recommend = (json["recommend"] as List?)
          ?.map((e) => Anime.fromJson(e, json["sourceKey"]))
          .toList(),
      isFavorite = json["isFavorite"],
      subId = json["subId"],
      likesCount = json["likesCount"],
      isLiked = json["isLiked"],
      commentsCount = json["commentsCount"],
      uploader = json["uploader"],
      uploadTime = json["uploadTime"],
      updateTime = json["updateTime"],
      url = json["url"],
      stars = (json["stars"] as num?)?.toDouble();

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "subtitle": subTitle,
      "cover": cover,
      "description": description,
      "tags": tags,
      "episode": episode,
      "thumbnails": thumbnails,
      "recommend": null,
      "sourceKey": sourceKey,
      "animeId": animeId,
      "isFavorite": isFavorite,
      "subId": subId,
      "isLiked": isLiked,
      "likesCount": likesCount,
      "commentsCount": commentsCount,
      "uploader": uploader,
      "uploadTime": uploadTime,
      "updateTime": updateTime,
      "url": url,
    };
  }

  @override
  HistoryType get historyType => HistoryType(sourceKey.hashCode);

  @override
  String get id => animeId;

  AnimeType get animeType => AnimeType(sourceKey.hashCode);

  @override
  PageJumpTarget? get viewMore => null;
}

class PageJumpTarget {
  final String sourceKey;

  final String page;

  final Map<String, dynamic>? attributes;

  const PageJumpTarget(this.sourceKey, this.page, this.attributes);

  static PageJumpTarget parse(String sourceKey, dynamic value) {
    if (value is Map) {
      if (value['page'] != null) {
        return PageJumpTarget(
          sourceKey,
          value["page"] ?? "search",
          value["attributes"],
        );
      } else if (value["action"] != null) {
        // old version `onClickTag`
        var page = value["action"];
        if (page == "search") {
          return PageJumpTarget(sourceKey, "search", {
            "text": value["keyword"],
          });
        } else if (page == "category") {
          return PageJumpTarget(sourceKey, "category", {
            "category": value["keyword"],
            "param": value["param"],
          });
        } else {
          return PageJumpTarget(sourceKey, page, null);
        }
      }
    } else if (value is String) {
      // old version string encoding. search: `search:keyword`, category: `category:keyword` or `category:keyword@param`
      var segments = value.split(":");
      var page = segments[0];
      if (page == "search") {
        return PageJumpTarget(sourceKey, "search", {"text": segments[1]});
      } else if (page == "category") {
        var c = segments[1];
        if (c.contains('@')) {
          var parts = c.split('@');
          var param = value.split("@");
          return PageJumpTarget(sourceKey, "category", {
            "category": parts[0],
            "param": param[1],
          });
        } else {
          return PageJumpTarget(sourceKey, "category", {"category": c});
        }
      } else {
        return PageJumpTarget(sourceKey, page, null);
      }
    }
    return PageJumpTarget(sourceKey, "Invalid Data", null);
  }

  void jump(BuildContext context) {
    if (page == "search") {
      context.to(
        () => SearchResultPage(
          text: attributes?["text"] ?? attributes?["keyword"] ?? "",
          sourceKey: sourceKey,
          options: List.from(attributes?["options"] ?? []),
        ),
      );
    } else if (page == "category") {
      var key = AnimeSource.find(sourceKey)!.categoryData!.key;
      context.to(
        () => CategoryAnimesPage(
          categoryKey: key,
          category:
              attributes?["category"] ??
              (throw ArgumentError("Category name is required")),
          options: List.from(attributes?["options"] ?? []),
          param: attributes?["param"],
        ),
      );
    } else {
      Log.error("Page Jump", "Unknown page: $page");
    }
  }

  /// 序列化成字符串存入 SQLite
  String toJsonString() {
    return jsonEncode({
      "sourceKey": sourceKey,
      "page": page,
      "attributes": attributes,
    });
  }

  /// 从字符串反序列化
  static PageJumpTarget fromJsonString(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return PageJumpTarget(
      map["sourceKey"],
      map["page"],
      map["attributes"] as Map<String, dynamic>?,
    );
  }
}
