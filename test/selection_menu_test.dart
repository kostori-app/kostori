import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/i18n/strings.g.dart';

Widget _host(Widget child) =>
    TranslationProvider(child: MaterialApp(home: Scaffold(body: child)));

Future<void> _pumpArea(WidgetTester tester) async {
  await tester.pumpWidget(
    _host(const Center(child: AppSelectionArea(child: Text('hello world')))),
  );
}

void main() {
  testWidgets('AppSelectionArea 在默认项后追加翻译与搜索', (tester) async {
    await _pumpArea(tester);

    await tester.longPress(find.text('hello world'));
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.text(t.translate), findsOneWidget);
    expect(find.text(t.search), findsOneWidget);

    // 框架默认项（复制 / 全选）仍在
    final l10n = MaterialLocalizations.of(
      tester.element(find.byType(AppSelectionArea)),
    );
    expect(find.text(l10n.copyButtonLabel), findsOneWidget);
    expect(find.text(l10n.selectAllButtonLabel), findsOneWidget);
  });

  testWidgets('未选中文本时不显示菜单', (tester) async {
    await _pumpArea(tester);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
  });
}
