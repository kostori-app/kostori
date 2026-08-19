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

/// 描述里的一行信息（可选颜色，供卡片覆盖层逐行徽章展示）
class AnimeDescriptionLine {
  final String text;

  /// 颜色：`#RRGGBB` / `#RGB` 或颜色名（red/yellow/green/...），UI 层解析
  final String? color;

  const AnimeDescriptionLine(this.text, this.color);

  @override
  String toString() => color == null ? text : '$text($color)';
}

class Anime {
  final String title;

  final String cover;

  final String id;

  final String? subtitle;

  final List<String>? tags;

  final String description;

  /// description 的结构化行（源返回 List 且含 Map 项时非空，可携带每行颜色）
  final List<AnimeDescriptionLine>? descriptionLines;

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
    this.viewMore, {
    this.descriptionLines,
  }) : favoriteId = null,
       stars = null;

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "cover": cover,
      "id": id,
      "subtitle": subtitle,
      "tags": tags,
      "description": description,
      if (descriptionLines != null)
        "descriptionLines": descriptionLines!.map((l) {
          if (l.color == null) return l.text;
          return {'text': l.text, 'color': l.color};
        }).toList(),
      "sourceKey": sourceKey,
      "language": language,
      "favoriteId": favoriteId,
      "viewMore": viewMore,
    };
  }

  Anime.fromJson(Map<String, dynamic> json, this.sourceKey)
    : title = json["title"],
      subtitle = json["subtitle"] ?? "",
      cover = json["cover"] ?? '',
      id = json["id"],
      tags = List<String>.from(json["tags"] ?? []),
      description = normalizeDescription(json["description"]),
      descriptionLines = parseDescriptionLines(json["description"]),
      language = json["language"],
      favoriteId = json["favoriteId"],
      stars = (json["stars"] as num?)?.toDouble(),
      viewMore = PageJumpTarget.parse(sourceKey, json["viewMore"]);

  /// 兼容 description 的三种写法：
  /// - `String`：多行用 `|` 分隔（旧写法），或直接含换行符
  /// - `List<String>`：每项一行
  /// - `List<Map>`：每项 `{ text, color }`（可指定该行展示颜色）
  static String normalizeDescription(dynamic value) {
    if (value is List) {
      return value.map((e) {
        if (e is Map) return (e['text'] ?? '').toString();
        return e.toString();
      }).join('\n');
    }
    return value?.toString() ?? '';
  }

  /// 解析 description 为结构化行（带颜色）；非 List 或纯 String 行时返回 null
  static List<AnimeDescriptionLine>? parseDescriptionLines(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    final lines = <AnimeDescriptionLine>[];
    for (final e in value) {
      if (e is String) {
        lines.add(AnimeDescriptionLine(e, null));
      } else if (e is Map) {
        final text = (e['text'] ?? '').toString();
        if (text.isEmpty) continue;
        lines.add(AnimeDescriptionLine(text, e['color']?.toString()));
      }
    }
    return lines.isEmpty ? null : lines;
  }

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
  /// 兼容旧 episode 格式：value 可为 String（集名）或 Map（携带 title/cover 等）
  static String episodeTitleOf(dynamic value) =>
      value is Map ? (value['title'] as String? ?? '') : (value?.toString() ?? '');

  static String? episodeCoverOf(dynamic value) =>
      value is Map ? (value['cover'] as String?) : null;

  @override
  final String title;

  @override
  final String? subTitle;

  @override
  final String cover;

  final String? description;

  final Map<String, List<String>> tags;

  /// id-name
  final Map<String, Map<String, dynamic>>? episode;

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

  static Map<String, Map<String, dynamic>> _generateNestedMap(
    Map<dynamic, dynamic> map,
  ) {
    var res = <String, Map<String, dynamic>>{};
    map.forEach((key, value) {
      // 兼容旧格式（value 为 String 集名）与新格式（value 为 Map 携带 title/cover 等）
      res[key] = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
    });
    return res;
  }

  AnimeDetails.fromJson(Map<String, dynamic> json)
    : title = json["title"],
      subTitle = json["subtitle"],
      cover = json["cover"],
      description = Anime.normalizeDescription(json["description"]),
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

  /// 解析 PageJumpTarget，支持两种写法：
  /// - Map：`{ page, attributes, url? }`（url 可选，二级页右上角"打开网页"）或旧 `{ action, keyword }`
  /// - String（旧版）：`search:关键词` / `category:分类名` / `category:分类名@param`
  static PageJumpTarget parse(String sourceKey, dynamic value) {
    if (value is Map) {
      if (value['page'] != null) {
        // 兼容源在跳转目标里附带网页地址：attributes['url'] 供二级页打开
        final attrs = (value["attributes"] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v),
            ) ??
            <String, dynamic>{};
        final url = value['url'] as String?;
        if (url != null && url.isNotEmpty) attrs['url'] = url;
        return PageJumpTarget(sourceKey, value["page"] ?? "search", attrs);
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
          webUrl: attributes?["url"],
        ),
      );
    } else if (page == "category") {
      var key = AnimeSource.find(sourceKey)!.categoryData!.key;
      context.to(
        () => CategoryAnimesPage(
          categoryKey: key,
          sourceKey: sourceKey,
          category:
              attributes?["category"] ??
              (throw ArgumentError("Category name is required")),
          options: List.from(attributes?["options"] ?? []),
          param: attributes?["param"],
          webUrl: attributes?["url"],
        ),
      );
    } else {
      SourceLog.error("Page Jump", "Unknown page: $page");
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
