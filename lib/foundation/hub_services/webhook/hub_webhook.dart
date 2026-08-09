part of 'package:kostori/foundation/hub_services/services.dart';

/// ── Webhook 存储 ─────────────────────────────────────────────────────────────
// 入站 webhook：外部服务通过 HTTP POST 以机器人身份向房间发消息。
// 出站 webhook：房间事件触发时向配置的 URL 推送。

/// 入站 webhook 记录
class HubWebhook {
  final String id;
  final String token;
  final String name;
  final String roomId;
  final String createdAt;

  const HubWebhook({
    required this.id,
    required this.token,
    required this.name,
    required this.roomId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'token': token,
    'name': name,
    'roomId': roomId,
    'createdAt': createdAt,
  };

  factory HubWebhook.fromJson(Map<String, dynamic> json) => HubWebhook(
    id: json['id']?.toString() ?? '',
    token: json['token']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Webhook',
    roomId: json['roomId']?.toString() ?? '',
    createdAt:
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
  );
}

/// 出站 webhook 配置
class HubOutboundWebhook {
  final String id;
  final String url;
  final String name;
  final String secret;
  final bool messageEvents;
  final bool systemEvents;
  final String createdAt;

  const HubOutboundWebhook({
    required this.id,
    required this.url,
    required this.name,
    this.secret = '',
    this.messageEvents = true,
    this.systemEvents = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'name': name,
    'secret': secret,
    'messageEvents': messageEvents,
    'systemEvents': systemEvents,
    'createdAt': createdAt,
  };

  factory HubOutboundWebhook.fromJson(Map<String, dynamic> json) =>
      HubOutboundWebhook(
        id: json['id']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Webhook',
        secret: json['secret']?.toString() ?? '',
        messageEvents: json['messageEvents'] as bool? ?? true,
        systemEvents: json['systemEvents'] as bool? ?? false,
        createdAt:
            json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      );
}

class HubWebhookManager {
  HubWebhookManager._();

  static final HubWebhookManager instance = HubWebhookManager._();

  static const _inboundKey = 'hub_webhooks';
  static const _outboundKey = 'hub_outbound_webhooks';
  static const _wsBotsKey = 'hub_ws_bot_connections';

  // ── 入站 ──

  List<HubWebhook> loadInbound() {
    final raw = appdata.implicitData[_inboundKey];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => HubWebhook.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return [];
  }

  void _saveInbound(List<HubWebhook> list) {
    appdata.implicitData[_inboundKey] = list.map((w) => w.toJson()).toList();
    appdata.writeImplicitData();
  }

  HubWebhook addInbound({required String name, required String roomId}) {
    final webhook = HubWebhook(
      id: const Uuid().v4(),
      token: const Uuid().v4().replaceAll('-', ''),
      name: name,
      roomId: roomId,
      createdAt: DateTime.now().toIso8601String(),
    );
    final list = [...loadInbound(), webhook];
    _saveInbound(list);
    return webhook;
  }

  void deleteInbound(String id) {
    _saveInbound(loadInbound().where((w) => w.id != id).toList());
  }

  HubWebhook? findByToken(String token) {
    for (final w in loadInbound()) {
      if (w.token == token) return w;
    }
    return null;
  }

  // ── 出站 ──

  List<HubOutboundWebhook> loadOutbound() {
    final raw = appdata.implicitData[_outboundKey];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => HubOutboundWebhook.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return [];
  }

  void _saveOutbound(List<HubOutboundWebhook> list) {
    appdata.implicitData[_outboundKey] = list.map((w) => w.toJson()).toList();
    appdata.writeImplicitData();
  }

  HubOutboundWebhook addOutbound({
    required String url,
    required String name,
    String secret = '',
    bool messageEvents = true,
    bool systemEvents = false,
  }) {
    final webhook = HubOutboundWebhook(
      id: const Uuid().v4(),
      url: url,
      name: name,
      secret: secret,
      messageEvents: messageEvents,
      systemEvents: systemEvents,
      createdAt: DateTime.now().toIso8601String(),
    );
    _saveOutbound([...loadOutbound(), webhook]);
    return webhook;
  }

  void deleteOutbound(String id) {
    _saveOutbound(loadOutbound().where((w) => w.id != id).toList());
  }

  /// 计算 HMAC-SHA256 签名（用于出站 webhook 校验）
  static String sign(String secret, String body) {
    final key = utf8.encode(secret);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(body));
    return digest.toString();
  }

  // ── WS 正向连接（Hub 主动连到机器人 WS 服务器，推送事件） ──

  List<HubWsBotConnection> loadWsBots() {
    final raw = appdata.implicitData[_wsBotsKey];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => HubWsBotConnection.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return [];
  }

  void _saveWsBots(List<HubWsBotConnection> list) {
    appdata.implicitData[_wsBotsKey] = list.map((w) => w.toJson()).toList();
    appdata.writeImplicitData();
  }

  HubWsBotConnection addWsBot({
    required String url,
    required String name,
    String secret = '',
    bool messageEvents = true,
    bool systemEvents = false,
  }) {
    final bot = HubWsBotConnection(
      id: const Uuid().v4(),
      url: url,
      name: name,
      secret: secret,
      messageEvents: messageEvents,
      systemEvents: systemEvents,
      createdAt: DateTime.now().toIso8601String(),
    );
    _saveWsBots([...loadWsBots(), bot]);
    return bot;
  }

  void deleteWsBot(String id) {
    _saveWsBots(loadWsBots().where((w) => w.id != id).toList());
  }
}

/// WS 正向连接：Hub 主动作为 WebSocket 客户端连到机器人的服务器，
/// 把房间消息 / 系统事件实时推送给机器人（机器人侧维护一个 WS 接收端即可）。
class HubWsBotConnection {
  final String id;
  final String url;
  final String name;

  /// 可选鉴权密钥：机器人侧用它校验「你好」握手（简单共享密钥），
  /// 也可留空由机器人自行按需处理。
  final String secret;
  final bool messageEvents;
  final bool systemEvents;
  final String createdAt;

  const HubWsBotConnection({
    required this.id,
    required this.url,
    required this.name,
    this.secret = '',
    this.messageEvents = true,
    this.systemEvents = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'name': name,
    'secret': secret,
    'messageEvents': messageEvents,
    'systemEvents': systemEvents,
    'createdAt': createdAt,
  };

  factory HubWsBotConnection.fromJson(Map<String, dynamic> json) =>
      HubWsBotConnection(
        id: json['id']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        name: json['name']?.toString() ?? 'WS Bot',
        secret: json['secret']?.toString() ?? '',
        messageEvents: json['messageEvents'] as bool? ?? true,
        systemEvents: json['systemEvents'] as bool? ?? false,
        createdAt:
            json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      );
}
