import 'package:flutter/material.dart';
import 'package:kostori/network/girigirilove_network/ggl_models.dart';
import 'package:kostori/network/girigirilove_network/ggl_network.dart';
import 'package:kostori/pages/anime_page.dart';
import 'package:kostori/tools/extensions.dart';
import 'package:kostori/tools/translations.dart';

import '../../components/components.dart';
import '../../foundation/app.dart';
import '../../foundation/history.dart';
import '../../foundation/local_favorites.dart';
import '../../network/girigirilove_network/ggl_image.dart';
import '../../network/res.dart';
import '../search_result_page.dart';
import '../watch/anime_watch_page.dart';

class GglAnimePage extends BaseAnimePage<GglAnimeInfo> {
  GglAnimePage(this.id, this.dataSrc, {Key? key});

  @override
  final String id;
  final String dataSrc;

  @override
  void openFavoritePanel() {
    favoriteAnime(FavoriteAnimeWidget(
      havePlatformFavorite: false,
      needLoadFolderData: false,
      localFavoriteItem: toLocalFavoriteItem(),
      setFavorite: (b) {
        if (favorite != b) {
          favorite = b;
          update();
        }
      },
    ));
  }

  @override
  String get cover => getGglCoverUrl(dataSrc);

  String _getEpName(int index) {
    final epName = data!.epNames.elementAtOrNull(index);
    if (epName != null) {
      return epName;
    }
    var name = "第 @c 章".tlParams({"c": (index + 1).toString()});
    return name;
  }

  @override
  EpsData? get eps {
    // final AnimeWatchPageState animeWatchPageState = AnimeWatchPageState();
    return EpsData(
      List<String>.generate(
          data!.series.values.length, (index) => _getEpName(index)),
      (i) async {
        await History.findOrCreate(data!);
        // 使用静态变量访问当前状态
        if (AnimeWatchPage.currentState != null) {
          AnimeWatchPage.currentState!.loadInfo(i + 1); // 传递集数
        }
      },
    );
  }

  @override
  String? get introduction => data!.description;

  @override
  Future<Res<GglAnimeInfo>> loadData() => GGLNetwork().getAnimeInfo(id);

  @override
  int? get pages => null;

  @override
  Future<bool> loadFavorite(GglAnimeInfo data) async {
    return data.favorite ||
        (await LocalFavoritesManager().findWithModel(toLocalFavoriteItem()))
            .isNotEmpty;
  }

  @override
  void read(History? history) async {
    history = await History.createIfNull(history, data!);
    // App.globalTo(
    //   () => ComicReadingPage.jmComic(
    //     data!,
    //     history!.ep,
    //     initialPage: history.page,
    //   ),
    // );
  }

  @override
  Widget recommendationBuilder(GglAnimeInfo data) =>
      SliverGridAnimes(animes: data.relatedAnimes, sourceKey: 'girigirilove');

  @override
  String get tag => "girigirilove animePage $id";

  @override
  Map<String, List<String>>? get tags => {
        "导演": (data!.director.isEmpty) ? "未知".toList() : data!.director,
        "配音演员": (data!.actors.isEmpty) ? "未知".toList() : data!.actors,
        "标签": data!.tags
      };

  @override
  void tapOnTag(String tag, String key) => context.to(() => SearchResultPage(
        keyword: tag,
        sourceKey: "girigirilove",
      ));

  @override
  ThumbnailsData? get thumbnailsCreator => null;

  @override
  String? get title => data?.name;

  @override
  Card? get uploaderInfo => null;

  @override
  String get source => "girigirilove";

  @override
  FavoriteItem toLocalFavoriteItem() => FavoriteItem.fromGglAnime(GglAnimeBrief(
        id,
        data!.subName,
        data!.name,
        data!.dataSrc,
        data!.tags,
        data!.description,
      ));

  @override
  String get downloadedId => "${data!.id}";

  @override
  String get sourceKey => "girigirilove";
}
