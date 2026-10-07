import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/me_plugin/me_plugin.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/me/me_page_plugins.dart';

const _detailText =
    'Favorites: 55\nCode: HTUT-708\n'
    'Release: Wed Oct 07 2026 09:00:00 GMT+0900 (Japan Standard Time)';

class _DetailPlugin extends MePagePlugin {
  _DetailPlugin()
    : super(
        name: 'Fixture',
        key: 'fixture',
        version: '1',
        description: '',
        filePath: '',
      );

  @override
  Future<List<dynamic>> page(
    String name, [
    Map<String, dynamic> params = const {},
  ]) async => [
    {
      'type': 'detailPage',
      'sections': [
        {'type': 'imageText', 'text': _detailText, 'showTitle': false},
      ],
    },
  ];
}

void main() {
  for (final width in [800.0, 320.0]) {
    testWidgets('detail selection excludes trailing blank space at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: PluginSubPage(
              plugin: _DetailPlugin(),
              name: 'detail',
              params: const {'title': 'Fixture'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<EditableTextState>(find.byType(EditableText));
      final editable = state.renderEditable;
      final start = _detailText.indexOf('HTUT-708');
      final selections = [
        TextSelection(
          baseOffset: start,
          extentOffset: start + 'HTUT-708'.length,
        ),
        TextSelection(
          baseOffset: start,
          extentOffset: start + 'HTUT-708\n'.length,
        ),
      ];
      for (final selection in selections) {
        state.widget.controller.selection = selection;
        await tester.pump();

        final painter = TextPainter(
          text: editable.text,
          textDirection: editable.textDirection,
          textScaler: editable.textScaler,
        )..layout(maxWidth: editable.size.width);
        addTearDown(painter.dispose);
        final glyphEnd = painter
            .getBoxesForSelection(selection)
            .map((box) => box.right)
            .reduce((a, b) => a > b ? a : b);
        final highlightEnd = editable
            .getBoxesForSelection(selection)
            .map((box) => box.right)
            .reduce((a, b) => a > b ? a : b);

        expect(highlightEnd, lessThanOrEqualTo(glyphEnd + 0.1));
      }
      expect(state.widget.controller.text, _detailText);
      expect(tester.takeException(), isNull);
    });
  }
}
