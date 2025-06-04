import '../user_item.dart';

class Comment {
  final int rate;
  final String comment;
  final int updatedAt;

  Comment({
    required this.rate,
    required this.comment,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      rate: json['rate'] ?? 0,
      comment: json['comment'] ?? '',
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rate': rate,
      'comment': comment,
      'updatedAt': updatedAt,
    };
  }
}

class CommentItem {
  final InfoUser user;
  final Comment comment;

  CommentItem({
    required this.user,
    required this.comment,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    return CommentItem(
      user: InfoUser.fromJson(json['user']),
      comment: Comment.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'comment': comment.toJson(),
    };
  }
}

class EpisodeComment {
  final InfoUser user;
  final String comment;
  final int createdAt;
  final int creatorID;

  EpisodeComment(
      {required this.user,
      required this.comment,
      required this.createdAt,
      required this.creatorID});

  factory EpisodeComment.fromJson(Map<String, dynamic> json) {
    return EpisodeComment(
      user: InfoUser.fromJson(json['user']),
      comment: json['content'] ?? '',
      createdAt: json['createdAt'] ?? 0,
      creatorID: json['creatorID'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'content': comment,
      'createdAt': createdAt,
      'creatorID': creatorID
    };
  }
}

class EpisodeCommentItem {
  final EpisodeComment comment;
  final List<EpisodeComment> replies;

  EpisodeCommentItem({required this.comment, required this.replies});

  factory EpisodeCommentItem.fromJson(Map<String, dynamic> json) {
    var list = json['replies'] as List;
    List<EpisodeComment> tempList =
        list.map((i) => EpisodeComment.fromJson(i)).toList();
    return EpisodeCommentItem(
        comment: EpisodeComment.fromJson(json), replies: tempList);
  }

  Map<String, dynamic> toJson() {
    return {
      'comment': comment.toJson(),
      'list': replies,
    };
  }
}

class CharacterComment {
  final InfoUser user;
  final String comment;
  final int createdAt;

  CharacterComment({
    required this.user,
    required this.comment,
    required this.createdAt,
  });

  factory CharacterComment.fromJson(Map<String, dynamic> json) {
    return CharacterComment(
      user: InfoUser.fromJson(json['user']),
      comment: json['content'] ?? '',
      createdAt: json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'content': comment,
      'createdAt': createdAt,
    };
  }
}

class CharacterCommentItem {
  final CharacterComment comment;
  final List<CharacterComment> replies;

  CharacterCommentItem({required this.comment, required this.replies});

  factory CharacterCommentItem.fromJson(Map<String, dynamic> json) {
    var list = json['replies'] as List;
    List<CharacterComment> tempList =
        list.map((i) => CharacterComment.fromJson(i)).toList();
    return CharacterCommentItem(
        comment: CharacterComment.fromJson(json), replies: tempList);
  }

  Map<String, dynamic> toJson() {
    return {
      'comment': comment.toJson(),
      'list': replies,
    };
  }
}
