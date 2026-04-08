import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/character/character_item.dart';
import 'package:kostori/i18n/strings.g.dart';

class CharacterCastsItem {
  final List<CharacterCast> casts;
  final BangumiItem subject;
  final int type;

  CharacterCastsItem({
    required this.casts,
    required this.subject,
    required this.type,
  });

  factory CharacterCastsItem.fromJson(Map<String, dynamic> json) {
    return CharacterCastsItem(
      casts: (json['casts'] as List? ?? [])
          .map((e) => CharacterCast.fromJson(e))
          .toList(),
      subject: BangumiItem.fromJson(json['subject'] ?? {}),
      type: json['type'] ?? 0,
    );
  }

  @override
  String toString() =>
      'CharacterCastsItem(type: $type, subject: ${subject.toString()}, casts: $casts)';
}

class CharacterCast {
  final CharacterActor person;
  final CastRelationType relation;
  final String summary;

  CharacterCast({
    required this.person,
    required this.relation,
    required this.summary,
  });

  factory CharacterCast.fromJson(Map<String, dynamic> json) {
    return CharacterCast(
      person: CharacterActor.fromJson(json['person'] ?? {}),
      relation: CastRelationTypeExtension.fromInt(json['relation'] ?? 0),
      summary: json['summary'] ?? '',
    );
  }
}

enum CastRelationType {
  cv, // 0 原声 CV
  actor, // 2 演员
  dub, // 1 配音
  chineseDub, // 3 中文配音
  japaneseDub, // 4 日语配音
  englishDub, // 5 英语配音
  koreanDub, // 6 韩语配音
}

extension CastRelationTypeExtension on CastRelationType {
  static CastRelationType fromInt(int value) {
    switch (value) {
      case 0:
        return CastRelationType.cv;
      case 2:
        return CastRelationType.actor;
      case 1:
        return CastRelationType.dub;
      case 3:
        return CastRelationType.chineseDub;
      case 4:
        return CastRelationType.japaneseDub;
      case 5:
        return CastRelationType.englishDub;
      case 6:
        return CastRelationType.koreanDub;
      default:
        return CastRelationType.cv;
    }
  }

  int toInt() {
    switch (this) {
      case CastRelationType.cv:
        return 0;
      case CastRelationType.actor:
        return 2;
      case CastRelationType.dub:
        return 1;
      case CastRelationType.chineseDub:
        return 3;
      case CastRelationType.japaneseDub:
        return 4;
      case CastRelationType.englishDub:
        return 5;
      case CastRelationType.koreanDub:
        return 6;
    }
  }

  String get nameStr {
    switch (this) {
      case CastRelationType.cv:
        return t.cv;
      case CastRelationType.actor:
        return t.actor;
      case CastRelationType.dub:
        return t.dub;
      case CastRelationType.chineseDub:
        return t.chineseDub;
      case CastRelationType.japaneseDub:
        return t.japaneseDub;
      case CastRelationType.englishDub:
        return t.englishDub;
      case CastRelationType.koreanDub:
        return t.koreanDub;
    }
  }
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
      nameCN: json['nameCN'] ?? json['name'] ?? '',
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

class CharacterPersonCastsItem {
  final CharacterActor character;
  final List<CharacterRelationItem> relations;

  CharacterPersonCastsItem({required this.character, required this.relations});

  factory CharacterPersonCastsItem.fromJson(Map<String, dynamic> json) {
    return CharacterPersonCastsItem(
      character: CharacterActor.fromJson(json['character'] ?? {}),
      relations: (json['relations'] as List? ?? [])
          .map((e) => CharacterRelationItem.fromJson(e))
          .toList(),
    );
  }
}

class CharacterRelationItem {
  final BangumiItem subject;
  final int type;

  CharacterRelationItem({required this.subject, required this.type});

  factory CharacterRelationItem.fromJson(Map<String, dynamic> json) {
    return CharacterRelationItem(
      subject: BangumiItem.fromJson(json['subject'] ?? {}),
      type: json['type'] ?? 0,
    );
  }
}
