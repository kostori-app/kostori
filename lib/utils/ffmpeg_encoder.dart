import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_session.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart'
    if (dart.library.io) 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:path/path.dart' as p;

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

/// 媒体文件信息（由 probe 解析）
class FfmpegMediaInfo {
  final Duration? duration;
  final int? width;
  final int? height;
  final double? fps;
  final int? videoBitrateKbps;
  final int? audioBitrateKbps;
  final String? videoCodec;
  final String? audioCodec;
  final String? format;
  final int? audioChannels;
  final int? audioSampleRate;
  final bool hasVideo;
  final bool hasAudio;

  const FfmpegMediaInfo({
    this.duration,
    this.width,
    this.height,
    this.fps,
    this.videoBitrateKbps,
    this.audioBitrateKbps,
    this.videoCodec,
    this.audioCodec,
    this.format,
    this.audioChannels,
    this.audioSampleRate,
    this.hasVideo = false,
    this.hasAudio = false,
  });

  @override
  String toString() =>
      'FfmpegMediaInfo(duration: $duration, ${width}x$height, fps: $fps, '
      'video: $videoCodec, audio: $audioCodec, format: $format)';
}

/// 完整下载参数（不重新编码，直接流复制）
class FfmpegDownloadArgs {
  final String inputUrl;
  final String outputPath;
  final Map<String, String> headers;
  final String? proxyUrl;

  /// 是否转封装格式（如下载 .ts 转为 .mp4）。null 表示保持原容器。
  final String? outputFormat;

  /// 是否保留音轨。false 时丢弃音频。
  final bool includeAudio;

  /// 是否限制只下载视频流（不包含字幕等）。
  final bool videoOnly;

  /// 网络重试次数（仅网络流）。
  final int reconnect;

  /// 超时（秒），0 表示不限制。
  final int timeoutSeconds;

  final void Function(double progress)? onProgress;

  /// 取消句柄：调用 cancel() 后 ffmpeg 进程会被终止。
  final FfmpegCancelToken? cancelToken;

  const FfmpegDownloadArgs({
    required this.inputUrl,
    required this.outputPath,
    this.headers = const {},
    this.proxyUrl,
    this.outputFormat,
    this.includeAudio = true,
    this.videoOnly = false,
    this.reconnect = 5,
    this.timeoutSeconds = 0,
    this.onProgress,
    this.cancelToken,
  });
}

/// 下载取消句柄
class FfmpegCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// 下载被取消
class FfmpegCancelledException implements Exception {
  @override
  String toString() => 'FfmpegCancelledException: download cancelled';
}

/// 图片操作参数（ffmpeg 完全支持图片处理）
class FfmpegImageArgs {
  final String inputPath;
  final String outputPath;
  final int? width;
  final int? height;
  final int? cropX;
  final int? cropY;
  final int? cropWidth;
  final int? cropHeight;
  final String? quality; // jpg 0-31(越小越好), png 0-9(越小越好), webp 0-100(越大越好)
  final String? format; // jpg / png / webp / bmp
  final double? rotateDegrees;
  final bool flipHorizontal;
  final bool flipVertical;
  final String? filter; // 额外 vf 滤镜，如 brightness=0.1:contrast=1.2
  final void Function(double progress)? onProgress;

  const FfmpegImageArgs({
    required this.inputPath,
    required this.outputPath,
    this.width,
    this.height,
    this.cropX,
    this.cropY,
    this.cropWidth,
    this.cropHeight,
    this.quality,
    this.format,
    this.rotateDegrees,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.filter,
    this.onProgress,
  });
}

