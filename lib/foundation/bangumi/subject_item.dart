import 'images_item.dart';

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
        id: json['id'],
        images: Images.fromJson(json['images']),
        locked: json['locked'],
        name: json['name'],
        nameCN: json['nameCN'],
        nsfw: json['nsfw'],
        type: json['type'],
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
