class CharacterFullItem {
  final int id;
  final String name;
  final String nameCN;
  final String info;
  final String summary;
  final String image;
  final List<CharacterInfoboxItem> infobox;

  CharacterFullItem({
    required this.id,
    required this.name,
    required this.nameCN,
    required this.info,
    required this.summary,
    required this.image,
    required this.infobox,
  });

  factory CharacterFullItem.fromJson(Map<String, dynamic> json) {
    return CharacterFullItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameCN: json['nameCN'] ?? json['name'] ?? '',
      info: json['info'] ?? '',
      summary: json['summary'] ?? '',
      image: (json['images']?['large']) ?? '',
      infobox: (json['infobox'] as List? ?? [])
          .map((e) => CharacterInfoboxItem.fromJson(e))
          .where((e) => e.values.isNotEmpty)
          .toList(),
    );
  }

  factory CharacterFullItem.fromTemplate() {
    return CharacterFullItem(
      id: 0,
      name: '',
      nameCN: '',
      info: '',
      summary: '',
      image: '',
      infobox: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameCN': nameCN,
      'info': info,
      'summary': summary,
      'infobox': infobox.map((e) => e.toJson()).toList(),
    };
  }
}

class CharacterInfoboxItem {
  final String key;
  final List<CharacterInfoboxValue> values;

  CharacterInfoboxItem({required this.key, required this.values});

  factory CharacterInfoboxItem.fromJson(Map<String, dynamic> json) {
    final values = (json['values'] as List? ?? [])
        .map((e) => CharacterInfoboxValue.fromJson(e))
        .where((v) => v.value.isNotEmpty)
        .toList();

    return CharacterInfoboxItem(key: json['key'] ?? '', values: values);
  }

  Map<String, dynamic> toJson() {
    return {'key': key, 'values': values.map((e) => e.toJson()).toList()};
  }
}

class CharacterInfoboxValue {
  final String value;
  final String? label;

  CharacterInfoboxValue({required this.value, this.label});

  factory CharacterInfoboxValue.fromJson(Map<String, dynamic> json) {
    return CharacterInfoboxValue(value: json['v'] ?? '', label: json['k']);
  }

  Map<String, dynamic> toJson() {
    return {'v': value, if (label != null) 'k': label};
  }
}
