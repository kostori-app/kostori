import 'dart:async';
import 'dart:ui';

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
    this.trailingSliver,
    this.errorLeading,
    this.menuBuilder,
    this.controller,
    this.refreshHandlerCallback,
    this.enablePageStorage = false,
    this.enableFloatingMenu = true,
  });

  final Future<Res<List<Anime>>> Function(int page)? loadPage;

  final Future<Res<List<Anime>>> Function(String? next)? loadNext;

  final Widget? leadingSliver;

  final Widget? trailingSliver;

  final Widget? errorLeading;

  final List<MenuEntry> Function(Anime)? menuBuilder;

  final ScrollController? controller;

  final void Function(VoidCallback c)? refreshHandlerCallback;

  final bool enablePageStorage;

  /// 是否显示内置的右下角浮动按钮（探索页用页面级 GridSpeedDial，可关闭）
  final bool enableFloatingMenu;

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
    scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    restoreState(PageStorage.of(context).readState(context));
    widget.refreshHandlerCallback?.call(refresh);
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
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.toOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                t.pagePM(p: _page.toString(), m: (_maxPage ?? '?').toString()),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.toOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    t.pagePM(
                      p: _page.toString(),
                      m: (_maxPage ?? '?').toString(),
                    ),
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
        setState(() {});
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
          bottom: 15,
          right: 10,
          child: widget.enableFloatingMenu
              ? FloatingMenu(
                  controller: scrollController,
                  child: [
                    [
                      SpeedDialChild(
                        child: const Icon(Icons.refresh),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        onTap: refresh,
                      ),
                    ],
                    [
                      SpeedDialChild(
                        child: const Icon(Icons.vertical_align_top),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        onTap: scrollToTop,
                      ),
                    ],
                    [
                      SpeedDialChild(
                        child: type == 'paging'
                            ? Icon(Icons.view_cozy_outlined)
                            : Icon(Icons.menu),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        onTap: () {
                          appdata.settings['animeListDisplayMode'] =
                              type == 'paging' ? 'continuous' : 'paging';
                          appdata.saveData();
                          refresh();
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
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.toOpacity(0.85),
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
              if (widget.leadingSliver != null) widget.leadingSliver!,
              SliverGridAnimes(
                animes: _data[_page] ?? const [],
                menuBuilder: widget.menuBuilder,
              ),
              if (widget.trailingSliver != null) widget.trailingSliver!,
              SliverPadding(padding: EdgeInsets.only(bottom: contentBottom + 4)),
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
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.toOpacity(0.85),
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

  Widget buildContinuousMode(BuildContext context) {
    Widget pageSelecto = Container(
      height: 46,
      decoration: BoxDecoration(color: Colors.transparent),
      child: context.width <= changePoint
          ? _buildCompactPageSelector()
          : _buildFullPageSelector(),
    );

    if (_error != null && _data.isEmpty) {
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          pageSelecto,
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
              if (widget.leadingSliver != null) widget.leadingSliver!,
              SliverGridAnimes(
                animes: _data.values.expand((element) => element).toList(),
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
      ],
    );
  }
}
