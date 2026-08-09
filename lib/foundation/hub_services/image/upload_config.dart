// upload_config.dart
part of 'package:kostori/foundation/hub_services/services.dart';

/// 图片上传模式
enum HubUploadMode {
  /// 服务端本地磁盘存储
  serverLocal,

  /// 服务端代理上传到 OSS/S3
  serverOss,

  /// 客户端直传 OSS/S3（服务端不经手）
  clientOss,
}

/// OSS 配置（S3 / 阿里云 OSS / MinIO 兼容）
class OssConfig {
  final String endpoint;
  final String bucket;
  final String accessKeyId;
  final String accessKeySecret;
  final String? region;
  final String? prefix;
  final String? cdnDomain;

  const OssConfig({
    required this.endpoint,
    required this.bucket,
    required this.accessKeyId,
    required this.accessKeySecret,
    this.region,
    this.prefix,
    this.cdnDomain,
  });

  bool get isValid =>
      endpoint.isNotEmpty &&
      bucket.isNotEmpty &&
      accessKeyId.isNotEmpty &&
      accessKeySecret.isNotEmpty;

  /// 拼接 OSS host：https://bucket.endpoint_host
  String get host {
    final ep = Uri.parse(endpoint);
    return '${ep.scheme}://$bucket.${ep.host}';
  }

  /// 拼接完整访问 URL
  String accessUrl(String key) {
    if (cdnDomain != null && cdnDomain!.isNotEmpty) {
      final cdn = cdnDomain!.endsWith('/')
          ? cdnDomain!.substring(0, cdnDomain!.length - 1)
          : cdnDomain!;
      return '$cdn/$key';
    }
    return '$host/$key';
  }

  /// 生成带前缀的存储 key
  String buildKey(String filename, Uint8List bytes) {
    final ext = filename.contains('.')
        ? filename.substring(filename.lastIndexOf('.'))
        : '.bin';
    final hash = md5.convert(bytes).toString();
    return '${prefix ?? "hub/"}$hash$ext';
  }

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'bucket': bucket,
    'accessKeyId': accessKeyId,
    'accessKeySecret': SecretVault.encrypt(accessKeySecret),
    if (region != null) 'region': region,
    if (prefix != null) 'prefix': prefix,
    if (cdnDomain != null) 'cdnDomain': cdnDomain,
  };

  factory OssConfig.fromJson(Map<String, dynamic> json) => OssConfig(
    endpoint: json['endpoint']?.toString() ?? '',
    bucket: json['bucket']?.toString() ?? '',
    accessKeyId: json['accessKeyId']?.toString() ?? '',
    accessKeySecret: SecretVault.decrypt(
      json['accessKeySecret']?.toString() ?? '',
    ),
    region: json['region']?.toString(),
    prefix: json['prefix']?.toString(),
    cdnDomain: json['cdnDomain']?.toString(),
  );

  OssConfig copyWith({
    String? endpoint,
    String? bucket,
    String? accessKeyId,
    String? accessKeySecret,
    String? region,
    String? prefix,
    String? cdnDomain,
  }) => OssConfig(
    endpoint: endpoint ?? this.endpoint,
    bucket: bucket ?? this.bucket,
    accessKeyId: accessKeyId ?? this.accessKeyId,
    accessKeySecret: accessKeySecret ?? this.accessKeySecret,
    region: region ?? this.region,
    prefix: prefix ?? this.prefix,
    cdnDomain: cdnDomain ?? this.cdnDomain,
  );
}

/// Hub 上传总配置 —— 服务端 & 客户端共用
class HubUploadConfig {
  final HubUploadMode mode;
  final OssConfig? ossConfig;
  final int maxSizeBytes;
  final String? localStorePath;

  const HubUploadConfig({
    this.mode = HubUploadMode.serverLocal,
    this.ossConfig,
    this.maxSizeBytes = 5 * 1024 * 1024,
    this.localStorePath,
  });

  // ── 持久化 ──

  static const _storageKey = 'hub_upload_config';

  static HubUploadConfig load() {
    final raw = appdata.implicitData[_storageKey];
    if (raw == null) return const HubUploadConfig();

    if (raw is Map) {
      return HubUploadConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    return const HubUploadConfig();
  }

  void save() {
    appdata.implicitData[_storageKey] = toJson();
    appdata.writeImplicitData();
  }

  // ── 校验 ──

  /// 服务端校验
  String? validateForServer() {
    switch (mode) {
      case HubUploadMode.serverLocal:
        return null;
      case HubUploadMode.serverOss:
        if (ossConfig == null || !ossConfig!.isValid) {
          return 'serverOss mode requires valid ossConfig '
              '(endpoint, bucket, accessKeyId, accessKeySecret)';
        }
        return null;
      case HubUploadMode.clientOss:
        return null;
    }
  }

  /// 客户端校验
  String? validateForClient() {
    switch (mode) {
      case HubUploadMode.serverLocal:
      case HubUploadMode.serverOss:
        return null;
      case HubUploadMode.clientOss:
        if (ossConfig == null || !ossConfig!.isValid) {
          return 'Please configure OSS settings in Hub settings';
        }
        return null;
    }
  }

  /// 客户端是否走服务端上传
  bool get uploadViaServer =>
      mode == HubUploadMode.serverLocal || mode == HubUploadMode.serverOss;

  /// 是否需要显示 OSS 配置 UI
  bool get clientNeedsOssConfig => mode == HubUploadMode.clientOss;

  bool get serverNeedsOssConfig => mode == HubUploadMode.serverOss;

  // ── 序列化 ──

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    if (ossConfig != null) 'ossConfig': ossConfig!.toJson(),
    'maxSizeBytes': maxSizeBytes,
    if (localStorePath != null) 'localStorePath': localStorePath,
  };

  factory HubUploadConfig.fromJson(Map<String, dynamic> json) {
    OssConfig? oss;
    final rawOss = json['ossConfig'];
    if (rawOss is Map) {
      oss = OssConfig.fromJson(Map<String, dynamic>.from(rawOss));
    }

    return HubUploadConfig(
      mode: HubUploadMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => HubUploadMode.serverLocal,
      ),
      ossConfig: oss,
      maxSizeBytes: (json['maxSizeBytes'] as num?)?.toInt() ?? 5 * 1024 * 1024,
      localStorePath: json['localStorePath']?.toString(),
    );
  }

  HubUploadConfig copyWith({
    HubUploadMode? mode,
    OssConfig? ossConfig,
    bool clearOssConfig = false,
    int? maxSizeBytes,
    String? localStorePath,
    bool clearLocalStorePath = false,
  }) => HubUploadConfig(
    mode: mode ?? this.mode,
    ossConfig: clearOssConfig ? null : (ossConfig ?? this.ossConfig),
    maxSizeBytes: maxSizeBytes ?? this.maxSizeBytes,
    localStorePath: clearLocalStorePath
        ? null
        : (localStorePath ?? this.localStorePath),
  );
}
