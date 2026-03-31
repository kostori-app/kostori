import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';

/// 编码参数
class FfmpegEncodeArgs {
  final String inputUrl;
  final String outputPath;
  final int startMs;
  final int lengthMs;
  final Map<String, String> headers;
  final String? proxyUrl;
  final String outputFormat; // mp4 / gif / webp / apng
  final int? width;
  final int? height;
  final int? cropX;
  final int? cropY;
  final int? cropWidth;
  final int? cropHeight;

  /// MP4: CRF value as string (e.g. "18", "23", "28").
  /// WebP: quality 0-100 as string (e.g. "75").
  /// GIF/APNG: unused.
  final String? quality;

  /// Frame-rate for animated formats (GIF / APNG / WebP).
  /// Ignored for MP4 (uses source fps).
  final int? fps;

  /// Whether to include audio stream. MP4 only; ignored for image formats.
  final bool includeAudio;

  final void Function(double progress)? onProgress;

  const FfmpegEncodeArgs({
    required this.inputUrl,
    required this.outputPath,
    required this.startMs,
    required this.lengthMs,
    this.headers = const {},
    this.proxyUrl,
    required this.outputFormat,
    this.width,
    this.height,
    this.cropX,
    this.cropY,
    this.cropWidth,
    this.cropHeight,
    this.quality,
    this.fps,
    this.includeAudio = true,
    this.onProgress,
  });
}

/// 使用 FFmpeg 进行视频编码
class FfmpegEncoder {
  final FfmpegEncodeArgs args;

  FfmpegEncoder(this.args);

  static Future<void> encode(FfmpegEncodeArgs args) async {
    final encoder = FfmpegEncoder(args);
    await encoder._encode();
  }

  Future<void> _encode() async {
    final startSec = args.startMs / 1000.0;
    final durationSec = args.lengthMs / 1000.0;
    final safeInput = args.inputUrl.replaceAll('\\', '/');
    final safeOutput = args.outputPath.replaceAll('\\', '/');

    Log.info('FfmpegEncoder', 'Input:  $safeInput');
    Log.info('FfmpegEncoder', 'Output: $safeOutput');
    Log.info('FfmpegEncoder', 'Start: ${startSec}s  Duration: ${durationSec}s');
    Log.info(
      'FfmpegEncoder',
      'Format: ${args.outputFormat}  Platform: ${Platform.operatingSystem}',
    );

    final cmd = _buildCommand(
      inputPath: safeInput,
      outputPath: safeOutput,
      startSec: startSec,
      durationSec: durationSec,
    );

    Log.info('FfmpegEncoder', 'Command: $cmd');

    if (Platform.isWindows) {
      await _encodeWindows(cmd);
    } else {
      await _encodeMobile(cmd);
    }

    await Future.delayed(const Duration(milliseconds: 500));

    final file = File(safeOutput);
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    Log.info('FfmpegEncoder', 'Output file exists: $exists, size: $size bytes');

    if (!exists) throw Exception('Output file not created: $safeOutput');
    if (size == 0) throw Exception('Output file is empty (0 bytes)');

    Log.info('FfmpegEncoder', 'Encoding successful');
  }

  // ── Windows ──────────────────────────────────────────────────────────────

  Future<void> _encodeWindows(String cmd) async {
    final ffmpegPath = await _findFfmpeg();
    if (ffmpegPath == null) {
      throw Exception(
        'FFmpeg not found. Please install FFmpeg and add to PATH, '
        'or set a custom path in Settings.',
      );
    }
    Log.info('FfmpegEncoder', 'Using FFmpeg at: $ffmpegPath');

    // Parse command string into argument list, stripping surrounding quotes
    final raw = cmd.split(' ').where((s) => s.isNotEmpty).toList();
    final processedArgs = raw.map((a) {
      if (a.startsWith('"') && a.endsWith('"')) {
        return a.substring(1, a.length - 1);
      }
      return a;
    }).toList();

    final process = await Process.start(ffmpegPath, processedArgs);

    final totalMs = args.lengthMs;
    double lastProgress = 0;

    process.stderr.transform(const SystemEncoding().decoder).listen((data) {
      final m = RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)').firstMatch(data);
      if (m != null) {
        try {
          final currentMs =
              int.parse(m.group(1)!) * 3600000 +
              int.parse(m.group(2)!) * 60000 +
              int.parse(m.group(3)!) * 1000 +
              int.parse(m.group(4)!);
          double p = (currentMs / totalMs).clamp(0.0, 1.0);
          if (p > lastProgress + 0.01) {
            lastProgress = p;
            args.onProgress?.call(p);
          }
        } catch (_) {}
      }
    });

