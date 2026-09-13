// 角色卡编辑 / 查看组件（故事与全局角色卡库共用）

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/ai_service/character_lorebook.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/io.dart';

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
      avatar: widget.card?.avatar ?? '🧑',
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
class CharacterCardView extends StatelessWidget {
  const CharacterCardView({super.key, required this.card});

  final CharacterCard card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget block(String title, String content) {
      if (content.trim().isEmpty) return const SizedBox.shrink();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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
          if (card.nickname.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                card.nickname.trim(),
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          block(t.characterDescription, card.description),
          block(t.characterPersonality, card.personality),
          block(t.characterScenario, card.scenario),
          block(t.characterFirstMessage, card.firstMessage),
          block(t.characterExampleDialogue, card.exampleDialogue),
          block(t.characterSystemPrompt, card.systemPrompt),
          block(t.characterPostHistory, card.postHistoryInstructions),
          block(t.characterCreatorNotes, card.creatorNotes),
          block(t.characterSource, card.source.join('\n')),
          if (CharacterLoreBook.fromMap(card.characterBook)?.entries.isNotEmpty ??
              false)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${t.worldBook} · '
                '${CharacterLoreBook.fromMap(card.characterBook)!.entries.length}',
                style: TextStyle(fontSize: 12, color: scheme.primary),
              ),
            ),
        ],
      ),
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

  final avatarTp = TextPainter(
    text: TextSpan(
      text: card.avatar.isEmpty ? '🧑' : card.avatar,
      style: TextStyle(fontSize: size * 0.42),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  avatarTp.paint(canvas, Offset((size - avatarTp.width) / 2, size * 0.16));

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
      builder: (ctx, sc) => ListView(
        controller: sc,
        children: [CharacterCardView(card: card)],
      ),
    ),
  );
}
