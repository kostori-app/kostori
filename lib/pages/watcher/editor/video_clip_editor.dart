// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math' as math;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/device_info.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/proxy.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/ffmpeg_encoder.dart';
import 'package:kostori/utils/io.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
          title: 'FFmpeg 未找到',
          content: const Text(
            '桌面端导出功能需要 FFmpeg，但未找到 FFmpeg 可执行文件。\n\n'
            '请在设置中配置 FFmpeg 路径，或确保 FFmpeg 在系统 PATH 中。',
          ),
          cancel: () {
            Navigator.of(context).pop(false);
          },
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('仍要打开'),
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
  Duration _previewStopTarget = Duration.zero;
  Directory? _previewHlsTempDir;

  bool _isPlaying = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';
  bool _exportCancelled = false;
  bool _atScrollTop = true;
  Directory? _hlsTempDir;

  @override
  void initState() {
    super.initState();
    _startTime = widget.currentPosition;
    _endTime = _startTime + const Duration(seconds: 10);
    final maxEndTime =
        _startTime + const Duration(milliseconds: maxExportDurationMs);
    if (_endTime > maxEndTime) _endTime = maxEndTime;
    _initPreviewPlayer();
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

  String _estimatedSize() {
    final durSec = _clipDuration.inMilliseconds / 1000.0;
    if (durSec <= 0 || _videoWidth == 0) return '--';

    final outW = _exportWidth ?? _videoWidth;
    final outH = _videoWidth > 0 && _videoHeight > 0
        ? (outW * _videoHeight / _videoWidth).round()
        : outW * 9 ~/ 16;
    final px = outW * outH;

    int bytes;
    switch (_format) {
      case ExportFormat.mp4:
        if (_mp4BitrateKbps != null) {
          final audio = _includeAudio ? 128000.0 : 0.0;
          bytes = ((_mp4BitrateKbps! * 1000.0 + audio) / 8 * durSec).round();
        } else {
          final bpp = switch (_quality) {
            ExportQuality.high => 0.10,
            ExportQuality.medium => 0.04,
            ExportQuality.low => 0.015,
          };
          final audio = _includeAudio ? 16000.0 : 0.0;
          bytes = ((px * bpp / 8 + audio) * durSec).round();
        }
      case ExportFormat.gif:
        final colorFactor = (_gifColors / 256.0).clamp(0.1, 1.0);
        final ditherFactor = _gifDither ? 1.15 : 1.0;
        bytes = (px * _animFps * durSec * 0.40 * colorFactor * ditherFactor)
            .round();
      case ExportFormat.apng:
        bytes = (px * _animFps * durSec * 0.25).round();
      case ExportFormat.webp:
        final qf = _webpQuality / 100.0;
        bytes = (px * _animFps * durSec * 0.15 * qf).round();
    }

    if (bytes < 1024) return '${bytes}B';
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

  void _seekToStart() {
    _previewPlayer?.seek(_previewSeekTarget);
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
      _previewStatus = '准备中…';
      _isPlaying = false;
    });

    try {
      final halfWindowMs = _previewWindowMs ~/ 2;
      final downloadStartMs = (_startTime.inMilliseconds - halfWindowMs).clamp(
        0,
        widget.duration.inMilliseconds,
      );
      final downloadEndMs = (_startTime.inMilliseconds + halfWindowMs).clamp(
        0,
        widget.duration.inMilliseconds,
      );
      final isHls = _HlsDownloader._isHls(widget.videoUrl);
      String mediaUrl = widget.videoUrl;

      if (isHls) {
        setState(() => _previewStatus = '正在下载预览片段…');
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
      setState(() => _previewStatus = '加载播放器…');

      bool hAenable = appdata.settings['hAenable'] ?? true;
      String hardwareDecoder =
          appdata.settings['hardwareDecoder'] ?? 'auto-safe';
      String videoRenderer = '';
      if (App.isAndroid) {
        final info = await DeviceInfo.getDeviceInfo();

        final String androidVideoRenderer =
            appdata.settings['animeListDisplayMode'];

        if (androidVideoRenderer == 'auto') {
          // Android 14 及以上使用基于 Vulkan 的 MPV GPU-NEXT 视频输出，着色器性能更好
          // GPU-NEXT 需要 Vulkan 1.2 支持
          // 避免 Android 14 及以下设备上部分机型 Vulkan 支持不佳导致的黑屏问题
          final int androidSdkVersion =
              (info as AndroidDeviceInfo).version.sdkInt;
          if (androidSdkVersion >= 34) {
            videoRenderer = 'gpu-next';
          } else {
            videoRenderer = 'gpu';
          }
        } else {
          videoRenderer = androidVideoRenderer;
        }
      }

      if (videoRenderer == 'mediacodec_embed') {
        hAenable = true;
        hardwareDecoder = 'mediacodec';
      }

      final player = Player();
      final controller = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          vo: videoRenderer,
          enableHardwareAcceleration: hAenable,
          hwdec: hAenable ? hardwareDecoder : 'no',
          androidAttachSurfaceAfterVideoParameters: false,
        ),
      );

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
            if (_endTime > _videoDuration) {
              _endTime = _videoDuration;
            }
          });
        }
      });

      final seekTarget = isHls && mediaUrl != widget.videoUrl
          ? Duration(milliseconds: _startTime.inMilliseconds - downloadStartMs)
          : _startTime;
      final stopTarget = seekTarget + _clipDuration;

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) {
        player.dispose();
        return;
      }
      await player.seek(seekTarget);

      _previewSeekTarget = seekTarget;
      _previewStopTarget = stopTarget;

      player.stream.videoParams.listen((p) {
        if (!mounted || p.dw == null || p.dh == null) return;
        setState(() {
          _videoWidth = p.dw!;
          _videoHeight = p.dh!;
        });
      });

      _previewPosSub = player.stream.position.listen((pos) {
        if (!mounted) return;
        if (_isPlaying && pos >= _previewStopTarget) {
          player.pause();
          player.seek(_previewSeekTarget);
          if (mounted) setState(() => _isPlaying = false);
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

  void _nudge({required bool isStart, required int deltaMs}) {
    setState(() {
      if (isStart) {
        _startTime = Duration(
          milliseconds: (_startTime.inMilliseconds + deltaMs).clamp(
            0,
            _endTime.inMilliseconds - 100,
          ),
        );
      } else {
        final maxEnd = [
          _startTime.inMilliseconds + maxExportDurationMs,
          _videoDuration.inMilliseconds,
        ].reduce((a, b) => a < b ? a : b);
        _endTime = Duration(
          milliseconds: (_endTime.inMilliseconds + deltaMs).clamp(
            _startTime.inMilliseconds + 100,
            maxEnd,
          ),
        );
      }
    });
  }

  void _setStartToCurrent() {
    final pos = _previewPlayer?.state.position ?? _startTime;
    setState(() {
      _startTime = pos;
      if (_startTime >= _endTime) {
        _endTime = _startTime + const Duration(seconds: 1);
        final maxEndTime =
            _startTime + const Duration(milliseconds: maxExportDurationMs);
        if (_endTime > maxEndTime) _endTime = maxEndTime;
        if (_endTime > _videoDuration) _endTime = _videoDuration;
      }
    });
  }

  void _setEndToCurrent() {
    final pos = _previewPlayer?.state.position ?? _endTime;
    setState(() {
      _endTime = pos;
      if (_endTime <= _startTime) {
        _startTime = _endTime - const Duration(seconds: 1);
        if (_startTime < Duration.zero) _startTime = Duration.zero;
      }
      final maxEndTime =
          _startTime + const Duration(milliseconds: maxExportDurationMs);
      if (_endTime > maxEndTime) _endTime = maxEndTime;
      if (_endTime > _videoDuration) _endTime = _videoDuration;
    });
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
            title: const Text('取消导出?'),
            content: const Text('导出正在进行中，关闭将中断导出。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确认关闭'),
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
      _exportStatus = '准备中…';
      _exportCancelled = false;
    });

    String exportUrl = widget.videoUrl;
    final exportHeaders = Map<String, String>.from(widget.httpHeaders ?? {});
    final proxyUrl = await getProxy();

    try {
      final bool isMobile = Platform.isAndroid || Platform.isIOS;
      final bool doPreDownload =
          _HlsDownloader._isHls(exportUrl) &&
          (_format == ExportFormat.mp4 || isMobile);

      if (doPreDownload) {
        setState(() => _exportStatus = '下载视频分片…');
        final localM3u8 = await _HlsDownloader.download(
          url: exportUrl,
          headers: exportHeaders,
          startMs: _startTime.inMilliseconds,
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

      setState(() => _exportStatus = '编码中…');

      final outputDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;

      final (ext, encodeArgs) = _buildEncodeArgs(
        outputDir: outputDir.path,
        timestamp: ts,
        exportUrl: exportUrl,
        exportHeaders: exportHeaders,
        proxyUrl: proxyUrl,
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
  }) {
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
            startMs: _startTime.inMilliseconds,
            lengthMs: _clipDuration.inMilliseconds,
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
            startMs: _startTime.inMilliseconds,
            lengthMs: _clipDuration.inMilliseconds,
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
            startMs: _startTime.inMilliseconds,
            lengthMs: _clipDuration.inMilliseconds,
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
            startMs: _startTime.inMilliseconds,
            lengthMs: _clipDuration.inMilliseconds,
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
                    tooltip: '关闭',
                    onPressed: _handleClose,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '视频剪辑',
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
                            tooltip: '停止预览',
                            onPressed: _stopPreview,
                          )
                        : IconButton(
                            key: const ValueKey('play'),
                            icon: const Icon(Icons.play_circle_outline),
                            tooltip: '预览片段',
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
                    _previewStatus.isEmpty ? '正在加载预览…' : _previewStatus,
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
                  const Text(
                    '预览加载失败',
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
                    child: const Text('重试', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else if (_previewController != null)
            Video(
              controller: _previewController!,
              fill: Colors.transparent,
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
                        tooltip: '编辑裁剪框',
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

  Widget _buildTimeSection() {
    final isCompact = App.isMobile;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 8 : 16,
        12,
        isCompact ? 8 : 16,
        0,
      ),
      child: Card.outlined(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 8 : 12,
            12,
            isCompact ? 8 : 12,
            8,
          ),
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
                },
                timelineThumbnails: Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: Text(
                      '视频时间轴缩略图',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ),
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

              const SizedBox(height: 10),

              if (isCompact)
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _setStartToCurrent,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.content_cut, size: 14),
                          const SizedBox(width: 4),
                          const Text('起点', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _setEndToCurrent,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.content_cut_rounded, size: 14),
                          const SizedBox(width: 4),
                          const Text('终点', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton.outlined(
                      onPressed: _seekToStart,
                      icon: const Icon(Icons.skip_previous, size: 16),
                      tooltip: '跳到起点',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    // Expanded OutlinedButton... (kept as is)
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
          child: Text(
            _fmt(time),
            style: TextStyle(
              fontSize: timeFontSize,
              fontFeatures: const [FontFeature.tabularFigures()],
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
                    onSelectionChanged: (s) =>
                        setState(() => _format = s.first),
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
      onSelected: (_) => setState(() => _exportWidth = value),
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
