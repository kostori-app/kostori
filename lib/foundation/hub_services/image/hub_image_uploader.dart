// hub_image_uploader.dart
part of 'package:kostori/foundation/hub_services/services.dart';

class HubImageUploader {
  final HubUploadConfig config;
  final String serverBaseUrl; // 必须是 http(s)://
  final String? authToken; // 可选：上传时带上的鉴权 token

  HubImageUploader({
    required this.config,
    required this.serverBaseUrl,
    this.authToken,
  });

  /// 上传图片，返回可访问的 URL。失败抛异常。
  Future<String> upload(
    Uint8List bytes,
    String fileName, {
    ProgressCallback? onProgress,
  }) async {
    if (bytes.length > config.maxSizeBytes) {
      final maxMb = (config.maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      throw Exception('Image too large (max ${maxMb}MB)');
    }

    return config.uploadViaServer
        ? _uploadToServer(bytes, fileName, onProgress: onProgress)
        : _uploadToClientOss(bytes, fileName, onProgress: onProgress);
  }

  // ═══════════════════════════════════════════════════════
  //  服务端上传
  // ═══════════════════════════════════════════════════════

  Future<String> _uploadToServer(
    Uint8List bytes,
    String fileName, {
    ProgressCallback? onProgress,
  }) async {
    final url = '${httpUrlOf(serverBaseUrl)}/hub/upload';
    HubLog.info(
      'HubUploader',
      '→ server upload  file=$fileName  size=${bytes.length}B  url=$url',
    );

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: DioMediaType.parse(_guessMime(fileName)),
      ),
    });

    final authHeaders = <String, String>{};
    final token = authToken;
    if (token != null && token.isNotEmpty) {
      authHeaders['Authorization'] = 'Bearer $token';
    }
    final response = await AppDio().request(
      url,
      data: formData,
      options: Options(
        method: 'POST',
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 20),
        headers: authHeaders,
      ),
    );

    if (response.statusCode != 200) {
      final msg = response.data is Map
          ? (response.data['error'] ?? 'Upload failed')
          : 'Upload failed (${response.statusCode})';
      HubLog.warning('HubUploader', '✗ server upload failed: $msg');
      throw Exception(msg.toString());
    }

    final data = response.data is String
        ? jsonDecode(response.data as String) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;

    final resultUrl = data['url'] as String?;
    if (resultUrl == null || resultUrl.isEmpty) {
      HubLog.warning('HubUploader', '✗ server returned no URL');
      throw Exception('Server returned no URL');
    }

    HubLog.info('HubUploader', '✓ server upload ok → $resultUrl');
    return resultUrl;
  }

  // ═══════════════════════════════════════════════════════
  //  客户端直传 OSS
  // ═══════════════════════════════════════════════════════

  Future<String> _uploadToClientOss(
    Uint8List bytes,
    String fileName, {
    ProgressCallback? onProgress,
  }) async {
    final oss = config.ossConfig;
    if (oss == null || !oss.isValid) {
      throw Exception(
        'OSS not configured. '
        'Please fill in endpoint, bucket, accessKeyId, accessKeySecret.',
      );
    }

    final key = oss.buildKey(fileName, bytes);
    final contentType = _guessMime(fileName);
    final date = HttpDate.format(DateTime.now().toUtc());
    final contentMd5 = base64Encode(md5.convert(bytes).bytes);

    final isS3 =
        oss.endpoint.contains('s3') ||
        oss.endpoint.contains('qiniucs') ||
        oss.endpoint.contains('amazonaws');

    final endpoint = oss.endpoint
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/$'), '');

    final String putUrl;
    final String authorization;

    if (isS3) {
      // ── AWS S3 V2 / 七牛 ──────────────────────────────
      final sts = 'PUT\n$contentMd5\n$contentType\n$date\n/${oss.bucket}/$key';
      final sig = base64Encode(
        Hmac(
          sha1,
          utf8.encode(oss.accessKeySecret),
        ).convert(utf8.encode(sts)).bytes,
      );
      authorization = 'AWS ${oss.accessKeyId}:$sig';
      putUrl = 'https://$endpoint/${oss.bucket}/$key';
      HubLog.info(
        'HubUploader',
        '→ S3-compatible upload  url=$putUrl  key=$key',
      );
    } else {
      // ── 阿里云 OSS V1 ──────────────────────────────────
      final sts = 'PUT\n$contentMd5\n$contentType\n$date\n/${oss.bucket}/$key';
      final sig = base64Encode(
        Hmac(
          sha1,
          utf8.encode(oss.accessKeySecret),
        ).convert(utf8.encode(sts)).bytes,
      );
      authorization = 'OSS ${oss.accessKeyId}:$sig';
      putUrl = 'https://${oss.bucket}.$endpoint/$key';
      HubLog.info('HubUploader', '→ Aliyun OSS upload  url=$putUrl  key=$key');
    }

    HubLog.info(
      'HubUploader',
      '  size=${bytes.length}B  mime=$contentType  md5=$contentMd5',
    );

    try {
      final response = await AppDio().request(
        putUrl,
        data: bytes,
        options: Options(
          method: 'PUT',
          headers: {
            'Content-Type': contentType,
            'Content-MD5': contentMd5,
            'Content-Length': bytes.length,
            'Date': date,
            'Authorization': authorization,
          },
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 30),
        ),
        onSendProgress: onProgress,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final url = oss.accessUrl(key);
        HubLog.info('HubUploader', '✓ OSS upload ok → $url');
        return url;
      }

      throw Exception(
        'OSS upload failed: ${response.statusCode} ${response.data}',
      );
    } on DioException catch (e) {
      HubLog.warning(
        'HubUploader',
        '✗ OSS upload error  status=${e.response?.statusCode}  '
            'body=${e.response?.data}',
      );
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  //  工具
  // ═══════════════════════════════════════════════════════

  /// ws:// → http://, wss:// → https://；无协议时补 http://
  static String httpUrlOf(String url) {
    if (url.startsWith('wss://')) return 'https://${url.substring(6)}';
    if (url.startsWith('ws://')) return 'http://${url.substring(5)}';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return 'http://$url';
  }

  static String _guessMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      'bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };
  }
}
