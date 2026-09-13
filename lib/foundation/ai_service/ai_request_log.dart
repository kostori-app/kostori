// AI 请求日志：记录每次对话/任务的请求与响应，便于排查问题。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';

class AiRequestLogEntry {
  final DateTime time;
  final String provider;
  final String? model;
  final String taskType;
  final String request;
  final String response;
  final String? error;
  final int durationMs;
  final int? tokens;

  const AiRequestLogEntry({
    required this.time,
    required this.provider,
    this.model,
    this.taskType = 'chat',
    this.request = '',
    this.response = '',
    this.error,
    this.durationMs = 0,
    this.tokens,
  });

  factory AiRequestLogEntry.fromJson(Map<String, dynamic> json) =>
      AiRequestLogEntry(
        time: DateTime.tryParse(json['time']?.toString() ?? '') ??
            DateTime.now(),
        provider: json['provider']?.toString() ?? '',
        model: json['model']?.toString(),
        taskType: json['taskType']?.toString() ?? 'chat',
        request: json['request']?.toString() ?? '',
        response: json['response']?.toString() ?? '',
        error: json['error']?.toString(),
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        tokens: (json['tokens'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'provider': provider,
    if (model != null) 'model': model,
    'taskType': taskType,
    'request': request,
    'response': response,
    if (error != null) 'error': error,
    'durationMs': durationMs,
    if (tokens != null) 'tokens': tokens,
  };
}

class AiRequestLogService extends ChangeNotifier {
  static final AiRequestLogService instance = AiRequestLogService._();

  AiRequestLogService._();

  static const _max = 50;
  static const _previewLimit = 4000;

  List<AiRequestLogEntry> _entries = [];
  bool _loaded = false;

  List<AiRequestLogEntry> get entries => List.unmodifiable(_entries);

  String get _path => '${App.dataPath}/ai_request_log.json';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = File(_path);
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          _entries = [
            for (final e in decoded)
              if (e is Map) AiRequestLogEntry.fromJson(e.cast<String, dynamic>()),
          ];
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  static String _preview(String text) => text.length <= _previewLimit
      ? text
      : '${text.substring(0, _previewLimit)}…';

  Future<void> add(AiRequestLogEntry entry) async {
    await ensureLoaded();
    _entries.insert(
      0,
      AiRequestLogEntry(
        time: entry.time,
        provider: entry.provider,
        model: entry.model,
        taskType: entry.taskType,
        request: _preview(entry.request),
        response: _preview(entry.response),
        error: entry.error,
        durationMs: entry.durationMs,
        tokens: entry.tokens,
      ),
    );
    if (_entries.length > _max) {
      _entries = _entries.sublist(0, _max);
    }
    notifyListeners();
    try {
      await File(
        _path,
      ).writeAsString(jsonEncode([for (final e in _entries) e.toJson()]));
    } catch (_) {}
  }

  Future<void> clear() async {
    _entries = [];
    notifyListeners();
    try {
      await File(_path).delete();
    } catch (_) {}
  }
}
