import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:kostori/foundation/app.dart';
import 'package:sqlite3/sqlite3.dart';

class SearchHistoryItem {
  final int? id;
  final String keyword;
  final int useCount;
  final int lastUsedAt;

  const SearchHistoryItem({
    this.id,
    required this.keyword,
    required this.useCount,
    required this.lastUsedAt,
  });

  factory SearchHistoryItem.fromRow(Map<String, Object?> row) {
    return SearchHistoryItem(
      id: row['id'] as int?,
      keyword: row['keyword'] as String,
      useCount: (row['useCount'] as num).toInt(),
      lastUsedAt: (row['lastUsedAt'] as num).toInt(),
    );
  }

  factory SearchHistoryItem.fromMap(Map<String, dynamic> map) {
    return SearchHistoryItem(
      id: map['id'] as int?,
      keyword: map['keyword'] as String,
      useCount: map['useCount'] as int,
      lastUsedAt: map['lastUsedAt'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'keyword': keyword,
      'useCount': useCount,
      'lastUsedAt': lastUsedAt,
    };
  }

  SearchHistoryItem copyWith({
    int? id,
    String? keyword,
    int? useCount,
    int? lastUsedAt,
  }) {
    return SearchHistoryItem(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}

class SearchHistoryManager with ChangeNotifier {
  static SearchHistoryManager? cache;

  SearchHistoryManager.create();

  factory SearchHistoryManager() =>
      cache == null ? (cache = SearchHistoryManager.create()) : cache!;

  late Database _db;

  bool isInitialized = false;

  Future<void> init() async {
    if (isInitialized) {
      return;
    }
    _db = sqlite3.open("${App.dataPath}/search_history.db");

    _db.execute("""
      create table if not exists search_history (
        keyword text primary key,
        useCount int,
        lastUsedAt int
      );
    """);
    notifyListeners();
  }

  static const _insertOrUpdateSql = """
      insert into search_history (
        keyword,
        useCount,
        lastUsedAt
      )
      values (?, 1, ?)
      on conflict(keyword) do update set
        useCount = useCount + 1,
        lastUsedAt = excluded.lastUsedAt;
    """;

  static const _selectAllSql = """
      select *
      from search_history
      order by lastUsedAt desc;
    """;

  static const _deleteSql = """
      delete from search_history
      where keyword = ?;
    """;

  static const _clearSql = """
      delete from search_history;
    """;

  void addSearch(String keyword) {
    final now = DateTime.now().millisecondsSinceEpoch;

    _db.execute(_insertOrUpdateSql, [keyword, now]);

    notifyListeners();
  }

  List<SearchHistoryItem> getSearchAll({int? limit}) {
    final result = limit == null
        ? _db.select(_selectAllSql)
        : _db.select(
            """
          select *
          from search_history
          order by lastUsedAt desc
          limit ?;
        """,
            [limit],
          );

    if (result.isEmpty) return [];

    return result.map(SearchHistoryItem.fromRow).toList();
  }

  void deleteSearch(String keyword) {
    _db.execute(_deleteSql, [keyword]);
    notifyListeners();
  }

  void clearSearch() {
    _db.execute(_clearSql);
    notifyListeners();
  }

  void close() {
    _db.close();
  }
}
