// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/utils/data.dart';
import 'package:kostori/utils/io.dart';
import 'package:webdav_client/webdav_client.dart' hide File;

/// 远端文件信息（用于判断是否已同步）
class RemoteFileInfo {
  final String name;
  final int size;
  final DateTime? modified;

  const RemoteFileInfo({required this.name, this.size = 0, this.modified});
}

class DataSync with ChangeNotifier {
  DataSync._() {
    final t = appdata.implicitData['dataLastSyncTime'];
    if (t is int) _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(t);
    if (isEnabled) {
      downloadData();
    }
    LocalFavoritesManager().onChanged.listen((_) => onDataChanged());
    AnimeSourceManager().addListener(onDataChanged);
    if (App.isDesktop) {
      Future.delayed(const Duration(seconds: 1), () {
        // 无头模式没有 UI 上下文（rootContext 为 null），直接跳过窗口监听
        final ctx = App.rootNavigatorKey.currentContext;
        if (ctx == null) return;
        var controller = WindowFrame.of(ctx);
        controller.addCloseListener(_handleWindowClose);
      });
    }
  }

  static DataSync? instance;

  factory DataSync() => instance ?? (instance = DataSync._());

  double? _progress;

  double? get progress => _progress;

  bool _isDownloading = false;

  bool get isDownloading => _isDownloading;

  bool _isUploading = false;

  bool get isUploading => _isUploading;

  bool _haveWaitingTask = false;

  String? _lastError;

  DateTime? _lastSyncTime;

  /// 上次成功同步的时间
  DateTime? get lastSyncTime => _lastSyncTime;

  void _recordSyncSuccess() {
    final now = DateTime.now();
    _lastSyncTime = now;
    appdata.implicitData['dataLastSyncTime'] = now.millisecondsSinceEpoch;
    appdata.writeImplicitData();
    notifyListeners();
  }

  String? get lastError => _lastError;

  bool get isEnabled {
    var config = appdata.settings['webdav'];
    var autoSync = appdata.implicitData['webdavAutoSync'] ?? false;
    return autoSync && config is List && config.isNotEmpty;
  }

  Timer? _uploadDebounce;
  bool _dirty = false;

  /// 数据变化时触发：节流合并短时间内的多次变化为一次上传，
  /// 避免频繁上下行占用流量（例如频繁切换页面、逐集更新进度）。
  void onDataChanged() {
    if (!isEnabled) return;
    _dirty = true;
    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(const Duration(seconds: 5), () {
      _uploadDebounce = null;
      if (!_dirty) return;
      // 距上次成功同步过近（<30s）则暂不上传；但保留 dirty 并定时重试，
      // 避免“只在下次改动才触发”（移动端退出时不依赖关窗兜底会丢改动）
      if (_lastSyncTime != null &&
          DateTime.now().difference(_lastSyncTime!) <
              const Duration(seconds: 30)) {
        _uploadDebounce = Timer(const Duration(seconds: 31), () {
          _uploadDebounce = null;
          if (_dirty) {
            _dirty = false;
            unawaited(uploadData());
          }
        });
        return;
      }
      _dirty = false;
      unawaited(uploadData());
    });
  }

  bool _handleWindowClose() {
    // 关闭前尽力刷出未触发防抖的待上传变化，但不阻塞退出：
    // 不再因“正在上传”而弹窗拦截，用户想退就直接退（上传会被中断）。
    if (_uploadDebounce != null) {
      _uploadDebounce?.cancel();
      _uploadDebounce = null;
      if (_dirty) {
        _dirty = false;
        unawaited(uploadData());
      }
    }
    return true;
  }

  List<String>? _validateConfig() {
    var config = appdata.settings['webdav'];
    if (config is! List) return null;
    if (config.isEmpty) return [];
    if (config.length != 3 || config.whereType<String>().length != 3) {
      return null;
    }
    return List.from(config);
  }

  /// 稳定的设备标识（持久化，用于多端同步时区分文件名，避免互相覆盖删除）
  String _deviceTag() {
    final existing = appdata.implicitData['sync_device_tag'];
    if (existing is String && existing.isNotEmpty) return existing;
    final tag = const Uuid().v4().replaceAll('-', '').substring(0, 6);
    appdata.implicitData['sync_device_tag'] = tag;
    appdata.writeImplicitData();
    return tag;
  }

