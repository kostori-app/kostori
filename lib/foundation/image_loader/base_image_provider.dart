import 'dart:async' show Completer, Future, StreamController, scheduleMicrotask;
import 'dart:collection' show Queue;
import 'dart:convert';
import 'dart:math' show max;
import 'dart:ui' as ui show Codec;
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/cache_manager.dart';
import 'package:kostori/foundation/log.dart';

/// 图片缓存键：与磁盘缓存/去重共用同一格式（改格式会使已落盘的旧键变孤儿，
/// 故短串分支保持原样）；超长文本（base64 data URL）用 sha1 + 长度代替
/// Dart `hashCode`（进程随机种子、跨重启失效、32 位易碰撞）。
String imageCacheKey(String url, String? sourceKey, [String? aid]) {
  final tail = '@$sourceKey${aid != null ? '@$aid' : ''}';
  if (url.length <= 512) return '$url$tail';
  return 'long:${sha1.convert(utf8.encode(url))}x${url.length}$tail';
}

/// 图片加载失败日志节流：同一 key 10 分钟内只记一次，且不带堆栈。
/// 坏图（如源返回的一批失效地址）否则会把控制台刷爆。
final Map<String, int> _imageErrorLoggedAt = {};

void _logImageError(String key, Object error) {
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - (_imageErrorLoggedAt[key] ?? 0) < 10 * 60 * 1000) return;
  if (_imageErrorLoggedAt.length > 1000) _imageErrorLoggedAt.clear();
  _imageErrorLoggedAt[key] = now;
  // 只留错误首行（地址 + 简短原因），不带堆栈
  final detail = error.toString().split('\n').first;
  DebugLog.error('Image Loading', '$key\n$detail');
}

abstract class BaseImageProvider<T extends BaseImageProvider<T>>
    extends ImageProvider<T> {
  const BaseImageProvider();

  /// 1×1 透明 PNG，解码失败/空响应体（非图片/损坏数据）时作为占位返回，
  /// 避免反复抛 Invalid image data / Empty response body
  static final Uint8List kTransparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  static double? _effectiveScreenWidth;

  /// 同时解码的图片数量上限（见 `_loadBufferAsync`：load 之后 decode 之前
  /// 没有别的闸门，缓存命中时会一批一起解码）。
  static final AsyncGate _decodeGate = AsyncGate(4);

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
        final sw = kReleaseMode ? null : (Stopwatch()..start());
        // 解码单独限流：load() 返回后槽位就释放了，缓存命中时一批图会在几毫秒内
        // 全部过闸，几十个 decode 同时跑会让 raster 尖峰（上百 ms 的长帧）。
        // 排队与起解前都检查 stop：滚出屏幕的图片直接让槽，不占解码资源。
        await _decodeGate.acquire(() {
          if (stop) throw const _ImageLoadingStopException();
        });
        late ui.Codec codec;
        try {
          if (stop) throw const _ImageLoadingStopException();
          final buffer = await ImmutableBuffer.fromUint8List(data);
          codec = await decode(
            buffer,
            getTargetSize: enableResize ? _getTargetSize : null,
          );
        } finally {
          _decodeGate.release();
        }
        if (sw != null && sw.elapsedMilliseconds >= 200) {
          DebugLog.warning(
            'ImagePerf',
            'decode ${sw.elapsedMilliseconds}ms (${data.length} B) $key',
          );
        }
        return codec;
      } catch (e) {
        // 坏字节的落盘键与内存键不在同一命名空间（如下游下载键），删 this.key
        // 删不掉，各子类通过 purgeBadCache 按写时的键清理
        await purgeBadCache();
        if (data.length < 2 * 1024) {
          // data is too short, it's likely that the data is text, not image
          try {
            var text = const Utf8Codec(allowMalformed: false).decoder
                .convert(data);
            throw Exception("Expected image data, but got text: $text");
          } catch (e) {
            // ignore
          }
        }
        // 非图片/损坏数据：返回 1×1 透明占位，避免 Invalid image data 刷屏
        try {
          final fallback = await ImmutableBuffer.fromUint8List(kTransparentPng);
          return await decode(fallback);
        } catch (_) {
          rethrow;
        }
      }
    } on _ImageLoadingStopException {
      rethrow;
    } catch (e) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      final msg = e.toString();
      if (!msg.contains('404') && !msg.contains('403')) {
        _logImageError(key.key, e);
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

  /// 解码失败时清理坏缓存：默认删内存键；数据实际落盘在别处的子类覆写
  ///（如下游 `ImageDownloader` 的磁盘键、本地文件），否则坏字节一直命中。
  Future<void> purgeBadCache() => CacheManager().delete(key);

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

  /// 此前只取前 64 字符（基本全是 `data:image/…;base64,` 前缀），不同图片
  /// 同键会导致 ImageCache 串图；改用全串短哈希（const 构造器下每次现算，
  /// 调用处是小图，sha1 开销可忽略）。
  @override
  String get key => imageCacheKey(base64String, null);

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

/// 简单的异步信号量（FIFO）：最多 [max] 个并发，释放时只唤醒队首一个。
///
/// 不轮询、不用定时器：等待者由 [release] 唤醒，醒来后再调一次 [checkStop]
/// 判断是否已被取消（滚出屏幕），是则立刻把槽位让给下一个，不泄漏。
class AsyncGate {
  AsyncGate(this.max);

  final int max;

  int _active = 0;

  final Queue<Completer<void>> _waiters = Queue();

  Future<void> acquire(void Function() checkStop) async {
    checkStop();
    if (_active < max) {
      _active++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
    try {
      checkStop();
    } catch (_) {
      // 排队期间已被取消：让出槽位后抛出停止异常
      release();
      rethrow;
    }
  }

  void release() {
    if (_waiters.isNotEmpty) {
      // 槽位直接转交给队首，无需先释放再竞争
      final next = _waiters.removeFirst();
      if (!next.isCompleted) next.complete();
    } else if (_active > 0) {
      _active--;
    }
  }
}
