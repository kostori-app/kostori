part of 'settings_page.dart';

class AiSettings extends StatefulWidget {
  const AiSettings({super.key});

  @override
  State<AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<AiSettings> {
  final _providers = OpenAiProviderRegistry.allProviders.entries
      .map((e) => (e.key, e.value.name, e.value.defaultModel, e.value.baseUrl))
      .toList();

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text('AI Settings'.tl)),

        // ── API Key 配置 ──────────────────────────
        _BuildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(title: 'AI 服务配置'.tl, icon: Icons.key_outlined),
              for (final (source, name, defaultModel, _) in _providers)
                _ApiKeyTileWidget(
                  source: source,
                  name: name,
                  defaultModel: defaultModel,
                  onSaved: () => setState(() {}),
                ),
            ],
          ),
        ),

        _BuildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(
                title: 'Persona Management'.tl,
                icon: Icons.tune_outlined,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // 导入并新建按钮
                        IconButton(
                          icon: const Icon(Icons.input),
                          onPressed: () => showPopUpWidget(
                            App.rootContext,
                            _PromptEditor(
                              configKey: '',
                              title: 'Import Persona'.tl,
                              defaultPrompt: '',
                              isCreateNew: true,
                              initialImport: true,
                            ),
                          ),
                        ),
                        // 纯新建按钮
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => showPopUpWidget(
                            App.rootContext,
                            _PromptEditor(
                              configKey:
                                  'custom_${DateTime.now().millisecondsSinceEpoch}',
                              title: 'New Persona'.tl,
                              defaultPrompt: '',
                              isCreateNew: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StreamBuilder<List<AiConfig>>(
                stream: AiDatabase.instance.aiConfigDao.watchAll(),
                builder: (context, snapshot) {
                  final configs = snapshot.data ?? [];
                  if (configs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('No configurations found'.tl, style: ts.s12),
                    );
                  }

                  return Column(
                    children: configs
                        .map((cfg) => _PromptTile(config: cfg))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// API Key 单行
// ─────────────────────────────────────────────

class _ApiKeyTileWidget extends StatefulWidget {
  const _ApiKeyTileWidget({
    required this.source,
    required this.name,
    required this.defaultModel,
    required this.onSaved,
  });

  final String source;
  final String name;
  final String defaultModel;
  final VoidCallback onSaved;

  @override
  State<_ApiKeyTileWidget> createState() => _ApiKeyTileWidgetState();
}

class _ApiKeyTileWidgetState extends State<_ApiKeyTileWidget> {
  AiApiKey? _row;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await AiDatabase.instance.aiApiKeyDao.getByProvider(
      widget.source,
    );
    if (mounted) {
      setState(() {
        _row = row;
        _loaded = true;
      });
    }
  }

  String get _statusText {
    if (!_loaded) return '...';
    if (_row == null || _row!.apiKey.isEmpty) return '未配置'.tl;
    return _row!.isEnabled ? '已启用'.tl : '已禁用'.tl;
  }

  Color _statusColor(BuildContext context) {
    if (_row == null || _row!.apiKey.isEmpty) {
      return context.colorScheme.onSurface.toOpacity(0.4);
    }
    return _row!.isEnabled ? Colors.green : Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.name),
      subtitle: Text(
        _row?.model ?? widget.defaultModel,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _statusText,
            style: TextStyle(fontSize: 12, color: _statusColor(context)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_right),
        ],
      ),
      onTap: () async {
        await showPopUpWidget(
          App.rootContext,
          _ApiKeyEditor(
            source: widget.source,
            name: widget.name,
            defaultModel: widget.defaultModel,
            row: _row,
          ),
        );
        await _load();
        widget.onSaved();
      },
    );
  }
}

// ─────────────────────────────────────────────
// API Key 编辑弹窗
// ─────────────────────────────────────────────

class _ApiKeyEditor extends StatefulWidget {
  const _ApiKeyEditor({
    required this.source,
    required this.name,
    required this.defaultModel,
    required this.row,
  });

  final String source;
  final String name;
  final String defaultModel;
  final AiApiKey? row;

  @override
  State<_ApiKeyEditor> createState() => _ApiKeyEditorState();
}

class _ApiKeyEditorState extends State<_ApiKeyEditor> {
  late final _keyCtrl = TextEditingController(text: widget.row?.apiKey ?? '');
  late final _urlCtrl = TextEditingController(text: widget.row?.baseUrl ?? '');
  late bool _enabled = widget.row?.isEnabled ?? true;
  bool _obscure = true;

  // 当前选中的模型 ID
  String? _selectedModelId;

  // 该 provider 下的所有模型
  List<AiModel> _models = [];

  @override
  void initState() {
    super.initState();
    _selectedModelId = widget.row?.model ?? widget.defaultModel;
    _loadModels();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final models = await (AiDatabase.instance.select(
      AiDatabase.instance.aiModels,
    )..where((t) => t.provider.equals(widget.source))).get();

    // 如果没有模型，插入默认模型
    if (models.isEmpty) {
      await AiDatabase.instance.aiModelDao.upsertModels([
        AiModelsCompanion.insert(
          provider: widget.source,
          modelId: widget.defaultModel,
          label: widget.defaultModel,
        ),
      ]);
      final refreshed = await (AiDatabase.instance.select(
        AiDatabase.instance.aiModels,
      )..where((t) => t.provider.equals(widget.source))).get();
      if (mounted) setState(() => _models = refreshed);
    } else {
      if (mounted) setState(() => _models = models);
    }
  }

  Future<void> _save() async {
    await AiDatabase.instance.aiApiKeyDao.upsert(
      AiApiKeysCompanion.insert(
        provider: widget.source,
        apiKey: _keyCtrl.text.trim(),
        model: Value(_selectedModelId),
        baseUrl: Value(
          _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
        ),
        isEnabled: Value(_enabled),
      ),
    );
    if (mounted) {
      App.rootContext.showMessage(message: 'Saved'.tl);
      App.rootContext.pop(context);
    }
  }

  Future<void> _delete() async {
    await AiDatabase.instance.aiApiKeyDao.deleteByProvider(widget.source);
    if (mounted) App.rootContext.pop(context);
  }

  Future<void> _addModel() async {
    final ctrl = TextEditingController();
    final labelCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: 'Add Model'.tl,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: 'Model ID'.tl,
                hintText: 'e.g. gpt-4o',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: 'Display Name'.tl,
                hintText: 'e.g. GPT-4o',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await AiDatabase.instance.aiModelDao.upsertModels([
                AiModelsCompanion.insert(
                  provider: widget.source,
                  modelId: ctrl.text.trim(),
                  label: labelCtrl.text.trim().isNotEmpty
                      ? labelCtrl.text.trim()
                      : ctrl.text.trim(),
                ),
              ]);
              Navigator.pop(ctx);
              await _loadModels();
            },
            child: Text('Add'.tl),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteModel(AiModel model) async {
    await AiDatabase.instance.aiModelDao.deleteModel(
      model.provider,
      model.modelId,
    );
    if (_selectedModelId == model.modelId) {
      _selectedModelId = _models.isNotEmpty
          ? _models.first.modelId
          : widget.defaultModel;
    }
    await _loadModels();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopUpWidgetScaffold(
      title: widget.name,
      tailing: [
        if (widget.row != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: scheme.error,
            onPressed: _delete,
          ),
      ],
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    child: _SettingCard(
                      children: [
                        _SettingPartTitle(
                          title: 'API Configuration'.tl,
                          icon: Icons.key_outlined,
                        ),

                        // ── API Key ──────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: TextFormField(
                            controller: _keyCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'API Key'.tl,
                              prefixIcon: const Icon(Icons.key, size: 20),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                        ),

                        // ── Base URL ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: TextFormField(
                            controller: _urlCtrl,
                            decoration: InputDecoration(
                              labelText: 'Base URL'.tl,
                              helperText: 'Optional'.tl,
                              prefixIcon: const Icon(
                                Icons.home_filled,
                                size: 20,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),

                        // ── 启用开关 ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            children: [
                              const Icon(Icons.toggle_on_outlined, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Enable'.tl)),
                              CustomSwitch(
                                value: _enabled,
                                onChanged: (v) => setState(() => _enabled = v),
                              ),
                            ],
                          ),
                        ),

                        const Divider(indent: 16, endIndent: 16),

                        // ── 模型选择 ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(
                            children: [
                              const Icon(Icons.model_training, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Model'.tl,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const Spacer(),
                              // 添加模型按钮
                              IconButton.filledTonal(
                                icon: const Icon(Icons.add, size: 18),
                                tooltip: 'Add Model'.tl,
                                visualDensity: VisualDensity.compact,
                                onPressed: _addModel,
                              ),
                            ],
                          ),
                        ),

                        // 模型列表
                        if (_models.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No models. Add one above.'.tl,
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _models.map((m) {
                                final isSelected =
                                    _selectedModelId == m.modelId;
                                return _ModelChip(
                                  model: m,
                                  isSelected: isSelected,
                                  onSelect: () => setState(
                                    () => _selectedModelId = m.modelId,
                                  ),
                                  onDelete: () => _deleteModel(m),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── 保存按钮 ─────────────────────────────
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _save,
                label: Text('Apply'.tl),
                icon: const Icon(Icons.check),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 模型 Chip（选中 + 长按/右键删除）
// ─────────────────────────────────────────────

class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.model,
    required this.isSelected,
    required this.onSelect,
    required this.onDelete,
  });

  final AiModel model;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      onSecondaryTap: () => _confirmDelete(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  model.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    showMenuX(
      context,
      Offset(offset.dx + size.width / 2, offset.dy + size.height),
      [
        MenuEntry(
          icon: Icons.delete_outline,
          text: 'Delete'.tl,
          color: Theme.of(context).colorScheme.error,
          onClick: onDelete,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// System Prompt 单行
// ─────────────────────────────────────────────

class _PromptTile extends StatelessWidget {
  const _PromptTile({required this.config});

  final AiConfig config;

  @override
  Widget build(BuildContext context) {
    final preview = config.systemPrompt.length > 30
        ? '${config.systemPrompt.substring(0, 30)}...'
        : config.systemPrompt;

    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              config.configKey,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (config.memo != null && config.memo!.isNotEmpty)
            Text(
              config.memo!,
              style: TextStyle(
                color: context.colorScheme.primary,
                fontSize: 11,
              ),
            ),
          Text(
            preview.replaceAll('\n', ' '),
            style: TextStyle(color: context.colorScheme.outline, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config.isSystem)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'System'.tl,
                style: TextStyle(
                  fontSize: 10,
                  color: context.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          const Icon(Icons.arrow_right, size: 20),
        ],
      ),
      onTap: () => showPopUpWidget(
        App.rootContext,
        _PromptEditor(
          configKey: config.configKey,
          title: config.configKey,
          defaultPrompt: config.systemPrompt,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// System Prompt 编辑弹窗
// ─────────────────────────────────────────────

class _PromptEditor extends StatefulWidget {
  const _PromptEditor({
    required this.configKey,
    required this.title,
    required this.defaultPrompt,
    this.initialImport = false,
    this.isCreateNew = false,
  });

  final String configKey;
  final String title;
  final String defaultPrompt;
  final bool initialImport;
  final bool isCreateNew;

  @override
  State<_PromptEditor> createState() => _PromptEditorState();
}

class _PromptEditorState extends State<_PromptEditor> {
  final _formKey = GlobalKey<FormState>();

  late final _ctrl = TextEditingController();
  late final _tempCtrl = TextEditingController();
  late final _keyCtrl = TextEditingController();
  late final _memoCtrl = TextEditingController();

  int? _id;

  bool? _isSystem;

  bool get _isReadOnly => !widget.isCreateNew && (_isSystem == true);

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.initialImport) _import();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tempCtrl.dispose();
    _keyCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await AiDatabase.instance.aiConfigDao.getByKey(
      widget.configKey,
    );
    if (!mounted) return;
    setState(() {
      _id = widget.isCreateNew ? null : cfg?.id;
      _isSystem = cfg?.isSystem;
      _ctrl.text = cfg?.systemPrompt ?? widget.defaultPrompt;
      _tempCtrl.text = (cfg?.temperature ?? 0.7).toString();
      _keyCtrl.text = widget.isCreateNew
          ? '${widget.configKey}_${DateTime.now().millisecondsSinceEpoch % 10000}'
          : (cfg?.configKey ?? widget.configKey);
      _memoCtrl.text = cfg?.memo ?? '';
    });
  }

  Future<void> _export() async {
    final temp = double.tryParse(_tempCtrl.text) ?? 0.7;
    await Clipboard.setData(
      ClipboardData(
        text: jsonEncode({
          'config_key': _keyCtrl.text,
          'system_prompt': _ctrl.text,
          'temperature': temp.clamp(0.0, 1.0),
          'memo': _memoCtrl.text,
        }),
      ),
    );
    if (mounted) {
      App.rootContext.showMessage(message: 'Config copied to clipboard'.tl);
    }
  }

  Future<void> _import() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    try {
      final map = jsonDecode(data!.text!) as Map<String, dynamic>;
      setState(() {
        if (widget.isCreateNew) {
          _id = null;
          final importedKey = map['config_key'] as String? ?? 'custom_config';
          _keyCtrl.text =
              '${importedKey}_${DateTime.now().millisecondsSinceEpoch % 1000}';
        }
        _ctrl.text = map['system_prompt'] ?? _ctrl.text;
        _tempCtrl.text = (map['temperature'] ?? 0.7).toString();
        _memoCtrl.text = map['memo'] ?? _memoCtrl.text;
      });
      App.rootContext.showMessage(
        message: widget.isCreateNew
            ? 'Imported as new config'.tl
            : 'Imported'.tl,
      );
    } catch (_) {
      App.rootContext.showMessage(
        message: 'Invalid clipboard format'.tl,
        level: LogLevel.warning,
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isReadOnly) {
      App.rootContext.showMessage(
        message: 'Cannot modify system preset'.tl,
        level: LogLevel.warning,
      );
      return;
    }
    try {
      final temp = double.tryParse(_tempCtrl.text) ?? 0.7;
      await AiDatabase.instance.aiConfigDao.upsert(
        AiConfigsCompanion.insert(
          id: _id != null ? Value(_id!) : const Value.absent(),
          configKey: _keyCtrl.text,
          systemPrompt: _ctrl.text,
          temperature: Value(temp.clamp(0.0, 1.0)),
          memo: Value(_memoCtrl.text.isEmpty ? null : _memoCtrl.text),
        ),
      );
      if (mounted) {
        App.rootContext.showMessage(message: 'Saved'.tl);
        App.rootContext.pop();
      }
    } catch (e) {
      App.rootContext.showMessage(
        message: e.toString().contains('UNIQUE constraint failed')
            ? 'Config Key already exists. Please change it.'.tl
            : 'Error: $e',
        level: LogLevel.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: widget.title,
      tailing: [
        IconButton(
          onPressed: _export,
          icon: const Icon(Icons.content_copy_outlined),
        ),
        if (!_isReadOnly)
          IconButton(
            onPressed: _import,
            icon: const Icon(Icons.content_paste_outlined),
          ),
        if (!_isReadOnly && _id != null)
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => ContentDialog(
                  title: 'Delete Config'.tl,
                  content: Text(
                    'Are you sure you want to delete "${widget.configKey}"?'.tl,
                  ),
                  actions: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Delete'.tl),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await AiDatabase.instance.aiConfigDao.deleteByKey(
                  widget.configKey,
                );
                if (mounted) App.rootContext.pop();
              }
            },
          ),
      ],
      body: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _SettingCard(
                    children: [
                      if (_isReadOnly)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Read-only System Preset'.tl,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      _buildField(
                        Icons.vpn_key_outlined,
                        'Config Key',
                        _keyCtrl,
                        enabled: !_isReadOnly,
                      ),
                      _buildField(
                        Icons.description_outlined,
                        'Memo',
                        _memoCtrl,
                        enabled: !_isReadOnly,
                      ),
                      _buildField(
                        Icons.device_thermostat,
                        'Temperature',
                        _tempCtrl,
                        enabled: !_isReadOnly,
                        isTemperature: true,
                        helperText: 'Value: 0.0 - 1.0'.tl,
                      ),
                      _buildPromptEditor(enabled: !_isReadOnly),
                    ],
                  ),
                ),
              ),
              if (!_isReadOnly)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: _save,
                    label: Text('Apply'.tl),
                    icon: const Icon(Icons.check),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    IconData icon,
    String label,
    TextEditingController ctrl, {
    bool enabled = true,
    bool isTemperature = false,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: isTemperature
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        inputFormatters: isTemperature
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        decoration: InputDecoration(
          labelText: label.tl,
          prefixIcon: Icon(icon, size: 20),
          helperText: helperText,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required'.tl;
          if (isTemperature) {
            final n = double.tryParse(v);
            if (n == null || n < 0 || n > 1) return '0.0 - 1.0'.tl;
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPromptEditor({bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: _ctrl,
        maxLines: 10,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: 'System Prompt'.tl,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
