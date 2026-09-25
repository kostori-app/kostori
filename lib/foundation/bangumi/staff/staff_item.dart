class StaffFullItem {
  final Staff staff;

  /// 该制作人员在本条目下的职位（如「导演」「音乐」），已按优先级排序
  final List<String> relations;

  StaffFullItem({required this.staff, required this.relations});
}

class Staff {
  final int id;
  final String name;
  final String nameCN;
  final Images? images;

  Staff({
    required this.id,
    required this.name,
    required this.nameCN,
    this.images,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] is int ? json['id'] as int : 0,
      name: json['name'] as String? ?? '',
      nameCN: json['nameCN'] as String? ?? '',
      images: json['images'] != null
          ? Images.fromJson(json['images'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Images {
  final String large;
  final String medium;
  final String small;
  final String grid;

  Images({
    required this.large,
    required this.medium,
    required this.small,
    required this.grid,
  });

  factory Images.fromJson(Map<String, dynamic> json) {
    return Images(
      large: json['large'] as String? ?? '',
      medium: json['medium'] as String? ?? '',
      small: json['small'] as String? ?? '',
      grid: json['grid'] as String? ?? '',
    );
  }
}

class Position {
  final PositionType type;
  final String summary;
  final String appearEps;

  Position({
    required this.type,
    required this.summary,
    required this.appearEps,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      type: json['type'] != null
          ? PositionType.fromJson(json['type'] as Map<String, dynamic>)
          : PositionType.fromTemplate(),
      summary: json['summary'] as String? ?? '',
      appearEps: json['appearEps'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type.toJson(), 'summary': summary, 'appearEps': appearEps};
  }
}

class PositionType {
  final int id;
  final String en;
  final String cn;
  final String jp;

  PositionType({
    required this.id,
    required this.en,
    required this.cn,
    required this.jp,
  });

  factory PositionType.fromJson(Map<String, dynamic> json) {
    return PositionType(
      id: json['id'] is int ? json['id'] as int : 0,
      en: json['en'] as String? ?? '',
      cn: json['cn'] as String? ?? '',
      jp: json['jp'] as String? ?? '',
    );
  }

  factory PositionType.fromTemplate() {
    return PositionType(id: 0, en: '', cn: '', jp: '');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'en': en, 'cn': cn, 'jp': jp};
  }
}
