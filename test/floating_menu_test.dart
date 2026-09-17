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
    // 紧凑尺寸（默认 FAB 为 56；mini 后视觉 40、点击区 48）
    final size = tester.getSize(find.byType(FloatingActionButton).first);
    expect(size.width, lessThan(56));
    expect(size.height, lessThan(56));
  });
}
