part of 'settings_page.dart';

class AiSettings extends StatefulWidget {
  const AiSettings({super.key});

  @override
  State<AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<AiSettings> {
  late List<(String, String, String, String)> _providers;

  @override
  void initState() {
    super.initState();
    _providers = _loadProviders();
    OpenAiProviderRegistry.refreshCustomProviders().then((_) {
      if (mounted) setState(() => _providers = _loadProviders());
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<(String, String, String, String)> _loadProviders() =>
      OpenAiProviderRegistry.allProviders.entries
          .where((e) => !OpenAiProviderRegistry.isCustomSource(e.key))
          .map(
            (e) => (e.key, e.value.name, e.value.defaultModel, e.value.baseUrl),
          )
          .toList();

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.aiSettings)),

        // ── API Key 配置 ──────────────────────────
        _BuildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(
                title: t.aiServiceConfig,
                icon: Icons.key_outlined,
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: t.newCustomProvider,
                  onPressed: () => showPopUpWidget(
                    App.rootContext,
                    const _CustomProviderEditor(),
                  ),
                ),
              ),
              for (final (source, name, defaultModel, _) in _providers)
                _ApiKeyTileWidget(
                  source: source,
                  name: name,
                  defaultModel: defaultModel,
                  onSaved: () => setState(() {}),
                ),
              StreamBuilder<List<AiCustomProvider>>(
                stream: AiDatabase.instance.aiCustomProviderDao.watchAll(),
                builder: (context, snapshot) {
                  final providers = snapshot.data ?? [];
                  if (providers.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: providers
                        .map((p) => _CustomProviderTile(provider: p))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),

        // ── 助手档案（助手管理）───────────────────
        _BuildSectionPadding(_AssistantProfileSection()),

        // ── 扩展管理设置 入口 ──────────────────────
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
                onTap: () =>
                    App.rootContext.to(() => const ExtensionSettingsPage()),
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
    if (_row == null || _row!.apiKey.isEmpty) return t.notConfigured;
    return _row!.isEnabled ? t.enabled : t.disabled;
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
// 余额查询配置（URL + 结果字段路径 + 测试查询）
// ─────────────────────────────────────────────

class _BalanceConfigFields extends StatefulWidget {
  const _BalanceConfigFields({
    required this.urlCtrl,
    required this.keyCtrl,
    required this.onQuery,
    required this.baseUrl,
  });

  final TextEditingController urlCtrl;
  final TextEditingController keyCtrl;
  final Future<Res<String>> Function() onQuery;

  /// 服务商基础地址（用于展示生效的完整查询地址）
  final String baseUrl;

  @override
  State<_BalanceConfigFields> createState() => _BalanceConfigFieldsState();
}

class _BalanceConfigFieldsState extends State<_BalanceConfigFields> {
  bool _loading = false;

  Future<void> _query() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await widget.onQuery();
      if (!mounted) return;
      if (res.success) {
        await ContentDialog.show(
          context: context,
          title: t.balance,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(res.data, style: ts.s18)),
            ],
          ),
        );
      } else {
        App.rootContext.showMessage(
          message: res.errorMessage == kBalanceQueryUnsupported
              ? t.balanceQueryUnsupported
              : (res.errorMessage ?? t.balanceQueryUnsupported),
          level: LogLevel.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 生效的余额查询完整地址（baseUrl + 相对路径，或绝对 URL）
  String _effectiveUrl() {
    final base = widget.baseUrl;
    final path = widget.urlCtrl.text.trim();
    if (path.isEmpty) return base;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return base.endsWith('/') ? '$base${path.substring(1)}' : '$base$path';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 20),
            const SizedBox(width: 8),
            Text(
              t.balanceQueryConfig,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _loading ? null : _query,
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: PolygonRefreshIndicator(),
                    )
                  : const Icon(Icons.bolt, size: 18),
              label: Text(t.queryBalance),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: widget.urlCtrl,
          decoration: InputDecoration(
            labelText: t.balanceQueryUrl,
            hintText: t.balanceQueryUrlHint,
            prefixIcon: const Icon(Icons.link, size: 20),
            border: const OutlineInputBorder(),
            helperText: widget.urlCtrl.text.trim().isNotEmpty
                ? '${t.effectiveAddress}: ${_effectiveUrl()}'
                : t.optionalField,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.keyCtrl,
          decoration: InputDecoration(
            labelText: t.balanceKeyPath,
            hintText: t.balanceKeyPathHint,
            prefixIcon: const Icon(Icons.manage_search, size: 20),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
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
  late final _urlCtrl = TextEditingController(
    text:
        widget.row?.baseUrl ??
        ((OpenAiProviderRegistry.allProviders[widget.source]?.isCustom ?? false)
            ? ''
            : (OpenAiProviderRegistry.allProviders[widget.source]?.baseUrl ??
                  '')),
  );
  late final _balanceUrlCtrl = TextEditingController(
    text:
        widget.row?.balanceUrl ??
        balanceDefaultConfig(widget.source)?.path ??
        '',
  );
  late final _balanceKeyCtrl = TextEditingController(
    text:
        widget.row?.balanceKey ??
        balanceDefaultConfig(widget.source)?.key ??
        '',
  );
  late final _modelsUrlCtrl = TextEditingController(
    text: widget.row?.modelsUrl ?? '',
  );
  late String _apiFormat = widget.row?.apiFormat ?? 'openai';
  bool _obscure = true;

  String get _family =>
      _apiFormat == 'openai_responses' ? 'openai' : _apiFormat;

  bool get _responses => _apiFormat == 'openai_responses';

  /// 内置服务商的默认基础地址（用于展示）
  String get _defaultBaseUrl =>
      OpenAiProviderRegistry.allProviders[widget.source]?.baseUrl ?? '';

  /// 当前生效的模型列表接口地址（不含自动附加的 ?key=）
  String get _modelsEndpointDisplay {
    final e = _modelsEndpoint;
    final idx = e.indexOf('?key=');
    return idx > 0 ? e.substring(0, idx) : e;
  }

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
    _balanceUrlCtrl.dispose();
    _balanceKeyCtrl.dispose();
    _modelsUrlCtrl.dispose();
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
    // 启用与否由是否填写 API Key 决定
    final enabled = _keyCtrl.text.trim().isNotEmpty;
    await AiDatabase.instance.aiApiKeyDao.upsert(
      AiApiKeysCompanion.insert(
        provider: widget.source,
        apiKey: _keyCtrl.text.trim(),
        model: Value(_selectedModelId),
        baseUrl: Value(
          _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
        ),
        balanceUrl: Value(
          _balanceUrlCtrl.text.trim().isEmpty
              ? null
              : _balanceUrlCtrl.text.trim(),
        ),
        balanceKey: Value(
          _balanceKeyCtrl.text.trim().isEmpty
              ? null
              : _balanceKeyCtrl.text.trim(),
        ),
        apiFormat: Value(_apiFormat),
        modelsUrl: Value(
          _modelsUrlCtrl.text.trim().isEmpty
              ? null
              : _modelsUrlCtrl.text.trim(),
        ),
        isEnabled: Value(enabled),
      ),
    );
    await OpenAiProviderRegistry.refreshKeyFormats();
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop(context);
    }
  }

  /// 模型列表接口地址（内置服务商：自定义或默认拼接）
  String get _modelsEndpoint {
    final base = _urlCtrl.text.trim().isNotEmpty
        ? _urlCtrl.text.trim()
        : (OpenAiProviderRegistry.allProviders[widget.source]?.baseUrl ?? '');
    if (base.isEmpty) return '';
    if (_modelsUrlCtrl.text.trim().isNotEmpty) {
      return _modelsUrlCtrl.text.trim();
    }
    return switch (_apiFormat) {
      'claude' => '$base/v1/models',
      // key 只走 x-goog-api-key 请求头（_probeHeaders），不放进 URL，
      // 避免 key 随 URL 泄漏到访问日志/代理
      'gemini' => '$base/models',
      _ => '$base/models',
    };
  }

  Map<String, String> get _probeHeaders {
    final key = _keyCtrl.text.trim();
    return switch (_apiFormat) {
      'claude' => {'x-api-key': key, 'anthropic-version': '2023-06-01'},
      'gemini' => {'x-goog-api-key': key},
      _ => {'Authorization': 'Bearer $key'},
    };
  }

  /// 测试服务商是否连通
  Future<void> _testConnection() async {
    final url = _modelsEndpoint;
    if (url.isEmpty || _keyCtrl.text.trim().isEmpty) {
      App.rootContext.showMessage(message: t.required, level: LogLevel.warning);
      return;
    }
    try {
      final response = await AppDio().request(
        url,
        options: Options(
          method: 'GET',
          headers: _probeHeaders,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      App.rootContext.showMessage(
        message: response.statusCode == 200
            ? t.connectionOk
            : t.connectionFailed,
        level: response.statusCode == 200 ? LogLevel.info : LogLevel.warning,
      );
    } catch (e) {
      App.rootContext.showMessage(
        message: '$t.connectionFailed: $e',
        level: LogLevel.warning,
      );
    }
  }

  /// 拉取可用模型并写入模型库
  Future<void> _fetchModels() async {
    final url = _modelsEndpoint;
    if (url.isEmpty || _keyCtrl.text.trim().isEmpty) {
      App.rootContext.showMessage(message: t.required, level: LogLevel.warning);
      return;
    }
    try {
      final response = await AppDio().request(
        url,
        options: Options(
          method: 'GET',
          headers: _probeHeaders,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final json = response.data;
      if (json is! Map) {
        App.rootContext.showMessage(
          message: t.noModelsReturned,
          level: LogLevel.warning,
        );
        return;
      }
      final items = json['data'] ?? json['models'];
      final ids = <String>[];
      if (items is List) {
        for (final item in items.whereType<Map>()) {
          var id = item['id']?.toString() ?? '';
          if (id.isEmpty) {
            id = (item['name']?.toString() ?? '').replaceFirst('models/', '');
          }
          if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
        }
      }
      if (ids.isEmpty) {
        App.rootContext.showMessage(
          message: t.noModelsReturned,
          level: LogLevel.warning,
        );
        return;
      }
      await _showImportDialog(ids);
    } catch (e) {
      App.rootContext.showMessage(
        message: '$t.connectionFailed: $e',
        level: LogLevel.warning,
      );
    }
  }

  /// 拉取结果导入对话框：全部导入 / 可选导入
  Future<void> _showImportDialog(List<String> ids) async {
    final picked = await _showModelImportDialog(context, ids);
    if (picked == null || picked.isEmpty) return;
    await _importModels(picked);
  }

  /// 自动判定模型类型/模态/能力后批量导入
  Future<void> _importModels(List<String> ids) async {
    final companions = <AiModelsCompanion>[];
    for (final id in ids) {
      final s = _autoModelSettings(id, _apiFormat);
      companions.add(
        AiModelsCompanion.insert(
          provider: widget.source,
          modelId: id,
          label: id,
          modelType: Value(s.type),
          inputModality: Value(s.input),
          outputModality: Value(s.output),
          supportsVision: Value(s.vision),
          supportsTools: Value(s.tools),
          supportsReasoning: Value(s.reasoning),
        ),
      );
    }
    await AiDatabase.instance.aiModelDao.upsertModels(companions);
    await _loadModels();
    App.rootContext.showMessage(
      message: '${t.connectionOk} · ${ids.length}',
      level: LogLevel.info,
    );
  }

  Future<Res<String>> _queryBalanceNow() => queryBalanceByUrl(
    baseUrl: _urlCtrl.text.trim().isNotEmpty
        ? _urlCtrl.text.trim()
        : (OpenAiProviderRegistry.allProviders[widget.source]?.baseUrl ?? ''),
    apiKey: _keyCtrl.text.trim(),
    balanceUrl: _balanceUrlCtrl.text.trim(),
    balanceKey: _balanceKeyCtrl.text.trim(),
  );

  Future<void> _delete() async {
    await showConfirmDialog(
      context: context,
      title: t.delete,
      content: '${t.confirmDeleteAiProvider}\n${widget.name}',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () async {
        await AiDatabase.instance.aiApiKeyDao.deleteByProvider(widget.source);
        if (mounted) App.rootContext.pop(context);
      },
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
        child: DefaultTabController(
          length: 2,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    // ── TabBar：主设置 / 模型设置 ─────────────
                    TabBar(
                      tabAlignment: TabAlignment.start,
                      isScrollable: true,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          text: t.mainSettings,
                        ),
                        Tab(
                          icon: const Icon(Icons.model_training, size: 18),
                          text: t.modelSettings,
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [_mainSettingsBody(), _modelSettingsBody()],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 保存按钮 ─────────────────────────────
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

  /// 主设置 Tab：API Key / Base URL / 接口格式 / 模型接口 / 余额
  Widget _mainSettingsBody() {
    final scheme = Theme.of(context).colorScheme;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingPartTitle(
              title: t.apiConfiguration,
              icon: Icons.key_outlined,
            ),

            // ── API Key ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextFormField(
                controller: _keyCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: t.apiKey,
                  prefixIcon: const Icon(Icons.key, size: 20),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
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
                  labelText: t.baseUrl,
                  helperText:
                      _defaultBaseUrl.isNotEmpty && _urlCtrl.text.trim().isEmpty
                      ? t.defaultValue(v: _defaultBaseUrl)
                      : t.optionalField,
                  prefixIcon: const Icon(Icons.home_filled, size: 20),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),

            // ── 接口格式（Tab 选择 + OpenAI 端点子选项）──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.apiFormat,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'openai',
                        label: Text('OpenAI'),
                        icon: Icon(Icons.chat_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: 'gemini',
                        label: Text('Gemini'),
                        icon: Icon(Icons.rocket_launch_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: 'claude',
                        label: Text('Claude'),
                        icon: Icon(Icons.bubble_chart_outlined, size: 16),
                      ),
                    ],
                    selected: {_family},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) {
                      setState(() {
                        _apiFormat = s.first == 'openai'
                            ? (_responses ? 'openai_responses' : 'openai')
                            : s.first;
                      });
                    },
                  ),
                  if (_family == 'openai') ...[
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'chat',
                          label: Text(t.endpointChatCompletions),
                          icon: const Icon(Icons.chat_outlined, size: 14),
                        ),
                        ButtonSegment(
                          value: 'responses',
                          label: Text(t.endpointResponses),
                          icon: const Icon(Icons.schema_outlined, size: 14),
                        ),
                      ],
                      selected: {_responses ? 'responses' : 'chat'},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) {
                        setState(() {
                          _apiFormat = s.first == 'responses'
                              ? 'openai_responses'
                              : 'openai';
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ── 查询模型接口 + 拉取/测试 ─────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _modelsUrlCtrl,
                      decoration: InputDecoration(
                        labelText: t.modelsUrl,
                        helperText:
                            _modelsUrlCtrl.text.trim().isEmpty &&
                                _modelsEndpointDisplay.isNotEmpty
                            ? t.defaultValue(v: _modelsEndpointDisplay)
                            : t.optionalField,
                        prefixIcon: const Icon(Icons.dns_outlined, size: 20),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.cloud_download_outlined),
                    tooltip: t.fetchModels,
                    onPressed: _fetchModels,
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.wifi_tethering),
                    tooltip: t.testConnection,
                    onPressed: _testConnection,
                  ),
                ],
              ),
            ),

            // ── 启用开关（由是否填写 API Key 决定，无需手动开关）──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '${t.apiConfiguration} · ${t.enabledByApiKey}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),

            const Divider(indent: 16, endIndent: 16),

            // ── 余额查询 ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _BalanceConfigFields(
                urlCtrl: _balanceUrlCtrl,
                keyCtrl: _balanceKeyCtrl,
                onQuery: _queryBalanceNow,
                baseUrl: _defaultBaseUrl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 模型设置 Tab：模型卡片列表
  Widget _modelSettingsBody() {
    return _ModelListSection(
      sourceKey: widget.source,
      models: _models,
      selectedModelId: _selectedModelId,
      onSelected: (id) => setState(() => _selectedModelId = id),
      onDelete: _deleteModel,
      onChanged: _loadModels,
      scrollable: true,
    );
  }
}

// ─────────────────────────────────────────────
// 模型列表区块（标题 + 添加 + Chip 列表）
// ─────────────────────────────────────────────

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

  /// 已折叠的基名分组
  final Set<String> _collapsed = {};

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
          App.rootContext.showMessage(message: t.saved);
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
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: rows.length,
        itemBuilder: (context, i) => rows[i],
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

    // ── 类型筛选 chips ─────────────────────────
    final types = <String>[];
    for (final m in widget.models) {
      final t = m.modelType.isEmpty ? 'chat' : m.modelType;
      if (!types.contains(t)) types.add(t);
    }
    final filterRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text(t.all),
              selected: _typeFilter == null,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _typeFilter = null),
            ),
            const SizedBox(width: 6),
            for (final type in types) ...[
              ChoiceChip(
                label: Text(_modelTypeLabel(type)),
                selected: _typeFilter == type,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(
                  () => _typeFilter = _typeFilter == type ? null : type,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );

    // ── 按基名分组（同基名不同后缀折叠为一组）──
    final filtered = _typeFilter == null
        ? widget.models
        : widget.models
              .where(
                (m) =>
                    (m.modelType.isEmpty ? 'chat' : m.modelType) == _typeFilter,
              )
              .toList();
    final groups = <String, List<AiModel>>{};
    for (final m in filtered) {
      groups.putIfAbsent(_baseModelName(m.modelId), () => []).add(m);
    }
    final bases = groups.keys.toList()..sort();

    return [
      header,
      filterRow,
      for (final base in bases) ...[
        _groupHeader(base, groups[base]!),
        if (!_collapsed.contains(base))
          for (final m in groups[base]!) _modelCard(m),
      ],
    ];
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

/// 按模型 ID + 接口格式推断模型设置（类型/输入输出模态/能力）
({
  String type,
  String input,
  String output,
  bool vision,
  bool tools,
  bool reasoning,
})
_autoModelSettings(String id, String apiFormat) {
  final lower = id.toLowerCase();
  if (lower.contains('embedding')) {
    return (
      type: 'embedding',
      input: 'text',
      output: 'text',
      vision: false,
      tools: false,
      reasoning: false,
    );
  }
  if (lower.contains('whisper') ||
      lower.contains('audio') ||
      lower.contains('tts') ||
      lower.contains('speech')) {
    return (
      type: 'audio',
      input: 'audio',
      output: 'text',
      vision: false,
      tools: false,
      reasoning: false,
    );
  }
  if (lower.contains('dall') ||
      lower.contains('image') ||
      lower.contains('imagen') ||
      lower.contains('midjourney') ||
      lower.contains('flux') ||
      lower.contains('sora') ||
      lower.contains('video') ||
      lower.contains('generate')) {
    return (
      type: 'image',
      input: 'text',
      output: 'image',
      vision: false,
      tools: false,
      reasoning: false,
    );
  }
  return (
    type: 'chat',
    input: 'text,image',
    output: 'text',
    vision: true,
    tools: true,
    reasoning: apiFormat == 'gemini',
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
    return ListTile(
      leading: Text(profile.icon, style: const TextStyle(fontSize: 24)),
      title: Row(
        children: [
          Flexible(
            child: Text(
              profile.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
          RadioGroup<String?>(
            groupValue: store.activeId,
            onChanged: (id) => store.setActive(id!),
            child: Radio<String?>(value: profile.id),
          ),
          const Icon(Icons.arrow_right, size: 20),
        ],
      ),
      onTap: () => showPopUpWidget(
        App.rootContext,
        _AssistantProfileEditor(profile: profile),
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

class _AssistantProfileEditor extends StatefulWidget {
  const _AssistantProfileEditor({this.profile});

  final AssistantProfile? profile;

  @override
  State<_AssistantProfileEditor> createState() =>
      _AssistantProfileEditorState();
}

class _AssistantProfileEditorState extends State<_AssistantProfileEditor> {
  static const _prefKeys = [
    'concise',
    'useMarkdown',
    'codeFirst',
    'actionable',
  ];

  static List<String> get _tagSuggestions => [
    t.aiTagRational,
    t.aiTagHumorous,
    t.aiTagSarcastic,
    t.aiTagGentle,
    t.aiTagRigorous,
    t.aiTagPassionate,
    t.aiTagCalm,
    t.aiTagCool,
    t.aiTagEnergetic,
    t.aiTagChuuni,
    t.aiTagCunning,
    t.aiTagFriendly,
  ];

  static List<(String, String, String)> get _knownExtensions => [
    ('markdown', t.aiExtMarkdown, t.aiExtMarkdownHint),
    (
      'image_understanding',
      t.aiExtImageUnderstanding,
      t.aiExtImageUnderstandingHint,
    ),
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _iconCtrl;
  late final TextEditingController _personaCtrl;
  late final TextEditingController _toneCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _catchphrasesCtrl;
  late final TextEditingController _examplesCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _knowledgeCtrl;
  late final TextEditingController _fragmentsCtrl;
  late final TextEditingController _temperatureCtrl;
  late final TextEditingController _topPCtrl;
  late final TextEditingController _maxTokensCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _headersCtrl;
  late final TextEditingController _extraBodyCtrl;
  late final TextEditingController _stopCtrl;
  late final TextEditingController _memoryEntryCtrl;
  late final TextEditingController _memoryMaxCtrl;

  late Set<String> _enabledSkillIds;
  late List<String> _skillIds;
  late List<AssistantExtension> _extensions;
  late MemorySettings _memory;
  late List<McpBinding> _mcpServers;
  late Map<String, bool> _behaviorPrefs;
  late ReplyLength _replyLength;
  late bool _useEmoji;
  late bool _useMarkdown;
  late bool _askBack;

  bool get _isNew => widget.profile == null;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _iconCtrl = TextEditingController(text: p?.icon ?? '🤖');
    _personaCtrl = TextEditingController(text: p?.persona ?? '');
    _toneCtrl = TextEditingController(text: p?.tone ?? '');
    _tagsCtrl = TextEditingController(
      text: (p?.personalityTags ?? const []).join('\n'),
    );
    _catchphrasesCtrl = TextEditingController(
      text: (p?.catchphrases ?? const []).join('\n'),
    );
    _examplesCtrl = TextEditingController(
      text: [
        for (final e in (p?.examples ?? const [])) '${e.user} | ${e.assistant}',
      ].join('\n'),
    );
    _promptCtrl = TextEditingController(text: p?.systemPrompt ?? '');
    _knowledgeCtrl = TextEditingController(
      text: (p?.knowledge ?? const []).join('\n'),
    );
    _fragmentsCtrl = TextEditingController(
      text: (p?.promptFragments ?? const []).join('\n'),
    );
    _temperatureCtrl = TextEditingController(
      text: p?.params.temperature?.toString() ?? '',
    );
    _topPCtrl = TextEditingController(text: p?.params.topP?.toString() ?? '');
    _maxTokensCtrl = TextEditingController(
      text: p?.params.maxTokens?.toString() ?? '',
    );
    _baseUrlCtrl = TextEditingController(
      text: p?.request.baseUrlOverride ?? '',
    );
    _apiKeyCtrl = TextEditingController(text: p?.request.apiKeyOverride ?? '');
    _headersCtrl = TextEditingController(
      text: [
        for (final e in (p?.request.customHeaders ?? const {}).entries)
          '${e.key}: ${e.value}',
      ].join('\n'),
    );
    _extraBodyCtrl = TextEditingController(
      text: (p?.request.extraBodyFields ?? const {}).isNotEmpty
          ? const JsonEncoder.withIndent(
              '  ',
            ).convert(p!.request.extraBodyFields)
          : '',
    );
    _stopCtrl = TextEditingController(
      text: (p?.request.stopSequences ?? const []).join('\n'),
    );
    _memoryEntryCtrl = TextEditingController();
    _memoryMaxCtrl = TextEditingController(
      text: (p?.memory.maxEntries ?? 50).toString(),
    );
    _enabledSkillIds = {...?p?.enabledSkillIds};
    _skillIds = [...?p?.skillIds];
    _extensions = [...?p?.extensions];
    _memory = p?.memory ?? const MemorySettings();
    _mcpServers = [...?p?.mcpServers];
    _behaviorPrefs = {
      for (final k in _prefKeys) k: p?.behaviorPrefs[k] == true,
    };
    _replyLength = p?.replyStyle.length ?? ReplyLength.normal;
    _useEmoji = p?.replyStyle.useEmoji ?? false;
    _useMarkdown = p?.replyStyle.useMarkdown ?? true;
    _askBack = p?.replyStyle.askBack ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _personaCtrl.dispose();
    _toneCtrl.dispose();
    _tagsCtrl.dispose();
    _catchphrasesCtrl.dispose();
    _examplesCtrl.dispose();
    _promptCtrl.dispose();
    _knowledgeCtrl.dispose();
    _fragmentsCtrl.dispose();
    _temperatureCtrl.dispose();
    _topPCtrl.dispose();
    _maxTokensCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _headersCtrl.dispose();
    _extraBodyCtrl.dispose();
    _stopCtrl.dispose();
    _memoryEntryCtrl.dispose();
    _memoryMaxCtrl.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController ctrl) => ctrl.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  AssistantProfile _buildProfile() {
    final id =
        widget.profile?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}';
    final allIds = SkillRegistry.instance.all.map((s) => s.id).toSet();
    final skills =
        _enabledSkillIds.isEmpty || setEquals(_enabledSkillIds, allIds)
        ? const <String>{}
        : {..._enabledSkillIds};
    final examples = <ProfileExample>[];
    for (final line in _lines(_examplesCtrl)) {
      final parts = line.split('|');
      if (parts.length >= 2) {
        examples.add(
          ProfileExample(
            user: parts[0].replaceFirst(RegExp(r'^用户\s*[:：]?\s*'), '').trim(),
            assistant: parts[1]
                .replaceFirst(RegExp(r'^助手\s*[:：]?\s*'), '')
                .trim(),
          ),
        );
      }
    }
    return AssistantProfile(
      id: id,
      name: _nameCtrl.text.trim(),
      icon: _iconCtrl.text.trim().isEmpty ? '🤖' : _iconCtrl.text.trim(),
      persona: _personaCtrl.text.trim(),
      tone: _toneCtrl.text.trim(),
      personalityTags: _lines(_tagsCtrl),
      catchphrases: _lines(_catchphrasesCtrl),
      examples: examples,
      replyStyle: ReplyStylePrefs(
        length: _replyLength,
        useEmoji: _useEmoji,
        useMarkdown: _useMarkdown,
        askBack: _askBack,
      ),
      systemPrompt: _promptCtrl.text.trim(),
      knowledge: _lines(_knowledgeCtrl),
      enabledSkillIds: skills,
      skillIds: _skillIds,
      extensions: _extensions,
      memory: MemorySettings(
        enabled: _memory.enabled,
        maxEntries: int.tryParse(_memoryMaxCtrl.text.trim()) ?? 50,
      ),
      request: RequestSettings(
        baseUrlOverride: _baseUrlCtrl.text.trim().isEmpty
            ? null
            : _baseUrlCtrl.text.trim(),
        apiKeyOverride: _apiKeyCtrl.text.trim().isEmpty
            ? null
            : _apiKeyCtrl.text.trim(),
        customHeaders: _parseHeaderLines(_headersCtrl),
        extraBodyFields: _parseJsonObject(_extraBodyCtrl.text),
        stopSequences: _lines(_stopCtrl),
      ),
      mcpServers: _mcpServers,
      params: AssistantParams(
        temperature: double.tryParse(_temperatureCtrl.text.trim()),
        topP: double.tryParse(_topPCtrl.text.trim()),
        maxTokens: int.tryParse(_maxTokensCtrl.text.trim()),
      ),
      behaviorPrefs: {
        for (final e in _behaviorPrefs.entries)
          if (e.value) e.key: true,
      },
      promptFragments: _lines(_fragmentsCtrl),
      isBuiltin: widget.profile?.isBuiltin ?? false,
    );
  }

  /// 解析多行 "Key: Value" 头
  Map<String, String> _parseHeaderLines(TextEditingController ctrl) {
    final result = <String, String>{};
    for (final line in _lines(ctrl)) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) result[key] = value;
    }
    return result;
  }

  /// 解析 JSON 对象；非法或空返回空 Map
  Map<String, dynamic> _parseJsonObject(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const {};
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
    } catch (_) {
      return const {};
    }
  }

  String? _validateRange(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final d = double.tryParse(v.trim());
    if (d == null || d < 0 || d > 1) return t.valueRange;
    return null;
  }

  String? _validatePositiveInt(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0) return t.invalidNumber;
    return null;
  }

  void _toggleSkill(String id, bool selected) {
    setState(() {
      final allIds = SkillRegistry.instance.all.map((s) => s.id).toSet();
      if (selected) {
        _enabledSkillIds.add(id);
      } else if (_enabledSkillIds.isEmpty) {
        _enabledSkillIds = {...allIds}..remove(id);
      } else {
        _enabledSkillIds.remove(id);
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final profile = _buildProfile();
    await AssistantProfileStore.instance.upsert(profile);
    if (mounted) {
      App.rootContext.showMessage(message: t.profileSaved);
      App.rootContext.pop();
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.deleteProfile,
        content: Text(t.confirmDeleteProfile),
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
      await AssistantProfileStore.instance.remove(widget.profile!.id);
      if (mounted) App.rootContext.pop();
    }
  }

  Future<void> _previewPrompt() async {
    final profile = _buildProfile();
    final enabled = SkillRegistry.instance.all
        .where(
          (s) => _enabledSkillIds.isEmpty || _enabledSkillIds.contains(s.id),
        )
        .toList();
    final injections = await PromptInjectionStore.instance.enabledSorted();
    final prompt = buildSystemPrompt(
      profile: profile,
      availableSkills: [for (final s in enabled) s.name],
      injections: injections,
    );
    await ContentDialog.show(
      context: context,
      title: t.previewSystemPrompt,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: SelectableText(
            prompt,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
      ),
    );
  }

  Future<void> _tryChatting() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final profile = _buildProfile();
    await AssistantProfileStore.instance.upsert(profile);
    if (!mounted) return;
    App.rootContext.showMessage(message: t.profileSaved);
    App.rootContext.to(
      () => AiChatPage(fresh: true, initialProfileId: profile.id),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    // ignore: unused_element_parameter
    IconData? icon,
    bool multiline = false,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        maxLines: multiline ? 6 : 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          alignLabelWithHint: multiline,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }

  /// 占位符说明区（与 replaceTemplateVars 共用同一注册表）
  Widget _templateVarHint(
    TextEditingController ctrl, {
    bool insertOnTap = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    void insert(String token) {
      if (!insertOnTap) return;
      final selection = ctrl.selection;
      final start = selection.isValid ? selection.start : ctrl.text.length;
      final end = selection.isValid ? selection.end : ctrl.text.length;
      ctrl.text = ctrl.text
          .replaceRange(start, end, token)
          .replaceAll('$token$token', token);
      ctrl.selection = TextSelection.collapsed(offset: start + token.length);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
              onTap: () => insert(v.token),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${v.token} ${v.label}',
                  style: TextStyle(fontSize: 11, color: scheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabScroll(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      child: child,
    );
  }

  Widget _buildTopFields() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _SettingCard(
        children: [
          _field(
            t.profileName,
            _nameCtrl,
            icon: Icons.badge_outlined,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? t.required : null,
          ),
          _field(
            t.profileIcon,
            _iconCtrl,
            icon: Icons.emoji_emotions_outlined,
            hintText: t.profileIconHint,
          ),
        ],
      ),
    );
  }

  void _toggleTag(String tag) {
    setState(() {
      final current = _lines(_tagsCtrl);
      final next = <String>[...current];
      if (next.contains(tag)) {
        next.remove(tag);
      } else {
        next.add(tag);
      }
      _tagsCtrl.text = next.join('\n');
    });
  }

  Widget _personaSectionTitle(String title, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  static List<(String, String)> get _personaSuggestions => [
    (t.aiPersonaGeneral, t.aiPersonaGeneralDesc),
    (t.aiPersonaEngineer, t.aiPersonaEngineerDesc),
    (t.aiPersonaButler, t.aiPersonaButlerDesc),
    (t.aiPersonaWriter, t.aiPersonaWriterDesc),
    (t.aiPersonaAdvisor, t.aiPersonaAdvisorDesc),
    (t.aiPersonaFriend, t.aiPersonaFriendDesc),
  ];

  static List<String> get _toneSuggestions => [
    t.aiToneFormal,
    t.aiTagHumorous,
    t.aiTagGentle,
    t.aiToneConcise,
    t.aiToneNatural,
    t.aiTagSarcastic,
  ];

  /// 点击选择式字段（readOnly，点击弹出 BottomSheet 选择）
  Widget _pickerField(
    String label,
    TextEditingController ctrl, {
    required VoidCallback onTap,
    bool multiline = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        readOnly: true,
        maxLines: multiline ? 3 : 1,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        validator: validator,
      ),
    );
  }

  Future<void> _pickPersona() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.profilePersona,
        icon: Icons.face_outlined,
        initialSize: 0.55,
        builder: (sheetCtx, sc) => ListView(
          controller: sc,
          shrinkWrap: true,
          children: [
            for (final p in _personaSuggestions)
              ListTile(
                leading: Icon(
                  _personaCtrl.text.trim() == p.$2
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _personaCtrl.text.trim() == p.$2
                      ? Theme.of(sheetCtx).colorScheme.primary
                      : null,
                ),
                title: Text(p.$1),
                subtitle: Text(p.$2, style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, p.$2),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t.custom),
              onTap: () => Navigator.pop(ctx, '__custom__'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (selected == '__custom__') {
      final ctrl = TextEditingController(text: _personaCtrl.text);
      final text = await showDialog<String>(
        context: context,
        builder: (ctx) => ContentDialog(
          title: t.profilePersona,
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 4,
            decoration: InputDecoration(border: const OutlineInputBorder()),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(t.confirm),
            ),
          ],
        ),
      );
      if (text != null && text.isNotEmpty) {
        setState(() => _personaCtrl.text = text);
      }
    } else {
      setState(() => _personaCtrl.text = selected);
    }
  }

  Future<void> _pickTone() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.profileTone,
        icon: Icons.format_quote_outlined,
        initialSize: 0.4,
        builder: (sheetCtx, sc) => ListView(
          controller: sc,
          shrinkWrap: true,
          children: [
            for (final tone in _toneSuggestions)
              ListTile(
                leading: Icon(
                  _toneCtrl.text.trim() == tone
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _toneCtrl.text.trim() == tone
                      ? Theme.of(sheetCtx).colorScheme.primary
                      : null,
                ),
                title: Text(tone),
                onTap: () => Navigator.pop(ctx, tone),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t.custom),
              onTap: () => Navigator.pop(ctx, '__custom__'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (selected == '__custom__') {
      final ctrl = TextEditingController(text: _toneCtrl.text);
      final text = await showDialog<String>(
        context: context,
        builder: (ctx) => ContentDialog(
          title: t.profileTone,
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(border: const OutlineInputBorder()),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(t.confirm),
            ),
          ],
        ),
      );
      if (text != null && text.isNotEmpty) {
        setState(() => _toneCtrl.text = text);
      }
    } else {
      setState(() => _toneCtrl.text = selected);
    }
  }

  Widget _buildPersonaTab() {
    final currentTags = _lines(_tagsCtrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pickerField(
          t.profilePersona,
          _personaCtrl,
          multiline: true,
          onTap: _pickPersona,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? t.profilePersonaRequired : null,
        ),
        _pickerField(
          t.profileTone,
          _toneCtrl,
          multiline: true,
          onTap: _pickTone,
        ),
        _personaSectionTitle(
          t.profilePersonalityTags,
          Icons.interests_outlined,
        ),
        _field(
          t.profilePersonalityTagsHint,
          _tagsCtrl,
          icon: Icons.local_offer_outlined,
          multiline: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tagSuggestions)
                FilterChip(
                  label: Text(tag),
                  selected: currentTags.contains(tag),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _toggleTag(tag),
                ),
            ],
          ),
        ),
        _personaSectionTitle(t.profileCatchphrases, Icons.format_quote),
        _field(
          t.profileCatchphrasesHint,
          _catchphrasesCtrl,
          icon: Icons.chat_bubble_outline,
          multiline: true,
        ),
        _personaSectionTitle(t.profileReplyStyle, Icons.tune),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<ReplyLength>(
            segments: [
              ButtonSegment(
                value: ReplyLength.short,
                label: Text(t.lengthShort),
                icon: Icon(Icons.short_text, size: 18),
              ),
              ButtonSegment(
                value: ReplyLength.normal,
                label: Text(t.lengthMedium),
                icon: Icon(Icons.format_align_left, size: 18),
              ),
              ButtonSegment(
                value: ReplyLength.detailed,
                label: Text(t.detailed),
                icon: Icon(Icons.notes, size: 18),
              ),
            ],
            selected: {_replyLength},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _replyLength = s.first),
          ),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: const Icon(Icons.emoji_emotions_outlined, size: 20),
          title: Text(t.replyUseEmoji),
          value: _useEmoji,
          onChanged: (v) => setState(() => _useEmoji = v ?? false),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: const Icon(Icons.format_align_left, size: 20),
          title: Text(t.replyUseMarkdown),
          value: _useMarkdown,
          onChanged: (v) => setState(() => _useMarkdown = v ?? false),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: const Icon(Icons.help_outline, size: 20),
          title: Text(t.replyAskBack),
          value: _askBack,
          onChanged: (v) => setState(() => _askBack = v ?? false),
        ),
        _personaSectionTitle(t.profileExamples, Icons.forum_outlined),
        _field(
          t.profileExamplesHint,
          _examplesCtrl,
          icon: Icons.record_voice_over_outlined,
          multiline: true,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPromptTab() {
    return Column(
      children: [
        _field(
          t.systemPrompt,
          _promptCtrl,
          icon: Icons.auto_awesome_outlined,
          multiline: true,
        ),
        _templateVarHint(_promptCtrl),
        _field(
          t.profilePromptFragments,
          _fragmentsCtrl,
          icon: Icons.format_list_numbered_outlined,
          multiline: true,
        ),
        _field(
          t.profileKnowledge,
          _knowledgeCtrl,
          icon: Icons.menu_book_outlined,
          multiline: true,
        ),
      ],
    );
  }

  Widget _buildLocalToolsTab() {
    final scheme = Theme.of(context).colorScheme;
    final localTools = SkillRegistry.instance.all;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handyman_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileLocalTools,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.profileLocalToolsHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (localTools.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t.noSkillsAvailable, style: ts.s12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in localTools)
                  FilterChip(
                    avatar: const Icon(Icons.extension, size: 16),
                    label: Text(s.name),
                    selected:
                        _enabledSkillIds.isEmpty ||
                        _enabledSkillIds.contains(s.id),
                    visualDensity: VisualDensity.compact,
                    onSelected: (sel) => _toggleSkill(s.id, sel),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileSkills,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.profileSkillsHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<AiSkill>>(
            stream: AiDatabase.instance.aiSkillDao.watchAll(),
            builder: (context, snapshot) {
              final skills = snapshot.data ?? [];
              if (skills.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t.noSkillsYet, style: ts.s12),
                );
              }
              return Column(
                children: skills.map((s) {
                  final selected = _skillIds.contains(s.key);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: const Icon(Icons.build_outlined, size: 20),
                    title: Text(s.name),
                    subtitle: Text(
                      s.description ?? s.key,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: selected,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        if (!_skillIds.contains(s.key)) _skillIds.add(s.key);
                      } else {
                        _skillIds.remove(s.key);
                      }
                    }),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTab() {
    final scheme = Theme.of(context).colorScheme;
    final prefs = [
      ('concise', t.conciseReplies, Icons.bolt_outlined),
      ('useMarkdown', t.useMarkdownFormatting, Icons.format_align_left),
      ('codeFirst', t.codeFirst, Icons.code),
      ('actionable', t.actionableAdvice, Icons.checklist),
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileParams,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.customParamsHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          _field(
            t.temperature,
            _temperatureCtrl,
            icon: Icons.thermostat_outlined,
            hintText: t.valueRange,
            validator: _validateRange,
          ),
          _field(
            'Top P',
            _topPCtrl,
            icon: Icons.speed_outlined,
            hintText: t.valueRange,
            validator: _validateRange,
          ),
          _field(
            t.tokens,
            _maxTokensCtrl,
            icon: Icons.numbers_outlined,
            hintText: t.customParamsHint,
            validator: _validatePositiveInt,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.checklist_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileBehaviorPrefs,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          for (final (key, label, icon) in prefs)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              secondary: Icon(icon, size: 20),
              title: Text(label),
              value: _behaviorPrefs[key] ?? false,
              onChanged: (v) =>
                  setState(() => _behaviorPrefs[key] = v ?? false),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.http_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileRequest,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.profileRequestSensitiveHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          _field(
            t.profileRequestBaseUrl,
            _baseUrlCtrl,
            icon: Icons.link_outlined,
            hintText: 'https://api.example.com/v1',
          ),
          _field(t.profileRequestApiKey, _apiKeyCtrl, icon: Icons.key_outlined),
          _field(
            t.profileRequestHeaders,
            _headersCtrl,
            icon: Icons.code_outlined,
            hintText: 'Authorization: Bearer xxx',
            multiline: true,
          ),
          _field(
            t.profileRequestExtraBody,
            _extraBodyCtrl,
            icon: Icons.data_object_outlined,
            hintText: '{"temperature": 0.7}',
            multiline: true,
          ),
          _field(
            t.profileRequestStop,
            _stopCtrl,
            icon: Icons.stop_circle_outlined,
            hintText: t.profileRequestStopHint,
            multiline: true,
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionsTab() {
    final scheme = Theme.of(context).colorScheme;
    bool isEnabled(String id) =>
        _extensions.any((e) => e.extensionId == id && e.enabled);
    void toggle(String id, bool v) {
      setState(() {
        final idx = _extensions.indexWhere((e) => e.extensionId == id);
        if (idx >= 0) {
          _extensions[idx] = _extensions[idx].copyWith(enabled: v);
        } else {
          _extensions.add(AssistantExtension(extensionId: id, enabled: v));
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.profileExtensionsHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final (id, label, desc) in _knownExtensions)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              secondary: const Icon(Icons.extension_outlined, size: 20),
              title: Text(label),
              subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
              value: isEnabled(id),
              onChanged: (v) => toggle(id, v ?? false),
            ),
        ],
      ),
    );
  }

  Widget _buildMemoryTab() {
    final scheme = Theme.of(context).colorScheme;
    final profileId =
        widget.profile?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToggleRow(
            t.profileMemoryEnabled,
            Icons.memory_outlined,
            _memory.enabled,
            (v) => setState(() => _memory = _memory.copyWith(enabled: v)),
          ),
          const SizedBox(height: 4),
          Text(
            t.profileMemoryHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          _field(
            t.profileMemoryMaxEntries,
            _memoryMaxCtrl,
            icon: Icons.numbers_outlined,
            validator: _validatePositiveInt,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.history_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.profileMemoryEntries,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await AssistantMemoryStore.instance.clear(profileId);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: Text(t.profileMemoryClear),
              ),
            ],
          ),
          FutureBuilder<List<String>>(
            future: AssistantMemoryStore.instance.entriesFor(profileId),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const <String>[];
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t.profileMemoryEmpty, style: ts.s12),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        '${i + 1}.',
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                      title: Text(
                        entries[i],
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () async {
                          await AssistantMemoryStore.instance.removeAt(
                            profileId,
                            i,
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: _field(
                  t.profileMemoryAdd,
                  _memoryEntryCtrl,
                  icon: Icons.add_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  final text = _memoryEntryCtrl.text.trim();
                  if (text.isEmpty) return;
                  await AssistantMemoryStore.instance.add(profileId, text);
                  _memoryEntryCtrl.clear();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(t.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMcpTab() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.profileMcpHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<AiMcpServer>>(
            stream: AiDatabase.instance.aiMcpServerDao.watchAll(),
            builder: (context, snapshot) {
              final servers = snapshot.data ?? [];
              if (servers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t.noMcpServers, style: ts.s12),
                );
              }
              bool bound(String id) =>
                  _mcpServers.any((m) => m.id == id && m.enabled);
              return Column(
                children: servers.map((s) {
                  final endpoint = s.transport == 'stdio'
                      ? (s.command ?? '')
                      : (s.url ?? '');
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: const Icon(Icons.dns_outlined, size: 20),
                    title: Text(s.name),
                    subtitle: Text(
                      endpoint,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: bound(s.id.toString()),
                    onChanged: (v) => setState(() {
                      final id = s.id.toString();
                      final idx = _mcpServers.indexWhere((m) => m.id == id);
                      if (v == true) {
                        if (idx >= 0) {
                          _mcpServers[idx] = _mcpServers[idx].copyWith(
                            enabled: true,
                          );
                        } else {
                          _mcpServers.add(
                            McpBinding(
                              id: id,
                              name: s.name,
                              serverUrl: endpoint,
                              enabled: true,
                            ),
                          );
                        }
                      } else if (idx >= 0) {
                        _mcpServers[idx] = _mcpServers[idx].copyWith(
                          enabled: false,
                        );
                      }
                    }),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: _isNew
          ? t.newProfile
          : '${t.editAssistantProfile} · ${widget.profile!.name}',
      tailing: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined),
          tooltip: t.previewSystemPrompt,
          onPressed: _previewPrompt,
        ),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: t.tryChatting,
          onPressed: _tryChatting,
        ),
        if (!_isNew && widget.profile!.isPreset == false)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: scheme.error,
            tooltip: t.deleteProfile,
            onPressed: _delete,
          ),
      ],
      body: DefaultTabController(
        length: 7,
        child: Stack(
          children: [
            Positioned.fill(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTopFields(),
                    TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: t.profileTabBasic),
                        Tab(text: t.profileTabPrompt),
                        Tab(text: t.profileTabExtensions),
                        Tab(text: t.profileTabMemory),
                        Tab(text: t.profileTabRequest),
                        Tab(text: t.profileTabMcp),
                        Tab(text: t.profileTabLocalTools),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _tabScroll(_buildPersonaTab()),
                          _tabScroll(_buildPromptTab()),
                          _tabScroll(_buildExtensionsTab()),
                          _tabScroll(_buildMemoryTab()),
                          _tabScroll(_buildRequestTab()),
                          _tabScroll(_buildMcpTab()),
                          _tabScroll(_buildLocalToolsTab()),
                        ],
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
    );
  }
}

// ─────────────────────────────────────────────
// 通用开关行
// ─────────────────────────────────────────────

Widget _buildToggleRow(
  String title,
  IconData icon,
  bool value,
  ValueChanged<bool> onChanged,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(title)),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// 自定义服务商 单行
// ─────────────────────────────────────────────

class _CustomProviderTile extends StatelessWidget {
  const _CustomProviderTile({required this.provider});

  final AiCustomProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        provider.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        provider.baseUrl,
        style: TextStyle(color: context.colorScheme.outline, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            provider.isEnabled ? t.enabled : t.disabled,
            style: TextStyle(
              fontSize: 12,
              color: provider.isEnabled ? Colors.green : Colors.orange,
            ),
          ),
          const Icon(Icons.arrow_right, size: 20),
        ],
      ),
      onTap: () => showPopUpWidget(
        App.rootContext,
        _CustomProviderEditor(provider: provider),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 自定义服务商 编辑弹窗
// ─────────────────────────────────────────────

class _CustomProviderEditor extends StatefulWidget {
  const _CustomProviderEditor({this.provider});

  final AiCustomProvider? provider;

  @override
  State<_CustomProviderEditor> createState() => _CustomProviderEditorState();
}

class _CustomProviderEditorState extends State<_CustomProviderEditor> {
  final _formKey = GlobalKey<FormState>();

  late final _keyCtrl = TextEditingController(
    text: widget.provider?.provider ?? '',
  );
  late final _nameCtrl = TextEditingController(
    text: widget.provider?.name ?? '',
  );
  late final _urlCtrl = TextEditingController(
    text: widget.provider?.baseUrl ?? '',
  );
  late final _apiKeyCtrl = TextEditingController(
    text: widget.provider?.apiKey ?? '',
  );
  late final _balanceUrlCtrl = TextEditingController(
    text: widget.provider?.balanceUrl ?? '',
  );
  late final _balanceKeyCtrl = TextEditingController(
    text: widget.provider?.balanceKey ?? '',
  );
  late final _modelsUrlCtrl = TextEditingController(
    text: widget.provider?.modelsUrl ?? '',
  );
  late final bool _enabled = widget.provider?.isEnabled ?? true;
  late String _apiFormat = widget.provider?.apiFormat ?? 'openai';
  bool _obscure = true;

  /// 接口家族（openai_responses 属于 openai）
  String get _family =>
      _apiFormat == 'openai_responses' ? 'openai' : _apiFormat;

  bool get _responses => _apiFormat == 'openai_responses';
  // 当前选中的默认模型 ID
  String? _selectedModelId;

  // 该服务商（custom_<key>）下的所有模型
  List<AiModel> _models = [];

  String? _loadedSourceKey;

  bool get _isNew => widget.provider == null;

  /// 模型归属的 source key：`custom_<provider key>`
  String get _sourceKey {
    final key = _keyCtrl.text.trim();
    return key.isEmpty ? '' : OpenAiProviderRegistry.customSourceKey(key);
  }

  @override
  void initState() {
    super.initState();
    _selectedModelId = widget.provider?.defaultModel;
    _loadModels();
    // 新建时 key 可编辑，模型归属随 key 变化而重载
    _keyCtrl.addListener(_onKeyChanged);
  }

  void _onKeyChanged() {
    if (_sourceKey != _loadedSourceKey) _loadModels();
  }

  @override
  void dispose() {
    _keyCtrl.removeListener(_onKeyChanged);
    _keyCtrl.dispose();
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _balanceUrlCtrl.dispose();
    _balanceKeyCtrl.dispose();
    _modelsUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    if (_sourceKey.isEmpty) {
      if (mounted) setState(() => _models = []);
      _loadedSourceKey = _sourceKey;
      return;
    }
    final models = await (AiDatabase.instance.select(
      AiDatabase.instance.aiModels,
    )..where((t) => t.provider.equals(_sourceKey))).get();
    if (!mounted) return;
    setState(() {
      _models = models;
      _loadedSourceKey = _sourceKey;
      if (_selectedModelId != null &&
          models.isNotEmpty &&
          !models.any((m) => m.modelId == _selectedModelId)) {
        _selectedModelId = models.first.modelId;
      }
    });
  }

  Future<void> _deleteModel(AiModel model) async {
    await AiDatabase.instance.aiModelDao.deleteModel(_sourceKey, model.modelId);
    if (_selectedModelId == model.modelId) {
      _selectedModelId = _models.isNotEmpty ? _models.first.modelId : null;
    }
    await _loadModels();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final key = _keyCtrl.text.trim();
    final dao = AiDatabase.instance.aiCustomProviderDao;
    if (_isNew && await dao.getByProvider(key) != null) {
      App.rootContext.showMessage(
        message: t.providerKeyExists,
        level: LogLevel.warning,
      );
      return;
    }
    await dao.upsert(
      AiCustomProvidersCompanion.insert(
        provider: key,
        name: _nameCtrl.text.trim(),
        baseUrl: _urlCtrl.text.trim(),
        defaultModel: Value(_selectedModelId),
        apiKey: Value(
          _apiKeyCtrl.text.trim().isEmpty ? null : _apiKeyCtrl.text.trim(),
        ),
        apiFormat: Value(_apiFormat),
        modelsUrl: Value(
          _modelsUrlCtrl.text.trim().isEmpty
              ? null
              : _modelsUrlCtrl.text.trim(),
        ),
        balanceUrl: Value(
          _balanceUrlCtrl.text.trim().isEmpty
              ? null
              : _balanceUrlCtrl.text.trim(),
        ),
        balanceKey: Value(
          _balanceKeyCtrl.text.trim().isEmpty
              ? null
              : _balanceKeyCtrl.text.trim(),
        ),
        isEnabled: Value(_enabled),
      ),
    );
    // 确保默认模型存在于 AiModels（聊天页模型列表按 custom_<key> 读取），
    // 已存在时保留其能力标记，不做覆盖。
    if (_selectedModelId != null) {
      final sourceKey = OpenAiProviderRegistry.customSourceKey(key);
      final existing = await AiDatabase.instance.aiModelDao.getModel(
        sourceKey,
        _selectedModelId!,
      );
      if (existing == null) {
        await AiDatabase.instance.aiModelDao.upsertModels([
          AiModelsCompanion.insert(
            provider: sourceKey,
            modelId: _selectedModelId!,
            label: _selectedModelId!,
          ),
        ]);
      }
    }
    await OpenAiProviderRegistry.refreshCustomProviders();
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop();
    }
  }

  Future<Res<String>> _queryBalanceNow() => queryBalanceByUrl(
    baseUrl: _urlCtrl.text.trim(),
    apiKey: _apiKeyCtrl.text.trim(),
    balanceUrl: _balanceUrlCtrl.text.trim(),
    balanceKey: _balanceKeyCtrl.text.trim(),
  );

  /// 模型列表接口地址（按接口格式拼接）
  String get _modelsEndpoint {
    final base = _urlCtrl.text.trim();
    if (base.isEmpty) return '';
    if (_modelsUrlCtrl.text.trim().isNotEmpty) {
      return _modelsUrlCtrl.text.trim();
    }
    return _apiFormat == 'claude' ? '$base/v1/models' : '$base/models';
  }

  Map<String, String> get _probeHeaders {
    final key = _apiKeyCtrl.text.trim();
    return switch (_apiFormat) {
      'claude' => {'x-api-key': key, 'anthropic-version': '2023-06-01'},
      'gemini' => {'x-goog-api-key': key},
      _ => {'Authorization': 'Bearer $key'},
    };
  }

  /// 测试服务商是否连通（GET 模型列表接口）
  Future<void> _testConnection() async {
    final url = _modelsEndpoint;
    if (url.isEmpty || _apiKeyCtrl.text.trim().isEmpty) {
      App.rootContext.showMessage(message: t.required, level: LogLevel.warning);
      return;
    }
    try {
      final response = await AppDio().request(
        url,
        options: Options(
          method: 'GET',
          headers: _probeHeaders,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      App.rootContext.showMessage(
        message: response.statusCode == 200
            ? t.connectionOk
            : t.connectionFailed,
        level: response.statusCode == 200 ? LogLevel.info : LogLevel.warning,
      );
    } catch (e) {
      App.rootContext.showMessage(
        message: '$t.connectionFailed: $e',
        level: LogLevel.warning,
      );
    }
  }

  /// 拉取可用模型并写入模型库
  Future<void> _fetchModels() async {
    final url = _modelsEndpoint;
    if (url.isEmpty || _apiKeyCtrl.text.trim().isEmpty || _sourceKey.isEmpty) {
      App.rootContext.showMessage(message: t.required, level: LogLevel.warning);
      return;
    }
    try {
      final response = await AppDio().request(
        url,
        options: Options(
          method: 'GET',
          headers: _probeHeaders,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final json = response.data;
      if (json is! Map) {
        App.rootContext.showMessage(
          message: t.noModelsReturned,
          level: LogLevel.warning,
        );
        return;
      }
      final items = json['data'] ?? json['models'];
      final ids = <String>[];
      if (items is List) {
        for (final item in items.whereType<Map>()) {
          var id = item['id']?.toString() ?? '';
          if (id.isEmpty) {
            id = (item['name']?.toString() ?? '').replaceFirst('models/', '');
          }
          if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
        }
      }
      if (ids.isEmpty) {
        App.rootContext.showMessage(
          message: t.noModelsReturned,
          level: LogLevel.warning,
        );
        return;
      }
      final sourceKey = _sourceKey;
      final picked = await _showModelImportDialog(context, ids);
      if (picked == null || picked.isEmpty) return;
      final existing = await AiDatabase.instance.aiModelDao.getModel(
        sourceKey,
        picked.first,
      );
      final companions = <AiModelsCompanion>[];
      for (final id in picked) {
        final s = _autoModelSettings(id, _apiFormat);
        companions.add(
          AiModelsCompanion.insert(
            provider: sourceKey,
            modelId: id,
            label: id,
            modelType: Value(s.type),
            inputModality: Value(s.input),
            outputModality: Value(s.output),
            supportsVision: Value(s.vision),
            supportsTools: Value(s.tools),
            supportsReasoning: Value(s.reasoning),
          ),
        );
      }
      await AiDatabase.instance.aiModelDao.upsertModels(companions);
      if (existing == null && _selectedModelId == null) {
        _selectedModelId = picked.first;
      }
      await _loadModels();
      App.rootContext.showMessage(
        message: '${t.connectionOk} · ${picked.length}',
        level: LogLevel.info,
      );
    } catch (e) {
      App.rootContext.showMessage(
        message: '$t.connectionFailed: $e',
        level: LogLevel.warning,
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.delete,
        content: Text(
          '${t.areYouSureYouWantToDeleteGeneric} "${widget.provider!.name}"?',
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
      await AiDatabase.instance.aiCustomProviderDao.deleteByProvider(
        widget.provider!.provider,
      );
      await OpenAiProviderRegistry.refreshCustomProviders();
      if (mounted) App.rootContext.pop();
    }
  }

  Widget _buildField(
    IconData icon,
    String label,
    TextEditingController ctrl, {
    bool enabled = true,
    bool obscure = false,
    bool required = true,
    String? hintText,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        enabled: enabled,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          hintText: hintText,
          border: const OutlineInputBorder(),
          suffixIcon: suffixIcon == null
              ? null
              : IconButton(icon: Icon(suffixIcon), onPressed: onSuffixTap),
        ),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? t.required : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopUpWidgetScaffold(
      title: _isNew ? t.newCustomProvider : widget.provider!.name,
      tailing: [
        if (!_isNew)
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
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _SettingCard(
                    children: [
                      _buildField(
                        Icons.vpn_key_outlined,
                        t.providerKey,
                        _keyCtrl,
                        enabled: _isNew,
                        hintText: t.providerKeyHint,
                      ),
                      _buildField(Icons.badge_outlined, t.name, _nameCtrl),
                      _buildField(Icons.home_filled, t.baseUrl, _urlCtrl),
                      // ── 接口格式（Tab 选择 + OpenAI 端点子选项）──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.apiFormat,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'openai',
                                  label: Text('OpenAI'),
                                  icon: Icon(Icons.chat_outlined, size: 16),
                                ),
                                ButtonSegment(
                                  value: 'gemini',
                                  label: Text('Gemini'),
                                  icon: Icon(
                                    Icons.rocket_launch_outlined,
                                    size: 16,
                                  ),
                                ),
                                ButtonSegment(
                                  value: 'claude',
                                  label: Text('Claude'),
                                  icon: Icon(
                                    Icons.bubble_chart_outlined,
                                    size: 16,
                                  ),
                                ),
                              ],
                              selected: {_family},
                              showSelectedIcon: false,
                              onSelectionChanged: (s) {
                                setState(() {
                                  _apiFormat = s.first == 'openai'
                                      ? (_responses
                                            ? 'openai_responses'
                                            : 'openai')
                                      : s.first;
                                });
                                _loadModels();
                              },
                            ),
                            if (_family == 'openai') ...[
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: [
                                  ButtonSegment(
                                    value: 'chat',
                                    label: Text(t.endpointChatCompletions),
                                    icon: const Icon(
                                      Icons.chat_outlined,
                                      size: 14,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: 'responses',
                                    label: Text(t.endpointResponses),
                                    icon: const Icon(
                                      Icons.schema_outlined,
                                      size: 14,
                                    ),
                                  ),
                                ],
                                selected: {_responses ? 'responses' : 'chat'},
                                showSelectedIcon: false,
                                onSelectionChanged: (s) {
                                  setState(() {
                                    _apiFormat = s.first == 'responses'
                                        ? 'openai_responses'
                                        : 'openai';
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      // ── 新建时仅创建外壳，其余配置在保存后编辑 ──
                      if (!_isNew) ...[
                        _buildField(
                          Icons.key,
                          t.apiKey,
                          _apiKeyCtrl,
                          obscure: _obscure,
                          suffixIcon: _obscure
                              ? Icons.visibility_off
                              : Icons.visibility,
                          onSuffixTap: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  Icons.dns_outlined,
                                  t.modelsUrl,
                                  _modelsUrlCtrl,
                                  required: false,
                                  hintText: 'https://api.example.com/v1/models',
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.cloud_download_outlined),
                                tooltip: t.fetchModels,
                                onPressed: _fetchModels,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _testConnection,
                              icon: const Icon(Icons.wifi_tethering),
                              label: Text(t.testApiKey),
                            ),
                          ),
                        ),
                        const Divider(indent: 16, endIndent: 16),
                        _ModelListSection(
                          sourceKey: _sourceKey,
                          models: _models,
                          selectedModelId: _selectedModelId,
                          canAdd: _sourceKey.isNotEmpty,
                          onSelected: (id) =>
                              setState(() => _selectedModelId = id),
                          onDelete: _deleteModel,
                          onChanged: _loadModels,
                        ),
                        const Divider(indent: 16, endIndent: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: _BalanceConfigFields(
                            urlCtrl: _balanceUrlCtrl,
                            keyCtrl: _balanceKeyCtrl,
                            onQuery: _queryBalanceNow,
                            baseUrl: _urlCtrl.text.trim(),
                          ),
                        ),
                      ],
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
// MCP 服务器 编辑弹窗
// ─────────────────────────────────────────────

class _McpServerEditor extends StatefulWidget {
  const _McpServerEditor({this.server});

  final AiMcpServer? server;

  @override
  State<_McpServerEditor> createState() => _McpServerEditorState();
}

class _McpServerEditorState extends State<_McpServerEditor> {
  final _formKey = GlobalKey<FormState>();

  late final _nameCtrl = TextEditingController(text: widget.server?.name ?? '');
  late String _transport = widget.server?.transport ?? 'http';
  late final _commandCtrl = TextEditingController(
    text: widget.server?.command ?? '',
  );
  late final _argsCtrl = TextEditingController(text: widget.server?.args ?? '');
  late final _envCtrl = TextEditingController(text: widget.server?.env ?? '');
  late final _urlCtrl = TextEditingController(text: widget.server?.url ?? '');
  late final _headersCtrl = TextEditingController(
    text: widget.server?.headers ?? '',
  );
  late bool _enabled = widget.server?.isEnabled ?? true;

  bool get _isNew => widget.server == null;
  bool get _isStdio => _transport == 'stdio';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commandCtrl.dispose();
    _argsCtrl.dispose();
    _envCtrl.dispose();
    _urlCtrl.dispose();
    _headersCtrl.dispose();
    super.dispose();
  }

  String? _validateJson(String? value, {required bool isList}) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (isList && decoded is! List) return t.invalidJson;
      if (!isList && decoded is! Map) return t.invalidJson;
    } catch (_) {
      return t.invalidJson;
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await AiDatabase.instance.aiMcpServerDao.upsert(
      AiMcpServersCompanion.insert(
        id: widget.server == null
            ? const Value.absent()
            : Value(widget.server!.id),
        name: _nameCtrl.text.trim(),
        transport: Value(_transport),
        command: Value(
          _isStdio && _commandCtrl.text.trim().isNotEmpty
              ? _commandCtrl.text.trim()
              : null,
        ),
        args: Value(
          _isStdio && _argsCtrl.text.trim().isNotEmpty
              ? _argsCtrl.text.trim()
              : null,
        ),
        env: Value(
          _isStdio && _envCtrl.text.trim().isNotEmpty
              ? _envCtrl.text.trim()
              : null,
        ),
        url: Value(
          !_isStdio && _urlCtrl.text.trim().isNotEmpty
              ? _urlCtrl.text.trim()
              : null,
        ),
        headers: Value(
          !_isStdio && _headersCtrl.text.trim().isNotEmpty
              ? _headersCtrl.text.trim()
              : null,
        ),
        isEnabled: Value(_enabled),
      ),
    );
    McpManager.invalidateCache();
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
          '${t.areYouSureYouWantToDeleteGeneric} "${widget.server!.name}"?',
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
      await AiDatabase.instance.aiMcpServerDao.deleteById(widget.server!.id);
      McpManager.invalidateCache();
      if (mounted) App.rootContext.pop();
    }
  }

  Widget _buildField(
    IconData icon,
    String label,
    TextEditingController ctrl, {
    bool enabled = true,
    bool multiline = false,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        enabled: enabled,
        maxLines: multiline ? 4 : 1,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          helperText: helperText,
          alignLabelWithHint: multiline,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopUpWidgetScaffold(
      title: _isNew ? t.newMcpServer : widget.server!.name,
      tailing: [
        if (!_isNew)
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
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _SettingCard(
                    children: [
                      _buildField(
                        Icons.badge_outlined,
                        t.mcpServerName,
                        _nameCtrl,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButtonFormField<String>(
                          initialValue: _transport,
                          decoration: InputDecoration(
                            labelText: t.transport,
                            prefixIcon: const Icon(Icons.swap_horiz, size: 20),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'http',
                              child: Text(t.http),
                            ),
                            DropdownMenuItem(value: 'sse', child: Text(t.sse)),
                            DropdownMenuItem(
                              value: 'stdio',
                              child: Text(t.stdio),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _transport = v);
                          },
                        ),
                      ),
                      if (_isStdio) ...[
                        _buildField(
                          Icons.terminal,
                          t.command,
                          _commandCtrl,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? t.required
                              : null,
                        ),
                        _buildField(
                          Icons.data_object,
                          t.args,
                          _argsCtrl,
                          helperText: t.optionalField,
                          validator: (v) => _validateJson(v, isList: true),
                        ),
                        _buildField(
                          Icons.workspaces_outline,
                          t.env,
                          _envCtrl,
                          helperText: t.optionalField,
                          validator: (v) => _validateJson(v, isList: false),
                        ),
                      ] else ...[
                        _buildField(
                          Icons.link,
                          t.serverUrl,
                          _urlCtrl,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? t.required
                              : null,
                        ),
                        _buildField(
                          Icons.manage_accounts_outlined,
                          t.headers,
                          _headersCtrl,
                          helperText: t.optionalField,
                          validator: (v) => _validateJson(v, isList: false),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildToggleRow(
                          t.enable,
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
          maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.toOpacity(0.5),
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

  final AiSkill? skill;

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
    final dao = AiDatabase.instance.aiSkillDao;
    if (!_isNew) return widget.skill!.key;
    final base = _slugifySkillKey(_nameCtrl.text);
    if (base.isEmpty) {
      return 'skill_${DateTime.now().millisecondsSinceEpoch}';
    }
    var key = base;
    var seq = 0;
    while (await dao.getByKey(key) != null) {
      key = '${base}_${++seq}';
    }
    return key;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final key = await _deriveKey();
    await AiDatabase.instance.aiSkillDao.upsert(
      AiSkillsCompanion.insert(
        id: widget.skill == null
            ? const Value.absent()
            : Value(widget.skill!.id),
        key: key,
        name: _nameCtrl.text.trim(),
        description: widget.skill?.description == null
            ? const Value.absent()
            : Value(widget.skill!.description),
        systemPrompt: _promptCtrl.text.trim(),
        isBuiltin: Value(_isBuiltin),
        isEnabled: Value(widget.skill?.isEnabled ?? true),
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
      await AiDatabase.instance.aiSkillDao.deleteById(widget.skill!.id);
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
            maxHeight: MediaQuery.of(context).size.height * 0.85,
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
