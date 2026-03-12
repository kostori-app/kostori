part of 'package:kostori/foundation/services/services.dart';

enum HubSystemEvent {
  serverShutdown,
  globalAdminChanged,
  blacklistUpdated,
  roomAdminChanged,
  youAreMuted,
  youAreUnmuted,
  userMuted,
  userUnmuted,
  youAreRoomBanned,
  youAreRoomUnbanned,
  roomBanUpdated,
  kickedFromRoom,
  clientKickedFromRoom,
  messageRecalled,
  roomCreated,
  roomDeleted,
  roomUpdated,
  clientJoined,
  clientLeft,
  clientJoinedRoom,
  clientLeftRoom,
  profileUpdated,
  statusChanged,
  roomAnnouncement,
  roomWelcome,
  poked,
  mentioned,
  announcement;

  String get value => switch (this) {
    serverShutdown => 'server_shutdown',
    globalAdminChanged => 'global_admin_changed',
    blacklistUpdated => 'blacklist_updated',
    roomAdminChanged => 'room_admin_changed',
    youAreMuted => 'you_are_muted',
    youAreUnmuted => 'you_are_unmuted',
    userMuted => 'user_muted',
    userUnmuted => 'user_unmuted',
    youAreRoomBanned => 'you_are_room_banned',
    youAreRoomUnbanned => 'you_are_room_unbanned',
    roomBanUpdated => 'room_ban_updated',
    kickedFromRoom => 'kicked_from_room',
    clientKickedFromRoom => 'client_kicked_from_room',
    messageRecalled => 'message_recalled',
    roomCreated => 'room_created',
    roomDeleted => 'room_deleted',
    roomUpdated => 'room_updated',
    clientJoined => 'client_joined',
    clientLeft => 'client_left',
    clientJoinedRoom => 'client_joined_room',
    clientLeftRoom => 'client_left_room',
    profileUpdated => 'profile_updated',
    statusChanged => 'status_changed',
    roomAnnouncement => 'room_announcement',
    roomWelcome => 'room_welcome',
    poked => 'poked',
    mentioned => 'mentioned',
    announcement => 'announcement',
  };

  static HubSystemEvent? fromValue(String? v) => v == null
      ? null
      : HubSystemEvent.values.firstWhereOrNull((e) => e.value == v);
}

sealed class HubEvent {
  const HubEvent();

  factory HubEvent.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['messageType']) as String?;
    if (type == null) return const HubEventUnknown(null);
    return switch (type) {
      'welcome' => HubEventWelcome.fromJson(json),
      'room_joined' => HubEventRoomJoined.fromJson(json),
      'message' => HubEventMessage.fromJson(json, isUnicast: false),
      'chat' => HubEventMessage.fromJson(json, isUnicast: false),
      'unicast' => HubEventMessage.fromJson(json, isUnicast: true),
      'system' => HubEventSystem.fromEvent(
        HubSystemEvent.fromValue(json['event'] as String?),
        json,
      ),
      'kicked' => HubEventKicked.fromJson(json),
      'pong' => const HubEventPong(),
      'error' => HubEventError.fromJson(json),
      _ => HubEventUnknown(type),
    };
  }
}

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
        blacklist: List<String>.from(json['blacklist'] as List? ?? []),
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

  const HubEventUnknown(this.type);
}

sealed class HubEventSystem extends HubEvent {
  const HubEventSystem();

