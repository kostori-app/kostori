class EpisodeInfo {
  int id;
  num sort;
  int ep;
  int comment;
  int type;
  String name;
  String nameCn;
  String airDate;
  String duration;
  String desc;

  EpisodeInfo(
      {required this.id,
      required this.sort,
      required this.ep,
      required this.comment,
      required this.type,
      required this.name,
      required this.nameCn,
      required this.airDate,
      required this.duration,
      required this.desc});

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    return EpisodeInfo(
        id: json['id'] ?? 0,
        sort: json['sort'] ?? 0,
        type: json['type'] ?? 0,
        name: json['name'] ?? '',
        nameCn: json['name_cn'] ?? '',
        airDate: json['airdate'] ?? '',
        duration: json['duration'] ?? '',
        desc: json['desc'] ?? '',
        ep: json['ep'] ?? 0,
        comment: json['comment'] ?? 0);
  }

  factory EpisodeInfo.fromTemplate() {
    return EpisodeInfo(
        id: 0,
        sort: 0,
        type: 0,
        name: '',
        nameCn: '',
        airDate: '',
        duration: '',
        desc: '',
        ep: 0,
        comment: 0);
  }

  void reset() {
    id = 0;
    sort = 0;
    type = 0;
    name = '';
    nameCn = '';
    desc = '';
    ep = 0;
    comment = 0;
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
