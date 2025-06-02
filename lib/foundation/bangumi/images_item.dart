class Images {
  final String common;
  final String grid;
  final String large;
  final String medium;
  final String small;

  Images({
    required this.common,
    required this.grid,
    required this.large,
    required this.medium,
    required this.small,
  });

  factory Images.fromJson(Map<String, dynamic> json) => Images(
        common: json['common'],
        grid: json['grid'],
        large: json['large'],
        medium: json['medium'],
        small: json['small'],
      );

  Map<String, dynamic> toJson() => {
        'common': common,
        'grid': grid,
        'large': large,
        'medium': medium,
        'small': small,
      };
}
