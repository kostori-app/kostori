class Api {
  // 新条目搜索post
  static const String bangumiRankSearch =
      'https://api.bgm.tv/v0/search/subjects?limit={0}&offset={1}';

  //旧搜索接口
  static const String bangumiBySearch = 'https://api.bgm.tv/search/subject/';

  // 从条目ID获取详细信息
  static const String bangumiInfoByID = 'https://api.bgm.tv/v0/subjects/';

  // 从条目ID获取剧集ID
  static const String bangumiEpisodeByID = 'https://api.bgm.tv/v0/episodes';

  // 每日放送
  static const String bangumiCalendar = 'https://api.bgm.tv/calendar';

  //bangumi-data
  static const String bangumiDataUrl =
      'https://unpkg.com/bangumi-data@0.3/dist/data.json';

  static const String checkBangumiDataUrl =
      'https://api.github.com/repos/bangumi-data/bangumi-data/releases/latest';

  // Github镜像
  static const String gitMirror = 'https://ghfast.top/';

  // kostori-config
  static const String kostoriConfig =
      'https://raw.githubusercontent.com/kostori-app/kostori-configs/master/index.json';

  ///Next
  // 角色
  static const String bangumiCharacterByIDNext =
      'https://next.bgm.tv/p1/characters/';

  // 剧集
  static const String bangumiEpisodeByIDNext =
      'https://next.bgm.tv/p1/episodes/';

  // 角色
  static const String characterInfoByCharacterIDNext =
      'https://next.bgm.tv/p1/characters/{0}';

  // 制作
  static const String bangumiStaffByIDNext =
      'https://next.bgm.tv/p1/subjects/{0}/staffs/persons';

  // 热门
  static const String bangumiTrendingByNext =
      'https://next.bgm.tv/p1/trending/subjects';

  // 番剧详情
  static const String bangumiInfoByIDNext = 'https://next.bgm.tv/p1/subjects/';

  // 讨论板
  static const String bangumiTopicsByIDNext =
      'https://next.bgm.tv/p1/subjects/{0}/topics';

  // 讨论版详情
  static const String bangumiTopicsInfoByIDNext =
      'https://next.bgm.tv/p1/subjects/-/topics/';

  // 最新讨论版
  static const String bangumiTopicsLatestByIDNext =
      'https://next.bgm.tv/p1/subjects/-/topics';

  // 热门讨论版
  static const String bangumiTopicsTrendingByIDNext =
      'https://next.bgm.tv/p1/trending/subjects/topics';

  // 日志列表
  static const String bangumiReviewsByIDNext =
      'https://next.bgm.tv/p1/subjects/{0}/reviews';

  // 日志详情
  static const String bangumiReviewsInfoByIDNext =
      'https://next.bgm.tv/p1/blogs/';

  // 日志吐槽
  static const String bangumiReviewsCommentsByIDNext =
      'https://next.bgm.tv/p1/blogs/{0}/comments';

  // 日志图片
  static const String bangumiReviewsPhotosByIDNext =
      'https://next.bgm.tv/p1/blogs/{0}/photos';

  // 日志关联项
  static const String bangumiReviewsSubjectsByIDNext =
      'https://next.bgm.tv/p1/blogs/{0}/subjects';

  static String formatUrl(String url, List<dynamic> params) {
    for (int i = 0; i < params.length; i++) {
      url = url.replaceAll('{$i}', params[i].toString());
    }
    return url;
  }
}
