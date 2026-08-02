import 'package:kostori/foundation/ai_service/ai_base.dart';

/// 技能抽象：可被模型通过 function calling 调用的能力单元。
///
/// 每个技能需要声明名称、描述与 OpenAI 风格的 JSON Schema 入参，
/// 并提供 [execute] 实现。参数校验失败时抛出 [SkillException]。
abstract class Skill {
  /// 技能唯一标识（即模型可见的工具名）
  String get id;

  /// 人类可读名称
  String get name;

  /// 供模型判断何时调用的描述
  String get description;

  /// OpenAI function schema（`type: object` + `properties` + `required`）
  Map<String, dynamic> get inputSchema;

  /// 执行技能，返回给模型的文本结果
  Future<String> execute(Map<String, dynamic> arguments);

  AiToolDefinition toAiTool() => AiToolDefinition(
    name: id,
    description: description,
    parameters: inputSchema,
  );
}

/// 技能参数校验 / 执行失败时抛出，错误信息可直接反馈给模型
class SkillException implements Exception {
  final String message;

  SkillException(this.message);

  @override
  String toString() => message;
}

/// 对 [Skill.inputSchema]（JSON Schema）做基础校验：
/// 必填字段是否存在、已声明字段类型是否匹配。
Map<String, dynamic> validateSkillArguments(
  Map<String, dynamic> schema,
  Map<String, dynamic> arguments,
) {
  if (schema.isEmpty) return arguments;
  final required = schema['required'];
  if (required is List) {
    for (final key in required.whereType<String>()) {
      if (!arguments.containsKey(key) || arguments[key] == null) {
        throw SkillException('缺少必填参数: $key');
      }
    }
  }
  final properties = schema['properties'];
  if (properties is Map) {
    arguments.forEach((key, value) {
      if (value == null) return;
      final prop = properties[key];
      if (prop is! Map) return;
      final type = prop['type'];
      if (type is! String || type.isEmpty) return;
      final ok = switch (type) {
        'string' => value is String,
        'integer' => value is int,
        'number' => value is num,
        'boolean' => value is bool,
        'array' => value is List,
        'object' => value is Map,
        _ => true,
      };
      if (!ok) {
        throw SkillException('参数 $key 应为 $type 类型，实际为 ${value.runtimeType}');
      }
    });
  }
  return arguments;
}
