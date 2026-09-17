import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/ui_components.dart';

void main() {
  testWidgets('FloatingMenu 使用紧凑尺寸且不溢出', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                bottom: 10,
                right: 10,
                child: FloatingMenu(
                  controller: controller,
                  child: [
                    [
                      SpeedDialChild(
                        child: const Icon(Icons.refresh),
                        onTap: () {},
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 磨砂玻璃（BlurEffect → BackdropFilter）+ 紧凑 40 圆形
    expect(find.byType(BackdropFilter), findsWidgets);
    final size = tester.getSize(find.byType(BackdropFilter).first);
    expect(size.width, 40);
    expect(size.height, 40);
  });

  testWidgets('展开后的子按钮同样是磨砂玻璃且不溢出', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GridSpeedDial(
              frosted: true,
              mini: true,
              isOpenOnStart: true,
              buttonSize: const Size(40, 40),
              childrenButtonSize: const Size(40, 40),
              icon: Icons.menu,
              activeIcon: Icons.close,
              childrens: [
                [
                  SpeedDialChild(child: const Icon(Icons.refresh)),
                  SpeedDialChild(child: const Icon(Icons.delete_outline)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 根按钮 + 2 个子按钮
    expect(find.byType(BackdropFilter), findsNWidgets(3));
    expect(
      tester.getSize(find.byType(BackdropFilter).last),
      const Size(40, 40),
    );
  });
}