  factory HubEventSystem.fromEvent(
    HubSystemEvent? event,
    Map<String, dynamic> p,
  ) => switch (event) {
    HubSystemEvent.serverShutdown => const HubSystemServerShutdown(),
    HubSystemEvent.globalAdminChanged => HubSystemGlobalAdminChanged.fromJson(
      p,
    ),
    HubSystemEvent.blacklistUpdated => HubSystemBlacklistUpdated.fromJson(p),
    HubSystemEvent.roomAdminChanged => HubSystemRoomAdminChanged.fromJson(p),
    HubSystemEvent.youAreMuted => HubSystemYouAreMuted.fromJson(p),
    HubSystemEvent.youAreUnmuted => const HubSystemYouAreUnmuted(),
    HubSystemEvent.userMuted => HubSystemUserMuted.fromJson(p, muted: true),
    HubSystemEvent.userUnmuted => HubSystemUserMuted.fromJson(p, muted: false),
    HubSystemEvent.youAreRoomBanned => HubSystemYouAreRoomBanned.fromJson(
      p,
      banned: true,
    ),
    HubSystemEvent.youAreRoomUnbanned => HubSystemYouAreRoomBanned.fromJson(
      p,
      banned: false,
    ),
    HubSystemEvent.roomBanUpdated => HubSystemRoomBanUpdated.fromJson(p),
    HubSystemEvent.kickedFromRoom => HubSystemKickedFromRoom.fromJson(p),
    HubSystemEvent.clientKickedFromRoom =>
      HubSystemClientKickedFromRoom.fromJson(p),
    HubSystemEvent.messageRecalled => HubSystemMessageRecalled.fromJson(p),
    HubSystemEvent.roomCreated => HubSystemRoomCreated.fromJson(p),
    HubSystemEvent.roomDeleted => HubSystemRoomDeleted.fromJson(p),
    HubSystemEvent.roomUpdated => HubSystemRoomUpdated.fromJson(p),
    HubSystemEvent.clientJoined => HubSystemClientJoined.fromJson(p),
    HubSystemEvent.clientLeft => HubSystemClientLeft.fromJson(p),
    HubSystemEvent.clientJoinedRoom => HubSystemClientRoomChanged.fromJson(
      p,
      joined: true,
    ),
    HubSystemEvent.clientLeftRoom => HubSystemClientRoomChanged.fromJson(
      p,
      joined: false,
    ),
    HubSystemEvent.profileUpdated => HubSystemProfileUpdated.fromJson(p),
    HubSystemEvent.statusChanged => HubSystemStatusChanged.fromJson(p),
    HubSystemEvent.roomAnnouncement => HubSystemRoomAnnouncement.fromJson(p),
    HubSystemEvent.roomWelcome => HubSystemRoomWelcome.fromJson(p),
    HubSystemEvent.poked => HubSystemPoked.fromJson(p),
    HubSystemEvent.mentioned => HubSystemMentioned.fromJson(p),
    HubSystemEvent.announcement => HubSystemAnnouncement.fromJson(p),
    null => HubSystemUnknown(p['event'] as String? ?? ''),
  };
}

class HubSystemServerShutdown extends HubEventSystem {
  const HubSystemServerShutdown();
}

class HubSystemYouAreUnmuted extends HubEventSystem {
  const HubSystemYouAreUnmuted();
}

class HubSystemKickedFromRoom extends HubEventSystem {
  final String roomId;
  final String by;
  final String byName;
  final bool permanent;

  const HubSystemKickedFromRoom({
    required this.roomId,
    required this.by,
    required this.byName,
    required this.permanent,
  });

  factory HubSystemKickedFromRoom.fromJson(Map<String, dynamic> j) =>
      HubSystemKickedFromRoom(
        roomId: j['roomId'] as String? ?? '',
        by: j['by'] as String? ?? '',
        byName: j['byName'] as String? ?? '',
        permanent: j['permanent'] as bool? ?? false,
      );
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

class HubSystemYouAreRoomBanned extends HubEventSystem {
  final String roomId;
  final String roomName;
  final bool isBanned;

  const HubSystemYouAreRoomBanned({
    required this.roomId,
    required this.roomName,
    required this.isBanned,
  });

  factory HubSystemYouAreRoomBanned.fromJson(
    Map<String, dynamic> j, {
    required bool banned,
  }) => HubSystemYouAreRoomBanned(
    roomId: j['roomId'] as String,
    roomName: j['roomName'] as String,
    isBanned: banned,
  );
}

class HubSystemRoomBanUpdated extends HubEventSystem {
  final String clientId;
  final bool banned;
  final String by;

  const HubSystemRoomBanUpdated({
    required this.clientId,
    required this.banned,
    required this.by,
  });

  factory HubSystemRoomBanUpdated.fromJson(Map<String, dynamic> j) =>
      HubSystemRoomBanUpdated(
        clientId: j['clientId'] as String,
        banned: j['banned'] as bool? ?? true,
        by: j['by'] as String? ?? '',
      );
}

class HubSystemClientKickedFromRoom extends HubEventSystem {
  final String clientId;
  final String by;

  const HubSystemClientKickedFromRoom({
    required this.clientId,
    required this.by,
  });

  factory HubSystemClientKickedFromRoom.fromJson(Map<String, dynamic> j) =>
      HubSystemClientKickedFromRoom(
        clientId: j['clientId'] as String,
        by: j['by'] as String? ?? '',
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
    Map<String, dynamic> p, {
    required bool joined,
  }) => HubSystemClientRoomChanged(
    client: HubClientDto.fromJson(p['client'] as Map<String, dynamic>),
    roomId: p['roomId'] as String? ?? '',
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
  final String roomId;

  const HubSystemRoomAnnouncement({
    required this.announcements,
    required this.setByUserId,
    required this.setByName,
    required this.roomId,
  });

  factory HubSystemRoomAnnouncement.fromJson(Map<String, dynamic> j) =>
      HubSystemRoomAnnouncement(
        announcements: List<String>.from(j['announcements'] as List? ?? []),
        setByUserId: j['setByUserId'] as String? ?? '',
        setByName: j['setByName'] as String? ?? '',
        roomId: j['roomId'] as String? ?? '',
      );
}

class HubSystemRoomWelcome extends HubEventSystem {
  final String message;

