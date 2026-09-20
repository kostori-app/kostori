import 'package:dio/dio.dart';

class NetworkUtils {
  static String get userAgent =>
      'kostori-app/1.0.0 (platform: _detectPlatform)';

  static Options withUserAgent(Map<String, dynamic> extraHeaders) {
    return Options(
      headers: {
        'User-Agent': userAgent,
        ...extraHeaders,
      },
    );
  }
}