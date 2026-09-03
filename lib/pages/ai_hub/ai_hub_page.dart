import 'dart:async';
import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/ai_model_card.dart';
import 'package:kostori/components/bangumi_widget.dart';import 'package:kostori/components/components.dart';
import 'package:kostori/components/custom_markdown_widget.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_conversation_service.dart';
import 'package:kostori/foundation/ai_service/assistant_profile.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/ai_service/plugin_module.dart';
import 'package:kostori/foundation/ai_service/role_management.dart';
import 'package:kostori/foundation/app.dart';
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

part 'image_tag_page.dart';

part 'soul_profile_page.dart';

part 'summary_page.dart';

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

  Future<void> _deletePlugin(PluginModule plugin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.delete,
        content: Text(
          '${t.areYouSureYouWantToDeleteGeneric} "${plugin.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
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
    this.onDelete,
  });

  final PluginModule plugin;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
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
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: t.more,
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(t.edit)),
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

class PluginModulePage extends StatefulWidget {
  const PluginModulePage({super.key, required this.plugin});

  final PluginModule plugin;

  @override
  State<PluginModulePage> createState() => _PluginModulePageState();
}

class _PluginModulePageState extends State<PluginModulePage> {
  final TextEditingController _inputController = TextEditingController();
  String _source = 'siliconFlow';
  String? _result;
  bool _running = false;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      App.rootContext.showMessage(message: t.pleaseEnterTextToTranslate);
      return;
    }
    setState(() {
      _running = true;
      _error = null;
    });
    final result = await AiConversationService().runTask(
      provider: _source,
      taskType: 'plugin_${widget.plugin.id}',
      prompt: text,
      systemPrompt: widget.plugin.prompt.trim().isEmpty
          ? null
          : widget.plugin.prompt.trim(),
      sessionTitle: widget.plugin.name,
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      if (result.success) {
        _result = result.data;
      } else {
        _error = result.errorMessage ?? 'Error';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: Appbar(
        title: Text('${widget.plugin.icon} ${widget.plugin.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: t.back,
          onPressed: () => context.canPop() ? context.pop() : App.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 源选择
          _AiSourceSelector(
            selected: _source,
            onChanged: (v) => setState(() => _source = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            maxLines: 6,
            minLines: 3,
            decoration: InputDecoration(
              hintText: t.enterTextToTranslate,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                t.charCount(count: _inputController.text.length),
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _running ? null : _run,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: PolygonRefreshIndicator(),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_running ? t.processing : t.run),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant, width: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.output, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          t.output,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          tooltip: t.copy,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _result!),
                            );
                            if (mounted) {
                              App.rootContext.showMessage(message: t.copied);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: CustomMarkdownWidget(data: _result!),
                  ),
                ],
              ),
            ),
          ],
        ],
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

  bool get _isNew => widget.plugin == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

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
    return PopUpWidgetScaffold(
      title: _isNew ? t.addPlugin : t.editPlugin,
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
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _field(t.name, _nameCtrl),
                        _field(
                          t.pluginIcon,
                          _iconCtrl,
                          required: false,
                        ),
                        _field(
                          t.pluginDescription,
                          _descCtrl,
                          required: false,
                        ),
                        _field(
                          t.pluginPrompt,
                          _promptCtrl,
                          required: false,
                          multiline: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            t.pluginPromptHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
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
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = true,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        maxLines: multiline ? 8 : 1,
        decoration: InputDecoration(
          labelText: label,
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
  Future<({List<BangumiItem> likedItems, String animeNames, String topTags})>
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

    return (likedItems: likedItems, animeNames: animeNames, topTags: topTags);
  }
}

// ─────────────────────────────────────────────
// 共用：AI 源选择器
// ─────────────────────────────────────────────

class _AiSourceSelector extends StatelessWidget {
  const _AiSourceSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final sources = OpenAiProviderRegistry.allProviders.entries
        .map((e) => (e.key, e.value.name))
        .toList();

    return _AiCard(
      icon: Icons.psychology,
      title: t.aiSource,
      child: Wrap(
        spacing: 8,
        children: sources.map((s) {
          return ChoiceChip(
            label: Text(s.$2),
            selected: selected == s.$1,
            onSelected: (v) {
              if (v) onChanged(s.$1);
            },
          );
        }).toList(),
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
              maxHeight: MediaQuery.of(context).size.height * 0.7,
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
  const _ModelSelector({required this.provider, this.onProviderChanged});

  final String provider;

  /// 切换服务商回调（内置插件页用它同步 _source）
  final ValueChanged<String>? onProviderChanged;

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderModelSheet(
        provider: provider,
        onProviderChanged: onProviderChanged ?? (_) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<AiApiKey?>(
      stream: AiDatabase.instance.aiApiKeyDao.watchByProvider(provider),
      builder: (ctx, keySnap) {
        final currentModel = keySnap.data?.model ?? '...';
        final displayName = currentModel.contains('/')
            ? currentModel.split('/').last
            : currentModel;

        return StreamBuilder<List<AiModel>>(
          stream: (AiDatabase.instance.select(
            AiDatabase.instance.aiModels,
          )..where((t) => t.provider.equals(provider))).watch(),
          builder: (ctx, modelSnap) {
            final models = modelSnap.data ?? [];

            final chip = Container(
              constraints: const BoxConstraints(maxWidth: 150),
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
                      displayName,
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
