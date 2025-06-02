import 'package:kostori/foundation/bangumi/creator_item.dart';

class TopicsItem {
  int createdAt;
  Creator creator;
  int creatorID;
  int display;
  int id;
  int parentID;
  int replyCount;
  int state;
  String title;
  int updatedAt;

  TopicsItem({
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
  });

  factory TopicsItem.fromJson(Map<String, dynamic> json) {
    return TopicsItem(
      createdAt: json['createdAt'] ?? 0,
      creator: Creator.fromJson(json['creator'] ?? {}),
      creatorID: json['creatorID'] ?? 0,
      display: json['display'] ?? 0,
      id: json['id'] ?? 0,
      parentID: json['parentID'] ?? 0,
      replyCount: json['replyCount'] ?? 0,
      state: json['state'] ?? 0,
      title: json['title'] ?? '',
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
    };
  }

  @override
  String toString() {
    return 'TopicsItem(id: $id, title: $title, creator: $creator, replyCount: $replyCount)';
  }
}
