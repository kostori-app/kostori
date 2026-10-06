import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/download_database.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';
import 'package:path/path.dart' as p;

Uint8List _infoBytes(bool singleFile) => Uint8List.fromList([
  ...ascii.encode(
    singleFile
        ? 'd6:lengthi4e4:name9:video.mp412:piece lengthi4e6:pieces20:'
        : 'd5:filesld6:lengthi4e4:pathl9:video.mp4ee'
              'd6:lengthi2e4:pathl8:note.txteee'
              '4:name4:pack12:piece lengthi4e6:pieces40:',
  ),
  ...List<int>.filled(singleFile ? 20 : 40, 0),
  101,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kostori_torrent_remove_');
    App.dataPath = root.path;
  });
  tearDownAll(() async {
    await DownloadDatabase.instance.close();
    await root.delete(recursive: true);
  });

  for (final singleFile in [false, true]) {
    for (final deleteFiles in [false, true]) {
      test(
        '${singleFile ? '单文件' : '多文件'}恢复任务${deleteFiles ? '删除改名文件及状态' : '仅删除任务保留文件及状态'}',
        () async {
          final directory = await Directory(
            p.join(root.path, '${singleFile}_$deleteFiles'),
          ).create();
          final bytes = _infoBytes(singleFile);
          final model = TorrentParser.parseFromInfoBytes(bytes);
          final engineRoot = singleFile
              ? p.join(directory.path, model.name)
              : directory.path;
          await Directory(engineRoot).create(recursive: true);
          final job = TorrentJob(
            id: '${singleFile}_$deleteFiles',
            magnet: 'magnet:?xt=urn:btih:${model.infoHash}',
            torrentPath: p.join(directory.path, 'metadata.torrent'),
            savePath: directory.path,
            createdAt: 0,
            status: TorrentJobStatus.paused,
            hasMetadata: true,
          );
          await File(job.torrentPath).writeAsBytes(bytes);
          final payloads = <File>[];
          final mappings = <String, String>{};
          for (var i = 0; i < model.files.length; i++) {
            final file = model.files[i];
            final path = i == 0
                ? p.join(engineRoot, singleFile ? '' : 'pack', 'renamed.mp4')
                : p.join(engineRoot, file.path);
            final local = File(path);
            await local.parent.create(recursive: true);
            await local.writeAsBytes(List<int>.filled(file.length, 1));
            payloads.add(local);
            mappings[file.path] = path;
          }
          final pathsFile = File(
            p.join(engineRoot, '${model.infoHash}.bt.paths.json'),
          );
          await pathsFile.writeAsString(jsonEncode(mappings));
          final unrelated = File(p.join(directory.path, 'keep.txt'));
          await unrelated.writeAsString('keep');
          await DownloadDatabase.instance.saveJobJson([
            jsonEncode(job.toJson()),
          ]);
          final container = ProviderContainer();
          final manager = container.read(torrentManagerProvider.notifier);
          try {
            await manager.init();
            final restored = manager.jobs.single;
            // 只 prepare 恢复，不读写 DownloadFile：覆盖内部 _file 尚未赋值。
            expect(
              manager.filesOf(restored).map((file) => file.localPath).toSet(),
              payloads.map((file) => file.path).toSet(),
            );
            await manager.remove(restored, deleteFiles: deleteFiles);
            expect(manager.jobs, isEmpty);
            for (final file in payloads) {
              expect(await file.exists(), !deleteFiles, reason: file.path);
            }
            expect(await pathsFile.exists(), !deleteFiles);
            expect(
              await File(p.join(engineRoot, '${model.infoHash}.bt.state'))
                  .exists(),
              !deleteFiles,
            );
            expect(await unrelated.readAsString(), 'keep');
            expect(await directory.exists(), isTrue);
            await Future<void>.delayed(Duration.zero);
          } finally {
            container.dispose();
          }
        },
      );
    }
  }

  test('文件删除失败保留任务和改名记录，重试时没有引擎也能删除', () async {
    final directory = await Directory(p.join(root.path, 'retry')).create();
    final bytes = _infoBytes(false);
    final model = TorrentParser.parseFromInfoBytes(bytes);
    final renamed = File(p.join(directory.path, 'pack', 'renamed.mp4'));
    await renamed.parent.create(recursive: true);
    await renamed.writeAsBytes([1, 2, 3, 4]);
    final pathsFile = File(
      p.join(directory.path, '${model.infoHash}.bt.paths.json'),
    );
    await pathsFile.writeAsString(
      jsonEncode({model.files.first.path: renamed.path}),
    );
    final job = TorrentJob(
      id: 'retry',
      magnet: 'magnet:?xt=urn:btih:${model.infoHash}',
      torrentPath: p.join(directory.path, 'metadata.torrent'),
      savePath: directory.path,
      createdAt: 0,
      status: TorrentJobStatus.paused,
      hasMetadata: true,
    );
    await File(job.torrentPath).writeAsBytes(bytes);
    await DownloadDatabase.instance.saveJobJson([jsonEncode(job.toJson())]);
    final container = ProviderContainer();
    final manager = container.read(torrentManagerProvider.notifier);
    try {
      await manager.init();
      final restored = manager.jobs.single;
      // 用同名目录模拟文件无法清理，不依赖各平台不同的权限语义。
      await renamed.delete();
      await Directory(renamed.path).create();
      await expectLater(
        manager.remove(restored),
        throwsA(isA<FileSystemException>()),
      );
      expect(manager.jobs, [restored]);
      expect(manager.engineOf(restored), isNull);
      expect(await File(job.torrentPath).exists(), isTrue);
      expect(await pathsFile.exists(), isTrue);

      await Directory(renamed.path).delete();
      await renamed.writeAsBytes([1, 2, 3, 4]);
      await manager.remove(restored);
      expect(manager.jobs, isEmpty);
      expect(await renamed.exists(), isFalse);
      expect(await pathsFile.exists(), isFalse);
      expect(await renamed.parent.exists(), isFalse);
      await Future<void>.delayed(Duration.zero);
    } finally {
      container.dispose();
    }
  });
}
