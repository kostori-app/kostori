// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math' show max;

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
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum ExportFormat { mp4, gif, apng, webp }

enum ExportQuality { high, medium, low }

// ─────────────────────────────────────────────────────────────────────────────
// Entry point (replaces MaterialPageRoute push)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showVideoClipEditor({
  required BuildContext context,
  required Player player,
  required String videoUrl,
  Map<String, String>? httpHeaders,
  required Duration currentPosition,
  required Duration duration,
}) async {
  // Check FFmpeg existence on desktop
  if (App.isDesktop) {
    final customPath = appdata.settings['ffmpegPath'] as String?;
    bool ffmpegExists = false;

    if (customPath != null && customPath.isNotEmpty) {
      ffmpegExists = await File(customPath).exists();
    }

    if (!ffmpegExists) {
      try {
        final result = await Process.run('where', ['ffmpeg.exe']);
        if (result.exitCode == 0) {
          ffmpegExists = true;
        }
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
        builder: (context) => AlertDialog(
          title: const Text('FFmpeg 未找到'),
          content: const Text(
            '桌面端导出功能需要 FFmpeg，但未找到 FFmpeg 可执行文件。\n\n'
            '请在设置中配置 FFmpeg 路径，或确保 FFmpeg 在系统 PATH 中。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
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
    VideoClipEditorPage(
      player: player,
      videoUrl: videoUrl,
      httpHeaders: httpHeaders,
      currentPosition: currentPosition,
      duration: duration,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Concurrent HLS segment downloader
// ─────────────────────────────────────────────────────────────────────────────

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

class _HlsDownloader {
  /// Downloads only the HLS segments that overlap [startMs, endMs].
  /// Parses #EXTINF durations to skip segments outside the clip range.
  /// Falls back to null (caller uses original URL) on any error.
  static Future<String?> download({
    required String url,
    required Map<String, String> headers,
    required int startMs,
    required int endMs,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!_isHls(url)) return null;

    try {
      final dio = AppDio();
      onProgress?.call(0, '解析播放列表…');

      // ── Fetch root playlist ───────────────────────────────────────────
      final rootResp = await dio.get<String>(
        url,
        options: Options(headers: headers, responseType: ResponseType.plain),
      );
      String content = rootResp.data ?? '';

      // ── If master playlist → pick highest-bandwidth variant ──────────
      String targetUrl = url;
      if (content.contains('#EXT-X-STREAM-INF')) {
        final baseUrl = _baseOf(url);
        String? bestVariant;
        int bestBandwidth = -1;

        final lines = content.split('\n');
        for (int i = 0; i < lines.length - 1; i++) {
          final l = lines[i].trim();
          if (l.startsWith('#EXT-X-STREAM-INF')) {
            final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(l);
            final bw = bwMatch != null
                ? int.tryParse(bwMatch.group(1)!) ?? 0
                : 0;
            final variantLine = lines[i + 1].trim();
            if (variantLine.isNotEmpty && !variantLine.startsWith('#')) {
              if (bw > bestBandwidth) {
                bestBandwidth = bw;
                bestVariant = variantLine.startsWith('http')
                    ? variantLine
                    : '$baseUrl$variantLine';
              }
            }
          }
        }

        if (bestVariant != null) {
          targetUrl = bestVariant;
          final variantResp = await dio.get<String>(
            targetUrl,
            options: Options(
              headers: headers,
              responseType: ResponseType.plain,
            ),
          );
          content = variantResp.data ?? '';
        }
      }

      // ── Parse segment list + durations from variant playlist ──────────
      final segBase = _baseOf(targetUrl);
      final playlistLines = content.split('\n');

      // Build a list of (url, durationMs) pairs
      final allSegs = <({String url, int durationMs})>[];
      double pendingDurSec = 0;
      for (final line in playlistLines) {
        final l = line.trim();
        if (l.startsWith('#EXTINF:')) {
          // #EXTINF:<duration>, → parse the float after the colon
          final raw = l.substring(8).split(',').first;
          pendingDurSec = double.tryParse(raw) ?? pendingDurSec;
        } else if (l.isNotEmpty && !l.startsWith('#')) {
          final segUrl = l.startsWith('http') ? l : '$segBase$l';
          allSegs.add((
            url: segUrl,
            durationMs: (pendingDurSec * 1000).round(),
          ));
          pendingDurSec = 0;
        }
      }
      if (allSegs.isEmpty) return null;

      // ── Find which segments overlap [startMs, endMs] ──────────────────
      // Add one-segment buffer before/after to handle imprecise seeks.
      int cursor = 0;
      int firstIdx = 0;
      int lastIdx = allSegs.length - 1;
      bool foundFirst = false;
      for (int i = 0; i < allSegs.length; i++) {
        final segEnd = cursor + allSegs[i].durationMs;
        if (!foundFirst && segEnd > startMs) {
          firstIdx = (i - 1).clamp(
            0,
            allSegs.length - 1,
          ); // 1-seg buffer before
          foundFirst = true;
        }
        if (cursor >= endMs) {
          lastIdx = (i + 1).clamp(0, allSegs.length - 1); // 1-seg buffer after
          break;
        }
        cursor += allSegs[i].durationMs;
      }
      final needed = allSegs.sublist(firstIdx, lastIdx + 1);

      Log.info(
        'HlsDownloader',
        'Downloading ${needed.length}/${allSegs.length} segments '
            '(idx $firstIdx–$lastIdx) for clip $startMs–${endMs}ms',
      );

      // ── Create temp directory ─────────────────────────────────────────
      final tempDir = await getTemporaryDirectory();
      final sessionId = DateTime.now().millisecondsSinceEpoch;
      final segDir = Directory('${tempDir.path}/kostori_hls_$sessionId');
      await segDir.create(recursive: true);

      // ── Concurrent download with semaphore (max 6 parallel) ──────────
      final sem = _Semaphore(6);
      final errors = <String>[];
      int completed = 0;
      final total = needed.length;

      await Future.wait(
        needed.asMap().entries.map((entry) async {
          await sem.acquire();
          try {
            final localIdx = entry.key;
            final segUrl = entry.value.url;
            final segPath =
                '${segDir.path}/seg_${localIdx.toString().padLeft(6, '0')}.ts';
            final resp = await dio.get<List<int>>(
              segUrl,
              options: Options(
                headers: headers,
                responseType: ResponseType.bytes,
              ),
            );
            if (resp.data != null && resp.data!.isNotEmpty) {
              await File(segPath).writeAsBytes(resp.data!, flush: true);
            }
            completed++;
            onProgress?.call(completed / total, '下载分片 $completed/$total…');
          } catch (e) {
            errors.add('Segment ${entry.key}: $e');
            Log.error(
              'HlsDownloader',
              'Segment ${firstIdx + entry.key} error: $e',
            );
          } finally {
            sem.release();
          }
        }),
      );

      if (errors.isNotEmpty) {
        for (final e in errors) {
          Log.error('HlsDownloader', e);
        }
        return null;
      }

      // ── Build trimmed local m3u8 (only needed segments) ───────────────
      // Extract header lines (everything before the first segment URL in the
      // original playlist) to keep codec/key/targetduration metadata.
      final headerLines = <String>[];
      bool headerDone = false;
      for (final line in playlistLines) {
        final l = line.trim();
        if (!headerDone && l.isNotEmpty && !l.startsWith('#')) {
          headerDone = true; // first segment → stop collecting headers
        }
        if (!headerDone) headerLines.add(line);
      }

      // Rebuild playlist: headers + EXTINF+localPath for each needed segment
      final localLines = <String>[...headerLines];
      for (int i = 0; i < needed.length; i++) {
        final durSec = (needed[i].durationMs / 1000.0).toStringAsFixed(3);
        localLines.add('#EXTINF:$durSec,');
        localLines.add('${segDir.path}/seg_${i.toString().padLeft(6, '0')}.ts');
      }
      localLines.add('#EXT-X-ENDLIST');

      final localM3u8 = '${segDir.path}/local.m3u8';
      await File(localM3u8).writeAsString(localLines.join('\n'));
      return localM3u8;
    } catch (e, st) {
      Log.error('HlsDownloader', '$e\n$st');
      return null;
    }
  }

  static bool _isHls(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('m3u8');
  }

  static String _baseOf(String url) {
    final idx = url.lastIndexOf('/');
    return idx >= 0 ? url.substring(0, idx + 1) : '$url/';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Page Widget
// ─────────────────────────────────────────────────────────────────────────────

class VideoClipEditorPage extends StatefulWidget {
  final Player player;
  final String videoUrl;
  final Map<String, String>? httpHeaders;
  final Duration currentPosition;
  final Duration duration;

  const VideoClipEditorPage({
    super.key,
    required this.player,
    required this.videoUrl,
    this.httpHeaders,
    required this.currentPosition,
    required this.duration,
  });

  @override
  State<VideoClipEditorPage> createState() => _VideoClipEditorPageState();
}

class _VideoClipEditorPageState extends State<VideoClipEditorPage> {
  late VideoController _videoController;
  StreamSubscription<Duration>? _positionSub;

  // ── Time ──────────────────────────────────────────────────────────────────
  static const maxExportDurationMs = 60000; // 60 seconds max export
  late Duration _startTime;
  late Duration _endTime;

  // ── Format & Quality ──────────────────────────────────────────────────────
  ExportFormat _format = ExportFormat.mp4;
  ExportQuality _quality = ExportQuality.medium;

  // ── Resolution ────────────────────────────────────────────────────────────
  int? _exportWidth; // null = source resolution

  // ── MP4 options ───────────────────────────────────────────────────────────
  bool _includeAudio = true;

  // ── Animated options (GIF / APNG / WebP) ─────────────────────────────────
  int _animFps = 15;
  int _webpQuality = 75; // 0-100

  // ── Crop ──────────────────────────────────────────────────────────────────
  bool _useCustomCrop = false;
  bool _showCropOverlay = false;

  // Normalized crop rect [0,1]×[0,1]; origin = top-left
  Rect _cropRect = const Rect.fromLTWH(0, 0, 1, 1);

  // ── Source video info ─────────────────────────────────────────────────────
  int _videoWidth = 0;
  int _videoHeight = 0;

  // ── Playback state ────────────────────────────────────────────────────────
  bool _isPlaying = false;

  // ── Export state ──────────────────────────────────────────────────────────
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';
  bool _exportCancelled = false;

  // ── Scroll-aware top border ───────────────────────────────────────────────
  bool _atScrollTop = true;

  // ── Temp HLS directory (cleaned up on dispose) ────────────────────────────
  Directory? _hlsTempDir;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(widget.player);

    // Default selection: current position → +10 s (max 60s)
    _startTime = widget.currentPosition;
    _endTime = _startTime + const Duration(seconds: 10);
    final maxEndTime =
        _startTime + const Duration(milliseconds: maxExportDurationMs);
    if (_endTime > maxEndTime) _endTime = maxEndTime;
    if (_endTime > widget.duration) _endTime = widget.duration;

    // Initial video dimensions
    final w = widget.player.state.width;
    final h = widget.player.state.height;
    if (w != null && h != null && w > 0 && h > 0) {
      _videoWidth = w;
      _videoHeight = h;
    }

    _positionSub = widget.player.stream.position.listen((pos) {
      if (!mounted) return;
      setState(() {});
      if (_isPlaying && pos >= _endTime) {
        widget.player.pause();
        setState(() => _isPlaying = false);
      }
    });

    widget.player.stream.videoParams.listen((p) {
      if (!mounted || p.dw == null || p.dh == null) return;
      setState(() {
        _videoWidth = p.dw!;
        _videoHeight = p.dh!;
      });
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _exportCancelled = true;
    _hlsTempDir?.delete(recursive: true).ignore();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Computed helpers
  // ─────────────────────────────────────────────────────────────────────────

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

  /// Rough file-size estimate based on format/quality/resolution/duration.
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
        // bitsPerPixelPerSecond varies by CRF
        final bpp = switch (_quality) {
          ExportQuality.high => 0.10,
          ExportQuality.medium => 0.04,
          ExportQuality.low => 0.015,
        };
        final audio = _includeAudio ? 16000.0 : 0.0; // 128 kbps
        bytes = ((px * bpp / 8 + audio) * durSec).round();
      case ExportFormat.gif:
        // GIF ~0.4 byte/pixel/frame (palette + LZW)
        bytes = (px * _animFps * durSec * 0.40).round();
      case ExportFormat.apng:
        // APNG ~0.25 byte/pixel/frame (PNG zlib)
        bytes = (px * _animFps * durSec * 0.25).round();
      case ExportFormat.webp:
        final qf = _webpQuality / 100.0;
        bytes = (px * _animFps * durSec * 0.15 * qf).round();
    }

    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Playback
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _previewClip() async {
    await widget.player.seek(_startTime);
    await widget.player.play();
    setState(() => _isPlaying = true);
  }

  Future<void> _stopPreview() async {
    await widget.player.pause();
    setState(() => _isPlaying = false);
  }

  void _seekToStart() {
    widget.player.seek(_startTime);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Time controls
  // ─────────────────────────────────────────────────────────────────────────

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
          widget.duration.inMilliseconds,
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
    final pos = widget.player.state.position;
    setState(() {
      _startTime = pos;
      if (_startTime >= _endTime) {
        _endTime = _startTime + const Duration(seconds: 1);
        final maxEndTime =
            _startTime + const Duration(milliseconds: maxExportDurationMs);
        if (_endTime > maxEndTime) _endTime = maxEndTime;
        if (_endTime > widget.duration) _endTime = widget.duration;
      }
    });
  }

  void _setEndToCurrent() {
    final pos = widget.player.state.position;
    setState(() {
      _endTime = pos;
      if (_endTime <= _startTime) {
        _startTime = _endTime - const Duration(seconds: 1);
        if (_startTime < Duration.zero) _startTime = Duration.zero;
      }
      // Clamp to max duration
      final maxEndTime =
          _startTime + const Duration(milliseconds: maxExportDurationMs);
      if (_endTime > maxEndTime) _endTime = maxEndTime;
      if (_endTime > widget.duration) _endTime = widget.duration;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Crop helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Apply a named aspect-ratio preset centered on the video.
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

  // ─────────────────────────────────────────────────────────────────────────
  // Export
  // ─────────────────────────────────────────────────────────────────────────

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
      // ── Step 1: HLS concurrent pre-download ─────────────────────────
      // For desktop, animated formats (GIF/APNG/WebP) can let FFmpeg handle HLS natively.
      // For mobile (Android/iOS), FFmpeg builds often lack HTTPS support, so we must
      // pre-download segments to local files regardless of format.
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

      // ── Step 2: Build FFmpeg args ─────────────────────────────────────
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

      // ── Step 3: Validate & save ───────────────────────────────────────
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
    // ── Crop pixel values (even-aligned for codec compatibility) ─────────
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
          ),
        );

      case ExportFormat.apng:
        return (
          'apng',
          FfmpegEncodeArgs(
            inputUrl: exportUrl,
            // ✅ Fixed: was incorrectly using .webp extension & webp format
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

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

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
            // ── App bar ──────────────────────────────────────────────────
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
                  // Preview / stop button in header
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
                            onPressed: _isExporting ? null : _previewClip,
                          ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────
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
                    // Bottom padding for the fixed export bar
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),

            // ── Fixed export bar ─────────────────────────────────────────
            _buildExportBar(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Video preview with optional crop overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildVideoPreview() {
    final aspectRatio = _videoWidth > 0 && _videoHeight > 0
        ? _videoWidth / _videoHeight
        : 16.0 / 9.0;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Video(controller: _videoController),
          // Crop overlay (only when active)
          if (_showCropOverlay)
            _CropOverlay(
              cropRect: _cropRect,
              onChanged: (r) => setState(() {
                _cropRect = r;
                _useCustomCrop = true;
              }),
            ),
          // Crop-toggle button (bottom-right corner)
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
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surface,
                      foregroundColor: _showCropOverlay
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      onPressed: () =>
                          setState(() => _showCropOverlay = !_showCropOverlay),
                      child: const Icon(Icons.crop, size: 18),
                    )
                  : const SizedBox.shrink(key: ValueKey('crop_off')),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Time section: range slider + fine controls
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTimeSection() {
    final cs = Theme.of(context).colorScheme;
    final totalMs = widget.duration.inMilliseconds.toDouble();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title + clip info
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '时间范围',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_fmt(_clipDuration)}  ≈ ${_estimatedSize()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('时间范围', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_fmt(_clipDuration)}  ≈ ${_estimatedSize()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),

              // RangeSlider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  rangeThumbShape: RoundRangeSliderThumbShape(
                    enabledThumbRadius: isCompact ? 6 : 8,
                  ),
                  trackHeight: 4,
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: isCompact ? 12 : 16,
                  ),
                ),
                child: RangeSlider(
                  min: 0,
                  max: max(totalMs, 1),
                  values: RangeValues(
                    _startTime.inMilliseconds.toDouble(),
                    _endTime.inMilliseconds.toDouble(),
                  ),
                  labels: RangeLabels(_fmt(_startTime), _fmt(_endTime)),
                  onChanged: (v) {
                    setState(() {
                      _startTime = Duration(milliseconds: v.start.round());
                      var newEnd = Duration(milliseconds: v.end.round());
                      // Clamp to max duration
                      final maxEnd =
                          _startTime +
                          const Duration(milliseconds: maxExportDurationMs);
                      if (newEnd > maxEnd) newEnd = maxEnd;
                      if (newEnd > widget.duration) newEnd = widget.duration;
                      _endTime = newEnd;
                    });
                  },
                ),
              ),

              // Fine-tune row: [- Start +]  |  [- End +]
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

              const SizedBox(height: 8),

              // "Set here" quick buttons
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
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _setStartToCurrent,
                        icon: const Icon(Icons.content_cut, size: 15),
                        label: const Text('设为起点'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _setEndToCurrent,
                        icon: const Icon(Icons.content_cut_rounded, size: 15),
                        label: const Text('设为终点'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: _seekToStart,
                      icon: const Icon(Icons.skip_previous, size: 18),
                      tooltip: '跳到起点',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                    ),
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
        // −1 s
        _nudgeBtn(
          icon: Icons.fast_rewind,
          size: iconSize,
          tooltip: isStart ? '起点 −1s' : '终点 −1s',
          onTap: () => _nudge(isStart: isStart, deltaMs: -1000),
          minSize: btnMinSize,
        ),
        // −0.1 s
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
        // +0.1 s
        _nudgeBtn(
          icon: Icons.add,
          size: iconSize,
          tooltip: isStart ? '起点 +0.1s' : '终点 +0.1s',
          onTap: () => _nudge(isStart: isStart, deltaMs: 100),
          minSize: btnMinSize,
        ),
        // +1 s
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

  // ─────────────────────────────────────────────────────────────────────────
  // Export settings card
  // ─────────────────────────────────────────────────────────────────────────

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

              // ── Format ────────────────────────────────────────────────
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

              // ── Resolution ────────────────────────────────────────────
              _label('分辨率'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _resChip(label: '原始', value: null),
                  _resChip(label: '480p', value: 480),
                  _resChip(label: '720p', value: 720),
                  _resChip(label: '1080p', value: 1080),
                ],
              ),
              const SizedBox(height: 12),

              // ── Format-specific settings ──────────────────────────────
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
                  onSelectionChanged: (s) => setState(() => _quality = s.first),
                ),
                const SizedBox(height: 10),
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

              // ── Info row ──────────────────────────────────────────────
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
        'H.264 · CRF $_crf · ${_includeAudio ? "含音频" : "无音频"}',
      ExportFormat.gif => 'GIF · $_animFps fps · 无音频 · 文件较大',
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

  // ─────────────────────────────────────────────────────────────────────────
  // Crop section
  // ─────────────────────────────────────────────────────────────────────────

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
              // Header
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

                // Aspect ratio presets
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

                // Edit overlay button
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

                // Current crop info
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
    // Determine if this preset is currently active
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

  // ─────────────────────────────────────────────────────────────────────────
  // Fixed export bar at bottom
  // ─────────────────────────────────────────────────────────────────────────

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
          // Progress bar
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

          // Buttons row
          Row(
            children: [
              // Clip info chip
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
              // Export button
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

  // ─────────────────────────────────────────────────────────────────────────
  // Small helpers
  // ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Visual crop overlay with drag handles
// ─────────────────────────────────────────────────────────────────────────────

class _CropOverlay extends StatefulWidget {
  final Rect cropRect; // normalized [0,1]×[0,1]
  final ValueChanged<Rect> onChanged;

  const _CropOverlay({required this.cropRect, required this.onChanged});

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  late Rect _rect;

  @override
  void initState() {
    super.initState();
    _rect = widget.cropRect;
  }

  @override
  void didUpdateWidget(_CropOverlay old) {
    super.didUpdateWidget(old);
    // Accept external updates (e.g. aspect preset buttons)
    if (old.cropRect != widget.cropRect) {
      setState(() => _rect = widget.cropRect);
    }
  }

  void _update(Rect r) {
    // Clamp all edges to [0,1]
    final clamped = Rect.fromLTRB(
      r.left.clamp(0.0, 1.0),
      r.top.clamp(0.0, 1.0),
      r.right.clamp(0.0, 1.0),
      r.bottom.clamp(0.0, 1.0),
    );
    setState(() => _rect = clamped);
    widget.onChanged(_rect);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final sz = Size(c.maxWidth, c.maxHeight);
        final dr = Rect.fromLTWH(
          _rect.left * sz.width,
          _rect.top * sz.height,
          _rect.width * sz.width,
          _rect.height * sz.height,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Dark mask + border + rule-of-thirds grid ──────────────────
            CustomPaint(size: sz, painter: _CropMaskPainter(dr)),

            // ── Interior drag (move the crop box) ─────────────────────────
            Positioned(
              left: dr.left,
              top: dr.top,
              width: dr.width,
              height: dr.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (d) {
                  final dx = d.delta.dx / sz.width;
                  final dy = d.delta.dy / sz.height;
                  _update(
                    Rect.fromLTWH(
                      (_rect.left + dx).clamp(0, 1.0 - _rect.width),
                      (_rect.top + dy).clamp(0, 1.0 - _rect.height),
                      _rect.width,
                      _rect.height,
                    ),
                  );
                },
                child: Container(color: Colors.transparent),
              ),
            ),

            // ── Corner & edge handles ──────────────────────────────────────
            // TL
            _handle(dr.topLeft, sz, (d) {
              final dx = d.delta.dx / sz.width;
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  (_rect.left + dx).clamp(0.0, _rect.right - 0.05),
                  (_rect.top + dy).clamp(0.0, _rect.bottom - 0.05),
                  _rect.right,
                  _rect.bottom,
                ),
              );
            }, corner: true),
            // TC
            _handle(dr.topCenter, sz, (d) {
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  (_rect.top + dy).clamp(0.0, _rect.bottom - 0.05),
                  _rect.right,
                  _rect.bottom,
                ),
              );
            }),
            // TR
            _handle(dr.topRight, sz, (d) {
              final dx = d.delta.dx / sz.width;
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  (_rect.top + dy).clamp(0.0, _rect.bottom - 0.05),
                  (_rect.right + dx).clamp(_rect.left + 0.05, 1.0),
                  _rect.bottom,
                ),
              );
            }, corner: true),
            // ML
            _handle(dr.centerLeft, sz, (d) {
              final dx = d.delta.dx / sz.width;
              _update(
                Rect.fromLTRB(
                  (_rect.left + dx).clamp(0.0, _rect.right - 0.05),
                  _rect.top,
                  _rect.right,
                  _rect.bottom,
                ),
              );
            }),
            // MR
            _handle(dr.centerRight, sz, (d) {
              final dx = d.delta.dx / sz.width;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  _rect.top,
                  (_rect.right + dx).clamp(_rect.left + 0.05, 1.0),
                  _rect.bottom,
                ),
              );
            }),
            // BL
            _handle(dr.bottomLeft, sz, (d) {
              final dx = d.delta.dx / sz.width;
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  (_rect.left + dx).clamp(0.0, _rect.right - 0.05),
                  _rect.top,
                  _rect.right,
                  (_rect.bottom + dy).clamp(_rect.top + 0.05, 1.0),
                ),
              );
            }, corner: true),
            // BC
            _handle(dr.bottomCenter, sz, (d) {
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  _rect.top,
                  _rect.right,
                  (_rect.bottom + dy).clamp(_rect.top + 0.05, 1.0),
                ),
              );
            }),
            // BR
            _handle(dr.bottomRight, sz, (d) {
              final dx = d.delta.dx / sz.width;
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  _rect.top,
                  (_rect.right + dx).clamp(_rect.left + 0.05, 1.0),
                  (_rect.bottom + dy).clamp(_rect.top + 0.05, 1.0),
                ),
              );
            }, corner: true),
          ],
        );
      },
    );
  }

  Widget _handle(
    Offset pos,
    Size sz,
    void Function(DragUpdateDetails) onUpdate, {
    bool corner = false,
  }) {
    final hs = corner ? 20.0 : 16.0;
    return Positioned(
      left: pos.dx - hs / 2,
      top: pos.dy - hs / 2,
      child: GestureDetector(
        onPanUpdate: onUpdate,
        child: Container(
          width: hs,
          height: hs,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: corner ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: corner ? null : BorderRadius.circular(4),
            border: Border.all(
              color: Colors.blue.shade400,
              width: corner ? 2.5 : 2.0,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 3, spreadRadius: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropMaskPainter extends CustomPainter {
  final Rect rect;

  _CropMaskPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final mask = Paint()..color = Colors.black.withAlpha(140);
    // Four shadow rects
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), mask);
    canvas.drawRect(
      Rect.fromLTRB(0, rect.bottom, size.width, size.height),
      mask,
    );
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), mask);
    canvas.drawRect(
      Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom),
      mask,
    );

    // White border
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, border);

    // Corner accents (L-shaped)
    final accent = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;
    const cl = 14.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final sx = corner.dx == rect.left ? 1 : -1;
      final sy = corner.dy == rect.top ? 1 : -1;
      canvas.drawLine(corner, Offset(corner.dx + sx * cl, corner.dy), accent);
      canvas.drawLine(corner, Offset(corner.dx, corner.dy + sy * cl), accent);
    }

    // Rule-of-thirds grid (subtle)
    final grid = Paint()
      ..color = Colors.white.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (int i = 1; i <= 2; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
  }

  @override
  bool shouldRepaint(_CropMaskPainter old) => old.rect != rect;
}
