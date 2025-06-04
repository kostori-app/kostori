import '../user_item.dart';

class ReviewsCommentsItem {
  final int id;
  final String content;
  final int createdAt;
  final int creatorID;
  final int mainID;
  final int relatedID;
  final int state;
  final InfoUser user;
  final List<Reaction> reactions;
  final List<ReviewsCommentsItem> replies;

  ReviewsCommentsItem({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.creatorID,
    required this.mainID,
    required this.relatedID,
    required this.state,
    required this.user,
    required this.reactions,
    required this.replies,
  });

  factory ReviewsCommentsItem.fromJson(Map<String, dynamic> json) {
    return ReviewsCommentsItem(
      id: json['id'],
      content: json['content'],
      createdAt: json['createdAt'],
      creatorID: json['creatorID'],
      mainID: json['mainID'],
      relatedID: json['relatedID'],
      state: json['state'],
      user: InfoUser.fromJson(json['user']),
      reactions: (json['reactions'] as List?)
              ?.map((e) => Reaction.fromJson(e))
              .toList() ??
          [],
      replies: (json['replies'] as List?)
              ?.map((e) => ReviewsCommentsItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt,
      'creatorID': creatorID,
      'mainID': mainID,
      'relatedID': relatedID,
      'state': state,
      'user': user.toJson(),
      'reactions': reactions.map((e) => e.toJson()).toList(),
      'replies': replies.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ReviewsCommentsItem(id: $id, content: $content, user: ${user.nickname}, replies: ${replies.length})';
  }
}

class Reaction {
  final int value;
  final List<User> users;

  Reaction({
    required this.value,
    required this.users,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      value: json['value'],
      users: (json['users'] as List<dynamic>)
          .map((e) => User.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'users': users.map((e) => e.toJson()).toList(),
    };
  }
}
