import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_absolute_path_provider/flutter_absolute_path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kostori/components/ai_model_card.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/custom_markdown_widget.dart';
import 'package:kostori/components/translation_widget.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/assistant_profile.dart';
import 'package:kostori/foundation/ai_service/balance_helper.dart';
import 'package:kostori/foundation/ai_service/mcp_client.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/ai_service/role_management.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/translation_service.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/foundation/translation/sort.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/device_info.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/me_plugin/me_plugin.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/network/api.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/network/bangumi_oauth.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/network/download.dart';
import 'package:kostori/network/m3u8_ad_rule.dart';
import 'package:kostori/pages/hub/hub_create_room_dialog.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/pages/hub/hub_page.dart';
import 'package:kostori/pages/hub/hub_room_settings_sheet.dart';
import 'package:kostori/pages/ai_hub/ai_hub_page.dart';
import 'package:kostori/pages/webview.dart';
import 'package:kostori/skills/skill_registry.dart';
import 'package:kostori/utils/data.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaml/yaml.dart';

part 'about.dart';

part 'app_settings.dart';

part 'appearance.dart';

part 'bangumi_settings.dart';
part 'me_plugin_settings.dart';

part 'explore_settings.dart';

part 'local_favorites.dart';

part 'network.dart';

part 'player_settings.dart';

part 'setting_components.dart';

part 'translation_settings.dart';

part 'service_settings.dart';

part 'anime_source_settings.dart';

part 'anime_source_builder.dart';

part 'hub_service_setting.dart';

part 'hub_client_setting.dart';

part 'hub_upload_settings.dart';

part 'log_settings.dart';

part 'ai_settings.dart';

part 'extension_settings.dart';

