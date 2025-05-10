import 'package:kostori/foundation/anime_source/anime_source.dart';

class AnimeType {
  final int value;

  const AnimeType(this.value);

  @override
  bool operator ==(Object other) => other is AnimeType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  String get sourceKey {
    return animeSource!.key;
  }

  AnimeSource? get animeSource {
    return AnimeSource.fromIntKey(value);
  }

  factory AnimeType.fromKey(String key) {
    return AnimeType(key.hashCode);
  }
}
