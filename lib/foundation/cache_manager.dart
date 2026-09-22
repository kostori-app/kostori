// ignore_for_file: collection_methods_unrelated_type

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/pending_requests.dart';
import 'package:kostori/utils/io.dart';
import 'package:sqlite3/sqlite3.dart';

/// 磁盘图片缓存：对外 API 与原来完全一致，sqlite 操作搬进专用后台 isolate。
///
/// 背景：此前 `_db.select/execute` 是同步调用，直接跑在 UI isolate，
/// 列表滚动时每张图一次同步查库（慢查 ≥20ms 有日志佐证），掉帧。
/// 现在主线程只留 `_memory`（纯 Map，无 IO）；所有 SQL + 清理期的文件
/// 删除都在 worker 里串行执行。文件读写（`readAsBytes/writeAsBytes`）
/// 本就是异步线程池，本来就不卡，继续留在主线程，避免大字节跨 isolate 拷贝。
class CacheManager {
  static String get cachePath => '${App.cachePath}/cache';

  static CacheManager? instance;

  /// 主线程镜像的体积（worker 为准，每次响应顺带同步；启动瞬时为 0，
  /// 原来也是异步 compute 回来之前为 0，语义一致）
  int _sizeMirror = 0;

  /// size in bytes
  int get currentSize => _sizeMirror;

  /// findCache 的内存缓存：列表滚动/重建时同一 key 会被反复查，避免每次都
  /// 跨 isolate 查 sqlite。条目只保鲜 [_memoryFreshMs]，之后回落到 worker
  ///（顺带续期），既摊平滚动期间的查询，又不改变滑动过期的语义。
  /// 写入/删除/清理时同步失效。
  final Map<String, _CacheLookup> _memory = {};
  static const int _memoryLimit = 512;
  static const int _memoryFreshMs = 30 * 1000;

  void _remember(String key, File? file, int? expires) {
    _memory.remove(key);
    _memory[key] = _CacheLookup(
      file,
      expires,
      DateTime.now().millisecondsSinceEpoch,
    );
    while (_memory.length > _memoryLimit) {
      _memory.remove(_memory.keys.first);
    }
  }

  // ── worker 通道 ────────────────────────────────────────────────

  SendPort? _workerPort;
  ReceivePort? _receivePort;

  /// worker 就绪信号：SendPort 到达即完成。_request 只等它，不轮询
  ///（轮询的 Timer 在测试 teardown 时会被判定为泄漏）。
  final Completer<void> _ready = Completer<void>();

  /// 在途的 worker 请求（配对逻辑见 [PendingRequests]）。
  final _pending = PendingRequests<Map<String, dynamic>?>();

  CacheManager._create() {
    Directory(cachePath).createSync(recursive: true);
    _receivePort = ReceivePort();
    _receivePort!.listen(_onWorkerMessage);
    Isolate.spawn(
      _cacheDbMain,
      _CacheDbInit(
        _receivePort!.sendPort,
        cachePath,
        '${App.dataPath}/cache.db',
      ),
    );
    // 启动即同步一次体积镜像并触发首次清理（原来 compute().then 同样逻辑）
    _request('stats', const {})
        .then((res) {
          if (res != null) checkCache();
        })
        .catchError((Object _) {});
  }

  void _onWorkerMessage(dynamic message) {
    if (message is SendPort) {
      _workerPort = message;
      if (!_ready.isCompleted) _ready.complete();
    } else if (message is _CacheDbResponse) {
      final err = message.error;
      if (err != null) {
        _pending.completeError(message.id, StateError(err));
        return;
      }
      final res = message.result;
      final size = res?['size'];
      if (size is int) _sizeMirror = size;
      _pending.complete(message.id, res);
    }
  }

  Future<Map<String, dynamic>?> _request(
    String op,
    Map<String, dynamic> args,
  ) async {
    await _ready.future;
    final rec = _pending.register();
    _workerPort!.send(_CacheDbRequest(rec.id, op, args));
    return rec.future;
  }

  /// Get the singleton instance of CacheManager.
  factory CacheManager() => instance ??= CacheManager._create();

  /// set cache size limit in MB
  void setLimitSize(int size) {
    _request('setLimit', {'size': size * 1024 * 1024}).catchError((Object _) {
      return null;
    });
  }

  /// 正在写入的 key 集合：同一 key 的并发写入只保留一个
  final Set<String> _writingKeys = {};