part 'role_management_settings.dart';

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
    t.explore,
    t.bangumi,
    t.fanyuan,
    t.mePagePlugin,
    t.player,
    t.appearance,
    t.localFavorites,
    t.app,
    t.network,
    t.ai,
    t.service,
    t.log,
    t.about,
  ];

  final icons = <IconData>[
    Icons.explore,
    Icons.account_balance,
    Icons.source,
    Icons.widgets_outlined,
    Icons.display_settings_rounded,
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

    // 注意：原实现包了一层全屏 BackdropFilter（blur），但下方 Material
    // 是 scaffoldBackgroundColor 不透明，模糊效果被完全盖住、实际不可见，
    // 却导致移动端大面积实时模糊严重卡顿，故移除
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: base,
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
                        // RepaintBoundary：动画期间整页作为图层移动，
                        // 避免每帧重绘导致跳转动画卡顿/消失
                        child: RepaintBoundary(child: child),
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
                      message: t.back,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        onPressed: context.pop,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(t.settings, style: ts.s20),
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
      itemBuilder: (context, index) =>
          buildItem(t[categories[index]] ?? categories[index], index),
    );
  }

  Widget buildRight() {
    return switch (currentPage) {
      -1 =>
        enableTwoViews
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final side = (constraints.biggest.shortestSide * 0.26).clamp(
                    96.0,
                    300.0,
                  );
                  return Center(
                    child: Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(side),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image(
                        image: const AssetImage("images/app_logo.png"),
                        filterQuality: FilterQuality.medium,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              )
            : SizedBox(),
      0 => const ExploreSettings(),
      1 => const BangumiSettings(),
      2 => const AnimeSourceSettings(),
      3 => const PluginSettings(),
      4 => const PlayerSettings(),
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

// ─────────────────────────────────────────────
// 翻译页（聚合入口 → 翻译）
// ─────────────────────────────────────────────

class ManualTranslationPage extends StatefulWidget {
  const ManualTranslationPage({super.key});

  @override
  State<ManualTranslationPage> createState() => _ManualTranslationPageState();
}

class _ManualTranslationPageState extends State<ManualTranslationPage> {
  final TextEditingController _inputController = TextEditingController();
  final TranslationController _translationController = TranslationController();
  late Sort _selectedLanguage;
  String poweredName = '';

  static const _quickTargets = ['zh-CN', 'en-US', 'ja', 'ko'];

  @override
  void initState() {
    super.initState();
    final savedLang = appdata.implicitData['currentLanguage'];
    _selectedLanguage = savedLang != null
        ? translationSorts.firstWhere(
            (s) => s.extData == savedLang,
            orElse: () => translationSorts.first,
          )
        : translationSorts.first;
    _inputController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    if (_inputController.text.trim().isEmpty) {
      App.rootContext.showMessage(message: t.pleaseEnterTextToTranslate);
      return;
    }
    poweredName = TranslationService.getPoweredName();
    await _translationController.translate(
      _inputController.text,
      targetLanguage: _selectedLanguage.extData,
    );
  }

  void _clear() {
    _inputController.clear();
    _translationController.clearTranslation();
    if (mounted) setState(() {});
  }

  Future<void> _copyResult() async {
    final text = _translationController.translatedText;
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) App.rootContext.showMessage(message: t.copied);
  }

  Future<void> _showLanguageSelector() async {
    final selected = await showDialog<Sort>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.selectTranslationLanguage,
        displayButton: false,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: RadioGroup<SortId>(
              groupValue: _selectedLanguage.id,
              onChanged: (_) {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final sort in translationSorts)
                    ListTile(
                      dense: true,
                      title: Text(sort.label),
                      trailing: Radio<SortId>(value: sort.id),
                      onTap: () => Navigator.pop(ctx, sort),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null) setState(() => _selectedLanguage = selected);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          title: Text(t.translation),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            tooltip: t.back,
            onPressed: () => context.canPop() ? context.pop() : App.pop(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                // ── 语言选择条 ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _langPill(
                          scheme,
                          icon: Icons.auto_awesome,
                          label: t.autoDetect,
                          caption: t.sourceLanguage,
                          onTap: null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: scheme.outline,
                        ),
                      ),
                      Expanded(
                        child: _langPill(
                          scheme,
                          icon: Icons.flag_outlined,
                          label: _selectedLanguage.label,
                          caption: t.targetLanguage,
                          onTap: _showLanguageSelector,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── 常用目标语言快捷切换 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final code in _quickTargets)
                        if (translationSorts.any((s) => s.extData == code))
                          ChoiceChip(
                            label: Text(
                              translationSorts
                                  .firstWhere((s) => s.extData == code)
                                  .label,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _selectedLanguage.extData == code,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() {
                              _selectedLanguage = translationSorts.firstWhere(
                                (s) => s.extData == code,
                              );
                            }),
                          ),
                    ],
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                // ── 输入区 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _inputController,
                    maxLines: 7,
                    minLines: 4,
                    decoration: InputDecoration(
                      hintText: t.enterTextToTranslate,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                  child: Row(
                    children: [
                      Text(
                        '${_inputController.text.length} ${t.characters}',
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                        tooltip: t.clear,
                        onPressed: _inputController.text.isEmpty
                            ? null
                            : _clear,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── 翻译按钮 ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: _translationController,
              builder: (context, _) {
                final translating = _translationController.isTranslating;
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: translating ? null : _translate,
                    icon: translating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: PolygonRefreshIndicator(),
                          )
                        : const Icon(Icons.translate),
                    label: Text(translating ? t.translating : t.translate),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // ── 结果区 ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: _translationController,
              builder: (context, _) {
                final hasResult =
                    _translationController.hasTranslation &&
                    _translationController.translatedText != null;
                if (!hasResult) {
                  return _SettingCard(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.translate,
                              size: 40,
                              color: scheme.outlineVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t.noTranslationYet,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                final result = _translationController.translatedText!;
                return _SettingCard(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.translate, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            t.translationResult,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            tooltip: t.copy,
                            onPressed: _copyResult,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SelectableText(
                        result,
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Powered by $poweredName',
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${result.length} ${t.characters}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.outline,
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
        ),
      ],
    );
  }

  Widget _langPill(
    ColorScheme scheme, {
    required IconData icon,
    required String label,
    required String caption,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
