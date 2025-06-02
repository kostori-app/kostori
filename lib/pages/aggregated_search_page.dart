import "package:flutter/material.dart";
import "package:kostori/components/components.dart";
import "package:kostori/foundation/app.dart";
import "package:kostori/foundation/appdata.dart";
import "package:kostori/pages/search_result_page.dart";
import "package:kostori/utils/translations.dart";

import 'package:kostori/foundation/anime_source/anime_source.dart';
import "package:shimmer_animation/shimmer_animation.dart";

class AggregatedSearchPage extends StatefulWidget {
  const AggregatedSearchPage(
      {super.key,
      required this.keyword,
      this.keywords,
      this.bangumiPage = false});

  final String keyword;
  final List<String>? keywords;
  final bool bangumiPage;

  @override
  State<AggregatedSearchPage> createState() => _AggregatedSearchPageState();
}

class _AggregatedSearchPageState extends State<AggregatedSearchPage> {
  late final List<AnimeSource> sources;

  late final SearchBarController controller;

  var _keyword = "";

  @override
  void initState() {
    var all = AnimeSource.all()
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
    var settings = appdata.settings['searchSources'] as List;
    var sources = <String>[];
    for (var source in settings) {
      if (all.contains(source)) {
        sources.add(source);
      }
    }
    this.sources = sources.map((e) => AnimeSource.find(e)!).toList();
    _keyword = widget.keyword;
    controller = SearchBarController(
      currentText: widget.keyword,
      onSearch: (text) {
        setState(() {
          _keyword = text;
        });
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(slivers: [
      SliverSearchBar(
          controller: controller,
          bangumiPage: widget.bangumiPage,
          keywords: widget.keywords),
      SliverList(
        key: ValueKey(_keyword),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final source = sources[index];
            return _SliverSearchResult(
              key: ValueKey(source.key),
              source: source,
              keyword: _keyword,
            );
          },
          childCount: sources.length,
        ),
      ),
    ]);
  }
}

class _SliverSearchResult extends StatefulWidget {
  const _SliverSearchResult({
    required this.source,
    required this.keyword,
    super.key,
  });

  final AnimeSource source;

  final String keyword;

  @override
  State<_SliverSearchResult> createState() => _SliverSearchResultState();
}

class _SliverSearchResultState extends State<_SliverSearchResult>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;

  static const _kAnimeHeight = 162.0;

  get _animeWidth => _kAnimeHeight * 0.7;

  static const _kLeftPadding = 16.0;

  List<Anime>? animes;

  String? error;

  void load() async {
    final data = widget.source.searchPageData!;
    var options =
        (data.searchOptions ?? []).map((e) => e.defaultValue).toList();
    if (data.loadPage != null) {
      var res = await data.loadPage!(widget.keyword, 1, options);
      if (!res.error) {
        setState(() {
          animes = res.data;
          isLoading = false;
        });
      } else {
        setState(() {
          error = res.errorMessage ?? "Unknown error".tl;
          isLoading = false;
        });
      }
    } else if (data.loadNext != null) {
      var res = await data.loadNext!(widget.keyword, null, options);
      if (!res.error) {
        setState(() {
          animes = res.data;
          isLoading = false;
        });
      } else {
        setState(() {
          error = res.errorMessage ?? "Unknown error".tl;
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Widget buildPlaceHolder() {
    return Container(
      height: _kAnimeHeight,
      width: _animeWidth,
      margin: const EdgeInsets.only(left: _kLeftPadding),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget buildAnime(Anime c) {
    return SimpleAnimeTile(anime: c, withTitle: true)
        .paddingLeft(_kLeftPadding)
        .paddingBottom(2);
  }

  @override
  Widget build(BuildContext context) {
    if (error != null && error!.startsWith("CloudflareException")) {
      error = "Cloudflare verification required".tl;
    }
    super.build(context);
    return InkWell(
      onTap: () {
        context.to(
          () => SearchResultPage(
            text: widget.keyword,
            sourceKey: widget.source.key,
          ),
        );
      },
      child: Column(
        children: [
          ListTile(
            mouseCursor: SystemMouseCursors.click,
            title: Text(widget.source.name),
          ),
          if (isLoading)
            SizedBox(
              height: _kAnimeHeight,
              width: double.infinity,
              child: Shimmer(
                child: LayoutBuilder(builder: (context, constrains) {
                  var itemWidth = _animeWidth + _kLeftPadding;
                  var items = (constrains.maxWidth / itemWidth).ceil();
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Row(
                          children: List.generate(
                            items,
                            (index) => buildPlaceHolder(),
                          ),
                        ),
                      )
                    ],
                  );
                }),
              ),
            )
          else if (animes == null || animes!.isEmpty)
            SizedBox(
              height: _kAnimeHeight,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error ?? "No search results found".tl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    ],
                  ),
                  const Spacer(),
                ],
              ).paddingHorizontal(16),
            )
          else
            SizedBox(
              height: _kAnimeHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var a in animes!) buildAnime(a),
                ],
              ),
            ),
        ],
      ).paddingBottom(16),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
