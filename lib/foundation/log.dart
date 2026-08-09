import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/io.dart';

enum LogSource {
  normal(null),
  net(Icons.wifi_rounded),
  hub(Icons.hub_rounded),
  source(Icons.source),
  stats(Icons.query_stats_outlined),
  player(Icons.display_settings_rounded),
  debug(Icons.bug_report_rounded);

  final IconData? icon;

  const LogSource(this.icon);
}

class LogItem {
  final LogLevel level;
  final String title;
  final String content;
  final LogSource source;
  final DateTime time = DateTime.now();

  @override
  toString() =>
      "${level.name} ${source != LogSource.normal ? '[${source.name}] ' : ''}$title $time \n$content\n\n";

  LogItem(
    this.level,
    this.title,
    this.content, {
    this.source = LogSource.normal,
  });
}

enum LogLevel { error, warning, info }

class Log {
  static final _controller = StreamController<List<LogItem>>.broadcast();

  static Stream<List<LogItem>> get stream => _controller.stream;
  static final List<LogItem> _logs = <LogItem>[];

  static List<LogItem> get logs => _logs;

  static const maxLogLength = 3000;

  static const maxLogNumber = 500;

  static bool ignoreLimitation = false;

  static bool isMuted = false;

  /// 是否对日志中的隐私项（token/密钥/密码等）打码。
  /// release/profile 默认开启；debug 默认关闭，避免影响调试时查看真实内容。
  /// 可通过设置「日志隐私保护」手动切换。
  static bool get redactSensitive {
    final v = appdata.implicitData['redactSensitiveLogs'];
    if (v is bool) return v;
    return !kDebugMode;
  }

  static set redactSensitive(bool v) {
    appdata.implicitData['redactSensitiveLogs'] = v;
    appdata.writeImplicitData();
  }

  /// 隐私敏感字段识别正则（key=value / key: value / "key":"value" / Bearer xxxx）
  static final RegExp _sensitivePattern = RegExp(
    r'(?:^|["\s,;])'
    r'(token|password|passwd|secret|apikey|api[_ -]?key|access[_ -]?key'
    r'|access[_ -]?key[_ -]?secret|authorization|bearer|auth|auth[_ -]?key'
    r'|private[_ -]?key|session|session[_ -]?id|cookie|set[-_]cookie|x[-_]api[-_]key)'
    r'["\s]*[:=]["\s]*([^\s,;&"\x27]+)',
    caseSensitive: false,
  );

  /// 认证头 Bearer token：`Authorization: Bearer token`
  static final RegExp _bearerTokenPattern = RegExp(
    r'(bearer["\s]*[:=]?["\s]+)([^\s,;&"\x27]+)',
    caseSensitive: false,
  );

  /// 将文本中的敏感字段值打码。默认掩码保留首尾少量字符以辅助定位。
  static String redact(String text) {
    if (text.isEmpty || !redactSensitive) return text;
    text = text.replaceAllMapped(_bearerTokenPattern, (m) {
      final prefix = m
          .group(0)!
          .substring(0, m.group(0)!.length - m.group(2)!.length);
      return '$prefix${_maskValue(m.group(2)!)}';
    });
    return text.replaceAllMapped(_sensitivePattern, (m) {
      // 取字段名到值之间（含字段名、冒号等），保留结构，仅掩码值
      final valueStart = m.group(0)!.indexOf(m.group(2)!);
      final prefix = m.group(0)!.substring(0, valueStart < 0 ? 0 : valueStart);
      return '$prefix${_maskValue(m.group(2)!)}';
    });
  }

  static String _maskValue(String val) {
    if (val.length <= 4) return '***';
    return '${val.substring(0, 2)}****${val.substring(val.length - 2)}';
  }

  static void printWarning(String text) {
    debugPrint('\x1B[33m$text\x1B[0m');
  }

  static void printError(String text) {
    debugPrint('\x1B[31m$text\x1B[0m');
  }

  static IOSink? _file;

  static void addLog(
    LogLevel level,
    String title,
    String content, {
    LogSource source = LogSource.normal,
  }) {
    if (isMuted) return;
    if (_file == null && App.isInitialized) {
      Directory dir;
      if (App.isAndroid) {
        dir = Directory(App.externalStoragePath!);
      } else {
        dir = Directory(App.dataPath);
      }
      var file = dir.joinFile("logs.txt");
      _file = file.openWrite();
    }

    if (redactSensitive) {
      title = redact(title);
      content = redact(content);
    }

    if (!ignoreLimitation && content.length > maxLogLength) {
      content = "${content.substring(0, maxLogLength)}...";
    }

    switch (level) {
      case LogLevel.error:
        printError(content);
      case LogLevel.warning:
        printWarning(content);
      case LogLevel.info:
        if (kDebugMode) {
          debugPrint(content);
        }
    }

    var newLog = LogItem(level, title, content, source: source);

    if (newLog == _logs.lastOrNull) {
      return;
    }

    _logs.add(newLog);
    _controller.add(List.unmodifiable(_logs));
    if (_file != null) {
      _file!.write(newLog.toString());
    }
    if (_logs.length > maxLogNumber) {
      var res = _logs.remove(
        _logs.firstWhereOrNull((element) => element.level == LogLevel.info),
      );
      if (!res) {
        _logs.removeAt(0);
      }
    }
  }

