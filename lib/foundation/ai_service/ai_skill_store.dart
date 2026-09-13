// AI 技能：从 ai_database.db 迁出，改为独立文件存储
// （dataPath/ai_skills/<key>.json），并纳入选择性同步。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/app.dart';

class AiSkillEntry {
  final String key;
  final String name;
  final String description;
  final String systemPrompt;
  final bool isBuiltin;
  final bool isEnabled;
  final int createdAt;

  const AiSkillEntry({
    required this.key,
    required this.name,
    this.description = '',
    this.systemPrompt = '',
    this.isBuiltin = false,
    this.isEnabled = true,
    this.createdAt = 0,
  });

  factory AiSkillEntry.fromJson(Map<String, dynamic> json) => AiSkillEntry(
    key: json['key']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    systemPrompt: json['systemPrompt']?.toString() ?? '',
    isBuiltin: json['isBuiltin'] as bool? ?? false,
    isEnabled: json['isEnabled'] as bool? ?? true,
    createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'description': description,
    'systemPrompt': systemPrompt,
    'isBuiltin': isBuiltin,
    'isEnabled': isEnabled,
    'createdAt': createdAt,
  };

  AiSkillEntry copyWith({
    String? key,
    String? name,
    String? description,
    String? systemPrompt,
    bool? isBuiltin,
    bool? isEnabled,
    int? createdAt,
  }) => AiSkillEntry(
    key: key ?? this.key,
    name: name ?? this.name,
    description: description ?? this.description,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    isBuiltin: isBuiltin ?? this.isBuiltin,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// 技能存储：`dataPath/ai_skills/<key>.json`
class AiSkillStore extends ChangeNotifier {
  static final AiSkillStore instance = AiSkillStore._();

  AiSkillStore._();

  static const _dirName = 'ai_skills';

  final List<AiSkillEntry> _items = [];
  bool _loaded = false;

  List<AiSkillEntry> get items => List.unmodifiable(_items);

  List<AiSkillEntry> get enabled => [
    for (final s in _items)
      if (s.isEnabled) s,
  ];

  String get dirPath => '${App.dataPath}/$_dirName';

  AiSkillEntry? find(String key) {
    for (final s in _items) {
      if (s.key == key) return s;
    }
    return null;
  }

  Future<void> init() async {
    _items.clear();
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await entity.readAsString());
          if (json is Map) {
            _items.add(AiSkillEntry.fromJson(json.cast<String, dynamic>()));
          }
        } catch (_) {}
      }
    } catch (_) {}
    _items.sort((a, b) => a.name.compareTo(b.name));
    _loaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  Future<void> reload() async {
    _loaded = false;
    await init();
  }

  Future<void> upsert(AiSkillEntry entry) async {
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File(
      '$dirPath/${entry.key}.json',
    ).writeAsString(jsonEncode(entry.toJson()));
    final idx = _items.indexWhere((s) => s.key == entry.key);
    if (idx >= 0) {
      _items[idx] = entry;
    } else {
      _items.add(entry);
    }
    _items.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> putAll(Iterable<AiSkillEntry> entries) async {
    for (final e in entries) {
      await upsert(e);
    }
  }

  Future<void> setEnabled(String key, {required bool enabled}) async {
    final s = find(key);
    if (s == null) return;
    await upsert(s.copyWith(isEnabled: enabled));
  }

  Future<void> remove(String key) async {
    final f = File('$dirPath/$key.json');
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    _items.removeWhere((s) => s.key == key);
    notifyListeners();
  }

  /// 一次性迁移：把 ai_database.db 里的技能写入独立文件，并清空原表
  Future<void> migrateFromDb() async {
    await ensureLoaded();
    try {
      final rows = await AiDatabase.instance.aiSkillDao.getAll();
      if (rows.isEmpty) return;
      for (final r in rows) {
        if (find(r.key) == null) {
          await upsert(
            AiSkillEntry(
              key: r.key,
              name: r.name,
              description: r.description ?? '',
              systemPrompt: r.systemPrompt,
              isBuiltin: r.isBuiltin,
              isEnabled: r.isEnabled,
              createdAt: r.createdAt.millisecondsSinceEpoch,
            ),
          );
        }
        await AiDatabase.instance.aiSkillDao.deleteById(r.id);
      }
    } catch (_) {}
  }
}
