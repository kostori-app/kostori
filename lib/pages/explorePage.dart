import 'package:flutter/material.dart';
import 'package:kostori/network/base_anime.dart';
import 'package:kostori/pages/search_result_page.dart';
import 'package:kostori/tools/extensions.dart';

import '../anime_source/anime_source.dart';
import '../base.dart';
import '../components/components.dart';
import '../foundation/app.dart';
// import '../foundation/state_controller.dart';
import '../network/res.dart';
import 'category_animes_page.dart';

class Explorepage extends StatefulWidget {
  const Explorepage({super.key});

  @override
  State<Explorepage> createState() => _ExplorepageState();
}

class _ExplorepageState extends State<Explorepage>
    with TickerProviderStateMixin {
  late TabController controller;

  bool showFB = true;

  double location = 0;

  var pages = appdata.appSettings.explorePages;

  @override
  void initState() {
    // 打印原始设置
    print("原始设置: ${appdata.appSettings.explorePages}");

    // 获取 pages
    pages = appdata.appSettings.explorePages;

    // 打印获取的 pages
    // print("打印获取的 pages: $pages");

    var all = AnimeSource.sources
        .map((e) => e.explorePages)
        .expand((e) => e.map((e) => e.title))
        .toList();

    // print("打印所有可用的 explorePages: $all");
    // print("打印筛选前的: $pages");

    pages = pages.where((e) => all.contains(e)).toList();

    // print("打印筛选后的: $pages");

    // print("条件判断: pages.isEmpty -> ${pages.isEmpty}");
    // print(
    //     "条件判断: explorePages.isNotEmpty -> ${appdata.appSettings.explorePages.isNotEmpty}");
    // print(
    //     "条件判断: pages.isEmpty && explorePages.isNotEmpty -> ${pages.isEmpty && appdata.appSettings.explorePages.isNotEmpty}");
    if (pages.isEmpty && appdata.appSettings.explorePages.isNotEmpty) {
      if (appdata.appSettings.explorePages.first.isNum) {
        // is odd data, update
        appdata.appSettings.explorePages = all;
        pages = all;
        appdata.updateSettings();
      }
    }

    controller = TabController(
      length: pages.length,
      vsync: this,
    );

    // print("打印最终的 pages: $pages");
    // print("打印最终的 controller 的长度: ${controller.length}");

    super.initState();
  }

  /// 刷新当前页面的内容
  void refresh() {
    // 获取当前选中的页面索引
    int page = controller.index;

    // 根据索引获取当前页面的 ID
    String currentPageId = pages[page];

    // 调用对应页面的 SimpleController 的 refresh 方法来刷新内容
    StateController.find<SimpleController>(tag: currentPageId).refresh();
  }

  /// 构建悬浮操作按钮（FAB）
  Widget buildFAB() => Material(
        color: Colors.transparent, // 设置背景为透明
        child: FloatingActionButton(
          key: const Key("FAB"), // 设置 FAB 的唯一键
          onPressed: refresh, // 点击 FAB 时调用 refresh 方法
          child: const Icon(Icons.refresh), // FAB 的图标为刷新图标
        ),
      );

  /// 构建一个标签（Tab）
  Tab buildTab(String i) {
    return Tab(text: i, key: Key(i)); // 创建一个带有文本和唯一键的 Tab
  }

  /// 构建页面的主体内容
  Widget buildBody(String i) =>
      _SingleExplorePage(i, key: Key(i)); // 返回一个包含单个探索页面的 Widget

  @override
  Widget build(BuildContext context) {
    // 创建标签栏
    Widget tabBar = Material(
      child: FilledTabBar(
        // 使用 pages 列表构建标签
        tabs: pages.map((e) => buildTab(e)).toList(),
        controller: controller, // 绑定控制器
      ),
    );

    return Stack(
      children: [
        // 页面主体
        Positioned.fill(
            child: Column(
          children: [
            tabBar, // 显示标签栏
            Expanded(
              // 用于显示 TabBarView
              child: NotificationListener<ScrollNotification>(
                onNotification: (notifications) {
                  // 检测到水平滚动通知
                  if (notifications.metrics.axis == Axis.horizontal) {
                    // 如果当前 FAB 不可见，则显示 FAB
                    if (!showFB) {
                      setState(() {
                        showFB = true; // 更新状态以显示 FAB
                      });
                    }
                    return true; // 消费通知
                  }

                  // 获取当前滚动位置
                  var current = notifications.metrics.pixels;

                  // 如果向下滚动并且 FAB 当前可见，则隐藏 FAB
                  if ((current > location && current != 0) && showFB) {
                    setState(() {
                      showFB = false; // 更新状态以隐藏 FAB
                    });
                  }
                  // 如果向上滚动或者在顶部并且 FAB 当前不可见，则显示 FAB
                  else if ((current < location || current == 0) && !showFB) {
                    setState(() {
                      showFB = true; // 更新状态以显示 FAB
                    });
                  }

                  location = current; // 更新位置状态
                  return false; // 不消费通知
                },
                child: MediaQuery.removePadding(
                  // 移除顶部的内边距
                  context: context,
                  removeTop: true,
                  child: TabBarView(
                    controller: controller, // 绑定控制器
                    children:
                        pages.map((e) => buildBody(e)).toList(), // 显示 Tab 内容
                  ),
                ),
              ),
            )
          ],
        )),
        // 悬浮操作按钮（FAB）
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedSwitcher(
            // 动画持续时间
            duration: const Duration(milliseconds: 150),
            reverseDuration: const Duration(milliseconds: 150),
            // 根据状态显示或隐藏 FAB
            child: showFB ? buildFAB() : const SizedBox(),
            transitionBuilder: (widget, animation) {
              // 定义动画效果
              var tween = Tween<Offset>(
                  begin: const Offset(0, 1), end: const Offset(0, 0));
              return SlideTransition(
                position: tween.animate(animation), // 使用位移动画
                child: widget,
              );
            },
          ),
        )
      ],
    );
  }
}

