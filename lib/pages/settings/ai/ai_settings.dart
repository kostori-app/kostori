part of '../settings_page.dart';

class AiSettings extends StatefulWidget {
  const AiSettings({super.key});

  @override
  State<AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<AiSettings> {
  late final _providers = AiProviderSettingsRepository();
  late final _providerStream = _providers.watchProviders();

  void _editProvider(AiProviderSettings provider) {
    showPopUpWidget(
      context,
      AiProviderEditor(
        settings: provider,
        repository: _providers,
        selectModels: _showModelImportDialog,
        modelsBuilder: (view) => _ModelListSection(
          sourceKey: view.source,
          models: view.models,
          selectedModelId: view.selectedModel,
          onSelected: view.onSelected,
          onDelete: view.onDelete,
          onChanged: view.onChanged,
          canAdd: view.source.isNotEmpty,
          scrollable: true,
        ),
      ),
    );
  }

  void _addProvider() => _editProvider(
    AiProviderSettings(
      source: OpenAiProviderRegistry.customSourceKey(const Uuid().v4()),
      name: '',
      baseUrl: '',
      isNew: true,
    ),
  );

  @override
  Widget build(BuildContext context) => SmoothCustomScrollView(
    slivers: [
      SliverAppbar(title: Text(t.aiSettings)),
      _BuildSectionPadding(
        _SettingCard(
          children: [
            _SettingPartTitle(
              title: t.aiServiceConfig,
              icon: Icons.dns_outlined,
            ),
            StreamBuilder<List<AiProviderSettings>>(
              stream: _providerStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(aiErrorMessageOf(snapshot.error)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: PolygonRefreshIndicator()),
                  );
                }
                return AiProviderSettingsSection(
                  providers: snapshot.data!,
                  onOpen: _editProvider,
                  onAdd: _addProvider,
                );
              },
            ),
          ],
        ),
      ),
      _BuildSectionPadding(const _GlobalContextBudgetCard()),
      _BuildSectionPadding(_AssistantProfileSection()),
      _BuildSectionPadding(
        _SettingCard(
          children: [
            _SettingPartTitle(
              title: t.extensionManagement,
              icon: Icons.extension_outlined,
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_mosaic_outlined),
              title: Text(t.extensionManagement),
              subtitle: Text(
                t.extensionManagementHint,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_right, size: 20),
              onTap: () => context.to(() => const ExtensionSettingsPage()),
            ),
          ],
        ),
      ),
    ],
  );
}

// 模型管理沿用现有能力编辑、筛选和批量操作，所有服务商共用。
class _ModelListSection extends StatefulWidget {
  const _ModelListSection({
    required this.sourceKey,
    required this.models,
    required this.selectedModelId,
    required this.onSelected,
    required this.onDelete,
    required this.onChanged,
    this.canAdd = true,
    this.scrollable = false,
  });

  /// 模型归属的服务商 source key（内置如 `deepseek`，自定义如 `custom_xxx`）
  final String sourceKey;

  final List<AiModel> models;

  final String? selectedModelId;

  final ValueChanged<String> onSelected;

  final ValueChanged<AiModel> onDelete;

  /// 增删/切换能力后刷新模型列表
  final Future<void> Function() onChanged;

  /// 是否允许添加模型（自定义服务商未填 key 时禁用）
  final bool canAdd;

  /// 是否自带滚动（Tab 页使用懒列表，避免切换时一次构建全部卡片卡顿）
  final bool scrollable;

  @override
  State<_ModelListSection> createState() => _ModelListSectionState();
}

class _ModelListSectionState extends State<_ModelListSection> {
  /// 当前类型筛选（null = 全部）
  String? _typeFilter;

  /// 搜索关键字（按名称 / ID 过滤）
  String _query = '';

  /// 已折叠的基名分组
  final Set<String> _collapsed = {};

  /// 默认模型卡片在列表中的下标（-1 表示未找到）
  int _defaultIndex = -1;

  /// 首次打开时自动滚动到默认模型（只滚一次）
  bool _autoScrolled = false;

  final ScrollController _scrollController = ScrollController();
  late final ListObserverController _observerController =
      ListObserverController(controller: _scrollController);