  /// 远端清单文件名（记录各部分的版本/大小/时间）
  static const _manifestName = 'manifest.json';

  /// 同步数据版本号（存 implicitData，不随 appdata.json 同步，
  /// 否则版本号本身会让「数据」部分每次都被判定为已变化）
  int get _dataVersion =>
      (appdata.implicitData['syncDataVersion'] as int?) ??
      (appdata.settings['dataVersion'] as int? ?? 0);

  void _setDataVersion(int v) {
    appdata.implicitData['syncDataVersion'] = v;
    appdata.writeImplicitData();
  }

  /// 读取远端清单（无则返回 null）
  Future<Res<Map<String, dynamic>?>> readManifest() async {
    final client = _client();
    if (client == null) return const Res(null);
    try {
      final bytes = await client.read(_manifestName);
      if (bytes.isEmpty) return const Res(null);
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map<String, dynamic>
          ? Res(decoded)
          : const Res(null);
    } catch (_) {
      return const Res(null);
    }
  }

  /// 上传单个部分（分部分同步）
  Future<Res<bool>> uploadOnePart(SyncPart part) async {
    final client = _client();
    if (client == null) return const Res.error('Invalid WebDAV configuration');
    _isUploading = true;
    _progress = null;
    notifyListeners();
    try {
      await prepareSyncPart(part.key);
      final file = await exportPart(part.key);
      try {
        final dir = _normDir(part.dir);
        await client.mkdirAll(dir);
        await client.write(
          _join(dir, '${part.name}.kostori'),
          await file.readAsBytes(),
          onProgress: (count, total) {
            _progress = total > 0 ? count / total : null;
            notifyListeners();
          },
        );
      } finally {
        file.deleteIgnoreError();
      }
      return const Res(true);
    } catch (e, s) {
      Log.error('Upload Part', e, s);
      return Res.error(e.toString());
    } finally {
      _isUploading = false;
      _progress = null;
      notifyListeners();
    }
  }

  /// 下载单个部分（分部分同步）
  Future<Res<bool>> downloadOnePart(SyncPart part) async {
    final client = _client();
    if (client == null) return const Res.error('Invalid WebDAV configuration');
    _isDownloading = true;
    _progress = null;
    notifyListeners();
    try {
      final local = File(
        FilePath.join(App.cachePath, 'sync_${part.key}.kostori'),
      );
      await client.read2File(
        _join(_normDir(part.dir), '${part.name}.kostori'),
        local.path,
        onProgress: (count, total) {
          _progress = total > 0 ? count / total : null;
          notifyListeners();
        },
      );
      await importPart(local);
      local.deleteIgnoreError();
      return const Res(true);
    } catch (e, s) {
      Log.error('Download Part', e, s);
      return Res.error(e.toString());
    } finally {
      _isDownloading = false;
      _progress = null;
      notifyListeners();
    }
  }

