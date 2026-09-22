// 角色卡编辑 / 查看组件（故事与全局角色卡库共用）

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/translation_widget.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_conversation_service.dart';
import 'package:kostori/foundation/ai_service/ai_factory.dart';
import 'package:kostori/foundation/ai_service/ai_image_service.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/ai_service/character_lorebook.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/translation/sort.dart';
import 'package:kostori/foundation/translation_service.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/io.dart';

/// 打开角色头像的图片预览（支持 data URL / http）
Future<void> showAvatarPreview(
  BuildContext context, {
  required String name,
  required String avatar,
}) async {
  final provider = CharacterAvatar.resolveAvatar(avatar);
  if (provider == null) return;
  try {
    await BangumiWidget.showImagePreview(
      context: context,
      url: avatar,
      title: name,
      heroTag: 'character_avatar_${identityHashCode(avatar)}',
      imageProvider: provider,
    );
  } catch (_) {}
}

/// 角色头像：有图片（data URL / http）则显示图片，否则显示名字首字
class CharacterAvatar extends StatefulWidget {
  const CharacterAvatar({
    super.key,
    required this.name,
    this.avatar = '',
    this.radius = 16,
    this.onTap,
    this.enablePreview = true,
  });

  final String name;
  final String avatar;
  final double radius;

  /// 自定义点击行为；为空且 [enablePreview] 为真时，默认打开图片预览
  final VoidCallback? onTap;

  /// 有图片时是否允许点击预览
  final bool enablePreview;

  /// 解析头像为图片源（data URL / http）；空或无法解析返回 null
  static ImageProvider? resolveAvatar(String avatar) {
    final a = avatar.trim();
    if (a.startsWith('data:image')) {
      final comma = a.indexOf(',');
      if (comma > 0) {
        try {
          return MemoryImage(base64Decode(a.substring(comma + 1)));
        } catch (_) {}
      }
    } else if (a.startsWith('http')) {
      return NetworkImage(a);
    }
    return null;
  }

  @override
  State<CharacterAvatar> createState() => _CharacterAvatarState();
}

class _CharacterAvatarState extends State<CharacterAvatar> {
  ImageProvider? _image;

  @override
  void initState() {
    super.initState();
    _image = CharacterAvatar.resolveAvatar(widget.avatar);
  }

  @override
  void didUpdateWidget(covariant CharacterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同一字符串对象时 == 为 O(1)，避免大 data URL 每次 build 重复解码
    if (!identical(oldWidget.avatar, widget.avatar) &&
        oldWidget.avatar != widget.avatar) {
      _image = CharacterAvatar.resolveAvatar(widget.avatar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = _image;
    if (image != null) {
      final circle = CircleAvatar(
        radius: widget.radius,
        backgroundImage: image,
      );
      final onTap =
          widget.onTap ??
          (widget.enablePreview
              ? () => showAvatarPreview(
                  context,
                  name: widget.name,
                  avatar: widget.avatar,
                )
              : null);
      if (onTap == null) return circle;
      return GestureDetector(onTap: onTap, child: circle);
    }
    final n = widget.name.trim();
    final initial = n.isEmpty ? '' : n.characters.first;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: scheme.primaryContainer,
      child: initial.isEmpty
          ? Icon(
              Icons.person,
              size: widget.radius * 1.1,
              color: scheme.onPrimaryContainer,
            )
          : Text(
              initial,
              style: TextStyle(
                fontSize: widget.radius * 0.9,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
    );
  }
}

/// 头像选择器：预览 + 选图 / AI 生成 / 清除
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    required this.name,
    required this.avatar,
    required this.onChanged,
    this.onGenerate,
  });

  final String name;
  final String avatar;
  final ValueChanged<String> onChanged;

  /// AI 生成头像；为空则不显示「AI 生成」按钮
  final Future<void> Function()? onGenerate;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _generating = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final mime = x.mimeType ?? 'image/png';
    widget.onChanged('data:$mime;base64,${base64Encode(bytes)}');
  }

  Future<void> _generate() async {
    final onGenerate = widget.onGenerate;
    if (onGenerate == null || _generating) return;
    setState(() => _generating = true);
    try {
      await onGenerate();
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CharacterAvatar(
              name: widget.name,
              avatar: widget.avatar,
              radius: 24,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _generating ? null : _pick,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(t.characterPickAvatar),
            ),
            if (widget.onGenerate != null)
              TextButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: PolygonRefreshIndicator(size: 18),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _generating ? t.aiImageGenerating : t.avatarAiGenerate,
                ),
              ),
            if (widget.avatar.trim().isNotEmpty)
              TextButton.icon(
                onPressed: _generating ? null : () => widget.onChanged(''),
                icon: const Icon(Icons.clear, size: 18),
                label: Text(t.clear),
              ),
          ],
        ),
      ),
    );
  }
}

