// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:math';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/proxy.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/ffmpeg_encoder.dart';
import 'package:kostori/utils/io.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';
import 'package:path_provider/path_provider.dart';

part 'crop.dart';

part 'hls_dowloader.dart';

part 'range_picker.dart';

enum ExportFormat { mp4, gif, apng, webp }

enum ExportQuality { high, medium, low }

Future<void> showVideoClipEditor({
  required BuildContext context,
  required String videoUrl,
  Map<String, String>? httpHeaders,
  required Duration currentPosition,
  required Duration duration,
}) async {
  if (App.isDesktop) {
    final customPath = appdata.settings['ffmpegPath'] as String?;
    bool ffmpegExists = false;

    if (customPath != null && customPath.isNotEmpty) {
      ffmpegExists = await File(customPath).exists();
    }

    if (!ffmpegExists) {
      try {
        final result = await Process.run('where', ['ffmpeg.exe']);
        if (result.exitCode == 0) ffmpegExists = true;
      } catch (_) {}
    }

    if (!ffmpegExists) {
      for (final p in [
        'C:\\ffmpeg\\bin\\ffmpeg.exe',
        'C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe',
        'C:\\Program Files (x86)\\ffmpeg\\bin\\ffmpeg.exe',
        '/usr/bin/ffmpeg',
        '/usr/local/bin/ffmpeg',
      ]) {
        if (await File(p).exists()) {
          ffmpegExists = true;
          break;
        }
      }
    }

    if (!ffmpegExists) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ContentDialog(
          title: t.ffmpegNotFound,
          content: Text(t.ffmpegNotFoundDesktop),
          cancel: () {
            Navigator.of(context).pop(false);
          },
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.stillOpenAnyway),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
  }

  await showPopUpWidget(
    context,
    ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: VideoClipEditorPage(
        videoUrl: videoUrl,
        httpHeaders: httpHeaders,
        currentPosition: currentPosition,
        duration: duration,
      ),
    ),
  );
}

class _Semaphore {
  _Semaphore(this.maxCount);

  final int maxCount;
  int _count = 0;
  final _queue = <Completer<void>>[];

  Future<void> acquire() async {
    if (_count < maxCount) {
      _count++;
      return;
    }
    final c = Completer<void>();
    _queue.add(c);
    await c.future;
  }

  void release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _count--;
    }
  }
}

class VideoClipEditorPage extends StatefulWidget {
  final String videoUrl;
  final Map<String, String>? httpHeaders;
  final Duration currentPosition;
  final Duration duration;

  const VideoClipEditorPage({
    super.key,
    required this.videoUrl,
    this.httpHeaders,
    required this.currentPosition,
    required this.duration,
  });

  @override
  State<VideoClipEditorPage> createState() => _VideoClipEditorPageState();
}

class _VideoClipEditorPageState extends State<VideoClipEditorPage> {
  static const maxExportDurationMs = 60000;
  static const _previewWindowMs = 3 * 60 * 1000;
  static bool _rangeInitialized = false;

  late Duration _startTime;
  late Duration _endTime;

  Duration _videoDuration = Duration.zero;

  ExportFormat _format = ExportFormat.mp4;
  ExportQuality _quality = ExportQuality.medium;

  int? _exportWidth;
  bool _includeAudio = true;
  int _animFps = 15;
  int _webpQuality = 75;
  int? _mp4BitrateKbps;
  int _gifColors = 128;
  bool _gifDither = true;

  bool _useCustomCrop = false;
  bool _showCropOverlay = false;
  Rect _cropRect = const Rect.fromLTWH(0, 0, 1, 1);

  int _videoWidth = 0;
  int _videoHeight = 0;

  Player? _previewPlayer;
  VideoController? _previewController;
  StreamSubscription<Duration>? _previewPosSub;
  bool _previewLoading = false;
  String? _previewError;
  String _previewStatus = '';
  Duration _previewSeekTarget = Duration.zero;
  Directory? _previewHlsTempDir;

  bool _isPlaying = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';
  bool _exportCancelled = false;
  bool _atScrollTop = true;
  Directory? _hlsTempDir;
  int _previewDownloadStartMs = 0;

