import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kostori/database/history.dart';

/// 单条备忘（剪贴板）：存在 `history.db` 的 `memos` 表，随历史同步。
class Memo {
  final String id;
  String content;
  int createdAt;
  int updatedAt;

  Memo({
    required this.id,
    required this.content,
    this.createdAt = 0,
    this.updatedAt = 0,
  });
}

/// 备忘录存储：内存缓存 + 落库，与 [TextRuleStore] 同构。
class MemoStore with ChangeNotifier {
  MemoStore._();

  static final MemoStore instance = MemoStore._();

  final List<Memo> _memos = [];

  bool _loaded = false;

  List<Memo> get memos => List.unmodifiable(_memos);

  /// 从数据库加载到内存（启动时调用一次，可重复调用，幂等）
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final rows = await HistoryManager().getMemos();
      _memos
        ..clear()
        ..addAll(
          rows.map(
            (m) => Memo(
              id: m['id']?.toString() ?? '',
              content: m['content']?.toString() ?? '',
              createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
              updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
            ),
          ),
        );
      _memos.removeWhere((m) => m.id.isEmpty);
    } catch (_) {}
    notifyListeners();
  }

  /// 新增一条备忘（空文本返回 null，不落库）
  Future<String?> add(String content) async {
    final text = content.trim();
    if (text.isEmpty) return null;
    try {
      final id = await HistoryManager().addMemo(text);
      final now = DateTime.now().millisecondsSinceEpoch;
      _memos.insert(
        0,
        Memo(id: id, content: text, createdAt: now, updatedAt: now),
      );
      notifyListeners();
      return id;
    } catch (_) {
      return null;
    }
  }

  /// 更新备忘内容（updatedAt 同步刷新，用于排序）
  Future<bool> update(String id, String content) async {
    final text = content.trim();
    if (text.isEmpty) return false;
    try {
      await HistoryManager().updateMemo(id, text);
      final idx = _memos.indexWhere((m) => m.id == id);
      if (idx >= 0) {
        _memos[idx]
          ..content = text
          ..updatedAt = DateTime.now().millisecondsSinceEpoch;
        _memos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 删除一条备忘
  Future<void> remove(String id) async {
    try {
      await HistoryManager().deleteMemo(id);
    } catch (_) {}
    _memos.removeWhere((m) => m.id == id);
    notifyListeners();
  }
}
