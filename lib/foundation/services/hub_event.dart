part of 'package:kostori/foundation/services/services.dart';

// ── 消息基类 ──────────────────────────────────────────────────────────────

sealed class HubEvent {
  const HubEvent();

  factory HubEvent.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['messageType']) as String?;
    if (type == null) return const HubEventUnknown(null);
    return switch (type) {
      'welcome' => HubEventWelcome.fromJson(json),
      'room_joined' => HubEventRoomJoined.fromJson(json),
      'message' => HubEventMessage.fromJson(json, isUnicast: false),
      'chat' => HubEventMessage.fromJson(json, isUnicast: true),
      'unicast' => HubEventMessage.fromJson(json, isUnicast: true),
      'system' => () {
        if (json['payload'] != null) {
          final payload = json['payload'] as Map<String, dynamic>;
          return HubEventSystem.fromEvent(payload['event'] as String?, payload);
        }
        final segments = json['segments'] as List?;
        if (segments != null) {
          for (final seg in segments) {
            final segMap = seg as Map<String, dynamic>;
            if (segMap['type'] == 'text') {
              final text = (segMap['data'] as Map?)?['text'] as String?;
              if (text != null) {
                try {
                  final payload = jsonDecode(text) as Map<String, dynamic>;
                  return HubEventSystem.fromEvent(
                    payload['event'] as String?,
                    payload,
                  );
                } catch (_) {}
              }
            }
          }
        }
        return const HubSystemUnknown('');
      }(),
      'kicked' => HubEventKicked.fromJson(json),
      'pong' => const HubEventPong(),
      'error' => HubEventError.fromJson(json),
      _ => HubEventUnknown(type),
    };
  }
}

// ── 具体事件类 ────────────────────────────────────────────────────────────

class HubEventWelcome extends HubEvent {
  final String yourId;
  final List<HubRoomDto> rooms;
  final HubRoomDto currentRoom;
  final List<HubMessage> history;
  final List<HubClientDto> clients;
  final List<String> blacklist;
  final int heartbeatInterval;
  final bool uploadEnabled;

  const HubEventWelcome({
    required this.yourId,
    required this.rooms,
    required this.currentRoom,
    required this.history,
    required this.clients,
    required this.blacklist,
    required this.heartbeatInterval,
    required this.uploadEnabled,
  });

  factory HubEventWelcome.fromJson(Map<String, dynamic> json) =>
      HubEventWelcome(
        yourId: json['yourId'] as String,
        rooms: (json['rooms'] as List? ?? [])
            .map((r) => HubRoomDto.fromJson(r as Map<String, dynamic>))
            .toList(),
        currentRoom: HubRoomDto.fromJson(json['room'] as Map<String, dynamic>),
        history: (json['history'] as List? ?? [])
            .map((m) => HubMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        clients: (json['clients'] as List? ?? [])
            .map((c) => HubClientDto.fromJson(c as Map<String, dynamic>))
            .toList(),
        blacklist: List<String>.from(json['blacklist'] ?? []),
        heartbeatInterval: json['heartbeatInterval'] as int? ?? 30000,
        uploadEnabled: json['uploadEnabled'] as bool? ?? false,
      );
}

class HubEventRoomJoined extends HubEvent {
  final HubRoomDto room;
  final List<HubMessage> history;

  const HubEventRoomJoined({required this.room, required this.history});

