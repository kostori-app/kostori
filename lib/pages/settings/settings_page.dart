import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_absolute_path_provider/flutter_absolute_path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/custom_markdown_widget.dart';
import 'package:kostori/components/translation_widget.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/translation_service.dart';
import 'package:kostori/foundation/translation/sort.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/device_info.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/network/api.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/network/download.dart';
import 'package:kostori/pages/hub/hub_create_room_dialog.dart';
import 'package:kostori/pages/hub/hub_page.dart';
import 'package:kostori/pages/hub/hub_room_settings_sheet.dart';
import 'package:kostori/pages/webview.dart';
import 'package:kostori/utils/data.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/utils.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:yaml/yaml.dart';

part 'about.dart';

part 'app_settings.dart';

part 'appearance.dart';

part 'bangumi_settings.dart';

part 'explore_settings.dart';

part 'local_favorites.dart';

part 'network.dart';

part 'player_settings.dart';

part 'setting_components.dart';

part 'translation_settings.dart';

part 'service_settings.dart';

part 'anime_source_settings.dart';

part 'hub_service_setting.dart';

part 'hub_client_setting.dart';

part 'hub_upload_settings.dart';

part 'log_settings.dart';

part 'ai_settings.dart';

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
    "Bangumi",
    "Fanyuan",
    "Player",
    "Translation",
    "Appearance",
    "Local Favorites",
    "APP",
    "Network",
    "Ai",
    "Service",
    "Log",
    "About",
  ];

  final icons = <IconData>[
    Icons.explore,
    Icons.account_balance,
    Icons.source,
    Icons.display_settings_rounded,
    Icons.translate_rounded,
    Icons.color_lens,
    Icons.collections_bookmark_rounded,
    Icons.apps,
    Icons.public,
    Icons.auto_awesome,
    Icons.miscellaneous_services_rounded,
    Icons.receipt_long_rounded,
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
            colors: [themeColor.toOpacity(0.0), themeColor.toOpacity(0.4)],
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
      1 => const BangumiSettings(),
      2 => const AnimeSourceSettings(),
      3 => const PlayerSettings(),
      4 => const TranslationSettings(),
      5 => const AppearanceSettings(),
      6 => const LocalFavoritesSettings(),
      7 => const AppSettings(),
      8 => const NetworkSettings(),
      9 => const AiSettings(),
      10 => const ServiceSettings(),
      11 => const LogSettings(),
      12 => const AboutSettings(),
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

class _ManualTranslationCard extends StatefulWidget {
  const _ManualTranslationCard();

  @override
  State<_ManualTranslationCard> createState() => _ManualTranslationCardState();
}

class _ManualTranslationCardState extends State<_ManualTranslationCard> {
  final TextEditingController _inputController = TextEditingController();
  final TranslationController _translationController = TranslationController();
  late Sort _selectedLanguage;

  String poweredName = '';

  @override
  void initState() {
    super.initState();
    String? savedLang = appdata.implicitData['currentLanguage'];
    _selectedLanguage = savedLang != null
        ? translationSorts.firstWhere(
            (s) => s.extData == savedLang,
            orElse: () => translationSorts.first,
          )
        : translationSorts.first;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    if (_inputController.text.isEmpty) {
      App.rootContext.showMessage(message: 'Please enter text to translate'.tl);
      return;
    }
    poweredName = TranslationService.getPoweredName();
    await _translationController.translate(
      _inputController.text,
      targetLanguage: _selectedLanguage.extData,
    );
  }

  void _showDialogSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ContentDialog(
          title: '选择翻译语言'.tl,
          displayButton: false,
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                child: RadioGroup<SortId>(
                  groupValue: _selectedLanguage.id,
                  onChanged: (value) {
                    if (value == null) return;
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: translationSorts.map((sort) {
                      return ListTile(
                        dense: true,
                        title: Text(
                          sort.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 24,
                          ),
                        ),
                        trailing: Radio<SortId>(value: sort.id),
                        onTap: () {
                          Navigator.of(context).pop();
                          _translate();
                          _selectedLanguage = sort;
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      children: [
        _SettingPartTitle(
          title: 'Manual Translation'.tl,
          icon: Icons.translate,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListenableBuilder(
            listenable: _translationController,
            builder: (context, _) {
              return Column(
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        onPressed: _translationController.isTranslating
                            ? null
                            : _translate,
                        icon: _translationController.isTranslating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.translate,
                                size: 24,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showDialogSelector(context),
                        icon: Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                          size: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _inputController,
                              maxLines: 3,
                              scrollPadding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).viewInsets.bottom +
                                    100,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter text to translate'.tl,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_translationController.hasTranslation) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.translate, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Translation result'.tl,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: Colors.grey.withValues(
                                              alpha: 0.05,
                                            ),
                                          ),
                                          child: Text(
                                            'Powered by $poweredName',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    CustomMarkdownWidget(
                                      data:
                                          _translationController
                                              .translatedText ??
                                          '',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
