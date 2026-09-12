part of 'settings_page.dart';

/// 全局文本规则管理页（不绑定具体番源）：新增/编辑/删除规则
class _TextRulesManagerPage extends StatefulWidget {
  const _TextRulesManagerPage();

  @override
  State<_TextRulesManagerPage> createState() => _TextRulesManagerPageState();
}

class _TextRulesManagerPageState extends State<_TextRulesManagerPage> {
  Future<void> _edit([TextRule? rule]) async {
    final result = await showDialog<TextRule>(
      context: context,
      builder: (_) => _TextRuleEditorDialog(initial: rule),
    );
    if (result == null || !mounted) return;
    final rules = TextRuleStore.rules;
    if (rule == null) {
      rules.add(result);
    } else {
      final idx = rules.indexWhere((e) => e.id == rule.id);
      if (idx >= 0) rules[idx] = result;
    }
    TextRuleStore.save();
    setState(() {});
  }

  void _delete(TextRule rule) {
    showConfirmDialog(
      context: context,
      title: t.delete,
      content: '${rule.name}\n${t.textRuleDeleteConfirm}',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () {
        TextRuleStore.rules.removeWhere((e) => e.id == rule.id);
        TextRuleStore.save();
        setState(() {});
      },
    );
  }

  Future<void> _selectSources(TextRule rule) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RuleSourcesDialog(rule: rule),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rules = TextRuleStore.rules;
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.textRules,
      tailing: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: t.textRuleAdd,
          onPressed: () => _edit(),
        ),
      ],
      body: rules.isEmpty
          ? Center(
              child: Text(
                t.textRuleNone,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final rule in rules)
                  ListTile(
                    leading: const Icon(Icons.text_fields),
                    title: Text(rule.name.isEmpty ? t.textRuleName : rule.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.steps.isEmpty
                              ? t.textRuleNone
                              : rule.steps
                                    .map((s) => s.find)
                                    .where((s) => s.isNotEmpty)
                                    .join('  →  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.sourceCount(
                            count: SourceTextRuleConfig.countSourcesUsing(
                              rule.id,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          tooltip: t.textRuleSelectSources,
                          icon: const Icon(Icons.playlist_add_check, size: 18),
                          onPressed: () => _selectSources(rule),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          tooltip: t.edit,
                          icon: const Icon(Icons.edit_note, size: 18),
                          onPressed: () => _edit(rule),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          tooltip: t.delete,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: cs.error,
                          ),
                          onPressed: () => _delete(rule),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 选择“哪些番源使用该规则”
class _RuleSourcesDialog extends StatefulWidget {
  const _RuleSourcesDialog({required this.rule});

  final TextRule rule;

  @override
  State<_RuleSourcesDialog> createState() => _RuleSourcesDialogState();
}

class _RuleSourcesDialogState extends State<_RuleSourcesDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = SourceTextRuleConfig.sourcesUsing(widget.rule.id);
  }

  @override
  Widget build(BuildContext context) {
    final sources = AnimeSource.all().toList();
    return ContentDialog(
      title: t.textRuleSelectSources,
      content: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: sources.isEmpty
              ? const Center(child: Text('—'))
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final s in sources)
                        CheckboxListTile(
                          dense: true,
                          value: _selected.contains(s.key),
                          title: Text(s.name),
                          subtitle: Text(
                            s.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(s.key);
                            } else {
                              _selected.remove(s.key);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        Button.filled(
          onPressed: () {
            SourceTextRuleConfig.setSourcesForRule(widget.rule.id, _selected);
            Navigator.of(context).pop();
          },
          child: Text(t.confirm),
        ),
      ],
    );
  }
}

/// 番源“规则”页：文本规则 + 下载标题格式（后续可继续加块）
class _SourceRulesPage extends StatefulWidget {
  const _SourceRulesPage({required this.source});

  final AnimeSource source;

  @override
  State<_SourceRulesPage> createState() => _SourceRulesPageState();
}

class _SourceRulesPageState extends State<_SourceRulesPage> {
  AnimeSource get source => widget.source;

  Future<void> _editDownloadFormat() async {
    final map = Map<String, dynamic>.from(
      appdata.implicitData['downloadTitleFormats'] as Map? ?? {},
    );
    final current = map[source.key] as String? ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _DownloadFormatDialog(initialValue: current),
    );
    if (value == null || !mounted) return;
    final v = value.trim();
    if (v.isEmpty) {
      map.remove(source.key);
    } else {
      map[source.key] = v;
    }
    appdata.implicitData['downloadTitleFormats'] = map;
    appdata.writeImplicitData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selectedRules = SourceTextRuleConfig.rulesFor(source.key);
    final formatMap = appdata.implicitData['downloadTitleFormats'] as Map?;
    final format = formatMap?[source.key]?.toString() ?? '';
    return PopUpWidgetScaffold(
      title: t.rules,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingCard(
            children: [
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: Text(t.textRules),
                subtitle: Text(
                  selectedRules.isEmpty
                      ? t.textRuleNone
                      : selectedRules.map((e) => e.name).join('、'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_right),
                onTap: () async {
                  await showPopUpWidget(
                    context,
                    _SourceTextRulesPage(source: source),
                  );
                  if (mounted) setState(() {});
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.title),
                title: Text(t.downloadTitleFormat),
                subtitle: Text(
                  format.isEmpty ? t.downloadFormatHint : format,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_right),
                onTap: _editDownloadFormat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 选择/管理文本规则：勾选应用到该源，并可新增/编辑/删除规则
class _SourceTextRulesPage extends StatefulWidget {
  const _SourceTextRulesPage({required this.source});

  final AnimeSource source;

  @override
  State<_SourceTextRulesPage> createState() => _SourceTextRulesPageState();
}

class _SourceTextRulesPageState extends State<_SourceTextRulesPage> {
  late List<String> _selected;
  late final TextEditingController _sampleCtrl;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(
      SourceTextRuleConfig.ruleIdsFor(widget.source.key),
    );
    _sampleCtrl = TextEditingController(text: kTextRulePreviewDefault);
  }

  @override
  void dispose() {
    _sampleCtrl.dispose();
    super.dispose();
  }

  /// 用当前选中的规则（按列表顺序）预览套用结果
  String get _preview {
    final sel = _selected.toSet();
    final applied = TextRuleStore.rules
        .where((r) => sel.contains(r.id))
        .toList();
    return TextRuleStore.apply(_sampleCtrl.text, applied);
  }

  void _save() =>
      SourceTextRuleConfig.setRuleIds(widget.source.key, _selected);

  Future<void> _edit([TextRule? rule]) async {
    final result = await showDialog<TextRule>(
      context: context,
      builder: (_) => _TextRuleEditorDialog(initial: rule),
    );
    if (result == null || !mounted) return;
    final rules = TextRuleStore.rules;
    if (rule == null) {
      rules.add(result);
      if (!_selected.contains(result.id)) _selected.add(result.id);
    } else {
      final idx = rules.indexWhere((e) => e.id == rule.id);
      if (idx >= 0) rules[idx] = result;
    }
    TextRuleStore.save();
    _save();
    setState(() {});
  }

  void _delete(TextRule rule) {
    showConfirmDialog(
      context: context,
      title: t.delete,
      content: '${rule.name}\n${t.textRuleDeleteConfirm}',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () {
        TextRuleStore.rules.removeWhere((e) => e.id == rule.id);
        TextRuleStore.save();
        _selected.remove(rule.id);
        _save();
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = TextRuleStore.rules;
    final colorScheme = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.textRules,
      tailing: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: t.textRuleAdd,
          onPressed: () => _edit(),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 实时预览：输入示例文本 → 显示套用当前选中规则后的结果
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _sampleCtrl,
                    maxLines: null,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: t.textRulePreviewInput,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.textRulePreviewResult,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    _preview,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              t.textRuleSelectHint,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t.textRuleNone,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final rule in rules)
              ListTile(
                leading: Checkbox(
                  value: _selected.contains(rule.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        if (!_selected.contains(rule.id)) {
                          _selected.add(rule.id);
                        }
                      } else {
                        _selected.remove(rule.id);
                      }
                    });
                    _save();
                  },
                ),
                title: Text(rule.name.isEmpty ? t.textRuleName : rule.name),
                subtitle: Text(
                  rule.steps.isEmpty
                      ? t.textRuleNone
                      : rule.steps
                            .map((s) => s.find)
                            .where((s) => s.isNotEmpty)
                            .join('  →  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: t.edit,
                      icon: const Icon(Icons.edit_note, size: 18),
                      onPressed: () => _edit(rule),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: t.delete,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      onPressed: () => _delete(rule),
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    if (_selected.contains(rule.id)) {
                      _selected.remove(rule.id);
                    } else {
                      _selected.add(rule.id);
                    }
                  });
                  _save();
                },
              ),
        ],
      ),
    );
  }
}

