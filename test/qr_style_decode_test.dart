import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/qr_code.dart';
import 'package:kostori/utils/qr_analysis_service.dart';

Future<String?> _renderAndDecode(
  WidgetTester tester,
  String content,
  double size,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: KostoriQrCode(content: content, size: size),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  final Uint8List bytes = (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }))!;
  return tester.runAsync<String?>(
    () => QrAnalysisService.decodeQrFromBytes(bytes),
  );
}

void main() {
  final cases = <String, String>{
    'short': 'kostori://anime?id=12345&source=test',
    'bangumi': 'kostori://bangumi?id=987654',
    'watchroom':
        'kostori://watchroom?room=abc123&server=https://example.com/ws&pwd=Xk92mZ',
    'long-url':
        'https://example.com/share/anime?id=123456789&source=some_source_key&token=abcdefghijklmnopqrstuvwxyz0123456789',
  };

  for (final entry in cases.entries) {
    for (final double size in <double>[420, 260, 180]) {
      testWidgets(
        'zxing2 styled QR [${entry.key}] size=$size',
        (tester) async {
          final decoded = await _renderAndDecode(tester, entry.value, size);
          // ignore: avoid_print
          print('CASE=${entry.key} size=$size -> ${decoded == entry.value ? "OK" : "FAIL($decoded)"}');
          expect(decoded, entry.value);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
  }
}
