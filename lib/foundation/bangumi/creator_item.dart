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
        group: json['group'] ?? 0,
        id: json['id'] ?? 0,
        joinedAt: json['joinedAt'] ?? 0,
        nickname: json['nickname'] ?? '',
        sign: json['sign'] ?? '',
        username: json['username'] ?? '',
      );

  factory Creator.empty() => Creator(
        id: 0,
        username: '',
        nickname: '',
        avatar: Avatar.empty(),
        group: 0,
        sign: '',
        joinedAt: 0,
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
