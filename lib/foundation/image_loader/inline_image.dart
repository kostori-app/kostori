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
      await CacheManager().writeCache(
        key,
        await _compress(bytes),
        _cacheDuration,
      );
    } catch (e) {
      DebugLog.error('InlineImageStore', 'store failed: $e');
    }
  }

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
      return await file.readAsBytes();
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

  /// 压缩成 WebP；平台不支持或图片本身不可解码时退回原字节。
  static Future<Uint8List> _compress(Uint8List bytes) async {
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
