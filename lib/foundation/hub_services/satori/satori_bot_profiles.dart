// satori_bot_profiles.dart
// Satori 接入机器人档案：每个接入方（Koishi 等）用专属令牌绑定一个 bot 身份，
// 支持自定义名字/头像/简介，从而区分多个第三方 bot。
part of 'package:kostori/foundation/hub_services/services.dart';

/// Satori 接入机器人档案（服务端身份，可编辑）
class SatoriBotProfile {
  /// 稳定身份 ID（即 Hub 里的 userId）
  final String id;

  /// 显示名
  String name;

  /// 头像 URL（可空）
  String? avatarUrl;

  /// 简介（可空）
  String? biography;

  /// 专属连接令牌：Satori 客户端用它鉴权并绑定到本 bot
  final String token;

  /// 是否启用（禁用后该令牌拒绝连接）
  bool enabled;

  SatoriBotProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.biography,
    required this.token,
    this.enabled = true,
  });

  /// 默认首个 bot（向后兼容旧版固定 satori-bot 身份）
  factory SatoriBotProfile.defaultBot() => SatoriBotProfile(
    id: 'satori-bot',
    name: 'Satori Bot',
    token: '',
    enabled: true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (biography != null) 'biography': biography,
    'token': token,
    'enabled': enabled,
  };

  factory SatoriBotProfile.fromJson(Map<String, dynamic> json) =>
      SatoriBotProfile(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        biography: json['biography'] as String?,
        token: json['token'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
      );

  SatoriBotProfile copyWith({
    String? name,
    String? avatarUrl,
    String? biography,
    bool? enabled,
  }) => SatoriBotProfile(
    id: id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    biography: biography ?? this.biography,
    token: token,
    enabled: enabled ?? this.enabled,
  );
}

/// 档案存储与查找（持久化在 appdata.implicitData）
class SatoriBotProfileStore {
  SatoriBotProfileStore._();

  static final SatoriBotProfileStore instance = SatoriBotProfileStore._();

  static const String _key = 'satori_bot_profiles';

  List<SatoriBotProfile> load() {
    final raw = appdata.implicitData[_key];
    if (raw is List) {
      final list = raw
          .whereType<Map>()
          .map((m) => SatoriBotProfile.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (list.isNotEmpty) return list;
    }
    // 无档案时返回默认 bot（向后兼容）
    return [SatoriBotProfile.defaultBot()];
  }

  void save(List<SatoriBotProfile> profiles) {
    appdata.implicitData[_key] = profiles.map((p) => p.toJson()).toList();
    appdata.writeImplicitData();
  }

  /// 按令牌查找档案（启用状态）
  SatoriBotProfile? findByToken(String token) {
    if (token.isEmpty) return null;
    for (final p in load()) {
      if (p.enabled && p.token.isNotEmpty && p.token == token) return p;
    }
    return null;
  }

  /// 按 id 查找
  SatoriBotProfile? findById(String id) {
    for (final p in load()) {
      if (p.id == id) return p;
    }
    return null;
  }

  String generateId() {
    final id = const Uuid().v4();
    return 'satori-$id';
  }

  String generateToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(32, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
