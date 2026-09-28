import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/download/download_file_writer.dart';

void main() {
  test('后台写盘 isolate：多文件并发交错写入内容正确', () async {
    final writer = await DownloadFileWriter.instance();
    expect(writer, isNotNull, reason: '写盘 isolate 应可创建');

    final dir = await Directory.systemTemp.createTemp('dl_writer_test');
    final pathA = '${dir.path}${Platform.pathSeparator}a.bin';
    final pathB = '${dir.path}${Platform.pathSeparator}b.bin';

    final bytesA = Uint8List.fromList(
      List<int>.generate(300000, (i) => i % 251),
    );
    final bytesB = Uint8List.fromList(
      List<int>.generate(200000, (i) => (i * 7 + 3) % 241),
    );

    final sinkA = await writer!.open(pathA);
    final sinkB = await writer.open(pathB);

    // A/B 交错分块写入，验证数据按 handle 正确归位、顺序不乱
    var ia = 0;
    var ib = 0;
    while (ia < bytesA.length || ib < bytesB.length) {
      if (ia < bytesA.length) {
        final end = (ia + 4096).clamp(0, bytesA.length);
        final bp = sinkA.add(Uint8List.sublistView(bytesA, ia, end));
        if (bp != null) await bp;
        ia = end;
      }
      if (ib < bytesB.length) {
        final end = (ib + 8192).clamp(0, bytesB.length);
        final bp = sinkB.add(Uint8List.sublistView(bytesB, ib, end));
        if (bp != null) await bp;
        ib = end;
      }
    }

    await sinkA.flush();
    await sinkB.flush();
    await sinkA.close();
    await sinkB.close();

    expect(await File(pathA).readAsBytes(), bytesA);
    expect(await File(pathB).readAsBytes(), bytesB);

    await dir.delete(recursive: true);
  });

  test('后台写盘 isolate：append 模式在已有内容后追加', () async {
    final writer = await DownloadFileWriter.instance();
    expect(writer, isNotNull);

    final dir = await Directory.systemTemp.createTemp('dl_writer_append');
    final path = '${dir.path}${Platform.pathSeparator}c.bin';
    await File(path).writeAsBytes([1, 2, 3]);

    final sink = await writer!.open(path, append: true);
    final tail = Uint8List.fromList([4, 5, 6, 7]);
    final bp = sink.add(tail);
    if (bp != null) await bp;
    await sink.flush();
    await sink.close();

    expect(await File(path).readAsBytes(), [1, 2, 3, 4, 5, 6, 7]);

    await dir.delete(recursive: true);
  });

  test('后台写盘 isolate：超过背压阈值的大量写入完整落盘', () async {
    final writer = await DownloadFileWriter.instance();
    expect(writer, isNotNull);

    final dir = await Directory.systemTemp.createTemp('dl_writer_big');
    final path = '${dir.path}${Platform.pathSeparator}big.bin';

    const chunkSize = 64 * 1024;
    const total = 12 * 1024 * 1024; // 12MB > 8MB 背压阈值
    final chunk = Uint8List.fromList(
      List<int>.generate(chunkSize, (i) => i % 256),
    );

    final sink = await writer!.open(path);
    var written = 0;
    while (written < total) {
      final bp = sink.add(chunk);
      written += chunk.length;
      if (bp != null) await bp;
    }
    await sink.flush();
    await sink.close();

    expect(await File(path).length(), written);

    await dir.delete(recursive: true);
  });
}
