import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/log.dart';
import 'package:zxing2/qrcode.dart';

class QrAnalysisService {
  static Future<String?> decodeQrFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;

      final byteData = await uiImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final int width = uiImage.width;
      final int height = uiImage.height;
      final Int32List pixels = byteData.buffer.asInt32List();

      return await compute(_isolatedDecode, {
        'pixels': pixels,
        'width': width,
        'height': height,
      });
    } catch (e) {
      Log.error('decodeQrFromBytes', e.toString());
      return null;
    }
  }
}

String? _isolatedDecode(Map<String, dynamic> params) {
  final Int32List pixels = params['pixels'];
  final int width = params['width'];
  final int height = params['height'];

  final List<LuminanceSource> candidates = [];
  final rawSource = RGBLuminanceSource(width, height, pixels);

  candidates.add(rawSource);

  if (height > width * 1.3) {
    int cropH = (height * 0.45).round();
    candidates.add(rawSource.crop(0, height - cropH, width, cropH));
  }

  candidates.add(rawSource.invert());

  final extremePixels = Int32List(pixels.length);
  for (var i = 0; i < pixels.length; i++) {
    final p = pixels[i];
    final gray =
        ((p >> 16) & 0xFF) * 0.299 +
        ((p >> 8) & 0xFF) * 0.587 +
        (p & 0xFF) * 0.114;
    extremePixels[i] = (gray > 220) ? 0xFFFFFFFF : 0xFF000000;
  }
  candidates.add(RGBLuminanceSource(width, height, extremePixels));

  final reader = QRCodeReader();
  for (final source in candidates) {
    try {
      return reader.decode(BinaryBitmap(HybridBinarizer(source))).text;
    } catch (_) {
      try {
        return reader
            .decode(BinaryBitmap(GlobalHistogramBinarizer(source)))
            .text;
      } catch (_) {}
    }
  }
  return null;
}
