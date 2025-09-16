import 'package:kostori/foundation/bangumi/images_item.dart';

class Subject {
  final int id;
  final Images images;
  final bool locked;
  final String name;
  final String nameCN;
  final bool nsfw;
  final int type;

  Subject({
    required this.id,
    required this.images,
    required this.locked,
    required this.name,
    required this.nameCN,
    required this.nsfw,
    required this.type,
  });

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] ?? 0,
        images: (json['images'] != null)
            ? Images.fromJson(json['images'])
            : Images.empty(),
        locked: json['locked'] ?? false,
        name: json['name'] ?? '',
        nameCN: json['nameCN'] ?? '',
        nsfw: json['nsfw'] ?? false,
        type: json['type'] ?? 0,
      );

  factory Subject.empty() => Subject(
        id: 0,
        images: Images.empty(),
        locked: false,
        name: '',
        nameCN: '',
        nsfw: false,
        type: 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'images': images.toJson(),
        'locked': locked,
        'name': name,
        'nameCN': nameCN,
        'nsfw': nsfw,
        'type': type,
      };
}
