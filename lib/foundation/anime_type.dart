import 'package:kostori/foundation/anime_source/anime_source.dart';

class AnimeType {
  final int value;

  const AnimeType(this.value);

  @override
  bool operator ==(Object other) => other is AnimeType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  String get sourceKey {
    if (this == local) {
      return "local";
    } else {
      return animeSource!.key;
    }
  }

  AnimeSource? get animeSource {
    if (this == local) {
      return null;
    } else {
      return AnimeSource.fromIntKey(value);
    }
  }

  static const local = AnimeType(0);

  factory AnimeType.fromKey(String key) {
    if (key == "local") {
      return local;
    } else {
      return AnimeType(key.hashCode);
    }
  }
}
