import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod 状态存储的公共基类。
///
/// 状态变化通过 [Notifier.state] 传播。`revision` 只为尚未迁移到
/// `ref.watch` 的非 Riverpod 组件提供过渡性的值监听接口，存储本身不再实现
/// Flutter 的 [Listenable]。
abstract class RiverpodStore extends Notifier<int> {
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  bool _built = false;
  bool _revisionDisposed = false;

  ValueListenable<int> get revision => _revision;

  @override
  int build() {
    _built = true;
    ref.onDispose(() {
      _built = false;
      _disposeRevision();
    });
    return 0;
  }

  void notifyListeners() {
    if (_built) state++;
    if (!_revisionDisposed) _revision.value++;
  }

  void dispose() {
    _disposeRevision();
  }

  void _disposeRevision() {
    if (_revisionDisposed) return;
    _revisionDisposed = true;
    _revision.dispose();
  }
}
