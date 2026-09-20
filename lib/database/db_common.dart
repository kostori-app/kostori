import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kostori/foundation/app.dart';
import 'package:path/path.dart' as p;

// WAL + NORMAL：异常中断（杀进程/崩溃/强制退出）时大幅降低
// 数据库损坏（disk image malformed）概率
LazyDatabase _walDb(File file) => LazyDatabase(() async {
  return NativeDatabase.createInBackground(
    file,
    setup: (db) {
      db.execute('PRAGMA journal_mode = WAL;');
      db.execute('PRAGMA synchronous = NORMAL;');
    },
  );
});

/// 6 个本地库统一的 WAL 开库方式（替代各处手写的 LazyDatabase 样板）
LazyDatabase openWalDb(String fileName) =>
    _walDb(File(p.join(App.dataPath, fileName)));

/// WAL checkpoint 静默执行：失败不影响调用方（下次打开自动重放 WAL）。
/// 各库 checkpoint() 共用，[run] 里保留各库自己的 _guard/_withDb 包裹。
Future<void> walCheckpoint(Future<void> Function() run) async {
  try {
    await run();
  } catch (_) {}
}
