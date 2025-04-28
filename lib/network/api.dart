class Api {
  // 新条目搜索post
  static const String bangumiRankSearch =
      'https://api.bgm.tv/v0/search/subjects?limit={0}&offset={1}';

  //旧搜索接口
  static const String bangumiBySearch = 'https://api.bgm.tv/search/subject/';

  // 从条目ID获取详细信息
  static const String bangumiInfoByID = 'https://api.bgm.tv/v0/subjects/';

  // Next条目API
  static const String bangumiInfoByIDNext = 'https://next.bgm.tv/p1/subjects/';

  // 每日放送
  static const String bangumiCalendar = 'https://api.bgm.tv/calendar';

  //bangumi-data
  static const String bangumiDataUrl =
      'https://unpkg.com/bangumi-data@0.3/dist/data.json';

  static const String checkBangumiDataUrl =
      'https://api.github.com/repos/bangumi-data/bangumi-data/releases/latest';

  // 从条目ID获取剧集ID
  static const String bangumiEpisodeByID = 'https://api.bgm.tv/v0/episodes';

  // Github镜像
  static const String gitMirror = 'https://ghfast.top/';

  // kostori-config
  static const String kostoriConfig =
      'https://raw.githubusercontent.com/kostori-app/kostori-configs/master/index.json';

  //Next
  static const String bangumiCharacterByIDNext =
      'https://next.bgm.tv/p1/characters/';
  static const String bangumiEpisodeByIDNext =
      'https://next.bgm.tv/p1/episodes/';
  static const String characterInfoByCharacterIDNext =
      'https://next.bgm.tv/p1/characters/{0}';
  static const String bangumiStaffByIDNext =
      'https://next.bgm.tv/p1/subjects/{0}/staffs/persons';

  static String formatUrl(String url, List<dynamic> params) {
    for (int i = 0; i < params.length; i++) {
      url = url.replaceAll('{$i}', params[i].toString());
    }
    return url;
  }
}