/// 文本规则编辑：名称 + 若干“查找/替换”步骤
class _TextRuleEditorDialog extends StatefulWidget {
  const _TextRuleEditorDialog({this.initial});

  final TextRule? initial;

  @override
  State<_TextRuleEditorDialog> createState() => _TextRuleEditorDialogState();
}

class _TextRuleStepEdit {
  final TextEditingController find;
  final TextEditingController replace;
  bool caseSensitive;

  _TextRuleStepEdit({
    String findText = '',
    String replaceText = '',
    this.caseSensitive = false,
  }) : find = TextEditingController(text: findText),
       replace = TextEditingController(text: replaceText);

  void dispose() {
    find.dispose();
    replace.dispose();
  }
}

class _TextRuleEditorDialogState extends State<_TextRuleEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sampleCtrl;
  final List<_TextRuleStepEdit> _steps = [];

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _sampleCtrl = TextEditingController(text: kTextRulePreviewDefault);
    if (r != null) {
      for (final s in r.steps) {
        _steps.add(
          _attach(
            _TextRuleStepEdit(
              findText: s.find,
              replaceText: s.replace,
              caseSensitive: s.caseSensitive,
            ),
          ),
        );
      }
    }
    if (_steps.isEmpty) _steps.add(_attach(_TextRuleStepEdit()));
  }

  _TextRuleStepEdit _attach(_TextRuleStepEdit s) {
    s.find.addListener(_onChanged);
    s.replace.addListener(_onChanged);
    return s;
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sampleCtrl.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  void _addStep() => setState(() => _steps.add(_attach(_TextRuleStepEdit())));

  void _removeStep(int i) {
    setState(() {
      _steps.removeAt(i).dispose();
    });
  }

  TextRule _buildRule() {
    final name = _nameCtrl.text.trim();
    final steps = <TextRuleStep>[];
    for (final s in _steps) {
      final find = s.find.text;
      if (find.isEmpty) continue;
      steps.add(
        TextRuleStep(
          find: find,
          replace: s.replace.text,
          caseSensitive: s.caseSensitive,
        ),
      );
    }
    final id = widget.initial?.id ?? TextRuleStore.newId();
    return TextRule(
      id: id,
      name: name.isEmpty ? t.textRuleName : name,
      steps: steps,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _save() => Navigator.of(context).pop(_buildRule());

  /// 编辑中的实时预览：示例文本 → 套用当前步骤后的结果
  Widget _editorPreview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final result = TextRuleStore.apply(_sampleCtrl.text, [_buildRule()]);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _sampleCtrl,
            maxLines: null,
            minLines: 1,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t.textRulePreviewInput,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.textRulePreviewResult,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          SelectableText(result, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: widget.initial == null ? t.textRuleAdd : t.edit,
      content: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: t.textRuleName,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                _editorPreview(context),
                const SizedBox(height: 12),
                for (var i = 0; i < _steps.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.textRuleStepN(n: i + 1),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        tooltip: t.delete,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _steps.length <= 1
                            ? null
                            : () => _removeStep(i),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _steps[i].find,
                    decoration: InputDecoration(
                      labelText: t.textRuleFind,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _steps[i].replace,
                    decoration: InputDecoration(
                      labelText: t.textRuleReplace,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        t.textRuleCaseSensitive,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      Switch(
                        value: _steps[i].caseSensitive,
                        onChanged: (v) =>
                            setState(() => _steps[i].caseSensitive = v),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
                TextButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(t.textRuleStepAdd),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [Button.filled(onPressed: _save, child: Text(t.confirm))],
    );
  }
}
