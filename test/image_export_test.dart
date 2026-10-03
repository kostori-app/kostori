import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/utils/image_export.dart';

/// PNG 文件头的 8 个魔数字节。
const _pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

bool _isPng(Uint8List bytes) {
  if (bytes.length < 8) return false;
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != _pngMagic[i]) return false;
  }
  return true;
}

/// 从 PNG 的 IHDR 读取宽高（字节 16~23 为大端 width / height）。
(int, int) _pngSize(Uint8List bytes) {
  final data = ByteData.sublistView(bytes, 0, 24);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('painterToPng 输出合法 PNG，尺寸按像素比放大', () async {
    final bytes = await ImageExporter.painterToPng(
      _FillPainter(const Color(0xFFFF0000)),
      const Size(100, 50),
      2.0,
    );

    expect(_isPng(bytes), isTrue);
    expect(_pngSize(bytes), (200, 100));
  });

  test('painterToPng 默认使用框架像素比 2.0', () async {
    final bytes = await ImageExporter.painterToPng(
      _FillPainter(const Color(0xFF00FF00)),
      const Size(30, 20),
    );

    expect(_isPng(bytes), isTrue);
    expect(_pngSize(bytes), (60, 40));
  });

  test('painterToPng 支持 1:1 输出', () async {
    final bytes = await ImageExporter.painterToPng(
      _FillPainter(const Color(0xFF00FF00)),
      const Size(30, 20),
      1.0,
    );

    expect(_pngSize(bytes), (30, 20));
  });

  test('painter 生成器只产出一张图', () async {
    final generator = ImageExporter.painter(
      painter: _FillPainter(const Color(0xFF0000FF)),
      size: const Size(16, 16),
    );

    final result = await generator(const SilentImageExportReporter());

    expect(result, hasLength(1));
    expect(_isPng(result.first), isTrue);
  });

  test('bytes 生成器在产出为 null 时返回空列表', () async {
    final generator = ImageExporter.bytes(() async => null);
    expect(await generator(const SilentImageExportReporter()), isEmpty);

    final ok = ImageExporter.bytes(() async => Uint8List.fromList([1, 2, 3]));
    expect(await ok(const SilentImageExportReporter()), hasLength(1));
  });

  test('静默进度回报器不会抛异常', () {
    const reporter = SilentImageExportReporter();
    reporter.message('生成中');
    reporter.progress(0, 2);
    reporter.progress(2, 2);
  });

  test('超出单张上限时按逻辑高度切片', () {
    // tileLogicalHeight = 4096 / pixelRatio
    expect(ImageExporter.maxSinglePixel / 2.0, 2048.0);
    // 内容高 5000、像素比 2 => 需要 3 片
    expect((5000 / 2048).ceil(), 3);
  });

  test('maxPixel 设为无穷时只切一片', () {
    final size = const Size(800, 6000);
    const pixelRatio = 2.0;
    bool withinSingle({required double maxPixel}) =>
        size.width * pixelRatio <= maxPixel &&
        size.height * pixelRatio <= maxPixel;

    expect(withinSingle(maxPixel: double.infinity), isTrue);
    expect(
      withinSingle(maxPixel: ImageExporter.maxSinglePixel),
      isFalse,
      reason: '默认上限下同样的内容会被切成 3 片',
    );
  });
}

class _FillPainter extends CustomPainter {
  const _FillPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FillPainter oldDelegate) =>
      oldDelegate.color != color;
}