  @override
  void initState() {
    super.initState();
    if (widget.scrollable) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _autoScrollToDefault(),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 打开后自动定位到默认模型（列表懒加载，用观察器按需跳转）
  Future<void> _autoScrollToDefault() async {
    if (_autoScrolled || !mounted || _defaultIndex < 0) return;
    _autoScrolled = true;
    // 等观察器完成首帧布局再跳转
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted || _defaultIndex < 0) return;
    try {
      await _observerController.jumpTo(index: _defaultIndex, alignment: 0);
    } catch (_) {
      // 列表尚未挂载时忽略
    }
  }

  /// 打开模型二级设置页（model 为 null 表示新增）
  Future<void> _openEditor(BuildContext context, {AiModel? model}) async {
    await showPopUpWidget(
      context,
      _ModelEditorPage(
        sourceKey: widget.sourceKey,
        model: model,
        isDefault: model != null && widget.selectedModelId == model.modelId,
        onSetDefault: (id) {
          widget.onSelected(id);
        },
        onChanged: widget.onChanged,
      ),
    );
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _buildRows(scheme);
    if (widget.scrollable) {
      return ListViewObserver(
        controller: _observerController,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: rows.length,
          itemBuilder: (context, i) => rows[i],
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  List<Widget> _buildRows(ColorScheme scheme) {
    // ── 标题 + 添加按钮 ─────────────────────────
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.model_training, size: 20),
          const SizedBox(width: 8),
          Text(t.model, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          IconButton.filledTonal(
            icon: const Icon(Icons.add, size: 18),
            tooltip: t.addModel,
            visualDensity: VisualDensity.compact,
            onPressed: widget.canAdd ? () => _openEditor(context) : null,
          ),
        ],
      ),
    );

    _defaultIndex = -1;

    if (widget.models.isEmpty) {
      return [
        header,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.canAdd
                ? t.noModelsAddOneAbove
                : t.enterProviderKeyToAddModel,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ),
      ];
    }

