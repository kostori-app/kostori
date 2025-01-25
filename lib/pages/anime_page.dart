import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/utils.dart';
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
import 'package:kostori/foundation/local.dart';
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
import 'package:sliver_tools/sliver_tools.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'bangumi/bangumi.dart';
import 'bangumi/bangumi_item.dart';
import 'bangumi/bottom_info.dart';

class AnimePage extends StatefulWidget {
  const AnimePage({
    super.key,
    required this.id,
    required this.sourceKey,
    this.cover,
    this.title,
  });

  final String id;

  final String sourceKey;

  final String? cover;

  final String? title;

  @override
  State<AnimePage> createState() => _AnimePageState();
}

class _AnimePageState extends LoadingState<AnimePage, AnimeDetails>
    with _AnimePageActions {
  bool showAppbarTitle = false;

  var scrollController = ScrollController();

  bool isDownloaded = false;

  void updateHistory() async {
    var newHistory = await HistoryManager()
        .find(widget.id, AnimeType(widget.sourceKey.hashCode));
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
      HistoryManager().addHistory(history!);
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
    if (widget.sourceKey == 'local') {
      var localAnime = LocalManager().find(widget.id, AnimeType.local);
      if (localAnime == null) {
        return const Res.error('Local anime not found');
      }
      if (isFirst) {
        Future.microtask(() {
          App.mainNavigatorKey!.currentContext!.pop();
        });
        isFirst = false;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      return const Res.error('Local anime');
    }
    var animeSource = AnimeSource.find(widget.sourceKey);
    if (animeSource == null) {
      return const Res.error('Anime source not found');
    }
    isAddToLocalFav = LocalFavoritesManager().isExist(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    );
    history = await HistoryManager()
        .find(widget.id, AnimeType(widget.sourceKey.hashCode));
    return animeSource.loadAnimeInfo!(widget.id);
  }

  @override
  Future<void> onDataLoaded() async {
    isLiked = anime.isLiked ?? false;
    isFavorite = anime.isFavorite ?? false;
    if (anime.episode == null) {
      isDownloaded = LocalManager().isDownloaded(
        anime.id,
        anime.animeType,
        0,
      );
    }
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

    yield Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 16),
        Material(
          color: Colors.transparent, // 背景透明，保持原样
          child: InkWell(
            borderRadius: BorderRadius.circular(8), // 匹配 Container 的圆角
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    contentPadding: EdgeInsets.all(0), // 移除默认的内边距，避免影响布局
                    content: Column(
                      mainAxisSize: MainAxisSize.min, // 使内容大小适应图片和文本
                      children: [
                        Padding(
                          padding: EdgeInsets.all(20), // 给图片加上padding，防止超出边框
                          child: InteractiveViewer(
                            panEnabled: true,
                            // 启用平移
                            boundaryMargin: EdgeInsets.all(20),
                            // 设置边界，避免拖动过远
                            minScale: 0.1,
                            // 设置最小缩放比例
                            maxScale: 8.0,
                            // 设置最大缩放比例
                            clipBehavior: Clip.hardEdge,
                            // 防止超出边框，裁剪超出部分
                            child: Image.network(
                              anime.cover, // 图片 URL
                              fit: BoxFit.contain, // 确保完整显示图片
                              height: App.isDesktop
                                  ? MediaQuery.of(context).size.height * 0.7
                                  : MediaQuery.of(context).size.height *
                                      0.45, // 设置高度
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            anime.title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(), // 关闭 dialog
                        child: Text("Close".tl),
                      ),
                    ],
                  );
                },
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              height: 144,
              width: 144 * 0.72,
              clipBehavior: Clip.antiAlias,
              child: AnimatedImage(
                image: CachedImageProvider(
                  anime.cover,
                  sourceKey: anime.sourceKey,
                ),
                width: double.infinity,
                height: double.infinity,
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

                  context.to(() => SearchResultPage(
                        text: anime.title,
                        sourceKey: animeSource.key,
                        options: const [],
                      ));
                },
                onLongPress: () {
                  // 将文本复制到剪贴板
                  Clipboard.setData(ClipboardData(text: anime.title));
                  // 显示一个提示消息
                  SmartDialog.showNotify(
                      msg: '已复制到剪贴板.', notifyType: NotifyType.success);
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
              const SizedBox(height: 58),
              SizedBox(
                  child: Column(children: [
                Wrap(
                  children: [
                    ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
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
                          iconColor: context.useTextColor(Colors.blue),
                        ),
                        if (anime.url != null)
                          _ActionButton(
                            icon: const Icon(Icons.open_in_browser),
                            text: 'Open in Browser'.tl,
                            onPressed: () => launchUrlString(anime.url!),
                            iconColor: context.useTextColor(Colors.blueGrey),
                          ),
                      ],
                    ).fixHeight(48),
                    // const Divider(),
                  ],
                )
              ]))
            ],
          ),
        ),
        const Divider(),
      ],
    ).toSliver();
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

