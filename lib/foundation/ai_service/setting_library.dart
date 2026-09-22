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

  /// 所属设定书（文件）ids：同一条目可属于多本（多对多归属）
  final List<String> bookIds;
  final Map<String, dynamic> payload;

  const SettingEntry({
    required this.id,
    required this.type,
    required this.name,
    this.group = '',
    this.bookIds = const [],
    this.payload = const {},
  });

  /// 主所属设定书（兼容旧逻辑 / 界面判断）
  String get bookId => bookIds.isEmpty ? '' : bookIds.first;

  factory SettingEntry.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? v) =>
        v is List ? v.whereType<String>().toList() : const <String>[];
    final ids = strList(json['bookIds']);
    return SettingEntry(
      id:
          json['id']?.toString() ??
          'set_${DateTime.now().microsecondsSinceEpoch}',
      type: json['type']?.toString() ?? SettingTypes.codex,
      name: json['name']?.toString() ?? '',
      group: json['group']?.toString() ?? '',
      bookIds: ids.isNotEmpty
          ? ids
          : ((json['bookId']?.toString() ?? '').isNotEmpty
                ? [json['bookId']!.toString()]
                : const []),
      payload: json['payload'] is Map
          ? (json['payload'] as Map).cast<String, dynamic>()
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    if (group.isNotEmpty) 'group': group,
    if (bookIds.isNotEmpty) 'bookIds': bookIds,
    if (bookId.isNotEmpty) 'bookId': bookId,
    'payload': payload,
  };

  SettingEntry copyWith({
    String? type,
    String? name,
    String? group,
    List<String>? bookIds,
    Map<String, dynamic>? payload,
  }) => SettingEntry(
    id: id,
    type: type ?? this.type,
    name: name ?? this.name,
    group: group ?? this.group,
    bookIds: bookIds ?? this.bookIds,
    payload: payload ?? this.payload,
  );

  /// 解析为词条定义
  StoryDefinition? toCodex() =>
      type == SettingTypes.codex ? StoryDefinition.fromJson(payload) : null;

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

  /// 所有条目（跨书去重：同一条目可属于多本，只返回一份）
  List<SettingEntry> get items {
    final seen = <String>{};
    return [
      for (final b in _books)
        for (final e in b.entries)
          if (seen.add(e.id)) e,
    ];
  }

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
    final rawBooks = <SettingBook>[];
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
            // 一本书（条目可能同时属于多本，文件间去重合并）
            final book = SettingBook.fromJson(map);
            rawBooks.add(
              SettingBook(id: fileId, name: book.name, entries: book.entries),
            );
          } else {
            // 旧格式：一条一个文件
            legacy.add(SettingEntry.fromJson(map));
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 合并各文件里的同 id 条目：成员取并集（多对多归属）
    final merged = <String, SettingEntry>{};
    for (final b in rawBooks) {
      for (final e0 in b.entries) {
        final e = e0.bookIds.contains(b.id)
            ? e0
            : e0.copyWith(bookIds: [b.id, ...e0.bookIds]);
        final prev = merged[e.id];
        merged[e.id] = prev == null
            ? e
            : prev.copyWith(bookIds: {...prev.bookIds, ...e.bookIds}.toList());
      }
    }
    _books = [
      for (final b in rawBooks)
        SettingBook(
          id: b.id,
          name: b.name,
          entries: [
            for (final e in merged.values)
              if (e.bookIds.contains(b.id)) e,
          ],
        ),
    ];

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
        entries: [
          for (final e in group.value) e.copyWith(bookIds: [bookId]),
        ],
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
    await File('$dirPath/${book.id}.json')
        .writeAsString(jsonEncode(book.toJson()));
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

  /// 新增 / 更新一条条目（可属于多本设定书）。
  /// [bookId] 指定时并入该书；[replaceBooks] 为 true 则把所属书整体替换为该本。
  Future<void> upsert(
    SettingEntry entry, {
    String? bookId,
    bool replaceBooks = false,
  }) async {
    await ensureLoaded();
    var ids = [...entry.bookIds];
    if (bookId != null && bookId.isNotEmpty) {
      if (ids.isEmpty || replaceBooks) {
        ids = [bookId];
      } else if (!ids.contains(bookId)) {
        ids = [...ids, bookId];
      }
    }
    if (ids.isEmpty) {
      if (_books.isEmpty) {
        ids = [(await createBook(name: '设定库')).id];
      } else {
        ids = [_books.last.id];
      }
    }
    for (final id in ids) {
      if (bookById(id) == null) {
        _books.add(SettingBook(id: id, name: '设定库'));
        await _writeBook(_books.last);
      }
    }
    final e = entry.copyWith(bookIds: ids);
    final affected = <String>{
      for (final b in _books)
        if (b.entries.any((x) => x.id == e.id)) b.id,
      ...ids,
    };
    for (var i = 0; i < _books.length; i++) {
      final filtered = _books[i].entries.where((x) => x.id != e.id).toList();
      if (filtered.length != _books[i].entries.length) {
        _books[i] = SettingBook(
          id: _books[i].id,
          name: _books[i].name,
          entries: filtered,
        );
      }
    }
    for (final id in ids) {
      final i = _books.indexWhere((b) => b.id == id);
      _books[i] = SettingBook(
        id: _books[i].id,
        name: _books[i].name,
        entries: [..._books[i].entries, e],
      );
    }
    for (final id in affected) {
      final i = _books.indexWhere((b) => b.id == id);
      if (i >= 0) await _writeBook(_books[i]);
    }
    notifyListeners();
  }

  /// 设置条目的所属分组（多选）
  Future<void> setBookIds(String entryId, List<String> bookIds) async {
    await ensureLoaded();
    SettingEntry? target;
    for (final e in items) {
      if (e.id == entryId) {
        target = e;
        break;
      }
    }
    if (target == null) return;
    // 至少要属于一个分组；全部取消视为不修改（避免误删）
    if (bookIds.isEmpty) return;
    await upsert(target.copyWith(bookIds: bookIds), replaceBooks: true);
  }

  /// 写入一本书（新建 / 覆盖 / 重命名）；条目成员关系取并集，保留其在别组的归属
  Future<void> upsertBook(SettingBook book) async {
    await ensureLoaded();
    final idx = _books.indexWhere((b) => b.id == book.id);
    if (idx >= 0) {
      _books[idx] = SettingBook(
        id: book.id,
        name: book.name,
        entries: _books[idx].entries,
      );
    } else {
      _books.add(SettingBook(id: book.id, name: book.name));
    }
    for (final e in book.entries) {
      await upsert(e, bookId: book.id);
    }
    final i = _books.indexWhere((b) => b.id == book.id);
    if (i >= 0) await _writeBook(_books[i]);
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
    final removed = bookById(bookId);
    _books.removeWhere((b) => b.id == bookId);
    _deleteBookFile(bookId);
    if (removed != null) {
      for (final e in removed.entries) {
        final remaining = e.bookIds.where((x) => x != bookId).toList();
        if (remaining.isEmpty) {
          // 仅属于本书 → 一并删除
          for (var i = 0; i < _books.length; i++) {
            final filtered = _books[i].entries
                .where((x) => x.id != e.id)
                .toList();
            if (filtered.length == _books[i].entries.length) continue;
            _books[i] = SettingBook(
              id: _books[i].id,
              name: _books[i].name,
              entries: filtered,
            );
            await _writeBook(_books[i]);
          }
        } else {
          // 仍属于其它书 → 去掉本书成员关系后更新
          final updated = e.copyWith(bookIds: remaining);
          for (var i = 0; i < _books.length; i++) {
            final at = _books[i].entries.indexWhere((x) => x.id == e.id);
            if (at < 0) continue;
            final list = [..._books[i].entries];
            list[at] = updated;
            _books[i] = SettingBook(
              id: _books[i].id,
              name: _books[i].name,
              entries: list,
            );
            await _writeBook(_books[i]);
          }
        }
      }
    }
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