class _SingleExplorePage extends StatefulWidget {
  const _SingleExplorePage(this.title, {super.key});

  final String title; // 页面标题

  @override
  State<_SingleExplorePage> createState() => _SingleExplorePageState();
}

class _SingleExplorePageState extends StateWithController<_SingleExplorePage> {
  late final ExplorePageData data; // 存储页面数据

  bool loading = true; // 加载状态

  String? message; // 网络错误信息

  List<ExplorePagePart>? parts; // 页面部分数据

  late final String animeSourceKey; // 动漫来源的关键字

  int key = 0; // 用于控制页面状态的关键字

  @override
  void initState() {
    super.initState();
    // 在初始化时查找与标题匹配的页面数据
    for (var source in AnimeSource.sources) {
      for (var d in source.explorePages) {
        if (d.title == widget.title) {
          data = d; // 找到页面数据
          animeSourceKey = source.key; // 存储来源关键字
          return;
        }
      }
    }
    throw "Explore Page ${widget.title} Not Found!"; // 未找到页面数据时抛出异常
  }

  @override
  Widget build(BuildContext context) {
    // 根据页面类型构建相应的组件
    if (data.loadMultiPart != null) {
      return buildMultiPart(); // 构建多部分页面
    } else if (data.loadPage != null) {
      return buildAnimeList(); // 构建动漫列表页面
    } else if (data.loadMixed != null) {
      return _MixedExplorePage(
        data,
        animeSourceKey,
        key: ValueKey(key), // 使用关键字作为页面的唯一标识
      );
    } else if (data.overridePageBuilder != null) {
      return Builder(
        builder: (context) {
          return data.overridePageBuilder!(context); // 使用自定义构建器构建页面
        },
        key: ValueKey(key),
      );
    } else {
      return const Center(
        child: Text("空页"), // 默认情况下返回一个空页
      );
    }
  }

