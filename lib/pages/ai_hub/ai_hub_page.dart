import 'dart:async';
import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/ai_model_card.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/custom_markdown_widget.dart';
import 'package:kostori/components/watermark.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_conversation_service.dart';
import 'package:kostori/foundation/ai_service/ai_image_service.dart';
import 'package:kostori/foundation/ai_service/assistant_profile.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/ai_service/plugin_module.dart';
import 'package:kostori/foundation/ai_service/story.dart';
import 'package:kostori/foundation/ai_service/role_management.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/character/character_casts_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/translation_service.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/init.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/skills/skill_registry.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/utils.dart';
import 'package:pasteboard/pasteboard.dart';

part 'ai_chat_page.dart';

part 'ai_chat_message_widgets.dart';

part 'image_tag_page.dart';

part 'soul_profile_page.dart';

part 'summary_page.dart';

part 'taste_radar_page.dart';

part 'story_page.dart';

class AiHubEntry extends StatelessWidget {
  const AiHubEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.to(() => const AiHubPage()),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.aiHub,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'AI',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AI Hub 主页（聊天 + 插件模块）
// ─────────────────────────────────────────────

class AiHubPage extends StatefulWidget {
  const AiHubPage({super.key});

  @override
  State<AiHubPage> createState() => _AiHubPageState();
}

class _AiHubPageState extends State<AiHubPage> {
  @override
  void initState() {
    super.initState();
    PluginStore.instance.init();
  }

  void _openPlugin(PluginModule plugin) {
    switch (plugin.id) {
      case 'soul_profile':
        context.to(() => const SoulProfilePage());
      case 'image_tag':
        context.to(() => const ImageTagPage());
      case 'summary':
        context.to(() => const SummaryPage());
      case 'taste_radar':
        context.to(() => const TasteRadarPage());
      case 'role_play':
        context.to(() => const StoryPage());
      case 'season_review':
        context.to(
          () => const SummaryPage(initialRange: _SummaryRange.quarter),
        );
      default:
        context.to(() => PluginModulePage(plugin: plugin));
    }
  }

  Future<void> _addPlugin() async {
    await showPopUpWidget(App.rootContext, const _PluginEditor());
    if (mounted) setState(() {});
  }

  Future<void> _editPlugin(PluginModule plugin) async {
    await showPopUpWidget(App.rootContext, _PluginEditor(plugin: plugin));
    if (mounted) setState(() {});
  }

  Future<void> _duplicatePlugin(PluginModule plugin) async {
    final copy = PluginModule(
      id: 'plugin_${DateTime.now().millisecondsSinceEpoch}',
      name: '${plugin.name} · ${t.copy}',
      icon: plugin.icon,
      description: plugin.description,
      prompt: plugin.prompt,
      starters: plugin.starters,
      tags: plugin.tags,
      provider: plugin.provider,
      model: plugin.model,
      temperature: plugin.temperature,
      maxContextMessages: plugin.maxContextMessages,
      chatMode: plugin.chatMode,
    );
    await PluginStore.instance.upsert(copy);
    if (mounted) setState(() {});
  }

