library kostori_settings;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';

import 'package:kostori/foundation/app.dart';
import 'package:kostori/base.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:kostori/tools/extensions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../anime_source/anime_source.dart';
import '../../components/components.dart';
import '../../components/select.dart';
import '../../foundation/cache_manager.dart';
import '../../foundation/ui_mode.dart';
import '../../main.dart';
import '../../network/app_dio.dart';
import '../../network/http_client.dart';
import '../../network/http_proxy.dart';
import '../../network/update.dart';
import '../../network/webdav.dart';
import '../../tools/io_tools.dart';
import '../logs_page.dart';
import '../welcome_page.dart';

part "anime_source_settings.dart";
part 'girigirilove_settings.dart';
part 'components.dart';
part 'network_setting.dart';
part 'app_settings.dart';

class SettingsPage extends StatefulWidget {
  static void open([int initialPage = -1]) {
    App.globalTo(() => SettingsPage(initialPage: initialPage));
  }

  const SettingsPage({this.initialPage = -1, super.key});

  final int initialPage;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> implements PopEntry {
  int currentPage = -1;

  ColorScheme get colors => Theme.of(context).colorScheme;

  bool get enableTwoViews => !UiMode.m1(context);

  final categories = <String>[
    // "浏览",
    "番源",
    // "阅读",
    "外观",
    // "本地收藏",
    "APP",
    "网络",
    "关于"
  ];

  final icons = <IconData>[
    // Icons.explore,
    Icons.source,
    // Icons.book,
    Icons.color_lens,
    // Icons.collections_bookmark_rounded,
    Icons.apps,
    Icons.public,
    Icons.info
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

  Widget buildReadingSettings() {
    return const Placeholder();
  }

  @override
  Widget build(BuildContext context) {
    if (currentPage != -1 && !enableTwoViews) {
      canPop.value = false;
      App.temporaryDisablePopGesture = true;
    } else {
      canPop.value = true;
      App.temporaryDisablePopGesture = false;
    }
    return Material(
      child: buildBody(),
    );
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

  Widget buildBody() {
    if (enableTwoViews) {
      return Row(
        children: [
          SizedBox(
            width: 350,
            height: double.infinity,
            child: buildLeft(),
          ),
          Expanded(child: buildRight())
        ],
      );
    } else {
      return Stack(
        children: [
          Positioned.fill(child: buildLeft()),
          Positioned(
            left: offset,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Listener(
              onPointerDown: handlePointerDown,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 300),
                switchInCurve: Curves.fastOutSlowIn,
                switchOutCurve: Curves.fastOutSlowIn,
                transitionBuilder: (child, animation) {
                  var tween = Tween<Offset>(
                      begin: const Offset(1, 0), end: const Offset(0, 0));

                  return SlideTransition(
                    position: tween.animate(animation),
                    child: child,
                  );
                },
                child: currentPage == -1
                    ? const SizedBox(
                        key: Key("1"),
                      )
                    : buildRight(),
              ),
            ),
          )
        ],
      );
    }
  }

  void handlePointerDown(PointerDownEvent event) {
    if (event.position.dx < 20) {
      gestureRecognizer.addPointer(event);
    }
  }

//设置左侧
  Widget buildLeft() {
    return Material(
      color: enableTwoViews ? colors.surface : null,
      elevation: enableTwoViews ? 1 : 0,
      surfaceTintColor: colors.surfaceTint,
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).padding.top,
          ),
          SizedBox(
            height: 56,
            child: Row(children: [
              const SizedBox(
                width: 8,
              ),
              Tooltip(
                message: "Back",
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => App.globalBack(),
                ),
              ),
              const SizedBox(
                width: 24,
              ),
              Text(
                "设置",
                style: Theme.of(context).textTheme.headlineSmall,
              )
            ]),
          ),
          const SizedBox(
            height: 4,
          ),
          Expanded(
            child: buildCategories(),
          )
        ],
      ),
    );
  }

