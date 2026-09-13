// 角色卡编辑 / 查看组件（故事与全局角色卡库共用）

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/ai_service/character_lorebook.dart';
import 'package:kostori/foundation/app.dart';
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

/// 头像选择器：预览 + 选图 / 清除
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.name,
    required this.avatar,
    required this.onChanged,
  });

  final String name;
  final String avatar;
  final ValueChanged<String> onChanged;

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
    onChanged('data:$mime;base64,${base64Encode(bytes)}');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          CharacterAvatar(name: name, avatar: avatar, radius: 24),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.image_outlined, size: 18),
            label: Text(t.characterPickAvatar),
          ),
          if (avatar.trim().isNotEmpty)
            TextButton.icon(
              onPressed: () => onChanged(''),
              icon: const Icon(Icons.clear, size: 18),
              label: Text(t.clear),
            ),
        ],
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

class _CharacterCardEditorState extends State<CharacterCardEditor> {
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

  @override
  void dispose() {
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
      creatorNotesMultilingual: widget.card?.creatorNotesMultilingual ?? const {},
      assets: widget.card?.assets ?? const [],
      extensions: widget.card?.extensions ?? const {},
      characterBook: widget.card?.characterBook,
      specVersion: widget.card?.specVersion ?? '3.0',
    );
    Navigator.of(context).pop(card);
  }

  @override
  Widget build(BuildContext context) {
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(t.storyCharacterName, _nameCtrl),
            AvatarPicker(
              name: _nameCtrl.text,
              avatar: _avatar,
              onChanged: (v) => setState(() => _avatar = v),
            ),
            _field(t.characterDescription, _descCtrl, multiline: true),
            _field(t.characterPersonality, _personalityCtrl, multiline: true),
            _field(t.characterScenario, _scenarioCtrl, multiline: true),
            _field(t.characterFirstMessage, _firstCtrl, multiline: true),
            _field(t.characterExampleDialogue, _exampleCtrl, multiline: true),
            _field(t.characterSystemPrompt, _systemCtrl, multiline: true),
            _field(t.characterPostHistory, _postCtrl, multiline: true),
            _field(t.characterNickname, _nicknameCtrl, required: false),
            _field(t.characterCreatorNotes, _creatorNotesCtrl, multiline: true, required: false),
            _field(t.characterSource, _sourceCtrl, multiline: true, required: false),
            _field(
              t.characterGroupGreetings,
              _groupGreetingsCtrl,
              multiline: true,
              required: false,
            ),
            _field(t.characterTags, _tagsCtrl, required: false),
            _field(t.characterCreator, _creatorCtrl, required: false),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = true,
    bool multiline = false,
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
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? t.required : null
            : null,
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
    Clipboard.setData(ClipboardData(text: card.name));
    App.rootContext.showMessage(message: t.copied);
  }

  Widget _block(BuildContext context, String title, String content) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            content.trim(),
            style: const TextStyle(fontSize: 13, height: 1.5),
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
                e.constant
                    ? Icons.push_pin_outlined
                    : Icons.menu_book_outlined,
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
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (e.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 21),
              child: SelectableText(
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
          CharacterAvatar(name: card.name, avatar: card.avatar, radius: 26),
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
                            card.name,
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
                if (card.nickname.trim().isNotEmpty)
                  Text(
                    card.nickname.trim(),
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
      text: card.name,
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
Future<void> exportCharacterCardPng(
  CharacterCard card, {
  int spec = 3,
}) async {
  final base =
      card.decodeAvatarImage() ?? await renderCharacterCardImage(card);
  if (base == null) return;
  final png = CharacterCard.embedCharaChunk(
    base,
    card.toCharaText(spec: spec),
  );
  await saveFile(data: png, filename: '${card.name}.png');
}

/// 以底部弹窗展示角色卡
Future<void> showCharacterCardView(BuildContext context, CharacterCard card) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Sheet(
      title: card.name,
      icon: Icons.badge_outlined,
      initialSize: 0.7,
      builder: (ctx, sc) => CharacterCardView(card: card),
    ),
  );
}
