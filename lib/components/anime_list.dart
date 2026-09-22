import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/cache.dart';
import 'package:kostori/network/cloudflare.dart';

class AnimeList extends StatefulWidget {
  const AnimeList({
    super.key,
    this.loadPage,
    this.loadNext,
    this.leadingSliver,
    this.leadingSlivers,
    this.trailingSliver,
    this.errorLeading,
    this.menuBuilder,
    this.controller,
    this.refreshHandlerCallback,
    this.enablePageStorage = false,
    this.enableFloatingMenu = true,
    this.showLoadedOverlay = true,
    this.manageBottomOverlay = true,
  });

  final Future<Res<List<Anime>>> Function(int page)? loadPage;

  final Future<Res<List<Anime>>> Function(String? next)? loadNext;

  final Widget? leadingSliver;

  /// 多个头部 sliver（逐个加入滚动视图，各自的 pinned 才能生效；
  /// 包在 SliverMainAxisGroup 里时内部 pinned 不起作用，搜索栏就钉不住）
  final List<Widget>? leadingSlivers;

  final Widget? trailingSliver;

  final Widget? errorLeading;

  final List<MenuEntry> Function(Anime)? menuBuilder;

  final ScrollController? controller;

  final void Function(VoidCallback c)? refreshHandlerCallback;

  final bool enablePageStorage;

  /// 是否显示内置的右下角浮动按钮（探索页用页面级 GridSpeedDial，可关闭）
  final bool enableFloatingMenu;

  /// 是否显示右下角信息圆片（页数 / 条目数）。
  final bool showLoadedOverlay;

  /// 是否自行向 NaviPane 上报底部悬浮形态（翻页抬升 / 圆片）。
  /// 探索页由 ExplorePage 统一管理，传 false，避免重复上报。
  final bool manageBottomOverlay;

  @override
  State<AnimeList> createState() => AnimeListState();
}

