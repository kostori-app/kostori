// 日志查询技能：让 AI 对话能读取软件内存中的最近日志，用于排查问题。

import 'package:kostori/foundation/log.dart';
import 'package:kostori/skills/skill.dart';

class QueryLogsSkill extends Skill {
  @override
  String get id => 'query_logs';

  @override
  String get name => '查询日志';

  @override
  String get description =>
      '查询软件运行日志（内存中的最近日志）。可按级别（error/warning/info）、关键词、'
      '来源（net/hub/player/source/stats/debug/normal）筛选，返回最近的若干条，用于排查问题。'
      '例如"最近有没有报错"、"查询网络日志"、"搜一下包含 xxx 的日志"。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'level': {
        'type': 'string',
        'description': '日志级别：error / warning / info，可为空（不限）',
      },
      'keyword': {'type': 'string', 'description': '关键词（匹配标题或内容），可为空'},
      'source': {
        'type': 'string',
        'description':
            '来源：normal / net / hub / player / source / stats / debug，可为空（不限）',
      },
      'count': {'type': 'integer', 'description': '返回条数，默认 20，最大 50'},
    },
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final levelStr = (arguments['level'] as String? ?? '').trim().toLowerCase();
    final keyword = (arguments['keyword'] as String? ?? '').trim();
    final sourceStr = (arguments['source'] as String? ?? '')
        .trim()
        .toLowerCase();
    final count = arguments['count'] is int
        ? (arguments['count'] as int).clamp(1, 50)
        : 20;

    LogLevel? level = switch (levelStr) {
      'error' => LogLevel.error,
      'warning' || 'warn' => LogLevel.warning,
      'info' => LogLevel.info,
      _ => null,
    };

    LogSource? source = LogSource.values
        .where((s) => s.name == sourceStr)
        .firstOrNull;

    final matched = Log.logs.where((log) {
      if (level != null && log.level != level) return false;
      if (source != null && log.source != source) return false;
      if (keyword.isNotEmpty &&
          !log.title.contains(keyword) &&
          !log.content.contains(keyword)) {
        return false;
      }
      return true;
    }).toList();

    if (matched.isEmpty) {
      final scope = <String>[];
      if (level != null) scope.add(level.name);
      if (source != null) scope.add('来源=${source.name}');
      if (keyword.isNotEmpty) scope.add('关键词"$keyword"');
      return '没有匹配的日志${scope.isEmpty ? '' : '（${scope.join(' / ')}）'}。';
    }

    // 取最近的 N 条
    final recent = matched.length > count
        ? matched.sublist(matched.length - count)
        : matched;

    final sb = StringBuffer();
    sb.writeln('共匹配 ${matched.length} 条，返回最近 ${recent.length} 条：');
    for (var i = recent.length - 1; i >= 0; i--) {
      final log = recent[i];
      final time =
          '${log.time.month}-${log.time.day} '
          '${log.time.hour.toString().padLeft(2, '0')}:'
          '${log.time.minute.toString().padLeft(2, '0')}:'
          '${log.time.second.toString().padLeft(2, '0')}';
      final src = log.source != LogSource.normal ? '[${log.source.name}] ' : '';
      var content = log.content.replaceAll('\n', ' ');
      if (content.length > 300) {
        content = '${content.substring(0, 300)}...';
      }
      sb.writeln('${log.level.name} $src$time ${log.title}');
      if (content.isNotEmpty) sb.writeln('  $content');
    }
    return sb.toString();
  }
}
