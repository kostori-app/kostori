import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/custom_markdown_widget.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/ai_service/ai_conversation_service.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/init.dart';
import 'package:kostori/pages/hub/hub_room_settings_sheet.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';

part 'ai_chat_page.dart';

part 'image_tag_page.dart';

part 'soul_profile_page.dart';

part 'summary_page.dart';

// ─────────────────────────────────────────────
// Config Keys
// ─────────────────────────────────────────────

const _soulProfileConfigKey = 'soul_profiler_v1';
const _imageTagConfigKey = 'image_tag_v1';
const _summaryConfigKey = 'summary_v1';

// ─────────────────────────────────────────────
// 入口 widget（原 _UserProfileAnalysis）
// ─────────────────────────────────────────────

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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI Hub'.tl,
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
// AI Hub 主页（模块列表）
// ─────────────────────────────────────────────

class AiHubPage extends StatelessWidget {
  const AiHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text('AI Hub'.tl)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _HubModuleCard(
            icon: Icons.psychology,
            title: '灵魂侧写'.tl,
            subtitle: '基于你的观看记录，解析你的番剧人格'.tl,
            color: const Color(0xFF6B8DE3),
            onTap: () => context.to(() => const SoulProfilePage()),
          ),
          const SizedBox(height: 8),
          _HubModuleCard(
            icon: Icons.brush,
            title: 'AI 绘画 Tag'.tl,
            subtitle: '根据你的喜好生成 AI 绘画风格标签'.tl,
            color: const Color(0xFFE36B8D),
            onTap: () => context.to(() => const ImageTagPage()),
          ),
          const SizedBox(height: 8),
          _HubModuleCard(
            icon: Icons.chat_bubble_outline,
            title: 'AI 对话'.tl,
            subtitle: '与 AI 进行有上下文记忆的多轮对话'.tl,
            color: const Color(0xFF4CAF50),
            onTap: () => context.to(() => const AiChatPage()),
          ),
          const SizedBox(height: 8),
          _HubModuleCard(
            icon: Icons.summarize_outlined,
            title: '周月总结'.tl,
            subtitle: '自动生成你的番剧观看周报/月报'.tl,
            color: const Color(0xFFFF9800),
            onTap: () => context.to(() => const SummaryPage()),
          ),
        ],
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
      title: 'AI Source'.tl,
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
    return HubSheet(
      title: 'History'.tl,
      icon: Icons.history,
      initialSize: 0.7,
      headerTrailing: TextButton.icon(
        icon: const Icon(Icons.delete_sweep, size: 18),
        label: Text('Clear All'.tl),
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
            return Center(child: Text('No history yet'.tl));
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
              child: CircularProgressIndicator(),
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