    // ── 类型筛选（分段胶囊）────────────────────
    final types = <String>[];
    for (final m in widget.models) {
      final tp = m.modelType.isEmpty ? 'chat' : m.modelType;
      if (!types.contains(tp)) types.add(tp);
    }
    final filterRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: CapsuleOptions(
        scrollable: true,
        alignment: WrapAlignment.start,
        children: [
          CapsuleOption(
            text: t.all,
            isSelected: _typeFilter == null,
            onTap: () => setState(() => _typeFilter = null),
          ),
          for (final type in types)
            CapsuleOption(
              text: _modelTypeLabel(type),
              isSelected: _typeFilter == type,
              onTap: () => setState(
                () => _typeFilter = _typeFilter == type ? null : type,
              ),
            ),
        ],
      ),
    );

    // ── 搜索框 ─────────────────────────────────
    final searchRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: t.search,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _query = ''),
                ),
          isDense: true,
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
      ),
    );

    // ── 过滤（类型 + 关键字）再按基名分组 ────────
    final q = _query.trim().toLowerCase();
    final filtered = widget.models.where((m) {
      final tp = m.modelType.isEmpty ? 'chat' : m.modelType;
      if (_typeFilter != null && tp != _typeFilter) return false;
      if (q.isNotEmpty &&
          !m.label.toLowerCase().contains(q) &&
          !m.modelId.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
    final groups = <String, List<AiModel>>{};
    for (final m in filtered) {
      groups.putIfAbsent(_baseModelName(m.modelId), () => []).add(m);
    }
    final bases = groups.keys.toList()..sort();

    final rows = <Widget>[header, filterRow, searchRow];
    for (final base in bases) {
      rows.add(_groupHeader(base, groups[base]!));
      if (_collapsed.contains(base)) continue;
      for (final m in groups[base]!) {
        if (!_autoScrolled && m.modelId == widget.selectedModelId) {
          _defaultIndex = rows.length;
        }
        rows.add(_modelCard(m));
      }
    }
    return rows;
  }

  Widget _groupHeader(String base, List<AiModel> group) {
    final scheme = Theme.of(context).colorScheme;
    final collapsed = _collapsed.contains(base);
    return InkWell(
      onTap: () => setState(() {
        if (collapsed) {
          _collapsed.remove(base);
        } else {
          _collapsed.add(base);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                base,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '${group.length}',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelCard(AiModel m) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: _ModelCard(
        model: m,
        isSelected: widget.selectedModelId == m.modelId,
        onOpen: () => _openEditor(context, model: m),
        onSetDefault: () => widget.onSelected(m.modelId),
        onDelete: () => widget.onDelete(m),
      ),
    );
  }
}

/// 提取模型基名：去掉尾部版本/日期/后缀（如 gpt-4o-2024-05-13 → gpt-4o）
String _baseModelName(String id) => baseModelName(id);

// ─────────────────────────────────────────────
// 模型卡片（单行样式：类型/输入模态/输出模态/能力 + 长按/右键操作）
// ─────────────────────────────────────────────

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.isSelected,
    required this.onOpen,
    required this.onSetDefault,
    required this.onDelete,
  });

  final AiModel model;
  final bool isSelected;
  final VoidCallback onOpen;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AiModelCard(
      model: model,
      isSelected: isSelected,
      showDefaultBadge: true,
      showLeadingRadio: false,
      onTap: onOpen,
      onLongPress: () => _showActions(context),
      onSecondaryTap: () => _showActions(context),
    );
  }

  void _showActions(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final scheme = Theme.of(context).colorScheme;
    showMenuX(
      context,
      Offset(offset.dx + size.width / 2, offset.dy + size.height),
      [
        MenuEntry(
          icon: Icons.tune_outlined,
          text: t.openModelSettings,
          onClick: onOpen,
        ),
        if (!isSelected)
          MenuEntry(
            icon: Icons.star_outline,
            text: t.setAsDefaultModel,
            onClick: onSetDefault,
          ),
        MenuEntry(
          icon: Icons.delete_outline,
          text: t.delete,
          color: scheme.error,
          onClick: onDelete,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 模型编辑页（单个模型的二级设置页，新增/编辑/删除/设默认）
// ─────────────────────────────────────────────

class _ModelEditorPage extends StatefulWidget {
  const _ModelEditorPage({
    required this.sourceKey,
    required this.onChanged,
    this.model,
    this.isDefault = false,
    this.onSetDefault,
  });

  final String sourceKey;
  final AiModel? model;
  final bool isDefault;
  final ValueChanged<String>? onSetDefault;
  final Future<void> Function() onChanged;

  @override
  State<_ModelEditorPage> createState() => _ModelEditorPageState();
}

class _ModelEditorPageState extends State<_ModelEditorPage> {
  static const _inputOptions = ['text', 'image'];
  static const _outputOptions = ['text', 'image'];
  static const _modelTypes = ['chat', 'image', 'embedding'];
  static const _capabilityOptions = ['tools', 'reasoning'];

  late final TextEditingController _idCtrl;
  late final TextEditingController _labelCtrl;
  late String _modelType;
  late List<String> _inputModality;
  late List<String> _outputModality;
  late bool _supportsTools;
  late bool _supportsReasoning;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _idCtrl = TextEditingController(text: m?.modelId ?? '');
    _labelCtrl = TextEditingController(text: m?.label ?? '');
    _modelType = (m?.modelType.isNotEmpty == true) ? m!.modelType : 'chat';
    _inputModality = _parseModality(m?.inputModality, const ['text']);
    _outputModality = _parseModality(m?.outputModality, const ['text']);
    _supportsTools = m?.supportsTools ?? true;
    _supportsReasoning = m?.supportsReasoning ?? false;
  }

  List<String> _parseModality(String? raw, List<String> fallback) {
    if (raw == null || raw.trim().isEmpty) return [...fallback];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;
    // 编辑时若修改了主键，先删除旧记录
    if (widget.model != null && widget.model!.modelId != id) {
      await AiDatabase.instance.aiModelDao.deleteModel(
        widget.sourceKey,
        widget.model!.modelId,
      );
    }
    await AiDatabase.instance.aiModelDao.upsertModels([
      AiModelsCompanion.insert(
        provider: widget.sourceKey,
        modelId: id,
        label: _labelCtrl.text.trim().isNotEmpty ? _labelCtrl.text.trim() : id,
        modelType: Value(_modelType),
        inputModality: Value(_inputModality.join(',')),
        outputModality: Value(_outputModality.join(',')),
        supportsVision: Value(widget.model?.supportsVision ?? true),
        supportsTools: Value(_supportsTools),
        supportsReasoning: Value(_supportsReasoning),
      ),
    ]);
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop(context);
    }
    await widget.onChanged();
  }

  Future<void> _delete() async {
    if (widget.model == null) return;
    await AiDatabase.instance.aiModelDao.deleteModel(
      widget.sourceKey,
      widget.model!.modelId,
    );
    if (mounted) App.rootContext.pop(context);
    await widget.onChanged();
  }

  void _setDefault() {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;
    widget.onSetDefault?.call(id);
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop(context);
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEditing = widget.model != null;

    return PopUpWidgetScaffold(
      title: isEditing ? t.editModel : t.addModel,
      tailing: [
        if (isEditing)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: scheme.error,
            tooltip: t.delete,
            onPressed: _delete,
          ),
      ],
      body: SingleChildScrollView(
        child: _SettingCard(
          children: [
            if (isEditing)
              _SettingPartTitle(
                title: widget.model?.label ?? '',
                icon: Icons.model_training,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextFormField(
                controller: _idCtrl,
                decoration: InputDecoration(
                  labelText: t.modelId,
                  hintText: 'e.g. gpt-4o',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextFormField(
                controller: _labelCtrl,
                decoration: InputDecoration(
                  labelText: t.displayName,
                  hintText: 'e.g. GPT-4o',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _typePicker(
                context,
                title: t.modelType,
                options: [
                  ..._modelTypes,
                  // 自动导入可能带来非固定选项的类型（如 audio），编辑时保留显示
                  if (!_modelTypes.contains(_modelType)) _modelType,
                ],
                selected: _modelType,
                onChanged: (v) => setState(() => _modelType = v),
                labelOf: _modelTypeLabel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _modalityPicker(
                context,
                title: t.inputModality,
                options: _inputOptions,
                selected: _inputModality,
                onChanged: (v) => setState(() => _inputModality = v),
                labelOf: _modalityValueLabel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _modalityPicker(
                context,
                title: t.outputModality,
                options: _outputOptions,
                selected: _outputModality,
                onChanged: (v) => setState(() => _outputModality = v),
                labelOf: _modalityValueLabel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _modalityPicker(
                context,
                title: t.capabilities,
                options: _capabilityOptions,
                selected: [
                  if (_supportsTools) 'tools',
                  if (_supportsReasoning) 'reasoning',
                ],
                onChanged: (v) => setState(() {
                  _supportsTools = v.contains('tools');
                  _supportsReasoning = v.contains('reasoning');
                }),
                labelOf: _capabilityLabel,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: Text(t.apply),
                    ),
                  ),
                  if (widget.model != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: widget.isDefault ? null : _setDefault,
                        icon: const Icon(Icons.star_outline),
                        label: Text(t.setAsDefaultModel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalityPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
    String Function(String)? labelOf,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              FilterChip(
                label: Text(labelOf?.call(o) ?? o),
                selected: selected.contains(o),
                visualDensity: VisualDensity.compact,
                onSelected: (sel) {
                  final next = [...selected];
                  if (sel) {
                    if (!next.contains(o)) next.add(o);
                  } else {
                    next.remove(o);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }

  /// 单选类型选择器（与多选 picker 同风格，使用 ChoiceChip）
  Widget _typePicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
    String Function(String)? labelOf,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(labelOf?.call(o) ?? o),
                selected: selected == o,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onChanged(o),
              ),
          ],
        ),
      ],
    );
  }
}

// ── 模型选项标签（i18n）───────────────────────

String _modelTypeLabel(String v) => modelTypeLabel(v);

String _modalityValueLabel(String v) => modalityValueLabel(v);

String _capabilityLabel(String v) => capabilityLabel(v);

/// 拉取模型导入对话框：全部导入 / 可选导入。返回用户选择导入的模型 ID；取消返回 null。
Future<List<String>?> _showModelImportDialog(
  BuildContext context,
  List<String> ids,
) async {
  var importAll = true;
  final selected = <String>{};
  return await showDialog<List<String>>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => ContentDialog(
        title: '${t.fetchModels} (${ids.length})',
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t.importAll),
                value: importAll,
                onChanged: (v) => setDialogState(() {
                  importAll = v ?? true;
                  if (importAll) selected.clear();
                }),
              ),
              if (!importAll)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final id in ids)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: selected.contains(id),
                          onChanged: (v) => setDialogState(() {
                            if (v == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogCtx,
              importAll ? ids : ids.where(selected.contains).toList(),
            ),
            child: Text(importAll ? t.importAll : t.importSelected),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// 助手档案（AssistantProfile）
// ─────────────────────────────────────────────

class _AssistantProfileSection extends StatefulWidget {
  const _AssistantProfileSection();

  @override
  State<_AssistantProfileSection> createState() =>
      _AssistantProfileSectionState();
}

class _AssistantProfileSectionState extends State<_AssistantProfileSection> {
  @override
  void initState() {
    super.initState();
    _ensureInit();
  }

  Future<void> _ensureInit() async {
    final store = AssistantProfileStore.instance;
    if (!store.isInitialized) {
      await store.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AssistantProfileStore.instance;
    return _SettingCard(
      children: [
        _SettingPartTitle(
          title: t.assistantProfiles,
          icon: Icons.badge_outlined,
          trailing: IconButton(
            icon: const Icon(Icons.add),
            tooltip: t.newProfile,
            onPressed: () => showPopUpWidget(
              App.rootContext,
              const _AssistantProfileEditor(),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            if (store.profiles.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(t.noProfilesYet, style: ts.s12),
              );
            }
            return Column(
              children: [
                for (final p in store.profiles)
                  _AssistantProfileTile(profile: p),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AssistantProfileTile extends StatelessWidget {
  const _AssistantProfileTile({required this.profile});

  final AssistantProfile profile;

  Future<void> _copy() async {
    await AssistantProfileStore.instance.copy(profile.id);
    App.rootContext.showMessage(message: t.profileSaved);
  }

  Future<void> _export() async {
    final json = AssistantProfileStore.instance.exportJson(profile.id);
    if (json.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: json));
    App.rootContext.showMessage(message: t.profileExported);
  }

  Future<void> _import() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text;
    if (text == null || text.isEmpty) {
      App.rootContext.showMessage(
        message: t.profileImportFailed,
        level: LogLevel.warning,
      );
      return;
    }
    final imported = await AssistantProfileStore.instance.importJson(text);
    App.rootContext.showMessage(
      message: imported == null ? t.profileImportFailed : t.profileSaved,
      level: imported == null ? LogLevel.warning : LogLevel.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = AssistantProfileStore.instance;
    final isActive = store.activeId == profile.id;
    final toolCount = profile.enabledSkillIds.isEmpty
        ? SkillRegistry.instance.all.length
        : profile.enabledSkillIds.length;
    final persona = profile.persona.trim();
    // 选中态用整张卡片高亮（不再单独画单选圆圈）
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isActive
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: AssistantAvatar(icon: profile.icon, size: 40),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  profile.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 6),
                Text(
                  t.defaultAssistant,
                  style: TextStyle(fontSize: 11, color: scheme.primary),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (persona.isNotEmpty)
                Text(
                  persona,
                  style: TextStyle(color: scheme.outline, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                '$toolCount ${t.profileLocalTools}',
                style: TextStyle(color: scheme.primary, fontSize: 11),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                tooltip: t.more,
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  switch (v) {
                    case 'copy':
                      _copy();
                    case 'export':
                      _export();
                    case 'import':
                      _import();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'copy', child: Text(t.profileCopy)),
                  PopupMenuItem(value: 'export', child: Text(t.profileExport)),
                  PopupMenuItem(value: 'import', child: Text(t.profileImport)),
                ],
              ),
              // 点箭头设为默认（选中）
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: t.defaultAssistant,
                icon: Icon(
                  isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: isActive ? scheme.primary : scheme.outlineVariant,
                ),
                onPressed: () => store.setActive(profile.id),
              ),
            ],
          ),
          onTap: () => showPopUpWidget(
            App.rootContext,
            _AssistantProfileEditor(profile: profile),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 助手档案 编辑弹窗
// ─────────────────────────────────────────────

/// 公共入口：从聊天页等外部打开助手档案编辑弹窗
void showAssistantProfileEditor({AssistantProfile? profile}) {
  showPopUpWidget(App.rootContext, _AssistantProfileEditor(profile: profile));
}

// ─────────────────────────────────────────────
// 辅助任务模型 单行
// ─────────────────────────────────────────────
class _AuxTaskTile extends StatefulWidget {
  const _AuxTaskTile({
    required this.taskKey,
    required this.icon,
    required this.title,
  });

  final String taskKey;
  final IconData icon;
  final String title;

  @override
  State<_AuxTaskTile> createState() => _AuxTaskTileState();
}

class _AuxTaskTileState extends State<_AuxTaskTile> {
  String _provider = '';
  String? _model;
  double? _temperature;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = AiDatabase.instance.aiAuxSettingsDao;
    final provider = await dao.get('${widget.taskKey}Provider');
    final model = await dao.get('${widget.taskKey}Model');
    final temp = await dao.get('${widget.taskKey}Temperature');
    if (mounted) {
      setState(() {
        _provider = provider ?? '';
        _model = model;
        _temperature = temp == null ? null : double.tryParse(temp);
        _loaded = true;
      });
    }
  }

  String get _summary {
    if (!_loaded) return '...';
    if (_provider.isEmpty) return t.auxFollowSession;
    final name =
        OpenAiProviderRegistry.allProviders[_provider]?.name ?? _provider;
    final m = _model;
    final base = m == null || m.isEmpty ? name : '$name · $m';
    final temp = _temperature;
    return temp == null ? base : '$base · temp ${temp.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(widget.icon),
      title: Text(widget.title),
      subtitle: Text(_summary, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_right, size: 20),
      onTap: () async {
        await showPopUpWidget(
          App.rootContext,
          _AuxModelEditor(
            taskKey: widget.taskKey,
            title: widget.title,
            provider: _provider,
            model: _model,
            temperature: _temperature,
          ),
        );
        await _load();
      },
    );
  }
}

// ─────────────────────────────────────────────
// 辅助任务模型 编辑弹窗
// ─────────────────────────────────────────────

class _AuxModelEditor extends StatefulWidget {
  const _AuxModelEditor({
    required this.taskKey,
    required this.title,
    required this.provider,
    this.model,
    this.temperature,
  });

  final String taskKey;
  final String title;
  final String provider;
  final String? model;
  final double? temperature;

  @override
  State<_AuxModelEditor> createState() => _AuxModelEditorState();
}

class _AuxModelEditorState extends State<_AuxModelEditor> {
  late String _provider = widget.provider;
  String? _selectedModelId;
  List<AiModel> _models = [];
  late final _tempCtrl = TextEditingController(
    text: widget.temperature?.toString() ?? '',
  );

  @override
  void initState() {
    super.initState();
    _selectedModelId = widget.model;
    if (_provider.isNotEmpty) _loadModels();
  }

  @override
  void dispose() {
    _tempCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    if (_provider.isEmpty) {
      if (mounted) setState(() => _models = []);
      return;
    }
    final models = await (AiDatabase.instance.select(
      AiDatabase.instance.aiModels,
    )..where((t) => t.provider.equals(_provider))).get();

    if (models.isEmpty) {
      // 如果没有模型，插入默认模型
      final defaultModel =
          OpenAiProviderRegistry.allProviders[_provider]?.defaultModel;
      if (defaultModel != null) {
        await AiDatabase.instance.aiModelDao.upsertModels([
          AiModelsCompanion.insert(
            provider: _provider,
            modelId: defaultModel,
            label: defaultModel,
          ),
        ]);
      }
      final refreshed = await (AiDatabase.instance.select(
        AiDatabase.instance.aiModels,
      )..where((t) => t.provider.equals(_provider))).get();
      if (mounted) setState(() => _models = refreshed);
    } else {
      if (mounted) setState(() => _models = models);
    }
  }

  Future<void> _deleteModel(AiModel model) async {
    await AiDatabase.instance.aiModelDao.deleteModel(_provider, model.modelId);
    if (_selectedModelId == model.modelId) {
      _selectedModelId = _models.isNotEmpty ? _models.first.modelId : null;
    }
    await _loadModels();
  }

  Future<void> _save() async {
    final dao = AiDatabase.instance.aiAuxSettingsDao;
    await dao.set(
      '${widget.taskKey}Provider',
      _provider.isEmpty ? null : _provider,
    );
    await dao.set(
      '${widget.taskKey}Model',
      _provider.isEmpty ? null : _selectedModelId,
    );
    final temp = double.tryParse(_tempCtrl.text.trim());
    await dao.set('${widget.taskKey}Temperature', temp?.toString());
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop(context);
    }
  }

  Widget _providerChip(String key, String name, IconData icon) {
    final selected = _provider == key;
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(name),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        if (selected) return;
        setState(() {
          _provider = key;
          _selectedModelId = null;
        });
        if (key.isNotEmpty) _loadModels();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final providers = OpenAiProviderRegistry.allProviders.entries.toList();

    return PopUpWidgetScaffold(
      title: widget.title,
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    child: _SettingCard(
                      children: [
                        _SettingPartTitle(
                          title: t.auxProviderSelection,
                          icon: Icons.cloud_outlined,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _providerChip(
                                '',
                                t.auxFollowSession,
                                Icons.sync_alt,
                              ),
                              for (final e in providers)
                                _providerChip(
                                  e.key,
                                  e.value.name,
                                  e.value.isCustom
                                      ? Icons.extension_outlined
                                      : Icons.cloud_outlined,
                                ),
                            ],
                          ),
                        ),
                        const Divider(indent: 16, endIndent: 16),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextFormField(
                            controller: _tempCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: t.auxTemperature,
                              helperText: t.valueRange,
                              prefixIcon: const Icon(
                                Icons.thermostat_outlined,
                                size: 20,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final d = double.tryParse(v.trim());
                              if (d == null || d < 0 || d > 1) {
                                return t.valueRange;
                              }
                              return null;
                            },
                          ),
                        ),
                        if (_provider.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              t.auxFollowSessionHint,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface
                                    .toOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          _ModelListSection(
                            sourceKey: _provider,
                            models: _models,
                            selectedModelId: _selectedModelId,
                            onSelected: (id) =>
                                setState(() => _selectedModelId = id),
                            onDelete: _deleteModel,
                            onChanged: _loadModels,
                          ),
                      ],
                    ),
                  ),
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
    );
  }
}

// ─────────────────────────────────────────────
// 技能 导入辅助
// ─────────────────────────────────────────────

class _ParsedSkillMd {
  const _ParsedSkillMd({
    required this.name,
    required this.description,
    required this.body,
  });

  final String name;
  final String? description;
  final String body;
}

/// 解析 Claude Code 风格的 SKILL.md（YAML frontmatter + Markdown 正文）
_ParsedSkillMd? _parseSkillMarkdown(String content, String fileName) {
  final trimmed = content.replaceFirst(RegExp(r'^\uFEFF'), '').trimLeft();
  var name = fileName.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
  String? description;
  var body = trimmed;

  final frontmatter = RegExp(
    r'^---\s*\n(.*?)\n---\s*\n?(.*)$',
    dotAll: true,
  ).firstMatch(trimmed);
  if (frontmatter != null) {
    try {
      final parsed = loadYaml(frontmatter.group(1)!);
      if (parsed is Map) {
        final rawName = parsed['name'];
        if (rawName is String && rawName.trim().isNotEmpty) {
          name = rawName.trim();
        }
        final rawDesc = parsed['description'];
        if (rawDesc is String && rawDesc.trim().isNotEmpty) {
          description = rawDesc.trim();
        }
        body = frontmatter.group(2) ?? '';
      }
    } catch (_) {
      // 无效 frontmatter 时退化为整个文件内容
    }
  }

  if (name.trim().isEmpty || body.trim().isEmpty) return null;
  return _ParsedSkillMd(
    name: name.trim(),
    description: description,
    body: body.trim(),
  );
}

String _slugifySkillKey(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

// ─────────────────────────────────────────────
// 技能 编辑弹窗
// ─────────────────────────────────────────────

class _SkillEditor extends StatefulWidget {
  const _SkillEditor({this.skill});

  final AiSkillEntry? skill;

  @override
  State<_SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<_SkillEditor> {
  final _formKey = GlobalKey<FormState>();

  late final _nameCtrl = TextEditingController(text: widget.skill?.name ?? '');
  late final _promptCtrl = TextEditingController(
    text: widget.skill?.systemPrompt ?? '',
  );
  bool _showPromptPreview = false;

  bool get _isNew => widget.skill == null;
  bool get _isBuiltin => widget.skill?.isBuiltin ?? false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<String> _deriveKey() async {
    if (!_isNew) return widget.skill!.key;
    final base = _slugifySkillKey(_nameCtrl.text);
    if (base.isEmpty) {
      return 'skill_${DateTime.now().millisecondsSinceEpoch}';
    }
    var key = base;
    var seq = 0;
    while (AiSkillStore.instance.find(key) != null) {
      key = '${base}_${++seq}';
    }
    return key;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final key = await _deriveKey();
    await AiSkillStore.instance.upsert(
      AiSkillEntry(
        key: key,
        name: _nameCtrl.text.trim(),
        description: widget.skill?.description ?? '',
        systemPrompt: _promptCtrl.text.trim(),
        isBuiltin: _isBuiltin,
        isEnabled: widget.skill?.isEnabled ?? true,
        createdAt:
            widget.skill?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop();
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.delete,
        content: Text(
          '${t.areYouSureYouWantToDeleteGeneric} "${widget.skill!.name}"?',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AiSkillStore.instance.remove(widget.skill!.key);
      if (mounted) App.rootContext.pop();
    }
  }

  Widget _buildField(
    IconData icon,
    String label,
    TextEditingController ctrl, {
    bool enabled = true,
    bool multiline = false,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        enabled: enabled,
        maxLines: multiline ? 10 : 1,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          hintText: hintText,
          alignLabelWithHint: multiline,
          border: const OutlineInputBorder(),
        ),
        validator: (v) => (v == null || v.isEmpty) ? t.required : null,
      ),
    );
  }

  Widget _buildPromptField() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${t.systemPrompt} · ${t.skillMarkdownHint}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _showPromptPreview
                      ? Icons.edit_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                tooltip: _showPromptPreview ? t.edit : t.preview,
                onPressed: () =>
                    setState(() => _showPromptPreview = !_showPromptPreview),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_showPromptPreview)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _promptCtrl.text.trim().isEmpty
                  ? Text(
                      t.noSystemPromptUsed,
                      style: TextStyle(color: theme.colorScheme.outline),
                    )
                  : CustomMarkdownWidget(data: _promptCtrl.text),
            )
          else
            TextFormField(
              controller: _promptCtrl,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: t.systemPrompt,
                prefixIcon: const Icon(Icons.auto_awesome_outlined, size: 20),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.isEmpty) ? t.required : null,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopUpWidgetScaffold(
      title: _isNew ? t.newSkill : widget.skill!.name,
      tailing: [
        if (!_isNew && !_isBuiltin)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: scheme.error,
            onPressed: _delete,
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
                      _buildField(Icons.badge_outlined, t.skillName, _nameCtrl),
                      _buildPromptField(),
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

/// 全局上下文预算（字符）：所有对话 / 故事共用的默认值
class _GlobalContextBudgetCard extends StatefulWidget {
  const _GlobalContextBudgetCard();

  @override
  State<_GlobalContextBudgetCard> createState() =>
      _GlobalContextBudgetCardState();
}

class _GlobalContextBudgetCardState extends State<_GlobalContextBudgetCard> {
  Future<void> _openEditor() async {
    final ctrl = TextEditingController(
      text: aiGlobalContextBudgetChars.toString(),
    );
    final value = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.toOpacity(0.36),
      builder: (ctx) => ContentDialog(
        title: t.aiContextBudget,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.aiContextBudgetHint,
              style: TextStyle(
                fontSize: 12,
                color: ctx.colorScheme.onSurface.toOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.profileMemoryContextBudget,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text(t.apply),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null && value >= 0) {
      aiGlobalContextBudgetChars = value;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      children: [
        _SettingPartTitle(
          title: t.aiContextBudget,
          icon: Icons.data_usage_outlined,
        ),
        _CallbackSetting(
          title: t.profileMemoryContextBudget,
          subtitle: '$aiGlobalContextBudgetChars',
          actionTitle: t.set,
          callback: _openEditor,
        ),
      ],
    );
  }
}
