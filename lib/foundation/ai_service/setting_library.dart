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

  /// 分组（便于批量选择 / 归类，空 = 未分组）
  final String group;

  /// 所属设定书（文件）id
  final String bookId;
  final Map<String, dynamic> payload;

  const SettingEntry({
    required this.id,
    required this.type,
    required this.name,
    this.group = '',
    this.bookId = '',
    this.payload = const {},
  });

  factory SettingEntry.fromJson(Map<String, dynamic> json) => SettingEntry(
    id:
        json['id']?.toString() ??
        'set_${DateTime.now().microsecondsSinceEpoch}',
    type: json['type']?.toString() ?? SettingTypes.codex,
    name: json['name']?.toString() ?? '',
    group: json['group']?.toString() ?? '',
    bookId: json['bookId']?.toString() ?? '',
    payload: json['payload'] is Map
        ? (json['payload'] as Map).cast<String, dynamic>()
        : const {},
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    if (group.isNotEmpty) 'group': group,
    if (bookId.isNotEmpty) 'bookId': bookId,
    'payload': payload,
  };

  SettingEntry copyWith({
    String? type,
    String? name,
    String? group,
    String? bookId,
    Map<String, dynamic>? payload,
  }) => SettingEntry(
    id: id,
    type: type ?? this.type,
    name: name ?? this.name,
    group: group ?? this.group,
    bookId: bookId ?? this.bookId,
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

/// 一本设定书（文件）：包含多条设定条目
class SettingBook {
  final String id;
  final String name;
  final List<SettingEntry> entries;

  const SettingBook({
    required this.id,
    this.name = '',
    this.entries = const [],
  });

  factory SettingBook.fromJson(Map<String, dynamic> json) => SettingBook(
    id:
        json['id']?.toString() ??
        'book_${DateTime.now().millisecondsSinceEpoch}',
    name: json['name']?.toString() ?? '',
    entries: [
      for (final e in (json['entries'] as List? ?? const []))
        if (e is Map) SettingEntry.fromJson(e.cast<String, dynamic>()),
    ],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'entries': [for (final e in entries) e.toJson()],
  };
}

/// 设定库存储：`dataPath/setting_library/<bookId>.json`（一本书一个文件、内含多条条目）
class SettingLibraryStore extends ChangeNotifier {
  static final SettingLibraryStore instance = SettingLibraryStore._();

  SettingLibraryStore._();

  static const _dirName = 'setting_library';

  List<SettingBook> _books = [];
  bool _loaded = false;

  /// 所有条目（跨书展平），保持向后兼容
  List<SettingEntry> get items => [for (final b in _books) ...b.entries];

  /// 全部设定书
  List<SettingBook> get books => List.unmodifiable(_books);

  SettingBook? bookById(String id) {
    for (final b in _books) {
      if (b.id == id) return b;
    }
    return null;
  }

  bool get isInitialized => _loaded;

  List<SettingEntry> byType(String type) => [
    for (final e in items)
      if (e.type == type) e,
  ];

  SettingEntry? find(String id) {
    for (final e in items) {
      if (e.id == id) return e;
    }
    return null;
  }

  String get dirPath => '${App.dataPath}/$_dirName';

  Future<void> init() async {
    _books = [];
    final legacy = <SettingEntry>[];
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await entity.readAsString());
          if (json is! Map) continue;
          final map = json.cast<String, dynamic>();
          final fileName = entity.uri.pathSegments.last;
          final fileId = fileName.substring(0, fileName.length - 5);
          if (map['entries'] is List) {
            // 新格式：一本书
            final book = SettingBook.fromJson(map);
            _books.add(
              SettingBook(
                id: fileId,
                name: book.name,
                entries: [
                  for (final e in book.entries) e.copyWith(bookId: fileId),
                ],
              ),
            );
          } else {
            // 旧格式：一条一个文件
            legacy.add(SettingEntry.fromJson(map));
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (legacy.isNotEmpty) await _migrateLegacyEntries(legacy);
    _loaded = true;
    notifyListeners();
  }

  /// 旧版「一条目一文件」→ 按分组合并成一本书
  Future<void> _migrateLegacyEntries(List<SettingEntry> legacy) async {
    final grouped = <String, List<SettingEntry>>{};
    for (final e in legacy) {
      grouped.putIfAbsent(e.group.trim(), () => []).add(e);
    }
    var i = 0;
    for (final group in grouped.entries) {
      final bookId = 'book_${DateTime.now().millisecondsSinceEpoch}_${i++}';
      final book = SettingBook(
        id: bookId,
        name: group.key.isEmpty ? '设定库' : group.key,
        entries: [for (final e in group.value) e.copyWith(bookId: bookId)],
      );
      _books.add(book);
      await _writeBook(book);
    }
    for (final e in legacy) {
      final f = File('$dirPath/${e.id}.json');
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> _writeBook(SettingBook book) async {
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File(
      '$dirPath/${book.id}.json',
    ).writeAsString(jsonEncode(book.toJson()));
  }

  void _deleteBookFile(String bookId) {
    final f = File('$dirPath/$bookId.json');
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  Future<void> reload() async {
    _loaded = false;
    await init();
  }

  /// 新增 / 更新一条条目：默认并入其所属书，未指定则用最后一本 / 新建一本
  Future<void> upsert(SettingEntry entry, {String? bookId}) async {
    await ensureLoaded();
    final targetId = bookId ?? entry.bookId;
    var book = targetId.isEmpty ? null : bookById(targetId);
    if (book == null) {
      if (_books.isNotEmpty && targetId.isEmpty && bookId == null) {
        book = _books.last;
      } else {
        book = await createBook(name: '设定库');
      }
    }
    final target = book.id;
    final e = entry.copyWith(bookId: target);
    for (var i = 0; i < _books.length; i++) {
      final b = _books[i];
      if (b.id == target) continue;
      final filtered = b.entries.where((x) => x.id != e.id).toList();
      if (filtered.length != b.entries.length) {
        _books[i] = SettingBook(id: b.id, name: b.name, entries: filtered);
        await _writeBook(_books[i]);
      }
    }
    final idx = _books.indexWhere((b) => b.id == target);
    final list = [..._books[idx].entries];
    final at = list.indexWhere((x) => x.id == e.id);
    if (at >= 0) {
      list[at] = e;
    } else {
      list.add(e);
    }
    _books[idx] = SettingBook(
      id: _books[idx].id,
      name: _books[idx].name,
      entries: list,
    );
    await _writeBook(_books[idx]);
    notifyListeners();
  }

  /// 整本书写入（新建 / 覆盖）
  Future<void> upsertBook(SettingBook book) async {
    await ensureLoaded();
    final normalized = SettingBook(
      id: book.id,
      name: book.name,
      entries: [for (final e in book.entries) e.copyWith(bookId: book.id)],
    );
    final idx = _books.indexWhere((b) => b.id == book.id);
    if (idx >= 0) {
      _books[idx] = normalized;
    } else {
      _books.add(normalized);
    }
    await _writeBook(normalized);
    notifyListeners();
  }

  /// 新建一本空书
  Future<SettingBook> createBook({String name = ''}) async {
    await ensureLoaded();
    final book = SettingBook(
      id: 'book_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    _books.add(book);
    await _writeBook(book);
    notifyListeners();
    return book;
  }

  Future<bool> remove(String id) async {
    await ensureLoaded();
    var changed = false;
    for (var i = 0; i < _books.length; i++) {
      final b = _books[i];
      final filtered = b.entries.where((e) => e.id != id).toList();
      if (filtered.length == b.entries.length) continue;
      _books[i] = SettingBook(id: b.id, name: b.name, entries: filtered);
      await _writeBook(_books[i]);
      changed = true;
    }
    if (changed) notifyListeners();
    return changed;
  }

  Future<void> removeBook(String bookId) async {
    await ensureLoaded();
    _books.removeWhere((b) => b.id == bookId);
    _deleteBookFile(bookId);
    notifyListeners();
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
