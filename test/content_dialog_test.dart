import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/i18n/strings.g.dart';

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('ContentDialog 把常见按钮渲染成分段式胶囊且不报错', (tester) async {
    await tester.pumpWidget(
      _host(
        ContentDialog(
          title: '标题',
          content: const Text('内容'),
          actions: [
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('新建'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CapsuleButton), findsNWidgets(3)); // 取消 + 2 个动作
    expect(find.text('新建'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('项目 Button 与 TextButton 也能转成胶囊', (tester) async {
    await tester.pumpWidget(
      _host(
        ContentDialog(
          content: const Text('内容'),
          actions: [
            FilledButton(onPressed: () {}, child: const Text('确认')),
            TextButton(onPressed: () {}, child: const Text('次要')),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CapsuleButton), findsNWidgets(3));
    expect(find.text('确认'), findsOneWidget);
    expect(find.text('次要'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        ContentDialog(
          content: const Text('内容'),
          actions: [
            Button.filled(onPressed: () {}, child: const Text('项目按钮')),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('项目按钮'), findsOneWidget);
  });

  testWidgets('禁用态按钮不响应点击', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _host(
        ContentDialog(
          content: const Text('内容'),
          actions: [
            FilledButton(
              onPressed: null,
              child: const Text('禁用'),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('禁用'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tapped, 0);
    expect(tester.takeException(), isNull);
  });
}
