import 'dart:async' show Future, StreamController, scheduleMicrotask;
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui show Codec;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/log.dart';

abstract class BaseImageProvider<T extends BaseImageProvider<T>>
    extends ImageProvider<T> {
  const BaseImageProvider();

  /// 1×1 透明 PNG，解码失败/空响应体（非图片/损坏数据）时作为占位返回，
  /// 避免反复抛 Invalid image data / Empty response body
  static final Uint8List kTransparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  static double? _effectiveScreenWidth;

  static const double _normalAnimeImageRatio = 0.72;

  static const double _minAnimeImageWidth = 1920 * _normalAnimeImageRatio;

  static TargetImageSize _getTargetSize(int? width, int? height) {
    if (_effectiveScreenWidth == null) {
      final screens = PlatformDispatcher.instance.displays;
      for (var screen in screens) {
        if (screen.size.width > screen.size.height) {
          _effectiveScreenWidth = max(
            _effectiveScreenWidth ?? 0,
            screen.size.height * _normalAnimeImageRatio,
          );
        } else {
          _effectiveScreenWidth = max(
            _effectiveScreenWidth ?? 0,
            screen.size.width,
          );
        }
      }
      if (_effectiveScreenWidth! < _minAnimeImageWidth) {
        _effectiveScreenWidth = _minAnimeImageWidth;
      }
    }
    // 宽高缺失时返回原值，避免空指针崩溃
    if (width == null || height == null || width <= 0 || height <= 0) {
      return TargetImageSize(width: width ?? 0, height: height ?? 0);
    }
    if (width > _effectiveScreenWidth!) {
      height = (height * _effectiveScreenWidth! / width).round();
      width = _effectiveScreenWidth!.round();
    }
    return TargetImageSize(width: width, height: height);
  }

  @override
  ImageStreamCompleter loadImage(T key, ImageDecoderCallback decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _loadBufferAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>(
          'Image provider: $this \n Image key: $key',
          this,
          style: DiagnosticsTreeStyle.errorProperty,
        );
      },
    );
  }

  Future<ui.Codec> _loadBufferAsync(
    T key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    try {
      int retryTime = 1;

      bool stop = false;

      chunkEvents.onCancel = () {
        stop = true;
      };

      Uint8List? data;

      while (data == null && !stop) {
        try {
          data = await load(chunkEvents, () {
            if (stop) {
              throw const _ImageLoadingStopException();
            }
          });
        } on _ImageLoadingStopException {
          rethrow;
        } catch (e) {
          final msg = e.toString();
          if (msg.contains("Invalid Status Code: 404")) {
            rethrow;
          }
          if (msg.contains("Invalid Status Code: 403")) {
            rethrow;
          }
          // 网络层不可达（连接超时/拒绝/重置/DNS 失败）时重试没有意义，
          // 直接失败显示占位，避免"无法访问的图片卡很久"
          final lower = msg.toLowerCase();
          if (lower.contains('timeout') ||
              lower.contains('socketexception') ||
              lower.contains('connection refused') ||
              lower.contains('failed to connect') ||
              lower.contains('connection reset') ||
              lower.contains('network is unreachable') ||
              lower.contains('hostlookup')) {
            rethrow;
          }
          if (msg.contains("handshake")) {
            if (retryTime < 5) {
              retryTime = 5;
            }
          }
          retryTime <<= 1;
          if (retryTime > (1 << 3) || stop) {
            rethrow;
          }
          await Future.delayed(Duration(seconds: retryTime));
        }
      }

      if (stop) {
        throw const _ImageLoadingStopException();
      }

      if (data!.isEmpty) {
        throw Exception("Empty image data");
      }

      try {
        final buffer = await ImmutableBuffer.fromUint8List(data);
        return await decode(
          buffer,
          getTargetSize: enableResize ? _getTargetSize : null,
        );
      } catch (e) {
        await CacheManager().delete(this.key);
        if (data.length < 2 * 1024) {
          // data is too short, it's likely that the data is text, not image
          try {
            var text = const Utf8Codec(
              allowMalformed: false,
            ).decoder.convert(data);
            throw Exception("Expected image data, but got text: $text");
          } catch (e) {
            // ignore
          }
        }
        // 非图片/损坏数据：返回 1×1 透明占位，避免 Invalid image data 刷屏
        try {
          final fallback = await ImmutableBuffer.fromUint8List(
            kTransparentPng,
          );
          return await decode(fallback);
        } catch (_) {
          rethrow;
        }
      }
    } on _ImageLoadingStopException {
      rethrow;
    } catch (e, s) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      final msg = e.toString();
      if (!msg.contains('404') && !msg.contains('403')) {
        DebugLog.error("Image Loading", e, s);
      }
      rethrow;
    } finally {
      chunkEvents.close();
    }
  }

  Future<Uint8List> load(
    StreamController<ImageChunkEvent> chunkEvents,
    void Function() checkStop,
  );

  String get key;

  @override
  bool operator ==(Object other) {
    return other is BaseImageProvider<T> && key == other.key;
  }

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() {
    return "$runtimeType($key)";
  }

  bool get enableResize => false;
}

typedef FileDecoderCallback = Future<ui.Codec> Function(Uint8List);

class _ImageLoadingStopException implements Exception {
  const _ImageLoadingStopException();
}

class Base64ImageProvider extends BaseImageProvider<Base64ImageProvider> {
  const Base64ImageProvider(this.base64String);

  final String base64String;

  @override
  String get key => base64String.substring(0, min(64, base64String.length));

  @override
  Future<Uint8List> load(
    StreamController<ImageChunkEvent> chunkEvents,
    void Function() checkStop,
  ) async {
    checkStop();

    var raw = base64String;
    if (raw.contains(',')) {
      raw = raw.split(',').last;
    }

    final bytes = base64Decode(raw);
    chunkEvents.add(
      ImageChunkEvent(
        cumulativeBytesLoaded: bytes.length,
        expectedTotalBytes: bytes.length,
      ),
    );
    return bytes;
  }

  @override
  bool operator ==(Object other) =>
      other is Base64ImageProvider && base64String == other.base64String;

  @override
  int get hashCode => base64String.hashCode;

  @override
  Future<Base64ImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }
}
