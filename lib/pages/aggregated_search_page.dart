import "package:flutter/material.dart";
import "package:kostori/components/components.dart";
import "package:kostori/database/search_history.dart";
import 'package:kostori/foundation/anime_source/anime_source.dart';
import "package:kostori/foundation/app.dart";
import "package:kostori/foundation/appdata.dart";
import "package:kostori/i18n/strings.g.dart";
import "package:kostori/pages/search_result_page.dart";
import "package:kostori/utils/search_source_groups.dart";
import "package:shimmer_animation/shimmer_animation.dart";

class AggregatedSearchPage extends StatefulWidget {
  const AggregatedSearchPage({
    super.key,
    required this.keyword,
    this.keywords,
    this.bangumiPage = false,
    this.sourceKeys,
    this.group,
  });

  final String keyword;
  final List<String>? keywords;
  final bool bangumiPage;

  /// 指定要搜索的源；为 null 时使用 [group] 分组内的启用源（或全部启用源）
  final List<String>? sourceKeys;

  /// 指定分组（'all' 表示全部）
  final String? group;

  @override
  State<AggregatedSearchPage> createState() => _AggregatedSearchPageState();
}

class _AggregatedSearchPageState extends State<AggregatedSearchPage> {
  late List<AnimeSource> sources;
  late final SearchBarController controller;

  late String selectedGroup;

  var _keyword = "";

  bool showOnlyNonEmpty = false;

  /// 记录每个 source 是否有结果
  final Map<String, bool> _sourceHasResult = {};

  List<AnimeSource> _resolveSources([String? group]) {
    if (widget.sourceKeys != null && group == null) {
      return [
        for (final k in widget.sourceKeys!)
          if (AnimeSource.find(k) != null) AnimeSource.find(k)!,
      ];
    }
    return enabledSearchSources(group ?? selectedGroup);
  }

  void _switchGroup(String group) {
    if (group == selectedGroup) return;
    setState(() {
      selectedGroup = group;
      saveSelectedSearchGroup(group);
      sources = _resolveSources(group);
      _sourceHasResult.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    selectedGroup = widget.group ?? selectedSearchGroup();
    sources = _resolveSources();
    showOnlyNonEmpty = appdata.implicitData['showOnlyNonEmpty'] ?? false;

    _keyword = widget.keyword;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SearchHistoryManager().addSearch(_keyword);
    });

    controller = SearchBarController(
      currentText: widget.keyword,
      onSearch: (text) {
        setState(() {
          _keyword = text;
          _sourceHasResult.clear();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverSearchBar(
          controller: controller,
          bangumiPage: widget.bangumiPage,
          keywords: widget.keywords,
        ),
        // 搜索源分组筛选
        if (widget.sourceKeys == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final group in searchGroups())
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OptionChip(
                          text: searchGroupLabel(group),
                          isSelected: selectedGroup == group,
                          onTap: () => _switchGroup(group),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                OptionChip(
                  text: showOnlyNonEmpty ? t.result : t.all,
                  isSelected: showOnlyNonEmpty,
                  onTap: () {
                    setState(() {
                      showOnlyNonEmpty = !showOnlyNonEmpty;
                      appdata.implicitData['showOnlyNonEmpty'] =
                          showOnlyNonEmpty;
                      appdata.writeImplicitData();
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        if (sources.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  t.noSearchSources,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.toOpacity(0.5),
                  ),
                ),
              ),
            ),
          )
        else
          SliverList(
            key: ValueKey('$_keyword|$selectedGroup'),
            delegate: SliverChildBuilderDelegate((context, index) {
              final source = sources[index];
              final hasResult = _sourceHasResult[source.key] ?? true;
              if (showOnlyNonEmpty && !hasResult) {
                return const SizedBox.shrink();
              }
              return _SliverSearchResult(
                key: ValueKey(source.key),
                source: source,
                keyword: _keyword,
                onResultLoaded: (bool result) {
                  if (_sourceHasResult[source.key] != result) {
                    setState(() {
                      _sourceHasResult[source.key] = result;
                    });
                  }
                },
              );
            }, childCount: sources.length),
          ),
      ],
    );
  }
}

class _SliverSearchResult extends StatefulWidget {
  const _SliverSearchResult({
    required this.source,
    required this.keyword,
    this.onResultLoaded,
    super.key,
  });

  final AnimeSource source;
  final String keyword;
  final void Function(bool hasResult)? onResultLoaded;

  @override
  State<_SliverSearchResult> createState() => _SliverSearchResultState();
}

class _SliverSearchResultState extends State<_SliverSearchResult>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;

  static const _kAnimeHeight = 162.0;

  double get _animeWidth => _kAnimeHeight * 0.7;
  static const _kLeftPadding = 16.0;

  List<Anime>? animes;
  String? error;

  /// 请求序号：用于丢弃过期的在途请求结果
  int _requestSeq = 0;

  Future<void> load() async {
    final seq = ++_requestSeq;
    final data = widget.source.searchPageData!;
    var options = (data.searchOptions ?? [])
        .map((e) => e.defaultValue)
        .toList();

    void notify(bool hasData) {
      widget.onResultLoaded?.call(hasData);
    }

    void applySuccess(List<Anime>? list) {
      if (seq != _requestSeq || !mounted) return;
      setState(() {
        animes = list;
        isLoading = false;
      });
      notify(list != null && list.isNotEmpty);
    }

    void applyError(String message) {
      if (seq != _requestSeq || !mounted) return;
      setState(() {
        error = message.startsWith('CloudflareException')
            ? t.cloudflareVerificationRequired
            : message;
        isLoading = false;
      });
      notify(false);
    }

    try {
      if (data.loadPage != null) {
        var res = await data.loadPage!(widget.keyword, 1, options);
        if (res.error) {
          applyError(res.errorMessage ?? t.unknownError);
        } else {
          applySuccess(res.data);
        }
      } else if (data.loadNext != null) {
        var res = await data.loadNext!(widget.keyword, null, options);
        if (res.error) {
          applyError(res.errorMessage ?? t.unknownError);
        } else {
          applySuccess(res.data);
        }
      }
    } catch (e) {
      applyError(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant _SliverSearchResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyword != widget.keyword) {
      _requestSeq++; // 使在途旧请求作废
      isLoading = true;
      animes = null;
      error = null;
      load();
    }
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
    return SimpleAnimeTile(
      anime: c,
      withTitle: true,
    ).paddingLeft(_kLeftPadding).paddingBottom(2);
  }

  @override
  Widget build(BuildContext context) {
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var itemWidth = _animeWidth + _kLeftPadding;
                    var items = (constraints.maxWidth / itemWidth).ceil();
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
                        ),
                      ],
                    );
                  },
                ),
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
                          error ?? t.noSearchResultsFound,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                children: [for (var a in animes!) buildAnime(a)],
              ),
            ),
        ],
      ).paddingBottom(16),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