  // 构建动漫列表
  Widget buildAnimeList() =>
      _AnimeList(data.loadPage!, tag.toString(), animeSourceKey);

  // 加载数据
  void load() async {
    var res = await data.loadMultiPart!(); // 异步加载多部分数据
    loading = false; // 设置加载状态为 false
    if (mounted) {
      setState(() {
        if (res.error) {
          message = res.errorMessageWithoutNull; // 保存错误信息
        } else {
          parts = res.data; // 保存加载的数据
        }
      });
    }
  }

  // 构建多部分页面
  Widget buildMultiPart() {
    if (loading) {
      load(); // 加载数据
      return const Center(
        child: CircularProgressIndicator(), // 显示加载指示器
      );
    } else if (message != null) {
      return NetworkError(
        message: message!, // 显示网络错误信息
        retry: refresh, // 重新加载的回调
        withAppbar: false,
      );
    } else {
      return buildPage(); // 构建页面
    }
  }

  // 构建页面
  Widget buildPage() {
    return SmoothCustomScrollView(
      slivers: _buildPage().toList(), // 使用构建的 slivers 列表
    );
  }

  // 生成页面的 slivers
  Iterable<Widget> _buildPage() sync* {
    for (var part in parts!) {
      yield* _buildExplorePagePart(part, animeSourceKey); // 迭代生成每个部分
    }
  }

  @override
  Object? get tag => widget.title; // 页面标签

  // 刷新页面
  @override
  void refresh() {
    message = null; // 清除错误信息
    if (data.loadMultiPart != null) {
      setState(() {
        loading = true; // 设置为加载状态
      });
    } else if (data.loadPage != null) {
      StateController.findOrNull<AnimesPageLogic>(tag: tag.toString())
          ?.refresh(); // 刷新动漫列表页面
    } else {
      setState(() {
        key++; // 增加关键字以强制刷新页面
      });
    }
  }
}

class _AnimeList extends AnimesPage<BaseAnime> {
  const _AnimeList(this.builder, this.tag, this.sourceKey);

  @override
  final String tag; // 页面标签

  final AnimeListBuilder builder; // 用于构建动漫列表的函数

  @override
  final String sourceKey; // 动漫来源的关键字

  // 获取动漫数据的方法，使用 builder 进行数据请求
  @override
  Future<Res<List<BaseAnime>>> getAnimes(int i) {
    return builder(i); // 调用 builder 函数获取第 i 页的数据
  }

  @override
  String? get title => null; // 标题为 null
}

// 混合探索页面
class _MixedExplorePage extends StatefulWidget {
  const _MixedExplorePage(this.data, this.sourceKey, {super.key});

  final ExplorePageData data; // 页面数据

  final String sourceKey; // 动漫来源的关键字

  @override
  State<_MixedExplorePage> createState() => _MixedExplorePageState();
}

