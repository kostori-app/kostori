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
        return DateTime.fromMillisecondsSinceEpoch(value * 1000)
            .toString()
            .substring(0, 19);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(value)
            .toString()
            .substring(0, 19);
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

  const Anime(
    this.title,
    this.cover,
    this.id,
    this.subtitle,
    this.tags,
    this.description,
    this.sourceKey,
    this.language,
  )   : favoriteId = null,
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
        stars = (json["stars"] as num?)?.toDouble();

  @override
  bool operator ==(Object other) {
    if (other is! Anime) return false;
    return other.id == id && other.sourceKey == sourceKey;
  }

  @override
  int get hashCode => id.hashCode ^ sourceKey.hashCode;
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

  final List<String>? director; // 新增导演字段

  final List<String>? actors; // 新增演员字段

  final String? uploader;

  final String? uploadTime;

  final String? updateTime;

  final String? url;

  final double? stars;

  static Map<String, List<String>> _generateMap(Map<dynamic, dynamic> map) {
    var res = <String, List<String>>{};
    map.forEach((key, value) {
      res[key] = List<String>.from(value);
    });
    return res;
  }

  static Map<String, Map<String, String>> _generateNestedMap(
      Map<dynamic, dynamic> map) {
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
        director = json["director"],
        actors = json["actors"],
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
      "director": director,
      "actors": actors,
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
}
