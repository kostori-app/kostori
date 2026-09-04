import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/favorite_database.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/image_loader/local_favorite_image.dart';
import 'package:kostori/foundation/log.dart';

String _getTimeString(DateTime time) {
  return time.toIso8601String().replaceFirst("T", " ").substring(0, 19);
}

/// 未分类（默认收藏）对外 token（新语义，最终用于释放 `default` 组名）
const String kUnassignedFolder = '_default';

/// 历史 token：drift 迁移前未分类一直用 `'default'` 字符串
const String kUnassignedLegacy = 'default';

/// 判断某分组引用是否指向"未分类/默认收藏"（伪组；字面 `default` 已释放给用户）
bool isUnassignedFolder(String? folder) =>
    folder == kUnassignedFolder || folder == '默认';

class FavoriteItem implements Anime {
  String name;
  String author;
  AnimeType type;
  @override
  List<String> tags;
  @override
  String id;
  String coverPath;
  late String time;
  @override
  final PageJumpTarget? viewMore;

  FavoriteItem({
    required this.id,
    required this.name,
    required this.coverPath,
    required this.author,
    required this.type,
    required this.tags,
    this.viewMore,
    DateTime? favoriteTime,
  }) {
    var t = favoriteTime ?? DateTime.now();
    time = _getTimeString(t);
  }

  @override
  bool operator ==(Object other) {
    return other is FavoriteItem && other.id == id && other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode;

  @override
  String toString() {
    var s = "FavoriteItem: $name $author $coverPath $hashCode $tags";
    if (s.length > 100) {
      return s.substring(0, 100);
    }
    return s;
  }

  @override
  String get cover => coverPath;

  @override
  String get description {
    var time = this.time.substring(0, 10);
    return appdata.settings['animeDisplayMode'] == 'detailed'
        ? "$time | ${type.animeSource?.name ?? "Unknown"}"
        : "${type.animeSource?.name ?? "Unknown"} | $time";
  }

  @override
  List<AnimeDescriptionLine>? get descriptionLines => null;

  @override
  String? get favoriteId => null;

  @override
  String? get language => null;

  int? get maxPage => null;

  @override
  String get sourceKey => type.animeSource?.key ?? "Unknown:${type.value}";

  @override
  double? get stars => null;

  @override
  String? get subtitle => author;

  @override
  String get title => name;

  @override
  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "author": author,
      "type": type.value,
      "tags": tags,
      "id": id,
      "coverPath": coverPath,
    };
  }

  /// 字段级合并专用序列化（含 viewMore 与时间，跨端 JSON 传输）
  Map<String, dynamic> toMergeJson() => {
    'id': id,
    'name': name,
    'author': author,
    'type': type.value,
    'tags': tags,
    'coverPath': coverPath,
    'time': time,
    'viewMore': viewMore is PageJumpTarget
        ? (viewMore as PageJumpTarget).toJsonString()
        : null,
  };

  static FavoriteItem fromJson(Map<String, dynamic> json) {
    var type = json["type"] as int;
    return FavoriteItem(
      id: json["id"] ?? json['target'],
      name: json["name"],
      author: json["author"],
      coverPath: json["coverPath"],
      type: AnimeType(type),
      tags: List<String>.from(json["tags"] ?? []),
      viewMore: json["viewMore"] is String
          ? PageJumpTarget.fromJsonString(json["viewMore"] as String)
          : null,
    );
  }
}

class FavoriteItemWithFolderInfo extends FavoriteItem {
  String folder;

  FavoriteItemWithFolderInfo(FavoriteItem item, this.folder)
    : super(
        id: item.id,
        name: item.name,
        coverPath: item.coverPath,
        author: item.author,
        type: item.type,
        tags: item.tags,
        viewMore: item.viewMore,
      );
}

class FavoriteItemWithUpdateInfo extends FavoriteItem {
  String? updateTime;

  DateTime? lastCheckTime;

  bool hasNewUpdate;

