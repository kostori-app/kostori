part of 'package:kostori/foundation/hub_services/services.dart';

const int kLanDiscoveryPort = 45678;
const int kLanBroadcastInterval = 2;
// 默认组播组地址（多线程广播），可在设置中修改；路由器/AP 对组播的转发通常比广播更可靠
const String kLanMulticastGroup = '224.0.0.167';

enum LanDeviceType {
  desktop,
  mobile,
  tablet,
  unknown;

  String get displayName => switch (this) {
    LanDeviceType.desktop => 'Desktop',
    LanDeviceType.mobile => 'Mobile',
    LanDeviceType.tablet => 'Tablet',
    LanDeviceType.unknown => 'Unknown',
  };

  static LanDeviceType fromString(String? value) {
    return LanDeviceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LanDeviceType.unknown,
    );
  }
}

class LanDiscoveredDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final LanDeviceType deviceType;
  final String? avatarUrl;
  final DateTime discoveredAt;
  final DateTime lastSeen;
  final Map<String, dynamic>? capabilities;

  const LanDiscoveredDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    this.deviceType = LanDeviceType.unknown,
    this.avatarUrl,
    required this.discoveredAt,
    required this.lastSeen,
    this.capabilities,
  });

  String get wsUrl => 'ws://$ip:$port/hub';

  bool get supportsRemoteControl =>
      capabilities?['remoteControl'] == true ||
      capabilities?['remote_control'] == true;

  bool get supportsQrPairing =>
      capabilities?['qrPairing'] == true || capabilities?['qr_pairing'] == true;

  factory LanDiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return LanDiscoveredDevice(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      ip: json['ip'] as String,
      port: json['port'] as int? ?? 42183,
      deviceType: LanDeviceType.fromString(json['deviceType'] as String?),
      avatarUrl: json['avatarUrl'] as String?,
      discoveredAt: DateTime.now(),
      lastSeen: DateTime.now(),
      capabilities: json['capabilities'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'port': port,
    'deviceType': deviceType.name,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (capabilities != null) 'capabilities': capabilities,
  };

  LanDiscoveredDevice copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    LanDeviceType? deviceType,
    String? avatarUrl,
    DateTime? discoveredAt,
    DateTime? lastSeen,
    Map<String, dynamic>? capabilities,
  }) {
    return LanDiscoveredDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      deviceType: deviceType ?? this.deviceType,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      lastSeen: lastSeen ?? this.lastSeen,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanDiscoveredDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class LanDiscoveryRequest {
  final String senderId;
  final String senderName;
  final LanDeviceType deviceType;
  final int port;
  final String? avatarUrl;
  final Map<String, dynamic>? capabilities;

  const LanDiscoveryRequest({
    required this.senderId,
    required this.senderName,
    this.deviceType = LanDeviceType.unknown,
    this.port = 42183,
    this.avatarUrl,
    this.capabilities,
  });

  factory LanDiscoveryRequest.fromJson(Map<String, dynamic> json) {
    final port = json['port'] as int? ?? 42183;
    return LanDiscoveryRequest(
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String? ?? 'Unknown',
      deviceType: LanDeviceType.fromString(json['deviceType'] as String?),
      port: (port >= 0 && port <= 65535) ? port : 42183,
      avatarUrl: json['avatarUrl'] as String?,
      capabilities: json['capabilities'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'discovery_request',
    'senderId': senderId,
    'senderName': senderName,
    'deviceType': deviceType.name,
    'port': port,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (capabilities != null) 'capabilities': capabilities,
  };
}

class LanDiscoveryResponse {
  final String senderId;
  final String senderName;
  final LanDeviceType deviceType;
  final String ip;
  final int port;
  final String? avatarUrl;
  final Map<String, dynamic>? capabilities;

  const LanDiscoveryResponse({
    required this.senderId,
    required this.senderName,
    this.deviceType = LanDeviceType.unknown,
    required this.ip,
    required this.port,
    this.avatarUrl,
    this.capabilities,
  });

  factory LanDiscoveryResponse.fromJson(Map<String, dynamic> json) {
    return LanDiscoveryResponse(
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String? ?? 'Unknown',
      deviceType: LanDeviceType.fromString(json['deviceType'] as String?),
      ip: json['ip'] as String,
      port: json['port'] as int? ?? 42183,
      avatarUrl: json['avatarUrl'] as String?,
      capabilities: json['capabilities'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'discovery_response',
    'senderId': senderId,
    'senderName': senderName,
    'deviceType': deviceType.name,
    'ip': ip,
    'port': port,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (capabilities != null) 'capabilities': capabilities,
  };

  LanDiscoveredDevice toDevice() {
    return LanDiscoveredDevice(
      id: senderId,
      name: senderName,
      ip: ip,
      port: port,
      deviceType: deviceType,
      avatarUrl: avatarUrl,
      discoveredAt: DateTime.now(),
      lastSeen: DateTime.now(),
      capabilities: capabilities,
    );
  }
}

class LanPairingRequest {
  final String requesterId;
  final String requesterName;
  final String token;
  final DateTime expiresAt;

  const LanPairingRequest({
    required this.requesterId,
    required this.requesterName,
    required this.token,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory LanPairingRequest.fromJson(Map<String, dynamic> json) {
    return LanPairingRequest(
      requesterId: json['requesterId'] as String,
      requesterName: json['requesterName'] as String? ?? 'Unknown',
      token: json['token'] as String,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : DateTime.now().add(const Duration(seconds: 10)),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'pairing_request',
    'requesterId': requesterId,
    'requesterName': requesterName,
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

class LanPairingResponse {
  final String targetId;
  final bool accepted;
  final String? wsUrl;
  final String? errorMessage;

  const LanPairingResponse({
    required this.targetId,
    required this.accepted,
    this.wsUrl,
    this.errorMessage,
  });

  factory LanPairingResponse.fromJson(Map<String, dynamic> json) {
    return LanPairingResponse(
      targetId: json['targetId'] as String,
      accepted: json['accepted'] as bool? ?? false,
      wsUrl: json['wsUrl'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'pairing_response',
    'targetId': targetId,
    'accepted': accepted,
    if (wsUrl != null) 'wsUrl': wsUrl,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };
}
