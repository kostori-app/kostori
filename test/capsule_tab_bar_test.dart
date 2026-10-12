import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/i18n/strings.g.dart';

void main() {
  testWidgets('选中 tab 长按可搜索并快速切换', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp(home: _TabHost())),
    );
    await tester.pumpAndSettle();

    expect(find.text('第二项'), findsOneWidget);
    await tester.longPress(find.text('第二项'));
    await tester.pumpAndSettle();

    expect(find.text(t.quickSelect), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '第三');
    await tester.pump();
    final thirdItem = find.descendant(
      of: find.byType(Sheet),
      matching: find.text('第三项'),
    );
    expect(thirdItem, findsOneWidget);
    await tester.tap(thirdItem);
    await tester.pumpAndSettle();

    final state = tester.state<_TabHostState>(find.byType(_TabHost));
    expect(state.controller.index, 2);
    expect(find.text(t.quickSelect), findsNothing);
  });

  testWidgets('未选中的 tab 长按不会打开快速选择', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp(home: _TabHost())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('第一项'));
    await tester.pumpAndSettle();

    expect(find.text(t.quickSelect), findsNothing);
  });

  testWidgets('仅传进度、不标记选中项的 CapsuleOptions 也能搜索切换', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp(home: _CapsuleOptionsHost())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('第一项'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '第四');
    await tester.pump();
    final fourthItem = find.descendant(
      of: find.byType(Sheet),
      matching: find.text('第四项'),
    );
    expect(fourthItem, findsOneWidget);
    await tester.tap(fourthItem);
    await tester.pumpAndSettle();

    final state = tester.state<_CapsuleOptionsHostState>(
      find.byType(_CapsuleOptionsHost),
    );
    expect(state.controller.index, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('纯点击 CapsuleOptions 长按选中项可搜索并跳到远处选项', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp(home: _ClickOnlyCapsuleHost())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('选项 2'));
    await tester.pumpAndSettle();
    expect(find.text(t.quickSelect), findsOneWidget);
    await tester.enterText(find.byType(TextField), '选项 16');
    await tester.pump();
    await tester.tap(find.widgetWithText(SelectCard, '选项 16'));
    await tester.pumpAndSettle();

    expect(
      tester
          .state<_ClickOnlyCapsuleHostState>(find.byType(_ClickOnlyCapsuleHost))
          .selectedIndex,
      15,
    );
    expect(find.text(t.quickSelect), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索无结果可清空，关闭面板保留原 tab', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp(home: _TabHost())),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('第二项'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text(t.noSearchResultsFound), findsOneWidget);
    expect(find.byType(SelectCard), findsNothing);

    await tester.tap(find.byTooltip(t.clear));
    await tester.pump();
    expect(find.byType(SelectCard), findsNWidgets(3));
    final selectedCard = tester.widget<SelectCard>(
      find.widgetWithText(SelectCard, '第二项'),
    );
    expect(selectedCard.selected, isTrue);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    final state = tester.state<_TabHostState>(find.byType(_TabHost));
    expect(state.controller.index, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机键盘弹出时搜索和结果保持可见', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp(home: _TabHost())),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('第二项'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.enterText(find.byType(TextField), '第三');
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(find.byType(Sheet)).dy, lessThanOrEqualTo(300));
    expect(tester.takeException(), isNull);
    tester.testTextInput.hide();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Sheet), matching: find.text('第三项')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.state<_TabHostState>(find.byType(_TabHost)).controller.index,
      2,
    );
  });
}

class _TabHost extends StatefulWidget {
  @override
  State<_TabHost> createState() => _TabHostState();
}

class _TabHostState extends State<_TabHost>
    with SingleTickerProviderStateMixin {
  late final TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CapsuleTabBar(
        controller: controller,
        labels: const ['第一项', '第二项', '第三项'],
      ),
    );
  }
}

class _CapsuleOptionsHost extends StatefulWidget {
  @override
  State<_CapsuleOptionsHost> createState() => _CapsuleOptionsHostState();
}

class _CapsuleOptionsHostState extends State<_CapsuleOptionsHost>
    with SingleTickerProviderStateMixin {
  late final TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CapsuleOptions(
        progress: controller.animation,
        scrollable: true,
        children: [
          for (var i = 0; i < controller.length; i++)
            CapsuleOption(
              text: ['第一项', '第二项', '第三项', '第四项'][i],
              // 模拟只用 progress 驱动选中状态的调用。
              isSelected: false,
              onTap: () => controller.animateTo(i),
            ),
        ],
      ),
    );
  }
}

class _ClickOnlyCapsuleHost extends StatefulWidget {
  @override
  State<_ClickOnlyCapsuleHost> createState() => _ClickOnlyCapsuleHostState();
}

class _ClickOnlyCapsuleHostState extends State<_ClickOnlyCapsuleHost> {
  int selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CapsuleOptions(
        quickSelect: true,
        scrollable: true,
        children: [
          for (var i = 0; i < 16; i++)
            CapsuleOption(
              text: '选项 ${i + 1}',
              isSelected: selectedIndex == i,
              onTap: () => setState(() => selectedIndex = i),
            ),
        ],
      ),
    );
  }
}
