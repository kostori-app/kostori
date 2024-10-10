import '../../network/res.dart';
import '../anime_source.dart';

final girigirilove = AnimeSource.named(
  name: "girigirilove",
  key: "girigirilove",
  filePath: 'built-in',
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
    ),
  ],
);
