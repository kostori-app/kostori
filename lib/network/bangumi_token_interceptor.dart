// ignore_for_file: empty_catches

import 'package:dio/dio.dart';
import 'package:kostori/network/bangumi_oauth.dart';

/// Bangumi API 401 时自动用 refresh_token 换新 token 并重试原请求。
/// 附加到 Bangumi 的 dio 上；刷新请求与重试请求均打上跳过标记防死循环。
class BangumiTokenInterceptor extends Interceptor {
  BangumiTokenInterceptor(this._dio);

  final Dio _dio;

  Future<bool>? _refreshing;

  static bool _isBangumiApi(Uri uri) {
    final host = uri.host;
    return host == 'api.bgm.tv' || host == 'next.bgm.tv' || host == 'bgm.tv';
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final options = err.requestOptions;

    if (status != 401 ||
        !_isBangumiApi(options.uri) ||
        options.extra['skipTokenRefresh'] == true ||
        !bangumiLoggedIn) {
      handler.next(err);
      return;
    }

    try {
      // 并发保护：多个 401 同时到达时只发起一次刷新
      final ok = await (_refreshing ??= bangumiRefreshToken());
      if (!ok) {
        handler.next(err);
        return;
      }
      final newToken = bangumiAccessToken;
      if (newToken == null || newToken.trim().isEmpty) {
        handler.next(err);
        return;
      }

      options.extra['skipTokenRefresh'] = true;
      options.headers['Authorization'] = 'Bearer ${newToken.trim()}';
      final res = await _dio.fetch(options);
      handler.resolve(res);
    } catch (e) {
      handler.next(err);
    } finally {
      _refreshing = null;
    }
  }
}
