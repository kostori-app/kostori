part of 'package:kostori/foundation/services/services.dart';

typedef MiddlewareHandler = Future<bool> Function(HttpRequest request);

class Middleware {
  // ─────────────────────────────────────────
  // 鉴权：支持 Bearer token
  // ─────────────────────────────────────────

  /// 从 Authorization header 或 query 参数取 Key 校验
  static MiddlewareHandler auth({bool admin = false}) {
    return (HttpRequest request) async {
      final header = request.headers.value('Authorization');
      final bearerToken = header != null && header.startsWith('Bearer ')
          ? header.substring(7)
          : null;
      final queryToken = request.uri.queryParameters['token'];
      final token = bearerToken ?? queryToken;

      final valid =
          token != null &&
          (admin
              ? ApiKeyManager().validateAdmin(token)
              : ApiKeyManager().validate(token));

      if (!valid) {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'error': 'Unauthorized',
              'message': token == null
                  ? 'Missing token (Authorization: Bearer <key> or ?token=)'
                  : 'Invalid token',
            }),
          );
        await request.response.close();
        return false;
      }

      return true;
    };
  }

  // ─────────────────────────────────────────
  // 本地免鉴权
  // ─────────────────────────────────────────

  static MiddlewareHandler localBypass(MiddlewareHandler next) {
    return (HttpRequest request) async {
      final ip = request.connectionInfo?.remoteAddress.address ?? '';
      final isLocal =
          ip == '127.0.0.1' || ip == '::1' || ip == '0:0:0:0:0:0:0:1';
      if (isLocal) return true;
      return next(request);
    };
  }

  // ─────────────────────────────────────────
  // 错误处理
  // ─────────────────────────────────────────

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

  // ─────────────────────────────────────────
  // 限流
  // ─────────────────────────────────────────

  static MiddlewareHandler rateLimit({
    int maxRequests = 60,
    Duration window = const Duration(minutes: 1),
  }) {
    final counts = <String, List<DateTime>>{};

    return (HttpRequest request) async {
      final ip = request.connectionInfo?.remoteAddress.address ?? 'unknown';
      final now = DateTime.now();
      final windowStart = now.subtract(window);

      counts[ip] = (counts[ip] ?? [])
          .where((t) => t.isAfter(windowStart))
          .toList();

      if (counts[ip]!.length >= maxRequests) {
        request.response
          ..statusCode = 429
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

  // ─────────────────────────────────────────
  // CORS
  // ─────────────────────────────────────────

  static MiddlewareHandler cors({
    String allowOrigin = '*',
    String allowMethods = 'GET, POST, PUT, DELETE, OPTIONS',
    String allowHeaders = 'Content-Type, Authorization',
  }) {
    return (HttpRequest request) async {
      request.response.headers
        ..set('Access-Control-Allow-Origin', allowOrigin)
        ..set('Access-Control-Allow-Methods', allowMethods)
        ..set('Access-Control-Allow-Headers', allowHeaders);

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return false;
      }
      return true;
    };
  }

  // ─────────────────────────────────────────
  // Body 大小限制
  // ─────────────────────────────────────────

  static MiddlewareHandler bodySizeLimit({int maxBytes = 1024 * 1024}) {
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

  // ─────────────────────────────────────────
  // IP 白名单
  // ─────────────────────────────────────────

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
