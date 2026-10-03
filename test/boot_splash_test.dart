import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/boot_splash.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';

/// 原生启动窗口的底色。改这里必须同步改
/// android/app/src/main/res/values{,-night}/colors.xml 与 iOS LaunchScreen。
const nativeLaunchBackground = '#0F1114';

String _read(String path) => File(path).readAsStringSync();

void main() {
  testWidgets('启动页渲染 logo、loading 与版本号', (tester) async {
    await tester.pumpWidget(const BootSplash());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text("v${App.version}"), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(PolygonRefreshIndicator), findsOneWidget);
  });

  testWidgets('启动页底色固定为原生启动窗口的底色', (tester) async {
    await tester.pumpWidget(const BootSplash());
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF0F1114));
    expect(
      kBootBackground.toARGB32(),
      0xFF000000 | int.parse(nativeLaunchBackground.substring(1), radix: 16),
    );
  });

  testWidgets('logo 精确居中于屏幕正中，不被 loading 顶偏', (tester) async {
    await tester.pumpWidget(const BootSplash());
    await tester.pump();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final logo = tester.getRect(find.byType(Image));

    expect(logo.width, closeTo(kBootLogoSize, 0.5));
    expect(logo.height, closeTo(kBootLogoSize, 0.5));
    expect(logo.center.dy, closeTo(screen.height / 2, 0.5));
    expect(logo.center.dx, closeTo(screen.width / 2, 0.5));
  });

  testWidgets('loading 固定在 logo 正下方', (tester) async {
    await tester.pumpWidget(const BootSplash());
    await tester.pump();

    final logo = tester.getRect(find.byType(Image));
    final spinner = tester.getRect(find.byType(PolygonRefreshIndicator));

    expect(spinner.width, closeTo(kBootSpinnerSize, 0.5));
    expect(
      spinner.center.dy,
      closeTo(logo.bottom + kBootLogoGap + kBootSpinnerSize / 2, 0.5),
    );
  });

  test('启动页几何常量与原生资源保持一致', () {
    // Dart 侧
    expect(kBootLogoSize, 132.0);
    // Android 原生启动窗口
    for (final f in [
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ]) {
      final xml = _read(f);
      expect(xml, contains('@color/launch_background'), reason: f);
      expect(xml, contains('android:width="132dp"'), reason: f);
      expect(xml, contains('android:height="132dp"'), reason: f);
      expect(xml, contains('android:gravity="center"'), reason: f);
    }
    // Android 12+ 系统闪屏：图标与底色都要显式指定，否则先白闪再切到启动页
    for (final f in [
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      final xml = _read(f);
      expect(
        xml,
        contains('<item name="android:windowSplashScreenAnimatedIcon">'),
        reason: f,
      );
      expect(xml, contains('@drawable/splash_logo'), reason: f);
      expect(xml, contains('@color/launch_background'), reason: f);
      // SDK 里没有 windowSplashScreenIconBackgroundSize 这个属性，写了链接不过
      expect(
        xml,
        isNot(contains('windowSplashScreenIconBackgroundSize')),
        reason: f,
      );
    }
    // Android 底色
    for (final f in [
      'android/app/src/main/res/values/colors.xml',
      'android/app/src/main/res/values-night/colors.xml',
    ]) {
      expect(
        _read(f),
        contains(
          '<color name="launch_background">$nativeLaunchBackground</color>',
        ),
        reason: f,
      );
    }
    // iOS 启动画面：132pt 的 LaunchImage 居中，底色为 #0F1114
    final sb = _read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
    expect(sb, contains('name="LaunchImage"'));
    expect(
      sb,
      contains('<image name="LaunchImage" width="132" height="132"/>'),
    );
    expect(sb, contains('firstAttribute="centerY"'));
    // 0.0588/0.0667/0.0784 ≈ 15/17/20 = #0F1114
    expect(sb, contains('red="0.05882352941"'));
    expect(sb, contains('green="0.06666666667"'));
    expect(sb, contains('blue="0.07843137255"'));
  });
}
