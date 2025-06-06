import '../bangumi_item.dart';
import 'character_item.dart';

class CharacterCastsItem {
  final List<CharacterActor> actors;
  final BangumiItem subject;
  final int type;

  CharacterCastsItem({
    required this.actors,
    required this.subject,
    required this.type,
  });

  factory CharacterCastsItem.fromJson(Map<String, dynamic> json) {
    return CharacterCastsItem(
      actors: (json['actors'] as List<dynamic>)
          .map((e) => CharacterActor.fromJson(e))
          .toList(),
      subject: BangumiItem.fromJson(json['subject']),
      type: json['type'] ?? 0,
    );
  }

  @override
  String toString() =>
      'CharacterCastsItem(type: $type, subject: ${subject.toString()}, actors: $actors)';
}

class CharacterActor {
  final int id;
  final String name;
  final String nameCN;
  final int comment;
  final int type;
  final bool nsfw;
  final bool lock;
  final String info;
  final CharacterAvator images;

  CharacterActor({
    required this.id,
    required this.name,
    required this.nameCN,
    required this.comment,
    required this.type,
    required this.nsfw,
    required this.lock,
    required this.info,
    required this.images,
  });

  factory CharacterActor.fromJson(Map<String, dynamic> json) {
    return CharacterActor(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameCN: json['nameCN'] ?? '',
      comment: json['comment'] ?? 0,
      type: json['type'] ?? 0,
      nsfw: json['nsfw'] ?? false,
      lock: json['lock'] ?? false,
      info: json['info'] ?? '',
      images: CharacterAvator.fromJson(json['images'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameCN': nameCN,
      'comment': comment,
      'type': type,
      'nsfw': nsfw,
      'lock': lock,
      'info': info,
      'images': images.toJson(),
    };
  }

  @override
  String toString() => 'CharacterActor(name: $name, nameCN: $nameCN)';
}
