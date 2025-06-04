import 'package:kostori/foundation/bangumi/user_item.dart';

class ReviewsInfoItem {
  final String content;
  final int createdAt;
  final String icon;
  final int id;
  final int noreply;
  final bool isPublic;
  final int related;
  final int replies;
  final List<String> tags;
  final String title;
  final int type;
  final int updatedAt;
  final ReviewsUser user;
  final int views;

  ReviewsInfoItem({
    required this.content,
    required this.createdAt,
    required this.icon,
    required this.id,
    required this.noreply,
    required this.isPublic,
    required this.related,
    required this.replies,
    required this.tags,
    required this.title,
    required this.type,
    required this.updatedAt,
    required this.user,
    required this.views,
  });

  factory ReviewsInfoItem.fromJson(Map<String, dynamic> json) {
    return ReviewsInfoItem(
      content: json['content'],
      createdAt: json['createdAt'],
      icon: json['icon'],
      id: json['id'],
      noreply: json['noreply'],
      isPublic: json['public'],
      related: json['related'],
      replies: json['replies'],
      tags: List<String>.from(json['tags']),
      title: json['title'],
      type: json['type'],
      updatedAt: json['updatedAt'],
      user: ReviewsUser.fromJson(json['user']),
      views: json['views'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'createdAt': createdAt,
      'icon': icon,
      'id': id,
      'noreply': noreply,
      'public': isPublic,
      'related': related,
      'replies': replies,
      'tags': tags,
      'title': title,
      'type': type,
      'updatedAt': updatedAt,
      'user': user.toJson(),
      'views': views,
    };
  }

  @override
  String toString() {
    return 'ReviewsInfoItem(title: $title, user: ${user.nickname}, views: $views)';
  }
}
