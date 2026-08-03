import 'dart:async';
import 'dart:typed_data';

import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/mcp_client.dart';
import 'package:kostori/skills/skill.dart';

/// 技能注册表：注册 / 查询 / 启用状态管理，并产出供模型使用的工具列表。
///
/// 启用状态由 AssistantProfile 联动（[setEnabled]），未显式设置的技能默认启用。
/// MCP 服务器工具通过 [syncMcp] 以适配器形式并入本注册表。
class SkillRegistry {
  static final SkillRegistry instance = SkillRegistry._();

  SkillRegistry._();

  final Map<String, Skill> _skills = {};
  final Map<String, bool> _enabled = {};
  final Set<String> _mcpSkills = {};

  /// 当前消息附带的图片字节（供如 recognize_anime 等需要图片的技能使用）
  Uint8List? _contextImage;

  void setContextImage(Uint8List? bytes) => _contextImage = bytes;

  Uint8List? get contextImage => _contextImage;

  /// 默认单技能执行超时
  static const Duration kDefaultTimeout = Duration(seconds: 10);

  void register(Skill skill) {
    _skills[skill.id] = skill;
  }

  void registerAll(Iterable<Skill> skills) {
    for (final s in skills) {
      register(s);
    }
  }

  void unregister(String id) {
    _skills.remove(id);
    _enabled.remove(id);
    _mcpSkills.remove(id);
  }

  Skill? find(String id) => _skills[id];

  List<Skill> get all => _skills.values.toList();

  // ── 启用状态 ──────────────────────────────

  void enable(String id) => _enabled[id] = true;

  void disable(String id) => _enabled[id] = false;

  bool isEnabled(String id) => _enabled[id] ?? true;

  /// 按集合整体设置启用状态（AssistrantProfile 联动）
  void setEnabled(Set<String> enabledIds) {
    for (final id in _skills.keys) {
      _enabled[id] = enabledIds.contains(id);
    }
  }

  void enableAll() => _enabled.clear();

  List<Skill> get enabled =>
      _skills.values.where((s) => isEnabled(s.id)).toList();

  // ── 工具产出 ──────────────────────────────

  /// 生成模型可见的工具定义 + 统一执行回调
  ({List<AiToolDefinition> tools, AiToolHandler handler}) buildTools() {
    final skills = enabled;
    return (
      tools: [for (final s in skills) s.toAiTool()],
      handler: (name, args) => execute(name, args),
    );
  }

  /// 执行技能：校验参数 → 超时保护 → 错误兜底
  Future<String> execute(String name, Map<String, dynamic> arguments) async {
    final skill = _skills[name];
    if (skill == null) throw SkillException('未找到技能: $name');
    final validated = validateSkillArguments(skill.inputSchema, arguments);
    return skill
        .execute(validated)
        .timeout(
          kDefaultTimeout,
          onTimeout: () {
            return '技能 $name 执行超时（超过 ${kDefaultTimeout.inSeconds} 秒）';
          },
        );
  }

  // ── MCP 兼容 ──────────────────────────────

  /// 将当前启用的 MCP 服务器工具以适配器形式并入注册表。
  /// 连不上的服务器由 [McpManager.loadTools] 自行跳过。
  Future<void> syncMcp() async {
    for (final id in _mcpSkills) {
      _skills.remove(id);
    }
    _mcpSkills.clear();
    final mcp = await McpManager.loadTools();
    if (mcp == null) return;
    for (final def in mcp.tools) {
      final adapter = McpSkillAdapter(def, mcp.handler);
      _skills[adapter.id] = adapter;
      _mcpSkills.add(adapter.id);
    }
  }
}

/// 将 MCP 工具包装为 [Skill]，实现"设置里配的 MCP 服务器也能被模型调用"
class McpSkillAdapter extends Skill {
  McpSkillAdapter(this.definition, this.handler);

  final AiToolDefinition definition;
  final AiToolHandler handler;

  @override
  String get id => definition.name;

  @override
  String get name => definition.name;

  @override
  String get description => definition.description;

  @override
  Map<String, dynamic> get inputSchema => definition.parameters;

  @override
  Future<String> execute(Map<String, dynamic> arguments) {
    return handler(id, arguments);
  }
}
