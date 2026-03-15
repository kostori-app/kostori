part of 'package:kostori/foundation/services/services.dart';

// ── HubMessage ────────────────────────────────────

class HubMessage {
  final String messageId;
  final HubMessageType messageType;
  final HubClientDto sender;
  final List<String> targetRoomIds;
  final List<MessageSegment> segments;
  final DateTime sentAt;
  final String? replyToMessageId;
  List<HubReaction> reactions;

  HubMessage({
    String? messageId,
    required this.messageType,
    required this.sender,
    required this.targetRoomIds,
    required this.segments,
    DateTime? sentAt,
    this.replyToMessageId,
    List<HubReaction>? reactions,
  }) : messageId = messageId ?? _generateId(),
       sentAt = sentAt ?? DateTime.now(),
       reactions = reactions ?? [];

  static String _generateId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      Random().nextInt(9999).toString().padLeft(4, '0');

  String get plainText =>
      segments.whereType<TextSegment>().map((s) => s.text).join('');

  bool toggleReaction(String emojiId, HubReactionUser user) {
    final idx = reactions.indexWhere((r) => r.emojiId == emojiId);
    if (idx >= 0) {
      final updated = reactions[idx].toggle(user);
      if (updated.isEmpty) {
        reactions.removeAt(idx);
      } else {
        reactions[idx] = updated;
      }
      return updated.users.any((u) => u.userId == user.userId);
    } else {
      reactions.add(HubReaction(emojiId: emojiId, users: [user]));
      return true;
    }
  }

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'messageType': messageType.name,
    'sender': sender.toJson(),
    'targetRoomIds': targetRoomIds,
    'segments': segments.map((s) => s.toJson()).toList(),
    'sentAt': sentAt.toIso8601String(),
    if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    if (reactions.isNotEmpty)
      'reactions': reactions.map((r) => r.toJson()).toList(),
  };

  factory HubMessage.fromJson(Map<String, dynamic> json) => HubMessage(
    messageId: json['messageId'] as String?,
    messageType: HubMessageType.values.firstWhere(
      (e) => e.name == json['messageType'],
      orElse: () => HubMessageType.chat,
    ),
    sender: HubClientDto.fromJson(json['sender'] as Map<String, dynamic>),
    targetRoomIds: List<String>.from(json['targetRoomIds'] as List? ?? []),
    segments: (json['segments'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MessageSegment.fromJson)
        .toList(),
    sentAt: json['sentAt'] != null
        ? DateTime.parse(json['sentAt'] as String)
        : null,
    replyToMessageId: json['replyToMessageId'] as String?,
    reactions: (json['reactions'] as List? ?? [])
        .map((r) => HubReaction.fromJson(r as Map<String, dynamic>))
        .toList(),
  );
}

class HubReactionUser {
  final String userId;
  final String username;

  const HubReactionUser({required this.userId, required this.username});

  factory HubReactionUser.fromJson(Map<String, dynamic> json) =>
      HubReactionUser(
        userId: json['id'].toString(),
        username: json['username'] as String,
      );

  Map<String, dynamic> toJson() => {'id': userId, 'username': username};
}

class HubReaction {
  final String emojiId;
  final List<HubReactionUser> users;

  const HubReaction({required this.emojiId, required this.users});

  factory HubReaction.fromJson(Map<String, dynamic> json) => HubReaction(
    emojiId: json['emojiId'] as String,
    users: (json['users'] as List? ?? [])
        .map((u) => HubReactionUser.fromJson(u as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'emojiId': emojiId,
    'users': users.map((u) => u.toJson()).toList(),
  };

  HubReaction toggle(HubReactionUser user) {
    final exists = users.any((u) => u.userId == user.userId);
    return HubReaction(
      emojiId: emojiId,
      users: exists
          ? users.where((u) => u.userId != user.userId).toList()
          : [...users, user],
    );
  }

  bool get isEmpty => users.isEmpty;
}

enum SegmentType { text, image, reaction, mention, quote }

abstract class MessageSegment {
  final SegmentType type;

  const MessageSegment(this.type);

  Map<String, dynamic> toJson();

  factory MessageSegment.fromJson(Map<String, dynamic> json) {
    final type = SegmentType.values.firstWhere((e) => e.name == json['type']);
    return switch (type) {
      SegmentType.text => TextSegment.fromJson(json['data']),
      SegmentType.image => ImageSegment.fromJson(json['data']),
      SegmentType.reaction => ReactionSegment.fromJson(json['data']),
      SegmentType.mention => MentionSegment.fromJson(json['data']),
      SegmentType.quote => QuoteSegment.fromJson(json['data']),
    };
  }
}

class ReactionSegment extends MessageSegment {
  final String targetMessageId;
  final String emojiId;
  final String reactorUserId;

  const ReactionSegment({
    required this.targetMessageId,
    required this.emojiId,
    required this.reactorUserId,
  }) : super(SegmentType.reaction);

  factory ReactionSegment.fromJson(Map<String, dynamic> json) =>
      ReactionSegment(
        targetMessageId: json['targetMessageId'] as String,
        emojiId: json['emojiId'] as String,
        reactorUserId: json['reactorUserId'] as String,
      );

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': {
      'targetMessageId': targetMessageId,
      'emojiId': emojiId,
      'reactorUserId': reactorUserId,
    },
  };
}

// ── 各种 Segment 实现 ──────────────────────────

class TextSegment extends MessageSegment {
  final String text;

  const TextSegment(this.text) : super(SegmentType.text);

  factory TextSegment.fromJson(Map<String, dynamic> json) =>
      TextSegment(json['text'] as String);

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': {'text': text},
  };
}

class ImageSegment extends MessageSegment {
  final String url;
  final int? width;
  final int? height;
  final String? alt;

  const ImageSegment({required this.url, this.width, this.height, this.alt})
    : super(SegmentType.image);

  factory ImageSegment.fromJson(Map<String, dynamic> json) => ImageSegment(
    url: json['url'] as String,
    width: json['width'] as int?,
    height: json['height'] as int?,
    alt: json['alt'] as String?,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': {'url': url, 'width': width, 'height': height, 'alt': alt},
  };
}

class MentionSegment extends MessageSegment {
  final String userId;
  final String displayName;

  const MentionSegment({required this.userId, required this.displayName})
    : super(SegmentType.mention);

  factory MentionSegment.fromJson(Map<String, dynamic> json) => MentionSegment(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': {'userId': userId, 'displayName': displayName},
  };
}

class QuoteSegment extends MessageSegment {
  final String messageId;
  final String fromName;
  final String preview;

  const QuoteSegment({
    required this.messageId,
    required this.fromName,
    required this.preview,
  }) : super(SegmentType.quote);

  factory QuoteSegment.fromJson(Map<String, dynamic> json) => QuoteSegment(
    messageId: json['messageId'] as String,
    fromName: json['fromName'] as String,
    preview: json['preview'] as String,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': {'messageId': messageId, 'fromName': fromName, 'preview': preview},
  };
}