//构建类别
  Widget buildCategories() {
    Widget buildItem(String name, int id) {
      final bool selected = id == currentPage;

      Widget content = AnimatedContainer(
        key: ValueKey(id),
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 58,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : null,
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icons[id]),
          const SizedBox(
            width: 16,
          ),
          Text(
            name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          if (selected) const Icon(Icons.arrow_right)
        ]),
      );

      return Padding(
        padding: enableTwoViews
            ? const EdgeInsets.fromLTRB(16, 0, 16, 0)
            : EdgeInsets.zero,
        child: InkWell(
          onTap: () => setState(() => currentPage = id),
          borderRadius: BorderRadius.circular(16),
          child: content,
        ).paddingVertical(4),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      itemBuilder: (context, index) => buildItem(categories[index], index),
    );
  }

  Widget buildAppearanceSettings() => Column(
        children: [
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: Text("主题选择"),
            trailing: Select(
              initialValue: int.parse(appdata.settings[27]),
              values: const [
                "dynamic",
                "red",
                "pink",
                "purple",
                "indigo",
                "blue",
                "cyan",
                "teal",
                "green",
                "lime",
                "yellow",
                "amber",
                "orange",
              ],
              onChange: (i) {
                appdata.settings[27] = i.toString();
                appdata.updateSettings();
                MyApp.updater?.call();
              },
              width: 140,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: Text("深色模式"),
            trailing: Select(
              initialValue: int.parse(appdata.settings[32]),
              values: ["跟随系统", "禁用", "启用"],
              onChange: (i) {
                appdata.settings[32] = i.toString();
                appdata.updateSettings();
                MyApp.updater?.call();
              },
              width: 140,
            ),
          ),
          if (App.isAndroid)
            ListTile(
              leading: const Icon(Icons.smart_screen_outlined),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("高刷新率模式"),
                  const SizedBox(
                    width: 2,
                  ),
                  InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    onTap: () => showDialogMessage(
                        context,
                        "高刷新率模式",
                        "启用后, APP将尝试设置高刷新率\n"
                            "如果OS没有限制APP的刷新率, 无需启用此项\n"
                            "OS可能不会响应更改"),
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                    ),
                  )
                ],
              ),
              trailing: Switch(
                value: appdata.settings[38] == "1",
                onChanged: (b) {
                  setState(() {
                    appdata.settings[38] = b ? "1" : "0";
                  });
                  appdata.updateSettings();
                  if (b) {
                    try {
                      FlutterDisplayMode.setHighRefreshRate();
                    } catch (e) {
                      // ignore
                    }
                  } else {
                    try {
                      FlutterDisplayMode.setLowRefreshRate();
                    } catch (e) {
                      // ignore
                    }
                  }
                },
              ),
            )
        ],
      );

  Widget buildAppSettings() {
    return Column(children: [
      ListTile(
        title: Text("日志"),
      ),
      ListTile(
        leading: const Icon(Icons.bug_report),
        title: const Text("Logs"),
        trailing: const Icon(Icons.arrow_right),
        onTap: () => context.to(() => const LogsPage()),
      ),
      ListTile(
        title: Text("更新"),
      ),
      ListTile(
        leading: const Icon(Icons.update),
        title: Text("检查更新"),
        subtitle: Text("${"当前:"} $appVersion"),
        onTap: () {
          findUpdate(context);
        },
      ),
      SwitchSetting(
        title: "启动时检查更新",
        settingsIndex: 2,
        icon: const Icon(Icons.security_update),
      ),
      Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom))
    ]);
  }

  Widget buildAbout() {
    return Column(
      children: [
        SizedBox(
          height: 130,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 156,
              height: 156,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(20)),
              child: const Image(
                image: AssetImage("assets/app_icon.png"),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
        const Text(
          "V$appVersion",
          style: TextStyle(fontSize: 16),
        ),
        Text("kostori"),
        Text("仅用于学习交流"),
        const SizedBox(
          height: 16,
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text("项目地址"),
          onTap: () =>
              launchUrlString("", mode: LaunchMode.externalApplication),
          trailing: const Icon(Icons.arrow_right),
        ),
        ListTile(
          leading: const Icon(Icons.comment_outlined),
          title: Text("提出建议(Github)"),
          onTap: () =>
              launchUrlString("", mode: LaunchMode.externalApplication),
          trailing: const Icon(Icons.arrow_right),
        ),
        ListTile(
          leading: const Icon(Icons.email),
          title: Text("通过电子邮件联系我"),
          onTap: () =>
              launchUrlString("", mode: LaunchMode.externalApplication),
          trailing: const Icon(Icons.arrow_right),
        ),
        ListTile(
          leading: const Icon(Icons.support_outlined),
          title: Text("支持开发"),
          onTap: () =>
              launchUrlString("", mode: LaunchMode.externalApplication),
          trailing: const Icon(Icons.arrow_right),
        ),
        ListTile(
          leading: const Icon(Icons.telegram),
          title: Text("加入Telegram群"),
          onTap: () =>
              launchUrlString("", mode: LaunchMode.externalApplication),
          trailing: const Icon(Icons.arrow_right),
        ),
        Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom))
      ],
    );
  }

  Widget buildRight() {
    final Widget body = switch (currentPage) {
      -1 => const SizedBox(),
      // 0 => buildExploreSettings(context, false),
      0 => const AnimeSourceSettings(),
      // 2 => const ReadingSettings(false),
      1 => buildAppearanceSettings(),
      // 4 => const LocalFavoritesSettings(),
      2 => buildAppSettings(),
      3 => const NetworkSettings(),
      4 => buildAbout(),
      _ => throw UnimplementedError()
    };

    if (currentPage != -1) {
      return Material(
        child: CustomScrollView(
          primary: false,
          slivers: [
            SliverAppBar(
                title: Text(categories[currentPage]),
                automaticallyImplyLeading: false,
                scrolledUnderElevation: enableTwoViews ? 0 : null,
                leading: enableTwoViews
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() => currentPage = -1),
                      )),
            SliverToBoxAdapter(
              child: body,
            )
          ],
        ),
      );
    }

    return body;
  }

  var canPop = ValueNotifier(true);

  @override
  ValueListenable<bool> get canPopNotifier => canPop;

  // @override
  // PopInvokedCallback? get onPopInvoked => (canPop) {
  //       if (currentPage != -1) {
  //         setState(() {
  //           currentPage = -1;
  //         });
  //       }
  //     };
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
