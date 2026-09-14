// 角色管理（扩展管理设置 - 区块 2）：
// 双页签：提示词注入（PromptInjection）+ 世界书（WorldBook）。
// 人格（persona/tone）已并入助手档案，本页不再包含人格设定。

part of 'settings_page.dart';

class PromptManagementSettingsPage extends StatelessWidget {
  const PromptManagementSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Appbar(
            title: Text(t.promptManagement),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              tooltip: t.back,
              onPressed: () => context.canPop() ? context.pop() : App.pop(),
            ),
            bottom: CapsuleTabBar(
              labels: [
                t.promptInjection,
                t.worldBook,
                t.storySettingLibrary,
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _PromptInjectionPanel(),
                _WorldBookPanel(),
                _SettingLibraryPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 设定库管理：词条 / 称号 / 职业 / 据点
class _SettingLibraryPanel extends StatefulWidget {
  const _SettingLibraryPanel();

  @override
  State<_SettingLibraryPanel> createState() => _SettingLibraryPanelState();
}

class _SettingLibraryPanelState extends State<_SettingLibraryPanel> {
  @override
  void initState() {
    super.initState();
    SettingLibraryStore.instance.init();
  }

  String _typeLabel(String type) => switch (type) {
    SettingTypes.codex => t.storyCodex,
    SettingTypes.title => t.storyTitles,
    SettingTypes.job => t.storyJob,
    SettingTypes.facility => t.storyBase,
    _ => type,
  };

  IconData _typeIcon(String type) => switch (type) {
    SettingTypes.codex => Icons.menu_book_outlined,
    SettingTypes.title => Icons.military_tech_outlined,
    SettingTypes.job => Icons.badge_outlined,
    SettingTypes.facility => Icons.home_work_outlined,
    _ => Icons.category_outlined,
  };

  Future<void> _add() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.storyAddEntry,
        icon: Icons.add,
        initialSize: 0.42,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            for (final type in SettingTypes.all)
              ListTile(
                leading: Icon(_typeIcon(type)),
                title: Text(_typeLabel(type)),
                onTap: () => Navigator.of(ctx).pop(type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    await _edit(
      SettingEntry(
        id: 'set_${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        name: '',
      ),
    );
  }

  Future<void> _edit(SettingEntry entry) async {
    final result = await showSettingEntryEditor(entry);
    if (result == null) return;
    await SettingLibraryStore.instance.upsert(result);
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    try {
      final text = utf8.decode(await result.files.first.readAsBytes());
      final decoded = jsonDecode(text);
      if (decoded is! List) throw 'invalid';
      var count = 0;
      for (final e in decoded) {
        if (e is Map) {
          await SettingLibraryStore.instance.upsert(
            SettingEntry.fromJson(e.cast<String, dynamic>()),
          );
          count++;
        }
      }
      App.rootContext.showMessage(message: t.importedEntries(count: count));
    } catch (e) {
      Log.error('importSettingLibrary', e.toString());
      App.rootContext.showMessage(
        message: t.importFailed,
        level: LogLevel.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = SettingLibraryStore.instance;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.category_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.storySettingLibraryHint,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.file_open_outlined),
                tooltip: t.importEntries,
                onPressed: _import,
              ),
              IconButton(
                icon: const Icon(Icons.save_alt),
                tooltip: t.exportEntries,
                onPressed: () => _exportJson(
                  [for (final e in store.items) e.toJson()],
                  'setting_library.json',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: t.storyAddEntry,
                onPressed: _add,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final items = store.items;
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(t.storySettingLibraryEmpty, style: ts.s12),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  for (final type in SettingTypes.all)
                    if (store.byType(type).isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              _typeIcon(type),
                              size: 16,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _typeLabel(type),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final e in store.byType(type))
                        _SettingCard(
                          children: [
                            ListTile(
                              dense: true,
                              leading: Icon(_typeIcon(type), size: 20),
                              title: Text(
                                e.name.isEmpty ? e.id : e.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _entrySummary(e),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    iconSize: 18,
                                    tooltip: t.edit,
                                    icon: const Icon(Icons.edit_note, size: 18),
                                    onPressed: () => _edit(e),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    iconSize: 18,
                                    tooltip: t.delete,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: scheme.error,
                                    ),
                                    onPressed: () async {
                                      await SettingLibraryStore.instance.remove(
                                        e.id,
                                      );
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _entrySummary(SettingEntry e) => switch (e.type) {
    SettingTypes.codex =>
      (e.payload['mechanics'] ?? e.payload['display'] ?? '').toString(),
    SettingTypes.title => (e.payload['effects'] ?? '').toString(),
    SettingTypes.job =>
      (e.payload['levels'] is List)
          ? '${(e.payload['levels'] as List).length} ${t.storyJobLevel}'
          : (e.payload['description'] ?? '').toString(),
    SettingTypes.facility =>
      '${t.storyBaseMaxLevel}: ${e.payload['maxLevel'] ?? 1}',
    _ => '',
  };
}

/// 编辑设定库条目（按类型显示不同字段）
/// 用 AI 按用户描述生成设定 JSON（返回的键名由 [promptTemplate] 指定）
Future<Map<String, dynamic>?> aiGenerateEntry({
  required String title,
  required String systemPrompt,
  required String promptTemplate,
}) async {
  final descCtrl = TextEditingController();
  final desc = await showDialog<String>(
    context: App.rootContext,
    builder: (ctx) => ContentDialog(
      title: title,
      content: TextField(
        controller: descCtrl,
        autofocus: true,
        minLines: 2,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: t.aiGenerateHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(descCtrl.text.trim()),
          child: Text(t.aiGenerate),
        ),
      ],
    ),
  );
  descCtrl.dispose();
  if (desc == null || desc.isEmpty) return null;
  try {
    final stored = appdata.implicitData['aiHubProvider'];
    final provider = (stored is String && stored.isNotEmpty)
        ? stored
        : 'siliconFlow';
    final res = await AiConversationService().runTask(
      provider: provider,
      taskType: 'setting_gen',
      sessionTitle: title,
      systemPrompt: systemPrompt,
      prompt: promptTemplate.replaceAll('{input}', desc),
    );
    if (!res.success) return null;
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(res.dataOrNull ?? '');
    if (m == null) return null;
    final d = jsonDecode(m.group(0)!);
    return d is Map ? d.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
}

Future<SettingEntry?> showSettingEntryEditor(SettingEntry entry) async {
  final nameCtrl = TextEditingController(text: entry.name);
  var codexKind = entry.payload['kind']?.toString() ?? 'item';
  final displayCtrl = TextEditingController(
    text: entry.payload['display']?.toString() ?? '',
  );
  final mechanicsCtrl = TextEditingController(
    text: entry.payload['mechanics']?.toString() ?? '',
  );
  final effectsCtrl = TextEditingController(
    text: entry.payload['effects']?.toString() ?? '',
  );
  var stackable = entry.payload['stackable'] == true;
  final descCtrl = TextEditingController(
    text: entry.payload['description']?.toString() ?? '',
  );
  final maxLevelCtrl = TextEditingController(
    text: entry.payload['maxLevel']?.toString() ?? '1',
  );
  final levelsCtrl = TextEditingController(
    text: [
      for (final l in (entry.payload['levels'] as List? ?? const []))
        if (l is Map)
          '${l['level'] ?? ''}|${l['name'] ?? ''}|${l['bonus'] ?? ''}',
    ].join('\n'),
  );

  const codexKinds = ['item', 'trait', 'race', 'skill', 'talent', 'body'];
  String kindLabel(String k) => switch (k) {
    'item' => t.storyCodexItem,
    'trait' => t.storyCodexTrait,
    'race' => t.storyCodexRace,
    'skill' => t.skills,
    'talent' => t.storyCodexTalent,
    'body' => t.storyCodexBody,
    _ => k,
  };

  final ok = await showDialog<bool>(
    context: App.rootContext,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => ContentDialog(
        title: entry.name.isEmpty ? t.storyAddEntry : t.edit,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final keys = switch (entry.type) {
                      SettingTypes.codex =>
                        '{"name":"名称","kind":"item|trait|race|skill|talent|body",'
                            '"display":"玩家可见描述","mechanics":"机制/数值"}',
                      SettingTypes.title => '{"name":"称号名","effects":"效果（数值/机制）"}',
                      SettingTypes.job =>
                        '{"name":"职业名","description":"简介",'
                            '"levels":[{"level":1,"name":"阶段名","bonus":"加成"}]}',
                      SettingTypes.facility =>
                        '{"name":"设施名","description":"说明","maxLevel":3}',
                      _ => '{"name":"名称","description":"说明"}',
                    };
                    final data = await aiGenerateEntry(
                      title: t.aiGenerate,
                      systemPrompt: t.settingAiSystem,
                      promptTemplate: '$keys\n{input}',
                    );
                    if (data == null || !ctx.mounted) return;
                    setLocal(() {
                      final n = data['name']?.toString() ?? '';
                      if (n.isNotEmpty) nameCtrl.text = n;
                      final k = data['kind']?.toString() ?? '';
                      if (codexKinds.contains(k)) codexKind = k;
                      final d = data['display']?.toString() ?? '';
                      if (d.isNotEmpty) displayCtrl.text = d;
                      final me = data['mechanics']?.toString() ?? '';
                      if (me.isNotEmpty) mechanicsCtrl.text = me;
                      final ef = data['effects']?.toString() ?? '';
                      if (ef.isNotEmpty) effectsCtrl.text = ef;
                      final de = data['description']?.toString() ?? '';
                      if (de.isNotEmpty) descCtrl.text = de;
                      final ml = data['maxLevel'];
                      if (ml is num) maxLevelCtrl.text = '${ml.toInt()}';
                      final lv = data['levels'];
                      if (lv is List) {
                        levelsCtrl.text = [
                          for (final l in lv)
                            if (l is Map)
                              '${l['level'] ?? ''}|${l['name'] ?? ''}|${l['bonus'] ?? ''}',
                        ].join('\n');
                      }
                    });
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: Text(t.aiGenerate),
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: t.storyCharacterName,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (entry.type == SettingTypes.codex) ...[
                Row(
                  children: [
                    Text('${t.storyCodex}: '),
                    Select(
                      current: kindLabel(codexKind),
                      values: [for (final k in codexKinds) kindLabel(k)],
                      onTap: (i) => setLocal(() => codexKind = codexKinds[i]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: displayCtrl,
                  decoration: InputDecoration(
                    labelText: t.storyCodexDisplay,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mechanicsCtrl,
                  decoration: InputDecoration(
                    labelText: t.storyCodexMechanics,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ] else if (entry.type == SettingTypes.title) ...[
                TextField(
                  controller: effectsCtrl,
                  decoration: InputDecoration(
                    labelText: t.storyCodexMechanics,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(t.storyTitleStackable),
                    const Spacer(),
                    CustomSwitch(
                      value: stackable,
                      onChanged: (v) => setLocal(() => stackable = v),
                    ),
                  ],
                ),
              ] else if (entry.type == SettingTypes.job) ...[
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: t.storyCodexDisplay,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: levelsCtrl,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: '${t.storyJobLevel}｜${t.storyCharacterName}｜${t.storyJobBonus}',
                    alignLabelWithHint: true,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: t.storyCodexDisplay,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: maxLevelCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t.storyBaseMaxLevel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
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

  final name = nameCtrl.text.trim();
  final payload = <String, dynamic>{};
  switch (entry.type) {
    case SettingTypes.codex:
      payload.addAll({
        'kind': codexKind,
        'key': name,
        'name': name,
        'display': displayCtrl.text.trim(),
        'mechanics': mechanicsCtrl.text.trim(),
      });
    case SettingTypes.title:
      payload.addAll({
        'key': name,
        'name': name,
        'effects': effectsCtrl.text.trim(),
        'stackable': stackable,
      });
    case SettingTypes.job:
      payload.addAll({
        'name': name,
        'description': descCtrl.text.trim(),
        'levels': [
          for (final line in levelsCtrl.text.split('\n'))
            if (line.trim().isNotEmpty)
              () {
                final parts = line.split('|');
                return {
                  'level': int.tryParse(parts.isNotEmpty ? parts[0].trim() : '') ?? 0,
                  'name': parts.length > 1 ? parts[1].trim() : '',
                  'bonus': parts.length > 2 ? parts[2].trim() : '',
                };
              }(),
        ],
      });
    case SettingTypes.facility:
      payload.addAll({
        'key': name,
        'name': name,
        'description': descCtrl.text.trim(),
        'maxLevel': int.tryParse(maxLevelCtrl.text.trim()) ?? 1,
      });
  }
  nameCtrl.dispose();
  displayCtrl.dispose();
  mechanicsCtrl.dispose();
  effectsCtrl.dispose();
  descCtrl.dispose();
  maxLevelCtrl.dispose();
  levelsCtrl.dispose();
  if (ok != true) return null;
  return entry.copyWith(name: name, payload: payload);
}

String _injectionPositionLabel(PromptInjectionPosition position) =>
    switch (position) {
      PromptInjectionPosition.afterPersonality =>
        t.injectionPositionAfterPersonality,
      PromptInjectionPosition.afterSystemPrompt =>
        t.injectionPositionAfterSystemPrompt,
      PromptInjectionPosition.afterKnowledge =>
        t.injectionPositionAfterKnowledge,
      PromptInjectionPosition.afterMemory => t.injectionPositionAfterMemory,
      PromptInjectionPosition.beforeTools => t.injectionPositionBeforeTools,
    };

// ─────────────────────────────────────────────
// 世界书 / 提示词注入 导入导出
// ─────────────────────────────────────────────

Future<void> _exportJson(List<Map<String, dynamic>> items, String filename) async {
  await saveFile(data: utf8.encode(jsonEncode(items)), filename: filename);
}

/// 解析世界书：兼容本应用格式（List）与 SillyTavern 世界书（{entries:{...}}）
List<WorldBookEntry> _parseWorldBookEntries(dynamic decoded) {
  final out = <WorldBookEntry>[];
  final now = DateTime.now().millisecondsSinceEpoch;
  var seq = 0;

  List<String> triggersOf(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  void addFromMap(Map<String, dynamic> m) {
    final triggers = triggersOf(m['triggers'] ?? m['keys'] ?? m['key']);
    final secondary = triggersOf(m['secondaryKeys'] ?? m['secondary_keys']);
    final content = (m['content'] ?? '').toString();
    final constant = m['constant'] == true;
    // 常驻条目可以没有触发词
    if ((triggers.isEmpty && !constant) || content.trim().isEmpty) return;
    // ST position：0=before_char，其余视为 after
    final position = switch (m['position']) {
      final num p => p.toInt() == 0 ? 'before' : 'after',
      final Object s when s.toString().contains('before') => 'before',
      _ => 'after',
    };
    out.add(
      WorldBookEntry(
        id: m['id']?.toString() ?? 'wb_${now}_${seq++}',
        name: (m['name'] ?? m['comment'] ?? 'Entry').toString(),
        group: (m['group'] as String?) ?? '',
        triggers: triggers,
        secondaryKeys: secondary,
        content: content,
        priority:
            (m['priority'] as num?)?.toInt() ??
            (m['insertion_order'] as num?)?.toInt() ??
            (m['order'] as num?)?.toInt() ??
            0,
        enabled:
            (m['enabled'] as bool?) ?? (m['disable'] == true ? false : true),
        constant: constant,
        recursive: m['recursive'] == true,
        position: position,
        depth: (m['depth'] as num?)?.toInt() ?? 4,
        sticky: (m['sticky'] as num?)?.toInt() ?? 0,
        cooldown: (m['cooldown'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  if (decoded is List) {
    for (final e in decoded) {
      if (e is Map) addFromMap(e.cast<String, dynamic>());
    }
  } else if (decoded is Map) {
    final entries = decoded['entries'];
    if (entries is Map) {
      for (final v in entries.values) {
        if (v is Map) addFromMap(v.cast<String, dynamic>());
      }
    } else if (entries is List) {
      for (final v in entries) {
        if (v is Map) addFromMap(v.cast<String, dynamic>());
      }
    } else {
      addFromMap(decoded.cast<String, dynamic>());
    }
  }
  return out;
}

Future<void> _importWorldBook() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (result == null || result.files.isEmpty) return;
  try {
    final text = utf8.decode(await result.files.first.readAsBytes());
    final entries = _parseWorldBookEntries(jsonDecode(text));
    if (entries.isEmpty) throw 'empty';
    for (final e in entries) {
      await WorldBookStore.instance.upsert(e);
    }
    App.rootContext.showMessage(
      message: t.importedEntries(count: entries.length),
    );
  } catch (e) {
    Log.error('importWorldBook', e.toString());
    App.rootContext.showMessage(message: t.importFailed, level: LogLevel.error);
  }
}

Future<void> _importPromptInjections() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (result == null || result.files.isEmpty) return;
  try {
    final text = utf8.decode(await result.files.first.readAsBytes());
    final decoded = jsonDecode(text);
    if (decoded is! List) throw 'invalid';
    var count = 0;
    for (final e in decoded) {
      if (e is Map) {
        await PromptInjectionStore.instance.upsert(
          PromptInjection.fromJson(e.cast<String, dynamic>()),
        );
        count++;
      }
    }
    App.rootContext.showMessage(message: t.importedEntries(count: count));
  } catch (e) {
    Log.error('importPromptInjections', e.toString());
    App.rootContext.showMessage(message: t.importFailed, level: LogLevel.error);
  }
}

// ─────────────────────────────────────────────
// 提示词注入 页签
// ─────────────────────────────────────────────

class _PromptInjectionPanel extends StatefulWidget {
  const _PromptInjectionPanel();

  @override
  State<_PromptInjectionPanel> createState() => _PromptInjectionPanelState();
}

class _PromptInjectionPanelState extends State<_PromptInjectionPanel> {
  @override
  void initState() {
    super.initState();
    PromptInjectionStore.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    final store = PromptInjectionStore.instance;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.promptInjectionHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.file_open_outlined),
                tooltip: t.importEntries,
                onPressed: _importPromptInjections,
              ),
              IconButton(
                icon: const Icon(Icons.save_alt),
                tooltip: t.exportEntries,
                onPressed: () => _exportJson(
                  [for (final i in store.items) i.toJson()],
                  'prompt_injections.json',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: t.newPromptInjection,
                onPressed: () => showPopUpWidget(
                  App.rootContext,
                  const _PromptInjectionEditor(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final items = [...store.items]
                ..sort((a, b) {
                  final byPos = a.position.index.compareTo(b.position.index);
                  return byPos != 0
                      ? byPos
                      : a.sortOrder.compareTo(b.sortOrder);
                });
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(t.noInjectionsYet, style: ts.s12),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SettingCard(
                      padding: EdgeInsets.zero,
                      children: [
                        _PromptInjectionTile(
                          item: item,
                          onToggle: (v) =>
                              store.upsert(item.copyWith(enabled: v)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PromptInjectionTile extends StatelessWidget {
  const _PromptInjectionTile({required this.item, required this.onToggle});

  final PromptInjection item;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(
        item.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.content.replaceAll('\n', ' '),
            style: TextStyle(color: scheme.outline, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${t.injectionPosition}: ${_injectionPositionLabel(item.position)}'
            ' · ${t.injectionSortOrder}: ${item.sortOrder}',
            style: TextStyle(color: scheme.primary, fontSize: 11),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomSwitch(value: item.enabled, onChanged: onToggle),
          const Icon(Icons.arrow_right, size: 20),
        ],
      ),
      onTap: () =>
          showPopUpWidget(App.rootContext, _PromptInjectionEditor(item: item)),
    );
  }
}

class _PromptInjectionEditor extends StatefulWidget {
  const _PromptInjectionEditor({this.item});

  final PromptInjection? item;

  @override
  State<_PromptInjectionEditor> createState() => _PromptInjectionEditorState();
}

class _PromptInjectionEditorState extends State<_PromptInjectionEditor> {
  final _formKey = GlobalKey<FormState>();

  late final _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
  late final _contentCtrl = TextEditingController(
    text: widget.item?.content ?? '',
  );
  late final _sortCtrl = TextEditingController(
    text: (widget.item?.sortOrder ?? 0).toString(),
  );
  late PromptInjectionPosition _position =
      widget.item?.position ?? PromptInjectionPosition.afterPersonality;
  late bool _enabled = widget.item?.enabled ?? true;

  bool get _isNew => widget.item == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contentCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final item = PromptInjection(
      id: widget.item?.id ?? 'inject_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      enabled: _enabled,
      position: _position,
      sortOrder: int.tryParse(_sortCtrl.text.trim()) ?? 0,
    );
    await PromptInjectionStore.instance.upsert(item);
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop();
    }
  }

  /// 占位符提示（点击插入到内容输入框光标处，发送时由 replaceTemplateVars 替换）
  Widget _templateVarHint() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            t.templateVarHint,
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
          for (final v in templateVarEntries)
            InkWell(
              onTap: () {
                final selection = _contentCtrl.selection;
                final start = selection.isValid
                    ? selection.start
                    : _contentCtrl.text.length;
                final end = selection.isValid
                    ? selection.end
                    : _contentCtrl.text.length;
                _contentCtrl.text = _contentCtrl.text
                    .replaceRange(start, end, v.token)
                    .replaceAll('${v.token}${v.token}', v.token);
                _contentCtrl.selection = TextSelection.collapsed(
                  offset: start + v.token.length,
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${v.token} ${v.label}',
                  style: TextStyle(fontSize: 11, color: scheme.primary),
                ),
              ),
            ),
          InkWell(
            onTap: () {
              const token = '@a';
              final selection = _contentCtrl.selection;
              final start = selection.isValid
                  ? selection.start
                  : _contentCtrl.text.length;
              final end = selection.isValid
                  ? selection.end
                  : _contentCtrl.text.length;
              _contentCtrl.text = _contentCtrl.text
                  .replaceRange(start, end, token)
                  .replaceAll('$token$token', token);
              _contentCtrl.selection = TextSelection.collapsed(
                offset: start + token.length,
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '@a ${t.targetLanguage}',
                style: TextStyle(fontSize: 11, color: scheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: _isNew ? t.newPromptInjection : t.editPromptInjection,
      body: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _SettingCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: t.injectionName,
                            prefixIcon: const Icon(Icons.title, size: 20),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? t.required
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: TextFormField(
                          controller: _contentCtrl,
                          maxLines: 10,
                          decoration: InputDecoration(
                            labelText: t.injectionContent,
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? t.required
                              : null,
                        ),
                      ),
                      _templateVarHint(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButtonFormField<PromptInjectionPosition>(
                          initialValue: _position,
                          decoration: InputDecoration(
                            labelText: t.injectionPosition,
                            prefixIcon: const Icon(
                              Icons.schedule_send_outlined,
                              size: 20,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final p in PromptInjectionPosition.values)
                              DropdownMenuItem(
                                value: p,
                                child: Text(_injectionPositionLabel(p)),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _position = v);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _sortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t.injectionSortOrder,
                            prefixIcon: const Icon(
                              Icons.sort_by_alpha,
                              size: 20,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return int.tryParse(v.trim()) == null
                                ? t.invalidNumber
                                : null;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildToggleRow(
                          t.enabled,
                          Icons.toggle_on_outlined,
                          _enabled,
                          (v) => setState(() => _enabled = v),
                        ),
                      ),
                      if (!_isNew)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () async {
                                await PromptInjectionStore.instance.remove(
                                  widget.item!.id,
                                );
                                if (mounted) App.rootContext.pop();
                              },
                              icon: Icon(
                                Icons.delete_outline,
                                color: scheme.error,
                              ),
                              label: Text(
                                t.delete,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: _save,
                  label: Text(t.apply),
                  icon: const Icon(Icons.check),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 世界书 页签
// ─────────────────────────────────────────────

class _WorldBookPanel extends StatefulWidget {
  const _WorldBookPanel();

  @override
  State<_WorldBookPanel> createState() => _WorldBookPanelState();
}

class _WorldBookPanelState extends State<_WorldBookPanel> {
  @override
  void initState() {
    super.initState();
    WorldBookStore.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    final store = WorldBookStore.instance;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.worldBookTriggersHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.gesture),
                tooltip: t.worldBookHitTest,
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => const _WorldBookHitTestDialog(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.file_open_outlined),
                tooltip: t.importEntries,
                onPressed: _importWorldBook,
              ),
              IconButton(
                icon: const Icon(Icons.save_alt),
                tooltip: t.exportEntries,
                onPressed: () => _exportJson(
                  [for (final e in store.entries) e.toJson()],
                  'world_book.json',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: t.newWorldBookEntry,
                onPressed: () =>
                    showPopUpWidget(App.rootContext, const _WorldBookEditor()),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final entries = [...store.entries]
                ..sort((a, b) {
                  final byGroup = a.group.compareTo(b.group);
                  if (byGroup != 0) return byGroup;
                  return b.priority.compareTo(a.priority);
                });
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(t.noWorldBookEntriesYet, style: ts.s12),
                );
              }
              final children = <Widget>[];
              String? currentGroup;
              for (final entry in entries) {
                if (entry.group != currentGroup) {
                  currentGroup = entry.group;
                  children.add(
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      child: Text(
                        entry.group.isEmpty ? t.worldBook : entry.group,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }
                children.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SettingCard(
                      padding: EdgeInsets.zero,
                      children: [
                        _WorldBookTile(
                          entry: entry,
                          onToggle: (v) =>
                              store.upsert(entry.copyWith(enabled: v)),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: children,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorldBookTile extends StatelessWidget {
  const _WorldBookTile({required this.entry, required this.onToggle});

  final WorldBookEntry entry;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              entry.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Text(
            '${t.worldBookPriority}: ${entry.priority}',
            style: TextStyle(color: scheme.primary, fontSize: 11),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.triggers.where((t) => t.trim().isNotEmpty).join(' / '),
            style: TextStyle(color: scheme.outline, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            entry.content.replaceAll('\n', ' '),
            style: TextStyle(color: scheme.outline, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomSwitch(value: entry.enabled, onChanged: onToggle),
          const Icon(Icons.arrow_right, size: 20),
        ],
      ),
      onTap: () =>
          showPopUpWidget(App.rootContext, _WorldBookEditor(entry: entry)),
    );
  }
}

class _WorldBookEditor extends StatefulWidget {
  const _WorldBookEditor({this.entry});

  final WorldBookEntry? entry;

  @override
  State<_WorldBookEditor> createState() => _WorldBookEditorState();
}

class _WorldBookEditorState extends State<_WorldBookEditor> {
  final _formKey = GlobalKey<FormState>();

  late final _nameCtrl = TextEditingController(text: widget.entry?.name ?? '');
  late final _groupCtrl = TextEditingController(
    text: widget.entry?.group ?? '',
  );
  late final _triggerCtrl = TextEditingController(
    text: (widget.entry?.triggers ?? const []).join('\n'),
  );
  late final _secondaryCtrl = TextEditingController(
    text: (widget.entry?.secondaryKeys ?? const []).join('\n'),
  );
  late final _contentCtrl = TextEditingController(
    text: widget.entry?.content ?? '',
  );
  late final _priorityCtrl = TextEditingController(
    text: (widget.entry?.priority ?? 0).toString(),
  );
  late final _depthCtrl = TextEditingController(
    text: (widget.entry?.depth ?? 4).toString(),
  );
  late final _stickyCtrl = TextEditingController(
    text: (widget.entry?.sticky ?? 0).toString(),
  );
  late final _cooldownCtrl = TextEditingController(
    text: (widget.entry?.cooldown ?? 0).toString(),
  );
  late bool _enabled = widget.entry?.enabled ?? true;
  late bool _constant = widget.entry?.constant ?? false;
  late bool _recursive = widget.entry?.recursive ?? false;
  late String _position = widget.entry?.position ?? 'after';

  bool get _isNew => widget.entry == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _groupCtrl.dispose();
    _triggerCtrl.dispose();
    _secondaryCtrl.dispose();
    _contentCtrl.dispose();
    _priorityCtrl.dispose();
    _depthCtrl.dispose();
    _stickyCtrl.dispose();
    _cooldownCtrl.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController ctrl) => ctrl.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// 用 AI 按描述补全名称 / 触发词 / 内容
  Future<void> _aiFill() async {
    final data = await aiGenerateEntry(
      title: t.aiGenerate,
      systemPrompt: t.worldBookAiSystem,
      promptTemplate: t.worldBookAiPrompt,
    );
    if (data == null || !mounted) return;
    setState(() {
      final n = data['name']?.toString() ?? '';
      if (n.isNotEmpty) _nameCtrl.text = n;
      final triggers = data['triggers'];
      if (triggers is List && triggers.isNotEmpty) {
        _triggerCtrl.text = triggers.map((e) => e.toString()).join('\n');
      }
      final content = data['content']?.toString() ?? '';
      if (content.isNotEmpty) _contentCtrl.text = content;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final entry = WorldBookEntry(
      id: widget.entry?.id ?? 'wb_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      group: _groupCtrl.text.trim(),
      triggers: _lines(_triggerCtrl),
      secondaryKeys: _lines(_secondaryCtrl),
      content: _contentCtrl.text.trim(),
      priority: int.tryParse(_priorityCtrl.text.trim()) ?? 0,
      enabled: _enabled,
      constant: _constant,
      recursive: _recursive,
      position: _position,
      depth: int.tryParse(_depthCtrl.text.trim()) ?? 4,
      sticky: int.tryParse(_stickyCtrl.text.trim()) ?? 0,
      cooldown: int.tryParse(_cooldownCtrl.text.trim()) ?? 0,
    );
    await WorldBookStore.instance.upsert(entry);
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: _isNew ? t.newWorldBookEntry : entryName,
      tailing: [
        IconButton(
          icon: const Icon(Icons.auto_awesome),
          tooltip: t.aiGenerate,
          onPressed: _aiFill,
        ),
      ],
      body: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _SettingCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: t.worldBookName,
                            prefixIcon: const Icon(Icons.title, size: 20),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? t.required
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _triggerCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: t.worldBookTriggers,
                            helperText: t.worldBookTriggersHint,
                            prefixIcon: const Icon(Icons.gesture, size: 20),
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (_constant) return null;
                            final triggers = _lines(_triggerCtrl);
                            return triggers.isEmpty ? t.required : null;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _contentCtrl,
                          maxLines: 8,
                          decoration: InputDecoration(
                            labelText: t.worldBookContent,
                            prefixIcon: const Icon(
                              Icons.notes_outlined,
                              size: 20,
                            ),
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? t.required
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _priorityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t.worldBookPriority,
                            helperText: t.worldBookPriorityHint,
                            prefixIcon: const Icon(
                              Icons.format_list_numbered,
                              size: 20,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return int.tryParse(v.trim()) == null
                                ? t.invalidNumber
                                : null;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _groupCtrl,
                          decoration: InputDecoration(
                            labelText: t.worldBookGroup,
                            prefixIcon: const Icon(
                              Icons.folder_outlined,
                              size: 20,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _secondaryCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: t.worldBookSecondaryKeys,
                            prefixIcon: const Icon(
                              Icons.filter_alt_outlined,
                              size: 20,
                            ),
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Text('${t.worldBookPosition}: '),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _position,
                              items: [
                                DropdownMenuItem(
                                  value: 'before',
                                  child: Text(t.worldBookPositionBefore),
                                ),
                                DropdownMenuItem(
                                  value: 'after',
                                  child: Text(t.worldBookPositionAfter),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _position = v ?? 'after'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _depthCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: t.worldBookDepth,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _stickyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: t.worldBookSticky,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _cooldownCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: t.worldBookCooldown,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildToggleRow(
                          t.worldBookConstant,
                          Icons.push_pin_outlined,
                          _constant,
                          (v) => setState(() => _constant = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildToggleRow(
                          t.worldBookRecursive,
                          Icons.account_tree_outlined,
                          _recursive,
                          (v) => setState(() => _recursive = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildToggleRow(
                          t.enabled,
                          Icons.toggle_on_outlined,
                          _enabled,
                          (v) => setState(() => _enabled = v),
                        ),
                      ),
                      if (!_isNew)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () async {
                                await WorldBookStore.instance.remove(
                                  widget.entry!.id,
                                );
                                if (mounted) App.rootContext.pop();
                              },
                              icon: Icon(
                                Icons.delete_outline,
                                color: scheme.error,
                              ),
                              label: Text(
                                t.delete,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: _save,
                  label: Text(t.apply),
                  icon: const Icon(Icons.check),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get entryName => widget.entry?.name ?? t.newWorldBookEntry;
}

// ─────────────────────────────────────────────
// 世界书 命中测试弹窗
// ─────────────────────────────────────────────

class _WorldBookHitTestDialog extends StatefulWidget {
  const _WorldBookHitTestDialog();

  @override
  State<_WorldBookHitTestDialog> createState() =>
      _WorldBookHitTestDialogState();
}

class _WorldBookHitTestDialogState extends State<_WorldBookHitTestDialog> {
  final _ctrl = TextEditingController();
  List<WorldBookEntry>? _hits;
  bool _testing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _testing = true);
    final hits = await WorldBookStore.instance.hits(text);
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _testing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ContentDialog(
      title: t.worldBookHitTest,
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.worldBookHitTestHint,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: t.worldBookHitTestPlaceholder,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _run(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _testing ? null : _run,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: PolygonRefreshIndicator(),
                        )
                      : const Icon(Icons.search, size: 16),
                  label: Text(t.worldBookHitTest),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: _hits == null
                  ? const SizedBox.shrink()
                  : _hits!.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t.worldBookNoHits),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        Text(
                          '${t.worldBookHitsResult} (${_hits!.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        for (final e in _hits!) _HitEntryCard(entry: e),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.ok),
        ),
      ],
    );
  }
}

class _HitEntryCard extends StatelessWidget {
  const _HitEntryCard({required this.entry});

  final WorldBookEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _SettingCard(
        padding: EdgeInsets.zero,
        children: [
          ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${t.worldBookPriority}: ${entry.priority}',
                  style: TextStyle(color: scheme.primary, fontSize: 11),
                ),
              ],
            ),
            subtitle: Text(
              '${t.worldBookTriggers}: ${entry.triggers.join(' / ')}',
              style: TextStyle(color: scheme.outline, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
