import 'avatar_item.dart';

class User {
  final int id;
  final String nickname;
  final String username;

  User({
    required this.id,
    required this.nickname,
    required this.username,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? 0,
        nickname: json['nickname'] ?? '',
        username: json['username'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'username': username,
      };
}

class InfoUser {
  final Avatar avatar;
  final int group;
  final int id;
  final int joinedAt;
  final String nickname;
  final String sign;
  final String username;

  InfoUser({
    required this.avatar,
    required this.group,
    required this.id,
    required this.joinedAt,
    required this.nickname,
    required this.sign,
    required this.username,
  });

  factory InfoUser.fromJson(Map<String, dynamic> json) {
    return InfoUser(
      avatar: Avatar.fromJson(json['avatar']),
      group: json['group'],
      id: json['id'],
      joinedAt: json['joinedAt'],
      nickname: json['nickname'],
      sign: json['sign'],
      username: json['username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avatar': avatar.toJson(),
      'group': group,
      'id': id,
      'joinedAt': joinedAt,
      'nickname': nickname,
      'sign': sign,
      'username': username,
    };
  }

  @override
  String toString() {
    return 'InfoUser(avatar: $avatar, group: $group, id: $id, joinedAt: $joinedAt, nickname: $nickname, sign: $sign, username: $username)';
  }
}