abstract mixin class _AnimePageActions {
  void update();

  AnimeDetails get anime;

  AnimeSource get animeSource => AnimeSource.find(anime.sourceKey)!;

  History? history;

  bool isLiking = false;

  bool isLiked = false;

  void likeOrUnlike() async {
    if (isLiking) return;
    isLiking = true;
    update();
    var res = await animeSource.likeOrUnlikeAnime!(anime.id, isLiked);
    if (res.error) {
      App.rootContext.showMessage(message: res.errorMessage!);
    } else {
      isLiked = !isLiked;
    }
    isLiking = false;
    update();
  }

  bool isAddToLocalFav = false;

  bool isFavorite = false;

  FavoriteItem _toFavoriteItem() {
    var tags = <String>[];
    for (var e in anime.tags.entries) {
      tags.addAll(e.value.map((tag) => '${e.key}:$tag'));
    }
    return FavoriteItem(
      id: anime.id,
      name: anime.title,
      coverPath: anime.cover,
      author: anime.subTitle ?? anime.uploader ?? '',
      type: anime.animeType,
      tags: tags,
    );
  }

  void openFavPanel() {
    showSideBar(
      App.rootContext,
      _FavoritePanel(
        cid: anime.id,
        type: anime.animeType,
        isFavorite: isFavorite,
        onFavorite: (local, network) {
          isFavorite = network ?? isFavorite;
          isAddToLocalFav = local ?? isAddToLocalFav;
          update();
        },
        favoriteItem: _toFavoriteItem(),
      ),
    );
  }

  void quickFavorite() {
    var folder = appdata.settings['quickFavorite'];
    if (folder is! String) {
      return;
    }
    LocalFavoritesManager().addAnime(
      folder,
      _toFavoriteItem(),
    );
    isAddToLocalFav = true;
    update();
    App.rootContext.showMessage(message: "Added".tl);
  }

  Future<void> bangumiBottomInfo(BuildContext context) async {
    var bangumiId = history!.bangumiId;
    showModalBottomSheet(
      isScrollControlled: true,
      enableDrag: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4, // 设置最大高度
        maxWidth: (App.isDesktop)
            ? MediaQuery.of(context).size.width * 9 / 16 // 设置最大宽度
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 自定义顶部区域
            Container(
              padding:
                  EdgeInsets.only(left: 20, top: 12, right: 20, bottom: 12),
              height: 60, // 自定义顶部区域高度
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)), // 圆角效果
              ),
              child: Row(children: [
                const Image(
                  image: AssetImage("assets/app_icon.png"),
                  filterQuality: FilterQuality.medium,
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    bangumiBottomInfoSelect(context);
                  }, // 按钮点击事件
                  child: Text('Match Bangumi ID'.tl), // 按钮文本
                ),
              ]),
            ),
            // 下面是 BottomInfo 内容
            Expanded(
                child: BottomInfo(
              bangumiId: bangumiId,
            )),
          ],
        );
      },
    );
  }

  // 显示 BottomSheet，并允许选择一个项目
  Future<void> bangumiBottomInfoSelect(BuildContext context) async {
    var res = await Bangumi.bangumiGetSearch(anime.title);

    // 如果 res 是 null 或者数据不正确，显示检索失败提示
    if (res.isEmpty) {
      SmartDialog.showNotify(
        msg: '检索失败，请稍后再试（一直捅 API 会出问题）...',
        notifyType: NotifyType.error,
      );
      return; // 如果数据无效，直接返回，不继续执行后续代码
    }

    // 显示 BottomSheet
    final selectedItem = await showModalBottomSheet<BangumiItem>(
      isScrollControlled: true,
      enableDrag: false,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 3 / 4, // 设置最大高度
        maxWidth: (App.isDesktop)
            ? MediaQuery.of(context).size.width * 9 / 16 // 设置最大宽度
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (context) {
        // 使用 StatefulBuilder 实现搜索框和动态搜索功能
        return StatefulBuilder(
          builder: (context, setState) {
            // 更新搜索结果的函数
            Future<void> fetchSearchResults(String query) async {
              if (query.isEmpty) {
                // 如果搜索框为空，则默认展示初始数据
                res = await Bangumi.bangumiGetSearch(anime.title);
              } else {
                // 否则根据用户输入重新搜索
                res = await Bangumi.bangumiGetSearch(query);
              }

              // 如果搜索结果为空，提示用户
              if (res.isEmpty) {
                SmartDialog.showNotify(
                  msg: '未找到相关结果，请尝试其他关键字',
                  notifyType: NotifyType.warning,
                );
              }

              // 更新状态
              setState(() {});
            }

            return SingleChildScrollView(
              clipBehavior: Clip.antiAlias,
              child: Container(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 搜索框部分
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: '搜索',
                          hintText: '请输入关键字进行搜索',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        onSubmitted: (query) {
                          fetchSearchResults(query); // 用户提交时重新搜索
                        },
                      ),
                    ),
                    // 搜索结果列表
                    if (res.isNotEmpty)
                      ...res.map((item) {
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context, item); // 返回选中的项
                          },
                          splashColor: Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .toOpacity(0.72),
                          highlightColor: Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .toOpacity(0.72),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 12.0),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                double height = constraints.maxWidth *
                                    (App.isDesktop
                                        ? (constraints.maxWidth > 1024
                                            ? 6 / 16
                                            : 10 / 16)
                                        : 10 / 16);
                                double width = height * 0.72;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        item.images['large']!,
                                        width: width,
                                        height: height,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    SizedBox(width: 12.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Bangumi ID: ${item.id}',
                                            style: TextStyle(
                                              fontSize: 18.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            item.nameCn,
                                            style: TextStyle(
                                              fontSize: 18.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            item.name,
                                            style: TextStyle(
                                              fontSize: 14.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      })
                    else
                      Center(
                        child: Text(
                          '暂无搜索结果',
                          style: TextStyle(fontSize: 16.0, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // 如果用户选择了某个项，执行相关操作
    if (selectedItem != null) {
      await handleSelection(context, selectedItem);
    }
  }

  // 处理选择后的操作
  Future<void> handleSelection(BuildContext context, BangumiItem item) async {
    // 模拟延迟操作，可以替换成其他操作（如网络请求等）
    // await Future.delayed(Duration(seconds: 1));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Determine the binding: @a ?'.tlParams({
            "a": item.name,
          })),
          content: Text(item.airDate),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  if (history != null) {
                    history!.bangumiId = item.id;
                    HistoryManager().addHistory(history!);
                    WatcherState.currentState!.bangumiId = item.id;
                    BottomInfoState.currentState?.upDate(item.id);
                  }
                } catch (e) {
                  Log.addLog(LogLevel.error, "绑定bangumiId", "$e");
                }

                SmartDialog.showToast('绑定bangumiId成功');
                Navigator.pop(context);
              },
              child: Text('Ok'.tl),
            ),
            TextButton(
              onPressed: () => {Navigator.pop(context)},
              child: Text('Close'.tl),
            ),
          ],
        );
      },
    );
  }

  Future<void> share() async {
    shareImage();
  }

  final GlobalKey _repaintKey = GlobalKey();

  void shareImage() {
    showPopUpWidget(
      App.rootContext,
      StatefulBuilder(builder: (context, setState) {
        if (history!.bangumiId == null) {
          return PopUpWidgetScaffold(
            title: anime.title,
            body: Column(
              children: [
                RepaintBoundary(
                  key: _repaintKey,
                  child: Padding(
                    padding:
                        EdgeInsets.only(bottom: context.padding.bottom + 16),
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: 16),
                                //封面
                                Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          context.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    height: 256,
                                    width: 256 * 0.72,
                                    clipBehavior: Clip.antiAlias,
                                    child: AnimatedImage(
                                      image: CachedImageProvider(
                                        anime.cover,
                                        sourceKey: anime.sourceKey,
                                      ),
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        //标题
                                        Text(
                                          anime.title,
                                          style: ts.s20,
                                        ),
                                        if (anime.subTitle != null)
                                          SelectableText(anime.subTitle!,
                                              style: ts.s14),
                                        //源名称
                                        Text(
                                          (AnimeSource.find(anime.sourceKey)
                                                  ?.name) ??
                                              '',
                                          style: ts.s12,
                                        ),
                                        const SizedBox(height: 16),
                                        if (history?.bangumiId == null)
                                          Text(
                                            anime.tags.entries.map((entry) {
                                              // 对每个键值对，创建一个字符串表示形式
                                              return '${entry.key}: ${entry.value.join(', ')}';
                                            }).join('\n'), // 用换行符分隔每个键值对
                                            style: ts.s12,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(),
                              ],
                            ),
                          ),
                          Text(
                            '简介',
                            style: ts.s18,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                            child: SelectableText(anime.description!)
                                .fixWidth(double.infinity),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Spacer(), // 使用 Spacer 将按钮区域移至弹出框外
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Spacer(),
                      FilledButton(
                        onPressed: () {
                          _captureAndSave();
                          App.rootContext.pop();
                        },
                        child: Text('Share'.tl),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<BangumiItem?>(
          future: Bangumi.getBangumiInfoByID(history!.bangumiId as int),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return PopUpWidgetScaffold(
                title: anime.title,
                body:
                    Center(child: CircularProgressIndicator()), // Loading state
              );
            } else if (snapshot.hasError) {
              return PopUpWidgetScaffold(
                title: anime.title,
                body: Center(
                    child: Text('Error: ${snapshot.error}')), // Error state
              );
            } else if (!snapshot.hasData) {
              return PopUpWidgetScaffold(
                title: anime.title,
                body: Center(child: Text('No data available')), // No data state
              );
            }

            final bangumiItem = snapshot.data; // Successfully loaded data

            return PopUpWidgetScaffold(
              title: anime.title,
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: _repaintKey,
                      child: Padding(
                        padding: EdgeInsets.only(
                            bottom: context.padding.bottom + 16),
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: Column(
                            children: [
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: LayoutBuilder(
                                      builder: (context, constraints) {
                                    double height = constraints.maxWidth / 2;
                                    double width = height * 0.72;
                                    return Container(
                                      width: constraints.maxWidth,
                                      height: height,
                                      padding: EdgeInsets.all(2),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(width: 16),
                                          //封面
                                          Material(
                                            color: Colors.transparent,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: context.colorScheme
                                                    .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              height: height,
                                              width: width,
                                              clipBehavior: Clip.antiAlias,
                                              child: AnimatedImage(
                                                image: CachedImageProvider(
                                                  anime.cover,
                                                  sourceKey: anime.sourceKey,
                                                ),
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  //标题
                                                  Text(
                                                    anime.title,
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  if (history?.bangumiId !=
                                                          null &&
                                                      bangumiItem != null)
                                                    Text(bangumiItem.name,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        )),
                                                  //源名称
                                                  Text(
                                                    (AnimeSource.find(
                                                                anime.sourceKey)
                                                            ?.name) ??
                                                        '',
                                                    style: ts.s12,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  if (history?.bangumiId !=
                                                          null &&
                                                      bangumiItem != null)
                                                    Container(
                                                      padding:
                                                          EdgeInsets.all(8.0),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16.0),
                                                        border: Border.all(
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .secondaryContainer
                                                              .toOpacity(0.72),
                                                          width: 2.0,
                                                        ),
                                                      ),
                                                      child: Text(
                                                          bangumiItem.airDate),
                                                    ),
                                                  SizedBox(height: 12.0),
                                                  if (history?.bangumiId !=
                                                          null &&
                                                      bangumiItem != null)
                                                    Text(
                                                        '预定全 ${bangumiItem.totalEpisodes} 话',
                                                        style: TextStyle(
                                                          fontSize: 14.0,
                                                        )),
                                                  Spacer(),
                                                  if (history?.bangumiId !=
                                                          null &&
                                                      bangumiItem != null)
                                                    Align(
                                                      alignment:
                                                          Alignment.bottomRight,
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            '${bangumiItem.score}',
                                                            style: TextStyle(
                                                              fontSize: 32.0,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: 5,
                                                          ),
                                                          Container(
                                                            padding:
                                                                EdgeInsets.all(
                                                                    2.0),
                                                            // 可选，设置内边距
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              // 设置圆角半径
                                                              border:
                                                                  Border.all(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .secondaryContainer
                                                                    .toOpacity(
                                                                        0.72),
                                                                width:
                                                                    2.0, // 设置边框宽度
                                                              ),
                                                            ),
                                                            child: Text(
                                                              Utils.getRatingLabel(
                                                                  bangumiItem
                                                                      .score),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: 4,
                                                          ),
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end, // 右对齐
                                                            children: [
                                                              RatingBarIndicator(
                                                                itemCount: 5,
                                                                rating: bangumiItem
                                                                        .score
                                                                        .toDouble() /
                                                                    2,
                                                                itemBuilder: (context,
                                                                        index) =>
                                                                    const Icon(
                                                                  Icons
                                                                      .star_rounded,
                                                                ),
                                                                itemSize: 20.0,
                                                              ),
                                                              Text(
                                                                '${bangumiItem.total} 人评 | #${bangumiItem.rank}',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        12),
                                                              )
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 16),
                                  child: Align(
                                    child: Row(
                                      children: [
                                        Text(
                                            '${bangumiItem.collection?['doing']} 在看',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            )),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection?['collect']} 看过',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error)),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection?['wish']} 想看',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueAccent)),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection?['on_hold']} 搁置',
                                            style: TextStyle(fontSize: 12)),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection?['dropped']} 抛弃',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            )),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection!['doing']! + bangumiItem.collection!['collect']! + bangumiItem.collection!['wish']! + bangumiItem.collection!['on_hold']! + bangumiItem.collection!['dropped']!} 总计数',
                                            style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              Text(
                                '简介',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                                child: SelectableText(anime.description!)
                                    .fixWidth(double.infinity),
                              ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                SizedBox(
                                  height: 12,
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                Text(
                                  '标签',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                SizedBox(
                                  height: 12,
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                Wrap(
                                    spacing: 8.0,
                                    runSpacing: App.isDesktop ? 8 : 0,
                                    children: List<Widget>.generate(
                                        bangumiItem.tags.length, (int index) {
                                      return Chip(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                                '${bangumiItem.tags[index].name} '),
                                            Text(
                                              '${bangumiItem.tags[index].count}',
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList()),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                SizedBox(
                                  height: 12,
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                Text(
                                  '评分统计图',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                SizedBox(
                                  height: 12,
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                LineChatPage(
                                  bangumiItem: bangumiItem,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    // Spacer(), // 使用 Spacer 将按钮区域移至弹出框外
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Spacer(),
                          FilledButton(
                            onPressed: () {
                              _captureAndSave();
                              App.rootContext.pop();
                            },
                            child: Text('Share'.tl),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // 截取图像并保存
  Future<void> _captureAndSave() async {
    try {
      RenderRepaintBoundary boundary = _repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary;

      // 获取截图数据
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List uint8List = byteData!.buffer.asUint8List();

      // 保存文件
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/popup_image.png');
      await file.writeAsBytes(uint8List);
      //     // 使用 shareFile 函数分享文件
      Uint8List data = await file.readAsBytes();
      Share.shareFile(data: data, filename: 'image.jpg', mime: 'image/jpeg');
      Log.addLog(LogLevel.info, '截图保存', file.path);
    } catch (e) {
      Log.addLog(LogLevel.error, '截图失败', '$e');
    }
  }

  /// read the anime
  ///
  /// [ep] the episode number, start from 1
  ///
  /// [page] the page number, start from 1
  void watch([int? ep, int? road]) {
    WatcherState.currentState!.loadInfo(ep!, road!); // 传递集数
  }

  void onTapTag(String tag, String namespace) {
    var config = animeSource.handleClickTagEvent?.call(namespace, tag) ??
        {
          'action': 'search',
          'keyword': tag,
        };
    var context = App.mainNavigatorKey!.currentContext!;
    if (config['action'] == 'search') {
      context.to(() => SearchResultPage(
            text: config['keyword'] ?? '',
            sourceKey: animeSource.key,
            options: const [],
          ));
    } else if (config['action'] == 'category') {
      context.to(
        () => CategoryAnimesPage(
          category: config['keyword'] ?? '',
          categoryKey: animeSource.categoryData!.key,
          param: config['param'],
        ),
      );
    }
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

class _AnimeEpisodes extends StatefulWidget {
  const _AnimeEpisodes();

  @override
  State<_AnimeEpisodes> createState() => _AnimeEpisodesState();
}

class _AnimeEpisodesState extends State<_AnimeEpisodes> {
  late _AnimePageState state;

  // 当前播放列表的索引，默认为0
  int playList = 0;
  Map<String, String> currentEps = {};
  int length = 0;
  bool reverse = false;
  bool showAll = false;

  @override
  void didChangeDependencies() {
    state = context.findAncestorStateOfType<_AnimePageState>()!;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    // 获取所有播放列表（例如，ep1, ep2, ep3...）
    state.anime.episode?.keys.toList();
    final episodeValues = state.anime.episode?.values.elementAt(playList);

    currentEps = episodeValues!;
    length = currentEps.length;

    if (!showAll) {
      length = math.min(length, 24); // 限制显示的集数
    }

    int currentLength = length;

    return SliverMainAxisGroup(
      slivers: [
        // 显示标题和切换顺序的按钮
        SliverToBoxAdapter(
          child: ListTile(
            title: Row(
              children: [
                Text("Episodes".tl),
                const SizedBox(width: 5),
                SizedBox(
                  height: 34,
                  child: TextButton(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                    ),
                    onPressed: () {
                      SmartDialog.show(
                          useAnimation: false,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('播放列表'),
                              content: StatefulBuilder(builder:
                                  (BuildContext context,
                                      StateSetter innerSetState) {
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 2,
                                  children: [
                                    for (int i = 0;
                                        i < state.anime.episode!.keys.length;
                                        i++) ...<Widget>[
                                      if (i == playList) ...<Widget>[
                                        FilledButton(
                                          onPressed: () {
                                            SmartDialog.dismiss();
                                            setState(() {
                                              playList = i;
                                            });
                                          },
                                          child: Text(state.anime.episode!.keys
                                              .elementAt(i)),
                                        ),
                                      ] else ...[
                                        FilledButton.tonal(
                                          onPressed: () {
                                            SmartDialog.dismiss();
                                            setState(() {
                                              playList = i;
                                            });
                                          },
                                          child: Text(state.anime.episode!.keys
                                              .elementAt(i)),
                                        ),
                                      ]
                                    ]
                                  ],
                                );
                              }),
                            );
                          });
                    },
                    child: Text(
                      state.anime.episode!.keys.elementAt(playList),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                Spacer(),
              ],
            ),
            trailing: Tooltip(
              message: "Order".tl,
              child: IconButton(
                icon: Icon(reverse
                    ? Icons.vertical_align_top
                    : Icons.vertical_align_bottom_outlined),
                onPressed: () {
                  setState(() {
                    reverse = !reverse; // 切换顺序
                  });
                },
              ),
            ),
          ),
        ),

        // 显示播放列表内容的网格
        SliverGrid(
          key: ValueKey(playList),
          delegate: SliverChildBuilderDelegate(
            childCount: currentLength, // 使用更新后的 length
            (context, i) {
              if (i >= currentEps.length) {
                return Container(); // 防止越界
              }

              if (reverse) {
                i = currentEps.length - i - 1; // 反向排序
              }

              var key = currentEps.keys.elementAt(i); // 获取集数名称
              var value = currentEps[key]!; // 获取集数内容
              bool visited =
                  (state.history?.watchEpisode ?? const {}).contains(i + 1);

              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Material(
                  color: context.colorScheme.surfaceContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: InkWell(
                    onTap: () => state.watch(i + 1, playList),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Center(
                        child: Text(
                          value,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: visited ? context.colorScheme.outline : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          gridDelegate: const SliverGridDelegateWithFixedHeight(
              maxCrossAxisExtent: 200, itemHeight: 48),
        ),

        // 显示更多按钮
        if (currentEps.length > 24 && !showAll)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.center,
              child: FilledButton.tonal(
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  )),
                ),
                onPressed: () {
                  setState(() {
                    showAll = true; // 显示更多集数
                  });
                },
                child: Text("${"Show all".tl} (${currentEps.length})"),
              ).paddingTop(12),
            ),
          ),

        const SliverToBoxAdapter(child: Divider()), // 添加分割线
      ],
    );
  }
}

class _FavoritePanel extends StatefulWidget {
  const _FavoritePanel({
    required this.cid,
    required this.type,
    required this.isFavorite,
    required this.onFavorite,
    required this.favoriteItem,
  });

  final String cid;

  final AnimeType type;

  /// whether the anime is in the network favorite list
  ///
  /// if null, the anime source does not support favorite or support multiple favorite lists
  final bool? isFavorite;

  final void Function(bool?, bool?) onFavorite;

  final FavoriteItem favoriteItem;

  @override
  State<_FavoritePanel> createState() => _FavoritePanelState();
}

class _FavoritePanelState extends State<_FavoritePanel> {
  late AnimeSource animeSource;

  @override
  void initState() {
    animeSource = widget.type.animeSource!;
    localFolders = LocalFavoritesManager().folderNames;
    added = LocalFavoritesManager().find(widget.cid, widget.type);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var hasNetwork = animeSource.favoriteData != null && animeSource.isLogged;
    return Scaffold(
      appBar: Appbar(
        title: Text("Favorite".tl),
      ),
      body: DefaultTabController(
        length: hasNetwork ? 2 : 1,
        child: Column(
          children: [
            TabBar(tabs: [
              Tab(text: "Local".tl),
              if (hasNetwork) Tab(text: "Network".tl),
            ]),
            Expanded(
              child: TabBarView(
                children: [
                  buildLocal(),
                  if (hasNetwork) buildNetwork(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  late List<String> localFolders;

  late List<String> added;

  var selectedLocalFolders = <String>{};

  Widget buildLocal() {
    var isRemove = selectedLocalFolders.isNotEmpty &&
        added.contains(selectedLocalFolders.first);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: localFolders.length + 1,
            itemBuilder: (context, index) {
              if (index == localFolders.length) {
                return SizedBox(
                  height: 36,
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        newFolder().then((v) {
                          setState(() {
                            localFolders = LocalFavoritesManager().folderNames;
                          });
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 20),
                          const SizedBox(width: 4),
                          Text("New Folder".tl)
                        ],
                      ),
                    ),
                  ),
                );
              }
              var folder = localFolders[index];
              var disabled = false;
              if (selectedLocalFolders.isNotEmpty) {
                if (added.contains(folder) &&
                    !added.contains(selectedLocalFolders.first)) {
                  disabled = true;
                } else if (!added.contains(folder) &&
                    added.contains(selectedLocalFolders.first)) {
                  disabled = true;
                }
              }
              return CheckboxListTile(
                title: Row(
                  children: [
                    Text(folder),
                    const SizedBox(width: 8),
                    if (added.contains(folder))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text("Added".tl, style: ts.s12),
                      ),
                  ],
                ),
                value: selectedLocalFolders.contains(folder),
                onChanged: disabled
                    ? null
                    : (v) {
                        setState(() {
                          if (v!) {
                            selectedLocalFolders.add(folder);
                          } else {
                            selectedLocalFolders.remove(folder);
                          }
                        });
                      },
              );
            },
          ),
        ),
        Center(
          child: FilledButton(
            onPressed: () {
              if (selectedLocalFolders.isEmpty) {
                return;
              }
              if (isRemove) {
                for (var folder in selectedLocalFolders) {
                  LocalFavoritesManager()
                      .deleteAnimeWithId(folder, widget.cid, widget.type);
                }
                widget.onFavorite(false, null);
              } else {
                for (var folder in selectedLocalFolders) {
                  LocalFavoritesManager().addAnime(folder, widget.favoriteItem);
                }
                widget.onFavorite(true, null);
              }
              context.pop();
            },
            child: isRemove ? Text("Remove".tl) : Text("Add".tl),
          ).paddingVertical(8),
        ),
      ],
    );
  }

  Widget buildNetwork() {
    return _NetworkFavorites(
      cid: widget.cid,
      animeSource: animeSource,
      isFavorite: widget.isFavorite,
      onFavorite: (network) {
        widget.onFavorite(null, network);
      },
    );
  }
}

class _NetworkFavorites extends StatefulWidget {
  const _NetworkFavorites({
    required this.cid,
    required this.animeSource,
    required this.isFavorite,
    required this.onFavorite,
  });

  final String cid;

  final AnimeSource animeSource;

  final bool? isFavorite;

  final void Function(bool) onFavorite;

  @override
  State<_NetworkFavorites> createState() => _NetworkFavoritesState();
}

class _NetworkFavoritesState extends State<_NetworkFavorites> {
  @override
  Widget build(BuildContext context) {
    bool isMultiFolder = widget.animeSource.favoriteData!.loadFolders != null;

    return isMultiFolder ? buildMultiFolder() : buildSingleFolder();
  }

  bool isLoading = false;

  Widget buildSingleFolder() {
    var isFavorite = widget.isFavorite ?? false;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Text(isFavorite ? "Added to favorites".tl : "Not added".tl),
          ),
        ),
        Center(
          child: Button.filled(
            isLoading: isLoading,
            onPressed: () async {
              setState(() {
                isLoading = true;
              });

              var res = await widget.animeSource.favoriteData!
                  .addOrDelFavorite!(widget.cid, '', !isFavorite, null);
              if (res.success) {
                widget.onFavorite(!isFavorite);
                context.pop();
                App.rootContext.showMessage(
                    message: isFavorite ? "Removed".tl : "Added".tl);
              } else {
                setState(() {
                  isLoading = false;
                });
                context.showMessage(message: res.errorMessage!);
              }
            },
            child: isFavorite ? Text("Remove".tl) : Text("Add".tl),
          ).paddingVertical(8),
        ),
      ],
    );
  }

  Map<String, String>? folders;

  var addedFolders = <String>{};

  var isLoadingFolders = true;

  // for network favorites, only one selection is allowed
  String? selected;

  void loadFolders() async {
    var res = await widget.animeSource.favoriteData!.loadFolders!(widget.cid);
    if (res.error) {
      context.showMessage(message: res.errorMessage!);
    } else {
      folders = res.data;
      if (res.subData is List) {
        addedFolders = List<String>.from(res.subData).toSet();
      }
      setState(() {
        isLoadingFolders = false;
      });
    }
  }

  Widget buildMultiFolder() {
    if (isLoadingFolders) {
      loadFolders();
      return const Center(child: CircularProgressIndicator());
    } else {
      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: folders!.length,
              itemBuilder: (context, index) {
                var name = folders!.values.elementAt(index);
                var id = folders!.keys.elementAt(index);
                return CheckboxListTile(
                  title: Row(
                    children: [
                      Text(name),
                      const SizedBox(width: 8),
                      if (addedFolders.contains(id))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text("Added".tl, style: ts.s12),
                        ),
                    ],
                  ),
                  value: selected == id,
                  onChanged: (v) {
                    setState(() {
                      selected = id;
                    });
                  },
                );
              },
            ),
          ),
          Center(
            child: Button.filled(
              isLoading: isLoading,
              onPressed: () async {
                if (selected == null) {
                  return;
                }
                setState(() {
                  isLoading = true;
                });
                var res =
                    await widget.animeSource.favoriteData!.addOrDelFavorite!(
                  widget.cid,
                  selected!,
                  !addedFolders.contains(selected!),
                  null,
                );
                if (res.success) {
                  context.showMessage(message: "Success".tl);
                  context.pop();
                } else {
                  context.showMessage(message: res.errorMessage!);
                  setState(() {
                    isLoading = false;
                  });
                }
              },
              child: selected != null && addedFolders.contains(selected!)
                  ? Text("Remove".tl)
                  : Text("Add".tl),
            ).paddingVertical(8),
          ),
        ],
      );
    }
  }
}

class _SelectDownloadChapter extends StatefulWidget {
  const _SelectDownloadChapter(this.eps, this.finishSelect, this.downloadedEps);

  final List<String> eps;
  final void Function(List<int>) finishSelect;
  final List<int> downloadedEps;

  @override
  State<_SelectDownloadChapter> createState() => _SelectDownloadChapterState();
}

class _SelectDownloadChapterState extends State<_SelectDownloadChapter> {
  List<int> selected = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("Download".tl),
        backgroundColor: context.colorScheme.surfaceContainerLow,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.eps.length,
              itemBuilder: (context, i) {
                return CheckboxListTile(
                    title: Text(widget.eps[i]),
                    value: selected.contains(i) ||
                        widget.downloadedEps.contains(i),
                    onChanged: widget.downloadedEps.contains(i)
                        ? null
                        : (v) {
                            setState(() {
                              if (selected.contains(i)) {
                                selected.remove(i);
                              } else {
                                selected.add(i);
                              }
                            });
                          });
              },
            ),
          ),
          Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: context.colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      var res = <int>[];
                      for (int i = 0; i < widget.eps.length; i++) {
                        if (!widget.downloadedEps.contains(i)) {
                          res.add(i);
                        }
                      }
                      widget.finishSelect(res);
                      context.pop();
                    },
                    child: Text("Download All".tl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () {
                            widget.finishSelect(selected);
                            context.pop();
                          },
                    child: Text("Download Selected".tl),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _CommentsPart extends StatefulWidget {
  const _CommentsPart({
    required this.comments,
    required this.showMore,
  });

  final List<Comment> comments;

  final void Function() showMore;

  @override
  State<_CommentsPart> createState() => _CommentsPartState();
}

class _CommentsPartState extends State<_CommentsPart> {
  final scrollController = ScrollController();

  late List<Comment> comments;

  @override
  void initState() {
    comments = widget.comments;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiSliver(
      children: [
        SliverToBoxAdapter(
          child: ListTile(
            title: Text("Comments".tl),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    scrollController.animateTo(
                      scrollController.position.pixels - 340,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.ease,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    scrollController.animateTo(
                      scrollController.position.pixels + 340,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.ease,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 184,
                child: MediaQuery.removePadding(
                  removeTop: true,
                  context: context,
                  child: ListView.builder(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      return _CommentWidget(comment: comments[index]);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ActionButton(
                icon: const Icon(Icons.comment),
                text: "View more".tl,
                onPressed: widget.showMore,
                iconColor: context.useTextColor(Colors.green),
              ).fixHeight(48).paddingRight(8).toAlign(Alignment.centerRight),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SliverToBoxAdapter(
          child: Divider(),
        ),
      ],
    );
  }
}

class _CommentWidget extends StatelessWidget {
  const _CommentWidget({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 0, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: 324,
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (comment.avatar != null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: context.colorScheme.surfaceContainer,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image(
                    image: CachedImageProvider(comment.avatar!),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ).paddingRight(8),
              Text(comment.userName, style: ts.bold),
            ],
          ),
          const SizedBox(height: 4),
          // Expanded(
          //   child: RichCommentContent(text: comment.content).fixWidth(324),
          // ),
          const SizedBox(height: 4),
          if (comment.time != null)
            Text(comment.time!, style: ts.s12).toAlign(Alignment.centerLeft),
        ],
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
  });

  final String? cover;

  final String? title;

  final String sourceKey;

  final String aid;

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
      tag: "cover$aid$sourceKey",
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
