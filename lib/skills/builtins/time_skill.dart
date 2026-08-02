import 'package:intl/intl.dart';
import 'package:kostori/skills/skill.dart';

/// 获取当前日期时间（演示零依赖技能）
class GetTimeSkill extends Skill {
  @override
  String get id => 'get_time';

  @override
  String get name => '当前时间';

  @override
  String get description => '获取当前日期、时间与星期，帮助回答时间相关的提问。';

  @override
  Map<String, dynamic> get inputSchema => {'type': 'object', 'properties': {}};

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final now = DateTime.now();
    final weekdays = const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '当前时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)} '
        '（${weekdays[now.weekday - 1]}）';
  }
}
