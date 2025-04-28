import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kostori/pages/aggregated_search_page.dart';
import 'package:kostori/pages/bangumi/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_item.dart';
import 'package:kostori/pages/bangumi/bottom_info.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/utils.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/pages/category_animes_page.dart';
import 'package:kostori/pages/favorites/favorites_page.dart';
import 'package:kostori/pages/search_result_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/tag_translation.dart';
import 'package:kostori/utils/translations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../network/app_dio.dart';

part 'actions.dart';

part 'favorite.dart';

part 'episodes.dart';

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
    with _AnimePageActions {
  bool showAppbarTitle = false;

  var scrollController = ScrollController();

  bool isDownloaded = false;

  void updateHistory() async {
    var newHistory =
        HistoryManager().find(widget.id, AnimeType(widget.sourceKey.hashCode));
    if (newHistory?.lastWatchEpisode != history?.lastWatchEpisode ||
        newHistory?.lastWatchTime != history?.lastWatchTime) {
      history = newHistory;
      update();
      if (history?.bangumiId == null) {
        updateBangumiId();
      }
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

    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(onScroll);
    HistoryManager().removeListener(updateHistory);
    super.dispose();
  }

  @override
  void update() {
    setState(() {});
  }

  @override
  AnimeDetails get anime => data!;

  Future<void> updateBangumiId() async {
    var res = await Bangumi.bangumiGetSearch(anime.title);
    // 如果列表为空，返回 null
    if (res.isEmpty) {
      return;
    } else {
      // 返回第一个BangumiItem的id
      history?.bangumiId = res.first.id; // 假设 BangumiItem 有一个 id 属性
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
    return Stack(
      children: [
        // 主内容 SmoothCustomScrollView
        Positioned.fill(
          child: SmoothCustomScrollView(
            controller: scrollController,
            slivers: [
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
                ),
              ),
              ...buildTitle(),
              buildDescription(),
              buildInfo(),
              buildEpisodes(),
              buildRecommend(),
              SliverPadding(
                  padding: EdgeInsets.only(bottom: context.padding.bottom)),
            ],
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
    history =
        HistoryManager().find(widget.id, AnimeType(widget.sourceKey.hashCode));
    return animeSource.loadAnimeInfo!(widget.id);
  }

  @override
  Future<void> onDataLoaded() async {
    isLiked = anime.isLiked ?? false;
    isFavorite = anime.isFavorite ?? false;
  }

  Widget buildTop() {
    return BlurEffect(
      child: Container(
        padding: EdgeInsets.only(top: context.padding.top),
        decoration: BoxDecoration(
          color: context.colorScheme.surface.toOpacity(0.82),
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.toOpacity(0.5),
              width: 0.5,
            ),
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
        constraints: const BoxConstraints(
          maxWidth: 550,
          maxHeight: 300,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 计算图片尺寸，保持0.72宽高比，同时限制最大高度
            final maxImageWidth = constraints.maxWidth * 0.3; // 宽度不超过容器30%
            final calculatedHeight = maxImageWidth / 0.72; // 按比例计算高度

            // 应用高度限制
            final imageHeight = math.min(calculatedHeight, 300.0);
            final imageWidth = imageHeight * 0.72; // 根据限制后的高度计算宽度

            BangumiItem? bangumiItem;
            if (history?.bangumiId != null) {
              bangumiItem =
                  await Bangumi.getBangumiInfoByID(history?.bangumiId as int);
            }
            return Container(
              width: constraints.maxWidth,
              height: imageHeight,
              padding: EdgeInsets.all(2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 16),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: Text(anime.title),
                                actions: [
                                  // IconButton(
                                  //   icon: const Icon(Icons.download),
                                  //   onPressed: () {},
                                  // ),
                                ],
                              ),
                              body: PhotoView(
                                imageProvider: CachedImageProvider(
                                  widget.cover ?? anime.cover,
                                  sourceKey: anime.sourceKey,
                                  aid: anime.id,
                                ),
                                minScale: PhotoViewComputedScale.contained,
                                maxScale: PhotoViewComputedScale.covered * 3,
                                heroAttributes: PhotoViewHeroAttributes(
                                  tag: "cover${widget.heroID}",
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Hero(
                        tag: "cover${widget.heroID}",
                        child: Container(
                          width: imageWidth,
                          // 使用计算后的宽度
                          height: imageHeight,
                          // 使用计算后的高度
                          decoration: BoxDecoration(
                            color: context.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: context.colorScheme.outlineVariant,
                                blurRadius: 1,
                                offset: const Offset(0, 1),
                              )
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AnimatedImage(
                            image: CachedImageProvider(
                              widget.cover ?? anime.cover,
                              sourceKey: anime.sourceKey,
                              aid: anime.id,
                            ),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
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
                            context.to(() => AggregatedSearchPage(
                                  keyword: anime.title,
                                ));
                          },
                          onLongPress: () {
                            Clipboard.setData(ClipboardData(text: anime.title));
                            SmartDialog.showNotify(
                                msg: '已复制到剪贴板.',
                                notifyType: NotifyType.success);
                          },
                          child: Text(
                            anime.title,
                            style: ts.s18,
                          ),
                        ),
                        if (anime.subTitle != null)
                          SelectableText(anime.subTitle!, style: ts.s14)
                              .paddingVertical(4),
                        Text(
                          (AnimeSource.find(anime.sourceKey)?.name) ?? '',
                          style: ts.s12,
                        ),
                        const Spacer(),
                        SizedBox(
                          child: Column(children: [
                            Wrap(
                              children: [
                                ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 0),
                                  children: [
                                    _ActionButton(
                                      icon: const Icon(Icons.star_border),
                                      activeIcon: const Icon(Icons.star),
                                      isActive: isFavorite || isAddToLocalFav,
                                      text: 'Favorite'.tl,
                                      onPressed: openFavPanel,
                                      onLongPressed: quickFavorite,
                                      iconColor:
                                          context.useTextColor(Colors.purple),
                                    ),
                                    _ActionButton(
                                      icon: const Icon(Icons.share),
                                      text: 'Share'.tl,
                                      onPressed: share,
                                      iconColor:
                                          context.useTextColor(Colors.blue),
                                    ),
                                    _ActionButton(
                                      icon: ClipOval(
                                        child: Image.asset(
                                          "assets/bgm.png",
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      text: 'Bangumi'.tl,
                                      onPressed: () async {
                                        bangumiBottomInfo(context);
                                      },
                                      iconColor:
                                          context.useTextColor(Colors.blue),
                                    ),
                                    if (anime.url != null)
                                      _ActionButton(
                                        icon: const Icon(Icons.open_in_browser),
                                        text: 'Open in Browser'.tl,
                                        onPressed: () =>
                                            launchUrlString(anime.url!),
                                        iconColor: context
                                            .useTextColor(Colors.blueGrey),
                                      ),
                                  ],
                                ).fixHeight(48),
                              ],
                            )
                          ]),
                        )
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

  Widget buildDescription() {
    if (anime.description == null || anime.description!.trim().isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          ListTile(
            title: Text("Description".tl),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(anime.description!).fixWidth(double.infinity),
          ),
          const SizedBox(height: 16),
          const Divider(),
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
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
          ),
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

    bool enableTranslation =
        App.locale.languageCode == 'zh' && animeSource.enableTagsTranslate;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text("Information".tl),
          ),
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
                  buildTag(
                    text: enableTranslation
                        ? TagsTranslation.translationTagWithNamespace(
                            tag,
                            e.key.toLowerCase(),
                          )
                        : tag,
                    onTap: () => onTapTag(tag, e.key),
                  ),
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
          const SizedBox(height: 12),
          const Divider(),
        ],
      ),
    );
  }

  Widget buildEpisodes() {
    if (anime.episode == null) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return const _AnimeEpisodes();
  }

  Widget buildRecommend() {
    if (anime.recommend == null || anime.recommend!.isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
        child: ListTile(
          title: Text("Related".tl),
        ),
      ),
      SliverGridAnimes(animes: anime.recommend!),
    ]);
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
    this.isLoading,
    this.iconColor,
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
    Widget buildContainer(double? width, double? height,
        {Color? color, double? radius}) {
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
          Appbar(title: Text(""), backgroundColor: context.colorScheme.surface),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          if (context.width < changePoint)
            Row(
              children: [
                Expanded(
                  child: buildContainer(null, 36, radius: 18),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildContainer(null, 36, radius: 18),
                ),
              ],
            ).paddingHorizontal(16),
          const Divider(),
          const SizedBox(height: 8),
          Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
            ).fixHeight(24).fixWidth(24),
          )
        ],
      ),
    );
  }

  Widget buildImage(BuildContext context) {
    Widget child;
    if (cover != null) {
      child = AnimatedImage(
        image: CachedImageProvider(
          cover!,
          sourceKey: sourceKey,
          aid: aid,
        ),
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
