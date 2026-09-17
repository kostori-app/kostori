import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/video_probe.dart';

void main() {
  group('classifyVideoUrl', () {
    test('通过响应头识别', () {
      expect(
        classifyVideoUrl(
          url: 'https://example.com/index',
          contentType: 'application/vnd.apple.mpegurl',
        ),
        VideoUrlKind.hls,
      );
      expect(
        classifyVideoUrl(
          url: 'https://example.com/index',
          contentType: 'application/dash+xml',
        ),
        VideoUrlKind.dash,
      );
      expect(
        classifyVideoUrl(
          url: 'https://example.com/a',
          contentType: 'video/mp4',
        ),
        VideoUrlKind.mp4,
      );
      expect(
        classifyVideoUrl(
          url: 'https://example.com/a',
          contentType: 'image/jpeg',
        ),
        VideoUrlKind.image,
      );
      expect(
        classifyVideoUrl(
          url: 'https://example.com/a',
          contentType: 'text/html; charset=utf-8',
        ),
        VideoUrlKind.html,
      );
    });

    test('通过响应体识别', () {
      expect(
        classifyVideoUrl(
          url: 'https://example.com/x',
          sample: Uint8List.fromList(utf8.encode('#EXTM3U\n#EXT-X-VERSION:3')),
        ),
        VideoUrlKind.hls,
      );
      expect(
        classifyVideoUrl(
          url: 'https://example.com/x',
          sample: Uint8List.fromList(utf8.encode('<?xml?><MPD></MPD>')),
        ),
        VideoUrlKind.dash,
      );
      final mp4 = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x18,
        ...utf8.encode('ftypisom'),
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
      expect(
        classifyVideoUrl(url: 'https://example.com/x', sample: mp4),
        VideoUrlKind.mp4,
      );
      final html = Uint8List.fromList(
        utf8.encode('<!DOCTYPE html><html><body>blocked</body></html>'),
      );
      expect(
        classifyVideoUrl(url: 'https://example.com/x', sample: html),
        VideoUrlKind.html,
      );
    });

    test('通过扩展名兜底', () {
      expect(
        classifyVideoUrl(url: 'https://example.com/live/index.m3u8?t=1'),
        VideoUrlKind.hls,
      );
      expect(
        classifyVideoUrl(url: 'https://example.com/v/1080.mp4'),
        VideoUrlKind.mp4,
      );
      expect(
        classifyVideoUrl(url: 'https://example.com/a.mp3'),
        VideoUrlKind.audio,
      );
      expect(
        classifyVideoUrl(url: 'https://example.com/stream.flv'),
        VideoUrlKind.flv,
      );
      expect(
        classifyVideoUrl(url: 'https://example.com/x.bin'),
        VideoUrlKind.unknown,
      );
    });

    test('可播放 / 播放列表判定', () {
      expect(VideoUrlKind.hls.playable, isTrue);
      expect(VideoUrlKind.hls.playlist, isTrue);
      expect(VideoUrlKind.mp4.playable, isTrue);
      expect(VideoUrlKind.mp4.playlist, isFalse);
      expect(VideoUrlKind.html.playable, isFalse);
      expect(VideoUrlKind.image.playable, isFalse);
    });
  });

  group('VideoProbeResult', () {
    test('可达性与大小展示', () {
      const ok = VideoProbeResult(
        url: 'https://example.com/a.m3u8',
        statusCode: 200,
        statusMessage: 'OK',
        contentLength: 2048,
        elapsedMs: 12,
        acceptRanges: 'bytes',
        kind: VideoUrlKind.hls,
      );
      expect(ok.reachable, isTrue);
      expect(ok.ok, isTrue);
      expect(ok.supportsRange, isTrue);
      expect(ok.looksLikeHtml, isFalse);
      expect(ok.sizeLabel, '2.0 KB');

      const failed = VideoProbeResult(url: 'x', error: 'connection refused');
      expect(failed.reachable, isFalse);
      expect(failed.ok, isFalse);
      expect(failed.sizeLabel, '-');
    });

    test('空样本不产生预览', () {
      const empty = VideoProbeResult(url: 'https://example.com/a');
      expect(empty.textPreview, isEmpty);
    });
  });
}
