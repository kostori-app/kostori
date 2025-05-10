class BangumiTag {
  final String name;

  final int count;

  final int totalCount;

  BangumiTag({
    required this.name,
    required this.count,
    required this.totalCount,
  });

  factory BangumiTag.fromJson(Map<String, dynamic> json) {
    return BangumiTag(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      totalCount: json['total_cont'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
      'total_cont': totalCount,
    };
  }

  @override
  String toString() {
    return 'BangumiTag{name: $name, count: $count, total_cont: $totalCount,}';
  }
}
