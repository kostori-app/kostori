import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/skills/skill.dart';

/// 询问用户（human-in-the-loop）：模型需要澄清需求、补充信息或确认操作时调用，
/// 应用弹出问答界面收集用户回答后回传（参考 RikkaHub 的 ask_user 工具）。
class AskUserSkill extends Skill {
  @override
  String get id => 'ask_user';

  @override
  String get name => 'ask_user';

  @override
  String get description =>
      '向用户提出一个或多个问题，用于澄清需求、补充信息或请求确认。'
      '每题可给出建议选项；用户始终可以自由输入（多选时可与选项并用）。'
      '返回 JSON 对象：问题 id → 用户的回答。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'questions': {
        'type': 'array',
        'description': '要询问的问题列表',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'description': '问题的唯一标识'},
            'question': {'type': 'string', 'description': '展示给用户的问题文本'},
            'options': {
              'type': 'array',
              'description': '可选的建议选项',
              'items': {'type': 'string'},
            },
            'selection_type': {
              'type': 'string',
              'enum': ['text', 'single', 'multi'],
              'description': '回答类型：text=自由输入（默认）；single=单选；multi=多选（可补充自定义文本）',
            },
          },
          'required': ['id', 'question'],
        },
      },
    },
    'required': ['questions'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final raw = arguments['questions'];
    if (raw is! List || raw.isEmpty) {
      throw SkillException('questions 不能为空');
    }
    final questions = <_AskQuestion>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final id = e['id']?.toString().trim() ?? '';
      final question = e['question']?.toString().trim() ?? '';
      if (id.isEmpty || question.isEmpty) continue;
      questions.add(
        _AskQuestion(
          id: id,
          question: question,
          options:
              (e['options'] as List?)
                  ?.map((x) => x.toString())
                  .where((x) => x.trim().isNotEmpty)
                  .toList() ??
              const [],
          type: e['selection_type']?.toString() ?? 'text',
        ),
      );
    }
    if (questions.isEmpty) throw SkillException('questions 不合法');
    final answers = await showAskUserDialog(questions);
    if (answers == null) return '用户取消了回答（未提供信息）。';
    return jsonEncode(answers);
  }
}

class _AskQuestion {
  const _AskQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.type,
  });

  final String id;
  final String question;
  final List<String> options;

  /// text / single / multi
  final String type;
}

/// 弹出问答对话框；返回 问题 id → 回答（多选用「、」连接），取消返回 null
Future<Map<String, String>?> showAskUserDialog(List<_AskQuestion> questions) {
  return showDialog<Map<String, String>>(
    context: App.rootContext,
    builder: (_) => _AskUserDialog(questions: questions),
  );
}

class _AskUserDialog extends StatefulWidget {
  const _AskUserDialog({required this.questions});

  final List<_AskQuestion> questions;

  @override
  State<_AskUserDialog> createState() => _AskUserDialogState();
}

class _AskUserDialogState extends State<_AskUserDialog> {
  late final List<TextEditingController> _texts;
  late final List<Set<String>> _picked;

  @override
  void initState() {
    super.initState();
    _texts = [for (final _ in widget.questions) TextEditingController()];
    _picked = [for (final _ in widget.questions) <String>{}];
  }

  @override
  void dispose() {
    for (final c in _texts) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final result = <String, String>{};
    for (var i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final custom = _texts[i].text.trim();
      if (q.type == 'multi') {
        final parts = [..._picked[i], if (custom.isNotEmpty) custom];
        result[q.id] = parts.join('、');
      } else if (q.type == 'single') {
        result[q.id] = custom.isNotEmpty
            ? custom
            : (_picked[i].firstOrNull ?? '');
      } else {
        result[q.id] = custom;
      }
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ContentDialog(
      title: t.askUser,
      displayButton: false,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.questions.length; i++) ...[
                Text(
                  widget.questions[i].question,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (widget.questions[i].options.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final opt in widget.questions[i].options)
                        widget.questions[i].type == 'multi'
                            ? FilterChip(
                                label: Text(opt),
                                selected: _picked[i].contains(opt),
                                visualDensity: VisualDensity.compact,
                                onSelected: (v) => setState(() {
                                  if (v) {
                                    _picked[i].add(opt);
                                  } else {
                                    _picked[i].remove(opt);
                                  }
                                }),
                              )
                            : ChoiceChip(
                                label: Text(opt),
                                selected: _picked[i].contains(opt),
                                visualDensity: VisualDensity.compact,
                                onSelected: (v) => setState(() {
                                  _picked[i]
                                    ..clear()
                                    ..addAll(v ? {opt} : {});
                                }),
                              ),
                    ],
                  ),
                const SizedBox(height: 6),
                TextField(
                  controller: _texts[i],
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t.askUserInputHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (i != widget.questions.length - 1)
                  Divider(height: 24, color: scheme.outlineVariant),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(onPressed: _submit, child: Text(t.confirm)),
        ),
      ],
    );
  }
}
