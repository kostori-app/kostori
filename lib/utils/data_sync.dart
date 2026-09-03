// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/utils/data.dart';
import 'package:kostori/utils/io.dart';
import 'package:webdav_client/webdav_client.dart' hide File;

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
      // 距上次成功同步过近（<30s）则暂不上传，保留 dirty 等下次触发，
      // 避免频繁进出详情页/误点条目导致反复上传十几 MB 的压缩包。
      // 窗口关闭时 _handleWindowClose 会兜底刷出待上传变化。
      if (_lastSyncTime != null &&
          DateTime.now().difference(_lastSyncTime!) <
              const Duration(seconds: 30)) {
        return;
      }
      _dirty = false;
      unawaited(uploadData());
    });
  }

  bool _handleWindowClose() {
    // 关闭前先刷出未触发防抖的待上传变化，避免丢失最后一次修改
    if (_uploadDebounce != null) {
      _uploadDebounce?.cancel();
      _uploadDebounce = null;
      if (_dirty) {
        _dirty = false;
        unawaited(uploadData());
      }
    }
    if (_isUploading) {
      _showWindowCloseDialog();
      return false;
    }
    return true;
  }

  void _showWindowCloseDialog() async {
    showLoadingDialog(
      App.rootContext,
      cancelButtonText: t.shutDown,
      onCancel: () => exit(0),
      barrierDismissible: false,
      message: t.uploadingData,
    );
    while (_isUploading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    exit(0);
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

  /// 从 .kostori 文件名中解析版本号（格式：$date-$version-$deviceTag.kostori）
  int _versionOf(String name) {
    final base = name.endsWith('.kostori')
        ? name.substring(0, name.length - '.kostori'.length)
        : name;
    final parts = base.split('-');
    // 兼容旧格式 $date-$version.kostori（2 段）与新格式（3 段）
    if (parts.length >= 2) {
      final v = int.tryParse(parts[1]);
      if (v != null) return v;
    }
    return 0;
  }

  int _maxVersionOf(List files) {
    var max = 0;
    for (final f in files) {
      final v = _versionOf(f.name ?? '');
      if (v > max) max = v;
    }
    return max;
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
        adapter: RHttpAdapter(),
      );

      try {
        // 读取服务端现有文件，以服务端为准确定新版本号与清理策略，
        // 避免多端本地各自递增导致版本号冲突 / 互相覆盖删除
        var files = await client.readDir('/');
        files = files.where((e) => e.name!.endsWith('.kostori')).toList();
        files.sort((a, b) => a.name!.compareTo(b.name!));

        // 计算全局最新版本号（取所有文件中版本号最大者）
        var maxVersion = _maxVersionOf(files);
        if (maxVersion < (appdata.settings['dataVersion'] as int? ?? 0)) {
          maxVersion = appdata.settings['dataVersion'] as int? ?? 0;
        }
        final newVersion = maxVersion + 1;
        appdata.settings['dataVersion'] = newVersion;
        await appdata.saveData(false);

        var data = await exportAppData();
        var date = (DateTime.now().millisecondsSinceEpoch ~/ 86400000)
            .toString();
        // 文件名带设备标识，避免多端同一天互相删除
        final deviceTag = _deviceTag();
        var filename = '$date-$newVersion-$deviceTag.kostori';

        // 清理旧文件：仅当文件数超过保留上限时删除最旧的（不删当天其他设备的）
        if (files.length >= 10) {
          files.sort((a, b) => a.name!.compareTo(b.name!));
          await client.remove(files.first.name!);
        }
        await client.write(
          filename,
          await data.readAsBytes(),
          onProgress: (count, total) {
            _progress = total > 0 ? count / total : null;
            notifyListeners();
          },
        );
        data.deleteIgnoreError();
        Log.info("Upload Data", "Data uploaded successfully ($filename)");
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
        adapter: RHttpAdapter(),
      );

      try {
        var files = await client.readDir('/');
        files = files.where((e) => e.name!.endsWith('.kostori')).toList();
        if (files.isEmpty) throw 'No data file found';
        // 按版本号取最新（而非文件名排序，避免旧格式与新格式混排导致取错）
        files.sort(
          (a, b) => _versionOf(b.name!).compareTo(_versionOf(a.name!)),
        );
        var file = files.first;
        var version = _versionOf(file.name!);
        var currentVersion = appdata.settings['dataVersion'] as int? ?? 0;
        if (version > 0 && version <= currentVersion) {
          Log.info("Data Sync", 'No new data to download');
          return const Res(true);
        }
        Log.info("Data Sync", "Downloading data from WebDAV server");
        var localFile = File(FilePath.join(App.cachePath, file.name!));
        await client.read2File(
          file.name!,
          localFile.path,
          onProgress: (count, total) {
            _progress = total > 0 ? count / total : null;
            notifyListeners();
          },
        );
        await importAppData(localFile, true);
        // 同步本地版本号为下载到的服务端版本
        appdata.settings['dataVersion'] = version;
        await appdata.saveData(false);
        await localFile.delete();
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
}