  Future<Res<bool>> uploadData() async {
    if (isDownloading) return const Res(true);
    if (_haveWaitingTask) return const Res(true);
    while (isUploading) {
      _haveWaitingTask = true;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _haveWaitingTask = false;
    _isUploading = true;
    _lastError = null;
    notifyListeners();
    try {
      var config = _validateConfig();
      if (config == null) {
        _lastError = 'Invalid WebDAV configuration';
        return const Res.error('Invalid WebDAV configuration');
      }
      if (config.isEmpty) return const Res(true);

      var client = newClient(
        config[0],
        user: config[1],
        password: config[2],
        adapter: WebdavRHttpAdapter(),
      );

      try {
        // 读取旧清单：内容未变化的部分跳过上传（哈希比对）
        final prevRes = await readManifest();
        final prevManifest = prevRes.dataOrNull;
        final remoteVersion = (prevManifest?['version'] as num?)?.toInt() ?? 0;
        final newVersion =
            (remoteVersion > _dataVersion ? remoteVersion : _dataVersion) + 1;
        final prevParts =
            (prevManifest?['parts'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final partsMeta = <String, dynamic>{};
        var uploaded = 0;
        for (final part in syncParts) {
          await prepareSyncPart(part.key);
          final hash = await partContentHash(part.key);
          final prev = prevParts[part.key];
          final prevHash = prev is Map ? prev['hash']?.toString() : null;
          if (prevHash != null && prevHash == hash) {
            // 未变化：跳过上传，沿用旧元数据
            partsMeta[part.key] = prev;
            continue;
          }
          final file = await exportPart(part.key);
          try {
            final bytes = await file.readAsBytes();
            final dir = _normDir(part.dir);
            await client.mkdirAll(dir);
            await client.write(
              _join(dir, '${part.name}.kostori'),
              bytes,
              onProgress: (count, total) {
                _progress = total > 0 ? count / total : null;
                notifyListeners();
              },
            );
            partsMeta[part.key] = {
              'version': newVersion,
              'size': bytes.length,
              'time': DateTime.now().millisecondsSinceEpoch,
              'hash': hash,
            };
            uploaded++;
          } finally {
            file.deleteIgnoreError();
          }
        }
        if (uploaded == 0) {
          // 没有任何变化：不推进版本、不重写清单（避免其他端无谓下载）
          Log.info("Upload Data", 'No changes to upload');
          return const Res(true);
        }
        final manifest = jsonEncode({
          'version': newVersion,
          'device': _deviceTag(),
          'time': DateTime.now().millisecondsSinceEpoch,
          'parts': partsMeta,
        });
        await client.write(_manifestName, utf8.encode(manifest));
        // 仅在全部上传成功后才推进本地版本号（失败不推进，避免漏下载）
        _setDataVersion(newVersion);
        // 记录本次上传后的各部分哈希，避免本机之后重复下载自己刚传的内容
        final syncedHashes = <String, dynamic>{};
        for (final entry in partsMeta.entries) {
          final meta = entry.value;
          if (meta is Map && meta['hash'] != null) {
            syncedHashes[entry.key] = meta['hash'];
          }
        }
        appdata.implicitData['syncPartHashes'] = syncedHashes;
        appdata.writeImplicitData();
        Log.info(
          "Upload Data",
          "Uploaded $uploaded/${syncParts.length} parts (v$newVersion)",
        );
        return const Res(true);
      } catch (e, s) {
        Log.error("Upload Data", e, s);
        _lastError = e.toString();
        return Res.error(e.toString());
      }
    } finally {
      _isUploading = false;
      _progress = null;
      if (_lastError == null) _recordSyncSuccess();
      notifyListeners();
    }
  }

  Future<Res<bool>> downloadData() async {
    if (_haveWaitingTask) return const Res(true);
    while (isDownloading || isUploading) {
      _haveWaitingTask = true;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _haveWaitingTask = false;
    _isDownloading = true;
    _lastError = null;
    notifyListeners();
    try {
      var config = _validateConfig();
      if (config == null) {
        _lastError = 'Invalid WebDAV configuration';
        return const Res.error('Invalid WebDAV configuration');
      }
      if (config.isEmpty) return const Res(true);

      var client = newClient(
        config[0],
        user: config[1],
        password: config[2],
        adapter: WebdavRHttpAdapter(),
      );

      try {
        final manifestRes = await readManifest();
        final manifest = manifestRes.dataOrNull;
        if (manifest == null) throw 'No data file found';
        final version = (manifest['version'] as num?)?.toInt() ?? 0;
        final currentVersion = _dataVersion;
        if (version > 0 && version <= currentVersion) {
          Log.info("Data Sync", 'No new data to download');
          return const Res(true);
        }
        final remoteMeta =
            (manifest['parts'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final localHashes =
            (appdata.implicitData['syncPartHashes'] as Map?)
                ?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final newHashes = <String, dynamic>{...localHashes};
        var downloaded = 0;
        for (final part in syncParts) {
          final meta = remoteMeta[part.key];
          if (meta is! Map) continue;
          final remoteHash = meta['hash']?.toString();
          // 与上次下载的哈希一致 → 该部分未变化，跳过下载
          if (remoteHash != null && remoteHash == localHashes[part.key]) {
            continue;
          }
          final localFile = File(
            FilePath.join(App.cachePath, 'sync_${part.key}.kostori'),
          );
          await client.read2File(
            _join(_normDir(part.dir), '${part.name}.kostori'),
            localFile.path,
            onProgress: (count, total) {
              _progress = total > 0 ? count / total : null;
              notifyListeners();
            },
          );
          await importPart(localFile);
          localFile.deleteIgnoreError();
          if (remoteHash != null) newHashes[part.key] = remoteHash;
          downloaded++;
        }
        appdata.implicitData['syncPartHashes'] = newHashes;
        appdata.writeImplicitData();
        Log.info(
          "Data Sync",
          "Downloaded $downloaded/${syncParts.length} parts (v$version)",
        );
        _setDataVersion(version);
        Log.info("Data Sync", "Data downloaded successfully");
        return const Res(true);
      } catch (e, s) {
        Log.error("Data Sync", e, s);
        _lastError = e.toString();
        return Res.error(e.toString());
      }
    } finally {
      _isDownloading = false;
      _progress = null;
      if (_lastError == null) _recordSyncSuccess();
      notifyListeners();
    }
  }

  // ─── 选择性同步（按条目上传 / 下载单个文件）──────────────

  Client? _client() {
    final config = _validateConfig();
    if (config == null || config.isEmpty) return null;
    return newClient(
      config[0],
      user: config[1],
      password: config[2],
      adapter: WebdavRHttpAdapter(),
    );
  }

  static String _normDir(String dir) {
    var d = dir.trim();
    if (d.isEmpty) return '/';
    if (!d.startsWith('/')) d = '/$d';
    while (d.length > 1 && d.endsWith('/')) {
      d = d.substring(0, d.length - 1);
    }
    return d;
  }

  static String _join(String dir, String name) =>
      dir == '/' ? '/$name' : '$dir/$name';

  /// 远端目录下的文件名列表（目录不存在时返回空）
  Future<Res<List<String>>> listRemoteFiles({String dir = '/'}) async {
    final entries = await listRemoteEntries(dir: dir);
    return entries.success
        ? Res([for (final e in entries.data) e.name])
        : Res.error(entries.errorMessage ?? '');
  }

  /// 远端目录下的文件信息（名称 / 大小 / 修改时间）
  Future<Res<List<RemoteFileInfo>>> listRemoteEntries({
    String dir = '/',
  }) async {
    final client = _client();
    if (client == null) return const Res([]);
    try {
      final files = await client.readDir(_normDir(dir));
      return Res([
        for (final f in files)
          if (f.name != null && !f.name!.endsWith('.part'))
            RemoteFileInfo(
              name: f.name!,
              size: f.size ?? 0,
              modified: f.mTime,
            ),
      ]);
    } catch (e, s) {
      // 目录不存在（404）视为空，不算错误
      final code = e is DioException ? e.response?.statusCode : null;
      if (code != 404) Log.error('List Remote', e, s);
      return const Res([]);
    }
  }

  /// 上传单个文件到远端目录（自动建目录）
  Future<Res<bool>> uploadFile({
    required String localPath,
    required String remoteName,
    String remoteDir = '/',
  }) async {
    final client = _client();
    if (client == null) return const Res.error('Invalid WebDAV configuration');
    try {
      final file = File(localPath);
      if (!file.existsSync()) return const Res.error('Local file missing');
      final dir = _normDir(remoteDir);
      if (dir != '/') {
        try {
          await client.mkdirAll(dir);
        } catch (_) {}
      }
      await client.write(_join(dir, remoteName), await file.readAsBytes());
      return const Res(true);
    } catch (e, s) {
      Log.error('Upload File', e, s);
      return Res.error(e.toString());
    }
  }

  /// 从远端目录下载单个文件
  Future<Res<bool>> downloadFile({
    required String remoteName,
    required String localPath,
    String remoteDir = '/',
  }) async {
    final client = _client();
    if (client == null) return const Res.error('Invalid WebDAV configuration');
    try {
      final parent = File(localPath).parent;
      if (!parent.existsSync()) parent.createSync(recursive: true);
      await client.read2File(_join(_normDir(remoteDir), remoteName), localPath);
      return const Res(true);
    } catch (e, s) {
      Log.error('Download File', e, s);
      return Res.error(e.toString());
    }
  }

  /// 删除远端目录下的单个文件
  Future<Res<bool>> deleteFile({
    required String remoteName,
    String remoteDir = '/',
  }) async {
    final client = _client();
    if (client == null) return const Res.error('Invalid WebDAV configuration');
    try {
      await client.remove(_join(_normDir(remoteDir), remoteName));
      return const Res(true);
    } catch (e, s) {
      Log.error('Delete File', e, s);
      return Res.error(e.toString());
    }
  }
}
