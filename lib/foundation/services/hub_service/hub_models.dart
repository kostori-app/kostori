part of 'package:kostori/foundation/services/services.dart';

// ── 枚举 ──────────────────────────────────────────

enum HubMessageType { broadcast, unicast, system }

enum UserStatus { online, away, busy, offline }

enum KickReason { kicked, banned, serverBanned }

// ── HubMessage ────────────────────────────────────

class HubMessage {
  final String id;
  final HubMessageType type;
  final String from;
  final String? to;
  final dynamic payload;
  final DateTime time;
  final String? replyTo;
  bool isPinned;
  Map<String, List<String>> reactions;

  HubMessage({
    String? id,
    required this.type,
    required this.from,
    this.to,
    required this.payload,
    this.replyTo,
    this.isPinned = false,
    Map<String, List<String>>? reactions,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toRadixString(36),
       time = DateTime.now(),
       reactions = reactions ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'from': from,
    'to': to,
    'payload': payload,
    'time': time.toIso8601String(),
    'replyTo': replyTo,
    'isPinned': isPinned,
    'reactions': reactions,
  };
}

// ── HubClientInfo ─────────────────────────────────

class HubClientInfo {
  final String id;
  String? name;
  final WebSocket socket;
  final DateTime connectedAt;
  String? avatar;
  String? bio;
  UserStatus status;
  bool isGlobalAdmin;
  DateTime? mutedUntil;
  String currentRoomId;

  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());

  HubClientInfo({
    required this.id,
    required this.socket,
    this.name,
    this.avatar,
    this.bio,
    this.status = UserStatus.online,
    this.isGlobalAdmin = false,
    this.mutedUntil,
    this.currentRoomId = 'lobby',
  }) : connectedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name ?? id,
    'connectedAt': connectedAt.toIso8601String(),
    'avatar': avatar,
    'bio': bio,
    'status': status.name,
    'isGlobalAdmin': isGlobalAdmin,
    'isMuted': isMuted,
    'mutedUntil': mutedUntil?.toIso8601String(),
    'currentRoomId': currentRoomId,
  };

  void send(Map<String, dynamic> data) {
    try {
      socket.add(jsonEncode(data));
    } catch (_) {}
  }
}

// ── HubRoom ───────────────────────────────────────

class HubRoom {
  final String id;
  String name;
  String? announcement;
  String? password;
  final String ownerId;
  final DateTime createdAt;
  final Map<String, HubClientInfo> members = {};
  final List<HubMessage> messages = [];
  final Set<String> adminIds = {};
  final Set<String> bannedIds = {};
  static const _maxHistory = 100;

  HubRoom({
    String? id,
    required this.name,
    required this.ownerId,
    this.announcement,
    this.password,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toRadixString(36),
       createdAt = DateTime.now();

  bool get isLocked => password != null && password!.isNotEmpty;

  bool validatePassword(String? pwd) {
    if (!isLocked) return true;
    return pwd == password;
  }

  bool isAdmin(String clientId) =>
      ownerId == clientId || adminIds.contains(clientId);

  void addMessage(HubMessage msg) {
    messages.add(msg);
    if (messages.length > _maxHistory) messages.removeAt(0);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'announcement': announcement,
    'ownerId': ownerId,
    'adminIds': adminIds.toList(),
    'memberCount': members.length,
    'members': members.values.map((m) => m.toJson()).toList(),
    'isLocked': isLocked,
    'createdAt': createdAt.toIso8601String(),
    'bannedIds': bannedIds.toList(),
  };
}