    final exitCode = await process.exitCode;
    args.onProgress?.call(1.0);
    if (exitCode != 0) throw Exception('FFmpeg exited with code: $exitCode');
  }

  // ── Android / iOS / other via ffmpeg_kit ─────────────────────────────────

  Future<void> _encodeMobile(String cmd) async {
    try {
      final totalMs = args.lengthMs;
      double lastProgress = 0;

      final session = await FFmpegKit.executeAsync(cmd, (_) async {});

      FFmpegKitConfig.enableStatisticsCallback((stats) {
        final t = stats.getTime();
        if (t > 0 && totalMs > 0) {
          double p = (t / totalMs).clamp(0.0, 1.0);
          if (p > lastProgress + 0.01) {
            lastProgress = p;
            args.onProgress?.call(p);
          }
        }
      });

      final returnCode = await session.getReturnCode();
      args.onProgress?.call(1.0);

      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        Log.error('FfmpegEncoder', 'Output: $output');
        throw Exception('FFmpeg encoding failed: $returnCode');
      }
    } catch (e) {
      Log.error('FfmpegEncoder', 'FFmpeg Kit error: $e');
      rethrow;
    }
  }

  // ── FFmpeg path discovery (Windows) ──────────────────────────────────────

  Future<String?> _findFfmpeg() async {
    final customPath = appdata.settings['ffmpegPath'] as String?;
    if (customPath != null && customPath.isNotEmpty) {
      if (await File(customPath).exists()) return customPath;
    }

    try {
      final result = await Process.run('where', ['ffmpeg.exe']);
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

  // ── Command builder ───────────────────────────────────────────────────────

  String _buildCommand({
    required String inputPath,
    required String outputPath,
    required double startSec,
    required double durationSec,
  }) {
    final buf = StringBuffer();

    // Seek BEFORE input for stream copy fast-seek
    buf.write('-ss $startSec ');
    buf.write('-t $durationSec ');

    // Proxy
    if (args.proxyUrl != null && args.proxyUrl!.isNotEmpty) {
      String proxy = args.proxyUrl!;
      if (!proxy.startsWith('http://')) proxy = 'http://$proxy';
      buf.write('-http_proxy "$proxy" ');
    }

    // Input
    buf.write('-i "$inputPath" ');

    // HTTP headers (for network inputs)
    if (args.headers.isNotEmpty) {
      for (final e in args.headers.entries) {
        buf.write('-headers "${e.key}: ${e.value}" ');
      }
    }

    // ── Build shared filter chain: crop → scale ──────────────────────────
    final filterParts = <String>[];

    if (args.cropWidth != null && args.cropHeight != null) {
      final x = args.cropX ?? 0;
      final y = args.cropY ?? 0;
      filterParts.add('crop=${args.cropWidth}:${args.cropHeight}:$x:$y');
    }

    if (args.width != null || args.height != null) {
      // -2 keeps aspect ratio AND ensures even dimension (required by H.264)
      final sw = args.width ?? -2;
      final sh = args.height ?? -2;
      filterParts.add('scale=$sw:$sh:flags=lanczos');
    }

    final int effectiveFps = args.fps ?? 15;

    // ── Per-format encoding ──────────────────────────────────────────────
    switch (args.outputFormat) {
      case 'mp4':
        // quality field is used as CRF (18=high, 23=medium, 28=low)
        final crf = args.quality ?? '23';
        if (filterParts.isNotEmpty) {
          buf.write('-vf "${filterParts.join(',')}" ');
        }
        buf.write('-c:v libx264 -preset fast -crf $crf ');
        if (args.includeAudio) {
          buf.write('-c:a aac -b:a 128k ');
        } else {
          buf.write('-an ');
        }
        buf.write('-movflags +faststart ');
        break;

      case 'gif':
        // fps first, then crop/scale
        final gifFilter = ['fps=$effectiveFps', ...filterParts].join(',');
        buf.write('-vf "$gifFilter" ');
        buf.write('-gifflags +transdiff ');
        buf.write('-loop 0 ');
        break;

      case 'apng':
        // fps first, then crop/scale; NOTE: 'plays 0' = infinite loop for APNG
        final apngFilter = ['fps=$effectiveFps', ...filterParts].join(',');
        buf.write('-vf "$apngFilter" ');
        buf.write('-c:v apng ');
        buf.write('-plays 0 ');
        break;

      case 'webp':
        // quality field is 0-100 WebP quality
        final webpFilter = ['fps=$effectiveFps', ...filterParts].join(',');
        buf.write('-vf "$webpFilter" ');
        buf.write('-c:v libwebp_anim ');
        buf.write('-loop 0 ');
        final quality = args.quality ?? '75';
        buf.write('-quality $quality ');
        break;
    }

    buf.write('-y ');
    buf.write('"$outputPath"');

    return buf.toString();
  }
}
