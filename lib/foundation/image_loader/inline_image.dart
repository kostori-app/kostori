import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/log.dart';

/// 站内 base64 / `data:` 图片的转存。
///
/// base64 文本既不能直接进数据库（体积是原图的 4/3，还会被多端同步放大），
/// 也不能每次渲染都重新解码，所以统一走这里：
/// - 入站时把 base64 解码 → 压缩（WebP）→ 写进 [CacheManager] 的磁盘缓存，
///   数据库/内存里只保留 `inline:<sha1>` 这种短引用；
/// - 渲染时按引用直接读缓存文件，命中就不再解码、不再请求；
/// - 缓存被清理后（miss）由调用方决定回源一次还是显示占位图。
///
/// 引用是对**原始 data URL 字符串**做 sha1（同步可得），因此写库时可以立即
/// 替换成短引用，真正耗时的解码/压缩在后台完成。
class InlineImageStore {
  InlineImageStore._();

  /// 短引用前缀
  static const String prefix = 'inline:';

  /// 压缩后的最长边（列表封面/缩略图足够）
  static const int maxEdge = 600;

  /// 压缩质量
  static const int quality = 80;

  /// 小于该体积的图片不再重编码（缩略图/截图本来就很小的场景省一次全量编码）
  static const int _kSkipCompressBelow = 40 * 1024;

  /// 缓存有效期：一年（真正的清理交给 [CacheManager] 的容量上限）
  static const int _cacheDuration = 365 * 24 * 60 * 60 * 1000;

  /// 正在转存的引用 → 任务（同一张图并发只转存一次）
  static final Map<String, Future<void>> _pending = {};

  /// 是否是 base64 图片（`data:` 前缀，或超长且没有 scheme 的字符串）
  static bool looksLikeBase64(String url) =>
      url.startsWith('data:') ||
      (!url.contains('://') && !url.startsWith('/') && url.length > 100);

  static bool isRef(String value) => value.startsWith(prefix);

  static String cacheKeyOfRef(String ref) =>
      'inline_v1_${ref.substring(prefix.length)}';

  static String keyOfDataUrl(String dataUrl) =>
      'inline_v1_${sha1.convert(utf8.encode(dataUrl))}';

  /// data URL / 裸 base64 → 短引用（同步可得，便于写库前替换）
  static String refOf(String dataUrl) =>
      '$prefix${sha1.convert(utf8.encode(dataUrl))}';

  /// 把 base64 图片换成短引用；非 base64 字符串原样返回。
  ///
  /// [store] 为 true 时在后台完成"解码 → 压缩 → 落盘"，调用方拿到引用即可先存库。
  static String refOfBase64(String url, {bool store = true}) {
    if (!looksLikeBase64(url) || isRef(url)) return url;
    final ref = refOf(url);
    if (store) unawaited(storeBase64(url));
    return ref;
  }

  /// 转存：解码 → 压缩 → 写盘（同一引用只做一次）
  static Future<void> storeBase64(String dataUrl) {
    final ref = refOf(dataUrl);
    final key = cacheKeyOfRef(ref);
    return _pending[key] ??= _store(key, dataUrl).whenComplete(() {
      _pending.remove(key);
    });
  }

  static Future<void> _store(String key, String dataUrl) async {
    try {
      if (await CacheManager().findCache(key) != null) return;
      final bytes = decode(dataUrl);
      if (bytes == null || bytes.isEmpty) return;
      // 不是图片（解密失败/被截断的响应）就不落盘，避免把坏内容缓存一年
      if (!looksLikeImage(bytes)) {
        DebugLog.warning('InlineImageStore', 'not an image, skip caching');
        return;
      }
      await CacheManager().writeCache(
        key,
        await _compress(bytes),
        _cacheDuration,
      );
    } catch (e) {
      DebugLog.error('InlineImageStore', 'store failed: $e');
    }
  }

  /// 是否是受支持的图片字节（按魔数判断）
  static bool looksLikeImage(List<int> b) {
    bool at(int i, List<int> sig) {
      if (b.length < i + sig.length) return false;
      for (var j = 0; j < sig.length; j++) {
        if (b[i + j] != sig[j]) return false;
      }
      return true;
    }

    if (at(0, [0x89, 0x50, 0x4E, 0x47])) return true; // PNG
    if (at(0, [0xFF, 0xD8, 0xFF])) return true; // JPEG
    if (at(0, [0x47, 0x49, 0x46, 0x38])) return true; // GIF8
    if (at(0, [0x42, 0x4D])) return true; // BMP
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
      return true; // RIFF....WEBP
    }
    if (at(4, [0x66, 0x74, 0x79, 0x70])) return true; // ftyp (avif/heic)
    return false;
  }

  /// 把回源拿到的字节按短引用重新转存（缓存失效后的回填）
  static Future<void> storeRef(String ref, List<int> bytes) =>
      CacheManager().writeCache(
        cacheKeyOfRef(ref),
        Uint8List.fromList(bytes),
        _cacheDuration,
      );

  /// 读取短引用对应的字节；同一张图正在转存时会先等它完成。
  static Future<Uint8List?> read(String ref) async {
    if (!isRef(ref)) return null;
    final key = cacheKeyOfRef(ref);
    final pending = _pending[key];
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    final file = await CacheManager().findCache(key);
    if (file == null) return null;
    try {
      final bytes = await file.readAsBytes();
      // 之前缓存的坏内容（解密失败/截断）：删掉并当作 miss，下次渲染会回源重试，
      // 不用等一年缓存过期
      if (!looksLikeImage(bytes)) {
        await CacheManager().delete(key);
        return null;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// 解码 `data:` URL / 裸 base64；失败返回 null
  static Uint8List? decode(String dataUrl) {
    try {
      var raw = dataUrl.trim();
      if (raw.startsWith('data:')) {
        final comma = raw.indexOf(',');
        if (comma < 0) return null;
        raw = raw.substring(comma + 1);
      }
      // 去掉换行/空白后再解码（部分源会把 base64 折行）
      return base64Decode(raw.replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return null;
    }
  }

  /// 压缩成 WebP；本来就很小 / 平台不支持 / 无法解码时退回原字节。
  static Future<Uint8List> _compress(Uint8List bytes) async {
    if (bytes.length < _kSkipCompressBelow) return bytes;
    try {
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxEdge,
        minHeight: maxEdge,
        quality: quality,
        format: CompressFormat.webp,
      );
      return out.isNotEmpty ? out : bytes;
    } catch (e) {
      DebugLog.error('InlineImageStore', 'compress failed: $e');
      return bytes;
    }
  }
}
