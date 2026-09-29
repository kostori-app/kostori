import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/boot_splash.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/app_theme.dart';

void main() {
  testWidgets('启动页渲染 logo 与版本号', (tester) async {
    await tester.pumpWidget(const BootSplash());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text("v${App.version}"), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('启动页底色与正式界面的 surface 一致', (tester) async {
    await tester.pumpWidget(const BootSplash());
    await tester.pump();

    final expected = buildAppTheme(
      primary: Colors.blue,
      brightness: Brightness.light,
      amoled: false,
    ).colorScheme.surface;
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, expected);
  });
}