  /// Write cache to disk.
  Future<void> writeCache(
    String key,
    List<int> data, [
    int duration = 7 * 24 * 60 * 60 * 1000,
  ]) async {
    // 同一 key 并发写去重：后续写入直接跳过（内容一致）
    if (_writingKeys.contains(key)) return;
    _writingKeys.add(key);
    try {
      // 落盘位置由 worker 分配（复用已有行，旧文件不再变孤儿）；
      // 文件本身在主线程异步写，不占 UI。
      final alloc = await _request('alloc', {
        'key': key,
        'size': data.length,
        'duration': duration,
      });
      if (alloc == null) return;
      final dir = alloc['dir'] as String;
      final name = alloc['name'] as String;
      var file = File('$cachePath/$dir/$name');
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      // 先写临时文件再改名，避免读到半截文件
      var tmp = File('$cachePath/$dir/.$name.tmp');
      await tmp.writeAsBytes(data, flush: true);
      await tmp.rename(file.path);
      final expires = alloc['expires'] as int;
      _remember(key, file, expires);
      checkCacheIfRequired();
    } finally {
      _writingKeys.remove(key);
    }
  }

  /// Find cache by key.
  /// If cache is expired, it will be deleted and return null.
  /// If cache is not found, it will return null.
  /// If cache is found, it will return the file, and update the expires time.
  Future<File?> findCache(String key) async {
    var now = DateTime.now().millisecondsSinceEpoch;
    final memo = _memory[key];
    if (memo != null) {
      final fresh = now - memo.time < _memoryFreshMs;
      final notExpired = memo.expires == null || memo.expires! >= now;
      if (fresh && notExpired) {
        if (memo.file == null) return null;
        // 正命中也要确认文件还在（缓存清理可能已删掉）
        if (await memo.file!.exists()) return memo.file;
      }
      _memory.remove(key);
    }
    final res = await _request('find', {'key': key});
    if (res == null || res['hit'] != true) {
      _remember(key, null, null);
      return null;
    }
    var file = File('$cachePath/${res['dir']}/${res['name']}');
    if (await file.exists()) {
      final expires = res['expires'] as int;
      _remember(key, file, expires);
      return file;
    }
    // 行在但文件没了（外部删除/清理残留）：删行，当 miss
    unawaited(_request('delete', {'key': key}).catchError((Object _) => null));
    _remember(key, null, null);
    return null;
  }

  /// Check cache size and delete expired cache.
  /// Only check cache if current size is greater than limit size.
  void checkCacheIfRequired() {
    _request('checkIfRequired', const {}).catchError((Object _) => null);
  }

  /// Check cache size and delete expired cache.
  /// If current size is greater than limit size,
  /// delete cache until current size is less than limit size.
  Future<void> checkCache() async {
    await _request('check', const {}).catchError((Object _) => null);
  }

  /// Delete cache by key.
  Future<void> delete(String key) async {
    _memory.remove(key);
    await _request('delete', {'key': key}).catchError((Object _) => null);
  }

  /// Delete all cache.
  Future<void> clear() async {
    _memory.clear();
    await _request('clear', const {}).catchError((Object _) => null);
  }
}

/// [_CacheLookup] 的内存条目：file 为 null 表示 miss。
class _CacheLookup {
  final File? file;

  final int? expires;

  /// 写入内存的时刻，用于控制保鲜期
  final int time;

  const _CacheLookup(this.file, this.expires, this.time);
}

// ═══════════════════════════════════════════════════════════
// 后台 sqlite worker（独立 isolate，串行执行所有 SQL）
// ═══════════════════════════════════════════════════════════

class _CacheDbInit {
  final SendPort sendPort;
  final String cachePath;
  final String dbPath;

  const _CacheDbInit(this.sendPort, this.cachePath, this.dbPath);
}

class _CacheDbRequest {
  final int id;
  final String op;
  final Map<String, dynamic> args;

  const _CacheDbRequest(this.id, this.op, this.args);
}

class _CacheDbResponse {
  final int id;
  final Map<String, dynamic>? result;
  final String? error;

  const _CacheDbResponse(this.id, this.result, this.error);
}