class AnimeListState extends State<AnimeList>
    with SingleTickerProviderStateMixin {
  int? _maxPage;

  final Map<int, List<Anime>> _data = {};

  int _page = 1;
  int _generation = 0;
  String? _error;

  final Map<int, bool> _loading = {};

  /// 已加载过的条目 key（`sourceKey|id`）：用于识别「空页 / 重复页」，
  /// 避免源一直返回同一批数据时无限翻页请求。
  final Set<String> _loadedKeys = {};

  String? _nextUrl;

  bool showFB = false;

  final scrollController = ScrollController();

  late bool enablePageStorage = widget.enablePageStorage;

  Map<String, dynamic> get state => {
    'maxPage': _maxPage,
    'data': _data,
    'page': _page,
    'error': _error,
    'loading': _loading,
    'nextUrl': _nextUrl,
  };

  void restoreState(Map<String, dynamic>? state) {
    if (state == null || !enablePageStorage) {
      return;
    }
    _maxPage = state['maxPage'];
    _data.clear();
    _data.addAll(state['data']);
    _page = state['page'];
    _error = state['error'];
    _loading.clear();
    _loading.addAll(state['loading']);
    _nextUrl = state['nextUrl'];
    _loadedKeys
      ..clear()
      ..addAll([
        for (final a in _data.values.expand((e) => e)) '${a.sourceKey}|${a.id}',
      ]);
  }

  void storeState() {
    if (enablePageStorage) {
      PageStorage.of(context).writeState(context, state);
    }
  }

  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void refresh() {
    // 用户主动刷新：清掉内存响应缓存，否则同一 URL 会命中 NetworkCacheManager
    // 的 5 秒~2 小时缓存，导致「点了刷新但没有重新请求、内容也不变」
    NetworkCacheManager().clear();
    _generation++;
    _data.clear();
    _loadedKeys.clear();
    _page = 1;
    _maxPage = null;
    _error = null;
    _nextUrl = null;
    _loading.clear();
    storeState();
    setState(() {});
  }

  @override
  void dispose() {
    _overlayNavi?.unregisterOverlay(this);
    scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    restoreState(PageStorage.of(context).readState(context));
    widget.refreshHandlerCallback?.call(refresh);
    _scheduleSyncBottomOverlay();
  }

  NaviPaneState? _overlayNavi;

  /// 首次上报时所属的主导航页下标（之后不再变，避免 keep-alive 期间被改写）
  int? _overlayNavPage;

  bool _overlaySyncScheduled = false;

  /// 合并触发并在帧后执行：注册会调用 NaviPane.setState，不能发生在 build 期。
  void _scheduleSyncBottomOverlay() {
    if (_overlaySyncScheduled) return;
    _overlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlaySyncScheduled = false;
      if (mounted) _syncBottomOverlay();
    });
  }

  /// 向 NaviPane 上报当前是翻页 / 连续、是否显示圆片。
  void _syncBottomOverlay() {
    if (!widget.manageBottomOverlay) return;
    final navi = context.findAncestorStateOfType<NaviPaneState>();
    if (navi == null) return;
    _overlayNavi = navi;
    final paging = appdata.settings['animeListDisplayMode'] == 'paging';
    final showChip = widget.showLoadedOverlay;
    if (!paging && !showChip) {
      navi.unregisterOverlay(this);
      _overlayNavPage = null;
      return;
    }
    _overlayNavPage ??= navi.currentPage;
    navi.registerOverlay(
      this,
      navPage: _overlayNavPage!,
      paging: paging,
      showChip: showChip,
    );
  }

  Widget _buildCompactPageSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              String value = '';
              showDialog(
                context: App.rootContext,
                builder: (context) {
                  return ContentDialog(
                    title: t.jumpToPage,
                    content: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: t.page),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (v) {
                        value = v;
                      },
                    ).paddingHorizontal(16),
                    actions: [
                      Button.filled(
                        onPressed: () {
                          Navigator.of(context).pop();
                          var page = int.tryParse(value);
                          if (page == null) {
                            context.showMessage(message: t.invalidPage);
                          } else {
                            if (page > 0 &&
                                (_maxPage == null || page <= _maxPage!)) {
                              setState(() {
                                _error = null;
                                _page = page;
                              });
                            } else {
                              context.showMessage(message: t.invalidPage);
                            }
                          }
                        },
                        child: Text(t.apply),
                      ),
                    ],
                  );
                },
              );
            },
            child: Container(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .toOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${t.pagePM(p: _page.toString(), m: (_maxPage ?? '?').toString())} · ${t.exploreItemsCount(count: (_data[_page] ?? const []).length)}',
              ),
            ),
          ),
        ),
        Row(
          children: [
            _buildAnimeButton(
              context: context,
              icon: Icons.chevron_left,
              tooltip: t.back,
              enabled: _page > 1,
              onPressed: _page > 1
                  ? () {
                      setState(() {
                        _error = null;
                        _page--;
                      });
                    }
                  : null,
            ),
            const SizedBox(width: 12),
            _buildAnimeButton(
              context: context,
              icon: Icons.chevron_right,
              tooltip: t.next,
              enabled: _page < (_maxPage ?? (_page + 1)),
              onPressed: _page < (_maxPage ?? (_page + 1))
                  ? () {
                      setState(() {
                        _error = null;
                        _page++;
                      });
                    }
                  : null,
            ),
          ],
        ),
      ],
    ).paddingVertical(8).paddingHorizontal(24);
  }

  Widget _buildFullPageSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(),
        Row(
          children: [
            _buildAnimeButton(
              context: context,
              icon: Icons.first_page,
              tooltip: t.first,
              enabled: _page > 1,
              onPressed: _page > 1
                  ? () {
                      setState(() {
                        _error = null;
                        _page = 1;
                      });
                    }
                  : null,
            ),
            const SizedBox(width: 4),
            _buildAnimeButton(
              context: context,
              icon: Icons.chevron_left,
              tooltip: t.back,
              enabled: _page > 1,
              onPressed: _page > 1
                  ? () {
                      setState(() {
                        _error = null;
                        _page--;
                      });
                    }
                  : null,
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  String value = '';
                  showDialog(
                    context: App.rootContext,
                    builder: (context) {
                      return ContentDialog(
                        title: t.jumpToPage,
                        content: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: t.page),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) {
                            value = v;
                          },
                        ).paddingHorizontal(16),
                        actions: [
                          Button.filled(
                            onPressed: () {
                              Navigator.of(context).pop();
                              var page = int.tryParse(value);
                              if (page == null) {
                                context.showMessage(message: t.invalidPage);
                              } else {
                                if (page > 0 &&
                                    (_maxPage == null || page <= _maxPage!)) {
                                  setState(() {
                                    _error = null;
                                    _page = page;
                                  });
                                } else {
                                  context.showMessage(message: t.invalidPage);
                                }
                              }
                            },
                            child: Text(t.apply),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Container(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .toOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${t.pagePM(p: _page.toString(), m: (_maxPage ?? '?').toString())} · ${t.exploreItemsCount(count: (_data[_page] ?? const []).length)}',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildAnimeButton(
              context: context,
              icon: Icons.chevron_right,
              tooltip: t.next,
              enabled: _page < (_maxPage ?? (_page + 1)),
              onPressed: _page < (_maxPage ?? (_page + 1))
                  ? () {
                      setState(() {
                        _error = null;
                        _page++;
                      });
                    }
                  : null,
            ),
            const SizedBox(width: 4),
            _buildAnimeButton(
              context: context,
              icon: Icons.last_page,
              tooltip: t.last,
              enabled: _page < (_maxPage ?? (_page + 1)),
              onPressed: _page < (_maxPage ?? (_page + 1))
                  ? () {
                      setState(() {
                        _error = null;
                        _page = _maxPage ?? (_page + 1);
                      });
                    }
                  : null,
            ),
          ],
        ),
        SizedBox(),
      ],
    ).paddingVertical(8).paddingHorizontal(24);
  }

  Widget _buildAnimeButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback? onPressed,
    double size = 48,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: size,
          height: size,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(16),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return Theme.of(context).colorScheme.primary.toOpacity(0.2);
              }
              if (states.contains(WidgetState.hovered)) {
                return Theme.of(context).colorScheme.secondary.toOpacity(0.1);
              }
              return null;
            }),
            child: Center(
              child: Icon(
                icon,
                color: enabled
                    ? colorScheme.primary
                    : colorScheme.onSurface.toOpacity(0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadPage(int page) async {
    if (widget.loadPage == null && widget.loadNext == null) {
      _error = t.loadPageAndLoadNextCantBeNull;
      Future.microtask(() {
        if (mounted) setState(() {});
      });
    }
    if (_data[page] != null || _loading[page] == true) {
      return;
    }

    final gen = _generation;

    _loading[page] = true;
    // 立即刷新让底部转圈可见；onLastItemBuild 会在 build 期同步调用，
    // 需延到微任务（当前帧结束后）再 setState，避免 build 中 setState
    scheduleMicrotask(() {
      if (mounted) setState(() {});
    });
    try {
      if (widget.loadPage != null) {
        var res = await widget.loadPage!(page);
        if (!mounted || gen != _generation) return;
        if (res.success) {
          final added = _setPageData(page, res.data);
          // 本页没有新条目（空页 / 源把同一页重复返回）：视为已到末尾。
          // 必须把 maxPage 收到当前页，否则「源报了一个偏大的 maxPage 却返回空页」
          // 会让无限滚动一直往后请求（明明没有新内容）。
          setState(() {
            if (added == 0) {
              _maxPage = page;
            } else if (res.subData != null && res.subData is int) {
              _maxPage = res.subData;
            }
          });
        } else {
          setState(() {
            _error = res.errorMessage ?? t.unknownError;
          });
        }
      } else {
        try {
          while (_data[page] == null) {
            if (gen != _generation) return;
            await _fetchNext(gen);
            // 到末尾（无下一页 / 空页）仍取不到该页：停止连续空请求
            if (_maxPage != null && page > _maxPage!) break;
          }
          if (mounted && gen == _generation) {
            setState(() {});
          }
        } catch (e) {
          if (mounted && gen == _generation) {
            setState(() {
              _error = e.toString();
            });
          }
        }
      }
    } finally {
      if (gen == _generation) _loading[page] = false;
      if (mounted) storeState();
    }
  }

  /// 写入某页数据，返回本页新增（此前未出现过）的条目数。
  /// 返回 0 表示这一页没有带来任何新内容，调用方应停止继续翻页。
  int _setPageData(int page, List<Anime> items) {
    var added = 0;
    for (final a in items) {
      if (_loadedKeys.add('${a.sourceKey}|${a.id}')) added++;
    }
    _data[page] = items;
    return added;
  }

  Future<void> _fetchNext(int gen) async {
    var res = await widget.loadNext!(_nextUrl);
    // 刷新后旧请求的响应直接丢弃，避免污染新列表的 _data/_loadedKeys
    if (gen != _generation) return;
    final page = _data.length + 1;
    final added = _setPageData(page, res.data);
    // 没有下一页，或这一页没有新条目：标记为末尾，避免无限请求
    if (res.subData == null || added == 0) {
      _maxPage = _data.length;
      _nextUrl = null;
    } else {
      _nextUrl = res.subData;
    }
  }

  /// 主悬浮导航底部占位。页面内容延伸到窗口底部（导航是悬浮层），
  /// 底部控件/内容需要自己让出导航栏区域，否则会和悬浮导航重叠。
  double _bottomNavInset(BuildContext context) {
    final pane = context.findAncestorStateOfType<NaviPaneState>();
    if (pane != null) return pane.bottomBarHeight;
    return MediaQuery.paddingOf(context).bottom;
  }

  /// 悬浮主导航因页面底部控件（翻页选择条）需要抬升的距离（由 NaviPane 计算）
  double _navLift(BuildContext context) =>
      context.findAncestorStateOfType<NaviPaneState>()?.navBottomLift ?? 0;

  /// 连续模式展平缓存：build 每次都会来一次，页数×条目的全量拷贝
  /// O(n) 分配是滑动掉帧的次因之一；_data[page] 只写入一次（refresh 除外），
  /// 用（页数，总条数）做结构指纹命中缓存
  List<Anime> _flatCache = const [];
  int _flatPages = -1;
  int _flatTotal = -1;

  List<Anime> _flatAnimes() {
    var total = 0;
    for (final list in _data.values) {
      total += list.length;
    }
    if (total == 0) {
      _flatCache = const [];
      _flatPages = _data.length;
      _flatTotal = 0;
      return _flatCache;
    }
    if (_flatPages == _data.length && _flatTotal == total) {
      return _flatCache;
    }
    _flatCache = _data.values.expand((e) => e).toList();
    _flatPages = _data.length;
    _flatTotal = total;
    return _flatCache;
  }

  /// 屏幕左右下角的信息圆片：左＝页数（圆形图标）、右＝条目（圆角三角形）。
  /// paging / 连续两种模式共用。
  List<Widget> _overlayChips(BuildContext context, {required bool paging}) {
    if (!widget.showLoadedOverlay) return const [];
    final navi = context.findAncestorStateOfType<NaviPaneState>();
    if (navi != null && !navi.overlayShowChip) return const [];
    final int pages = paging ? _page : _data.length;
    final int items = paging
        ? (_data[_page]?.length ?? 0)
        : _flatAnimes().length;
    final bottom = navOverlayChipBottom(context);
    return [
      Positioned(
        left: 0,
        bottom: bottom,
        child: LoadedInfoChip(
          text: pages.toString(),
          icon: Icons.circle,
          iconSize: 7,
          alignment: Alignment.bottomLeft,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
      ),
      Positioned(
        right: 0,
        bottom: bottom,
        child: LoadedInfoChip(
          text: items.toString(),
          icon: Icons.play_arrow_rounded,
          iconSize: 11,
          iconTrailing: true,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomLeft: Radius.circular(10),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    var type = appdata.settings['animeListDisplayMode'];
    return Stack(
      children: [
        Positioned.fill(
          child: type == 'paging'
              ? buildPagingMode(context)
              : buildContinuousMode(context),
        ),
        Positioned(
          bottom: widget.showLoadedOverlay
              ? navOverlayFabBottom(context)
              : _bottomNavInset(context) + 15,
          right: 12,
          child: widget.enableFloatingMenu
              ? FloatingMenu(
                  controller: scrollController,
                  child: [
                    [
                      SpeedDialChild(
                        child: const Icon(Icons.refresh),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        onTap: refresh,
                      ),
                    ],
                    [
                      SpeedDialChild(
                        child: const Icon(Icons.vertical_align_top),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        onTap: scrollToTop,
                      ),
                    ],
                    [
                      SpeedDialChild(
                        child: type == 'paging'
                            ? Icon(Icons.view_cozy_outlined)
                            : Icon(Icons.menu),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        onTap: () {
                          appdata.settings['animeListDisplayMode'] =
                              type == 'paging' ? 'continuous' : 'paging';
                          appdata.saveData();
                          refresh();
                          _scheduleSyncBottomOverlay();
                          setState(() {});
                        },
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget buildPagingMode(BuildContext context) {
    Widget pageSelecto = Container(
      height: 46,
      decoration: BoxDecoration(color: Colors.transparent),
      child: context.width <= changePoint
          ? _buildCompactPageSelector()
          : _buildFullPageSelector(),
    );
    // 悬浮主导航会因翻页选择条整体上移，列表底部留白要清过导航栏顶部；
    // 选择条本身仍贴底（抬升在 NaviPane 里按设置做）。
    final contentBottom = _bottomNavInset(context) + 20 + _navLift(context);

    if (_error != null) {
      return Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                if (widget.errorLeading != null) widget.errorLeading!,
                Expanded(
                  child: NetworkError(
                    withAppbar: false,
                    message: _error!,
                    retry: () {
                      setState(() {
                        _error = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            left: 0,
            bottom: 0,
            child: Stack(
              children: [
                ClipRect(
                  child: BlurEffect(
                    child: Container(
                      color: Theme.of(context).colorScheme.surface
                          .toOpacity(0.85),
                      child: pageSelecto,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_data[_page] == null) {
      _loadPage(_page);
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          const Expanded(child: Center(child: KostoriRefreshIndicator())),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: SmoothCustomScrollView(
            key: enablePageStorage ? PageStorageKey('scroll$_page') : null,
            controller: widget.controller ?? scrollController,
            slivers: [
              if (widget.leadingSlivers != null) ...widget.leadingSlivers!,
              if (widget.leadingSliver != null) widget.leadingSliver!,
              SliverGridAnimes(
                animes: _data[_page] ?? const [],
                menuBuilder: widget.menuBuilder,
              ),
              if (widget.trailingSliver != null) widget.trailingSliver!,
              SliverPadding(
                padding: EdgeInsets.only(bottom: contentBottom + 4),
              ),
            ],
          ),
        ),
        Positioned(
          right: 0,
          left: 0,
          bottom: 0,
          child: Stack(
            children: [
              ClipRect(
                child: BlurEffect(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface
                        .toOpacity(0.85),
                    child: pageSelecto,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._overlayChips(context, paging: true),
      ],
    );
  }

  Widget buildContinuousMode(BuildContext context) {
    // 连续模式没有翻页概念，报错时只显示错误与重试，不显示翻页条
    if (_error != null && _data.isEmpty) {
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          Expanded(
            child: NetworkError(
              withAppbar: false,
              message: _error!,
              retry: () {
                setState(() {
                  _error = null;
                });
              },
            ),
          ),
        ],
      );
    }
    if (_data[1] == null) {
      _loadPage(1);
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          const Expanded(child: Center(child: KostoriRefreshIndicator())),
        ],
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: SmoothCustomScrollView(
            key: enablePageStorage ? PageStorageKey('scroll$_page') : null,
            controller: widget.controller ?? scrollController,
            slivers: [
              if (widget.leadingSlivers != null) ...widget.leadingSlivers!,
              if (widget.leadingSliver != null) widget.leadingSliver!,
              SliverGridAnimes(
                animes: _flatAnimes(),
                menuBuilder: widget.menuBuilder,
                onLastItemBuild: () {
                  if (_error == null &&
                      (_maxPage == null || _data.length < _maxPage!)) {
                    _loadPage(_data.length + 1);
                  }
                },
              ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      var cfe = CloudflareException.fromString(_error!);
                      return Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.error_outline),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cfe == null
                                      ? _error!
                                      : "Cloudflare verification required",
                                  maxLines: 3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: cfe != null
                                ? FilledButton(
                                    onPressed: () => passCloudflare(cfe, () {
                                      setState(() {
                                        _error = null;
                                      });
                                    }),
                                    child: Text(t.check),
                                  )
                                : OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _error = null;
                                      });
                                    },
                                    child: Text(t.retry),
                                  ),
                          ),
                        ],
                      ).paddingHorizontal(16).paddingVertical(8);
                    },
                  ),
                ),
              if (widget.trailingSliver != null) widget.trailingSliver!,
              // 让出底部悬浮主导航，避免最后一行被压住
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: _bottomNavInset(context) + 20 + _navLift(context),
                ),
              ),
            ],
          ),
        ),
        // 加载更多转圈悬浮在视口底部：不占内容流，避免触发瞬间在屏幕外被截
        if (_loading.values.any((v) => v) && _data[1] != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: _bottomNavInset(context) + 12 + _navLift(context),
            child: IgnorePointer(
              child: SizedBox(
                height: 64,
                child: Center(child: PolygonRefreshIndicator(size: 44)),
              ),
            ),
          ),
        if (_error == null && _data.isNotEmpty)
          ..._overlayChips(context, paging: false),
      ],
    );
  }
}

/// 左下/右下角信息小圆片：图标 + 数字。
/// 页数用圆形图标、条目用圆角三角形；[alignment] 让贴左/贴右的缩放都朝屏内。
/// [iconTrailing] 为 true 时图标放在数字右边；[borderRadius] 控制圆角
/// （贴边的圆片：贴边侧直角、内侧倒圆）。
class LoadedInfoChip extends StatelessWidget {
  const LoadedInfoChip({
    super.key,
    required this.text,
    this.icon,
    this.iconSize = 10,
    this.iconTrailing = false,
    this.alignment = Alignment.bottomRight,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final String text;

  final IconData? icon;

  final double iconSize;

  final bool iconTrailing;

  final Alignment alignment;

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: cs.onSurface, fontSize: 10);
    return Transform.scale(
      scale: 1.2,
      alignment: alignment,
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.toOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null && !iconTrailing) ...[
                  Icon(icon, size: iconSize, color: cs.onSurface),
                  const SizedBox(width: 4),
                ],
                Text(text, style: style),
                if (icon != null && iconTrailing) ...[
                  const SizedBox(width: 4),
                  Icon(icon, size: iconSize, color: cs.onSurface),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
