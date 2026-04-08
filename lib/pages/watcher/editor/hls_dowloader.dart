part of 'video_clip_editor.dart';

class _HlsDownloader {
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

      final rootResp = await dio.get<String>(
        url,
        options: Options(headers: headers, responseType: ResponseType.plain),
      );
      String content = rootResp.data ?? '';

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

      final segBase = _baseOf(targetUrl);
      final playlistLines = content.split('\n');

      final allSegs = <({String url, int durationMs})>[];
      double pendingDurSec = 0;
      for (final line in playlistLines) {
        final l = line.trim();
        if (l.startsWith('#EXTINF:')) {
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

      int cursor = 0;
      int firstIdx = 0;
      int lastIdx = allSegs.length - 1;
      bool foundFirst = false;
      for (int i = 0; i < allSegs.length; i++) {
        final segEnd = cursor + allSegs[i].durationMs;
        if (!foundFirst && segEnd > startMs) {
          firstIdx = (i - 1).clamp(0, allSegs.length - 1);
          foundFirst = true;
        }
        if (cursor >= endMs) {
          lastIdx = (i + 1).clamp(0, allSegs.length - 1);
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

      final tempDir = await getTemporaryDirectory();
      final sessionId = DateTime.now().millisecondsSinceEpoch;
      final segDir = Directory('${tempDir.path}/kostori_hls_$sessionId');
      await segDir.create(recursive: true);

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

      final mergedPath = '${segDir.path}/merged.ts';
      final mergedFile = File(mergedPath);
      final sink = mergedFile.openWrite();
      for (int i = 0; i < needed.length; i++) {
        final tsPath = '${segDir.path}/seg_${i.toString().padLeft(6, '0')}.ts';
        final tsFile = File(tsPath);
        if (await tsFile.exists()) {
          final data = await tsFile.readAsBytes();
          sink.add(data);
          await tsFile.delete();
        }
      }
      await sink.close();

      return mergedPath;
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
