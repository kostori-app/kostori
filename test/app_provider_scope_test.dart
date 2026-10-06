import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/init.dart';
import 'package:kostori/main.dart';

class _SharedCounter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

void main() {
  testWidgets('启动和主界面共用容器及后台管理器实例', (tester) async {
    final oldReady = bootReady.value;
    final oldError = bootError.value;
    final counter = NotifierProvider<_SharedCounter, int>(_SharedCounter.new);
    final startupManager = providerContainer.read(counter.notifier);
    startupManager.increment();
    bootReady.value = true;
    bootError.value = null;
    addTearDown(() {
      bootReady.value = oldReady;
      bootError.value = oldError;
      providerContainer.invalidate(counter);
    });

    _SharedCounter? uiManager;
    var uiValue = -1;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          // 检查 BootGate 实际选择的容器；替换其子树，避免启动网络和平台服务。
          final gate = const BootGate().build(context) as Directionality;
          final builder = gate.child as ListenableBuilder;
          final transition = builder.builder(context, null) as AnimatedSwitcher;
          expect(transition.child, isA<UncontrolledProviderScope>());
          final scope = transition.child! as UncontrolledProviderScope;
          expect(identical(scope.container, providerContainer), isTrue);
          return UncontrolledProviderScope(
            container: scope.container,
            child: Consumer(
              builder: (context, ref, child) {
                uiManager = ref.read(counter.notifier);
                uiValue = ref.watch(counter);
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );

    expect(identical(uiManager, startupManager), isTrue);
    expect(uiValue, 1);
    startupManager.increment();
    await tester.pump();
    expect(uiValue, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      identical(providerContainer.read(counter.notifier), startupManager),
      isTrue,
    );
  });
}
