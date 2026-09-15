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
  bool _dragOver = false;

  /// 展开的设定书（默认全部折叠）
  final Set<String> _expandedBooks = {};

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

  Future<void> _add({String? bookId}) async {
    final store = SettingLibraryStore.instance;
    if (bookId == null) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Sheet(
          title: t.storyAddEntry,
          icon: Icons.add,
          initialSize: 0.4,
          builder: (ctx, sc) => ListView(
            controller: sc,
            children: [
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: Text(t.newSettingBook),
                onTap: () => Navigator.of(ctx).pop('__new__'),
              ),
              for (final b in store.books)
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(
                    b.name.isEmpty ? t.storySettingLibrary : b.name,
                  ),
                  trailing: Text('${b.entries.length}'),
                  onTap: () => Navigator.of(ctx).pop(b.id),
                ),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;
      bookId = choice == '__new__'
          ? (await store.createBook()).id
          : choice;
    }
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
        bookId: bookId,
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
    final file = result.files.first;
    final bookName = file.name.replaceAll(
      RegExp(r'\.json$', caseSensitive: false),
      '',
    );
    try {
      await _importBytes(await file.readAsBytes(), name: bookName);
    } catch (e) {
      Log.error('importSettingLibrary', e.toString());
      App.rootContext.showMessage(
        message: t.importFailed,
        level: LogLevel.error,
      );
    }
  }

  /// 从 JSON（List）字节导入设定（拖拽 / 选择文件共用）：每次生成一本新书
  Future<void> _importBytes(List<int> bytes, {String name = ''}) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) throw 'invalid';
    final entries = <SettingEntry>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final raw = SettingEntry.fromJson(e.cast<String, dynamic>());
      entries.add(
        SettingEntry(
          id: _stableImportId(
            'set_',
            '${raw.type}\u0000${raw.name}\u0000${jsonEncode(raw.payload)}',
          ),
          type: raw.type,
          name: raw.name,
          group: raw.group,
          payload: raw.payload,
        ),
      );
    }
    if (entries.isEmpty) throw 'empty';
    final book = await SettingLibraryStore.instance.createBook(name: name);
    await SettingLibraryStore.instance.upsertBook(
      SettingBook(id: book.id, name: book.name, entries: entries),
    );
    App.rootContext.showMessage(
      message: t.importedEntries(count: entries.length),
    );
  }

  /// 拖入 JSON 文件导入
  Future<void> _onDrop(DropDoneDetails detail) async {
    for (final f in detail.files) {
      if (!f.name.toLowerCase().endsWith('.json')) continue;
      try {
        await _importBytes(
          await f.readAsBytes(),
          name: f.name.replaceAll(
            RegExp(r'\.json$', caseSensitive: false),
            '',
          ),
        );
      } catch (e) {
        Log.error('dropSettingLibrary', e.toString());
      }
    }
    if (mounted) setState(() => _dragOver = false);
  }

  /// 新建一本设定书（组）
  Future<void> _newBook() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.newSettingBook,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t.storyCharacterName,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    final book = await SettingLibraryStore.instance.createBook(name: name);
    if (!mounted) return;
    setState(() => _expandedBooks.add(book.id));
  }

  /// 重命名设定书
  Future<void> _renameBook(SettingBook book) async {
    final ctrl = TextEditingController(text: book.name);
    final name = await showDialog<String>(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.rename,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: t.storyCharacterName,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    await SettingLibraryStore.instance.upsertBook(
      SettingBook(id: book.id, name: name, entries: book.entries),
    );
    if (mounted) setState(() {});
  }

  /// 把条目移动到另一本设定书
  Future<void> _moveEntry(SettingEntry entry) async {
    final store = SettingLibraryStore.instance;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.worldBookMove,
        icon: Icons.drive_file_move_outline,
        initialSize: 0.4,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            for (final b in store.books)
              if (b.id != entry.bookId)
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(b.name.isEmpty ? t.storySettingLibrary : b.name),
                  trailing: Text('${b.entries.length}'),
                  onTap: () => Navigator.of(ctx).pop(b.id),
                ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await store.upsert(entry, bookId: choice);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => DropTarget(
    onDragDone: _onDrop,
    onDragEntered: (_) {
      if (mounted) setState(() => _dragOver = true);
    },
    onDragExited: (_) {
      if (mounted) setState(() => _dragOver = false);
    },
    child: Container(
      decoration: _dragOver
          ? BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : null,
      child: _buildBody(context),
    ),
  );

  Widget _buildBody(BuildContext context) {
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
                tooltip: t.newSettingBook,
                onPressed: _newBook,
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
                  for (final book in store.books) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              _expandedBooks.contains(book.id)
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 20,
                            ),
                            onPressed: () => setState(() {
                              if (_expandedBooks.contains(book.id)) {
                                _expandedBooks.remove(book.id);
                              } else {
                                _expandedBooks.add(book.id);
                              }
                            }),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                if (_expandedBooks.contains(book.id)) {
                                  _expandedBooks.remove(book.id);
                                } else {
                                  _expandedBooks.add(book.id);
                                }
                              }),
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                book.name.isEmpty
                                    ? t.storySettingLibrary
                                    : book.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '${book.entries.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: t.storyAddEntry,
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => _add(bookId: book.id),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '',
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (v) {
                              if (v == 'rename') _renameBook(book);
                              if (v == 'delete') {
                                SettingLibraryStore.instance
                                    .removeBook(book.id)
                                    .then((_) {
                                      if (mounted) setState(() {});
                                    });
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(t.rename),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(t.delete),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_expandedBooks.contains(book.id))
                      for (final e in book.entries)
                      _SettingCard(
                        children: [
                          ListTile(
                            dense: true,
                            leading: Icon(_typeIcon(e.type), size: 20),
                            title: Text(
                              e.name.isEmpty ? e.id : e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (e.group.trim().isNotEmpty) e.group.trim(),
                                _entrySummary(e),
                              ].join(' · '),
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
                                  tooltip: t.worldBookMove,
                                  icon: const Icon(
                                    Icons.drive_file_move_outline,
                                    size: 18,
                                  ),
                                  onPressed: () => _moveEntry(e),
                                ),
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
/// 用 AI 按用户描述生成设定 JSON（返回的键名由 [promptTemplate] 指定）。
/// 支持多轮迭代：生成后可继续输入修改意见，AI 在上一版基础上改进，直到点「完成」。
Future<Map<String, dynamic>?> aiGenerateEntry({
  required String title,
  required String systemPrompt,
  required String promptTemplate,
  Map<String, dynamic>? previous,
}) async {
  const done = '__ai_done__';
  final descCtrl = TextEditingController();
  final refineCtrl = TextEditingController();
  // 传入已有条目 → 直接在它基础上迭代优化
  Map<String, dynamic>? current = previous;
  // 单独指定生成用的厂商（模型取该厂商已保存的模型）
  final providers = OpenAiProviderRegistry.allProviders;
  final storedProvider = appdata.implicitData['settingGenProvider'];
  var genProvider = (storedProvider is String &&
          providers.containsKey(storedProvider))
      ? storedProvider
      : providers.keys.firstWhere((_) => true, orElse: () => 'siliconFlow');
  // 生成专用的模型（为空则用该厂商已保存的模型）
  final storedModel = appdata.implicitData['settingGenModel'];
  var genModel = storedModel is String ? storedModel : '';
  try {
    while (true) {
      final isFirst = current == null;
      final input = await showDialog<String>(
        context: App.rootContext,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => ContentDialog(
          title: isFirst ? title : '$title · ${t.aiRefine}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 生成用的厂商 / 模型（复用 AI 工坊的模型选择组件）
              StreamBuilder<AiApiKey?>(
                stream: AiDatabase.instance.aiApiKeyDao.watchByProvider(
                  genProvider,
                ),
                builder: (_, snap) {
                  final model = genModel.isNotEmpty
                      ? genModel
                      : (snap.data?.model ?? '');
                  final label =
                      '${providers[genProvider]?.name ?? genProvider} · '
                      '${model.isEmpty ? t.set : model}';
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => showModalBottomSheet<void>(
                      context: App.rootContext,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ProviderModelSheet(
                        provider: genProvider,
                        onProviderChanged: (p) {
                          setLocal(() => genProvider = p);
                          appdata.implicitData['settingGenProvider'] = p;
                          appdata.writeImplicitData();
                        },
                        currentModel: genModel.isEmpty ? null : genModel,
                        // 生成专用模型：不写回该厂商的聊天模型
                        onModelSelected: (m) {
                          setLocal(() => genModel = m);
                          appdata.implicitData['settingGenModel'] = m;
                          appdata.writeImplicitData();
                        },
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.model_training, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(label)),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              if (!isFirst) ...[
                Text(
                  jsonEncode(current),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: isFirst ? descCtrl : refineCtrl,
                autofocus: true,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: isFirst ? t.aiGenerateHint : t.aiRefineHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            if (!isFirst)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(done),
                child: Text(t.confirm),
              ),
            FilledButton(
              onPressed: () => Navigator.of(
                ctx,
              ).pop((isFirst ? descCtrl : refineCtrl).text.trim()),
              child: Text(isFirst ? t.aiGenerate : t.aiRefine),
            ),
          ],
        ),
        ),
      );
      if (input == null || input == done) return current;
      if (input.isEmpty) continue;
      final prompt = isFirst
          ? promptTemplate.replaceAll('{input}', input)
          : '${promptTemplate.replaceAll('{input}', input)}\n\n'
                '${t.aiPreviousResult}：${jsonEncode(current)}\n'
                '${t.aiRefineFeedback}：$input';
      // 生成期间显示 loading：否则点了没反应，过一会才突然弹出来
      final loading = showLoadingDialog(App.rootContext);
      final res = await AiConversationService()
          .runTask(
            provider: genProvider,
            taskType: 'setting_gen',
            sessionTitle: title,
            systemPrompt: systemPrompt,
            prompt: prompt,
            modelOverride: genModel.isEmpty ? null : genModel,
          )
          .whenComplete(() => loading.close());
      if (!res.success) continue;
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(res.dataOrNull ?? '');
      if (m == null) continue;
      try {
        final d = jsonDecode(m.group(0)!);
        if (d is Map) current = d.cast<String, dynamic>();
      } catch (_) {}
    }
  } finally {
    descCtrl.dispose();
    refineCtrl.dispose();
  }
}

Future<SettingEntry?> showSettingEntryEditor(SettingEntry entry) async {
  final nameCtrl = TextEditingController(text: entry.name);
  final groupCtrl = TextEditingController(text: entry.group);
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

  const codexKinds = kStoryCodexKinds;
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
                      // 已有内容 → 在现有基础上优化
                      previous: entry.payload.isEmpty ? null : entry.payload,
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
              TextField(
                controller: groupCtrl,
                decoration: InputDecoration(
                  labelText: t.worldBookGroup,
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
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: t.storyCodexDisplay,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mechanicsCtrl,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: t.storyCodexMechanics,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ] else if (entry.type == SettingTypes.title) ...[
                TextField(
                  controller: effectsCtrl,
                  minLines: 2,
                  maxLines: 6,
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
                  minLines: 2,
                  maxLines: 6,
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
                  minLines: 2,
                  maxLines: 6,
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
  groupCtrl.dispose();
  displayCtrl.dispose();
  mechanicsCtrl.dispose();
  effectsCtrl.dispose();
  descCtrl.dispose();
  maxLevelCtrl.dispose();
  levelsCtrl.dispose();
  if (ok != true) return null;
  return entry.copyWith(
    name: name,
    group: groupCtrl.text.trim(),
    payload: payload,
  );
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

/// 导入时生成稳定 id（基于内容哈希）：避免沿用源文件里的 1/2/3 数字 id
/// 导致不同文件互相覆盖；同一份文件重复导入会落到同一 id（自动去重）。
String _stableImportId(String prefix, String seed) =>
    '$prefix${sha1.convert(utf8.encode(seed)).toString().substring(0, 16)}';

/// 解析世界书：兼容本应用格式（List）与 SillyTavern 世界书（{entries:{...}}）
List<WorldBookEntry> _parseWorldBookEntries(dynamic decoded) {
  final out = <WorldBookEntry>[];

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
    // ST position：0=角色定义前，1=角色定义后，2/3=作者注释（项目无此概念，
    // 就近归到角色定义后），4=按深度插入；字符串值按关键字判断
    final position = switch (m['position']) {
      final num p => switch (p.toInt()) {
        0 => 'before_char',
        4 => 'at_depth',
        _ => 'after_char',
      },
      final Object s when s.toString().toLowerCase().contains('depth') =>
        'at_depth',
      final Object s when s.toString().toLowerCase().contains('before') =>
        'before_char',
      final Object s when s.toString().toLowerCase().contains('after') =>
        'after_char',
      _ => 'after_char',
    };
    // ST role：0=system，1=user，2=assistant
    final role = switch (m['role']) {
      final num r => switch (r.toInt()) {
        1 => 'user',
        2 => 'assistant',
        _ => 'system',
      },
      final Object s when const {
        'system',
        'user',
        'assistant',
      }.contains(s.toString().toLowerCase()) =>
        s.toString().toLowerCase(),
      _ => 'system',
    };
    out.add(
      WorldBookEntry(
        id: _stableImportId(
          'wb_',
          '${m['name'] ?? m['comment'] ?? 'Entry'}\u0000$content\u0000'
          '${triggers.join(',')}\u0000${m['group'] ?? ''}',
        ),
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
        role: role,
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
  final file = result.files.first;
  final bookName = file.name.replaceAll(
    RegExp(r'\.json$', caseSensitive: false),
    '',
  );
  try {
    await importWorldBookBytes(await file.readAsBytes(), name: bookName);
  } catch (e) {
    Log.error('importWorldBook', e.toString());
    App.rootContext.showMessage(message: t.importFailed, level: LogLevel.error);
  }
}

/// 从 JSON 字节导入世界书（拖拽 / 选择文件共用）：每次生成一本新书（内含全部条目）
Future<void> importWorldBookBytes(List<int> bytes, {String name = ''}) async {
  final entries = _parseWorldBookEntries(jsonDecode(utf8.decode(bytes)));
  if (entries.isEmpty) throw 'empty';
  final book = await WorldBookStore.instance.createBook(name: name);
  await WorldBookStore.instance.upsertBook(
    WorldBookBook(id: book.id, name: book.name, entries: entries),
  );
  App.rootContext.showMessage(
    message: t.importedEntries(count: entries.length),
  );
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
                  // 底部留白：避免右下角「应用」按钮遮住最后几个字段
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  child: _SettingCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: t.injectionName,
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
  bool _dragOver = false;

  /// 展开的世界书（默认全部折叠）
  final Set<String> _expandedBooks = {};

  @override
  void initState() {
    super.initState();
    WorldBookStore.instance.init();
  }

  /// 拖入 JSON 文件导入世界书
  Future<void> _onDrop(DropDoneDetails detail) async {
    for (final f in detail.files) {
      if (!f.name.toLowerCase().endsWith('.json')) continue;
      try {
        await importWorldBookBytes(
          await f.readAsBytes(),
          name: f.name.replaceAll(
            RegExp(r'\.json$', caseSensitive: false),
            '',
          ),
        );
      } catch (e) {
        Log.error('dropWorldBook', e.toString());
      }
    }
    if (mounted) setState(() => _dragOver = false);
  }

  /// 选目标语言（默认中文，可自定义）
  Future<String?> _pickLang() async {
    final ctrl = TextEditingController(text: '中文');
    final result = await showDialog<String>(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.loreTriggerLang,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final l in ['中文', 'English', '日本語', '한국어'])
                  ActionChip(
                    label: Text(l),
                    onPressed: () => ctrl.text = l,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: t.loreTriggerLangHint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return (result == null || result.isEmpty) ? null : result;
  }

  /// 为整本书的条目批量生成目标语言的触发词（AI，分批）
  Future<void> _genTriggers(WorldBookBook book) async {
    if (book.entries.isEmpty) return;
    final lang = await _pickLang();
    if (lang == null || !mounted) return;
    final providers = OpenAiProviderRegistry.allProviders;
    final storedProvider = appdata.implicitData['settingGenProvider'];
    final provider =
        (storedProvider is String && providers.containsKey(storedProvider))
        ? storedProvider
        : providers.keys.firstWhere((_) => true, orElse: () => 'siliconFlow');
    final storedModel = appdata.implicitData['settingGenModel'];
    final model = storedModel is String ? storedModel : '';
    const system =
        '你是世界书关键词生成助手。为给定的每条条目生成“目标语言”的触发关键词'
        '（2~5 个短词或短语，能代表该条目主题，供在聊天中命中触发）。'
        '只输出 JSON 数组，形如 [{"id":"条目id","triggers":["词1","词2"]}]，'
        '不要任何其它文字。';

    var updated = 0;
    final loading = showLoadingDialog(App.rootContext);
    try {
      const batch = 20;
      for (var i = 0; i < book.entries.length; i += batch) {
        final slice = book.entries.sublist(
          i,
          (i + batch).clamp(0, book.entries.length),
        );
        final items = [
          for (final e in slice)
            {
              'id': e.id,
              'name': e.name,
              'content': e.content.length > 300
                  ? e.content.substring(0, 300)
                  : e.content,
            },
        ];
        final res = await AiConversationService().runTask(
          provider: provider,
          taskType: 'wb_triggers',
          sessionTitle: t.loreGenTriggers,
          systemPrompt: system,
          prompt:
              '目标语言：$lang\n\n条目：\n${jsonEncode(items)}\n\n'
              '请为每个条目生成 $lang 触发关键词，输出 JSON 数组。',
          modelOverride: model.isEmpty ? null : model,
        );
        if (!res.success) continue;
        final text = res.dataOrNull ?? '';
        final m = RegExp(r'\[[\s\S]*\]').firstMatch(text);
        if (m == null) continue;
        Object? decoded;
        try {
          decoded = jsonDecode(m.group(0)!);
        } catch (_) {
          decoded = null;
        }
        if (decoded is! List) continue;
        for (final item in decoded) {
          if (item is! Map) continue;
          final id = item['id']?.toString() ?? '';
          final raw = item['triggers'];
          final triggers = raw is List
              ? raw
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList()
              : <String>[];
          if (id.isEmpty || triggers.isEmpty) continue;
          WorldBookEntry? entry;
          for (final e in book.entries) {
            if (e.id == id) {
              entry = e;
              break;
            }
          }
          if (entry == null) continue;
          final merged = <String>[...entry.triggers];
          for (final tg in triggers) {
            if (!merged.contains(tg)) merged.add(tg);
          }
          if (merged.length == entry.triggers.length) continue;
          await WorldBookStore.instance.upsert(
            entry.copyWith(triggers: merged),
            bookId: book.id,
          );
          updated++;
        }
      }
    } finally {
      loading.close();
    }
    if (!mounted) return;
    App.rootContext.showMessage(
      message: updated > 0
          ? t.loreTriggerGenDone(count: updated)
          : t.loreTriggerGenFailed,
      level: updated > 0 ? LogLevel.info : LogLevel.error,
    );
    setState(() {});
  }

  /// 新建一本世界书（组）
  Future<void> _newBook() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.newWorldBook,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t.worldBookName,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    final book = await WorldBookStore.instance.createBook(name: name);
    if (!mounted) return;
    setState(() => _expandedBooks.add(book.id));
  }

  /// 重命名世界书
  Future<void> _renameBook(WorldBookBook book) async {
    final ctrl = TextEditingController(text: book.name);
    final name = await showDialog<String>(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.rename,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: t.worldBookName,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    await WorldBookStore.instance.upsertBook(
      WorldBookBook(id: book.id, name: name, entries: book.entries),
    );
    if (mounted) setState(() {});
  }

  /// 把条目移动到另一本书
  Future<void> _moveEntry(WorldBookEntry entry) async {
    final store = WorldBookStore.instance;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.worldBookMove,
        icon: Icons.drive_file_move_outline,
        initialSize: 0.4,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            for (final b in store.books)
              if (b.id != entry.bookId)
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(b.name.isEmpty ? t.worldBook : b.name),
                  trailing: Text('${b.entries.length}'),
                  onTap: () => Navigator.of(ctx).pop(b.id),
                ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await store.upsert(entry, bookId: choice);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => DropTarget(
    onDragDone: _onDrop,
    onDragEntered: (_) {
      if (mounted) setState(() => _dragOver = true);
    },
    onDragExited: (_) {
      if (mounted) setState(() => _dragOver = false);
    },
    child: Container(
      decoration: _dragOver
          ? BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : null,
      child: _buildBody(context),
    ),
  );

  Widget _buildBody(BuildContext context) {
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
                tooltip: t.newWorldBook,
                onPressed: _newBook,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final books = store.books;
              if (books.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(t.noWorldBookEntriesYet, style: ts.s12),
                );
              }
              final children = <Widget>[];
              for (final book in books) {
                final expanded = _expandedBooks.contains(book.id);
                void toggle() => setState(() {
                  if (expanded) {
                    _expandedBooks.remove(book.id);
                  } else {
                    _expandedBooks.add(book.id);
                  }
                });
                children.add(
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            expanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 20,
                          ),
                          onPressed: toggle,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: toggle,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              book.name.isEmpty ? t.worldBook : book.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${book.entries.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: t.loreGenTriggers,
                          icon: const Icon(Icons.translate, size: 18),
                          onPressed: () => _genTriggers(book),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: t.newWorldBookEntry,
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () => showPopUpWidget(
                            App.rootContext,
                            _WorldBookEditor(bookId: book.id),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '',
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (v) {
                            if (v == 'rename') _renameBook(book);
                            if (v == 'delete') store.removeBook(book.id);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'rename', child: Text(t.rename)),
                            PopupMenuItem(value: 'delete', child: Text(t.delete)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
                if (!expanded) continue;
                final sorted = [...book.entries]
                  ..sort((a, b) => b.priority.compareTo(a.priority));
                for (final entry in sorted) {
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
                            onMove: () => _moveEntry(entry),
                          ),
                        ],
                      ),
                    ),
                  );
                }
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
  const _WorldBookTile({
    required this.entry,
    required this.onToggle,
    this.onMove,
  });

  final WorldBookEntry entry;
  final ValueChanged<bool> onToggle;

  /// 移动到其它世界书
  final VoidCallback? onMove;

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
          if (onMove != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: t.worldBookMove,
              icon: const Icon(Icons.drive_file_move_outline, size: 18),
              onPressed: onMove,
            ),
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
  const _WorldBookEditor({this.entry, this.bookId});

  final WorldBookEntry? entry;

  /// 新建条目时并入的世界书 id（空 = 并入最后一本 / 新建一本）
  final String? bookId;

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
  late String _position = widget.entry?.position ?? 'after_char';
  late String _role = widget.entry?.role ?? 'system';
  late final List<String> _boundChars = [...?widget.entry?.characterIds];
  late final List<String> _boundTags = [...?widget.entry?.tags];

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

  /// 角色卡上出现过的全部标签（绑定标签从这里选）
  List<String> get _availableTags {
    final out = <String>{};
    for (final c in CharacterCardStore.instance.cards) {
      out.addAll(c.tags.where((e) => e.trim().isNotEmpty));
    }
    out.addAll(_boundTags);
    final list = out.toList()..sort();
    return list;
  }

  List<String> _lines(TextEditingController ctrl) => ctrl.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// 用 AI 按描述补全名称 / 触发词 / 内容
  Future<void> _aiFill() async {
    final existing = <String, dynamic>{
      if (_nameCtrl.text.trim().isNotEmpty) 'name': _nameCtrl.text.trim(),
      if (_contentCtrl.text.trim().isNotEmpty)
        'content': _contentCtrl.text.trim(),
      if (_triggerCtrl.text.trim().isNotEmpty)
        'triggers': _lines(_triggerCtrl),
    };
    final data = await aiGenerateEntry(
      title: t.aiGenerate,
      systemPrompt: t.worldBookAiSystem,
      promptTemplate: t.worldBookAiPrompt,
      // 已有内容 → 在现有基础上优化
      previous: existing.isEmpty ? null : existing,
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
      // 没填触发词就按常驻处理（对齐 SillyTavern：条目可以没有关键词）
      constant: _constant || _lines(_triggerCtrl).isEmpty,
      recursive: _recursive,
      position: _position,
      role: _role,
      characterIds: _boundChars,
      tags: _boundTags,
      depth: int.tryParse(_depthCtrl.text.trim()) ?? 4,
      sticky: int.tryParse(_stickyCtrl.text.trim()) ?? 0,
      cooldown: int.tryParse(_cooldownCtrl.text.trim()) ?? 0,
    );
    await WorldBookStore.instance.upsert(entry, bookId: widget.bookId);
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
                  // 底部留白：避免右下角「应用」按钮遮住最后几个字段
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  child: _SettingCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: t.worldBookName,
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
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                          // 留空视为常驻，不再强制要求触发词
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _contentCtrl,
                          maxLines: 8,
                          decoration: InputDecoration(
                            labelText: t.worldBookContent,
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
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Text(t.worldBookPosition),
                            const Spacer(),
                            Select(
                              current: switch (_position) {
                                'before_char' || 'before' =>
                                  t.worldBookPositionBefore,
                                'at_depth' => t.worldBookPositionAtDepth,
                                _ => t.worldBookPositionAfter,
                              },
                              values: [
                                t.worldBookPositionBefore,
                                t.worldBookPositionAfter,
                                t.worldBookPositionAtDepth,
                              ],
                              onTap: (i) => setState(
                                () => _position = const [
                                  'before_char',
                                  'after_char',
                                  'at_depth',
                                ][i],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_position == 'at_depth')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              Text(t.worldBookRole),
                              const Spacer(),
                              Select(
                                current: _role,
                                values: const [
                                  'system',
                                  'user',
                                  'assistant',
                                ],
                                onTap: (i) => setState(
                                  () => _role = const [
                                    'system',
                                    'user',
                                    'assistant',
                                  ][i],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.worldBookBindCharacters),
                            const SizedBox(height: 6),
                            CapsuleChipGroup(
                              children: [
                                for (final c
                                    in CharacterCardStore.instance.cards)
                                  CapsuleChip(
                                    text: c.name,
                                    isSelected: _boundChars.contains(c.id),
                                    onTap: () => setState(() {
                                      _boundChars.contains(c.id)
                                          ? _boundChars.remove(c.id)
                                          : _boundChars.add(c.id);
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(t.worldBookBindTags),
                            const SizedBox(height: 6),
                            CapsuleChipGroup(
                              children: [
                                for (final tag in _availableTags)
                                  CapsuleChip(
                                    text: tag,
                                    isSelected: _boundTags.contains(tag),
                                    onTap: () => setState(() {
                                      _boundTags.contains(tag)
                                          ? _boundTags.remove(tag)
                                          : _boundTags.add(tag);
                                    }),
                                  ),
                              ],
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