/// 使用 FFmpeg 进行视频编码 / 下载 / 探测 / 图片处理
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
      await _runWindows(
        cmd,
        totalMs: args.lengthMs,
        onProgress: args.onProgress,
      );
    } else {
      await _runMobile(
        cmd,
        totalMs: args.lengthMs,
        onProgress: args.onProgress,
      );
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

  // ── 完整下载（流复制，不重编码） ──────────────────────────────────────

  static Future<void> download(FfmpegDownloadArgs args) async {
    final safeInput = args.inputUrl.replaceAll('\\', '/');
    final safeOutput = args.outputPath.replaceAll('\\', '/');

    final buf = StringBuffer();
    final isNetwork =
        args.inputUrl.startsWith('http://') ||
        args.inputUrl.startsWith('https://');

    if (args.proxyUrl != null && args.proxyUrl!.isNotEmpty && isNetwork) {
      String proxy = args.proxyUrl!;
      if (!proxy.startsWith('http://')) proxy = 'http://$proxy';
      buf.write('-http_proxy "$proxy" ');
    }

    if (args.headers.isNotEmpty && isNetwork) {
      for (final e in args.headers.entries) {
        buf.write('-headers "${e.key}: ${e.value}" ');
      }
    }

    buf.write('-y -i "$safeInput" ');

    // 网络重连
    if (args.reconnect > 0 && isNetwork) {
      buf.write(
        '-reconnect 1 -reconnect_streamed 1 '
        '-reconnect_delay_max ${args.reconnect} ',
      );
    }

    // 流复制（不重编码），保持原码率
    buf.write('-c copy ');

    if (!args.includeAudio) buf.write('-an ');
    if (args.videoOnly) {
      buf.write('-map 0:v:0 ');
    }

    if (args.outputFormat != null) {
      buf.write('-f ${args.outputFormat} ');
    }

    buf.write('"$safeOutput"');

    final cmd = buf.toString();
    Log.info('FfmpegEncoder', 'Download: $cmd');

    // 流复制无法从 stderr 解析 time，用文件大小估算进度
    if (Platform.isWindows) {
      await _runWindows(
        cmd,
        totalMs: 0,
        isDownload: true,
        outputPath: safeOutput,
        onProgress: args.onProgress,
        cancelToken: args.cancelToken,
      );
    } else {
      await _runMobile(
        cmd,
        totalMs: 0,
        isDownload: true,
        outputPath: safeOutput,
        onProgress: args.onProgress,
        cancelToken: args.cancelToken,
      );
    }
  }

  // ── 媒体探测（解析视频详情） ─────────────────────────────────────────

  /// 本地 ts 分片合并转 mp4（concat demuxer + 流复制）。
  /// 供 m3u8 分片下载后合并使用。
  static Future<void> mergeTs({
    required List<String> tsPaths,
    required String outputPath,
    FfmpegCancelToken? cancelToken,
    void Function(double progress)? onProgress,
  }) async {
    if (tsPaths.isEmpty) {
      throw Exception('没有可合并的 ts 分片');
    }
    final tmpDir = Directory.systemTemp;
    final listFile = File(
      p.join(
        tmpDir.path,
        'kostori_concat_${DateTime.now().millisecondsSinceEpoch}.txt',
      ),
    );
    final lines = tsPaths
        .map((path) => "file '${path.replaceAll("'", r"'\''")}'")
        .join('\n');
    await listFile.writeAsString(lines);

    final safeList = listFile.path.replaceAll('\\', '/');
    final safeOutput = outputPath.replaceAll('\\', '/');
    final cmd = '-y -f concat -safe 0 -i "$safeList" -c copy "$safeOutput"';

    try {
      if (Platform.isWindows) {
        await _runWindows(
          cmd,
          totalMs: 0,
          outputPath: outputPath,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      } else {
        await _runMobile(
          cmd,
          totalMs: 0,
          outputPath: outputPath,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      }
    } finally {
      try {
        await listFile.delete();
      } catch (_) {}
    }
  }

  /// 解析媒体文件/流的详细信息（时长、分辨率、编码、码率等）。
  /// 移动端走 FFprobeKit；桌面端优先 `ffprobe`，缺失时回退解析 `ffmpeg -i` 输出。
  static Future<FfmpegMediaInfo?> probe(String input) async {
    final safeInput = input.replaceAll('\\', '/');
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return await _probeDesktop(safeInput);
      }
      return await _probeMobile(safeInput);
    } catch (e) {
      Log.warning('FfmpegEncoder', 'probe failed: $e');
      return null;
    }
  }

  static Future<FfmpegMediaInfo?> _probeDesktop(String input) async {
    // 优先使用 ffprobe（JSON 输出，最可靠）
    final ffprobe = await _findFfprobe();
    if (ffprobe != null) {
      try {
        final res = await Process.run(ffprobe, [
          '-v',
          'error',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          input,
        ]);
        if (res.exitCode == 0 && res.stdout is String) {
          final info = _parseFfprobeJson(res.stdout as String);
          if (info != null) return info;
        }
      } catch (e) {
        Log.warning('FfmpegEncoder', 'ffprobe failed: $e');
      }
    }

    // 回退：ffmpeg -i 输出解析
    final ffmpeg = await _findFfmpeg();
    if (ffmpeg == null) return null;
    final res = await Process.run(ffmpeg, ['-i', input]);
    return _parseFfmpegStderr(res.stderr is String ? res.stderr as String : '');
  }

  static Future<FfmpegMediaInfo?> _probeMobile(String input) async {
    final session = await FFprobeKit.getMediaInformation(input);
    final returnCode = await session.getReturnCode();
    if (returnCode == null || !ReturnCode.isSuccess(returnCode)) {
      return null;
    }
    final media = session.getMediaInformation();
    if (media == null) return null;

    Duration? duration;
    final durationMs = media.getNumberFormatProperty('duration')?.toDouble();
    if (durationMs != null && durationMs > 0) {
      duration = Duration(microseconds: (durationMs * 1000000).round());
    }

    int? videoW, videoH, audioCh, audioSr;
    double? fps;
    int? vBitrate, aBitrate;
    String? vCodec, aCodec;
    bool hasVideo = false, hasAudio = false;

    for (final stream in media.getStreams()) {
      final s = stream;
      final type = s.getStringProperty('codec_type') ?? '';
      if (type == 'video' && !hasVideo) {
        hasVideo = true;
        videoW = s.getWidth();
        videoH = s.getHeight();
        vCodec = s.getCodec();
        final fr = s.getStringProperty('avg_frame_rate') ?? '';
        final parts = fr.split('/');
        if (parts.length == 2) {
          final num = double.tryParse(parts[0]);
          final den = double.tryParse(parts[1]);
          if (num != null && den != null && den > 0) fps = num / den;
        }
        final br = s.getStringProperty('bit_rate');
        vBitrate = br != null ? int.tryParse(br)! ~/ 1000 : null;
      } else if (type == 'audio' && !hasAudio) {
        hasAudio = true;
        aCodec = s.getCodec();
        audioCh = s.getNumberProperty('channels')?.toInt();
        audioSr = s.getNumberProperty('sample_rate')?.toInt();
        final br = s.getStringProperty('bit_rate');
        aBitrate = br != null ? int.tryParse(br)! ~/ 1000 : null;
      }
    }

    return FfmpegMediaInfo(
      duration: duration,
      width: videoW,
      height: videoH,
      fps: fps,
      videoBitrateKbps: vBitrate,
      audioBitrateKbps: aBitrate,
      videoCodec: vCodec,
      audioCodec: aCodec,
      format: media.getFormat(),
      audioChannels: audioCh,
      audioSampleRate: audioSr,
      hasVideo: hasVideo,
      hasAudio: hasAudio,
    );
  }

  static FfmpegMediaInfo? _parseFfprobeJson(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final format = data['format'] as Map<String, dynamic>?;
      final streams = data['streams'] as List? ?? [];

      Duration? duration;
      final fmtDur = format?['duration'];
      if (fmtDur is String) {
        final d = double.tryParse(fmtDur);
        if (d != null && d > 0) {
          duration = Duration(microseconds: (d * 1000000).round());
        }
      }

      int? videoW, videoH, audioCh, audioSr;
      double? fps;
      int? vBitrate, aBitrate;
      String? vCodec, aCodec, fmtName;
      bool hasVideo = false, hasAudio = false;
      fmtName = format?['format_name']?.toString();

      for (final s in streams) {
        if (s is! Map<String, dynamic>) continue;
        final type = s['codec_type']?.toString() ?? '';
        if (type == 'video' && !hasVideo) {
          hasVideo = true;
          videoW = s['width'] as int?;
          videoH = s['height'] as int?;
          vCodec = s['codec_name']?.toString();
          final fr = s['avg_frame_rate']?.toString() ?? '';
          final parts = fr.split('/');
          if (parts.length == 2) {
            final num = double.tryParse(parts[0]);
            final den = double.tryParse(parts[1]);
            if (num != null && den != null && den > 0) fps = num / den;
          }
          final br = s['bit_rate']?.toString();
          vBitrate = br != null ? int.tryParse(br)! ~/ 1000 : null;
        } else if (type == 'audio' && !hasAudio) {
          hasAudio = true;
          aCodec = s['codec_name']?.toString();
          audioCh = s['channels'] as int?;
          audioSr = s['sample_rate'] != null
              ? int.tryParse(s['sample_rate'].toString())
              : null;
          final br = s['bit_rate']?.toString();
          aBitrate = br != null ? int.tryParse(br)! ~/ 1000 : null;
        }
      }

      return FfmpegMediaInfo(
        duration: duration,
        width: videoW,
        height: videoH,
        fps: fps,
        videoBitrateKbps: vBitrate,
        audioBitrateKbps: aBitrate,
        videoCodec: vCodec,
        audioCodec: aCodec,
        format: fmtName,
        audioChannels: audioCh,
        audioSampleRate: audioSr,
        hasVideo: hasVideo,
        hasAudio: hasAudio,
      );
    } catch (e) {
      Log.warning('FfmpegEncoder', 'parse ffprobe json failed: $e');
      return null;
    }
  }

  static FfmpegMediaInfo? _parseFfmpegStderr(String stderr) {
    Duration? duration;
    int? width, height;
    double? fps;
    String? vCodec, aCodec;

    final durM = RegExp(
      r'Duration:\s*(\d+):(\d+):(\d+\.\d+)',
    ).firstMatch(stderr);
    if (durM != null) {
      try {
        duration =
            Duration(
              hours: int.parse(durM.group(1)!),
              minutes: int.parse(durM.group(2)!),
              seconds: double.parse(durM.group(3)!).toInt(),
            ) +
            Duration(
              milliseconds: (double.parse(durM.group(3)!) % 1 * 1000).round(),
            );
      } catch (_) {}
    }

    final videoM = RegExp(
      r'Stream #\d+:\d+(?:\(\w+\))?:\s*Video:\s*(\w+).*?'
      r'(\d{2,5})x(\d{2,5}).*?(?:,\s*([\d.]+)\s*fps)?',
    ).firstMatch(stderr);
    if (videoM != null) {
      vCodec = videoM.group(1);
      width = int.tryParse(videoM.group(2) ?? '');
      height = int.tryParse(videoM.group(3) ?? '');
      fps = double.tryParse(videoM.group(4) ?? '');
    }

    final audioM = RegExp(
      r'Stream #\d+:\d+(?:\(\w+\))?:\s*Audio:\s*(\w+)',
    ).firstMatch(stderr);
    if (audioM != null) {
      aCodec = audioM.group(1);
    }

    return FfmpegMediaInfo(
      duration: duration,
      width: width,
      height: height,
      fps: fps,
      videoCodec: vCodec,
      audioCodec: aCodec,
      hasVideo: videoM != null,
      hasAudio: audioM != null,
    );
  }

  // ── 图片处理 ─────────────────────────────────────────────────────────

  /// 对图片执行缩放/裁剪/旋转/翻转/格式转换等操作。
  /// ffmpeg 完全支持图片处理，功能与专业图片工具一致。
  static Future<void> processImage(FfmpegImageArgs args) async {
    final safeInput = args.inputPath.replaceAll('\\', '/');
    final safeOutput = args.outputPath.replaceAll('\\', '/');

    final buf = StringBuffer();
    buf.write('-y -i "$safeInput" ');

    final filterParts = <String>[];
    if (args.cropWidth != null && args.cropHeight != null) {
      filterParts.add(
        'crop=${args.cropWidth}:${args.cropHeight}:${args.cropX ?? 0}:${args.cropY ?? 0}',
      );
    }
    if (args.width != null || args.height != null) {
      final sw = args.width ?? -2;
      final sh = args.height ?? -2;
      filterParts.add('scale=$sw:$sh:flags=lanczos');
    }
    if (args.rotateDegrees != null && args.rotateDegrees != 0) {
      filterParts.add('rotate=${args.rotateDegrees}');
    }
    if (args.flipHorizontal) filterParts.add('hflip');
    if (args.flipVertical) filterParts.add('vflip');
    if (args.filter != null && args.filter!.isNotEmpty) {
      filterParts.add(args.filter!);
    }
    if (filterParts.isNotEmpty) {
      buf.write('-vf "${filterParts.join(',')}" ');
    }

    final format = args.format?.toLowerCase() ?? '';
    switch (format) {
      case 'png':
        buf.write('-c:v png ');
        if (args.quality != null) {
          buf.write('-compression_level ${args.quality} ');
        }
        break;
      case 'webp':
        buf.write('-c:v libwebp ');
        if (args.quality != null) {
          buf.write('-quality ${args.quality} ');
        }
        break;
      case 'bmp':
        buf.write('-c:v bmp ');
        break;
      case 'jpg':
      case 'jpeg':
      default:
        buf.write('-c:v mjpeg ');
        if (args.quality != null) {
          buf.write('-q:v ${args.quality} ');
        }
        break;
    }

    buf.write('"$safeOutput"');

    final cmd = buf.toString();
    Log.info('FfmpegEncoder', 'Image: $cmd');

    if (Platform.isWindows) {
      await _runWindows(cmd, totalMs: 0, onProgress: args.onProgress);
    } else {
      await _runMobile(cmd, totalMs: 0, onProgress: args.onProgress);
    }
  }

  // ── 执行器 ──────────────────────────────────────────────────────────

  static Future<String?> _findFfmpeg() async {
    final customPath = appdata.implicitData['ffmpegPath'] as String?;
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

  static Future<String?> _findFfprobe() async {
    try {
      final result = await Process.run('where', ['ffprobe.exe']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim().split('\n').first.trim();
      }
    } catch (_) {}

    for (final p in [
      'C:\\ffmpeg\\bin\\ffprobe.exe',
      'C:\\Program Files\\ffmpeg\\bin\\ffprobe.exe',
      'C:\\Program Files (x86)\\ffmpeg\\bin\\ffprobe.exe',
      '/usr/bin/ffprobe',
      '/usr/local/bin/ffprobe',
    ]) {
      if (await File(p).exists()) return p;
    }
    return null;
  }

  /// 桌面端执行。下载模式（无 time 输出）用文件大小估算进度。
  static Future<void> _runWindows(
    String cmd, {
    required int totalMs,
    bool isDownload = false,
    String? outputPath,
    void Function(double progress)? onProgress,
    FfmpegCancelToken? cancelToken,
  }) async {
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

    // 取消检查：定时探测取消句柄，命中则终止进程
    Timer? cancelTimer;
    if (cancelToken != null) {
      cancelTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (cancelToken.isCancelled) {
          process.kill();
        }
      });
    }

    double lastProgress = 0;
    int lastSize = 0;
    final stderrBuffer = StringBuffer();

    void report(double p) {
      if (p > lastProgress + 0.01) {
        lastProgress = p;
        onProgress?.call(p);
      }
    }

    // 下载模式：监控输出文件大小（时间戳输出可能不存在）
    Timer? sizeTimer;
    if (isDownload && outputPath != null) {
      sizeTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        final f = File(outputPath);
        if (!await f.exists()) return;
        final size = await f.length();
        if (size > lastSize) {
          lastSize = size;
          // 没有总时长信息，仅标记已产出数据
          report(lastProgress);
        }
      });
    }

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
          if (totalMs > 0) {
            double p = (currentMs / totalMs).clamp(0.0, 1.0);
            report(p);
          }
        } catch (_) {}
      }
    });

    final exitCode = await process.exitCode;
    cancelTimer?.cancel();
    sizeTimer?.cancel();
    if (cancelToken != null && cancelToken.isCancelled) {
      throw FfmpegCancelledException();
    }
    onProgress?.call(1.0);
    if (exitCode != 0) {
      throw Exception(
        'FFmpeg exited with code: $exitCode. Stderr: $stderrBuffer',
      );
    }
  }

  /// 移动端执行。
  static Future<void> _runMobile(
    String cmd, {
    required int totalMs,
    bool isDownload = false,
    String? outputPath,
    void Function(double progress)? onProgress,
    FfmpegCancelToken? cancelToken,
  }) async {
    Log.info('FfmpegEncoder', 'Mobile FFmpeg command: $cmd');

    double lastProgress = 0;

    FFmpegKitConfig.enableStatisticsCallback((stats) {
      final t = stats.getTime();
      if (t > 0 && totalMs > 0) {
        double p = (t / totalMs).clamp(0.0, 1.0);
        if (p > lastProgress + 0.01) {
          lastProgress = p;
          onProgress?.call(p);
        }
      }
    });

    final completer = Completer<void>();
    FFmpegSession? completedSession;

    try {
      final session = await FFmpegKit.executeAsync(
        cmd,
        (session) async {
          completedSession = session;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        (log) {},
        (stats) {
          final t = stats.getTime();
          if (t > 0 && totalMs > 0) {
            double p = (t / totalMs).clamp(0.0, 1.0);
            if (p > lastProgress + 0.01) {
              lastProgress = p;
              onProgress?.call(p);
            }
          }
        },
      );

      final timeout = Duration(seconds: 300);
      // 取消检查：定时探测，命中则取消 ffmpeg session
      Timer? cancelTimer;
      if (cancelToken != null) {
        cancelTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
          if (cancelToken.isCancelled) {
            session.cancel();
          }
        });
      }
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          session.cancel();
          throw Exception(
            'FFmpeg encoding timed out after ${timeout.inSeconds} seconds',
          );
        },
      );
      cancelTimer?.cancel();

      if (cancelToken != null && cancelToken.isCancelled) {
        throw FfmpegCancelledException();
      }

      onProgress?.call(1.0);

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
