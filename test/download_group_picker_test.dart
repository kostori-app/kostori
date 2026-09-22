import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/download_filter.dart';

void main() {
  testWidgets('分组选择器的筛选胶囊居中', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: DownloadGroupPickerBody(current: '', onSelected: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 胶囊轨道内的滚动视图宽度应小于整宽（按内容收缩），且水平居中
    final track = find.descendant(
      of: find.byType(CapsuleOptions),
      matching: find.byType(SingleChildScrollView),
    );
    expect(track, findsOneWidget);

    final bodyWidth = tester
        .getSize(find.byType(DownloadGroupPickerBody))
        .width;
    final trackSize = tester.getSize(track);
    final trackCenter = tester.getCenter(track);
    expect(trackSize.width, lessThan(bodyWidth));
    expect(trackCenter.dx, closeTo(bodyWidth / 2, 1.0));
  });
}
