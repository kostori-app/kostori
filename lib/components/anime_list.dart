import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/utils/translations.dart';

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

  @override
  State<AnimeList> createState() => AnimeListState();
}

class AnimeListState extends State<AnimeList> {
  int? _maxPage;

  final Map<int, List<Anime>> _data = {};

  int _page = 1;

  String? _error;

  final Map<int, bool> _loading = {};

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

  void onScroll() {
    if (scrollController.offset > 50) {
      if (!showFB) setState(() => showFB = true);
    } else {
      if (showFB) setState(() => showFB = false);
    }
  }

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
    _data.clear();
    _page = 1;
    _maxPage = null;
    _error = null;
    _nextUrl = null;
    _loading.clear();
    storeState();
    setState(() {});
  }

  @override
  void initState() {
    scrollController.addListener(onScroll);
    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(onScroll);
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
                    title: "Jump to page".tl,
                    content: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "Page".tl),
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
                            context.showMessage(message: "Invalid page".tl);
                          } else {
                            if (page > 0 &&
                                (_maxPage == null || page <= _maxPage!)) {
                              setState(() {
                                _error = null;
                                _page = page;
                              });
                            } else {
                              context.showMessage(message: "Invalid page".tl);
                            }
                          }
                        },
                        child: Text("Apply".tl),
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
                "Page @p / @m".tlParams({"p": _page, "m": _maxPage ?? '?'}),
              ),
            ),
          ),
        ),
        Row(
          children: [
            _buildAnimeButton(
              context: context,
              icon: Icons.chevron_left,
              tooltip: "Back".tl,
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
              tooltip: "Next".tl,
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
              tooltip: "First".tl,
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
              tooltip: "Back".tl,
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
                        title: "Jump to page".tl,
                        content: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: "Page".tl),
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
                                context.showMessage(message: "Invalid page".tl);
                              } else {
                                if (page > 0 &&
                                    (_maxPage == null || page <= _maxPage!)) {
                                  setState(() {
                                    _error = null;
                                    _page = page;
                                  });
                                } else {
                                  context.showMessage(
                                    message: "Invalid page".tl,
                                  );
                                }
                              }
                            },
                            child: Text("Apply".tl),
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
                    "Page @p / @m".tlParams({"p": _page, "m": _maxPage ?? '?'}),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildAnimeButton(
              context: context,
              icon: Icons.chevron_right,
              tooltip: "Next".tl,
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
              tooltip: "Last".tl,
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
      _error = "loadPage and loadNext can't be null at the same time";
      Future.microtask(() {
        setState(() {});
      });
    }
    if (_data[page] != null || _loading[page] == true) {
      return;
    }
    _loading[page] = true;
    try {
      if (widget.loadPage != null) {
        var res = await widget.loadPage!(page);
        if (!mounted) return;
        if (res.success) {
          if (res.data.isEmpty) {
            setState(() {
              _data[page] = const [];
              _maxPage ??= page;
            });
          } else {
            setState(() {
              _data[page] = res.data;
              if (res.subData != null && res.subData is int) {
                _maxPage = res.subData;
              }
            });
          }
        } else {
          setState(() {
            _error = res.errorMessage ?? "Unknown error".tl;
          });
        }
      } else {
        try {
          while (_data[page] == null) {
            await _fetchNext();
          }
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = e.toString();
            });
          }
        }
      }
    } finally {
      _loading[page] = false;
      storeState();
    }
  }

  Future<void> _fetchNext() async {
    var res = await widget.loadNext!(_nextUrl);
    _data[_data.length + 1] = res.data;
    if (res.subData == null) {
      _maxPage = _data.length;
    } else {
      _nextUrl = res.subData;
    }
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
          bottom: 30,
          right: 10,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            opacity: showFB ? 1 : 0,
            child: Visibility(
              visible: showFB,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 0),
                child: GridSpeedDial(
                  icon: Icons.menu,
                  activeIcon: Icons.close,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  spacing: 6,
                  spaceBetweenChildren: 4,
                  direction: SpeedDialDirection.up,
                  childPadding: const EdgeInsets.all(6),
                  childrens: [
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
                          refresh;
                          setState(() {});
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
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
          const Expanded(child: Center(child: CircularProgressIndicator())),
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
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: 46 + MediaQuery.of(context).padding.bottom + 4,
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
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    return SmoothCustomScrollView(
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
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, maxLines: 3)),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                    },
                    child: Text("Retry".tl),
                  ),
                ),
              ],
            ).paddingHorizontal(16).paddingVertical(8),
          )
        else if (_maxPage == null || _data.length < _maxPage!)
          const SliverListLoadingIndicator(),
        if (widget.trailingSliver != null) widget.trailingSliver!,
      ],
    );
  }
}