/// 打开角色卡编辑器，返回编辑后的卡片（取消时为 null）
Future<CharacterCard?> showCharacterCardEditor(
  BuildContext context,
  CharacterCard? card,
) {
  return showPopUpWidget<CharacterCard?>(
    context,
    CharacterCardEditor(card: card),
  );
}

/// 角色卡编辑器（新增 / 编辑）
class CharacterCardEditor extends StatefulWidget {
  const CharacterCardEditor({super.key, this.card});

  final CharacterCard? card;

  @override
  State<CharacterCardEditor> createState() => _CharacterCardEditorState();
}

class _CharacterCardEditorState extends State<CharacterCardEditor>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late String _avatar = widget.card?.avatar ?? '';
  late final _nameCtrl = TextEditingController(text: widget.card?.name ?? '');
  late final _descCtrl = TextEditingController(
    text: widget.card?.description ?? '',
  );
  late final _personalityCtrl = TextEditingController(
    text: widget.card?.personality ?? '',
  );
  late final _scenarioCtrl = TextEditingController(
    text: widget.card?.scenario ?? '',
  );
  late final _firstCtrl = TextEditingController(
    text: widget.card?.firstMessage ?? '',
  );
  late final _exampleCtrl = TextEditingController(
    text: widget.card?.exampleDialogue ?? '',
  );
  late final _systemCtrl = TextEditingController(
    text: widget.card?.systemPrompt ?? '',
  );
  late final _postCtrl = TextEditingController(
    text: widget.card?.postHistoryInstructions ?? '',
  );
  late final _tagsCtrl = TextEditingController(
    text: (widget.card?.tags ?? const []).join(', '),
  );
  late final _creatorCtrl = TextEditingController(
    text: widget.card?.creator ?? '',
  );
  late final _nicknameCtrl = TextEditingController(
    text: widget.card?.nickname ?? '',
  );
  late final _creatorNotesCtrl = TextEditingController(
    text: widget.card?.creatorNotes ?? '',
  );
  late final _sourceCtrl = TextEditingController(
    text: (widget.card?.source ?? const []).join('\n'),
  );
  late final _groupGreetingsCtrl = TextEditingController(
    text: (widget.card?.groupOnlyGreetings ?? const []).join('\n'),
  );

  bool get _isNew => widget.card == null;

  /// 正在把角色名翻译成昵称
  bool _translating = false;

  /// 拼头像出图用的提示词（基于名称 / 描述 / 性格 / 场景）
  String _avatarPrompt() {
    final parts = <String>[];
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) parts.add(name);
    final desc = _descCtrl.text.trim();
    if (desc.isNotEmpty) parts.add(desc);
    final persona = _personalityCtrl.text.trim();
    if (persona.isNotEmpty) parts.add(persona);
    final scenario = _scenarioCtrl.text.trim();
    if (scenario.isNotEmpty) parts.add(scenario);
    if (parts.isEmpty) return '';
    return '${parts.join('，')}，'
        'role-play character portrait, head and shoulders, front view, '
        'high quality, square avatar';
  }

  /// AI 生成角色头像：优先用「辅助任务模型 → 头像生成」的服务商/模型
  Future<void> _generateAvatar() async {
    final prompt = _avatarPrompt();
    if (prompt.isEmpty) return;
    final aux = await AiConversationService().loadAuxConfig('avatarImage');
    final base = AiImageGenConfig.load();
    final config = aux.provider.isEmpty
        ? base
        : base.copyWith(provider: aux.provider, model: aux.model ?? '');
    final res = await AiImageService.generate(prompt: prompt, config: config);
    final bytes = res.dataOrNull;
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      App.rootContext.showMessage(
        message: res.errorMessage ?? t.aiImageGenerateFailed,
        level: LogLevel.warning,
      );
      return;
    }
    setState(() {
      _avatar = 'data:image/png;base64,${base64Encode(bytes)}';
    });
  }

  /// 翻译目标语言：跟随应用当前语言，兜底简体中文
  String get _translationTarget {
    final locale = App.locale;
    final country = locale.countryCode;
    final full = (country == null || country.isEmpty)
        ? locale.languageCode
        : '${locale.languageCode}-$country';
    const supported = {
      'zh-CN',
      'zh-TW',
      'en-US',
      'en-GB',
      'ja',
      'ko',
      'fr',
      'de',
      'es',
      'it',
      'pt',
      'ru',
    };
    if (supported.contains(full)) return full;
    if (supported.contains(locale.languageCode)) return locale.languageCode;
    return 'zh-CN';
  }

  /// 上次/默认的目标语言
  Sort _currentTargetSort() {
    final saved = appdata.implicitData['characterNameTargetLang'] as String?;
    return translationSorts.firstWhere(
      (s) => s.extData == saved,
      orElse: () => translationSorts.firstWhere(
        (s) => s.extData == _translationTarget,
        orElse: () => translationSorts.first,
      ),
    );
  }

  /// 选择翻译目标语言
  Future<Sort?> _pickTargetLanguage() {
    final selected = _currentTargetSort();
    return showDialog<Sort>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.selectTranslationLanguage,
        displayButton: false,
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: RadioGroup<SortId>(
              groupValue: selected.id,
              onChanged: (_) {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final sort in translationSorts)
                    ListTile(
                      dense: true,
                      title: Text(sort.label),
                      trailing: Radio<SortId>(value: sort.id),
                      onTap: () => Navigator.of(ctx).pop(sort),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 挑选一个可用的 AI 服务商（优先当前翻译源 / 生成源）
  Future<String?> _resolveNameTranslateProvider() async {
    await OpenAiProviderRegistry.refreshCustomProviders();
    final available = OpenAiProviderRegistry.allProviders.keys.toSet();
    final raw = (appdata.settings['translationSource'] as String? ?? '')
        .toLowerCase();
    final genProvider = appdata.implicitData['settingGenProvider'];
    final preferred = <String>[
      if (_aiTranslateProviders.contains(raw)) raw,
      if (genProvider is String) genProvider,
    ];
    final order = <String>{
      for (final p in preferred)
        if (available.contains(p)) p,
      ...available,
    };
    for (final p in order) {
      if (OpenAiProviderRegistry.isCustomSource(p)) return p;
      final row = await AiDatabase.instance.aiApiKeyDao.getByProvider(p);
      if (row != null && row.apiKey.trim().isNotEmpty && row.isEnabled) {
        return p;
      }
    }
    return null;
  }

  static const _aiTranslateProviders = {
    'siliconflow',
    'doubao',
    'gemini',
    'deepseek',
    'qiniu',
    'openrouter',
    'ohmygpt',
  };

  /// 去掉译文里的引号 / “翻译：” 前缀等噪声
  String _cleanName(String raw) {
    var s = raw.trim();
    if (s.contains('\n')) s = s.split('\n').first.trim();
    s = s.replaceAll(RegExp(r'''^["“”'‘’`]+|["“”'‘’`]+$'''), '').trim();
    s = s.replaceAll(RegExp(r'^(翻译|译文|译名|结果)\s*[:：]\s*'), '').trim();
    return s;
  }

  /// 拼一段角色设定，供翻译时判断性别 / 气质 / 译法
  String _nameTranslateContext() {
    String clip(String s, int max) => s.length > max ? s.substring(0, max) : s;
    final parts = <String>[];
    final tags = _tagsCtrl.text.trim();
    if (tags.isNotEmpty) parts.add('标签：$tags');
    final desc = _descCtrl.text.trim();
    if (desc.isNotEmpty) parts.add('描述：${clip(desc, 300)}');
    final persona = _personalityCtrl.text.trim();
    if (persona.isNotEmpty) parts.add('性格：${clip(persona, 200)}');
    final scenario = _scenarioCtrl.text.trim();
    if (scenario.isNotEmpty) parts.add('场景：${clip(scenario, 200)}');
    return parts.join('\n');
  }

  /// 翻译角色名：优先用 AI 转写专名，失败再退回普通翻译
  Future<String> _translateName(String name, String lang) async {
    final label = translationSorts.labelByExtData(lang);
    final aux = await AiConversationService().loadAuxConfig('charTranslate');
    final provider = aux.provider.isNotEmpty
        ? aux.provider
        : await _resolveNameTranslateProvider();
    if (provider != null) {
      final ai = AiFactory.create(provider);
      if (ai != null) {
        final context = _nameTranslateContext();
        final res = await ai.generate(
          [
            '目标语言：$label',
            '角色名：$name',
            if (context.isNotEmpty) '角色设定：\n$context',
          ].join('\n'),
          systemPrompt:
              '你是角色名本地化助手，负责把角色名翻译成目标语言里好听、地道的译名。\n'
              '规则：\n'
              '1. 只输出译名本身，不要解释、不要加引号、不要任何标注。\n'
              '2. 人名按目标语言书写习惯音译/意译，选常见、顺口、符合角色性别与气质的字。\n'
              '3. 保持原文的姓名顺序：原文「名+姓」就译成「名·姓」，用「·」连接名与姓。\n'
              '4. 连接词（and / & / 等）译为「 & 」或目标语言对应的连接词，不要直译成句子。\n'
              '5. 结合给定的角色设定判断性别、身份与风格来选字。',
          modelOverride: aux.model,
          params: aux.temperature == null
              ? null
              : AiGenerationParams(temperature: aux.temperature),
        );
        final out = _cleanName(res.dataOrNull ?? '');
        if (out.isNotEmpty) return out;
      }
    }
    final res = await TranslationService().translate(
      name,
      targetLanguage: lang,
    );
    return _cleanName(res.dataOrNull ?? '');
  }

  /// 把角色名翻译后填入昵称（英文名 → 中文名等）
  Future<void> _translateNameToNickname({bool pickLanguage = false}) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final Sort? lang = pickLanguage
        ? await _pickTargetLanguage()
        : _currentTargetSort();
    if (lang == null || !mounted) return;
    appdata.implicitData['characterNameTargetLang'] = lang.extData;
    appdata.writeImplicitData();
    setState(() => _translating = true);
    try {
      final text = await _translateName(name, lang.extData);
      if (!mounted) return;
      if (text.isEmpty) {
        App.rootContext.showMessage(
          message: t.translationFailed,
          level: LogLevel.warning,
        );
        return;
      }
      setState(() {
        _nicknameCtrl.text = text;
      });
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  /// 世界书条目（可编辑副本）
  late List<Map<String, dynamic>> _bookEntries;

  @override
  void initState() {
    super.initState();
    final book = CharacterLoreBook.fromMap(widget.card?.characterBook);
    _bookEntries = [
      for (final e in book?.entries ?? const <CharacterLoreEntry>[])
        {
          'name': e.name,
          'keys': e.keys,
          if (e.secondaryKeys.isNotEmpty) 'secondary_keys': e.secondaryKeys,
          'content': e.content,
          'constant': e.constant,
          'recursive': false,
          'enabled': e.enabled,
        },
    ];
  }

  bool _tabCtrlReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 不能在 initState 里构建页签（部分页签会调用 Theme.of），放到这里
    if (!_tabCtrlReady) {
      _tabCtrl = TabController(length: _editorTabs().length, vsync: this);
      _tabCtrlReady = true;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _personalityCtrl.dispose();
    _scenarioCtrl.dispose();
    _firstCtrl.dispose();
    _exampleCtrl.dispose();
    _systemCtrl.dispose();
    _postCtrl.dispose();
    _tagsCtrl.dispose();
    _creatorCtrl.dispose();
    _nicknameCtrl.dispose();
    _creatorNotesCtrl.dispose();
    _sourceCtrl.dispose();
    _groupGreetingsCtrl.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController ctrl) => ctrl.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final card = CharacterCard(
      id: widget.card?.id ?? 'card_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      avatar: _avatar,
      description: _descCtrl.text.trim(),
      personality: _personalityCtrl.text.trim(),
      scenario: _scenarioCtrl.text.trim(),
      firstMessage: _firstCtrl.text.trim(),
      exampleDialogue: _exampleCtrl.text.trim(),
      systemPrompt: _systemCtrl.text.trim(),
      postHistoryInstructions: _postCtrl.text.trim(),
      tags: _tagsCtrl.text
          .split(RegExp(r'[,，]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      creator: _creatorCtrl.text.trim(),
      nickname: _nicknameCtrl.text.trim(),
      creatorNotes: _creatorNotesCtrl.text.trim(),
      source: _lines(_sourceCtrl),
      groupOnlyGreetings: _lines(_groupGreetingsCtrl),
      creationDate: widget.card?.creationDate,
      modificationDate: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      creatorNotesMultilingual:
          widget.card?.creatorNotesMultilingual ?? const {},
      assets: widget.card?.assets ?? const [],
      extensions: widget.card?.extensions ?? const {},
      characterBook: _bookEntries.isEmpty
          ? null
          : {...?widget.card?.characterBook, 'entries': _bookEntries},
      specVersion: widget.card?.specVersion ?? '3.0',
    );
    // 编辑器在 PopUpWidget 的嵌套 Navigator 里，必须 pop 根 Navigator，
    // 否则只会弹掉内层路由（弹窗留成黑屏）且卡片无法返回
    Navigator.of(context, rootNavigator: true).pop(card);
  }

  late final TabController _tabCtrl;

  List<(String, Widget)> _editorTabs() => [
    (t.basicInfo, _basicSection()),
    (t.storyCharacterPersona, _personaSection()),
    (t.characterDialogue, _dialogueSection()),
    (t.storySystemPrompt, _promptSection()),
    (t.worldBook, _worldBookSection()),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _editorTabs();
    return PopUpWidgetScaffold(
      title: _isNew ? t.storyAddCharacter : t.edit,
      tailing: [
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: t.apply,
          onPressed: _save,
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: CapsuleOptions(
                scrollable: true,
                progress: _tabCtrl.animation,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    CapsuleOption(
                      text: tabs[i].$1,
                      isSelected: _tabCtrl.index == i,
                      onTap: () => _tabCtrl.animateTo(i),
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  for (final tab in tabs)
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                      child: tab.$2,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _basicSection() => Column(
    children: [
      AvatarPicker(
        name: _nameCtrl.text,
        avatar: _avatar,
        onChanged: (v) => setState(() => _avatar = v),
        onGenerate: _generateAvatar,
      ),
      _field(t.storyCharacterName, _nameCtrl),
      _field(
        t.characterNickname,
        _nicknameCtrl,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: t.translate,
              onPressed: _translating ? null : () => _translateNameToNickname(),
              icon: _translating
                  ? const PolygonRefreshIndicator(size: 16)
                  : const Icon(Icons.translate, size: 18),
            ),
            IconButton(
              tooltip: t.selectTranslationLanguage,
              onPressed: _translating
                  ? null
                  : () => _translateNameToNickname(pickLanguage: true),
              icon: const Icon(
                Icons.keyboard_double_arrow_down_rounded,
                size: 18,
              ),
            ),
          ],
        ),
      ),
      _field(t.characterTags, _tagsCtrl),
      _field(t.characterCreator, _creatorCtrl),
    ],
  );

  Widget _personaSection() => Column(
    children: [
      _field(t.characterDescription, _descCtrl, multiline: true),
      _field(t.characterPersonality, _personalityCtrl, multiline: true),
      _field(t.characterScenario, _scenarioCtrl, multiline: true),
    ],
  );

  Widget _dialogueSection() => Column(
    children: [
      _field(t.characterFirstMessage, _firstCtrl, multiline: true),
      _field(t.characterExampleDialogue, _exampleCtrl, multiline: true),
      _field(t.characterGroupGreetings, _groupGreetingsCtrl, multiline: true),
    ],
  );

  Widget _promptSection() => Column(
    children: [
      _field(t.characterSystemPrompt, _systemCtrl, multiline: true),
      _field(t.characterPostHistory, _postCtrl, multiline: true),
      _field(t.characterCreatorNotes, _creatorNotesCtrl, multiline: true),
      _field(t.characterSource, _sourceCtrl, multiline: true),
    ],
  );

  Widget _worldBookSection() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bookEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              t.storyNoEntries,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        for (var i = 0; i < _bookEntries.length; i++) _bookEntryTile(i, scheme),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _editBookEntry(null),
            icon: const Icon(Icons.add, size: 18),
            label: Text(t.storyAddEntry),
          ),
        ),
      ],
    );
  }

  Widget _bookEntryTile(int i, ColorScheme scheme) {
    final e = _bookEntries[i];
    final name = e['name']?.toString().trim() ?? '';
    final keys = (e['keys'] as List?)?.whereType<String>().toList() ?? const [];
    final enabled = e['enabled'] != false;
    final constant = e['constant'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          constant ? Icons.push_pin_outlined : Icons.menu_book_outlined,
          size: 18,
          color: enabled ? scheme.primary : scheme.outline,
        ),
        title: Text(
          name.isEmpty ? '${t.storyCodex} ${i + 1}' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? null : scheme.outline,
          ),
        ),
        subtitle: keys.isEmpty
            ? null
            : Text(
                keys.join('、'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: t.edit,
              icon: const Icon(Icons.edit_note, size: 18),
              onPressed: () => _editBookEntry(i),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: t.delete,
              icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
              onPressed: () => setState(() => _bookEntries.removeAt(i)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBookEntry(int? index) async {
    final existing = index == null ? null : _bookEntries[index];
    final nameCtrl = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    final keysCtrl = TextEditingController(
      text: ((existing?['keys'] as List?) ?? const []).join('、'),
    );
    final contentCtrl = TextEditingController(
      text: existing?['content']?.toString() ?? '',
    );
    var constant = existing?['constant'] == true;
    var recursive = existing?['recursive'] == true;
    var enabled = existing?['enabled'] != false;

    final ok = await showDialog<bool>(
      context: App.rootContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => ContentDialog(
          title: index == null ? t.storyAddEntry : t.edit,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: t.storyCharacterName,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: keysCtrl,
                  decoration: InputDecoration(
                    labelText: t.storyLoreKeys,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentCtrl,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: t.characterDescription,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                _switchRow(t.storyLoreConstant, constant, (v) {
                  setLocal(() => constant = v);
                }),
                _switchRow(t.storyLoreRecursive, recursive, (v) {
                  setLocal(() => recursive = v);
                }),
                _switchRow(t.enabled, enabled, (v) {
                  setLocal(() => enabled = v);
                }),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.confirm),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) {
      nameCtrl.dispose();
      keysCtrl.dispose();
      contentCtrl.dispose();
      return;
    }
    final entry = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'keys': keysCtrl.text
          .split(RegExp(r'[,，、]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'content': contentCtrl.text.trim(),
      'constant': constant,
      'recursive': recursive,
      'enabled': enabled,
    };
    nameCtrl.dispose();
    keysCtrl.dispose();
    contentCtrl.dispose();
    setState(() {
      if (index == null) {
        _bookEntries.add(entry);
      } else {
        _bookEntries[index] = entry;
      }
    });
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool multiline = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextFormField(
        controller: ctrl,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 8 : 1,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

/// 角色卡查看（只读展示）
class CharacterCardView extends StatefulWidget {
  const CharacterCardView({super.key, required this.card});

  final CharacterCard card;

  @override
  State<CharacterCardView> createState() => _CharacterCardViewState();
}

class _CharacterCardViewState extends State<CharacterCardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  CharacterCard get card => widget.card;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _copyName() {
    Clipboard.setData(ClipboardData(text: card.displayName));
    App.rootContext.showMessage(message: t.copied);
  }

  /// 每个字段一个翻译控制器（英文卡可一键翻译查看）
  final Map<String, TranslationController> _transCtrl = {};

  TranslationController _ctrlFor(String key) =>
      _transCtrl.putIfAbsent(key, () => TranslationController());

  Widget _block(BuildContext context, String title, String content) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final tc = _ctrlFor(title);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              TranslateIconButton(
                data: content.trim(),
                controller: tc,
                iconSize: 18,
              ),
            ],
          ),
          const SizedBox(height: 4),
          AppSelectableText(
            content.trim(),
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          TranslationOutput(
            controller: tc,
            padding: const EdgeInsets.only(top: 8),
          ),
        ],
      ),
    );
  }

  /// 世界书单条：名称 / 触发词 / 常驻 / 内容
  Widget _loreEntry(BuildContext context, CharacterLoreEntry e) {
    final scheme = Theme.of(context).colorScheme;
    final title = e.name.trim().isEmpty
        ? '${t.storyCodex} ${e.index + 1}'
        : e.name.trim();
    final marks = <String>[
      if (e.constant) t.storyLoreConstant,
      if (!e.enabled) t.disabled,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                e.constant ? Icons.push_pin_outlined : Icons.menu_book_outlined,
                size: 15,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (marks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    marks.join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          if (e.keys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 21),
              child: Text(
                '${t.storyLoreKeys}: ${e.keys.join('、')}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          if (e.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 21),
              child: AppSelectableText(
                e.content.trim(),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final book = CharacterLoreBook.fromMap(card.characterBook);

    final basic = <Widget>[
      Row(
        children: [
          CharacterAvatar(
            name: card.displayName,
            avatar: card.avatar,
            radius: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _copyName,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            card.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                if (card.displayName != card.name)
                  Text(
                    card.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (card.creator.trim().isNotEmpty)
                  Text(
                    card.creator.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      if (card.tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in card.tags)
                Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      _block(context, t.characterDescription, card.description),
    ];

    final persona = <Widget>[
      _block(context, t.characterPersonality, card.personality),
      _block(context, t.characterScenario, card.scenario),
    ];

    final dialogue = <Widget>[
      _block(context, t.characterFirstMessage, card.firstMessage),
      if (card.alternateGreetings.isNotEmpty)
        _block(
          context,
          t.characterAlternateGreetings,
          card.alternateGreetings.join('\n\n---\n\n'),
        ),
      _block(context, t.characterExampleDialogue, card.exampleDialogue),
    ];

    final prompt = <Widget>[
      _block(context, t.characterSystemPrompt, card.systemPrompt),
      _block(context, t.characterPostHistory, card.postHistoryInstructions),
      _block(context, t.characterCreatorNotes, card.creatorNotes),
      _block(context, t.characterSource, card.source.join('\n')),
      if (book != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            '${t.worldBook} · ${book.entries.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
        ),
        for (final e in book.entries) _loreEntry(context, e),
      ],
    ];

    final tabs = <(String, List<Widget>)>[
      (t.basicInfo, basic),
      (t.storyCharacterPersona, persona),
      (t.characterDialogue, dialogue),
      (t.storySystemPrompt, prompt),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: CapsuleOptions(
            alignment: WrapAlignment.center,
            progress: _tabCtrl.animation,
            children: [
              for (var i = 0; i < tabs.length; i++)
                CapsuleOption(
                  text: tabs[i].$1,
                  isSelected: _tabCtrl.index == i,
                  onTap: () => _tabCtrl.animateTo(i),
                ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              for (final tab in tabs)
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: tab.$2,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 渲染角色卡图片（头像 emoji + 名字，纯色渐变背景）
Future<Uint8List?> renderCharacterCardImage(
  CharacterCard card, {
  double size = 512,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, size, size);
  final hash = card.name.codeUnits.fold<int>(0, (a, b) => a + b);
  final baseColor = HSVColor.fromAHSV(
    1,
    (hash * 37) % 360,
    0.45,
    0.35,
  ).toColor();
  final paint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [baseColor, baseColor.withValues(alpha: 0.6)],
    ).createShader(rect);
  canvas.drawRect(rect, paint);

  final n = card.name.trim();
  final initial = n.isEmpty ? '' : n.characters.first;
  if (initial.isNotEmpty) {
    final avatarTp = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          fontSize: size * 0.42,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    avatarTp.paint(canvas, Offset((size - avatarTp.width) / 2, size * 0.16));
  }

  final nameTp = TextPainter(
    text: TextSpan(
      text: card.displayName,
      style: TextStyle(
        fontSize: size * 0.09,
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: size * 0.86);
  nameTp.paint(canvas, Offset((size - nameTp.width) / 2, size * 0.68));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return data?.buffer.asUint8List();
}

/// 导出角色卡为 PNG（内嵌 chara 块），酒馆可直接导入
Future<void> exportCharacterCardPng(CharacterCard card, {int spec = 3}) async {
  final base = card.decodeAvatarImage() ?? await renderCharacterCardImage(card);
  if (base == null) return;
  final png = CharacterCard.embedCharaChunk(base, card.toCharaText(spec: spec));
  await saveFile(data: png, filename: '${card.name}.png');
}

/// 以底部弹窗展示角色卡
Future<void> showCharacterCardView(BuildContext context, CharacterCard card) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Sheet(
      title: card.displayName,
      icon: Icons.badge_outlined,
      initialSize: 0.7,
      builder: (ctx, sc) => CharacterCardView(card: card),
    ),
  );
}
