import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_absolute_path_provider/flutter_absolute_path_provider.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:intl/intl.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/device_info.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/api.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/network/download.dart';
import 'package:kostori/pages/settings/anime_source_settings.dart';
import 'package:kostori/utils/data.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:local_auth/local_auth.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/blocks/leaf/paragraph.dart';
import 'package:markdown_widget/widget/inlines/code.dart';
import 'package:markdown_widget/widget/markdown_block.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:yaml/yaml.dart';

part 'about.dart';

part 'app.dart';

part 'appearance.dart';

part 'explore_settings.dart';

part 'local_favorites.dart';

part 'network.dart';

part 'setting_components.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({this.initialPage = -1, super.key});

  final int initialPage;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> implements PopEntry {
  int currentPage = -1;

  ColorScheme get colors => Theme.of(context).colorScheme;

  bool get enableTwoViews => context.width > 720;

  final categories = <String>[
    "Explore",
    "Fanyuan",
    "Appearance",
    "Local Favorites",
    "APP",
    "Network",
    "About",
  ];

  final icons = <IconData>[
    Icons.explore,
    Icons.source,
    Icons.color_lens,
    Icons.collections_bookmark_rounded,
    Icons.apps,
    Icons.public,
    Icons.info,
  ];

  double offset = 0;

  late final HorizontalDragGestureRecognizer gestureRecognizer;

  ModalRoute? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? nextRoute = ModalRoute.of(context);
    if (nextRoute != _route) {
      _route?.unregisterPopEntry(this);
      _route = nextRoute;
      _route?.registerPopEntry(this);
    }
  }

  @override
  void initState() {
    currentPage = widget.initialPage;
    gestureRecognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onUpdate = ((details) => setState(() => offset += details.delta.dx))
      ..onEnd = (details) async {
        if (details.velocity.pixelsPerSecond.dx.abs() > 1 &&
            details.velocity.pixelsPerSecond.dx >= 0) {
          setState(() {
            Future.delayed(const Duration(milliseconds: 300), () => offset = 0);
            currentPage = -1;
          });
        } else if (offset > MediaQuery.of(context).size.width / 2) {
          setState(() {
            Future.delayed(const Duration(milliseconds: 300), () => offset = 0);
            currentPage = -1;
          });
        } else {
          int i = 10;
          while (offset != 0) {
            setState(() {
              offset -= i;
              i *= 10;
              if (offset < 0) {
                offset = 0;
              }
            });
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
      }
      ..onCancel = () async {
        int i = 10;
        while (offset != 0) {
          setState(() {
            offset -= i;
            i *= 10;
            if (offset < 0) {
              offset = 0;
            }
          });
          await Future.delayed(const Duration(milliseconds: 10));
        }
      };
    super.initState();
  }

  @override
  dispose() {
    super.dispose();
    gestureRecognizer.dispose();
    _route?.unregisterPopEntry(this);
  }

  @override
  Widget build(BuildContext context) {
    if (currentPage != -1) {
      canPop.value = false;
    } else {
      canPop.value = true;
    }
    return Material(child: buildBody());
  }

  Widget buildBackground(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary.toOpacity(0.1);
    final height = MediaQuery.of(context).size.height;

    Widget base = SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              themeColor.toOpacity(0.0), // 顶部透明
              themeColor.toOpacity(0.4), // 中间
            ],
            stops: const [0.2, 1.0],
          ),
        ),
      ),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
          tileMode: TileMode.clamp,
        ),
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: base,
        ),
      ),
    );
  }

  Widget buildBody() {
    if (enableTwoViews) {
      return Stack(
        children: [
          buildBackground(context),
          Positioned.fill(
            child: Row(
              children: [
                Container(
                  width: 280,
                  height: double.infinity,
                  color: Colors.transparent,
                  child: buildLeft(),
                ),
                Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: context.colorScheme.outlineVariant,
                        width: 0.6,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return LayoutBuilder(
                        builder: (context, constrains) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, _) {
                              var width = constrains.maxWidth;
                              var value = animation.isForwardOrCompleted
                                  ? 1 - animation.value
                                  : 1;
                              var left = width * value;
                              return Stack(
                                children: [
                                  Positioned(
                                    top: 0,
                                    bottom: 0,
                                    left: left,
                                    width: width,
                                    child: child,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                    child: buildRight(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return LayoutBuilder(
        builder: (context, constrains) {
          return Stack(
            children: [
              buildBackground(context),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: currentPage == -1
                      ? buildLeft()
                      : const SizedBox.shrink(),
                ),
              ),
              Positioned(
                left: offset,
                width: constrains.maxWidth,
                top: 0,
                bottom: 0,
                child: Listener(
                  // 滑动返回
                  onPointerDown: handlePointerDown,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.fastOutSlowIn,
                    switchOutCurve: Curves.fastOutSlowIn,
                    transitionBuilder: (child, animation) {
                      var tween = Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: const Offset(0, 0),
                      );

                      return SlideTransition(
                        position: tween.animate(animation),
                        child: child,
                      );
                    },
                    child: Material(
                      color: Colors.transparent,
                      key: ValueKey(currentPage),
                      child: buildRight(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void handlePointerDown(PointerDownEvent event) {
    if (event.position.dx < 20) {
      gestureRecognizer.addPointer(event);
    }
  }

  Widget buildLeft() {
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Tooltip(
                      message: "Back".tl,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        onPressed: context.pop,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text("Settings".tl, style: ts.s20),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(child: buildCategories()),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCategories() {
    Widget buildItem(String name, int id) {
      final bool selected = id == currentPage;

      Widget content = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          key: ValueKey(id),
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 46,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer.toOpacity(0.36) : null,
            border: Border(
              left: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icons[id],
                size: 28,
                color: Color.lerp(
                  Theme.of(context).colorScheme.primary,
                  !context.isDarkMode
                      ? Colors.black.toOpacity(0.72)
                      : Colors.white.toOpacity(0.72),
                  0.4,
                ),
              ),
              const SizedBox(width: 16),
              Text(name, style: ts.s16),
              const Spacer(),
              if (selected) const Icon(Icons.arrow_right),
            ],
          ),
        ),
      );

      return AnimatedPadding(
        padding: EdgeInsets.fromLTRB(24, 0, selected ? 12 : 24, 0),
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              highlightColor: !context.isDarkMode
                  ? Colors.black.toOpacity(0.1)
                  : Colors.white.toOpacity(0.1),
              splashColor: Colors.transparent.toOpacity(0.0),
              onTap: () => setState(() => currentPage = id),
              child: content,
            ),
          ),
        ).paddingVertical(4),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      itemBuilder: (context, index) => buildItem(categories[index].tl, index),
    );
  }

  Widget buildRight() {
    return switch (currentPage) {
      -1 =>
        enableTwoViews
            ? SizedBox(
                child: Center(
                  child: Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(136),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const Image(
                      image: AssetImage("images/app_icon.png"),
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              )
            : SizedBox(),
      0 => const ExploreSettings(),
      1 => const AnimeSourceSettings(),
      2 => const AppearanceSettings(),
      3 => const LocalFavoritesSettings(),
      4 => const AppSettings(),
      5 => const NetworkSettings(),
      6 => const AboutSettings(),
      _ => throw UnimplementedError(),
    };
  }

  var canPop = ValueNotifier(true);

  @override
  ValueListenable<bool> get canPopNotifier => canPop;

  @override
  void onPopInvokedWithResult(bool didPop, result) {
    if (currentPage != -1) {
      setState(() {
        currentPage = -1;
      });
    }
  }

  @override
  void onPopInvoked(bool didPop) {
    if (currentPage != -1) {
      setState(() {
        currentPage = -1;
      });
    }
  }
}