  static void info(String title, String content) {
    addLog(LogLevel.info, title, content);
  }

  static void warning(String title, String content) {
    addLog(LogLevel.warning, title, content);
  }

  static void error(String title, Object content, [Object? stackTrace]) {
    var info = content.toString();
    if (stackTrace != null) {
      info += "\n${stackTrace.toString()}";
    }
    addLog(LogLevel.error, title, info);
  }

  static void clear() => _logs.clear();

  @override
  String toString() {
    var res = "Logs\n\n";
    for (var log in _logs) {
      res += log.toString();
    }
    return res;
  }
}

/// 网络请求日志
class NetLog {
  NetLog._();

  static const _settingKey = 'enableNetLog';

  static bool get enabled => appdata.settings[_settingKey] as bool? ?? false;

  static void info(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.info, title, content, source: LogSource.net);
  }

  static void warning(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.warning, title, content, source: LogSource.net);
  }

  static void error(String title, Object content, [Object? stackTrace]) {
    if (!enabled) return;
    var info = content.toString();
    if (stackTrace != null) info += "\n${stackTrace.toString()}";
    Log.addLog(LogLevel.error, title, info, source: LogSource.net);
  }

  static void log(LogLevel level, String title, String content) {
    if (!enabled) return;
    Log.addLog(level, title, content, source: LogSource.net);
  }
}

/// Hub / WebSocket 日志
class HubLog {
  HubLog._();

  static const _settingKey = 'enableHubLog';

  static bool get enabled => appdata.settings[_settingKey] as bool? ?? false;

  static void info(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.info, title, content, source: LogSource.hub);
  }

  static void warning(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.warning, title, content, source: LogSource.hub);
  }

  static void error(String title, Object content, [Object? stackTrace]) {
    if (!enabled) return;
    var info = content.toString();
    if (stackTrace != null) info += "\n${stackTrace.toString()}";
    Log.addLog(LogLevel.error, title, info, source: LogSource.hub);
  }
}

class SourceLog {
  SourceLog._();

  static const _settingKey = 'enableSourceLog';

  static bool get enabled => appdata.settings[_settingKey] as bool? ?? false;

  static void info(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.info, title, content, source: LogSource.source);
  }

  static void warning(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.warning, title, content, source: LogSource.source);
  }

  static void error(String title, Object content, [Object? stackTrace]) {
    if (!enabled) return;
    var info = content.toString();
    if (stackTrace != null) info += "\n${stackTrace.toString()}";
    Log.addLog(LogLevel.error, title, info, source: LogSource.source);
  }

  static void log(LogLevel level, String title, String content) {
    if (!enabled) return;
    Log.addLog(level, title, content, source: LogSource.source);
  }
}

class StatsLog {
  StatsLog._();

  static const _settingKey = 'enableStatsLog';

  static bool get enabled => appdata.settings[_settingKey] as bool? ?? false;

  static void info(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.info, title, content, source: LogSource.stats);
  }

  static void warning(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.warning, title, content, source: LogSource.stats);
  }

  static void error(String title, Object content, [Object? stackTrace]) {
    if (!enabled) return;
    var info = content.toString();
    if (stackTrace != null) info += "\n${stackTrace.toString()}";
    Log.addLog(LogLevel.error, title, info, source: LogSource.stats);
  }
}

class PlayLog {
  PlayLog._();

  static const _settingKey = 'enablePlayerLog';

  static bool get enabled => appdata.settings[_settingKey] as bool? ?? false;

  static void info(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.info, title, content, source: LogSource.player);
  }

  static void warning(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.warning, title, content, source: LogSource.player);
  }

  static void error(String title, Object content, [Object? stackTrace]) {
    if (!enabled) return;
    var info = content.toString();
    if (stackTrace != null) info += "\n${stackTrace.toString()}";
    Log.addLog(LogLevel.error, title, info, source: LogSource.player);
  }
}

class DebugLog {
  DebugLog._();

  static const _settingKey = 'debugInfo';

  static bool get enabled => appdata.settings[_settingKey] as bool? ?? false;

  static void info(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.info, title, content, source: LogSource.debug);
  }

  static void warning(String title, String content) {
    if (!enabled) return;
    Log.addLog(LogLevel.warning, title, content, source: LogSource.debug);
  }

  static void error(String title, Object content, [Object? stackTrace]) {
    if (!enabled) return;
    var info = content.toString();
    if (stackTrace != null) info += "\n${stackTrace.toString()}";
    Log.addLog(LogLevel.error, title, info, source: LogSource.debug);
  }
}
