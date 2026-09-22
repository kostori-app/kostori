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
              labels: [t.promptInjection, t.worldBook, t.storySettingLibrary],
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
                  title: Text(b.name.isEmpty ? t.storySettingLibrary : b.name),
                  trailing: Text('${b.entries.length}'),
                  onTap: () => Navigator.of(ctx).pop(b.id),
                ),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;
      bookId = choice == '__new__' ? (await store.createBook()).id : choice;
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
        bookIds: [bookId],
      ),
    );
  }

  Future<void> _edit(SettingEntry entry) async {
    final result = await showSettingEntryEditor(entry);
    if (result == null) return;
    await SettingLibraryStore.instance.upsert(result);
    if (mounted) setState(() {});
  }

  /// 设定条目的 JSON 结构（供 AI 生成/精修）
  static String _settingSchema(String type) => switch (type) {
    SettingTypes.codex =>
      '{"name":"名称","kind":"item|trait|race|skill|talent|body",'
          '"display":"玩家可见描述","mechanics":"机制/数值"}',
    SettingTypes.title => '{"name":"称号名","effects":"效果（数值/机制）"}',
    SettingTypes.job =>
      '{"name":"职业名","description":"简介",'
          '"levels":[{"level":1,"name":"阶段名","bonus":"加成"}]}',
    SettingTypes.facility => '{"name":"设施名","description":"说明","maxLevel":3}',
    _ => '{"name":"名称","description":"说明"}',
  };

  /// 组的「AI 生成条目」：先选类型，再一次性生成多条并写入本书
  Future<void> _aiAddEntries(SettingBook book) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.aiGenerate,
        icon: Icons.auto_awesome,
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
    final items = await showAiEntryStudio(
      title: '${t.aiGenerate} · ${_typeLabel(type)}',
      systemPrompt: t.settingAiSystem,
      schemaHint: _settingSchema(type),
      multiple: true,
    );
    if (items == null || !mounted) return;
    var i = 0;
    for (final m in items) {
      final name = (m['name'] ?? m['key'] ?? '').toString();
      if (name.trim().isEmpty) continue;
      await SettingLibraryStore.instance.upsert(
        SettingEntry(
          id: 'set_${DateTime.now().microsecondsSinceEpoch}_${i++}',
          type: type,
          name: name,
          payload: m,
        ),
        bookId: book.id,
      );
    }
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
          name: f.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), ''),
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

  /// 管理条目的所属分组（可多选，同一条目可被多本设定书共用）
  Future<void> _moveEntry(SettingEntry entry) async {
    final store = SettingLibraryStore.instance;
    final selected = <String>{...entry.bookIds};
    final ok = await showDialog<bool>(
      context: App.rootContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => ContentDialog(
          title: t.worldBookGroups,
          content: SingleChildScrollView(
            child: CapsuleChipGroup(
              children: [
                for (final b in store.books)
                  CapsuleChip(
                    text: b.name.isEmpty ? t.storySettingLibrary : b.name,
                    isSelected: selected.contains(b.id),
                    onTap: () => setLocal(() {
                      if (!selected.remove(b.id)) selected.add(b.id);
                    }),
                  ),
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
    if (ok != true || !mounted) return;
    await store.setBookIds(entry.id, selected.toList());
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
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
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
                onPressed: () => _exportJson([
                  for (final e in store.items) e.toJson(),
                ], 'setting_library.json'),
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
                            tooltip: t.aiGenerate,
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            onPressed: () => _aiAddEntries(book),
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
                                    tooltip: t.worldBookGroups,
                                    icon: const Icon(
                                      Icons.folder_outlined,
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

/// 设定生成用的服务商 / 模型 / 参数：
/// 优先「辅助任务模型 → 设定生成」，未配置时回退旧的 settingGen* 设置，
/// 再回退到第一个可用服务商。
Future<({String provider, String? model, AiGenerationParams? params})>
resolveSettingGenConfig() async {
  final providers = OpenAiProviderRegistry.allProviders;
  final aux = await AiConversationService().loadAuxConfig('settingGen');
  final storedProvider = appdata.implicitData['settingGenProvider'];
  final provider = aux.provider.isNotEmpty
      ? aux.provider
      : (storedProvider is String && providers.containsKey(storedProvider))
      ? storedProvider
      : providers.keys.firstWhere((_) => true, orElse: () => 'siliconFlow');
  final storedModel = appdata.implicitData['settingGenModel'];
  final model = aux.model ?? (storedModel is String ? storedModel : '');
  final params = aux.temperature == null
      ? null
      : AiGenerationParams(temperature: aux.temperature);
  return (provider: provider, model: model, params: params);
}

/// 编辑设定库条目（按类型显示不同字段）
/// 用 AI 按用户描述生成设定 JSON（返回的键名由 [promptTemplate] 指定）。
/// 支持多轮迭代：生成后可继续输入修改意见，AI 在上一版基础上改进，直到点「完成」。
/// AI 条目工作室：多轮对话生成 / 精修条目，最终敲版返回条目列表。
/// [multiple]=true 时可一次产出多条（整组批量生成）；否则针对 [previous] 单条精修。
/// 模型统一走「辅助任务模型 → 设定生成」，不再在弹窗里选厂商。
Future<List<Map<String, dynamic>>?> showAiEntryStudio({
  required String title,
  required String systemPrompt,
  required String schemaHint,
  List<Map<String, dynamic>> previous = const [],
  bool multiple = true,
  // 非空：在当前导航器内以整块填充方式打开（用于本身就是弹窗的编辑器内部，
  // 避免再叠一层弹窗导致背景不对）。
  BuildContext? hostContext,
}) async {
  final base = await resolveSettingGenConfig();
  final page = _AiEntryStudio(
    title: title,
    systemPrompt: systemPrompt,
    schemaHint: schemaHint,
    previous: previous,
    multiple: multiple,
    provider: base.provider,
    model: base.model ?? '',
    params: base.params,
    rootPop: hostContext == null,
  );
  if (hostContext != null) {
    return Navigator.of(hostContext).push<List<Map<String, dynamic>>?>(
      MaterialPageRoute(builder: (_) => page),
    );
  }
  return showPopUpWidget<List<Map<String, dynamic>>?>(App.rootContext, page);
}

class _AiEntryStudio extends StatefulWidget {
  const _AiEntryStudio({
    required this.title,
    required this.systemPrompt,
    required this.schemaHint,
    required this.provider,
    required this.model,
    required this.params,
    required this.previous,
    required this.multiple,
    this.rootPop = true,
  });

  final String title;
  final String systemPrompt;
  final String schemaHint;
  final String provider;
  final String model;
  final AiGenerationParams? params;
  final List<Map<String, dynamic>> previous;
  final bool multiple;

  /// true：敲版时 pop 根 Navigator（PopUpWidget）；false：pop 当前 Navigator
  final bool rootPop;

  @override
  State<_AiEntryStudio> createState() => _AiEntryStudioState();
}

class _AiEntryStudioState extends State<_AiEntryStudio> {
  late List<Map<String, dynamic>> _items = [...widget.previous];
  final _inputCtrl = TextEditingController();
  final _messages = <(bool isUser, String text)>[];
  bool _streaming = false;
  String _streamText = '';
  CancelToken? _cancel;

  @override
  void dispose() {
    _cancel?.cancel();
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<String?> _run(String prompt) async {
    final ai = AiFactory.create(widget.provider);
    if (ai == null) {
      App.rootContext.showMessage(
        message: t.unknownServiceProvider(provider: widget.provider),
        level: LogLevel.error,
      );
      return null;
    }
    final cancel = CancelToken();
    _cancel = cancel;
    final buf = StringBuffer();
    setState(() {
      _streaming = true;
      _streamText = '';
    });
    try {
      await for (final chunk in ai.chatStream(
        [AiUserMessage(content: prompt)],
        systemPrompt: widget.systemPrompt,
        modelOverride: widget.model.isEmpty ? null : widget.model,
        params: widget.params,
        cancelToken: cancel,
      )) {
        if (!mounted) return null;
        if (chunk.errorMessage != null) {
          App.rootContext.showMessage(
            message: chunk.errorMessage!,
            level: LogLevel.error,
          );
          return null;
        }
        buf
          ..clear()
          ..write(chunk.text);
        setState(() => _streamText = chunk.text);
        if (chunk.done) break;
      }
    } catch (e) {
      if (mounted && !cancel.isCancelled) {
        App.rootContext.showMessage(
          message: e.toString(),
          level: LogLevel.error,
        );
      }
      return null;
    } finally {
      _cancel = null;
      if (mounted) {
        setState(() {
          _streaming = false;
          _streamText = ''; // 结束后由消息气泡展示，避免重复显示
        });
      }
    }
    return buf.toString();
  }

  /// 展示用文本：去掉 JSON 代码块与 actions 段，只留解说
  String _displayText(String text) {
    var s = text.replaceAll(RegExp(r'<actions>[\s\S]*?</actions>'), '');
    final fence = s.indexOf('```');
    if (fence >= 0) s = s.substring(0, fence);
    return s.trim();
  }

  /// 查看条目：底部弹窗渲染（名称 + 触发词 + 内容）
  Future<void> _showEntries() async {
    await showModalBottomSheet<void>(
      context: App.rootContext,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: '${t.storyCodex} · ${_items.length}',
        icon: Icons.list_alt,
        initialSize: 0.7,
        builder: (ctx, sc) => ListView.builder(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: _items.length,
          itemBuilder: (_, i) {
            final m = _items[i];
            final name = (m['name'] ?? m['key'] ?? m['title'] ?? '条目 ${i + 1}')
                .toString();
            final triggers =
                (m['triggers'] as List?)?.map((e) => e.toString()).toList() ??
                const <String>[];
            final content =
                (m['content'] ??
                        m['mechanics'] ??
                        m['display'] ??
                        m['effects'] ??
                        m['description'] ??
                        '')
                    .toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (triggers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tg in triggers)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tg,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (content.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    AppSelectableText(
                      content.trim(),
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _generatePrompt(String desc) =>
      '根据下面的需求生成${widget.multiple ? '若干' : '一条'}条目。\n'
      '每个条目的 JSON 结构：\n${widget.schemaHint}\n'
      '只输出 JSON 数组（用 ```json 围栏包裹），不要任何解释。\n\n'
      '需求：$desc';

  String _refinePrompt(String feedback) =>
      '当前条目（JSON 数组）：\n${jsonEncode(_items)}\n\n'
      '用户的修改要求：$feedback\n\n'
      '优先只输出需要变更的部分：用 <actions> 标签包裹 JSON 数组，'
      'path 形如 items[0].name、items[1].content（支持 set/add/remove）；'
      '若需要整体重写，也可直接输出更新后的 JSON 数组。';

  List<Map<String, dynamic>>? _parseItems(String text) {
    final candidates = <String>[];
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fenced != null) candidates.add(fenced.group(1)!);
    final lb = text.indexOf('[');
    final rb = text.lastIndexOf(']');
    if (lb >= 0 && rb > lb) candidates.add(text.substring(lb, rb + 1));
    final lo = text.indexOf('{');
    final ro = text.lastIndexOf('}');
    if (lo >= 0 && ro > lo) candidates.add(text.substring(lo, ro + 1));
    for (final raw in candidates) {
      try {
        final decoded = jsonDecode(raw.trim());
        if (decoded is List) {
          final list = [
            for (final e in decoded)
              if (e is Map) e.cast<String, dynamic>(),
          ];
          if (list.isNotEmpty) return list;
        } else if (decoded is Map) {
          return [decoded.cast<String, dynamic>()];
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _submit() async {
    if (_streaming) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    final generating = _items.isEmpty;
    setState(() => _messages.add((true, text)));
    final reply = await _run(
      generating ? _generatePrompt(text) : _refinePrompt(text),
    );
    if (!mounted || reply == null) return;
    setState(() => _messages.add((false, reply)));
    if (generating) {
      final parsed = _parseItems(reply);
      if (parsed == null) {
        App.rootContext.showMessage(
          message: t.cardAiParseFailed,
          level: LogLevel.warning,
        );
        return;
      }
      setState(() => _items = parsed);
      return;
    }
    final actions = parseJsonActions(reply);
    if (actions.isNotEmpty) {
      final root = <String, dynamic>{'items': _items};
      final updated = applyJsonActions(root, actions);
      final list = [
        for (final e in (updated['items'] as List? ?? const []))
          if (e is Map) e.cast<String, dynamic>(),
      ];
      if (list.isNotEmpty) setState(() => _items = list);
      return;
    }
    final parsed = _parseItems(reply);
    if (parsed != null) setState(() => _items = parsed);
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: widget.title,
      tailing: [
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: t.confirm,
          onPressed: _items.isEmpty
              ? null
              : () {
                  if (widget.rootPop) {
                    Navigator.of(
                      App.rootContext,
                      rootNavigator: true,
                    ).pop(_items);
                  } else {
                    context.pop(_items);
                  }
                },
        ),
      ],
      body: Column(
        children: [
          // 条目预览改为按钮，避免占满内容区
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _items.isEmpty ? null : _showEntries,
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: Text('${t.storyCodex} · ${_items.length}'),
                ),
                const Spacer(),
                if (_streaming)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: PolygonRefreshIndicator(size: 16),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              children: [
                if (_streamText.isNotEmpty)
                  _bubble(_displayText(_streamText), false, streaming: true),
                for (final m in _messages.reversed)
                  _bubble(m.$1 ? m.$2 : _displayText(m.$2), m.$1),
              ],
            ),
          ),
          ChatComposer(
            controller: _inputCtrl,
            hintText: _items.isEmpty ? t.aiGenerateHint : t.aiRefineHint,
            sending: _streaming,
            onSend: _submit,
            onStop: () => _cancel?.cancel(),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, bool isUser, {bool streaming = false}) {
    final scheme = Theme.of(context).colorScheme;
    final body = text.isEmpty
        ? (streaming
              ? t.generatingReply
              : t.aiEntriesUpdated(count: _items.length))
        : text;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppSelectableText(
          body,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: text.isEmpty && !streaming ? scheme.onSurfaceVariant : null,
          ),
        ),
      ),
    );
  }
}

/// 设定库触发词输入（「、,，/／|」或换行分隔）→ 列表
List<String> _splitSettingTriggers(String s) => s
    .split(RegExp(r'[、,，/／|\n]+'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// AI 精修请求：编辑器内点「精修」时返回，由外层关闭编辑器后再开工作室
class _AiRefineRequest {
  final Map<String, dynamic> payload;
  const _AiRefineRequest(this.payload);
}

/// 编辑设定库条目。AI 精修会先关掉本编辑器 → 开工作室 → 带着结果重开，
/// 避免在弹窗上再叠一层弹窗（那样背景/层级会不对）。
Future<SettingEntry?> showSettingEntryEditor(SettingEntry entry) async {
  var current = entry;
  while (true) {
    final result = await _showSettingEntryDialog(current);
    if (result is _AiRefineRequest) {
      final refined = await showAiEntryStudio(
        title: '${t.edit} · ${t.aiRefine}',
        systemPrompt: t.settingAiSystem,
        schemaHint: _SettingLibraryPanelState._settingSchema(current.type),
        previous: [result.payload],
        multiple: false,
      );
      if (refined != null && refined.isNotEmpty) {
        final item = refined.first;
        final n = item['name']?.toString().trim() ?? '';
        current = current.copyWith(
          name: n.isNotEmpty ? n : current.name,
          payload: item,
        );
      }
      continue;
    }
    if (result is SettingEntry) return result;
    return null;
  }
}

Future<Object?> _showSettingEntryDialog(SettingEntry entry) async {
  final nameCtrl = TextEditingController(text: entry.name);
  final groupCtrl = TextEditingController(text: entry.group);
  final triggersCtrl = TextEditingController(
    text: (entry.payload['triggers'] as List?)?.join('、') ?? '',
  );
  final bookIds = <String>{...entry.bookIds};
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

  /// 收集当前字段为一个条目 JSON（供 AI 精修与保存共用）
  Map<String, dynamic> buildPayload() {
    final name = nameCtrl.text.trim();
    final triggers = _splitSettingTriggers(triggersCtrl.text);
    final payload = <String, dynamic>{};
    switch (entry.type) {
      case SettingTypes.codex:
        payload.addAll({
          'kind': codexKind,
          'key': name,
          'name': name,
          'display': displayCtrl.text.trim(),
          'mechanics': mechanicsCtrl.text.trim(),
          if (triggers.isNotEmpty) 'triggers': triggers,
        });
      case SettingTypes.title:
        payload.addAll({
          'key': name,
          'name': name,
          'effects': effectsCtrl.text.trim(),
          'stackable': stackable,
          if (triggers.isNotEmpty) 'triggers': triggers,
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
                    'level':
                        int.tryParse(parts.isNotEmpty ? parts[0].trim() : '') ??
                        0,
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
          if (triggers.isNotEmpty) 'triggers': triggers,
        });
    }
    return payload;
  }

  final ok = await showDialog<Object?>(
    context: App.rootContext,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => ContentDialog(
        title: entry.name.isEmpty ? t.storyAddEntry : t.edit,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 仅对已有条目提供 AI 精修（新建请用组上的「AI 生成」）
              if (entry.payload.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    // 先关掉本编辑器，由外层打开工作室，再带结果重开：
                    // 避免在弹窗上再叠弹窗导致背景不对
                    onPressed: () =>
                        Navigator.of(ctx).pop(_AiRefineRequest(buildPayload())),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(t.aiRefine),
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(t.worldBookGroups),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: CapsuleChipGroup(
                  children: [
                    for (final b in SettingLibraryStore.instance.books)
                      CapsuleChip(
                        text: b.name.isEmpty ? t.storySettingLibrary : b.name,
                        isSelected: bookIds.contains(b.id),
                        onTap: () => setLocal(() {
                          if (!bookIds.remove(b.id)) bookIds.add(b.id);
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (entry.type != SettingTypes.job) ...[
                TextField(
                  controller: triggersCtrl,
                  decoration: InputDecoration(
                    labelText: t.worldBookTriggers,
                    helperText: t.storyTriggersHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
                    labelText:
                        '${t.storyJobLevel}｜${t.storyCharacterName}｜${t.storyJobBonus}',
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
  final group = groupCtrl.text.trim();
  final payload = buildPayload();
  nameCtrl.dispose();
  groupCtrl.dispose();
  triggersCtrl.dispose();
  displayCtrl.dispose();
  mechanicsCtrl.dispose();
  effectsCtrl.dispose();
  descCtrl.dispose();
  maxLevelCtrl.dispose();
  levelsCtrl.dispose();
  if (ok != true) return null;
  return entry.copyWith(
    name: name,
    group: group,
    bookIds: bookIds.toList(),
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

Future<void> _exportJson(
  List<Map<String, dynamic>> items,
  String filename,
) async {
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
      final Object s
          when const {
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
  final entries = _parseWorldBookEntries(jsonDecode(utf8.decode(bytes)))
      .map((e) => e.copyWith(bookIds: const []))
      .toList();
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
                onPressed: () => _exportJson([
                  for (final i in store.items) i.toJson(),
                ], 'prompt_injections.json'),
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
          name: f.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), ''),
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
                  ActionChip(label: Text(l), onPressed: () => ctrl.text = l),
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
    final gen = await resolveSettingGenConfig();
    final provider = gen.provider;
    final model = gen.model ?? '';
    const system =
        '你是世界书关键词生成助手。为给定的每条条目生成“目标语言”的触发关键词'
        '（2~5 个短词或短语，能代表该条目主题，供在聊天中命中触发）。'
        '只输出 JSON 数组，形如 [{"id":"条目id","triggers":["词1","词2"]}]，'
        '不要任何其它文字。';

    var updated = 0;
    final total = book.entries.length;
    final loading = showLoadingDialog(
      App.rootContext,
      withProgress: true,
      message: t.loreTriggerGenProgress(done: 0, total: total),
    );
    try {
      const batch = 20;
      for (var i = 0; i < total; i += batch) {
        loading.setMessage(t.loreTriggerGenProgress(done: i, total: total));
        loading.setProgress(i / total);
        final slice = book.entries.sublist(i, (i + batch).clamp(0, total));
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
          params: gen.params,
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
        final done = (i + batch).clamp(0, total);
        loading.setMessage(t.loreTriggerGenProgress(done: done, total: total));
        loading.setProgress(done / total);
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

  /// 组的「AI 生成条目」：一次性生成多条世界书条目并写入本书
  Future<void> _aiAddEntries(WorldBookBook book) async {
    final items = await showAiEntryStudio(
      title: t.aiGenerate,
      systemPrompt: t.worldBookAiSystem,
      schemaHint: '{"name":"条目名","triggers":["触发词1","触发词2"],"content":"条目内容"}',
      multiple: true,
    );
    if (items == null || !mounted) return;
    var i = 0;
    for (final m in items) {
      final name = (m['name'] ?? '').toString();
      final content = (m['content'] ?? '').toString();
      if (name.trim().isEmpty && content.trim().isEmpty) continue;
      await WorldBookStore.instance.upsert(
        WorldBookEntry(
          id: 'wb_${DateTime.now().microsecondsSinceEpoch}_${i++}',
          name: name,
          triggers:
              (m['triggers'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
          content: content,
        ),
        bookId: book.id,
      );
    }
    if (mounted) setState(() {});
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

  /// 管理条目的所属分组（可多选，同一条目可被多本书共用）
  Future<void> _moveEntry(WorldBookEntry entry) async {
    final store = WorldBookStore.instance;
    final selected = <String>{...entry.bookIds};
    final ok = await showDialog<bool>(
      context: App.rootContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => ContentDialog(
          title: t.worldBookGroups,
          content: SingleChildScrollView(
            child: CapsuleChipGroup(
              children: [
                for (final b in store.books)
                  CapsuleChip(
                    text: b.name.isEmpty ? t.worldBook : b.name,
                    isSelected: selected.contains(b.id),
                    onTap: () => setLocal(() {
                      if (!selected.remove(b.id)) selected.add(b.id);
                    }),
                  ),
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
    if (ok != true || !mounted) return;
    await store.setBookIds(entry.id, selected.toList());
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
                onPressed: () => _exportJson([
                  for (final e in store.entries) e.toJson(),
                ], 'world_info.json'),
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
                            expanded ? Icons.expand_more : Icons.chevron_right,
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
                          tooltip: t.aiGenerate,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          onPressed: () => _aiAddEntries(book),
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
                            onDelete: () => store.remove(entry.id),
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
    this.onDelete,
  });

  final WorldBookEntry entry;
  final ValueChanged<bool> onToggle;

  /// 移动到其它世界书
  final VoidCallback? onMove;

  /// 删除该条目
  final VoidCallback? onDelete;

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
              tooltip: t.worldBookGroups,
              icon: const Icon(Icons.folder_outlined, size: 18),
              onPressed: onMove,
            ),
          if (onDelete != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: t.delete,
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: onDelete,
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

  /// 所属分组（可多选）
  late final List<String> _bookIds = [
    ...?widget.entry?.bookIds,
    if ((widget.entry?.bookIds ?? const []).isEmpty &&
        widget.bookId != null &&
        widget.bookId!.isNotEmpty)
      widget.bookId!,
  ];

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
      if (_triggerCtrl.text.trim().isNotEmpty) 'triggers': _lines(_triggerCtrl),
    };
    final items = await showAiEntryStudio(
      // 在当前弹窗导航器内打开，避免叠一层弹窗
      hostContext: context,
      title: existing.isEmpty ? t.aiGenerate : t.aiRefine,
      systemPrompt: t.worldBookAiSystem,
      schemaHint: '{"name":"条目名","triggers":["触发词1","触发词2"],"content":"条目内容"}',
      previous: existing.isEmpty ? const [] : [existing],
      multiple: false,
    );
    if (items == null || items.isEmpty || !mounted) return;
    final data = items.first;
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
      bookIds: _bookIds,
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.worldBookGroups),
                            const SizedBox(height: 6),
                            CapsuleChipGroup(
                              children: [
                                for (final b in WorldBookStore.instance.books)
                                  CapsuleChip(
                                    text: b.name.isEmpty ? t.worldBook : b.name,
                                    isSelected: _bookIds.contains(b.id),
                                    onTap: () => setState(() {
                                      if (!_bookIds.remove(b.id)) {
                                        _bookIds.add(b.id);
                                      }
                                    }),
                                  ),
                              ],
                            ),
                          ],
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
                                'before_char' ||
                                'before' => t.worldBookPositionBefore,
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
                                values: const ['system', 'user', 'assistant'],
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
                                    text: c.displayName,
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
