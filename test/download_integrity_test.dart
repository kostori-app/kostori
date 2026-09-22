import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/download/download_manager.dart';

void main() {
  group('parseDownloadRange', () {
    test('206 从 Content-Range 解析区间起点与完整大小', () {
      final r = parseDownloadRange(
        status: 206,
        contentRange: 'bytes 1000-1999/2000',
        contentLength: 1000,
      );
      expect(r.start, 1000);
      expect(r.total, 2000);
    });

    test('206 首次请求起点为 0', () {
      final r = parseDownloadRange(
        status: 206,
        contentRange: 'bytes 0-1999/2000',
        contentLength: 2000,
      );
      expect(r.start, 0);
      expect(r.total, 2000);
    });

    test('206 总大小未知（*）时返回 -1', () {
      final r = parseDownloadRange(
        status: 206,
        contentRange: 'bytes 1000-1999/*',
        contentLength: 1000,
      );
      expect(r.start, 1000);
      expect(r.total, -1);
    });

    test('206 缺少或无法解析 Content-Range 时不臆测大小', () {
      expect(
        parseDownloadRange(
          status: 206,
          contentRange: null,
          contentLength: 1000,
        ),
        (start: -1, total: -1),
      );
      expect(
        parseDownloadRange(
          status: 206,
          contentRange: 'bytes',
          contentLength: 1000,
        ),
        (start: -1, total: -1),
      );
    });

    test('200 用 Content-Length 作为完整大小', () {
      final r = parseDownloadRange(
        status: 200,
        contentRange: null,
        contentLength: 2000,
      );
      expect(r.start, 0);
      expect(r.total, 2000);
    });

    test('无 Content-Length 时无法校验', () {
      expect(
        parseDownloadRange(status: 200, contentRange: null, contentLength: -1),
        (start: -1, total: -1),
      );
      expect(
        parseDownloadRange(status: 404, contentRange: null, contentLength: 100),
        (start: -1, total: -1),
      );
    });
  });

  group('isTruncatedHlsPlaylist', () {
    const head =
        '#EXTM3U\n#EXT-X-PLAYLIST-TYPE:VOD\n#EXT-X-TARGETDURATION:10\n'
        '#EXTINF:10.0,\nseg0.ts\n';

    test('VOD 缺少 ENDLIST 视为被截断', () {
      expect(isTruncatedHlsPlaylist(head), isTrue);
    });

    test('VOD 带 ENDLIST 视为完整', () {
      expect(isTruncatedHlsPlaylist('$head#EXT-X-ENDLIST\n'), isFalse);
    });

    test('写法带空格也能识别', () {
      expect(isTruncatedHlsPlaylist('#EXT-X-PLAYLIST-TYPE:  VOD\n'), isTrue);
    });

    test('直播列表（无 PLAYLIST-TYPE）不误判', () {
      expect(
        isTruncatedHlsPlaylist('#EXTM3U\n#EXTINF:10.0,\nseg0.ts\n'),
        isFalse,
      );
    });
  });
}
