import 'dart:async';

/// 跨 isolate 请求的 id → Completer 配对表。
///
/// `JSPool`、`CacheManager` 原来各写一套（计数器 + Map + 超时清理），
/// 漏清表项的 bug 已经出过两次（超时孤儿、异常分支漏结算）。
/// 收敛到这里：超时自动删表项、关闭时一键结算全部。
class PendingRequests<T> {
  int _nextId = 0;

  final Map<int, Completer<T>> _map = {};

  int get length => _map.length;

  bool get isEmpty => _map.isEmpty;

  bool get isNotEmpty => _map.isNotEmpty;

  /// 登记一个新请求，返回 id 与 future（调用方随后把带 id 的消息发出去）。
  ({int id, Future<T> future}) register() {
    final id = _nextId++;
    final c = Completer<T>();
    _map[id] = c;
    return (id: id, future: c.future);
  }

  /// 登记并限时：超时时先删表项再抛（迟到响应在路由处因找不到表项被丢弃，
  /// 不堆积孤儿、不虚增 pending 计数）。
  ({int id, Future<T> future}) registerWithTimeout(
    Duration timeout,
    TimeoutException Function() onTimeout,
  ) {
    final rec = register();
    final future = rec.future.timeout(
      timeout,
      onTimeout: () {
        _map.remove(rec.id);
        throw onTimeout();
      },
    );
    return (id: rec.id, future: future);
  }

  /// 结算成功，返回是否找到对应请求（迟到/重复响应返回 false，调用方丢弃）。
  bool complete(int id, T value) {
    final c = _map.remove(id);
    if (c == null) return false;
    if (!c.isCompleted) c.complete(value);
    return true;
  }

  /// 结算失败，用法同 [complete]。
  bool completeError(int id, Object error) {
    final c = _map.remove(id);
    if (c == null) return false;
    if (!c.isCompleted) c.completeError(error);
    return true;
  }

  /// 全部按失败结算并清空（通道关闭 / worker 炸了时调用，避免调用方永挂）。
  void settleAllError(Object error) {
    if (_map.isEmpty) return;
    final all = _map.values.toList();
    _map.clear();
    for (final c in all) {
      if (!c.isCompleted) c.completeError(error);
    }
  }
}
