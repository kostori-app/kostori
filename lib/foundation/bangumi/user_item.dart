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
        id: json['id'],
        nickname: json['nickname'],
        username: json['username'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'username': username,
      };
}