  Future<void> _deletePlugin(PluginModule plugin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.delete,
        content: Text(
          '${t.areYouSureYouWantToDeleteGeneric} "${plugin.name}"?',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await PluginStore.instance.remove(plugin.id);
    if (!ok && mounted) {
      App.rootContext.showMessage(
        message: t.builtinPluginCannotDelete,
        level: LogLevel.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: Appbar(title: Text(t.aiHub)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ── AI 聊天（一级入口，与插件模块区分）──
          _HubModuleCard(
            icon: Icons.chat_bubble_outline,
            title: t.aiChat,
            subtitle: t.aiChatDescription,
            color: const Color(0xFF4CAF50),
            onTap: () => context.to(() => const AiChatPage()),
          ),
          const SizedBox(height: 16),
          // ── 插件模块 ──
          Row(
            children: [
              Icon(Icons.extension_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.pluginModules,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 20),
                tooltip: t.addPlugin,
                onPressed: _addPlugin,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: PluginStore.instance,
            builder: (context, _) {
              final plugins = PluginStore.instance.plugins;
              if (plugins.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(t.noPluginsYet, style: ts.s12),
                );
              }
              return Column(
                children: [
                  for (final p in plugins) ...[
                    _PluginCard(
                      plugin: p,
                      onTap: () => _openPlugin(p),
                      onEdit: p.isBuiltin ? null : () => _editPlugin(p),
                      onDuplicate: () => _duplicatePlugin(p),
                      onDelete: p.isBuiltin ? null : () => _deletePlugin(p),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 插件卡片
// ─────────────────────────────────────────────

class _PluginCard extends StatelessWidget {
  const _PluginCard({
    required this.plugin,
    required this.onTap,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
  });

  final PluginModule plugin;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(plugin.icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plugin.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (plugin.isBuiltin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t.builtin,
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plugin.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onEdit != null || onDuplicate != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: t.more,
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'duplicate') onDuplicate?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      PopupMenuItem(value: 'edit', child: Text(t.edit)),
                    if (onDuplicate != null)
                      PopupMenuItem(value: 'duplicate', child: Text(t.copy)),
                    if (onDelete != null)
                      PopupMenuItem(value: 'delete', child: Text(t.delete)),
                  ],
                )
              else
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 自定义插件：提示词驱动的一问一答模块
// ─────────────────────────────────────────────

class PluginModulePage extends ConsumerStatefulWidget {
  const PluginModulePage({super.key, required this.plugin});

  final PluginModule plugin;

  @override
  ConsumerState<PluginModulePage> createState() => _PluginModulePageState();
}

class _PluginModulePageState extends ConsumerState<PluginModulePage> {
  final TextEditingController _inputController = TextEditingController();
  String? _sessionId;
  String? _result;
  bool _running = false;
  String? _error;

  PluginModule get plugin => widget.plugin;

  /// 插件自带服务商优先，否则跟随 AI 工坊当前选择
  String get _provider =>
      plugin.provider.isNotEmpty ? plugin.provider : aiHubProvider();

  AiGenerationParams? get _params => plugin.temperature == null
      ? null
      : AiGenerationParams(temperature: plugin.temperature);

  @override
  void initState() {
    super.initState();
    if (plugin.chatMode) _ensureSession();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<String> _ensureSession() async {
    final existing = _sessionId;
    if (existing != null) return existing;
    final id = await AiConversationService().createSession(
      type: 'plugin_${plugin.id}',
      provider: _provider,
      title: plugin.name,
    );
    if (mounted) setState(() => _sessionId = id);
    return id;
  }

  Future<void> _send([String? preset]) async {
    if (_running) return;
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty) {
      App.rootContext.showMessage(message: t.pleaseEnterTextToTranslate);
      return;
    }
    if (preset == null) _inputController.clear();
    setState(() {
      _running = true;
      _error = null;
    });
    final sessionId = await _ensureSession();
    final res = await AiConversationService().sendMessage(
      sessionId: sessionId,
      userMessage: text,
      taskType: 'plugin_${plugin.id}',
      maxContextMessages: plugin.chatMode ? plugin.maxContextMessages : 0,
      providerOverride: _provider,
      systemPromptOverride: plugin.prompt.trim().isEmpty
          ? null
          : plugin.prompt.trim(),
      paramsOverride: _params,
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      if (res.success) {
        if (!plugin.chatMode) _result = res.data;
      } else {
        _error = res.errorMessage ?? 'Error';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: Appbar(title: Text('${plugin.icon} ${plugin.name}')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _pluginHeader(scheme),
                if (plugin.starters.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in plugin.starters)
                        ActionChip(
                          label: Text(s),
                          onPressed: _running ? null : () => _send(s),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (_error != null) _errorBox(scheme),
                if (plugin.chatMode)
                  _chatMessages(scheme)
                else if (_result != null)
                  _AiResultCard(
                    icon: Icons.output,
                    title: t.output,
                    content: _result!,
                  ),
              ],
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _pluginHeader(ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(plugin.icon, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plugin.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (plugin.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  plugin.description,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
              if (plugin.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in plugin.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorBox(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }

  Widget _chatMessages(ColorScheme scheme) {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: PolygonRefreshIndicator()),
      );
    }
    return StreamBuilder<List<AiTask>>(
      stream: AiConversationService().watchMessages(sessionId),
      builder: (context, snap) {
        final messages = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final m in messages) _bubble(context, scheme, m),
            if (_running) _thinking(),
          ],
        );
      },
    );
  }

  Widget _bubble(BuildContext context, ColorScheme scheme, AiTask m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: CustomMarkdownWidget(
          data: isUser ? m.inputContent : (m.outputContent ?? ''),
        ),
      ),
    );
  }

  Widget _thinking() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: PolygonRefreshIndicator(),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: plugin.chatMode ? 4 : 6,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: t.enterTextToTranslate,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _running ? null : () => _send(),
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: PolygonRefreshIndicator(),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 插件编辑弹窗（新增/编辑自定义插件）
// ─────────────────────────────────────────────

class _PluginEditor extends StatefulWidget {
  const _PluginEditor({this.plugin});

  final PluginModule? plugin;

  @override
  State<_PluginEditor> createState() => _PluginEditorState();
}

class _PluginEditorState extends State<_PluginEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.plugin?.name ?? '');
  late final _iconCtrl = TextEditingController(
    text: widget.plugin?.icon ?? '🧩',
  );
  late final _descCtrl = TextEditingController(
    text: widget.plugin?.description ?? '',
  );
  late final _promptCtrl = TextEditingController(
    text: widget.plugin?.prompt ?? '',
  );
  late final _startersCtrl = TextEditingController(
    text: (widget.plugin?.starters ?? const []).join('\n'),
  );
  late final _tagsCtrl = TextEditingController(
    text: (widget.plugin?.tags ?? const []).join(', '),
  );

  late String _provider = (widget.plugin?.provider.isNotEmpty ?? false)
      ? widget.plugin!.provider
      : aiHubProvider();
  late String _model = widget.plugin?.model ?? '';
  late bool _chatMode = widget.plugin?.chatMode ?? false;
  late bool _useTemperature = widget.plugin?.temperature != null;
  late double _temperature = widget.plugin?.temperature ?? 0.7;
  late int _maxContext = widget.plugin?.maxContextMessages ?? 20;

  bool get _isNew => widget.plugin == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    _startersCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController c) => c.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> _csv(TextEditingController c) => c.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final module = PluginModule(
      id:
          widget.plugin?.id ??
          'plugin_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      icon: _iconCtrl.text.trim().isEmpty ? '🧩' : _iconCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      prompt: _promptCtrl.text.trim(),
      starters: _lines(_startersCtrl),
      tags: _csv(_tagsCtrl),
      provider: _provider,
      model: _model,
      temperature: _useTemperature ? _temperature : null,
      maxContextMessages: _maxContext,
      chatMode: _chatMode,
      isBuiltin: widget.plugin?.isBuiltin ?? false,
    );
    await PluginStore.instance.upsert(module);
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: _isNew ? t.addPlugin : t.editPlugin,
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  child: Column(
                    children: [
                      _field(t.name, _nameCtrl),
                      _field(t.pluginIcon, _iconCtrl, required: false),
                      _field(t.pluginDescription, _descCtrl, required: false),
                      _field(
                        t.pluginPrompt,
                        _promptCtrl,
                        required: false,
                        multiline: true,
                        hint: t.pluginPromptHint,
                      ),
                      _field(
                        t.pluginStarters,
                        _startersCtrl,
                        required: false,
                        multiline: true,
                        hint: t.pluginStartersHint,
                      ),
                      _field(t.pluginTags, _tagsCtrl, required: false),
                      _card(
                        scheme,
                        title: t.pluginModel,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.model,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              _ModelSelector(
                                provider: _provider,
                                currentModel: _model,
                                onProviderChanged: (p) => setState(() {
                                  _provider = p;
                                  _model = '';
                                }),
                                onModelSelected: (m) =>
                                    setState(() => _model = m),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _card(
                        scheme,
                        title: t.aiSettings,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(t.pluginChatMode),
                            subtitle: Text(
                              t.pluginChatModeDesc,
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: _chatMode,
                            onChanged: (v) => setState(() => _chatMode = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(t.pluginTemperature),
                            subtitle: Text(
                              _useTemperature
                                  ? _temperature.toStringAsFixed(2)
                                  : t.auto,
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: _useTemperature,
                            onChanged: (v) =>
                                setState(() => _useTemperature = v),
                          ),
                          if (_useTemperature)
                            Slider(
                              value: _temperature,
                              min: 0,
                              max: 2,
                              divisions: 20,
                              label: _temperature.toStringAsFixed(2),
                              onChanged: (v) =>
                                  setState(() => _temperature = v),
                            ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${t.pluginContextMessages}: $_maxContext',
                            ),
                            subtitle: Slider(
                              value: _maxContext.toDouble(),
                              min: 0,
                              max: 50,
                              divisions: 50,
                              label: '$_maxContext',
                              onChanged: (v) =>
                                  setState(() => _maxContext = v.round()),
                            ),
                          ),
                        ],
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

  Widget _card(
    ColorScheme scheme, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = true,
    bool multiline = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextFormField(
        controller: ctrl,
        maxLines: multiline ? 6 : 1,
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? t.required : null
            : null,
      ),
    );
  }
}

class _HubModuleCard extends StatelessWidget {
  const _HubModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 共用 Mixin：加载番剧数据
// ─────────────────────────────────────────────

mixin _AnimeDataMixin {
  Future<({
    List<BangumiItem> likedItems,
    String animeNames,
    String topTags,
    List<Map<String, dynamic>> tagData,
  })>
  loadAnimeData() async {
    final allStats = await StatsManager().getStatsAll();
    final seenIds = <int>{};
    final likedStats = allStats
        .where(
          (s) => s.bangumiId != null && s.liked && seenIds.add(s.bangumiId!),
        )
        .toList();
    final bangumi = providerContainer.read(bangumiManagerProvider);
    final likedItems = <BangumiItem>[];
    for (final s in likedStats) {
      final item = await bangumi.getBangumiItem(s.bangumiId!);
      if (item != null) likedItems.add(item);
    }

    final tagData = BangumiUtils.sortedTagItemMap(
      likedItems,
      minTagCount: 0,
      minItemCount: 1,
    );
    final topTags = tagData
        .take(50)
        .map((e) => '- ${e['word']}: ${e['value'].toInt()} items')
        .join('\n');
    final animeNames = likedItems
        .take(100)
        .map((item) => '- ${item.nameCn}')
        .join('\n');

    return (
      likedItems: likedItems,
      animeNames: animeNames,
      topTags: topTags,
      tagData: tagData,
    );
  }
}

// ─────────────────────────────────────────────
// 共用：AI 源选择器
// ─────────────────────────────────────────────

/// AI 工坊当前选中的服务商（持久化到 implicitData，跨页面/重启保留）
String aiHubProvider() {
  final v = appdata.implicitData['aiHubProvider'];
  if (v is String && OpenAiProviderRegistry.allProviders.containsKey(v)) {
    return v;
  }
  return OpenAiProviderRegistry.allProviders.keys.firstWhere(
    (_) => true,
    orElse: () => 'siliconFlow',
  );
}

void setAiHubProvider(String provider) {
  appdata.implicitData['aiHubProvider'] = provider;
  appdata.writeImplicitData();
}

/// 复用 AI 聊天风格的输入条：圆角容器 + 无边框输入框 + 上箭头发送
class _AiComposerBar extends StatelessWidget {
  const _AiComposerBar({
    required this.controller,
    required this.onSend,
    this.sending = false,
    this.hintText,
    this.bottomLeading,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final String? hintText;

  /// 底部工具行左侧内容（如模型选择器），与 AI 聊天输入栏一致
  final Widget? bottomLeading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: hintText ?? t.inputMessage,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: Row(
              children: [
                if (bottomLeading != null) ...[
                  bottomLeading!,
                  const SizedBox(width: 6),
                ],
                const Spacer(),
                if (sending)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: PolygonRefreshIndicator(),
                    ),
                  )
                else
                  IconButton.filled(
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    tooltip: t.sendMessage,
                    onPressed: onSend,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 冒险叙事的干净气泡：AI 全文 Markdown（无模型名/时间/操作/用量），用户右对齐气泡
class _StoryBubble extends StatelessWidget {
  const _StoryBubble({required this.content, required this.isUser});

  final String content;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: CustomMarkdownWidget(data: content),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: CustomMarkdownWidget(data: content, indentFirstLine: false),
    );
  }
}

/// 共用的 AI 设置卡片：服务商选择 + 当前模型，风格与其它设置卡片一致
class _AiSettingsCard extends StatelessWidget {
  const _AiSettingsCard({required this.provider, required this.onChanged});

  final String provider;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    void select(String key) {
      if (key == provider) return;
      setAiHubProvider(key);
      onChanged(key);
    }

    return _AiCard(
      icon: Icons.psychology,
      title: t.aiSettings,
      child: Row(
        children: [
          Text(
            t.model,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          // 模型按钮内已含服务商切换，无需再单独放数据源选择
          _ModelSelector(provider: provider, onProviderChanged: select),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 共用卡片
// ─────────────────────────────────────────────

class _AiCard extends StatelessWidget {
  const _AiCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 共用：AI 结果卡片（复制 / 导出图片带水印）
// ─────────────────────────────────────────────

class _AiResultCard extends ConsumerWidget {
  const _AiResultCard({
    required this.icon,
    required this.title,
    required this.content,
    this.header,
  });

  final IconData icon;
  final String title;

  /// Markdown 正文
  final String content;

  /// 正文上方的附加内容（如统计卡片），会一并出现在导出图片中
  final Widget? header;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: content));
    App.rootContext.showMessage(message: t.copied);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final bytes = await ImageSaver.captureWidgetToImage(
        context: context,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (header != null) ...[header!, const SizedBox(height: 12)],
              CustomMarkdownWidget(data: content),
              const SizedBox(height: 16),
              const Center(child: KostoriWatermark()),
            ],
          ),
        ),
      );
      if (bytes == null) return;
      final filename =
          'kostori_ai_${DateTime.now().millisecondsSinceEpoch}.png';
      await ImageSaver.saveOrShareImage(bytes: bytes, filename: filename);
    } catch (e) {
      ImageSaver.showResult(success: false, message: t.screenshotFailed);
    } finally {
      await ref.read(imagesProvider.notifier).loadImages();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AiCard(
      icon: icon,
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            tooltip: t.copy,
            onPressed: _copy,
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, size: 18),
            tooltip: t.exportScreenshot,
            onPressed: () => _export(context, ref),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 12)],
          const Divider(),
          CustomMarkdownWidget(data: content),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 共用：会话历史 Sheet
// ─────────────────────────────────────────────

class _SessionHistorySheet extends StatelessWidget {
  const _SessionHistorySheet({required this.taskType});

  final String taskType;

  @override
  Widget build(BuildContext context) {
    return Sheet(
      title: t.history,
      icon: Icons.history,
      initialSize: 0.7,
      headerTrailing: TextButton.icon(
        icon: const Icon(Icons.delete_sweep, size: 18),
        label: Text(t.clearAll),
        onPressed: () async {
          final sessions = await AiConversationService()
              .watchSessions(type: taskType)
              .first;
          for (final s in sessions) {
            await AiConversationService().deleteSession(s.sessionId);
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
      builder: (context, sc) => StreamBuilder<List<AiSession>>(
        stream: AiConversationService().watchSessions(type: taskType),
        builder: (ctx, snapshot) {
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return Center(child: Text(t.noHistoryYet));
          }
          return ListView.separated(
            controller: sc,
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = sessions[i];
              return ListTile(
                title: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  s.createdAt.toLocal().toString().substring(0, 16),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.provider,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(ctx).colorScheme.outline,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () =>
                          AiConversationService().deleteSession(s.sessionId),
                    ),
                  ],
                ),
                onTap: () => _showDetail(ctx, s.sessionId),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, String sessionId) {
    showDialog(
      context: context,
      builder: (_) => _SessionDetailDialog(sessionId: sessionId),
    );
  }
}

class _SessionDetailDialog extends StatelessWidget {
  const _SessionDetailDialog({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: sessionId,
      displayButton: false,
      content: StreamBuilder<List<AiTask>>(
        stream: AiConversationService().watchMessages(sessionId),
        builder: (ctx, snapshot) {
          final messages = snapshot.data ?? [];
          if (messages.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: PolygonRefreshIndicator(),
            );
          }
          final reply = messages.lastWhere(
            (m) => m.role == 'model',
            orElse: () => messages.last,
          );
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      messages.first.inputContent,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    CustomMarkdownWidget(data: reply.outputContent ?? ''),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 0.8,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({
    required this.provider,
    this.onProviderChanged,
    this.currentModel,
    this.onModelSelected,
  });

  final String provider;

  /// 切换服务商回调（内置插件页用它同步 _source）
  final ValueChanged<String>? onProviderChanged;

  /// 自定义当前模型（为空则用该服务商已保存的模型）
  final String? currentModel;

  /// 自定义模型选择回调（为空则写回该服务商的聊天模型）
  final ValueChanged<String>? onModelSelected;

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderModelSheet(
        provider: provider,
        onProviderChanged: onProviderChanged ?? (_) {},
        currentModel: currentModel,
        onModelSelected: onModelSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<AiApiKey?>(
      stream: AiDatabase.instance.aiApiKeyDao.watchByProvider(provider),
      builder: (ctx, keySnap) {
        final providerName =
            OpenAiProviderRegistry.allProviders[provider]?.name ?? provider;
        final model = onModelSelected != null
            ? (currentModel ?? '')
            : (keySnap.data?.model ?? '');
        final displayName = model.isEmpty
            ? t.set
            : (model.contains('/') ? model.split('/').last : model);
        final chipLabel = '$providerName · $displayName';

        return StreamBuilder<List<AiModel>>(
          stream: (AiDatabase.instance.select(
            AiDatabase.instance.aiModels,
          )..where((t) => t.provider.equals(provider))).watch(),
          builder: (ctx, modelSnap) {
            final models = modelSnap.data ?? [];

            final chip = Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.model_training,
                    size: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      chipLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (models.length > 1) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_up,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            );

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showSheet(context),
              child: chip,
            );
          },
        );
      },
    );
  }
}
