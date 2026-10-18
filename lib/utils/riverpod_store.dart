import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod 状态存储的公共基类。
///
/// 状态变化通过 [Notifier.state] 传播，存储本身不实现 Flutter 的
/// [Listenable]，页面统一通过 provider 订阅。
abstract class RiverpodStore extends Notifier<int> {
  bool _built = false;

  @override
  int build() {
    _built = true;
    ref.onDispose(() => _built = false);
    return 0;
  }

  void notifyListeners() {
    if (_built) state++;
  }
}
