class Avatar {
  final String large;
  final String medium;
  final String small;

  Avatar({
    required this.large,
    required this.medium,
    required this.small,
  });

  factory Avatar.fromJson(Map<String, dynamic> json) => Avatar(
        large: json['large'] ?? '',
        medium: json['medium'] ?? '',
        small: json['small'] ?? '',
      );

  factory Avatar.empty() => Avatar(large: '', medium: '', small: '');

  Map<String, dynamic> toJson() => {
        'large': large,
        'medium': medium,
        'small': small,
      };
}
