import 'package:kostori/foundation/bangumi/creator_item.dart';
import 'package:kostori/foundation/bangumi/subject_item.dart';
import 'package:kostori/foundation/bangumi/user_item.dart';

class TopicsInfoItem {
  final int createdAt;
  final Creator creator;
  final int creatorID;
  final int display;
  final int id;
  final int parentID;
  final int replyCount;
  final int state;
  final String title;
  final int updatedAt;
  final List<TopicReply> replies;
  final Subject subject;

  TopicsInfoItem({
    required this.createdAt,
    required this.creator,
    required this.creatorID,
    required this.display,
    required this.id,
    required this.parentID,
    required this.replyCount,
    required this.state,
    required this.title,
    required this.updatedAt,
    required this.replies,
    required this.subject,
  });

  factory TopicsInfoItem.fromJson(Map<String, dynamic> json) {
    return TopicsInfoItem(
      createdAt: json['createdAt'] ?? 0,
      creator: json['creator'] != null
          ? Creator.fromJson(json['creator'] as Map<String, dynamic>)
          : Creator.empty(),
      creatorID: json['creatorID'] ?? 0,
      display: json['display'] ?? 0,
      id: json['id'] ?? 0,
      parentID: json['parentID'] ?? 0,
      replyCount: json['replyCount'] ?? 0,
      state: json['state'] ?? 0,
      title: json['title'] ?? '',
      updatedAt: json['updatedAt'] ?? 0,
      replies:
          (json['replies'] as List?)?.map((e) {
            // 安全处理嵌套回复的 null
            return TopicReply.fromJson(e as Map<String, dynamic>? ?? {});
          }).toList() ??
          [],
      subject: json['subject'] != null
          ? Subject.fromJson(json['subject'] as Map<String, dynamic>)
          : Subject.empty(), // 也要创建默认值
    );
  }

  Map<String, dynamic> toJson() => {
    'createdAt': createdAt,
    'creator': creator.toJson(),
    'creatorID': creatorID,
    'display': display,
    'id': id,
    'parentID': parentID,
    'replyCount': replyCount,
    'state': state,
    'title': title,
    'updatedAt': updatedAt,
    'replies': replies.map((e) => e.toJson()).toList(),
    'subject': subject.toJson(),
  };

  @override
  String toString() => toJson().toString();
}

class TopicReply {
  final String content;
  final int createdAt;
  final Creator creator;
  final int creatorID;
  final int id;
  final List<Reaction> reactions;
  final int state;
  final List<TopicReply> replies;

  TopicReply({
    required this.content,
    required this.createdAt,
    required this.creator,
    required this.creatorID,
    required this.id,
    required this.reactions,
    required this.state,
    required this.replies,
  });

  factory TopicReply.fromJson(Map<String, dynamic> json) => TopicReply(
    content: json['content'] ?? '',
    createdAt: json['createdAt'] ?? 0,
    creator: json['creator'] != null
        ? Creator.fromJson(json['creator'] as Map<String, dynamic>)
        : Creator.empty(),
    creatorID: json['creatorID'] ?? 0,
    id: json['id'] ?? 0,
    reactions:
        (json['reactions'] as List?)?.map((e) {
          return Reaction.fromJson(e as Map<String, dynamic>? ?? {});
        }).toList() ??
        [],
    state: json['state'] ?? 0,
    replies:
        (json['replies'] as List?)
            ?.map((e) => TopicReply.fromJson(e))
            .toList() ??
        [],
  );

  Map<String, dynamic> toJson() => {
    'content': content,
    'createdAt': createdAt,
    'creator': creator.toJson(),
    'creatorID': creatorID,
    'id': id,
    'reactions': reactions.map((e) => e.toJson()).toList(),
    'state': state,
    'replies': replies.map((e) => e.toJson()).toList(),
  };
}

class Reaction {
  final List<User> users;
  final int value;

  Reaction({required this.users, required this.value});

  factory Reaction.fromJson(Map<String, dynamic> json) => Reaction(
    users:
        (json['users'] as List?)?.map((e) => User.fromJson(e)).toList() ?? [],
    value: json['value'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'users': users.map((e) => e.toJson()).toList(),
    'value': value,
  };
}
