import 'avatar_item.dart';

class Creator {
  final Avatar avatar;
  final int group;
  final int id;
  final int joinedAt;
  final String nickname;
  final String sign;
  final String username;

  Creator({
    required this.avatar,
    required this.group,
    required this.id,
    required this.joinedAt,
    required this.nickname,
    required this.sign,
    required this.username,
  });

  factory Creator.fromJson(Map<String, dynamic> json) => Creator(
        avatar: Avatar.fromJson(json['avatar']),
        group: json['group'],
        id: json['id'],
        joinedAt: json['joinedAt'],
        nickname: json['nickname'],
        sign: json['sign'],
        username: json['username'],
      );

  Map<String, dynamic> toJson() => {
        'avatar': avatar.toJson(),
        'group': group,
        'id': id,
        'joinedAt': joinedAt,
        'nickname': nickname,
        'sign': sign,
        'username': username,
      };
}