  double? _estimatedBytes;
  bool _sampling = false;
  Timer? _sampleDebounce;

  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );

  // 缩略图相关
  bool _thumbnailsLoading = false;
  List<String> _thumbnailPaths = [];

  @override
  void initState() {
    super.initState();
    _rangeInitialized = false;
    _startTime = widget.currentPosition;
    _endTime = const Duration(seconds: 60);
    _initPreviewPlayer();
  }

  void _initRangeFromDuration(Duration totalDuration) {
    DebugLog.info('_initRangeFromDuration.totalDuration', '$totalDuration');
    final clipDuration = const Duration(seconds: 60);
    var start = (totalDuration - clipDuration) ~/ 2;

    if (start < Duration.zero) start = Duration.zero;

    var end = start + clipDuration;

    if (end > totalDuration) {
      end = totalDuration;
      start = end - clipDuration;
      if (start < Duration.zero) start = Duration.zero;
    }

    _startTime = start;
    _endTime = end;
  }

  @override
  void dispose() {
    _previewPosSub?.cancel();
    _previewPlayer?.dispose();
    _previewHlsTempDir?.delete(recursive: true).ignore();
    _exportCancelled = true;
    _hlsTempDir?.delete(recursive: true).ignore();
    super.dispose();
  }

  Duration get _clipDuration => _endTime - _startTime;

  int get _crf => switch (_quality) {
    ExportQuality.high => 18,
    ExportQuality.medium => 23,
    ExportQuality.low => 28,
  };

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(
      2,
      '0',
    );
    return '$mm:$ss.$cs';
  }

  Future<void> _runSampleEstimate() async {
    if (_previewHlsTempDir == null && _HlsDownloader._isHls(widget.videoUrl)) {
      return; // 还没有本地文件，不采样
    }
    if (_clipDuration.inMilliseconds <= 0) return;
    if (_sampling) return;

    setState(() {
      _sampling = true;
      _estimatedBytes = null;
    });

    try {
      // 取片段中间 1 秒
      final sampleSec = 1.0;
      final midMs =
          _startTime.inMilliseconds + _clipDuration.inMilliseconds ~/ 2;
      final sampleStartMs = (midMs - 500).clamp(
        _startTime.inMilliseconds,
        _endTime.inMilliseconds - 1000,
      );

      final tempDir = await getTemporaryDirectory();

      // 构造和真实导出一样的参数，只改 startMs 和 lengthMs
      final localPath = _getSampleInputPath(); // 见下方
      if (localPath == null) return;

      final (_, encodeArgs) = _buildEncodeArgs(
        outputDir: tempDir.path,
        timestamp: 0,
        exportUrl: localPath,
        exportHeaders: {},
        proxyUrl: null,
        startMsOverride: sampleStartMs,
        lengthMsOverride: (sampleSec * 1000).toInt(),
      );

      await FfmpegEncoder.encode(encodeArgs);

      if (!await File(encodeArgs.outputPath).exists()) return;

      final sampleBytes = await File(encodeArgs.outputPath).length();
      File(encodeArgs.outputPath).delete().ignore();

      // 按时长比例推算总大小
      final ratio = _clipDuration.inMilliseconds / (sampleSec * 1000);
      if (mounted) {
        setState(() {
          _estimatedBytes = sampleBytes * ratio;
          _sampling = false;
        });
      }
    } catch (e) {
      Log.error('SampleEstimate', '$e');
      if (mounted) setState(() => _sampling = false);
    }
  }

  String? _getSampleInputPath() {
    final dir = _previewHlsTempDir;
    if (dir == null) return widget.videoUrl;
    final files = dir.listSync();
    final mp4 = files.where((f) => f.path.endsWith('.mp4')).firstOrNull;
    if (mp4 != null) return mp4.path;
    final ts = files.where((f) => f.path.endsWith('merged.ts')).firstOrNull;
    if (ts != null) return ts.path;
    return widget.videoUrl;
  }

  void _scheduleSampleEstimate() {
    _sampleDebounce?.cancel();
    _sampleDebounce = Timer(
      const Duration(milliseconds: 800),
      _runSampleEstimate,
    );
  }

  String _estimatedSize() {
    if (_sampling) return '估算中…';
    final bytes = _estimatedBytes;
    if (bytes == null || _videoWidth == 0) return '--';
    if (bytes < 1024) return '${bytes.toInt()}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  Future<void> _previewClip() async {
    final player = _previewPlayer;
    if (player == null) return;
    await player.seek(_previewSeekTarget);
    await player.play();
    setState(() => _isPlaying = true);
  }

  Future<void> _stopPreview() async {
    await _previewPlayer?.pause();
    setState(() => _isPlaying = false);
  }

  Future<void> _initPreviewPlayer() async {
    _previewPosSub?.cancel();
    _previewPosSub = null;
    final oldPlayer = _previewPlayer;
    _previewPlayer = null;
    _previewController = null;
    oldPlayer?.dispose();
    _previewHlsTempDir?.delete(recursive: true).ignore();
    _previewHlsTempDir = null;

    if (!mounted) return;
    setState(() {
      _previewLoading = true;
      _previewError = null;
      _previewStatus = t.preparing;
      _isPlaying = false;
    });

    try {
      final halfWindowMs = _previewWindowMs ~/ 2;
      final downloadStartMs = (_startTime.inMilliseconds - halfWindowMs).clamp(
        0,
        widget.duration.inMilliseconds,
      );
      _previewDownloadStartMs = downloadStartMs;
      final downloadEndMs = (_startTime.inMilliseconds + halfWindowMs).clamp(
        0,
        widget.duration.inMilliseconds,
      );
      final isHls = _HlsDownloader._isHls(widget.videoUrl);
      String mediaUrl = widget.videoUrl;

      if (isHls) {
        setState(() => _previewStatus = t.downloadingPreviewClip);
        final local = await _HlsDownloader.download(
          url: widget.videoUrl,
          headers: widget.httpHeaders ?? {},
          startMs: downloadStartMs,
          endMs: downloadEndMs,
          onProgress: (p, msg) {
            if (mounted) setState(() => _previewStatus = msg);
          },
        );
        if (!mounted) return;
        if (local != null) {
          mediaUrl = local;
          _previewHlsTempDir = File(local).parent;
        }
      }

      if (!mounted) return;
      setState(() => _previewStatus = t.loadingPlayer);

      final player = Player();
      final controller = VideoController(player);

      await player.open(
        Media(
          mediaUrl,
          httpHeaders: isHls && mediaUrl != widget.videoUrl
              ? {}
              : (widget.httpHeaders ?? {}),
        ),
        play: false,
      );

      player.stream.duration.listen((d) {
        if (!mounted || d == Duration.zero) return;
        if (_videoDuration != d) {
          setState(() {
            _videoDuration = d;
            if (!_rangeInitialized && _endTime > _videoDuration) {
              _endTime = _videoDuration;
            }
          });
        }
        if (!_rangeInitialized && d != Duration.zero) {
          _rangeInitialized = true;
          _initRangeFromDuration(d);
        }
      });

      final seekTarget = isHls && mediaUrl != widget.videoUrl
          ? Duration(milliseconds: _startTime.inMilliseconds - downloadStartMs)
          : _startTime;

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) {
        player.dispose();
        return;
      }
      await player.seek(seekTarget);

      _previewSeekTarget = seekTarget;

      player.stream.videoParams.listen((p) {
        if (!mounted || p.dw == null || p.dh == null) return;
        setState(() {
          _videoWidth = p.dw!;
          _videoHeight = p.dh!;
        });
      });

      _previewPosSub = player.stream.position.listen((pos) {
        if (!mounted) return;

        final playing = player.state.playing;
        final needsOffset = isHls && mediaUrl != widget.videoUrl;
        final offset = needsOffset
            ? Duration(milliseconds: _previewDownloadStartMs)
            : Duration.zero;

        final localStart = _startTime - offset;
        final localEnd = _endTime - offset;

        if (_isPlaying && (pos >= localEnd || pos < localStart)) {
          player.seek(localStart);
        }

        _positionNotifier.value = pos;

        if (playing != _isPlaying) {
          setState(() => _isPlaying = playing);
        }
      });

      if (!mounted) {
        player.dispose();
        return;
      }

      setState(() {
        _previewPlayer = player;
        _previewController = controller;
        _previewLoading = false;
        _previewStatus = '';
      });

      _generateThumbnails();
      _scheduleSampleEstimate();
    } catch (e, st) {
      Log.error('PreviewPlayer', '$e\n$st');
      if (mounted) {
        setState(() {
          _previewLoading = false;
          _previewError = e.toString();
          _previewStatus = '';
        });
      }
    }
  }

  Future<String?> _findFfmpeg() async {
    final customPath = appdata.settings['ffmpegPath'] as String?;
    if (customPath != null && customPath.isNotEmpty) {
      if (await File(customPath).exists()) return customPath;
    }

    try {
      final result = Platform.isWindows
          ? await Process.run('where', ['ffmpeg.exe'])
          : await Process.run('which', ['ffmpeg']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim().split('\n').first.trim();
      }
    } catch (_) {}

    for (final p in [
      'C:\\ffmpeg\\bin\\ffmpeg.exe',
      'C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe',
      'C:\\Program Files (x86)\\ffmpeg\\bin\\ffmpeg.exe',
      '/usr/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
    ]) {
      if (await File(p).exists()) return p;
    }
    return null;
  }

  Future<void> _generateThumbnails() async {
    Log.info(
      'Thumbnail',
      'Start generating, _videoDuration=${_videoDuration.inSeconds}s',
    );
    if (_videoDuration == Duration.zero) {
      Log.info('Thumbnail', 'Duration is zero, skip');
      return;
    }

    // 获取本地视频文件路径（合并后的 ts 文件或 mp4）
    final localDir = _previewHlsTempDir?.path;
    Log.info('Thumbnail', 'Local video dir: $localDir');

    // 先检查本地文件
    String? mediaPath;
    if (localDir != null) {
      final mediaDir = Directory(localDir);
      if (await mediaDir.exists()) {
        final files = mediaDir.listSync();

        final mp4Files = files
            .where((f) => f.path.toLowerCase().endsWith('.mp4'))
            .toList();
        if (mp4Files.isNotEmpty) {
          mediaPath = mp4Files.first.path;
          Log.info('Thumbnail', 'Found mp4: $mediaPath');
        } else {
          final mergedTs = files
              .where((f) => f.path.toLowerCase().endsWith('merged.ts'))
              .toList();
          if (mergedTs.isNotEmpty) {
            mediaPath = mergedTs.first.path;
            Log.info('Thumbnail', 'Found merged.ts: $mediaPath');
          }
        }
      }
    }

    // 如果没有本地文件，检查是否需要从网络提取（针对非 HLS 视频）
    if (mediaPath == null) {
      final isHls = _HlsDownloader._isHls(widget.videoUrl);
      if (!isHls) {
        // 非 HLS 视频，可以使用原始 URL 进行缩略图提取
        mediaPath = widget.videoUrl;
        Log.info(
          'Thumbnail',
          'Using original URL for non-HLS video: $mediaPath',
        );
      } else {
        Log.info('Thumbnail', 'No local file and is HLS, skip');
        if (mounted) setState(() => _thumbnailsLoading = false);
        return;
      }
    }

    for (final path in _thumbnailPaths) {
      try {
        await File(path).delete();
      } catch (_) {}
    }

    setState(() {
      _thumbnailsLoading = true;
      _thumbnailPaths = [];
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final thumbDir = Directory(
        '${tempDir.path}/thumbnails_${DateTime.now().millisecondsSinceEpoch}',
      );
      await thumbDir.create(recursive: true);

      final totalSeconds = _videoDuration.inSeconds;
      const thumbnailCount = 10;
      final intervalSeconds = (totalSeconds / thumbnailCount).floor();
      Log.info(
        'Thumbnail',
        'Total $totalSeconds seconds, interval $intervalSeconds seconds',
      );

      if (intervalSeconds < 1) {
        Log.info('Thumbnail', 'Interval too small, skip');
        if (mounted) setState(() => _thumbnailsLoading = false);
        return;
      }

      final safeInputUrl = mediaPath.replaceAll('\\', '/');
      final List<String> paths = [];

      final bool isDesktop =
          Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      Log.info('Thumbnail', 'Is desktop: $isDesktop');

      final String? ffmpegPath = isDesktop ? await _findFfmpeg() : null;
      Log.info('Thumbnail', 'FFmpeg path: $ffmpegPath');

      if (isDesktop && ffmpegPath == null) {
        Log.info('Thumbnail', 'FFmpeg not found on desktop, skip');
        if (mounted) setState(() => _thumbnailsLoading = false);
        return;
      }

      for (int i = 1; i < thumbnailCount; i++) {
        final timeSec = i * intervalSeconds;
        final outputPath = '${thumbDir.path}/thumb_$i.jpg';

        // 构建参数列表，避免空格路径问题
        final args = [
          '-y',
          '-ss',
          '$timeSec',
          '-i',
          safeInputUrl,
          '-vframes',
          '1',
          '-q:v',
          '2',
          '-vf',
          'scale=120:-1',
          outputPath,
        ];

        try {
          Log.info('Thumbnail', 'Processing frame $i at $timeSec sec');
          if (isDesktop) {
            Log.info(
              'Thumbnail',
              'Running FFmpeg: $ffmpegPath with args: $args',
            );
            final process = await io.Process.start(ffmpegPath!, args);
            final stdoutBuffer = StringBuffer();
            final stderrBuffer = StringBuffer();

            process.stdout.transform(const io.SystemEncoding().decoder).listen((
              data,
            ) {
              stdoutBuffer.write(data);
            });
            process.stderr.transform(const io.SystemEncoding().decoder).listen((
              data,
            ) {
              stderrBuffer.write(data);
            });

            final exitCode = await process.exitCode;
            Log.info('Thumbnail', 'FFmpeg stdout: $stdoutBuffer');
            Log.info('Thumbnail', 'FFmpeg stderr: $stderrBuffer');
            Log.info('Thumbnail', 'FFmpeg exited with code: $exitCode');
            if (exitCode == 0 && await File(outputPath).exists()) {
              paths.add(outputPath);
              Log.info('Thumbnail', 'Frame $i saved: $outputPath');
            }
          } else {
            // 移动端：拼成字符串传给 FFmpegKit（内部已处理）
            final cmd = args.map((a) => a.contains(' ') ? '"$a"' : a).join(' ');
            Log.info('Thumbnail', 'Running FFmpegKit: $cmd');
            final session = await FFmpegKit.execute(cmd);
            final returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode) &&
                await File(outputPath).exists()) {
              paths.add(outputPath);
            }
          }
        } catch (e) {
          Log.error('Thumbnail', 'Frame $i failed: $e');
        }
      }

      if (mounted) {
        setState(() {
          _thumbnailPaths = paths;
          _thumbnailsLoading = false;
        });
      }
    } catch (e) {
      Log.error('Thumbnail', 'Generate failed: $e');
      if (mounted) setState(() => _thumbnailsLoading = false);
    }
  }

  void _nudge({required bool isStart, required int deltaMs}) {
    const int maxClipMs = 60000;
    const int minClipMs = 100;
    final int totalMs = _videoDuration.inMilliseconds;

    setState(() {
      if (isStart) {
        int newStart = _startTime.inMilliseconds + deltaMs;
        newStart = newStart.clamp(0, _endTime.inMilliseconds - minClipMs);
        if (_endTime.inMilliseconds - newStart > maxClipMs) {
          _endTime = Duration(milliseconds: newStart + maxClipMs);
        }
        _startTime = Duration(milliseconds: newStart);
      } else {
        int newEnd = _endTime.inMilliseconds + deltaMs;
        newEnd = newEnd.clamp(_startTime.inMilliseconds + minClipMs, totalMs);
        if (newEnd - _startTime.inMilliseconds > maxClipMs) {
          _startTime = Duration(milliseconds: newEnd - maxClipMs);
        }
        _endTime = Duration(milliseconds: newEnd);
      }
    });
    _scheduleSampleEstimate();
  }

  void _applyCropAspect(int w, int h) {
    if (w == 0 || h == 0 || _videoWidth == 0 || _videoHeight == 0) return;
    final targetAspect = w / h;
    final videoAspect = _videoWidth / _videoHeight;

    double cw, ch;
    if (targetAspect > videoAspect) {
      cw = 1.0;
      ch = videoAspect / targetAspect;
    } else {
      ch = 1.0;
      cw = targetAspect / videoAspect;
    }

    setState(() {
      _cropRect = Rect.fromCenter(
        center: const Offset(0.5, 0.5),
        width: cw,
        height: ch,
      );
      _useCustomCrop = true;
      _showCropOverlay = true;
    });
  }

  void _resetCrop() {
    setState(() {
      _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
      _useCustomCrop = false;
      _showCropOverlay = false;
    });
  }

  Future<bool> _confirmClose() async {
    if (!_isExporting) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t.cancelExport),
            content: Text(t.exportInProgress),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.confirmClose),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleClose() async {
    if (!await _confirmClose()) return;
    App.pop();
  }

  Future<void> _exportClip() async {
    if (_clipDuration.inMilliseconds <= 0) {
      App.rootContext.showMessage(message: t.exportFailed);
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportStatus = t.preparing;
      _exportCancelled = false;
    });

    String exportUrl = widget.videoUrl;
    final exportHeaders = Map<String, String>.from(widget.httpHeaders ?? {});
    final proxyUrl = await getProxy();
    final localDir = _previewHlsTempDir?.path;
    bool useLocalFile = false;

    if (localDir != null) {
      final mediaDir = Directory(localDir);
      if (await mediaDir.exists()) {
        final files = mediaDir.listSync();

        final mp4Files = files
            .where((f) => f.path.toLowerCase().endsWith('.mp4'))
            .toList();
        if (mp4Files.isNotEmpty) {
          exportUrl = mp4Files.first.path;
          useLocalFile = true;
          Log.info('Export', 'Using local mp4 file: $exportUrl');
        } else {
          final mergedTs = files
              .where((f) => f.path.toLowerCase().endsWith('merged.ts'))
              .toList();
          if (mergedTs.isNotEmpty) {
            exportUrl = mergedTs.first.path;
            useLocalFile = true;
            Log.info('Export', 'Using local merged file: $exportUrl');
          }
        }
      }
    }

    try {
      final bool isMobile = Platform.isAndroid || Platform.isIOS;
      final bool doPreDownload = useLocalFile
          ? false
          : _HlsDownloader._isHls(exportUrl) &&
                (_format == ExportFormat.mp4 || isMobile);

      if (doPreDownload) {
        setState(() => _exportStatus = t.downloadingVideoSegments);
        final localM3u8 = await _HlsDownloader.download(
          url: exportUrl,
          headers: exportHeaders,
          startMs: _startTime.inMilliseconds + _previewDownloadStartMs,
          endMs: _endTime.inMilliseconds,
          onProgress: (p, msg) {
            if (mounted && !_exportCancelled) {
              setState(() {
                _exportProgress = p * 0.4;
                _exportStatus = msg;
              });
            }
          },
        );
        if (localM3u8 != null) {
          exportUrl = localM3u8;
          _hlsTempDir = File(localM3u8).parent;
        }
      }

      if (_exportCancelled) return;

      setState(() => _exportStatus = t.encoding);

      final outputDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final startMsForEncode = doPreDownload ? 0 : _startTime.inMilliseconds;
      final (ext, encodeArgs) = _buildEncodeArgs(
        outputDir: outputDir.path,
        timestamp: ts,
        exportUrl: exportUrl,
        exportHeaders: exportHeaders,
        proxyUrl: proxyUrl,
        startMsOverride: startMsForEncode,
      );

      final baseProgress =
          doPreDownload && _HlsDownloader._isHls(widget.videoUrl) ? 0.4 : 0.0;

      final encodeArgsWithProgress = FfmpegEncodeArgs(
        inputUrl: encodeArgs.inputUrl,
        outputPath: encodeArgs.outputPath,
        startMs: encodeArgs.startMs,
        lengthMs: encodeArgs.lengthMs,
        headers: encodeArgs.headers,
        proxyUrl: proxyUrl,
        outputFormat: encodeArgs.outputFormat,
        width: encodeArgs.width,
        height: encodeArgs.height,
        cropX: encodeArgs.cropX,
        cropY: encodeArgs.cropY,
        cropWidth: encodeArgs.cropWidth,
        cropHeight: encodeArgs.cropHeight,
        quality: encodeArgs.quality,
        fps: encodeArgs.fps,
        includeAudio: encodeArgs.includeAudio,
        onProgress: (p) {
          if (mounted && !_exportCancelled) {
            setState(() {
              _exportProgress = baseProgress + p * (1.0 - baseProgress);
            });
          }
        },
      );

      await FfmpegEncoder.encode(encodeArgsWithProgress);

      if (_exportCancelled) return;

      final outFile = File(encodeArgs.outputPath);
      if (!await outFile.exists()) throw Exception('Output file not created');
      final size = await outFile.length();
      if (size == 0) throw Exception('Output file is empty');
      Log.info('Export', 'Success, size: $size bytes');

      final filename = 'kostori_clip_$ts.$ext';
      final saved = await ImageSaver.writeFile(
        bytes: await outFile.readAsBytes(),
        filename: filename,
      );
      outFile.delete().ignore();

      if (saved != null) {
        if (App.isAndroid) {
          const ch = MethodChannel('kostori/media');
          await ch.invokeMethod('scanFolder', {'path': saved.parent.path});
        }
        App.rootContext.showMessage(message: t.exportSuccess);
      } else {
        throw Exception('Failed to save file');
      }
    } catch (e, st) {
      if (_exportCancelled) return;
      Log.error('Export', '$e\n$st');
      App.rootContext.showMessage(message: '${t.exportFailed}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  (String, FfmpegEncodeArgs) _buildEncodeArgs({
    required String outputDir,
    required int timestamp,
    required String exportUrl,
    required Map<String, String> exportHeaders,
    required String? proxyUrl,
    int? startMsOverride,
    int? lengthMsOverride,
  }) {
    final startMs = startMsOverride ?? _startTime.inMilliseconds;
    final lengthMs = lengthMsOverride ?? _clipDuration.inMilliseconds;
    int? cropX, cropY, cropW, cropH;
    if (_useCustomCrop && _videoWidth > 0 && _videoHeight > 0) {
      cropW = (_cropRect.width * _videoWidth).round() & ~1;
      cropH = (_cropRect.height * _videoHeight).round() & ~1;
      cropW = cropW.clamp(2, _videoWidth);
      cropH = cropH.clamp(2, _videoHeight);
      cropX = (_cropRect.left * _videoWidth).round().clamp(
        0,
        _videoWidth - cropW,
      );
      cropY = (_cropRect.top * _videoHeight).round().clamp(
        0,
        _videoHeight - cropH,
      );
    }

    final outW = _exportWidth;

    switch (_format) {
      case ExportFormat.mp4:
        return (
          'mp4',
          FfmpegEncodeArgs(
            inputUrl: exportUrl,
            outputPath: '$outputDir/clip_$timestamp.mp4',
            startMs: startMs,
            lengthMs: lengthMs,
            headers: exportHeaders,
            outputFormat: 'mp4',
            width: outW,
            cropX: cropX,
            cropY: cropY,
            cropWidth: cropW,
            cropHeight: cropH,
            quality: _crf.toString(),
            videoBitrateKbps: _mp4BitrateKbps,
            includeAudio: _includeAudio,
          ),
        );

      case ExportFormat.gif:
        return (
          'gif',
          FfmpegEncodeArgs(
            inputUrl: exportUrl,
            outputPath: '$outputDir/clip_$timestamp.gif',
            startMs: startMs,
            lengthMs: lengthMs,
            headers: exportHeaders,
            outputFormat: 'gif',
            width: outW ?? (cropW ?? 480),
            cropX: cropX,
            cropY: cropY,
            cropWidth: cropW,
            cropHeight: cropH,
            fps: _animFps,
            gifColors: _gifColors,
            gifDither: _gifDither,
          ),
        );

      case ExportFormat.apng:
        return (
          'apng',
          FfmpegEncodeArgs(
            inputUrl: exportUrl,
            outputPath: '$outputDir/clip_$timestamp.apng',
            startMs: startMs,
            lengthMs: lengthMs,
            headers: exportHeaders,
            outputFormat: 'apng',
            width: outW,
            cropX: cropX,
            cropY: cropY,
            cropWidth: cropW,
            cropHeight: cropH,
            fps: _animFps,
          ),
        );

      case ExportFormat.webp:
        return (
          'webp',
          FfmpegEncodeArgs(
            inputUrl: exportUrl,
            outputPath: '$outputDir/clip_$timestamp.webp',
            startMs: startMs,
            lengthMs: lengthMs,
            headers: exportHeaders,
            outputFormat: 'webp',
            width: outW,
            cropX: cropX,
            cropY: cropY,
            cropWidth: cropW,
            cropHeight: cropH,
            quality: _webpQuality.toString(),
            fps: _animFps,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleClose();
      },
      child: Material(
        color: cs.surface,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 56 + topPad,
              padding: EdgeInsets.only(top: topPad),
              decoration: BoxDecoration(
                color: cs.surface,
                border: _atScrollTop
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: cs.outlineVariant,
                          width: 0.6,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: t.close,
                    onPressed: _handleClose,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.videoClipEditor,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isPlaying
                        ? IconButton(
                            key: const ValueKey('stop'),
                            icon: const Icon(Icons.stop_circle_outlined),
                            tooltip: t.stopPreview,
                            onPressed: _stopPreview,
                          )
                        : IconButton(
                            key: const ValueKey('play'),
                            icon: const Icon(Icons.play_circle_outline),
                            tooltip: t.previewClip,
                            onPressed:
                                (_isExporting || _previewController == null)
                                ? null
                                : _previewClip,
                          ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.axisDirection != AxisDirection.down) {
                    return false;
                  }
                  final atTop = n.metrics.pixels == n.metrics.minScrollExtent;
                  if (atTop != _atScrollTop) {
                    setState(() => _atScrollTop = atTop);
                  }
                  return false;
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildVideoPreview()),
                    SliverToBoxAdapter(child: _buildVideoControls()),
                    SliverToBoxAdapter(child: _buildTimeSection()),
                    SliverToBoxAdapter(child: _buildExportSettings()),
                    SliverToBoxAdapter(child: _buildCropSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
            _buildExportBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    final cs = Theme.of(context).colorScheme;
    final aspectRatio = _videoWidth > 0 && _videoHeight > 0
        ? _videoWidth / _videoHeight
        : 16.0 / 9.0;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),

          if (_previewLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.white70,
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _previewStatus.isEmpty ? t.loadingPreview : _previewStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_previewError != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.previewLoadFailed,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _previewError!,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: _initPreviewPlayer,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white70,
                    ),
                    child: Text(t.retry),
                  ),
                ],
              ),
            )
          else if (_previewController != null)
            Video(
              controller: _previewController!,
              fill: Colors.black,
              controls: NoVideoControls,
            ),

          if (_showCropOverlay && _previewController != null)
            _CropOverlay(
              cropRect: _cropRect,
              onChanged: (r) => setState(() {
                _cropRect = r;
                _useCustomCrop = true;
              }),
            ),

          if (_previewController != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _useCustomCrop
                    ? FloatingActionButton.small(
                        key: const ValueKey('crop_on'),
                        heroTag: 'crop_toggle',
                        tooltip: t.editCropBox,
                        backgroundColor: _showCropOverlay
                            ? cs.primary
                            : cs.surface,
                        foregroundColor: _showCropOverlay
                            ? cs.onPrimary
                            : cs.onSurface,
                        onPressed: () => setState(
                          () => _showCropOverlay = !_showCropOverlay,
                        ),
                        child: const Icon(Icons.crop, size: 18),
                      )
                    : const SizedBox.shrink(key: ValueKey('crop_off')),
              ),
            ),

          if (!_previewLoading && _previewController != null)
            Positioned(
              left: 8,
              bottom: 8,
              child: Tooltip(
                message: '重新加载预览片段',
                child: GestureDetector(
                  onTap: _initPreviewPlayer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white70, size: 13),
                        SizedBox(width: 4),
                        Text(
                          '重载',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    if (_previewController == null || _previewLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black87,
      child: ValueListenableBuilder<Duration>(
        valueListenable: _positionNotifier,
        builder: (context, position, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressBar(
                progress: position,
                total: _videoDuration,
                buffered: _videoDuration,
                onSeek: (duration) {
                  _previewPlayer?.seek(duration);
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_5),
                    onPressed: () {
                      final newPos = position - const Duration(seconds: 5);
                      _previewPlayer?.seek(
                        newPos < Duration.zero ? Duration.zero : newPos,
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: () {
                      _previewPlayer?.seek(_startTime);
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    iconSize: 36,
                    icon: AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        key: ValueKey<bool>(_isPlaying),
                      ),
                    ),
                    onPressed: () {
                      if (_isPlaying) {
                        _previewPlayer?.pause();
                        setState(() => _isPlaying = false);
                      } else {
                        if (position < _startTime || position >= _endTime) {
                          _previewPlayer?.seek(_startTime);
                        }
                        _previewPlayer?.play();
                        setState(() => _isPlaying = true);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    onPressed: () {
                      _previewPlayer?.seek(_endTime);
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.forward_5),
                    onPressed: () {
                      final newPos = position + const Duration(seconds: 5);
                      if (newPos >= _endTime) {
                        _previewPlayer?.seek(_startTime);
                      } else {
                        _previewPlayer?.seek(newPos);
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeSection() {
    final isCompact = App.isMobile;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RangePickerWidget(
                totalDuration: _videoDuration,
                startTime: _startTime,
                endTime: _endTime,
                onRangeChanged: (start, end) {
                  setState(() {
                    _startTime = start;
                    _endTime = end;
                  });
                  _scheduleSampleEstimate();
                },
                timelineThumbnails: _thumbnailsLoading
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white38,
                          ),
                        ),
                      )
                    : _thumbnailPaths.isEmpty
                    ? Center(
                        child: Text(
                          '视频时间轴缩略图',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth =
                              constraints.maxWidth / _thumbnailPaths.length;
                          return Row(
                            children: _thumbnailPaths.map((path) {
                              return SizedBox(
                                width: itemWidth,
                                height: 60,
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      Container(color: Colors.grey[800]),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              if (isCompact)
                Column(
                  children: [
                    _buildFineControl(isStart: true, compact: isCompact),
                    _buildFineControl(isStart: false, compact: isCompact),
                  ],
                )
              else
                Row(
                  children: [
                    _buildFineControl(isStart: true, compact: isCompact),
                    const Spacer(),
                    _buildFineControl(isStart: false, compact: isCompact),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFineControl({required bool isStart, bool compact = false}) {
    final time = isStart ? _startTime : _endTime;
    final iconSize = compact ? 12.0 : 14.0;
    final btnMinSize = compact ? 24.0 : 28.0;
    final timeFontSize = compact ? 11.0 : 12.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _nudgeBtn(
          icon: Icons.fast_rewind,
          size: iconSize,
          tooltip: isStart ? '起点 −1s' : '终点 −1s',
          onTap: () => _nudge(isStart: isStart, deltaMs: -1000),
          minSize: btnMinSize,
        ),
        _nudgeBtn(
          icon: Icons.remove,
          size: iconSize,
          tooltip: isStart ? '起点 −0.1s' : '终点 −0.1s',
          onTap: () => _nudge(isStart: isStart, deltaMs: -100),
          minSize: btnMinSize,
        ),
        InkWell(
          onTap: () => _showTimeEditDialog(isStart),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
            child: Text(
              _fmt(time),
              style: TextStyle(
                fontSize: timeFontSize,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        _nudgeBtn(
          icon: Icons.add,
          size: iconSize,
          tooltip: isStart ? '起点 +0.1s' : '终点 +0.1s',
          onTap: () => _nudge(isStart: isStart, deltaMs: 100),
          minSize: btnMinSize,
        ),
        _nudgeBtn(
          icon: Icons.fast_forward,
          size: iconSize,
          tooltip: isStart ? '起点 +1s' : '终点 +1s',
          onTap: () => _nudge(isStart: isStart, deltaMs: 1000),
          minSize: btnMinSize,
        ),
      ],
    );
  }

  void _showTimeEditDialog(bool isStart) {
    final TextEditingController controller = TextEditingController(
      text: _fmt(isStart ? _startTime : _endTime),
    );

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: isStart ? '修改起点' : '修改终点',
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '支持格式: 90, 01:30, 1.5...',
            helperText: '输入纯数字视为秒数',
          ),
          onSubmitted: (_) => _handleSubmitted(isStart, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => _handleSubmitted(isStart, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _handleSubmitted(bool isStart, String value) {
    final newDuration = _parseDuration(value);
    if (newDuration != null) {
      setState(() {
        if (isStart) {
          _startTime = newDuration.clamp(Duration.zero, _endTime);
        } else {
          _endTime = newDuration.clamp(_startTime, widget.duration);
        }
      });
    }
    App.pop();
  }

  Duration? _parseDuration(String input) {
    if (input.isEmpty) return null;

    final double? seconds = double.tryParse(input);
    if (seconds != null) {
      return Duration(milliseconds: (seconds * 1000).toInt());
    }

    final parts = input
        .split(':')
        .map((e) => double.tryParse(e) ?? 0.0)
        .toList();

    try {
      if (parts.length == 2) {
        return Duration(
          minutes: parts[0].toInt(),
          milliseconds: (parts[1] * 1000).toInt(),
        );
      } else if (parts.length >= 3) {
        return Duration(
          hours: parts[0].toInt(),
          minutes: parts[1].toInt(),
          milliseconds: (parts[2] * 1000).toInt(),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Widget _nudgeBtn({
    required IconData icon,
    required double size,
    required String tooltip,
    required VoidCallback onTap,
    double minSize = 28,
  }) {
    return IconButton(
      icon: Icon(icon, size: size),
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
    );
  }

  Widget _buildExportSettings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(Icons.settings_outlined, '导出设置'),
              const SizedBox(height: 10),

              _label('格式'),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, c) {
                  final narrow = c.maxWidth < 380;
                  return SegmentedButton<ExportFormat>(
                    segments: const [
                      ButtonSegment(
                        value: ExportFormat.mp4,
                        label: Text('MP4'),
                        icon: Icon(Icons.videocam_outlined, size: 15),
                      ),
                      ButtonSegment(
                        value: ExportFormat.gif,
                        label: Text('GIF'),
                        icon: Icon(Icons.gif_box_outlined, size: 15),
                      ),
                      ButtonSegment(
                        value: ExportFormat.apng,
                        label: Text('APNG'),
                        icon: Icon(Icons.animation, size: 15),
                      ),
                      ButtonSegment(
                        value: ExportFormat.webp,
                        label: Text('WebP'),
                        icon: Icon(Icons.image_outlined, size: 15),
                      ),
                    ],
                    selected: {_format},
                    onSelectionChanged: (s) => setState(() {
                      _format = s.first;
                      _scheduleSampleEstimate();
                    }),
                    style: ButtonStyle(
                      visualDensity: narrow
                          ? VisualDensity.compact
                          : VisualDensity.comfortable,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              _label('分辨率'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _resChip(label: '原始', value: null),
                  _resChip(label: '240p', value: 240),
                  _resChip(label: '360p', value: 360),
                  _resChip(label: '480p', value: 480),
                  _resChip(label: '720p', value: 720),
                  _resChip(label: '1080p', value: 1080),
                ],
              ),
              const SizedBox(height: 12),

              if (_format == ExportFormat.mp4) ...[
                _label('质量 (CRF)'),
                const SizedBox(height: 6),
                SegmentedButton<ExportQuality>(
                  segments: const [
                    ButtonSegment(
                      value: ExportQuality.high,
                      label: Text('高质量'),
                      icon: Icon(Icons.high_quality, size: 15),
                    ),
                    ButtonSegment(
                      value: ExportQuality.medium,
                      label: Text('标准'),
                      icon: Icon(Icons.hd_outlined, size: 15),
                    ),
                    ButtonSegment(
                      value: ExportQuality.low,
                      label: Text('压缩'),
                      icon: Icon(Icons.compress, size: 15),
                    ),
                  ],
                  selected: {_quality},
                  onSelectionChanged: (s) => setState(() {
                    _quality = s.first;
                    _mp4BitrateKbps = null;
                    _scheduleSampleEstimate();
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.speed_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _label(
                        _mp4BitrateKbps == null
                            ? '固定码率（可选，覆盖 CRF）'
                            : '固定码率  ${_mp4BitrateKbps}kbps',
                      ),
                    ),
                    if (_mp4BitrateKbps != null)
                      TextButton(
                        onPressed: () => setState(() => _mp4BitrateKbps = null),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 28),
                        ),
                        child: const Text('重置'),
                      ),
                  ],
                ),
                Slider(
                  min: 100,
                  max: 8000,
                  divisions: 79,
                  value: (_mp4BitrateKbps ?? 0).toDouble().clamp(100, 8000),
                  label: _mp4BitrateKbps == null
                      ? 'CRF'
                      : '${_mp4BitrateKbps}k',
                  onChanged: (v) => setState(() => _mp4BitrateKbps = v.round()),
                ),
                if (_mp4BitrateKbps != null) ...[
                  Wrap(
                    spacing: 6,
                    children: [100, 200, 500, 1000, 2000, 4000]
                        .map(
                          (k) => ActionChip(
                            label: Text('${k}k'),
                            onPressed: () =>
                                setState(() => _mp4BitrateKbps = k),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.volume_up_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('包含音频')),
                    CustomSwitch(
                      value: _includeAudio,
                      onChanged: (v) => setState(() => _includeAudio = v),
                    ),
                  ],
                ),
              ],

              if (_format != ExportFormat.mp4) ...[
                _label('帧率  $_animFps fps'),
                Slider(
                  min: 5,
                  max: 30,
                  divisions: 25,
                  value: _animFps.toDouble(),
                  label: '$_animFps fps',
                  onChanged: (v) => setState(() => _animFps = v.round()),
                ),
                if (_format == ExportFormat.gif) ...[
                  _label('调色板颜色数  $_gifColors  （越少体积越小）'),
                  Slider(
                    min: 2,
                    max: 256,
                    divisions: 14,
                    value: _gifColors.toDouble(),
                    label: '$_gifColors 色',
                    onChanged: (v) => setState(() => _gifColors = v.round()),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [16, 32, 64, 128, 256]
                        .map(
                          (c) => ChoiceChip(
                            label: Text('$c'),
                            selected: _gifColors == c,
                            onSelected: (_) => setState(() => _gifColors = c),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.grain_outlined, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('启用抖动（画质更好，体积稍大）')),
                      CustomSwitch(
                        value: _gifDither,
                        onChanged: (v) => setState(() => _gifDither = v),
                      ),
                    ],
                  ),
                ],
                if (_format == ExportFormat.webp) ...[
                  _label('WebP 质量  $_webpQuality'),
                  Slider(
                    min: 10,
                    max: 100,
                    divisions: 18,
                    value: _webpQuality.toDouble(),
                    label: '$_webpQuality',
                    onChanged: (v) => setState(() => _webpQuality = v.round()),
                  ),
                ],
              ],

              const Divider(height: 16),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _formatHint(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHint() {
    return switch (_format) {
      ExportFormat.mp4 =>
        _mp4BitrateKbps != null
            ? 'H.264 · ${_mp4BitrateKbps}kbps · ${_includeAudio ? "含音频" : "无音频"}'
            : 'H.264 · CRF $_crf · ${_includeAudio ? "含音频" : "无音频"}',
      ExportFormat.gif =>
        'GIF · $_animFps fps · $_gifColors色 · ${_gifDither ? "抖动开" : "抖动关"} · 无音频',
      ExportFormat.apng => 'APNG · $_animFps fps · 无音频 · 浏览器兼容好',
      ExportFormat.webp => 'WebP · $_animFps fps · 质量$_webpQuality · 体积最小',
    };
  }

  Widget _resChip({required String label, required int? value}) {
    return ChoiceChip(
      label: Text(label),
      selected: _exportWidth == value,
      onSelected: (_) => setState(() {
        _exportWidth = value;
        _scheduleSampleEstimate();
      }),
    );
  }

  Widget _buildCropSection() {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _sectionTitle(Icons.crop, '裁剪'),
                  const Spacer(),
                  CustomSwitch(
                    value: _useCustomCrop,
                    onChanged: (v) {
                      setState(() {
                        _useCustomCrop = v;
                        _showCropOverlay = v;
                        if (!v) _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
                      });
                    },
                  ),
                ],
              ),

              if (_useCustomCrop) ...[
                const SizedBox(height: 8),
                _label('宽高比快速预设'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _aspectChip('16:9', 16, 9),
                    _aspectChip('4:3', 4, 3),
                    _aspectChip('1:1', 1, 1),
                    _aspectChip('9:16', 9, 16),
                    _aspectChip('4:5', 4, 5),
                    ActionChip(
                      label: const Text('重置'),
                      avatar: const Icon(Icons.refresh, size: 14),
                      onPressed: _resetCrop,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      setState(() => _showCropOverlay = !_showCropOverlay),
                  icon: Icon(
                    _showCropOverlay ? Icons.visibility_off : Icons.visibility,
                    size: 17,
                  ),
                  label: Text(_showCropOverlay ? '隐藏裁剪框' : '显示裁剪框（可拖拽）'),
                ),
                const SizedBox(height: 8),
                if (_videoWidth > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.crop_free, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _cropInfoText(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  '开启后可通过拖拽选择导出区域',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _cropInfoText() {
    if (_videoWidth == 0 || _videoHeight == 0) return '--';
    final x = (_cropRect.left * _videoWidth).round();
    final y = (_cropRect.top * _videoHeight).round();
    final w = (_cropRect.width * _videoWidth).round();
    final h = (_cropRect.height * _videoHeight).round();
    final pct =
        '${(_cropRect.width * 100).round()}×${(_cropRect.height * 100).round()}%';
    return '$w×${h}px  起点($x, $y)  [$pct]';
  }

  Widget _aspectChip(String label, int w, int h) {
    final isActive = _useCustomCrop && _isAspectMatch(w, h);
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => _applyCropAspect(w, h),
    );
  }

  bool _isAspectMatch(int w, int h) {
    if (_videoWidth == 0 || _videoHeight == 0) return false;
    final target = w / h;
    final current =
        _cropRect.width /
        max(_cropRect.height, 0.001) *
        (_videoWidth / max(_videoHeight, 1));
    return (current - target).abs() < 0.05;
  }

  Widget _buildExportBar() {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPad),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isExporting) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _exportProgress,
                      minHeight: 6,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_exportProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (_exportStatus.isNotEmpty) ...[
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _exportStatus,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_fmt(_clipDuration)} · ${_estimatedSize()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isExporting ? null : _exportClip,
                icon: _isExporting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Icon(Icons.file_download_outlined, size: 18),
                label: Text(_isExporting ? '导出中…' : '导出'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
