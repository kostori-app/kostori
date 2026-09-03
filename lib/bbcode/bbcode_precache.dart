import 'package:flutter/material.dart';
import 'package:kostori/bbcode/bbcode_base_listener.dart';
import 'package:kostori/bbcode/bbcode_elements.dart';
import 'package:kostori/bbcode/generated/BBCodeLexer.dart';
import 'package:kostori/bbcode/generated/BBCodeParser.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:antlr4/antlr4.dart';

/// 解析 BBCode 正文，提取其中的完整图片 URL（与 BBCodeWidget 渲染用同一套逻辑）。
List<String> extractBangumiImageUrls(String bbcode) {
  final urls = <String>{};
  if (bbcode.isEmpty) return urls.toList();
  try {
    BBCodeParser.checkVersion();
    final input = InputStream.fromString(bbcode);
    final lexer = BBCodeLexer(input);
    final tokens = CommonTokenStream(lexer);
    final parser = BBCodeParser(tokens);
    final tree = parser.document();
    final listener = BBCodeBaseListener();
    ParseTreeWalker.DEFAULT.walk(listener, tree);
    for (final e in listener.bbcode) {
      if (e is BBCodeImg) {
        final raw = e.imageUrl;
        urls.add(
          raw.startsWith('http') ? raw : 'https://lain.bgm.tv/pic/photo/g/$raw',
        );
      }
    }
  } catch (_) {
    // 解析失败不阻塞正文渲染
  }
  return urls.toList();
}

/// 页面级图片缓存保持：进入页面后预加载图片，使其在页面生命周期内保持缓存
/// （不因滚动离开视口被 ImageCache 回收而反复重解码）；页面退出时释放。
///
/// 注意：必须用 CachedImageProvider（走统一图片加载：代理/headers/磁盘缓存），
/// 裸 NetworkImage 会用原生 HttpClient 直连，绕过代理导致加载失败。
class BangumiPageImageCache {
  BangumiPageImageCache();

  final List<ImageProvider> _providers = [];
  bool _disposed = false;

  /// 保持的图片数量上限：触底加载无限增长时，超出部分释放最旧，
  /// 避免滑多了保持几百张图导致内存/缓存膨胀卡顿。
  static const int _maxKeep = 100;

  /// 预加载图片。已预加载过 / 已销毁时忽略。
  /// [cacheWidth] 与卡片显示一致时（ResizeImage 包装）ImageCache key 才匹配，
  /// 否则预加载的图无法被显示复用。
  void precache(
    BuildContext context,
    String url, {
    String? sourceKey,
    int? cacheWidth,
  }) {
    if (_disposed || url.isEmpty) return;
    final base = CachedImageProvider(url, sourceKey: sourceKey);
    final ImageProvider provider = cacheWidth != null && cacheWidth > 0
        ? ResizeImage.resizeIfNeeded(cacheWidth, null, base)
        : base;
    final existing = _providers.any(
      (p) =>
          p == provider ||
          (p is ResizeImage &&
              p.imageProvider is CachedImageProvider &&
              (p.imageProvider as CachedImageProvider).url == url &&
              (p.imageProvider as CachedImageProvider).sourceKey == sourceKey &&
              p.width == cacheWidth),
    );
    if (existing) return;
    _providers.add(provider);
    // 预加载到 ImageCache；返回的 ImageStream 由 ImageCache 持有，
    // provider 也由本类持有，防止滚动离开视口后被回收
    precacheImage(provider, context);
    // 超出上限：释放最旧的保持，避免无限累积
    while (_providers.length > _maxKeep) {
      final oldest = _providers.removeAt(0);
      try {
        PaintingBinding.instance.imageCache.evict(oldest);
      } catch (_) {}
    }
  }

  /// 批量预加载
  void precacheAll(
    BuildContext context,
    Iterable<String> urls, {
    String? sourceKey,
    int? cacheWidth,
  }) {
    for (final url in urls) {
      precache(context, url, sourceKey: sourceKey, cacheWidth: cacheWidth);
    }
  }

  /// 页面退出：释放保持的缓存，允许回收
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final p in _providers) {
      try {
        PaintingBinding.instance.imageCache.evict(p);
      } catch (_) {}
    }
    _providers.clear();
  }
}
