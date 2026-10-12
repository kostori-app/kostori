part of '../settings_page.dart';

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
