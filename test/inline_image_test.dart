import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/image_loader/inline_image.dart';

/// 1x1 透明 PNG
const String _kPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';

void main() {
  group('InlineImageStore', () {
    test('识别 base64 / data URL', () {
      expect(
        InlineImageStore.looksLikeBase64('data:image/png;base64,$_kPng'),
        isTrue,
      );
      expect(InlineImageStore.looksLikeBase64('a' * 200), isTrue);
      expect(InlineImageStore.looksLikeBase64('https://a.com/b.jpg'), isFalse);
      expect(InlineImageStore.looksLikeBase64('/data/a.jpg'), isFalse);
      expect(InlineImageStore.looksLikeBase64('short'), isFalse);
    });

    test('同一个 data URL 得到同一个引用，且引用很短', () {
      final url = 'data:image/png;base64,$_kPng';
      final ref = InlineImageStore.refOf(url);
      expect(ref, startsWith(InlineImageStore.prefix));
      expect(ref.length, lessThan(80));
      expect(InlineImageStore.refOf(url), ref);
      expect(InlineImageStore.isRef(ref), isTrue);
      // 非 base64 原样返回，不会被改写
      expect(
        InlineImageStore.refOfBase64('https://a.com/b.jpg'),
        'https://a.com/b.jpg',
      );
    });

    test('looksLikeImage 只认真实图片魔数', () {
      expect(InlineImageStore.looksLikeImage(base64Decode(_kPng)), isTrue);
      expect(
        InlineImageStore.looksLikeImage([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]),
        isTrue,
      );
      expect(InlineImageStore.looksLikeImage(utf8.encode('GIF89a...')), isTrue);
      // 解密失败/HTML 错误页/截断内容 → 不当作图片
      expect(
        InlineImageStore.looksLikeImage(utf8.encode('<html>error</html>')),
        isFalse,
      );
      expect(InlineImageStore.looksLikeImage(const [1, 2, 3]), isFalse);
      expect(InlineImageStore.looksLikeImage(const []), isFalse);
    });

    test('超长 URL 的图片键不会把整串拼进去', () {
      final dataUrl = 'data:image/png;base64,$_kPng${'A' * 5000}';
      final provider = CachedImageProvider(dataUrl, sourceKey: 'demo');
      expect(provider.key.length, lessThan(120));
      // 同一 URL 稳定，同一 URL 不同源/剧集不串图
      expect(provider.key, CachedImageProvider(dataUrl, sourceKey: 'demo').key);
      expect(
        provider.key,
        isNot(CachedImageProvider(dataUrl, sourceKey: 'other').key),
      );
      // 普通 URL 保持与磁盘键同一格式（此前内存键 `url+src` 与磁盘键 `url@src`
      // 不一致，坏缓存删不掉；统一后内存键重建不影响落盘）
      expect(
        const CachedImageProvider('https://a.com/b.jpg', sourceKey: 'demo').key,
        'https://a.com/b.jpg@demo',
      );
    });

    test('解码 data URL 与裸 base64', () {
      final bytes = InlineImageStore.decode('data:image/png;base64,$_kPng');
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
      expect(InlineImageStore.decode(_kPng), bytes);
      expect(InlineImageStore.decode('not base64!!'), isNull);
    });

    test('decodeAsync 大图走后台 isolate，结果与同步解码一致', () async {
      final raw = 'A' * 300000;
      final sync = InlineImageStore.decode(raw);
      expect(sync, isNotNull);
      expect(await InlineImageStore.decodeAsync(raw), sync);
      expect(await InlineImageStore.decodeAsync('not base64!!'), isNull);
    });

    // 注意：真机/真异步环境下的落盘往返（testWidgets 是假异步，文件 IO 不会完成）
    test('转存后可读回，未转存则读不到', () async {
      final tempPath = Directory.systemTemp
          .createTempSync('kostori_inline_')
          .path;
      App.dataPath = tempPath;
      App.cachePath = tempPath;

      final url = 'data:image/png;base64,$_kPng';
      final ref = InlineImageStore.refOfBase64(url, store: false);
      // 未转存（缓存里没有）时读不到 → 调用方回源或占位
      expect(await InlineImageStore.read(ref), isNull);

      await InlineImageStore.storeBase64(url);
      final bytes = await InlineImageStore.read(ref);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
    });
  });
}
