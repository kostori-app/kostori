import '../../foundation/history.dart';
import '../base_anime.dart';
import 'ggl_image.dart';

class HomePageData {
  List<HomePageItem> items;

  HomePageData(this.items);
}

class HomePageItem {
  String name;
  String id;
  // bool category;
  List<GglAnimeBrief> animes;

  HomePageItem(
    this.name,
    this.id,
    this.animes,
  );
}

class GglAnimeBrief extends BaseAnime {
  @override
  String id;
  String name;
  String subName;
  String dataSrc;
  @override
  String description;
  // String classification;
  List<String> categories;
  @override
  List<String> get tags => categories;

  GglAnimeBrief(
    this.id,
    this.name,
    this.subName,
    this.dataSrc,
    this.categories,
    this.description,
  );

  @override
  String get cover => getGglCoverUrl(dataSrc);

  @override
  String get subTitle => subTitle;

  @override
  String get title => title;
}

// class AnimeCategoryInfo {
//   String name;
//
//   AnimeCategoryInfo(this.name);
// }

class GglAnimeInfo with HistoryMixin {
  String name;
  String id;
  String subName;
  // List<String> author;
  String description;
  String dataSrc;
  List<String> director; // 新增导演字段
  List<String> actors; // 新增演员字段
  // int likes;
  // int views;
  // int comments;

  ///章节信息, 键为章节序号, 值为漫画ID
  Map<int, String> series;
  List<String> tags;
  List<GglAnimeBrief> relatedAnimes;
  // bool liked;
  bool favorite;
  List<String> epNames;

  GglAnimeInfo(
      this.name,
      this.id,
      this.subName,
      // this.author,
      this.description,
      this.dataSrc,
      this.director, // 新增
      this.actors, // 新增
      // this.likes,
      // this.views,
      this.series,
      this.tags,
      this.relatedAnimes,
      // this.liked,
      this.favorite,
      // this.comments,
      this.epNames);

  static Map<String, String> seriesToJsonMap(Map<int, String> map) {
    var res = <String, String>{};
    for (var i in map.entries) {
      res[i.key.toString()] = i.value;
    }
    return res;
  }

  static Map<int, String> jsonMapToSeries(Map<String, dynamic> map) {
    var res = <int, String>{};
    for (var i in map.entries) {
      res[int.parse(i.key)] = i.value;
    }
    return res;
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "id": id,
      "subName": subName,
      "description": description,
      "dataSrc": dataSrc,
      "director": director, // 导演
      "actors": actors, // 演员
      "series": seriesToJsonMap(series),
      "tags": tags,
      "relatedAnimes": [],
      "favorite": favorite,
      "epNames": epNames
    };
  }

  GglAnimeInfo.fromMap(Map<String, dynamic> map)
      : name = map["name"],
        id = map["id"],
        subName = map["subName"],
        description = map["description"],
        dataSrc = map["dataSrc"],
        director = List<String>.from(map["director"]), // 新增
        actors = List<String>.from(map["actors"]), // 新增
        // likes = 0,
        // views = 0,
        series = jsonMapToSeries(map["series"]),
        tags = List<String>.from(map["tags"]),
        relatedAnimes = [],
        // liked = false,
        favorite = false,
        // comments = 0,
        epNames = List.from(map["epNames"] ?? []);

  GglAnimeBrief toBrief() =>
      GglAnimeBrief(id, name, subName, dataSrc, tags, description);

  @override
  String get cover => getGglCoverUrl(dataSrc);

  @override
  HistoryType get historyType => HistoryType.gglAnime;

  @override
  String get subTitle => name;

  @override
  String get target => id;

  @override
  String get title => name;
}
