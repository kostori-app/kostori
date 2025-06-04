import 'package:kostori/foundation/bangumi/user_item.dart';

class ReviewsItem {
  final Entry entry;
  final int id;
  final ReviewsUser user;

  ReviewsItem({
    required this.entry,
    required this.id,
    required this.user,
  });

  factory ReviewsItem.fromJson(Map<String, dynamic> json) {
    return ReviewsItem(
      entry: Entry.fromJson(json['entry']),
      id: json['id'],
      user: ReviewsUser.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry': entry.toJson(),
      'id': id,
      'user': user.toJson(),
    };
  }

  @override
  String toString() {
    return 'ReviewsItem(entry: $entry, id: $id, user: $user)';
  }
}

class Entry {
  final int createdAt;
  final String icon;
  final int id;
  final bool isPublic;
  final int replies;
  final String summary;
  final String title;
  final int type;
  final int uid;
  final int updatedAt;

  Entry({
    required this.createdAt,
    required this.icon,
    required this.id,
    required this.isPublic,
    required this.replies,
    required this.summary,
    required this.title,
    required this.type,
    required this.uid,
    required this.updatedAt,
  });

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      createdAt: json['createdAt'],
      icon: json['icon'],
      id: json['id'],
      isPublic: json['public'],
      replies: json['replies'],
      summary: json['summary'],
      title: json['title'],
      type: json['type'],
      uid: json['uid'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt,
      'icon': icon,
      'id': id,
      'public': isPublic,
      'replies': replies,
      'summary': summary,
      'title': title,
      'type': type,
      'uid': uid,
      'updatedAt': updatedAt,
    };
  }

  @override
  String toString() {
    return 'Entry(title: $title, summary: $summary, public: $isPublic)';
  }
}
