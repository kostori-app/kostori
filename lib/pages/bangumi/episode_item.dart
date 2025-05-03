class EpisodeInfo {
  int id;
  num episode;
  int type;
  String name;
  String nameCn;
  String airDate;
  String duration;

  EpisodeInfo(
      {required this.id,
      required this.episode,
      required this.type,
      required this.name,
      required this.nameCn,
      required this.airDate,
      required this.duration});

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    return EpisodeInfo(
        id: json['id'] ?? 0,
        episode: json['sort'] ?? 0,
        type: json['type'] ?? 0,
        name: json['name'] ?? '',
        nameCn: json['name_cn'] ?? '',
        airDate: json['airdate'] ?? '',
        duration: json['duration'] ?? '');
    ;
  }

  factory EpisodeInfo.fromTemplate() {
    return EpisodeInfo(
        id: 0,
        episode: 0,
        type: 0,
        name: '',
        nameCn: '',
        airDate: '',
        duration: '');
  }

  void reset() {
    id = 0;
    episode = 0;
    type = 0;
    name = '';
    nameCn = '';
  }

  String readType() {
    switch (type) {
      case 0:
        return 'ep';
      case 1:
        return 'sp';
      case 2:
        return 'op';
      case 3:
        return 'ed';
      default:
        return '';
    }
  }
}
