import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/custom_markdown_widget.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';

void main() {
  testWidgets('markdown 代码块带语言头与复制按钮且不报错', (tester) async {
    const md = '''
# 标题

正文一段。

- 第一项
- 第二项

```dart
final x = 1;
  final y = 2;
```

> 引用

---
''';
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CustomMarkdownWidget(data: md)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 语言标签 + 复制按钮
    expect(find.text('dart'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
    // 标题 / 列表项 / 引用都渲染出来
    expect(find.textContaining('标题'), findsOneWidget);
    expect(find.textContaining('第一项'), findsOneWidget);
    expect(find.textContaining('引用'), findsOneWidget);
  });

  testWidgets('连续列表项保持紧凑（不产生松散列表空白）', (tester) async {
    final out = Utils.normalizeData('一\n二\n\n- a\n- b', indentFirstLine: false);
    expect(out.contains('- a\n\n- b'), isFalse);
    expect(out, contains('- a\n- b'));
  });
}
