part of 'package:kostori/pages/ai_hub/ai_hub_page.dart';

IconData _storyActionIcon(String name) => switch (name) {
  'use' => Icons.play_arrow_outlined,
  'drop' => Icons.delete_outline,
  'rest' => Icons.bedtime_outlined,
  'move' => Icons.directions_walk,
  'inspect' => Icons.search,
  'trade' => Icons.swap_horiz,
  'talk' => Icons.chat_bubble_outline,
  'fight' => Icons.sports_martial_arts_outlined,
  'map' => Icons.map_outlined,
  _ => Icons.bolt_outlined,
};

IconData _codexIcon(String kind) => switch (kind) {
  'item' => Icons.inventory_2_outlined,
  'race' => Icons.groups_outlined,
  'trait' => Icons.psychology_alt_outlined,
  'talent' => Icons.auto_awesome_outlined,
  'skill' => Icons.sports_martial_arts_outlined,
  'body' => Icons.monitor_heart_outlined,
  _ => Icons.menu_book_outlined,
};

Widget _sectionTitle(String text, [IconData? icon]) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 16),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  ),
);

/// 面板数据源注册表：编辑器的选择项 / 图标 / 标签都由这里驱动，
/// 新增数据源时在此登记，并在 [_StoryDetailsSheetState._buildPanel] 补渲染分支。
typedef StoryPanelSourceDef = ({
  String id,
  IconData icon,
  String Function() label,
});

final List<StoryPanelSourceDef> storyPanelSources = [
  (id: 'resources', icon: Icons.favorite_border, label: () => t.storyResources),
  (
    id: 'attributes',
    icon: Icons.insights_outlined,
    label: () => t.storyAttributes,
  ),
  (
    id: 'skills',
    icon: Icons.sports_martial_arts_outlined,
    label: () => t.skills,
  ),
  (
    id: 'inventory',
    icon: Icons.inventory_2_outlined,
    label: () => t.storyInventory,
  ),
  (id: 'quests', icon: Icons.flag_outlined, label: () => t.storyQuests),
  (id: 'effects', icon: Icons.auto_awesome, label: () => t.storyEffects),
  (id: 'titles', icon: Icons.workspace_premium_outlined, label: () => t.storyTitles),
  (id: 'job', icon: Icons.badge_outlined, label: () => t.storyJob),
  (id: 'base', icon: Icons.home_work_outlined, label: () => t.storyBase),
  (id: 'codex', icon: Icons.menu_book_outlined, label: () => t.storyCodex),
  (id: 'variables', icon: Icons.tune, label: () => t.storyVariables),
  (id: 'equipment', icon: Icons.shield_outlined, label: () => t.storyEquipment),
  (
    id: 'combat',
    icon: Icons.local_fire_department_outlined,
    label: () => t.storyCombat,
  ),
  (
    id: 'achievements',
    icon: Icons.emoji_events_outlined,
    label: () => t.storyAchievements,
  ),
];

/// 好感度档位（范围 -100..100）
(String, Color) npcAffinityTier(int v, ColorScheme cs) {
  if (v <= -60) return (t.affinityHate, cs.error);
  if (v < -20) return (t.affinityCold, cs.outline);
  if (v < 20) return (t.affinityStranger, cs.onSurfaceVariant);
  if (v < 60) return (t.affinityFriend, cs.primary);
  return (t.affinityClose, cs.tertiary);
}

IconData? _panelIcon(String name) {
  if (name.isEmpty) return null;
  for (final s in storyPanelSources) {
    if (s.id == name) return s.icon;
  }
  return _storyActionIcon(name);
}

class _ParsedReply {
  final String narrative;
  final GameState? state;
  final List<String> choices;
  final List<StoryEvent> events;
  final List<VarOp> varOps;
  final StoryCheck? check;

  /// 结构化内容块（旁白 / 对白 / 事件 / 检定），渲染按块分派
  final List<StoryBlock> blocks;

  const _ParsedReply({
    required this.narrative,
    this.state,
    this.choices = const [],
    this.events = const [],
    this.varOps = const [],
    this.check,
    this.blocks = const [],
  });
}