class _MixedExplorePageState
    extends MultiPageLoadingState<_MixedExplorePage, Object> {
  // 构建 slivers 的方法，返回 Widget 列表
  Iterable<Widget> buildSlivers(BuildContext context, List<Object> data) sync* {
    List<BaseAnime> cache = []; // 缓存动漫列表
    for (var part in data) {
      if (part is ExplorePagePart) {
        // 如果是 ExplorePagePart 类型
        if (cache.isNotEmpty) {
          yield SliverGridAnimes(
            animes: (cache), // 返回缓存的动漫列表
            sourceKey: widget.sourceKey,
          );
          yield const SliverToBoxAdapter(child: Divider()); // 添加分隔符
          cache.clear(); // 清空缓存
        }
        yield* _buildExplorePagePart(
            part, widget.sourceKey); // 构建 ExplorePagePart 的内容
        yield const SliverToBoxAdapter(child: Divider()); // 添加分隔符
      } else {
        // 如果是动漫列表类型，添加到缓存中
        cache.addAll(part as List<BaseAnime>);
      }
    }
    // 如果缓存中还有数据，构建最后一个 SliverGridAnimes
    if (cache.isNotEmpty) {
      yield SliverGridAnimes(
        animes: (cache),
        sourceKey: widget.sourceKey,
      );
    }
  }

  @override
  Widget buildContent(BuildContext context, List<Object> data) {
    // 构建内容
    return SmoothCustomScrollView(
      slivers: [
        ...buildSlivers(context, data), // 将 slivers 添加到 ScrollView 中
        if (haveNextPage)
          const ListLoadingIndicator().toSliver() // 如果有下一页，添加加载指示器
      ],
    );
  }

  @override
  Future<Res<List<Object>>> loadData(int page) async {
    // 加载数据的方法
    var res = await widget.data.loadMixed!(page); // 调用 loadMixed 方法获取数据
    if (res.error) {
      return res; // 如果有错误，直接返回
    }
    // 验证返回的数据类型
    for (var element in res.data) {
      if (element is! ExplorePagePart && element is! List<BaseAnime>) {
        return const Res.error(
            "function loadMixed return invalid data"); // 验证失败时返回错误
      }
    }
    return res; // 返回加载的数据
  }
}

/// 构建探索页面部分的 Widget。
///
/// [part] 是包含该部分内容的 ExplorePagePart 对象。
/// [sourceKey] 是数据源的唯一标识符。
Iterable<Widget> _buildExplorePagePart(
    ExplorePagePart part, String sourceKey) sync* {
  /// 构建标题的 Widget。
  ///
  /// [part] 是包含标题信息的 ExplorePagePart 对象。
  Widget buildTitle(ExplorePagePart part) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 60, // 设置标题的高度
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 5, 10), // 设置内边距
          child: Row(
            children: [
              // 显示标题文本
              Text(
                part.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w500), // 设置标题样式
              ),
              const Spacer(), // 在标题和按钮之间添加空间

              // 如果 part.viewMore 不为空，则显示“查看更多”按钮
              if (part.viewMore != null)
                TextButton(
                  onPressed: () {
                    // 获取当前上下文
                    var context = App.mainNavigatorKey!.currentContext!;

                    // 根据 viewMore 的前缀导航到不同的页面
                    if (part.viewMore!.startsWith("search:")) {
                      // 导航到搜索结果页面
                      context.to(
                        () => SearchResultPage(
                          keyword: part.viewMore!
                              .replaceFirst("search:", ""), // 获取搜索关键字
                          sourceKey: sourceKey,
                        ),
                      );
                    } else if (part.viewMore!.startsWith("category:")) {
                      // 导航到类别动画页面
                      var cp = part.viewMore!.replaceFirst("category:", "");
                      var c = cp.split('@').first; // 获取类别
                      String? p = cp.split('@').last; // 获取参数
                      if (p == c) {
                        p = null; // 如果参数与类别相同，则设置为 null
                      }
                      context.to(
                        () => CategoryAnimesPage(
                          category: c,
                          categoryKey: AnimeSource.find(sourceKey)!
                              .categoryData!
                              .key, // 获取类别键
                          param: p, // 传递参数
                        ),
                      );
                    }
                  },
                  child: Text("查看更多"), // 按钮文本
                )
            ],
          ),
        ),
      ),
    );
  }

  /// 构建动画内容的 Widget。
  ///
  /// [part] 是包含动画列表的 ExplorePagePart 对象。
  Widget buildAnimes(ExplorePagePart part) {
    return SliverGridAnimes(
        animes: part.animes, sourceKey: sourceKey); // 返回动画网格
  }

  // 构建标题并生成 Widget
  yield buildTitle(part);

  // 构建动画内容并生成 Widget
  yield buildAnimes(part);
}
