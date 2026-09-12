part of 'settings_page.dart';

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
      if (!mounted) return;
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
