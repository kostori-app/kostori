import 'package:kostori/foundation/ai_service/story.dart';
import 'package:kostori/skills/skill.dart';
import 'package:kostori/skills/skill_registry.dart';

/// 掷骰技能：让模型（NPC 判定 / 剧情判定）自己发起骰子判定，
/// 由项目负责掷骰并回传结果，避免模型自编点数。
///
/// 故事观可以在提示词里约定「需要判定时调用 roll_dice」。
class DiceSkill extends Skill {
  @override
  String get id => 'roll_dice';

  @override
  String get name => 'roll_dice';

  @override
  String get description =>
      '掷骰判定：剧情或 NPC 需要判定成败时调用，由系统掷骰并返回结果；'
      '不要自己编造点数。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'label': {'type': 'string', 'description': '判定名，如「力量检定」'},
      'dice': {'type': 'string', 'description': '骰子记法，如 1d20 / 2d6，默认 1d20'},
      'modifier': {'type': 'integer', 'description': '修正值，默认 0'},
      'dc': {'type': 'integer', 'description': '难度 DC，可省略'},
    },
    'required': ['label'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final label = arguments['label']?.toString().trim() ?? '';
    final dice = arguments['dice']?.toString().trim() ?? '1d20';
    final modifier = (arguments['modifier'] as num?)?.toInt() ?? 0;
    final dc = (arguments['dc'] as num?)?.toInt();
    // 与故事页面保持一致：使用当前故事的暴击/方向设置
    final roll = rollDice(
      dice,
      modifier: modifier,
      dc: dc,
      crits: SkillRegistry.instance.diceCrits,
      direction: SkillRegistry.instance.diceDirection,
    );
    return '${label.isEmpty ? '判定' : label}：${roll.detail}';
  }
}