Future<void> _cacheDbMain(_CacheDbInit init) async {
  final port = ReceivePort();
  init.sendPort.send(port.sendPort);
  final db = sqlite3.open(init.dbPath);
  db.execute('''
      CREATE TABLE IF NOT EXISTS cache (
        key TEXT PRIMARY KEY NOT NULL,
        dir TEXT NOT NULL,
        name TEXT NOT NULL,
        expires INTEGER NOT NULL,
        type TEXT
      )
    ''');
  var size = 0;
  try {
    // 启动时统计体积（原来在主线程 compute 里做）
    await for (final entity in Directory(
      init.cachePath,
    ).list(recursive: true)) {
      if (entity is File) {
        try {
          size += await entity.length();
        } catch (_) {}
      }
    }
  } catch (_) {}
  var limitSize = 2 * 1024 * 1024 * 1024;
  var dirCounter = 0;
  var checking = false;

  int fileLen(String path) {
    try {
      final f = File(path);
      return f.existsSync() ? f.lengthSync() : 0;
    } catch (_) {
      return 0;
    }
  }

  void deleteFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        size -= fileLen(path);
        f.deleteSync();
      }
    } catch (_) {}
  }

  /// 过期 sweep + 超配额 LRU，与原来 checkCache 语义一致
  void runCheck() {
    if (checking) return;
    checking = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final expired = db.select(
        'SELECT dir, name FROM cache WHERE expires < ?',
        [now],
      );
      for (final row in expired) {
        deleteFile('${init.cachePath}/${row[0]}/${row[1]}');
      }
      db.execute('DELETE FROM cache WHERE expires < ?', [now]);
      while (size > limitSize) {
        final oldest = db.select(
          'SELECT key, dir, name FROM cache ORDER BY expires ASC LIMIT 10',
        );
        if (oldest.isEmpty) break;
        var progressed = false;
        for (final row in oldest) {
          final path = '${init.cachePath}/${row[1]}/${row[2]}';
          if (File(path).existsSync()) {
            deleteFile(path);
            db.execute('DELETE FROM cache WHERE key = ?', [row[0]]);
            progressed = true;
            if (size <= limitSize) break;
          } else {
            db.execute('DELETE FROM cache WHERE key = ?', [row[0]]);
            progressed = true;
          }
        }
        if (!progressed) break;
      }
    } finally {
      checking = false;
    }
  }

  await for (final message in port) {
    if (message is! _CacheDbRequest) continue;
    try {
      Map<String, dynamic>? result;
      switch (message.op) {
        case 'stats':
          result = {'size': size};
        case 'setLimit':
          limitSize = (message.args['size'] as int?) ?? limitSize;
          result = {'size': size};
        case 'find':
          final key = message.args['key'] as String;
          final rows = db.select(
            'SELECT dir, name, expires FROM cache WHERE key = ?',
            [key],
          );
          if (rows.isEmpty) {
            result = {'hit': false, 'size': size};
          } else {
            final now = DateTime.now().millisecondsSinceEpoch;
            final expires = rows.first[2] as int;
            if (expires < now) {
              // 过期：删行 + 删文件（原来主线程做文件删除）
              db.execute('DELETE FROM cache WHERE key = ?', [key]);
              deleteFile('${init.cachePath}/${rows.first[0]}/${rows.first[1]}');
              result = {'hit': false, 'size': size};
            } else {
              // 命中续期 7 天（与原来 findCache 语义一致）
              final newExpires = now + 7 * 24 * 60 * 60 * 1000;
              db.execute('UPDATE cache SET expires = ? WHERE key = ?', [
                newExpires,
                key,
              ]);
              result = {
                'hit': true,
                'dir': rows.first[0] as String,
                'name': rows.first[1] as String,
                'expires': newExpires,
                'size': size,
              };
            }
          }
        case 'alloc':
          // 分配落盘位置 + 预占体积：复用已有行（旧文件不再变孤儿），
          // 否则轮转新位置。文件由主线程随后写入。
          final key = message.args['key'] as String;
          final dataLen = message.args['size'] as int? ?? 0;
          final duration =
              message.args['duration'] as int? ?? 7 * 24 * 60 * 60 * 1000;
          final existing = db.select(
            'SELECT dir, name FROM cache WHERE key = ?',
            [key],
          );
          final String dir;
          final String name;
          if (existing.isNotEmpty) {
            dir = existing.first[0] as String;
            name = existing.first[1] as String;
            size -= fileLen('${init.cachePath}/$dir/$name');
          } else {
            dirCounter++;
            dirCounter %= 100;
            dir = dirCounter.toString();
            // 非 ASCII key 按 utf8 取字节做 md5（codeUnits 是 UTF-16 码元）
            name = md5.convert(utf8.encode(key)).toString();
          }
          final expires = DateTime.now().millisecondsSinceEpoch + duration;
          db.execute(
            'INSERT OR REPLACE INTO cache (key, dir, name, expires)'
            ' VALUES (?, ?, ?, ?)',
            [key, dir, name, expires],
          );
          size += dataLen;
          result = {'dir': dir, 'name': name, 'expires': expires, 'size': size};
        case 'delete':
          final key = message.args['key'] as String;
          final rows = db.select('SELECT dir, name FROM cache WHERE key = ?', [
            key,
          ]);
          if (rows.isNotEmpty) {
            db.execute('DELETE FROM cache WHERE key = ?', [key]);
            deleteFile('${init.cachePath}/${rows.first[0]}/${rows.first[1]}');
          }
          result = {'size': size};
        case 'clear':
          try {
            await Directory(init.cachePath).delete(recursive: true);
          } catch (_) {}
          try {
            await Directory(init.cachePath).create(recursive: true);
          } catch (_) {}
          db.execute('DELETE FROM cache');
          size = 0;
          result = {'size': size};
        case 'check':
          runCheck();
          result = {'size': size};
        case 'checkIfRequired':
          if (size > limitSize) runCheck();
          result = {'size': size};
        default:
          throw StateError('unknown cache op: ${message.op}');
      }
      init.sendPort.send(_CacheDbResponse(message.id, result, null));
    } catch (e) {
      init.sendPort.send(_CacheDbResponse(message.id, null, e.toString()));
    }
  }
}
