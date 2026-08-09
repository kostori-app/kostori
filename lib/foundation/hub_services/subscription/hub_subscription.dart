part of 'package:kostori/foundation/hub_services/services.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  订阅管理（Subscription）
//  ═══════════════════════════════════════════════════════════════════════════
//  统一三种连接方式：
//   - ws（WebSocket）：正向=Hub 监听(监听地址+端口+心跳+token+备注)；
//                      反向=Hub 主动连接目标 URL(URL+心跳+token+备注)
//   - webhook：Hub 向目标 URL POST 事件(URL+心跳+token+备注)
//   - http：Hub 监听 HTTP 服务(监听地址+端口+token+备注)
//  心跳与 token 均可选。

/// 订阅连接方式
enum HubSubscriptionType { ws, webhook, http }

/// WS 订阅的方向
enum HubWsDirection { forward, reverse }

/// 一条订阅配置
class HubSubscription {
  final String id;

  final HubSubscriptionType type;

  /// WS 订阅才有效：forward（Hub 监听）/ reverse（Hub 连接目标）
  final HubWsDirection? wsDirection;

  /// ws-forward / http 的监听地址（如 0.0.0.0，空表示任意）
  final String? listenHost;

  /// ws-forward / http 的监听端口
  final int? listenPort;

  /// ws-reverse / webhook 的目标 URL
  final String? url;

  /// 心跳间隔（毫秒），可选；0/null 表示不发送心跳
  final int? heartbeatMs;

  /// 鉴权 token，可选
  final String? token;

  /// 备注/名称
  final String note;

  final String createdAt;

  const HubSubscription({
    required this.id,
    required this.type,
    this.wsDirection,
    this.listenHost,
    this.listenPort,
    this.url,
    this.heartbeatMs,
    this.token,
    this.note = '',
    required this.createdAt,
  });

  /// 展示用的摘要（地址或 url）
  String get summary {
    return switch (type) {
      HubSubscriptionType.ws =>
        wsDirection == HubWsDirection.reverse
            ? (url ?? '')
            : '${listenHost?.trim().isNotEmpty == true ? listenHost!.trim() : '0.0.0.0'}:${listenPort ?? 0}',
      HubSubscriptionType.webhook => url ?? '',
      HubSubscriptionType.http =>
        '${listenHost?.trim().isNotEmpty == true ? listenHost!.trim() : '0.0.0.0'}:${listenPort ?? 0}',
    };
  }

  HubSubscription copyWith({
    HubSubscriptionType? type,
    HubWsDirection? wsDirection,
    String? listenHost,
    int? listenPort,
    String? url,
    int? heartbeatMs,
    String? token,
    String? note,
  }) => HubSubscription(
    id: id,
    type: type ?? this.type,
    wsDirection: wsDirection ?? this.wsDirection,
    listenHost: listenHost ?? this.listenHost,
    listenPort: listenPort ?? this.listenPort,
    url: url ?? this.url,
    heartbeatMs: heartbeatMs ?? this.heartbeatMs,
    token: token ?? this.token,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    if (wsDirection != null) 'wsDirection': wsDirection!.name,
    if (listenHost != null) 'listenHost': listenHost,
    if (listenPort != null) 'listenPort': listenPort,
    if (url != null) 'url': url,
    if (heartbeatMs != null) 'heartbeatMs': heartbeatMs,
    if (token != null) 'token': token,
    'note': note,
    'createdAt': createdAt,
  };

  factory HubSubscription.fromJson(Map<String, dynamic> json) {
    final type =
        HubSubscriptionType.values.asNameMap()[json['type']] ??
        HubSubscriptionType.webhook;
    return HubSubscription(
      id: json['id']?.toString() ?? const Uuid().v4(),
      type: type,
      wsDirection: type == HubSubscriptionType.ws
          ? HubWsDirection.values.asNameMap()[json['wsDirection']] ??
                HubWsDirection.reverse
          : null,
      listenHost: json['listenHost']?.toString(),
      listenPort: (json['listenPort'] as num?)?.toInt(),
      url: json['url']?.toString(),
      heartbeatMs: (json['heartbeatMs'] as num?)?.toInt(),
      token: json['token']?.toString(),
      note: json['note']?.toString() ?? '',
      createdAt:
          json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}

/// 订阅管理：持久化 + 旧 webhook/wsbot 数据迁移
class HubSubscriptionManager {
  HubSubscriptionManager._();

  static final HubSubscriptionManager instance = HubSubscriptionManager._();

  static const _key = 'hub_subscriptions';
  static const _migratedKey = 'hub_subscriptions_migrated';

  bool _migrated = false;

  List<HubSubscription> load() {
    final raw = appdata.implicitData[_key];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => HubSubscription.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return [];
  }

  void _save(List<HubSubscription> list) {
    appdata.implicitData[_key] = list.map((s) => s.toJson()).toList();
    appdata.writeImplicitData();
  }

  HubSubscription add(HubSubscription sub) {
    _save([...load(), sub]);
    return sub;
  }

  void update(HubSubscription sub) {
    _save([
      for (final s in load())
        if (s.id == sub.id) sub else s,
    ]);
  }

  void delete(String id) {
    _save(load().where((s) => s.id != id).toList());
  }

  /// 迁移旧版 inbound/outbound webhook 与 ws bot 数据到订阅模型。
  /// 仅在旧数据存在且未迁移过时执行一次。
  void migrateLegacy() {
    if (_migrated) return;
    _migrated = true;
    if (appdata.implicitData[_migratedKey] == true) return;
    final subs = load();
    if (subs.isNotEmpty) return;

    final migrated = <HubSubscription>[];

    // 入站 webhook 仍由 Hub 主服务的 /hub/webhook/<token> 路由提供，不迁移为独立 http 订阅，
    // 否则会在 hub_port 上重复绑定监听器导致冲突。
    // 出站 webhook → webhook 订阅
    for (final w in HubWebhookManager.instance.loadOutbound()) {
      migrated.add(
        HubSubscription(
          id: const Uuid().v4(),
          type: HubSubscriptionType.webhook,
          url: w.url,
          token: w.secret,
          note: w.name,
          createdAt: w.createdAt,
        ),
      );
    }
    // WS 正向连接 → ws 反向订阅（Hub 连接目标 URL）
    for (final b in HubWebhookManager.instance.loadWsBots()) {
      migrated.add(
        HubSubscription(
          id: const Uuid().v4(),
          type: HubSubscriptionType.ws,
          wsDirection: HubWsDirection.reverse,
          url: b.url,
          token: b.secret,
          note: b.name,
          createdAt: b.createdAt,
        ),
      );
    }

    if (migrated.isNotEmpty) {
      _save(migrated);
      HubLog.info('HubSubscription', '✅ 已迁移 ${migrated.length} 条旧订阅配置');
    }
    appdata.implicitData[_migratedKey] = true;
    appdata.writeImplicitData();
  }
}
