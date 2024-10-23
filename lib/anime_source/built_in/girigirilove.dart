import 'package:flutter/cupertino.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/network/girigirilove_network/ggl_models.dart';
import 'package:kostori/network/girigirilove_network/ggl_network.dart';

import '../../foundation/app.dart';
import '../../foundation/def.dart';
import '../../foundation/history.dart';
import '../../foundation/image_loader/cached_image.dart';
import '../../foundation/local_favorites.dart';
import '../../network/girigirilove_network/ggl_image.dart';
import '../../network/res.dart';
import '../../pages/anime_page.dart';
import '../../pages/ggl/ggl_anime_page.dart';
import '../anime_source.dart';

final girigirilove = AnimeSource.named(
  name: "girigirilove",
  key: "girigirilove",
  filePath: 'built-in',
// favoriteData: FavoriteData(
//   key: "girigirilove",
//   title: "girigirilove",
//   multiFolder: true,
//   loadAnime:
// ),
  animeTileBuilderOverride: (context, anime, options) {
    return _GglAnimeTile(
      anime as GglAnimeBrief,
      addonMenuOptions: options,
    );
  },
  explorePages: [
    ExplorePageData.named(
      title: "ggl主页",
      type: ExplorePageType.singlePageWithMultiPart,
      loadMultiPart: () async {
        var res = <ExplorePagePart>[];
        return Res(res);
      },
    ),
    ExplorePageData.named(
      title: "ggl最新",
      type: ExplorePageType.multiPageAnimeList,
      loadPage: (page) => GGLNetwork().getLatest(page),
    ),
  ],
  animePageBuilder: (context, id, cover) {
    // print("已经在animePageBuilder");
    return GglAnimePage(id, cover!);
  },
);

class _GglAnimeTile extends AnimeTile {
  final GglAnimeBrief anime;

  const _GglAnimeTile(this.anime, {this.addonMenuOptions});

  @override
  String get description => "${anime.id}";

  @override
  Widget get image => AnimatedImage(
        image: CachedImageProvider(
          getGglCoverUrl(anime.dataSrc),
          headers: {
            "User-Agent": webUA,
          },
        ),
        fit: BoxFit.cover,
        height: double.infinity,
        width: double.infinity,
        filterQuality: FilterQuality.medium,
      );

  @override
  void onTap_() {
    App.mainNavigatorKey!.currentContext!.to(
      () => AnimePage(
          sourceKey: 'girigirilove', id: anime.id, cover: anime.dataSrc),
    );
  }

  @override
  String get subTitle => anime.subName;

  @override
  String get title => anime.name;

  @override
  ActionFunc? get read => () async {
        bool cancel = false;
        var dialog = showLoadingDialog(
          App.globalContext!,
          onCancel: () => cancel = true,
        );
        var res = await GGLNetwork().getAnimeInfo(anime.id);
        if (cancel) {
          return;
        }
        dialog.close();
        if (res.error) {
          showToast(message: res.errorMessage ?? "Error");
        } else {
          var history = await History.findOrCreate(res.data);
          // App.globalTo(
          //   () => AnimeReadingPage.jmComic(
          //     res.data,
          //     history.ep,
          //     initialPage: history.page,
          //   ),
          // );
        }
      };

  @override
  List<String>? get tags => anime.tags;

  @override
  FavoriteItem? get favoriteItem => FavoriteItem.fromGglAnime(anime);

  @override
  String get animeID => anime.id;

  @override
  final List<AnimeTileMenuOption>? addonMenuOptions;
}
