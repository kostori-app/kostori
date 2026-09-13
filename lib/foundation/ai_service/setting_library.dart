// 设定库：可复用的设定条目（词条 / 称号 / 职业 / 据点）。
// 全局维护，故事通过 id 引用（类似世界书库 / 提示词库）。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/ai_service/story.dart';

/// 设定条目类型
class SettingTypes {
  static const codex = 'codex';
  static const title = 'title';
  static const job = 'job';
  static const facility = 'facility';

  static const all = [codex, title, job, facility];
}

/// 单条设定：类型 + 名称 + 类型相关的 payload（JSON）
class SettingEntry {
  final String id;

  /// codex | title | job | facility
  final String type;
  final String name;
  final Map<String, dynamic> payload;

  const SettingEntry({
    required this.id,
    required this.type,
    required this.name,
    this.payload = const {},
  });

  factory SettingEntry.fromJson(Map<String, dynamic> json) => SettingEntry(
    id:
        json['id']?.toString() ??
        'set_${DateTime.now().microsecondsSinceEpoch}',
    type: json['type']?.toString() ?? SettingTypes.codex,
    name: json['name']?.toString() ?? '',
    payload: json['payload'] is Map
        ? (json['payload'] as Map).cast<String, dynamic>()
        : const {},
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'payload': payload,
  };

  SettingEntry copyWith({
    String? type,
    String? name,
    Map<String, dynamic>? payload,
  }) => SettingEntry(
    id: id,
    type: type ?? this.type,
    name: name ?? this.name,
    payload: payload ?? this.payload,
  );

  /// 解析为词条定义
  StoryDefinition? toCodex() => type == SettingTypes.codex
      ? StoryDefinition.fromJson(payload)
      : null;

  /// 解析为称号定义
  StoryTitle? toTitle() =>
      type == SettingTypes.title ? StoryTitle.fromJson(payload) : null;

  /// 解析为职业定义
  StoryJob? toJob() =>
      type == SettingTypes.job ? StoryJob.fromJson(payload) : null;

  /// 解析为据点设施定义
  StoryFacility? toFacility() =>
      type == SettingTypes.facility ? StoryFacility.fromJson(payload) : null;
}

/// 设定库存储：`dataPath/setting_library/<id>.json`
class SettingLibraryStore extends ChangeNotifier {
  static final SettingLibraryStore instance = SettingLibraryStore._();

  SettingLibraryStore._();

  static const _dirName = 'setting_library';

  List<SettingEntry> _items = [];
  bool _loaded = false;

  List<SettingEntry> get items => List.unmodifiable(_items);

  bool get isInitialized => _loaded;

  List<SettingEntry> byType(String type) => [
    for (final e in _items)
      if (e.type == type) e,
  ];

  SettingEntry? find(String id) {
    for (final e in _items) {
      if (e.id == id) return e;
    }
    return null;
  }

  String get dirPath => '${App.dataPath}/$_dirName';

  Future<void> init() async {
    _items = [];
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await entity.readAsString());
          if (json is Map) {
            _items.add(SettingEntry.fromJson(json.cast<String, dynamic>()));
          }
        } catch (_) {}
      }
    } catch (_) {}
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

  Future<void> upsert(SettingEntry entry) async {
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File(
      '$dirPath/${entry.id}.json',
    ).writeAsString(jsonEncode(entry.toJson()));
    final idx = _items.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _items[idx] = entry;
    } else {
      _items.add(entry);
    }
    notifyListeners();
  }

  Future<bool> remove(String id) async {
    final file = File('$dirPath/$id.json');
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    final before = _items.length;
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    return _items.length != before;
  }
}

/// 把设定库中选中的条目并入故事（词条 / 称号 / 职业 / 据点）
Story mergeSettingLibrary(Story story, Iterable<SettingEntry> entries) {
  var codex = [...story.codex];
  var titles = [...story.titles];
  final facilities = [...story.facilities];
  StoryJob? job = story.job;

  final codexKeys = {for (final d in codex) '${d.kind}\u0000${d.key}'};
  final titleKeys = {for (final x in titles) x.key};
  final facilityKeys = {for (final f in facilities) f.key};

  for (final e in entries) {
    switch (e.type) {
      case SettingTypes.codex:
        final d = e.toCodex();
        if (d != null && codexKeys.add('${d.kind}\u0000${d.key}')) {
          codex.add(d);
        }
      case SettingTypes.title:
        final x = e.toTitle();
        if (x != null && titleKeys.add(x.key)) titles.add(x);
      case SettingTypes.job:
        job ??= e.toJob();
      case SettingTypes.facility:
        final f = e.toFacility();
        if (f != null && facilityKeys.add(f.key)) facilities.add(f);
    }
  }
  return story.copyWith(
    codex: codex,
    titles: titles,
    job: job,
    facilities: facilities,
  );
}
