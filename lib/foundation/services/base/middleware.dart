part of 'package:kostori/foundation/services/services.dart';

typedef MiddlewareHandler = Future<bool> Function(HttpRequest request);

class Middleware {
  /// 从 ApiKeyManager 取当前生效的 Key 来校验
  static MiddlewareHandler apiKey() {
    return (HttpRequest request) async {
      // 同时支持 Header 和 Query 参数两种方式
      final headerKey = request.headers.value('X-API-Key');
      final queryKey = request.uri.queryParameters['token'];
      final key = headerKey ?? queryKey;

      final passed = key != null && ApiKeyManager().validate(key);

      if (!passed) {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': 'Unauthorized',
              'message': key == null
                  ? 'Missing API Key (X-API-Key header or ?token=)'
                  : 'Invalid API Key',
            }),
          );
        await request.response.close();
        return false;
      }

      return true;
    };
  }

  /// 本地访问免鉴权
  static MiddlewareHandler localBypass(MiddlewareHandler next) {
    return (HttpRequest request) async {
      final ip = request.connectionInfo?.remoteAddress.address ?? '';
      final isLocal =
          ip == '127.0.0.1' || ip == '::1' || ip == '0:0:0:0:0:0:0:1';
      if (isLocal) return true;
      return next(request);
    };
  }

  static MiddlewareHandler errorHandler() {
    return (HttpRequest request) async {
      try {
        return true;
      } catch (e, stack) {
        Log.error('ErrorHandler', '$e', stack);
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': 'Internal Server Error',
              'message': e.toString(),
            }),
          );
        await request.response.close();
        return false;
      }
    };
  }

  static MiddlewareHandler rateLimit({
    int maxRequests = 60, // 最多请求次数
    Duration window = const Duration(minutes: 1), // 时间窗口
  }) {
    final counts = <String, List<DateTime>>{};

    return (HttpRequest request) async {
      final ip = request.connectionInfo?.remoteAddress.address ?? 'unknown';
      final now = DateTime.now();
      final windowStart = now.subtract(window);

      // 清理过期记录
      counts[ip] = (counts[ip] ?? [])
          .where((t) => t.isAfter(windowStart))
          .toList();

      if (counts[ip]!.length >= maxRequests) {
        request.response
          ..statusCode =
              429 // Too Many Requests
          ..headers.contentType = ContentType.json
          ..headers.set('Retry-After', '60')
          ..write(
            jsonEncode({
              'error': 'Too Many Requests',
              'message': '请求过于频繁，请稍后再试',
              'retryAfter': 60,
            }),
          );
        await request.response.close();
        return false;
      }

      counts[ip]!.add(now);
      return true;
    };
  }

  static MiddlewareHandler cors({
    String allowOrigin = '*',
    String allowMethods = 'GET, POST, PUT, DELETE, OPTIONS',
    String allowHeaders = 'Content-Type, X-API-Key',
  }) {
    return (HttpRequest request) async {
      request.response.headers
        ..set('Access-Control-Allow-Origin', allowOrigin)
        ..set('Access-Control-Allow-Methods', allowMethods)
        ..set('Access-Control-Allow-Headers', allowHeaders);

      // OPTIONS 预检请求直接返回
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return false;
      }

      return true;
    };
  }

  static MiddlewareHandler bodySizeLimit({int maxBytes = 1024 * 1024}) {
    // 默认1MB
    return (HttpRequest request) async {
      final contentLength = request.contentLength;

      if (contentLength != -1 && contentLength > maxBytes) {
        request.response
          ..statusCode = HttpStatus.requestEntityTooLarge
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': 'Request Entity Too Large',
              'maxBytes': maxBytes,
              'receivedBytes': contentLength,
            }),
          );
        await request.response.close();
        return false;
      }

      return true;
    };
  }

  static MiddlewareHandler ipWhitelist(List<String> allowedIps) {
    return (HttpRequest request) async {
      final ip = request.connectionInfo?.remoteAddress.address ?? '';

      // 本地永远放行
      final isLocal = ip == '127.0.0.1' || ip == '::1';
      if (isLocal) return true;

      if (!allowedIps.contains(ip)) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': 'Forbidden',
              'message': 'IP $ip is not allowed',
            }),
          );
        await request.response.close();
        return false;
      }

      return true;
    };
  }
}
