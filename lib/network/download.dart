import 'dart:async';
import 'dart:io';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/app_dio.dart';

class AppDownloadTask {
  final String url;
  final String savePath;
  final CancelToken _cancelToken = CancelToken();
  final Dio _dio = Dio(); // 每个任务独立 Dio

  AppDownloadTask({required this.url, required this.savePath});

  late final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  Stream<double> get progressStream => _progressController.stream;

  Future<void> start() async {
    final file = File(savePath);
    if (!file.existsSync()) {
      await file.create(recursive: true);
      Log.addLog(LogLevel.info, 'AppDownloadTask', 'Created file at $savePath');
    }

    try {
      Log.addLog(LogLevel.info, 'AppDownloadTask', 'Starting download: $url');
      await _dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          double progress = total > 0
              ? (received / total).clamp(0.0, 1.0)
              : 0.0;
          _progressController.add(progress);
        },
      );
      Log.addLog(LogLevel.info, 'AppDownloadTask', 'Download completed');
      _progressController.add(1.0);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        Log.addLog(LogLevel.warning, 'AppDownloadTask', 'Download canceled');
        _progressController.addError("Download canceled");
        if (await file.exists()) {
          await file.delete();
        }
      } else {
        Log.addLog(LogLevel.error, 'AppDownloadTask', 'Download failed: $e');
        _progressController.addError(e);
      }
    }
  }

  void cancel() {
    _cancelToken.cancel("cancel");
  }
}
