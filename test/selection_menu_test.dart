import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/i18n/strings.g.dart';

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

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

  group('firstUrlInSelection', () {
    test('纯链接原样返回', () {
      expect(
        firstUrlInSelection('https://drive.example.com/s/abc123'),
        'https://drive.example.com/s/abc123',
      );
    });

    test('去掉结尾的标点', () {
      expect(
        firstUrlInSelection(' https://drive.example.com/s/abc123。 '),
        'https://drive.example.com/s/abc123',
      );
      expect(
        firstUrlInSelection('（https://drive.example.com/s/abc123）'),
        'https://drive.example.com/s/abc123',
      );
    });

    test('从整段文本里取第一个链接', () {
      expect(
        firstUrlInSelection('看这个 https://site.example/p/1 提取码 1234'),
        'https://site.example/p/1',
      );
    });

    test('没有链接 / 非 http(s) / 只有协议时返回 null', () {
      expect(firstUrlInSelection('hello world'), isNull);
      expect(firstUrlInSelection('magnet:?xt=urn:btih:abc'), isNull);
      expect(firstUrlInSelection('https://'), isNull);
      expect(firstUrlInSelection(''), isNull);
    });
  });

  group('firstMagnetInSelection', () {
    test('纯磁力链原样返回', () {
      const magnet =
          'magnet:?xt=urn:btih:ABCDEF0123456789&dn=name&tr=udp%3A%2F%2Fa';
      expect(firstMagnetInSelection(magnet), magnet);
    });

    test('去掉结尾的标点', () {
      expect(
        firstMagnetInSelection('magnet:?xt=urn:btih:abc。'),
        'magnet:?xt=urn:btih:abc',
      );
      expect(
        firstMagnetInSelection('（magnet:?xt=urn:btih:abc）'),
        'magnet:?xt=urn:btih:abc',
      );
    });

    test('从整段文本里取第一个磁力链', () {
      expect(
        firstMagnetInSelection('下载这个 magnet:?xt=urn:btih:abc 谢谢'),
        'magnet:?xt=urn:btih:abc',
      );
    });

    test('没有磁力链时返回 null', () {
      expect(firstMagnetInSelection('hello world'), isNull);
      expect(firstMagnetInSelection('https://site.example/p/1'), isNull);
      expect(firstMagnetInSelection(''), isNull);
    });
  });
}