  FavoriteItemWithUpdateInfo(
    FavoriteItem item,
    this.updateTime,
    this.hasNewUpdate,
    int? lastCheckTime,
  ) : lastCheckTime = lastCheckTime == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastCheckTime),
      super(
        id: item.id,
        name: item.name,
        coverPath: item.coverPath,
        author: item.author,
        type: item.type,
        tags: item.tags,
        viewMore: item.viewMore,
      );

  @override
  String get description {
    var updateTime = this.updateTime ?? "Unknown";
    var sourceName = type.animeSource?.name ?? "Unknown";
    return "$updateTime | $sourceName";
  }

  @override
  List<AnimeDescriptionLine>? get descriptionLines => null;

  @override
  operator ==(Object other) {
    return other is FavoriteItemWithUpdateInfo &&
        other.updateTime == updateTime &&
        other.hasNewUpdate == hasNewUpdate &&
        super == other;
  }

  @override
  int get hashCode =>
      super.hashCode ^ updateTime.hashCode ^ hasNewUpdate.hashCode;
}

/// 内存条目（同步外观的数据载体）：携带组内顺序与最近观看时间，
/// 便于在 UI 上同步读取，同时后台持久化到 drift。
class _FavEntry {
  FavoriteItem item;
  String? recentlyWatched;

  _FavEntry(this.item, [this.recentlyWatched]);
}

class LocalFavoritesManager with ChangeNotifier {
  factory LocalFavoritesManager() =>
      cache ?? (cache = LocalFavoritesManager._create());

  LocalFavoritesManager._create();

  static LocalFavoritesManager? cache;

  FavoriteDatabase? _db;

  final Map<String, List<_FavEntry>> _byFolder = {};

  final List<String> _folderOrder = [];

  var _hashedIds = <int, int>{};

  Timer? _persistTimer;

  bool _persistScheduled = false;

  int get totalAnimes => _hashedIds.length;

  int folderAnimes(String folder) => _byFolder[_resolveFolder(folder)]?.length ?? 0;

  List<String> get folderNames => List.unmodifiable(_folderOrder);

  String _resolveFolder(String? folder) {
    if (folder == '默认' || folder == kUnassignedFolder) {
      return kUnassignedFolder;
    }
    // 历史数据里 `default` 曾指未分类；若用户还没真的建过叫 default 的
    // 自定义分组，仍把它当未分类兼容；建过则以自定义组为准
    if (folder == kUnassignedLegacy && !_byFolder.containsKey(kUnassignedLegacy)) {
      return kUnassignedFolder;
    }
    return folder ?? kUnassignedFolder;
  }

  bool existsFolder(String name) => _byFolder.containsKey(_resolveFolder(name));

  Future<void> init() async {
    _byFolder.clear();
    _folderOrder.clear();
    _hashedIds.clear();
    await appdata.ensureInit();
    final db = FavoriteDatabase.open(FavoriteDatabase.defaultPath());
    _db = db;
    await _migrateUnassignedToken(db);
    await _loadFromDrift(db);
  }

  /// 一次性迁移：把历史上以 `default`/`默认` 存储的“未分类”统一改存到
  /// 保留 token `_default`，从而把字面 `default` 让给用户自定义分组。
  Future<void> _migrateUnassignedToken(FavoriteDatabase db) async {
    const legacy = ['default', '默认'];
    try {
      await db.transaction(() async {
        final canonicalExists = await (db.selectOnly(db.favoriteFolders)
              ..addColumns([db.favoriteFolders.id])
              ..where(db.favoriteFolders.id.equals(kUnassignedFolder)))
            .get()
            .then((r) => r.isNotEmpty);
        if (!canonicalExists) {
          var order = 0;
          final oldOrder = await (db.selectOnly(db.favoriteFolders)
                ..addColumns([db.favoriteFolders.sortOrder])
                ..where(db.favoriteFolders.id.isIn(legacy)))
              .get();
          if (oldOrder.isNotEmpty) {
            order = oldOrder.first.read(db.favoriteFolders.sortOrder) ?? 0;
          }
          await db.into(db.favoriteFolders).insert(
            FavoriteFoldersCompanion.insert(
              id: kUnassignedFolder,
              name: kUnassignedFolder,
              sortOrder: order,
            ),
          );
        }
        await (db.update(db.favoriteItems)
              ..where((t) => t.folderId.isIn(legacy)))
            .write(FavoriteItemsCompanion(folderId: Value(kUnassignedFolder)));
        await (db.delete(db.favoriteFolders)..where(
          (t) => t.id.isIn(legacy),
        )).go();
      });
    } catch (e) {
      Log.error('FavoriteMigrate', 'unassigned token migration failed: $e');
    }
  }

