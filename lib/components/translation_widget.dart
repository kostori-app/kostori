import 'package:flutter/material.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/custom_markdown_widget.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/translation/sort.dart';
import 'package:kostori/foundation/translation_service.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:skeletonizer/skeletonizer.dart';

class TranslatedContent extends StatefulWidget {
  const TranslatedContent({
    super.key,
    required this.data,
    this.translationController,
  });

  final String data;
  final TranslationController? translationController;

  @override
  State<TranslatedContent> createState() => _TranslatedContentState();
}

class _TranslatedContentState extends State<TranslatedContent> {
  TranslationService translationService = TranslationService();
  late TranslationController translationController;

  @override
  void initState() {
    super.initState();
    translationController = widget.translationController!;
  }

  @override
  void didUpdateWidget(TranslatedContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      if (mounted) {
        setState(() {});
      }
      translationController.clearTranslation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final poweredName = TranslationService.getPoweredName();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.translate, size: 14),
              const SizedBox(width: 4),
              Text(
                t.translationResult,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.withValues(alpha: 0.05),
                ),
                child: Text(
                  'Powered by $poweredName',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: translationController,
            builder: (context, _) {
              if (translationController.isTranslating) {
                return Skeletonizer.zone(child: Bone.multiText(lines: 3));
              }
              if (translationController.hasTranslation) {
                return CustomMarkdownWidget(
                  data: translationController.translatedText!,
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class TranslationWidget extends StatefulWidget {
  const TranslationWidget({super.key, required this.data, required this.title});

  final String data;
  final Widget title;

  @override
  State<TranslationWidget> createState() => _TranslationWidgetState();
}

class _TranslationWidgetState extends State<TranslationWidget> {
  final TranslationController translationController = TranslationController();
  late Sort selectedLanguage;

  @override
  void initState() {
    super.initState();
    String? savedLang = appdata.implicitData['currentLanguage'];
    selectedLanguage = savedLang != null
        ? translationSorts.firstWhere(
            (s) => s.extData == savedLang,
            orElse: () => translationSorts.first,
          )
        : translationSorts.first;
  }

  @override
  void dispose() {
    translationController.dispose();
    super.dispose();
  }

  Future<void> handleTranslation(String text, {String? targetLanguage}) async {
    await translationController.translate(text, targetLanguage: targetLanguage);
  }

  void _showDialogSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => DefaultTabController(
        length: 2,
        child: ContentDialog(
          title: t.selectTranslationLanguage,
          displayButton: false,
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                // ── 语言 / 翻译源 切换 ───────────────
                TabBar(
                  tabAlignment: TabAlignment.center,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.translate, size: 18),
                      text: t.selectTranslationLanguage,
                    ),
                    Tab(
                      icon: const Icon(Icons.sync_alt, size: 18),
                      text: t.translationService,
                    ),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.of(dialogContext).size.height * 0.6,
                  child: TabBarView(
                    children: [
                      _buildLanguageList(dialogContext),
                      _buildSourceList(dialogContext),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageList(BuildContext dialogContext) {
    final primary = Theme.of(dialogContext).colorScheme.primary;
    final outlineVariant = Theme.of(dialogContext).colorScheme.outlineVariant;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        dialogContext,
      ).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: RadioGroup<SortId>(
          groupValue: selectedLanguage.id,
          onChanged: (_) {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: translationSorts.map((sort) {
              final isSelected = sort.id == selectedLanguage.id;
              return ListTile(
                dense: true,
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.translate,
                  size: 20,
                  color: isSelected ? primary : outlineVariant,
                ),
                title: Text(
                  sort.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Radio<SortId>(value: sort.id),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  handleTranslation(widget.data, targetLanguage: sort.extData);
                  selectedLanguage = sort;
                  appdata.implicitData['currentLanguage'] = sort.extData;
                  appdata.writeImplicitData();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceList(BuildContext dialogContext) {
    final currentSource =
        (appdata.settings['translationSource'] as String?) ?? 'bing';
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        dialogContext,
      ).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: RadioGroup<String>(
          groupValue: currentSource,
          onChanged: (_) {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: translationSourceList.entries.map((entry) {
              final source = translationSourceDisplayMap[entry.key]!;
              final isAi = [
                'siliconFlow',
                'doubao',
                'gemini',
                'qiniu',
                'deepseek',
                'openrouter',
                'ohmygpt',
              ].contains(source);
              final isDeepL = source == 'deepl';
              return ListTile(
                dense: true,
                leading: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6B8DE3), Color(0xFF8B5CF6)],
                  ).createShader(bounds),
                  child: Icon(
                    isAi ? Icons.auto_awesome : Icons.language,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  entry.value,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Radio<String>(value: source),
                onTap: () =>
                    _selectSource(dialogContext, source, isDeepL, isAi),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _selectSource(
    BuildContext dialogContext,
    String source,
    bool isDeepL,
    bool isAi,
  ) async {
    if (isDeepL) {
      final key = appdata.settings['deeplKey'] as String?;
      if (key == null || key.isEmpty) {
        Navigator.of(dialogContext).pop();
        await showPopUpWidget(App.rootContext, const DeepLConfigPage());
        return;
      }
    }
    if (isAi) {
      final keyRow = await AiDatabase.instance.aiApiKeyDao.getByProvider(
        source,
      );
      if (keyRow == null || keyRow.apiKey.isEmpty || !keyRow.isEnabled) {
        App.rootContext.showMessage(
          message: t.pleaseConfigureApiKeyInAiSettingsFirst,
        );
        return;
      }
    }
    appdata.settings['translationSource'] = source;
    appdata.saveData();
    Navigator.of(dialogContext).pop();
    App.rootContext.showMessage(message: t.saved);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: translationController,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: widget.title),
                IconButton(
                  onPressed: translationController.isTranslating
                      ? null
                      : () => handleTranslation(widget.data),
                  icon: translationController.isTranslating
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: PolygonRefreshIndicator(),
                        )
                      : Icon(
                          Icons.translate,
                          size: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),
                SizedBox(width: 8),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ExpandableText(
                text: widget.data,
                translationController: translationController,
              ),
            ),
          ],
        );
      },
    );
  }
}

class TranslateIconButton extends StatefulWidget {
  const TranslateIconButton({
    super.key,
    required this.data,
    required this.controller,
    this.iconSize = 24.0,
    this.targetLanguage,
  });

  final String data;
  final TranslationController controller;
  final double iconSize;
  final String? targetLanguage;

  @override
  State<TranslateIconButton> createState() => _TranslateIconButtonState();
}

class _TranslateIconButtonState extends State<TranslateIconButton> {
  late Sort _selectedLanguage;

  @override
  void initState() {
    super.initState();
    final saved = appdata.implicitData['currentLanguage'] as String?;
    _selectedLanguage = saved != null
        ? translationSorts.firstWhere(
            (s) => s.extData == saved,
            orElse: () => translationSorts.first,
          )
        : translationSorts.first;
  }

  Future<void> _translate({String? targetLanguage}) async {
    await widget.controller.translate(
      widget.data,
      targetLanguage: targetLanguage ?? widget.targetLanguage,
    );
  }

  void _showLanguageDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.selectTranslationLanguage,
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: RadioGroup<SortId>(
              groupValue: _selectedLanguage.id,
              onChanged: (_) {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: translationSorts.map((sort) {
                  return ListTile(
                    dense: true,
                    title: Text(sort.label),
                    trailing: Radio<SortId>(value: sort.id),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => _selectedLanguage = sort);
                      appdata.implicitData['currentLanguage'] = sort.extData;
                      appdata.writeImplicitData();
                      _translate(targetLanguage: sort.extData);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isTranslating = widget.controller.isTranslating;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: t.translationResult,
              onPressed: isTranslating ? null : () => _translate(),
              icon: isTranslating
                  ? SizedBox(
                      width: widget.iconSize,
                      height: widget.iconSize,
                      child: PolygonRefreshIndicator(),
                    )
                  : Icon(
                      Icons.translate,
                      size: widget.iconSize,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
            if (widget.targetLanguage == null)
              IconButton(
                tooltip: t.selectTranslationLanguage,
                onPressed: isTranslating ? null : _showLanguageDialog,
                icon: Icon(
                  Icons.keyboard_double_arrow_down_rounded,
                  size: widget.iconSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        );
      },
    );
  }
}

class TranslationOutput extends StatelessWidget {
  const TranslationOutput({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.symmetric(horizontal: 0),
  });

  final TranslationController controller;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isTranslating && !controller.hasTranslation) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: padding,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.translate, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      t.translationResult,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.withValues(alpha: 0.05),
                      ),
                      child: Text(
                        'Powered by ${TranslationService.getPoweredName()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (controller.isTranslating)
                  Skeletonizer.zone(child: Bone.multiText(lines: 3))
                else if (controller.hasTranslation)
                  CustomMarkdownWidget(data: controller.translatedText!),
              ],
            ),
          ),
        );
      },
    );
  }
}
