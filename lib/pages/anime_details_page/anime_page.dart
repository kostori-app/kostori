// ignore_for_file: unused_element_parameter

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/aggregated_search_page.dart';
import 'package:kostori/pages/bangumi/bottom_info.dart';
import 'package:kostori/pages/favorites/favorites_page.dart';
import 'package:kostori/pages/search_result_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../components/bangumi_widget.dart';
import '../../components/misc_components.dart';
import '../../components/share_widget.dart';
import '../../utils/data_sync.dart';
import '../bangumi/info_controller.dart';

part 'actions.dart';

part 'episodes.dart';

part 'favorite.dart';

class AnimePage extends StatefulWidget {
  const AnimePage({
    super.key,
    required this.id,
    required this.sourceKey,
    this.cover,
    this.title,
    this.heroID,
  });

  final String id;

  final String sourceKey;

  final String? cover;

  final String? title;

  final int? heroID;

  @override
  State<AnimePage> createState() => _AnimePageState();
}

class _AnimePageState extends LoadingState<AnimePage, AnimeDetails>
    with _AnimePageActions, TickerProviderStateMixin {
  bool showAppbarTitle = false;

  var scrollController = ScrollController();

  bool isDownloaded = false;
  bool isUpdateBangumiBind = false;
  bool isBangumi = false;

  BangumiItem? get bangumiItem => bangumiBindInfo;
  late TabController tabController;

  void updateHistory() async {
    var newHistory = HistoryManager().find(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    );
    if (!isUpdateBangumiBind && history?.bangumiId != null) {
      Bangumi.getBangumiInfoBind(history!.bangumiId as int);
      isUpdateBangumiBind = true;
    }
    if (newHistory?.lastWatchEpisode != history?.lastWatchEpisode ||
        newHistory?.lastWatchTime != history?.lastWatchTime) {
      history = newHistory;
      if (history?.bangumiId == null) {
        debugPrint('isBangumi是: $isBangumi');
        if (isBangumi) {
          updateBangumiId();
        }
      }
      update();
    }
  }

  void updateBangumiBind() async {
    if (history?.bangumiId != null) {
      bangumiBindInfo = await BangumiManager().bindFind(
        history!.bangumiId as int,
      );
      update();
    }
  }

  @override
  Widget buildLoading() {
    return _AnimePageLoadingPlaceHolder(
      cover: widget.cover,
      title: widget.title,
      sourceKey: widget.sourceKey,
      aid: widget.id,
      heroID: widget.heroID,
    );
  }

  @override
  void initState() {
    scrollController.addListener(onScroll);
    HistoryManager().addListener(updateHistory);
    BangumiManager().addListener(updateBangumiBind);
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(onScroll);
    HistoryManager().removeListener(updateHistory);
    BangumiManager().removeListener(updateBangumiBind);
    Future.microtask(() {
      DataSync().onDataChanged();
    });
    scrollController.dispose();
    tabController.dispose();
    super.dispose();
  }

  @override
  void update() {
    setState(() {});
  }

  @override
  AnimeDetails get anime => data!;

  Future<void> updateBangumiId() async {
    if (Utils.containsIllegalCharacters(anime.title)) {
      return;
    }
    var res = await Bangumi.combinedBangumiSearch(anime.title);
    if (res.isEmpty ||
        !Utils.isHalfOverlap(anime.title, res.first.nameCn) ||
        !Utils.isHalfOverlap(anime.title, res.first.name)) {
      return;
    } else {
      history?.bangumiId = res.first.id;
      HistoryManager().addHistoryAsync(history!);
    }
  }

  void onScroll() {
    if (scrollController.offset > 250) {
      if (!showAppbarTitle) {
        setState(() {
          showAppbarTitle = true;
        });
      }
    } else {
      if (showAppbarTitle) {
        setState(() {
          showAppbarTitle = false;
        });
      }
    }
  }

  var isFirst = true;

  @override
  Widget buildContent(BuildContext context, AnimeDetails data) {
    Widget widget = Stack(
      children: [
        Positioned.fill(
          child: NestedScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPadding(padding: EdgeInsets.only(top: 28)),
                Watcher(
                  type: anime.animeType,
                  wid: anime.id,
                  name: anime.title,
                  episode: anime.episode,
                  anime: anime,
                  history: History.fromModel(
                    model: anime,
                    lastWatchEpisode: history?.lastWatchEpisode ?? 1,
                    lastWatchTime: history?.lastWatchTime ?? 0,
                    lastRoad: history?.lastRoad ?? 0,
                    allEpisode: anime.episode!.length,
                    bangumiId: history?.bangumiId,
                    watchEpisode: history?.watchEpisode,
                  ),
                ),
                TabBar(
                  controller: tabController,
                  isScrollable: true,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabAlignment: TabAlignment.center,
                  tabs: [
                    Tab(text: '基本信息'.tl),
                    Tab(text: '全部剧集'.tl),
                    Tab(text: '关联条目'.tl),
                  ],
                ).toSliver(),
              ];
            },
            body: animeTab(),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          top: showAppbarTitle ? 0 : -(40 + context.padding.top),
          left: 0,
          right: 0,
          height: 40 + context.padding.top,
          child: buildTop(),
        ),
      ],
    );
    widget = AppScrollBar(
      topPadding: MediaQuery.of(context).padding.top,
      controller: scrollController,
      isNested: true,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );
    return widget;
  }

  @override
  Future<Res<AnimeDetails>> loadData() async {
    var animeSource = AnimeSource.find(widget.sourceKey);
    if (animeSource == null) {
      return const Res.error('Anime source not found');
    }
    isAddToLocalFav = LocalFavoritesManager().isExist(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    );
    history = HistoryManager().find(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    );
    isBangumi = animeSource.isBangumi;

    return animeSource.loadAnimeInfo!(widget.id);
  }

  @override
  Future<void> onDataLoaded() async {
    isLiked = anime.isLiked ?? false;
    isFavorite = anime.isFavorite ?? false;
  }

  Widget animeTab() {
    return TabBarView(
      controller: tabController,
      children: [
        CustomScrollView(
          slivers: [...buildTitle(), buildDescription(), buildInfo()],
        ),
        CustomScrollView(slivers: [buildEpisodes()]),
        CustomScrollView(slivers: [buildRecommend()]),
      ],
    );
  }

  Widget buildTop() {
    return BlurEffect(
      child: Container(
        padding: EdgeInsets.only(top: context.padding.top),
        decoration: BoxDecoration(
          color: context.colorScheme.surface.toOpacity(0.82),
          border: Border(
            bottom: BorderSide(color: Colors.grey.toOpacity(0.5), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Tooltip(
              message: "Back".tl,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                anime.title,
                style: ts.s18,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Iterable<Widget> buildTitle() sync* {
    yield const SliverPadding(padding: EdgeInsets.only(top: 8));

    yield SliverLazyToBoxAdapter(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 300),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxImageWidth = constraints.maxWidth * 0.3;
            final calculatedHeight = maxImageWidth / 0.72;
            final imageHeight = math.min(calculatedHeight, 300.0);
            final imageWidth = imageHeight * 0.72;

            return SizedBox(
              width: constraints.maxWidth,
              height: imageHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 16),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        (history?.bangumiId == null || bangumiItem == null)
                            ? BangumiWidget.showImagePreview(
                                context,
                                anime.cover,
                                anime.title,
                                "cover${widget.heroID}",
                              )
                            : BangumiWidget.showImagePreview(
                                context,
                                bangumiItem!.images['large']!,
                                bangumiItem!.nameCn,
                                "cover${widget.heroID}",
                              );
                      },
                      child: Hero(
                        tag: "cover${widget.heroID}",
                        child: Container(
                          width: imageWidth,
                          height: imageHeight,
                          decoration: BoxDecoration(
                            color: context.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: context.colorScheme.outlineVariant,
                                blurRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AnimatedImage(
                            image: CachedImageProvider(
                              widget.cover ?? anime.cover,
                              sourceKey: anime.sourceKey,
                              aid: anime.id,
                            ),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            var context = App.mainNavigatorKey!.currentContext!;
                            context.to(
                              () => AggregatedSearchPage(keyword: anime.title),
                            );
                          },
                          onLongPress: () {
                            Clipboard.setData(ClipboardData(text: anime.title));
                            App.rootContext.showMessage(message: '已复制到剪贴板.');
                          },
                          child: Text(
                            anime.title,
                            style: ts.s18,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (anime.subTitle != null)
                          SelectableText(
                            anime.subTitle!,
                            style: ts.s14,
                            maxLines: 2,
                          ).paddingVertical(4),
                        Text(
                          AnimeSource.find(anime.sourceKey)?.name ?? '',
                          style: ts.s12,
                        ),
                        const Spacer(),
                        if (bangumiItem != null)
                          Align(
                            child: Row(
                              children: [
                                Text(
                                  '${bangumiItem?.collection?['doing']} 在看',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                Text(' / '),
                                Text(
                                  '${bangumiItem?.collection?['collect']} 看过',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                Text(' / '),
                                Text(
                                  '${bangumiItem?.collection?['dropped']} 抛弃',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (bangumiItem != null)
                          Align(
                            alignment: Alignment.topLeft,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text('${bangumiItem?.score}', style: ts.s24),
                                SizedBox(width: 5),
                                Container(
                                  padding: EdgeInsets.all(2.0), // 可选，设置内边距
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      8,
                                    ), // 设置圆角半径
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                          .toOpacity(0.72),
                                      width: 2.0, // 设置边框宽度
                                    ),
                                  ),
                                  child: Text(
                                    Utils.getRatingLabel(bangumiItem!.score),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start, // 右对齐
                                  children: [
                                    RatingBarIndicator(
                                      itemCount: 5,
                                      rating: bangumiItem!.score.toDouble() / 2,
                                      itemBuilder: (context, index) =>
                                          const Icon(Icons.star_rounded),
                                      itemSize: 20.0,
                                    ),
                                    Text(
                                      '@t reviews | #@r'.tlParams({
                                        'r': bangumiItem!.rank,
                                        't': bangumiItem!.total,
                                      }),
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        SizedBox(
                          height: 45,
                          child: _buildActionButtons(context, anime),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AnimeDetails anime) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _ActionButton(
          icon: const Icon(Icons.star_border),
          activeIcon: const Icon(Icons.star),
          isActive: isFavorite || isAddToLocalFav,
          text: 'Favorite'.tl,
          onPressed: openFavPanel,
          onLongPressed: quickFavorite,
          iconColor: context.useTextColor(Colors.purple),
        ),
        _ActionButton(
          icon: const Icon(Icons.share),
          text: 'Share'.tl,
          onPressed: share,
          iconColor: context.useTextColor(Colors.blue),
        ),
        _ActionButton(
          icon: ClipOval(
            child: SizedBox(
              width: 24,
              height: 24,
              child: SvgPicture.asset(
                'assets/img/bangumi_icon.svg',
                fit: BoxFit.fill, // 强制填充
              ),
            ),
          ),
          text: 'Bangumi'.tl,
          onPressed: () async {
            bangumiBottomInfo(context);
          },
          // iconColor: context.useTextColor(Colors.blue),
        ),
        if (anime.url != null)
          _ActionButton(
            icon: const Icon(Icons.open_in_browser),
            text: 'Open in Browser'.tl,
            onPressed: () => launchUrlString(anime.url!),
            iconColor: context.useTextColor(Colors.blueGrey),
          ),
      ],
    ).fixHeight(48);
  }

  Widget buildDescription() {
    if (anime.description == null || anime.description!.trim().isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 120,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.grey.toOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(title: Text("Description".tl)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(anime.description!).fixWidth(double.infinity),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 120,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.grey.toOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget buildInfo() {
    if (anime.tags.isEmpty &&
        anime.uploader == null &&
        anime.uploadTime == null &&
        anime.uploadTime == null) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }

    int i = 0;

    Widget buildTag({
      required String text,
      VoidCallback? onTap,
      bool isTitle = false,
    }) {
      Color color;
      if (isTitle) {
        const colors = [
          Colors.blue,
          Colors.cyan,
          Colors.red,
          Colors.pink,
          Colors.purple,
          Colors.indigo,
          Colors.teal,
          Colors.green,
          Colors.lime,
          Colors.yellow,
        ];
        color = context.useBackgroundColor(colors[(i++) % (colors.length)]);
      } else {
        color = context.colorScheme.surfaceContainerLow;
      }

      final borderRadius = BorderRadius.circular(12);

      const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 6);

      if (onTap != null) {
        return Material(
          color: color,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: text));
              context.showMessage(message: "Copied".tl);
            },
            onSecondaryTapDown: (details) {
              showMenuX(context, details.globalPosition, [
                MenuEntry(
                  icon: Icons.remove_red_eye,
                  text: "View".tl,
                  onClick: onTap,
                ),
                MenuEntry(
                  icon: Icons.copy,
                  text: "Copy".tl,
                  onClick: () {
                    Clipboard.setData(ClipboardData(text: text));
                    context.showMessage(message: "Copied".tl);
                  },
                ),
              ]);
            },
            child: Text(text).padding(padding),
          ),
        );
      } else {
        return Container(
          decoration: BoxDecoration(color: color, borderRadius: borderRadius),
          child: Text(text).padding(padding),
        );
      }
    }

    Widget buildWrap({required List<Widget> children}) {
      return Wrap(
        runSpacing: 8,
        spacing: 8,
        children: children,
      ).paddingHorizontal(16).paddingBottom(8);
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(title: Text("Information".tl)),
          if (anime.stars != null)
            Row(
              children: [
                StarRating(
                  value: anime.stars!,
                  size: 24,
                  // onTap: starRating,
                ),
                const SizedBox(width: 8),
                Text(anime.stars!.toStringAsFixed(2)),
              ],
            ).paddingLeft(16).paddingVertical(8),
          for (var e in anime.tags.entries)
            buildWrap(
              children: [
                if (e.value.isNotEmpty)
                  buildTag(text: e.key.ts(animeSource.key), isTitle: true),
                for (var tag in e.value)
                  buildTag(text: tag, onTap: () => onTapTag(tag, e.key)),
              ],
            ),
          if (anime.uploader != null)
            buildWrap(
              children: [
                buildTag(text: 'Uploader'.tl, isTitle: true),
                buildTag(text: anime.uploader!),
              ],
            ),
          if (anime.uploadTime != null)
            buildWrap(
              children: [
                buildTag(text: 'Upload Time'.tl, isTitle: true),
                buildTag(text: anime.uploadTime!),
              ],
            ),
          if (anime.updateTime != null)
            buildWrap(
              children: [
                buildTag(text: 'Update Time'.tl, isTitle: true),
                buildTag(text: anime.updateTime!),
              ],
            ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 120,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.grey.toOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget buildEpisodes() {
    if (anime.episode == null) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return _AnimeEpisodes(history: history);
  }

  Widget buildRecommend() {
    if (anime.recommend == null || anime.recommend!.isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: ListTile(title: Text("Related".tl))),
        SliverGridAnimes(animes: anime.recommend!, isRecommend: true),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    this.onLongPressed,
    this.activeIcon,
    this.isActive,
    this.iconColor,
    this.isLoading,
  });

  final Widget icon;

  final Widget? activeIcon;

  final bool? isActive;

  final String text;

  final void Function() onPressed;

  final bool? isLoading;

  final Color? iconColor;

  final void Function()? onLongPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colorScheme.outlineVariant,
          width: 0.6,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!(isLoading ?? false)) {
            onPressed();
          }
        },
        onLongPress: onLongPressed,
        borderRadius: BorderRadius.circular(18),
        child: IconTheme.merge(
          data: IconThemeData(size: 20, color: iconColor),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading ?? false)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                )
              else
                (isActive ?? false) ? (activeIcon ?? icon) : icon,
              const SizedBox(width: 8),
              Text(text),
            ],
          ).paddingHorizontal(16),
        ),
      ),
    );
  }
}

class _AnimePageLoadingPlaceHolder extends StatelessWidget {
  const _AnimePageLoadingPlaceHolder({
    this.cover,
    this.title,
    required this.sourceKey,
    required this.aid,
    this.heroID,
  });

  final String? cover;

  final String? title;

  final String sourceKey;

  final String aid;

  final int? heroID;

  @override
  Widget build(BuildContext context) {
    Widget buildContainer(
      double? width,
      double? height, {
      Color? color,
      double? radius,
    }) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color ?? context.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(radius ?? 4),
        ),
      );
    }

    return Shimmer(
      color: context.isDarkMode ? Colors.grey.shade700 : Colors.white,
      child: Column(
        children: [
          buildVideoPlaceholder(context),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 16),
              buildImage(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(title ?? "", style: ts.s18)
                    else
                      buildContainer(200, 25),
                    const SizedBox(height: 8),
                    buildContainer(80, 20),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildVideoPlaceholder(BuildContext context) {
    final double aspectRatioMultiplier = App.isDesktop ? 0.45 : 0.6;
    final double maxWidth = MediaQuery.of(context).size.width;
    final double maxHeight = maxWidth * aspectRatioMultiplier;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(App.isDesktop ? 16.0 : 8.0),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
          color: Colors.black,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: MiscComponents.placeholder(
                  context,
                  50,
                  50,
                  Colors.transparent,
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildImage(BuildContext context) {
    Widget child;
    if (cover != null) {
      child = AnimatedImage(
        image: CachedImageProvider(cover!, sourceKey: sourceKey, aid: aid),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      child = const SizedBox();
    }

    return Hero(
      tag: "cover$heroID",
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.outlineVariant,
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        height: 144,
        width: 144 * 0.72,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