  const HubSystemRoomWelcome({required this.message});

  factory HubSystemRoomWelcome.fromJson(Map<String, dynamic> j) =>
      HubSystemRoomWelcome(message: j['message'] as String? ?? '');
}

class HubSystemPoked extends HubEventSystem {
  final String fromId;
  final String fromName;

  const HubSystemPoked({required this.fromId, required this.fromName});

  factory HubSystemPoked.fromJson(Map<String, dynamic> j) => HubSystemPoked(
    fromId: j['fromId'] as String? ?? '',
    fromName: j['fromName'] as String? ?? '',
  );
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

  factory HubSystemMentioned.fromJson(Map<String, dynamic> j) =>
      HubSystemMentioned(
        fromId: j['fromId'] as String? ?? '',
        fromName: j['fromName'] as String? ?? '',
        messageId: j['messageId'] as String? ?? '',
        previewText: j['previewText'] as String? ?? '',
      );
}

class HubSystemAnnouncement extends HubEventSystem {
  final String text;
  final String by;

  const HubSystemAnnouncement({required this.text, required this.by});

  factory HubSystemAnnouncement.fromJson(Map<String, dynamic> j) =>
      HubSystemAnnouncement(
        text: j['announcement'] as String? ?? '',
        by: j['by'] as String? ?? '',
      );
}

// ── HubSystemPayload（供 HubSystemRow 渲染用）─────────────────────────────────

sealed class HubSystemPayload {
  const HubSystemPayload();

  static HubSystemPayload? fromJson(Map<String, dynamic> json) =>
      switch (HubSystemEvent.fromValue(json['event'] as String?)) {
        HubSystemEvent.clientJoined => HubPayloadClientJoined.fromJson(json),
        HubSystemEvent.clientLeft => HubPayloadClientLeft.fromJson(json),
        HubSystemEvent.clientJoinedRoom => HubPayloadClientJoinedRoom.fromJson(
          json,
        ),
        HubSystemEvent.clientLeftRoom => HubPayloadClientLeftRoom.fromJson(
          json,
        ),
        HubSystemEvent.roomWelcome => HubPayloadRoomWelcome.fromJson(json),
        HubSystemEvent.clientKickedFromRoom =>
          HubPayloadClientKickedFromRoom.fromJson(json),
        _ => null,
      };
}

class HubPayloadClientJoined extends HubSystemPayload {
  final String displayName;

  const HubPayloadClientJoined({required this.displayName});

  factory HubPayloadClientJoined.fromJson(Map<String, dynamic> j) =>
      HubPayloadClientJoined(
        displayName: (j['client'] as Map?)?['displayName'] as String? ?? '',
      );
}

class HubPayloadClientLeft extends HubSystemPayload {
  final String clientName;

  const HubPayloadClientLeft({required this.clientName});

  factory HubPayloadClientLeft.fromJson(Map<String, dynamic> j) =>
      HubPayloadClientLeft(clientName: j['clientName'] as String? ?? '');
}

class HubPayloadClientJoinedRoom extends HubSystemPayload {
  final String displayName;

  const HubPayloadClientJoinedRoom({required this.displayName});

  factory HubPayloadClientJoinedRoom.fromJson(Map<String, dynamic> j) =>
      HubPayloadClientJoinedRoom(
        displayName: (j['client'] as Map?)?['displayName'] as String? ?? '',
      );
}

class HubPayloadClientLeftRoom extends HubSystemPayload {
  final String clientName;

  const HubPayloadClientLeftRoom({required this.clientName});

  factory HubPayloadClientLeftRoom.fromJson(Map<String, dynamic> j) =>
      HubPayloadClientLeftRoom(clientName: j['clientName'] as String? ?? '');
}

class HubPayloadRoomWelcome extends HubSystemPayload {
  final String message;

  const HubPayloadRoomWelcome({required this.message});

  factory HubPayloadRoomWelcome.fromJson(Map<String, dynamic> j) =>
      HubPayloadRoomWelcome(message: j['message'] as String? ?? '');
}

class HubPayloadClientKickedFromRoom extends HubSystemPayload {
  final String clientName;
  final String operatorName;

  const HubPayloadClientKickedFromRoom({
    required this.clientName,
    required this.operatorName,
  });

  factory HubPayloadClientKickedFromRoom.fromJson(Map<String, dynamic> j) =>
      HubPayloadClientKickedFromRoom(
        clientName: j['clientName'] as String? ?? '',
        operatorName: j['operatorName'] as String? ?? '',
      );
}