  factory HubEventRoomJoined.fromJson(Map<String, dynamic> json) =>
      HubEventRoomJoined(
        room: HubRoomDto.fromJson(json['room'] as Map<String, dynamic>),
        history: (json['history'] as List? ?? [])
            .map((m) => HubMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class HubEventMessage extends HubEvent {
  final HubMessage message;
  final bool isUnicast;

  const HubEventMessage({required this.message, required this.isUnicast});

  factory HubEventMessage.fromJson(
    Map<String, dynamic> json, {
    required bool isUnicast,
  }) =>
      HubEventMessage(message: HubMessage.fromJson(json), isUnicast: isUnicast);
}

class HubEventPong extends HubEvent {
  const HubEventPong();
}

class HubEventKicked extends HubEvent {
  final String reason;
  final String operatorName;
  final String? message;

  const HubEventKicked({
    required this.reason,
    required this.operatorName,
    this.message,
  });

  factory HubEventKicked.fromJson(Map<String, dynamic> json) => HubEventKicked(
    reason: json['reason'] as String? ?? 'kicked',
    operatorName: json['operatorName'] as String? ?? 'server',
    message: json['message'] as String?,
  );
}

class HubEventError extends HubEvent {
  final String message;

  const HubEventError(this.message);

  factory HubEventError.fromJson(Map<String, dynamic> json) =>
      HubEventError(json['message'] as String? ?? 'Error');
}

class HubEventUnknown extends HubEvent {
  final String? type;

  const HubEventUnknown(this.type); // String? 而不是 String
}

// ── System 事件细分 ───────────────────────────────────────────────────────

sealed class HubEventSystem extends HubEvent {
  const HubEventSystem();

  factory HubEventSystem.fromEvent(
    String? event,
    Map<String, dynamic> payload,
  ) => switch (event) {
    'server_shutdown' => const HubSystemServerShutdown(),
    'global_admin_changed' => HubSystemGlobalAdminChanged.fromJson(payload),
    'blacklist_updated' => HubSystemBlacklistUpdated.fromJson(payload),
    'room_admin_changed' => HubSystemRoomAdminChanged.fromJson(payload),
    'you_are_muted' => HubSystemYouAreMuted.fromJson(payload),
    'you_are_unmuted' => const HubSystemYouAreUnmuted(),
    'user_muted' => HubSystemUserMuted.fromJson(payload, muted: true),
    'user_unmuted' => HubSystemUserMuted.fromJson(payload, muted: false),
    'you_are_room_banned' => HubSystemRoomBanned.fromJson(
      payload,
      banned: true,
    ),
    'you_are_room_unbanned' => HubSystemRoomBanned.fromJson(
      payload,
      banned: false,
    ),
    'kicked_from_room' => const HubSystemKickedFromRoom(),
    'message_recalled' => HubSystemMessageRecalled.fromJson(payload),
    'room_created' => HubSystemRoomCreated.fromJson(payload),
    'room_deleted' => HubSystemRoomDeleted.fromJson(payload),
    'room_updated' => HubSystemRoomUpdated.fromJson(payload),
    'client_joined' => HubSystemClientJoined.fromJson(payload),
    'client_left' => HubSystemClientLeft.fromJson(payload),
    'client_joined_room' => HubSystemClientRoomChanged.fromJson(
      payload,
      joined: true,
    ),
    'client_left_room' => HubSystemClientRoomChanged.fromJson(
      payload,
      joined: false,
    ),
    'profile_updated' => HubSystemProfileUpdated.fromJson(payload),
    'status_changed' => HubSystemStatusChanged.fromJson(payload),

    'room_announcement' => HubSystemRoomAnnouncement(
      announcements: List<String>.from(payload['announcements'] as List? ?? []),
      setByUserId: payload['setByUserId'] as String? ?? '',
      setByName: payload['setByName'] as String? ?? '',
    ),

    'room_welcome' => HubSystemRoomWelcome(
      message: payload['message'] as String? ?? '',
    ),

    'poked' => HubSystemPoked(
      fromId: payload['fromId'] as String? ?? '',
      fromName: payload['fromName'] as String? ?? '',
    ),

    'mentioned' => HubSystemMentioned(
      fromId: payload['fromId'] as String? ?? '',
      fromName: payload['fromName'] as String? ?? '',
      messageId: payload['messageId'] as String? ?? '',
      previewText: payload['previewText'] as String? ?? '',
    ),

    _ => HubSystemUnknown(event ?? ''),
  };
}

class HubSystemServerShutdown extends HubEventSystem {
  const HubSystemServerShutdown();
}

class HubSystemYouAreUnmuted extends HubEventSystem {
  const HubSystemYouAreUnmuted();
}

class HubSystemKickedFromRoom extends HubEventSystem {
  const HubSystemKickedFromRoom();
}

class HubSystemUnknown extends HubEventSystem {
  final String event;

  const HubSystemUnknown(this.event);
}

class HubSystemGlobalAdminChanged extends HubEventSystem {
  final String clientId;
  final bool isGlobalAdmin;

  const HubSystemGlobalAdminChanged({
    required this.clientId,
    required this.isGlobalAdmin,
  });

  factory HubSystemGlobalAdminChanged.fromJson(Map<String, dynamic> j) =>
      HubSystemGlobalAdminChanged(
        clientId: j['clientId'] as String,
        isGlobalAdmin: j['isGlobalAdmin'] as bool,
      );
}

class HubSystemBlacklistUpdated extends HubEventSystem {
  final List<String> blacklist;

  const HubSystemBlacklistUpdated(this.blacklist);

  factory HubSystemBlacklistUpdated.fromJson(Map<String, dynamic> j) =>
      HubSystemBlacklistUpdated(
        List<String>.from(j['blacklist'] as List? ?? []),
      );
}

class HubSystemRoomAdminChanged extends HubEventSystem {
  final String roomId;
  final String clientId;
  final bool isRoomAdmin;

  const HubSystemRoomAdminChanged({
    required this.roomId,
    required this.clientId,
    required this.isRoomAdmin,
  });

  factory HubSystemRoomAdminChanged.fromJson(Map<String, dynamic> j) =>
      HubSystemRoomAdminChanged(
        roomId: j['roomId'] as String,
        clientId: j['clientId'] as String,
        isRoomAdmin: j['isRoomAdmin'] as bool,
      );
}

class HubSystemYouAreMuted extends HubEventSystem {
  final int seconds;
  final String until;

  const HubSystemYouAreMuted({required this.seconds, required this.until});

  factory HubSystemYouAreMuted.fromJson(Map<String, dynamic> j) =>
      HubSystemYouAreMuted(
        seconds: j['seconds'] as int,
        until: j['until'] as String,
      );
}

class HubSystemUserMuted extends HubEventSystem {
  final String clientId;
  final bool isMuted;

  const HubSystemUserMuted({required this.clientId, required this.isMuted});

  factory HubSystemUserMuted.fromJson(
    Map<String, dynamic> j, {
    required bool muted,
  }) => HubSystemUserMuted(clientId: j['clientId'] as String, isMuted: muted);
}

class HubSystemRoomBanned extends HubEventSystem {
  final String roomId;
  final String roomName;
  final bool isBanned;

  const HubSystemRoomBanned({
    required this.roomId,
    required this.roomName,
    required this.isBanned,
  });

  factory HubSystemRoomBanned.fromJson(
    Map<String, dynamic> j, {
    required bool banned,
  }) => HubSystemRoomBanned(
    roomId: j['roomId'] as String,
    roomName: j['roomName'] as String,
    isBanned: banned,
  );
}

class HubSystemMessageRecalled extends HubEventSystem {
  final String messageId;

  const HubSystemMessageRecalled(this.messageId);

  factory HubSystemMessageRecalled.fromJson(Map<String, dynamic> j) =>
      HubSystemMessageRecalled(j['messageId'] as String);
}

class HubSystemRoomCreated extends HubEventSystem {
  final HubRoomDto room;

  const HubSystemRoomCreated(this.room);

  factory HubSystemRoomCreated.fromJson(Map<String, dynamic> j) =>
      HubSystemRoomCreated(
        HubRoomDto.fromJson(j['room'] as Map<String, dynamic>),
      );
}

class HubSystemRoomDeleted extends HubEventSystem {
  final String roomId;

  const HubSystemRoomDeleted(this.roomId);

  factory HubSystemRoomDeleted.fromJson(Map<String, dynamic> j) =>
      HubSystemRoomDeleted(j['roomId'] as String);
}

class HubSystemRoomUpdated extends HubEventSystem {
  final HubRoomDto room;

  const HubSystemRoomUpdated(this.room);

  factory HubSystemRoomUpdated.fromJson(Map<String, dynamic> j) =>
      HubSystemRoomUpdated(
        HubRoomDto.fromJson(j['room'] as Map<String, dynamic>),
      );
}

class HubSystemClientJoined extends HubEventSystem {
  final HubClientDto client;

  const HubSystemClientJoined(this.client);

  factory HubSystemClientJoined.fromJson(Map<String, dynamic> j) =>
      HubSystemClientJoined(
        HubClientDto.fromJson(j['client'] as Map<String, dynamic>),
      );
}

class HubSystemClientLeft extends HubEventSystem {
  final String clientId;
  final String? clientName;

  const HubSystemClientLeft({required this.clientId, this.clientName});

  factory HubSystemClientLeft.fromJson(Map<String, dynamic> j) =>
      HubSystemClientLeft(
        clientId: j['clientId'] as String,
        clientName: j['clientName'] as String?,
      );
}

class HubSystemClientRoomChanged extends HubEventSystem {
  final HubClientDto client;
  final String roomId;
  final bool joined;

  const HubSystemClientRoomChanged({
    required this.client,
    required this.roomId,
    required this.joined,
  });

  factory HubSystemClientRoomChanged.fromJson(
    Map<String, dynamic> payload, {
    required bool joined,
  }) => HubSystemClientRoomChanged(
    client: HubClientDto.fromJson(payload['client'] as Map<String, dynamic>),
    roomId: payload['roomId'] as String? ?? '',
    joined: joined,
  );
}

class HubSystemProfileUpdated extends HubEventSystem {
  final HubClientDto client;

  const HubSystemProfileUpdated(this.client);

  factory HubSystemProfileUpdated.fromJson(Map<String, dynamic> j) =>
      HubSystemProfileUpdated(
        HubClientDto.fromJson(j['client'] as Map<String, dynamic>),
      );
}

class HubSystemStatusChanged extends HubEventSystem {
  final String clientId;
  final UserStatus onlineStatus;

  const HubSystemStatusChanged({
    required this.clientId,
    required this.onlineStatus,
  });

  factory HubSystemStatusChanged.fromJson(Map<String, dynamic> j) =>
      HubSystemStatusChanged(
        clientId: j['clientId'] as String,
        onlineStatus:
            UserStatus.values.firstWhereOrNull(
              (e) => e.name == j['onlineStatus'],
            ) ??
            UserStatus.online,
      );
}

class HubSystemRoomAnnouncement extends HubEventSystem {
  final List<String> announcements;
  final String setByUserId;
  final String setByName;

  const HubSystemRoomAnnouncement({
    required this.announcements,
    required this.setByUserId,
    required this.setByName,
  });
}

class HubSystemRoomWelcome extends HubEventSystem {
  final String message;

  const HubSystemRoomWelcome({required this.message});
}

class HubSystemPoked extends HubEventSystem {
  final String fromId;
  final String fromName;

  const HubSystemPoked({required this.fromId, required this.fromName});
}

class HubSystemMentioned extends HubEventSystem {
  final String fromId;
  final String fromName;
  final String messageId;
  final String previewText;

  const HubSystemMentioned({
    required this.fromId,
    required this.fromName,
    required this.messageId,
    required this.previewText,
  });
}

sealed class HubSystemPayload {
  const HubSystemPayload();

  static HubSystemPayload? fromJson(Map<String, dynamic> json) {
    return switch (json['event'] as String?) {
      'client_joined' => ClientJoined.fromJson(json),
      'client_left' => ClientLeft.fromJson(json),
      'client_joined_room' => ClientJoinedRoom.fromJson(json),
      'client_left_room' => ClientLeftRoom.fromJson(json),
      'room_welcome' => RoomWelcome.fromJson(json),
      _ => null,
    };
  }
}

class ClientJoined extends HubSystemPayload {
  final String displayName;

  const ClientJoined({required this.displayName});

  factory ClientJoined.fromJson(Map<String, dynamic> j) => ClientJoined(
    displayName: (j['client'] as Map?)?['displayName'] as String? ?? '',
  );
}

class ClientLeft extends HubSystemPayload {
  final String clientName;

  const ClientLeft({required this.clientName});

  factory ClientLeft.fromJson(Map<String, dynamic> j) =>
      ClientLeft(clientName: j['clientName'] as String? ?? '');
}

class ClientJoinedRoom extends HubSystemPayload {
  final String displayName;

  const ClientJoinedRoom({required this.displayName});

  factory ClientJoinedRoom.fromJson(Map<String, dynamic> j) => ClientJoinedRoom(
    displayName: (j['client'] as Map?)?['displayName'] as String? ?? '',
  );
}

class ClientLeftRoom extends HubSystemPayload {
  final String clientName;

  const ClientLeftRoom({required this.clientName});

  factory ClientLeftRoom.fromJson(Map<String, dynamic> j) =>
      ClientLeftRoom(clientName: j['clientName'] as String? ?? '');
}

class RoomWelcome extends HubSystemPayload {
  final String message;

  const RoomWelcome({required this.message});

  factory RoomWelcome.fromJson(Map<String, dynamic> j) =>
      RoomWelcome(message: j['message'] as String? ?? '');
}
