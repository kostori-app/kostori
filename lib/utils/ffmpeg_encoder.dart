import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_session.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
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
  final String? quality;
  final int? fps;
  final bool includeAudio;

  /// MP4 固定码率 (kbps)。设置后忽略 [quality] (CRF)，改用 -b:v 模式。
  /// 用于极低码率场景（e.g. 200 kbps）。
  final int? videoBitrateKbps;

  /// GIF 调色板最大颜色数 (2–256)。越少体积越小，质量越低。默认 128。
  final int gifColors;

  /// GIF 是否启用抖动 (dithering)。关闭后色块更明显但体积更小。
  final bool gifDither;

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
    this.videoBitrateKbps,
    this.gifColors = 128,
    this.gifDither = true,
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

  Future<void> _encodeWindows(String cmd) async {
    final ffmpegPath = await _findFfmpeg();
    if (ffmpegPath == null) {
      throw Exception(
        'FFmpeg not found. Please install FFmpeg and add to PATH, '
        'or set a custom path in Settings.',
      );
    }
    Log.info('FfmpegEncoder', 'Using FFmpeg at: $ffmpegPath');

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
    final stderrBuffer = StringBuffer();

    process.stderr.transform(const SystemEncoding().decoder).listen((data) {
      stderrBuffer.write(data);
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
    if (exitCode != 0) {
      throw Exception(
        'FFmpeg exited with code: $exitCode. Stderr: $stderrBuffer',
      );
    }
  }

  Future<void> _encodeMobile(String cmd) async {
    Log.info('FfmpegEncoder', 'Mobile FFmpeg command: $cmd');

    final totalMs = args.lengthMs;
    double lastProgress = 0;

    // Enable statistics callback before starting
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

    final completer = Completer<void>();
    FFmpegSession? completedSession;

    try {
      final session = await FFmpegKit.executeAsync(
        cmd,
        (session) async {
          // Session complete callback
          completedSession = session;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        (log) {},
        (stats) {
          // Statistics callback
          final t = stats.getTime();
          if (t > 0 && totalMs > 0) {
            double p = (t / totalMs).clamp(0.0, 1.0);
            if (p > lastProgress + 0.01) {
              lastProgress = p;
              args.onProgress?.call(p);
            }
          }
        },
      );

      final timeout = Duration(seconds: 300);
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          session.cancel();
          throw Exception(
            'FFmpeg encoding timed out after ${timeout.inSeconds} seconds',
          );
        },
      );

      args.onProgress?.call(1.0);

      final returnCode = await completedSession!.getReturnCode();
      final output = await completedSession!.getOutput();
      final allLogs = await completedSession!.getAllLogsAsString();

      if (returnCode == null) {
        Log.error('FfmpegEncoder', 'Return code is null');
        Log.error('FfmpegEncoder', 'Output: $output');
        Log.error('FfmpegEncoder', 'All logs: $allLogs');
        throw Exception(
          'FFmpeg encoding failed: return code is null. '
          'Command: $cmd. '
          'Output: $output. '
          'Logs: $allLogs',
        );
      }

      if (!ReturnCode.isSuccess(returnCode)) {
        Log.error('FfmpegEncoder', 'Return code: $returnCode');
        Log.error('FfmpegEncoder', 'Output: $output');
        Log.error('FfmpegEncoder', 'All logs: $allLogs');
        throw Exception(
          'FFmpeg encoding failed: $returnCode. '
          'Command: $cmd. '
          'Output: $output. '
          'Logs: $allLogs',
        );
      }
    } catch (e) {
      Log.error('FfmpegEncoder', 'FFmpeg Kit error: $e');
      rethrow;
    }
  }

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

  String _buildCommand({
    required String inputPath,
    required String outputPath,
    required double startSec,
    required double durationSec,
  }) {
    final buf = StringBuffer();

    if (args.proxyUrl != null &&
        args.proxyUrl!.isNotEmpty &&
        (args.inputUrl.startsWith('http://') ||
            args.inputUrl.startsWith('https://'))) {
      String proxy = args.proxyUrl!;
      if (!proxy.startsWith('http://')) proxy = 'http://$proxy';
      buf.write('-http_proxy "$proxy" ');
    }

    if (args.headers.isNotEmpty &&
        (args.inputUrl.startsWith('http://') ||
            args.inputUrl.startsWith('https://'))) {
      for (final e in args.headers.entries) {
        buf.write('-headers "${e.key}: ${e.value}" ');
      }
    }

    final roughSec = (startSec - 5).clamp(0.0, startSec);
    buf.write('-ss $roughSec ');
    buf.write('-i "$inputPath" ');

    buf.write('-ss ${startSec - roughSec} ');
    buf.write('-t $durationSec ');

    final filterParts = <String>[];

    if (args.cropWidth != null && args.cropHeight != null) {
      final x = args.cropX ?? 0;
      final y = args.cropY ?? 0;
      filterParts.add('crop=${args.cropWidth}:${args.cropHeight}:$x:$y');
    }

    if (args.width != null || args.height != null) {
      final sw = args.width ?? -2;
      final sh = args.height ?? -2;
      filterParts.add('scale=$sw:$sh:flags=lanczos');
    }

    final int effectiveFps = args.fps ?? 15;

    switch (args.outputFormat) {
      case 'mp4':
        if (filterParts.isNotEmpty) {
          buf.write('-vf "${filterParts.join(',')}" ');
        }
        buf.write('-c:v libx264 ');
        buf.write('-preset fast ');
        if (args.videoBitrateKbps != null) {
          buf.write('-b:v ${args.videoBitrateKbps}k ');
          buf.write('-maxrate ${(args.videoBitrateKbps! * 1.5).round()}k ');
          buf.write('-bufsize ${args.videoBitrateKbps! * 2}k ');
        } else {
          final crf = args.quality ?? '23';
          buf.write('-crf $crf ');
        }
        if (args.includeAudio) {
          buf.write('-c:a aac -b:a 128k ');
        } else {
          buf.write('-an ');
        }
        buf.write('-movflags +faststart ');
        break;

      case 'gif':
        final gifScale = ['fps=$effectiveFps', ...filterParts].join(',');
        final maxColors = args.gifColors.clamp(2, 256);
        final dither = args.gifDither ? 'sierra2_4a' : 'none';
        buf.write(
          '-vf "$gifScale,split[s0][s1];'
          '[s0]palettegen=max_colors=$maxColors:reserve_transparent=0[p];'
          '[s1][p]paletteuse=dither=$dither" ',
        );
        buf.write('-loop 0 ');
        break;

      case 'apng':
        final apngFilter = ['fps=$effectiveFps', ...filterParts].join(',');
        buf.write('-vf "$apngFilter" ');
        buf.write('-c:v apng ');
        buf.write('-plays 0 ');
        break;

      case 'webp':
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
