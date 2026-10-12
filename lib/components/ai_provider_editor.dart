import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_provider_settings.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/context.dart';
import 'package:kostori/repositories/ai_provider_settings_repository.dart';

/// 复用已有模型管理组件，编辑器只统一配置流程。
class AiProviderModelsView {
  const AiProviderModelsView({
    required this.source,
    required this.models,
    required this.selectedModel,
    required this.onSelected,
    required this.onDelete,
    required this.onChanged,
  });
  final String source;
  final List<AiModel> models;
  final String? selectedModel;
  final ValueChanged<String> onSelected;
  final ValueChanged<AiModel> onDelete;
  final Future<void> Function() onChanged;
}

class AiProviderEditor extends StatefulWidget {
  const AiProviderEditor({
    super.key,
    required this.settings,
    required this.modelsBuilder,
    required this.selectModels,
    this.repository,
    this.onSaved,
  });
  final AiProviderSettings settings;
  final AiProviderSettingsRepository? repository;
  final Widget Function(AiProviderModelsView) modelsBuilder;
  final Future<List<String>?> Function(BuildContext, List<String>) selectModels;
  final VoidCallback? onSaved;

  @override
  State<AiProviderEditor> createState() => _AiProviderEditorState();
}

class _AiProviderEditorState extends State<AiProviderEditor>
    with SingleTickerProviderStateMixin {
  late final _repository = widget.repository ?? AiProviderSettingsRepository();
  late final _tabs = TabController(length: 3, vsync: this);
  late final _name = TextEditingController(text: widget.settings.name);
  late final _baseUrl = TextEditingController(text: widget.settings.baseUrl);
  late final _apiKey = TextEditingController(text: widget.settings.apiKey);
  late final _model = TextEditingController(text: widget.settings.model);
  late final _modelsUrl = TextEditingController(
    text: widget.settings.modelsUrl,
  );
  late final _balanceUrl = TextEditingController(
    text: widget.settings.balanceUrl,
  );
  late final _balanceKey = TextEditingController(
    text: widget.settings.balanceKey,
  );
  late String _format = widget.settings.apiFormat;
  late bool _enabled = widget.settings.isEnabled;
  bool _obscure = true;
  bool _loading = true;
  bool _saved = false;
  String? _busy;
  String? _nameError;
  String? _urlError;
  String? _keyError;
  String? _modelError;
  String? _modelsUrlError;
  List<AiModel> _models = [];

  AiProviderSettings get _settings => widget.settings.copyWith(
    name: _name.text.trim(),
    baseUrl: _baseUrl.text.trim(),
    apiKey: _apiKey.text.trim(),
    model: _model.text.trim(),
    apiFormat: _format,
    modelsUrl: _modelsUrl.text.trim(),
    balanceUrl: _balanceUrl.text.trim(),
    balanceKey: _balanceKey.text.trim(),
    isEnabled: _enabled,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (!widget.settings.isCustom) {
        await _repository.ensureModel(
          widget.settings.source,
          widget.settings.model,
          _format,
        );
      }
      await _loadModels();
    } catch (error) {
      if (mounted) {
        context.showMessage(
          message: aiErrorMessageOf(error),
          level: LogLevel.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadModels() async {
    final models = await _repository.models(widget.settings.source);
    if (mounted) setState(() => _models = models);
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in [
      _name,
      _baseUrl,
      _apiKey,
      _model,
      _modelsUrl,
      _balanceUrl,
      _balanceKey,
    ]) {
      controller.dispose();
    }
    // 新建取消后清理草稿模型，避免留下无法归属的记录。
    if (widget.settings.isNew && !_saved) {
      unawaited(_repository.discardModels(widget.settings.source));
    }
    super.dispose();
  }

  bool _validate({bool connectionOnly = false}) {
    final settings = _settings;
    setState(() {
      _nameError = !connectionOnly && settings.name.isEmpty
          ? context.t.required
          : null;
      _urlError = !AiProviderApi.isHttpUrl(settings.baseUrl)
          ? context.t.aiProviderInvalidUrl
          : null;
      _keyError =
          !settings.isCustom &&
              (settings.isEnabled || connectionOnly) &&
              settings.apiKey.isEmpty
          ? context.t.required
          : null;
      _modelError =
          !connectionOnly && settings.isEnabled && settings.model.isEmpty
          ? context.t.aiProviderModelRequired
          : null;
      final override = Uri.tryParse(settings.modelsUrl);
      _modelsUrlError =
          settings.modelsUrl.isNotEmpty &&
              (override == null ||
                  (override.hasScheme &&
                      !AiProviderApi.isHttpUrl(settings.modelsUrl)))
          ? context.t.aiProviderInvalidUrl
          : null;
    });
    if (_nameError != null || _urlError != null || _keyError != null) {
      _tabs.animateTo(0);
      return false;
    }
    if (_modelError != null) {
      _tabs.animateTo(1);
      return false;
    }
    if (_modelsUrlError != null) {
      _tabs.animateTo(2);
      return false;
    }
    return true;
  }

  Future<void> _run(String action, Future<void> Function() work) async {
    if (_busy != null || _loading) return;
    setState(() => _busy = action);
    try {
      await work();
    } catch (error) {
      if (mounted) {
        context.showMessage(
          message: aiErrorMessageOf(error),
          level: LogLevel.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _save() async {
    if (!_validate()) return;
    final settings = _settings;
    await _run('save', () async {
      await _repository.save(settings);
      _saved = true;
      if (!mounted) return;
      widget.onSaved?.call();
      context.showMessage(message: context.t.saved);
      await Navigator.of(context, rootNavigator: true).maybePop();
    });
  }

  Future<void> _testConnection() async {
    if (!_validate(connectionOnly: true)) return;
    final settings = _settings;
    await _run('test', () async {
      await _repository.testConnection(settings);
      if (mounted) context.showMessage(message: context.t.connectionOk);
    });
  }

  Future<void> _fetchModels() async {
    if (!_validate(connectionOnly: true)) return;
    final settings = _settings;
    await _run('models', () async {
      final ids = await _repository.fetchModels(settings);
      if (!mounted) return;
      if (ids.isEmpty) {
        context.showMessage(
          message: context.t.noModelsReturned,
          level: LogLevel.warning,
        );
        return;
      }
      final selected = await widget.selectModels(context, ids);
      if (selected == null || selected.isEmpty) return;
      await _repository.importModels(settings, selected);
      if (!mounted) return;
      if (_model.text.trim().isEmpty) _model.text = selected.first;
      await _loadModels();
    });
  }

  Future<void> _deleteModel(AiModel model) async {
    await _run('modelDelete', () async {
      await _repository.deleteModel(model);
      await _loadModels();
      if (mounted && _model.text.trim() == model.modelId) {
        setState(
          () => _model.text = _models.isEmpty ? '' : _models.first.modelId,
        );
      }
    });
  }

  Future<void> _deleteProvider() async {
    await showConfirmDialog(
      context: context,
      title: context.t.delete,
      content: '${context.t.confirmDeleteAiProvider}\n${widget.settings.name}',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () => _run('delete', () async {
        await _repository.delete(widget.settings);
        _saved = true;
        if (mounted) {
          await Navigator.of(context, rootNavigator: true).maybePop();
        }
      }),
    );
  }

  Future<void> _queryBalance() => _run('balance', () async {
    final result = await _repository.queryBalance(_settings);
    if (!mounted) return;
    if (result.error) {
      context.showMessage(
        message: result.errorMessage == kBalanceQueryUnsupported
            ? context.t.balanceQueryUnsupported
            : (result.errorMessage ?? context.t.connectionFailed),
        level: LogLevel.warning,
      );
      return;
    }
    await ContentDialog.show(
      context: context,
      title: context.t.balance,
      content: Text(result.data),
    );
  });

  String _formatLabel(String format) => switch (format) {
    'openai_responses' => context.t.aiProtocolResponses,
    'gemini' => context.t.aiProtocolGemini,
    'claude' => context.t.aiProtocolClaude,
    _ => context.t.aiProtocolChatCompletions,
  };

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? error,
    bool readOnly = false,
    bool secret = false,
    Key? key,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      key: key,
      controller: controller,
      readOnly: readOnly,
      onChanged: onChanged,
      obscureText: secret && _obscure,
      autocorrect: false,
      enableSuggestions: !secret,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 3,
        errorText: error,
        border: const OutlineInputBorder(),
        suffixIcon: secret
            ? IconButton(
                tooltip: _obscure
                    ? context.t.aiProviderShowKey
                    : context.t.aiProviderHideKey,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    ),
  );

  Widget _connection() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          _name,
          context.t.name,
          error: _nameError,
          readOnly: !widget.settings.isCustom,
          key: const ValueKey('ai-provider-name'),
        ),
        _field(
          _baseUrl,
          context.t.baseUrl,
          error: _urlError,
          hint: context.t.aiProviderBaseUrlHint,
          key: const ValueKey('ai-provider-base-url'),
        ),
        Text(
          context.t.apiFormat,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Select(
            current: _formatLabel(_format),
            values:
                (widget.settings.fixedApiFormat
                        ? [_format]
                        : AiProviderApi.formats)
                    .map(_formatLabel)
                    .toList(),
            onTap: (index) => setState(() {
              _format = (widget.settings.fixedApiFormat
                  ? [_format]
                  : AiProviderApi.formats)[index];
            }),
          ),
        ),
        const SizedBox(height: 16),
        _field(
          _apiKey,
          context.t.apiKey,
          secret: true,
          error: _keyError,
          hint: widget.settings.isCustom
              ? context.t.aiProviderOptionalKeyHint
              : null,
          key: const ValueKey('ai-provider-api-key'),
        ),
        Row(
          children: [
            Expanded(child: Text(context.t.enabled)),
            CustomSwitch(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Button.outlined(
            isLoading: _busy == 'test',
            onPressed: _testConnection,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_tethering, size: 18),
                const SizedBox(width: 8),
                Text(context.t.testConnection),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _modelSettings() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _field(
              _model,
              context.t.defaultModel,
              error: _modelError,
              hint: context.t.aiProviderDefaultModelHint,
              key: const ValueKey('ai-provider-default-model'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t.aiProviderModelCount(count: _models.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Button.outlined(
                  isLoading: _busy == 'models',
                  onPressed: _fetchModels,
                  child: Text(context.t.fetchModels),
                ),
              ],
            ),
          ),
          SizedBox(
            height: (constraints.maxHeight - 180)
                .clamp(280.0, 900.0)
                .toDouble(),
            child: widget.modelsBuilder(
              AiProviderModelsView(
                source: widget.settings.source,
                models: _models,
                selectedModel: _model.text.trim().isEmpty
                    ? null
                    : _model.text.trim(),
                onSelected: (id) => setState(() => _model.text = id),
                onDelete: _deleteModel,
                onChanged: _loadModels,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _advanced() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          _modelsUrl,
          context.t.modelsUrl,
          error: _modelsUrlError,
          hint: context.t.aiProviderModelsUrlHint,
          key: const ValueKey('ai-provider-models-url'),
        ),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          context.t.balanceQueryConfig,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        _field(
          _balanceUrl,
          context.t.balanceQueryUrl,
          hint: context.t.balanceQueryUrlHint,
        ),
        _field(
          _balanceKey,
          context.t.balanceKeyPath,
          hint: context.t.balanceKeyPathHint,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Button.outlined(
            isLoading: _busy == 'balance',
            onPressed: _queryBalance,
            child: Text(context.t.aiProviderQueryBalance),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopUpWidgetScaffold(
    title: widget.settings.isNew
        ? context.t.newCustomProvider
        : widget.settings.source == 'openai'
        ? context.t.aiOpenAiProvider
        : widget.settings.name,
    tailing: [
      if (!widget.settings.isNew &&
          (widget.settings.isCustom || widget.settings.apiKey.isNotEmpty))
        IconButton(
          onPressed: _busy == null ? _deleteProvider : null,
          tooltip: context.t.delete,
          icon: const Icon(Icons.delete_outline),
        ),
    ],
    body: Column(
      children: [
        CapsuleTabBar(
          controller: _tabs,
          labels: [
            context.t.aiProviderConnection,
            context.t.modelSettings,
            context.t.aiProviderAdvanced,
          ],
          icons: const [
            Icons.link_outlined,
            Icons.model_training_outlined,
            Icons.tune,
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: PolygonRefreshIndicator())
              : AbsorbPointer(
                  absorbing: _busy != null,
                  child: TabViewBody(
                    controller: _tabs,
                    children: [_connection(), _modelSettings(), _advanced()],
                  ),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _enabled
                      ? context.t.aiProviderEnabledHint
                      : context.t.aiProviderDisabledHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              Button.filled(
                isLoading: _busy == 'save',
                onPressed: _save,
                child: Text(context.t.apply),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