  Future<void> _loadFromDrift(FavoriteDatabase db) async {
    final folders = await (db.select(db.favoriteFolders)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    for (final f in folders) {
      final rows = await (db.select(db.favoriteItems)
            ..where((t) => t.folderId.equals(f.id))
            ..orderBy([(t) => OrderingTerm.asc(t.displayOrder)]))
          .get();
      _byFolder[f.name] = [
        for (final r in rows)
          _FavEntry(
            _rowToFavoriteItem(r),
            r.recentlyWatched,
          ),
      ];
      _folderOrder.add(f.name);
    }
    _rebuildHashedIds();
  }

  FavoriteItem _rowToFavoriteItem(FavoriteItemRow r) {
    return FavoriteItem(
      id: r.id,
      name: r.name,
      author: r.author ?? '',
      coverPath: r.coverPath ?? '',
      type: AnimeType(r.type),
      tags: (r.tags ?? '').split(',').where((e) => e.isNotEmpty).toList(),
      viewMore: (r.viewMore ?? '').isEmpty
          ? null
          : PageJumpTarget.fromJsonString(r.viewMore!),
    )..time = r.time ?? '';
  }

  void _rebuildHashedIds() {
    final map = <int, int>{};
    for (final list in _byFolder.values) {
      for (final e in list) {
        final hash = e.item.id.hashCode ^ e.item.type.value;
        map[hash] = (map[hash] ?? 0) + 1;
      }
    }
    _hashedIds = map;
  }

  void _incrementHashedId(String id, int type) {
    final hash = id.hashCode ^ type;
    _hashedIds[hash] = (_hashedIds[hash] ?? 0) + 1;
  }

  void reduceHashedId(String id, int type) {
    final hash = id.hashCode ^ type;
    if (_hashedIds.containsKey(hash)) {
      if (_hashedIds[hash]! > 1) {
        _hashedIds[hash] = _hashedIds[hash]! - 1;
      } else {
        _hashedIds.remove(hash);
      }
    }
  }

  void _notify() {
    notifyListeners();
  }

  /// 计划一次后台整库持久化（数据量小，直接全量重写，简单可靠）。
  /// 内存同步更新后 UI 立即可用；落盘延迟合并，避免高频写库。
  void _schedulePersist() {
    _persistScheduled = true;
    _persistTimer ??= Timer(const Duration(milliseconds: 250), _persistNow);
  }

  Future<void> _persistNow() async {
    _persistTimer = null;
    if (!_persistScheduled) return;
    _persistScheduled = false;
    final db = _db;
    if (db == null) return;
    try {
      await db.transaction(() async {
        await db.delete(db.favoriteItems).go();
        await db.delete(db.favoriteFolders).go();
        var orderIndex = 0;
        for (final folder in _folderOrder) {
          await db.into(db.favoriteFolders).insert(
            FavoriteFoldersCompanion.insert(
              id: folder,
              name: folder,
              sortOrder: orderIndex++,
            ),
          );
          final entries = _byFolder[folder] ?? const [];
          for (var i = 0; i < entries.length; i++) {
            final e = entries[i];
            final it = e.item;
            await db.into(db.favoriteItems).insert(
              FavoriteItemsCompanion.insert(
                folderId: folder,
                id: it.id,
                name: it.name,
                author: Value(it.author.isEmpty ? null : it.author),
                type: it.type.value,
                tags: Value(it.tags.isEmpty ? null : it.tags.join(',')),
                coverPath: Value(it.coverPath.isEmpty ? null : it.coverPath),
                time: Value(it.time),
                displayOrder: Value(i),
                recentlyWatched: Value(e.recentlyWatched),
                viewMore: Value(
                  it.viewMore is PageJumpTarget
                      ? (it.viewMore as PageJumpTarget).toJsonString()
                      : null,
                ),
              ),
            );
          }
        }
      });
    } catch (e) {
      Log.error('FavoritePersist', 'write failed: $e');
    }
  }

  // ─── 查询 ─────────────────────────────────────────────

  List<FavoriteItem> getFolderAnimes(String folder) {
    return getAllAnimes(folder);
  }

  Future<List<FavoriteItem>> getFolderAnimesAsync(
    String folder,
    FavoriteSortType sortType,
  ) async {
    return getAllAnimes(folder, sortType);
  }

  List<FavoriteItem> getAllAnimes(
    String folder, [
    FavoriteSortType sortType = FavoriteSortType.displayOrderAsc,
  ]) {
    final list = _byFolder[_resolveFolder(folder)] ?? const [];
    return _sortEntries(list, sortType)
        .map((e) => e.item)
        .toList(growable: false);
  }

  List<FavoriteItem> getAllFavoriteItemsForMerge() {
    final result = <FavoriteItem>[];
    for (final folder in _folderOrder) {
      result.addAll(getAllAnimes(folder));
    }
    return result;
  }

  void mergeFavoriteList(List<FavoriteItem> remote) {
    if (remote.isEmpty) return;
    var defaultFolder = _folderOrder.contains('默认')
        ? '默认'
        : (_folderOrder.isNotEmpty ? _folderOrder.first : '默认');
    var changed = false;
    for (final r in remote) {
      if (findWithModelSync(r)) continue;
      try {
        addAnime(defaultFolder, r);
        changed = true;
      } catch (e) {
        DebugLog.error('mergeFavoriteList', '添加收藏 ${r.id} 失败：$e');
      }
    }
    if (changed) _notify();
  }

  bool findWithModelSync(FavoriteItem item) {
    for (final folder in _folderOrder) {
      final list = _byFolder[folder] ?? const [];
      if (list.any((e) => e.item.id == item.id && e.item.type == item.type)) {
        return true;
      }
    }
    return false;
  }

  List<String> find(String id, AnimeType type) {
    final res = <String>[];
    for (final folder in _folderOrder) {
      final list = _byFolder[folder] ?? const [];
      if (list.any((e) => e.item.id == id && e.item.type == type)) {
        res.add(folder);
      }
    }
    return res;
  }

  Future<List<String>> findWithModel(FavoriteItem item) async => find(
    item.id,
    item.type,
  );

  List<FavoriteItemWithFolderInfo> allAnimes() {
    final res = <FavoriteItemWithFolderInfo>[];
    for (final folder in _folderOrder) {
      for (final e in _byFolder[folder] ?? const []) {
        res.add(FavoriteItemWithFolderInfo(e.item, folder));
      }
    }
    return res;
  }

  FavoriteItem getAnime(String folder, String id, AnimeType type) {
    final e = _findEntry(folder, id, type);
    if (e == null) throw Exception("Anime not found");
    return e.item;
  }

  FavoriteItem? findAnime(String id, AnimeType type) {
    for (final folder in _folderOrder) {
      final e = _findEntry(folder, id, type);
      if (e != null) return e.item;
    }
    return null;
  }

  _FavEntry? _findEntry(String folder, String id, AnimeType type) {
    for (final e in _byFolder[_resolveFolder(folder)] ?? const []) {
      if (e.item.id == id && e.item.type == type) return e;
    }
    return null;
  }

  bool isExist(String id, AnimeType type) {
    return _hashedIds.containsKey(id.hashCode ^ type.value);
  }

  List<FavoriteItem> searchInFolder(String folder, String keyword) {
    final list = _byFolder[_resolveFolder(folder)] ?? const [];
    final kw = keyword.split(' ').first.toLowerCase();
    final results = list
        .where((e) => _matches(e.item, kw))
        .map((e) => e.item)
        .toList();
    final rest = keyword.split(' ').skip(1).toList();
    return _filterWords(results, rest);
  }

  List<FavoriteItemWithFolderInfo> search(
    String keyword, [
    FavoriteSortType sortType = FavoriteSortType.displayOrderAsc,
  ]) {
    final kw = keyword.split(' ').first.toLowerCase();
    final results = <FavoriteItemWithFolderInfo>[];
    for (final folder in _folderOrder) {
      for (final e in _byFolder[folder] ?? const []) {
        if (_matches(e.item, kw)) {
          results.add(FavoriteItemWithFolderInfo(e.item, folder));
        }
        if (results.length >= 200) break;
      }
      if (results.length >= 200) break;
    }
    final rest = keyword.split(' ').skip(1).toList();
    if (rest.isEmpty) return results;
    return results.where((e) => _matches(e, rest.first.toLowerCase())).toList();
  }

  bool _matches(FavoriteItem item, String kw) {
    if (item.name.toLowerCase().contains(kw)) return true;
    if (item.author.toLowerCase().contains(kw)) return true;
    return item.tags.any((e) => e.toLowerCase().contains(kw));
  }

  List<FavoriteItem> _filterWords(
    List<FavoriteItem> items,
    List<String> words,
  ) {
    var result = items;
    for (final w in words) {
      final k = w.toLowerCase();
      result = result
          .where((e) => _matches(e, k))
          .toList();
    }
    return result;
  }

  List<_FavEntry> _sortEntries(
    List<_FavEntry> list,
    FavoriteSortType sortType,
  ) {
    final copy = List<_FavEntry>.from(list);
    copy.sort((a, b) {
      final int cmp;
      switch (sortType) {
        case FavoriteSortType.nameAsc:
          cmp = a.item.name.compareTo(b.item.name);
        case FavoriteSortType.nameDesc:
          cmp = b.item.name.compareTo(a.item.name);
        case FavoriteSortType.timeAsc:
          cmp = a.item.time.compareTo(b.item.time);
        case FavoriteSortType.timeDesc:
          cmp = b.item.time.compareTo(a.item.time);
        case FavoriteSortType.recentlyWatchedAsc:
          cmp = (a.recentlyWatched ?? '').compareTo(b.recentlyWatched ?? '');
        case FavoriteSortType.recentlyWatchedDesc:
          cmp = (b.recentlyWatched ?? '').compareTo(a.recentlyWatched ?? '');
        default:
          cmp = 0;
      }
      return cmp != 0 ? cmp : a.item.time.compareTo(b.item.time);
    });
    return copy;
  }

  // ─── 分组管理 ─────────────────────────────────────────

  String createFolder(String name, [bool renameWhenInvalidName = false]) {
    if (name.isEmpty) {
      if (renameWhenInvalidName) {
        int i = 0;
        while (existsFolder(i.toString())) {
          i++;
        }
        name = i.toString();
      } else {
        throw "name is empty!";
      }
    }
    if (existsFolder(name)) {
      if (renameWhenInvalidName) {
        var prevName = name;
        int i = 0;
        while (existsFolder('$prevName$i')) {
          i++;
        }
        name = '$prevName$i';
      } else {
        throw Exception("Folder is existing");
      }
    }
    _byFolder[_resolveFolder(name)] = <_FavEntry>[];
    _folderOrder.add(name);
    _notify();
    _schedulePersist();
    return name;
  }

  void updateOrder(List<String> folders) {
    final current = folders.toList();
    _folderOrder
      ..clear()
      ..addAll(current);
    _notify();
    _schedulePersist();
  }

  void rename(String before, String after) {
    if (folderNames.contains(after)) {
      throw "Name already exists!";
    }
    if (after.contains('"')) {
      throw "Invalid name";
    }
    final key = _resolveFolder(before);
    final entries = _byFolder.remove(key) ?? <_FavEntry>[];
    _byFolder[_resolveFolder(after)] = entries;
    _folderOrder[_folderOrder.indexOf(before)] = after;
    _notify();
    _schedulePersist();
  }

  void deleteFolder(String name) {
    if (isUnassignedFolder(name)) return;
    _byFolder.remove(name);
    _folderOrder.remove(name);
    _rebuildHashedIds();
    _notify();
    _schedulePersist();
  }

  // ─── 增删改 ───────────────────────────────────────────

  bool addAnime(String folder, FavoriteItem anime, [int? order]) {
    final key = _resolveFolder(folder);
    final list = _byFolder[key];
    if (list == null) {
      throw Exception("Folder does not exists");
    }
    if (list.any((e) => e.item.id == anime.id && e.item.type == anime.type)) {
      return false;
    }
    final entry = _FavEntry(anime);
    if (order != null) {
      final idx = order.clamp(0, list.length);
      list.insert(idx, entry);
    } else if (appdata.settings['newFavoriteAddTo'] == "end") {
      list.add(entry);
    } else {
      list.insert(0, entry);
    }
    StatsManager().addFavoriteRecord(
      id: anime.id,
      type: anime.type.value,
      folder: folder,
      action: FavoriteAction.add,
    );
    _incrementHashedId(anime.id, anime.type.value);
    _notify();
    _schedulePersist();
    return true;
  }

  void addTagTo(String folder, String id, String tag) {
    for (final entry in _byFolder[_resolveFolder(folder)] ?? const []) {
      if (entry.item.id == id) {
        entry.item.tags = [tag, ...entry.item.tags];
      }
    }
    _notify();
    _schedulePersist();
  }

  void removeFavoriteFromFolder(String folder, String id, AnimeType type) {
    final list = _byFolder[_resolveFolder(folder)];
    if (list == null) return;
    list.removeWhere(
      (e) => e.item.id == id && e.item.type == type,
    );
  }

  void moveFavorite(
    List<String> sources,
    List<String> targets,
    String id,
    AnimeType type,
  ) {
    if (sources.isEmpty || targets.isEmpty) return;
    for (final source in sources) {
      final e = _findEntry(source, id, type);
      if (e == null) continue;
      for (final target in targets) {
        if (target == source) continue;
        _copyInto(target, e);
      }
    }
    for (final source in sources) {
      removeFavoriteFromFolder(source, id, type);
    }
    final uniqueTargets = targets.where((t) => !sources.contains(t)).toList();
    StatsManager().addFavoriteRecord(
      id: id,
      type: type.value,
      folder: '${sources.join("|")},${uniqueTargets.join("|")}',
      action: FavoriteAction.move,
    );
    _rebuildHashedIds();
    _notify();
    _schedulePersist();
  }

  void _copyInto(String targetFolder, _FavEntry src) {
    final list = _byFolder[_resolveFolder(targetFolder)];
    if (list == null) return;
    if (list.any(
      (e) => e.item.id == src.item.id && e.item.type == src.item.type,
    )) {
      return;
    }
    list.add(_FavEntry(_cloneItem(src.item), src.recentlyWatched));
  }

  FavoriteItem _cloneItem(FavoriteItem src) => FavoriteItem(
    id: src.id,
    name: src.name,
    coverPath: src.coverPath,
    author: src.author,
    type: src.type,
    tags: List<String>.from(src.tags),
    viewMore: src.viewMore,
  );

  void batchMoveFavorites(
    String sourceFolder,
    String targetFolder,
    List<FavoriteItem> items,
  ) {
    if (!existsFolder(sourceFolder)) {
      throw Exception("Source folder does not exist");
    }
    if (!existsFolder(targetFolder)) {
      throw Exception("Target folder does not exist");
    }
    for (var item in items) {
      final e = _findEntry(sourceFolder, item.id, item.type);
      if (e != null && sourceFolder != targetFolder) {
        _copyInto(targetFolder, e);
      }
      removeFavoriteFromFolder(sourceFolder, item.id, item.type);
    }
    for (var i in items) {
      if (sourceFolder != targetFolder) {
        StatsManager().addFavoriteRecord(
          id: i.id,
          type: i.type.value,
          folder: '$sourceFolder,$targetFolder',
          action: FavoriteAction.move,
        );
      }
    }
    _rebuildHashedIds();
    _notify();
    _schedulePersist();
  }

  void batchCopyFavorites(
    String sourceFolder,
    String targetFolder,
    List<FavoriteItem> items,
  ) {
    if (!existsFolder(sourceFolder)) {
      throw Exception("Source folder does not exist");
    }
    if (!existsFolder(targetFolder)) {
      throw Exception("Target folder does not exist");
    }
    for (var item in items) {
      final e = _findEntry(sourceFolder, item.id, item.type);
      if (e != null) _copyInto(targetFolder, e);
    }
    for (var i in items) {
      StatsManager().addFavoriteRecord(
        id: i.id,
        type: i.type.value,
        folder: '$sourceFolder,$targetFolder',
        action: FavoriteAction.add,
      );
    }
    _rebuildHashedIds();
    _notify();
    _schedulePersist();
  }

  void batchDeleteAnimes(String folder, List<FavoriteItem> animes) {
    final list = _byFolder[_resolveFolder(folder)];
    for (var anime in animes) {
      LocalFavoriteImageProvider.delete(anime.id, anime.type.value);
      list?.removeWhere(
        (e) => e.item.id == anime.id && e.item.type == anime.type,
      );
    }
    for (var i in animes) {
      reduceHashedId(i.id, i.type.value);
      StatsManager().addFavoriteRecord(
        id: i.id,
        type: i.type.value,
        folder: folder,
        action: FavoriteAction.remove,
      );
    }
    _notify();
    _schedulePersist();
  }

  void batchDeleteAnimesInAllFolders(List<AnimeID> animes) {
    for (var anime in animes) {
      LocalFavoriteImageProvider.delete(anime.id, anime.type.value);
      for (final folder in _folderOrder) {
        _byFolder[folder]?.removeWhere(
          (e) => e.item.id == anime.id && e.item.type == anime.type,
        );
      }
      _hashedIds.remove(anime.id.hashCode ^ anime.type.value);
    }
    _notify();
    _schedulePersist();
  }

  void deleteAnimeWithId(String folder, String id, AnimeType type) {
    LocalFavoriteImageProvider.delete(id, type.value);
    removeFavoriteFromFolder(folder, id, type);
    StatsManager().addFavoriteRecord(
      id: id,
      type: type.value,
      folder: folder,
      action: FavoriteAction.remove,
    );
    reduceHashedId(id, type.value);
    _notify();
    _schedulePersist();
  }

  Future<int> removeInvalid() async {
    var count = 0;
    final all = allAnimes();
    for (var c in all) {
      if (c.type.animeSource == null) {
        deleteAnimeWithId(c.folder, c.id, c.type);
        count++;
      }
    }
    return count;
  }

  Future<void> clearAll() async {
    await _persistNow();
    await _db?.close();
    _db = null;
    final file = File(FavoriteDatabase.defaultPath());
    if (file.existsSync()) file.deleteSync();
    await init();
    _notify();
  }

  void editTags(String id, String folder, List<String> tags) {
    for (final e in _byFolder[_resolveFolder(folder)] ?? const []) {
      if (e.item.id == id) e.item.tags = List<String>.from(tags);
    }
    _notify();
    _schedulePersist();
  }

  void updateInfo(String folder, FavoriteItem anime) {
    for (final e in _byFolder[_resolveFolder(folder)] ?? const []) {
      if (e.item.id == anime.id && e.item.type == anime.type) {
        e.item.name = anime.name;
        e.item.author = anime.author;
        e.item.coverPath = anime.coverPath;
        e.item.tags = List<String>.from(anime.tags);
      }
    }
    _notify();
    _schedulePersist();
  }

  void updateRecentlyWatched(String id, AnimeType type) {
    if (!isExist(id, type)) return;
    final now = _getTimeString(DateTime.now());
    for (final folder in _folderOrder) {
      for (final e in _byFolder[folder] ?? const []) {
        if (e.item.id == id && e.item.type == type) {
          e.recentlyWatched = now;
        }
      }
    }
    _notify();
    _schedulePersist();
  }

  // ─── 导出/导入 ────────────────────────────────────────

  String folderToJson(String folder) {
    final list = _byFolder[_resolveFolder(folder)] ?? const [];
    return jsonEncode({
      "info": "Generated by Kostori",
      "name": folder,
      "animes": list.map((e) => e.item.toJson()).toList(),
    });
  }

  void fromJson(String json) {
    final data = jsonDecode(json);
    var folder = data["name"];
    if (folder == null || folder is! String) {
      throw "Invalid data";
    }
    if (existsFolder(folder)) {
      int i = 0;
      while (existsFolder('$folder($i)')) {
        i++;
      }
      folder = '$folder($i)';
    }
    createFolder(folder);
    for (var anime in data["animes"]) {
      try {
        addAnime(folder, FavoriteItem.fromJson(anime));
      } catch (e) {
        Log.error("Import Data", e.toString());
      }
    }
  }

  /// 兼容旧 API：跟随更新列已由 drift 表固定提供，无需动态 ALTER
  void prepareTableForFollowUpdates(String table, [bool clearData = true]) {}

  final _favoritesStream = StreamController<void>.broadcast();

  Stream<void> get onChanged => _favoritesStream.stream;

  void close() {
    _persistTimer?.cancel();
    _persistTimer = null;
    _favoritesStream.close();
    _db?.close();
    _db = null;
  }

  // 兼容旧字段读取（迁移期间内部使用）
  void initCounts() {}

  int count(String folderName) => folderAnimes(folderName);

  int maxValue(String folder) {
    final list = _byFolder[_resolveFolder(folder)];
    return (list?.length ?? 0) > 0 ? list!.length : 0;
  }

  int minValue(String folder) => 0;
}

final favoritesChangedProvider = StreamProvider<void>((ref) {
  return LocalFavoritesManager()._favoritesStream.stream;
});

enum FavoriteSortType {
  nameAsc("name_asc"),
  nameDesc("name_desc"),
  timeAsc("time_asc"),
  timeDesc("time_desc"),
  displayOrderAsc("displayOrder_asc"),
  displayOrderDesc("displayOrder_desc"),
  recentlyWatchedAsc("recentlyWatched_asc"),
  recentlyWatchedDesc("recentlyWatched_desc");

  final String value;

  const FavoriteSortType(this.value);

  static FavoriteSortType fromString(String value) {
    for (var type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return nameAsc;
  }

  String get orderBy => switch (this) {
    FavoriteSortType.nameAsc => 'name ASC',
    FavoriteSortType.nameDesc => 'name DESC',
    FavoriteSortType.timeAsc => 'time ASC',
    FavoriteSortType.timeDesc => 'time DESC',
    FavoriteSortType.displayOrderAsc => 'display_order ASC',
    FavoriteSortType.displayOrderDesc => 'display_order DESC',
    FavoriteSortType.recentlyWatchedAsc => 'recently_watched ASC',
    FavoriteSortType.recentlyWatchedDesc => 'recently_watched DESC',
  };
}
