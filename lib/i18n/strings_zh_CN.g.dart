///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';

import 'strings.g.dart';

// Path: <root>
class TranslationsZhCn extends Translations
    with BaseTranslations<AppLocale, Translations> {
  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [AppLocale.build] is preferred.
  TranslationsZhCn({Map<String,
      Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<
      AppLocale,
      Translations>? meta})
      : assert(overrides ==
      null, 'Set "translation_overrides: true" in order to enable this feature.'),
        $meta = meta ?? TranslationMetadata(
          locale: AppLocale.zhCn,
          overrides: overrides ?? {},
          cardinalResolver: cardinalResolver,
          ordinalResolver: ordinalResolver,
        ),
        super(cardinalResolver: cardinalResolver,
          ordinalResolver: ordinalResolver) {
    super.$meta.setFlatMapFunction(
        $meta.getTranslation); // copy base translations to super.$meta
    $meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <zh-CN>.
  @override final TranslationMetadata<AppLocale, Translations> $meta;

  /// Access flat map
  @override dynamic operator [](String key) =>
      $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

  late final TranslationsZhCn _root = this; // ignore: unused_field

  @override
  TranslationsZhCn $copyWith(
      {TranslationMetadata<AppLocale, Translations>? meta}) =>
      TranslationsZhCn(meta: meta ?? this.$meta);

  // Translations
  @override String aToAddBToRemoveCToMove(
      {required Object a, required Object b, required Object c}) =>
      '${a} 项添加 • ${b} 项删除 • ${c} 项移动';

  @override String aToAddBToRemove({required Object a, required Object b}) =>
      '${a} 项添加 • ${b} 项删除';

  @override String cUpdates({required Object c}) => '${c} 项更新';

  @override String get aNewVersionIsAvailableDoYouWantToUpdateNow =>
      '发现新版本，是否立即更新？';

  @override String get app => '应用';

  @override String get about => '关于';

  @override String get accounts => '账户';

  @override String get addAAnimeSourceInHomePage => '在首页添加番剧源';

  @override String get addAnimeSource => '添加番剧源';

  @override String get addNewFavoriteTo => '添加新收藏到';

  @override String get addToFavorites => '添加到收藏';

  @override String get addToDefault => '添加到默认';

  @override String get removeFromFavorites => '取消收藏';

  @override String get imageProperties => '图片属性';

  @override String get fileName => '文件名';

  @override String get fileSize => '文件大小';

  @override String get modifiedTime => '修改时间';

  @override String get path => '路径';

  @override String get titleCopied => '标题已复制';

  @override String get imageFormat => '格式';

  @override String get confirmDeleteImage => '确认删除图片？';

  @override String get bangumiPlan => 'Bangumi 计划';

  @override String get switchFavoriteUser => '切换收藏用户';

  @override String get add => '添加';

  @override String addedCountAnimesToDownloadQueue({required Object count}) =>
      '已将 ${count} 部番剧加入下载队列';

  @override String get added => '已添加';

  @override String get aggregatedSearch => '聚合搜索';

  @override String get aggregated => '聚合';

  @override String get aiSource => 'AI 数据源';

  @override String get ai => 'AI';

  @override String get soulProfile => '灵魂画像';

  @override String get soulProfilerDescription =>
      '根据你的观看历史，分析你的动漫人格';

  @override String get imageTag => 'AI 图片标签';

  @override String get imageTagDescription =>
      '根据你的偏好生成 AI 绘画风格标签';

  @override String get aiChat => 'AI 聊天';

  @override String get aiChatDescription => '多轮对话，AI 具有上下文记忆';

  @override String get summary => '总结';

  @override String get summaryDescription => '自动生成你的动漫观看周报/月报';

  @override String get basicInfo => '基本信息';

  @override String get allEpisodes => '全部剧集';

  @override String get relatedEntries => '相关条目';

  @override String get alsoRemoveFilesOnDisk => '同时删除本地文件';

  @override String get animeSourceList => '番剧源列表';

  @override String get animeSource => '番剧源';

  @override String get appearance => '外观';

  @override String get areYouSureYouWantToClearYourHistory =>
      '确定要清除历史记录吗？';

  @override String get areYouSureYouWantToClearYourProgress =>
      '确定要清除全部进度吗？';

  @override String get authorizationRequired => '需要身份验证';

  @override String get autoPageTurning => '自动翻页';

  @override String get back => '返回';

  @override String get bangumi => '番组计划';

  @override String get block => '封锁';

  @override String get blue => '蓝色';

  @override String get brief => '简介';

  @override String get cacheLimit => '缓存限制';

  @override String get cacheSize => '缓存大小';

  @override String get cacheCleared => '缓存已清除';

  @override String get cancel => '取消';

  @override String get categories => '分类';

  @override String get categoryPages => '分类页面';

  @override String get characters => '角色';

  @override String get checkForUpdatesOnStartup => '启动时检查更新';

  @override String get checkForUpdates => '检查更新';

  @override String get checkUpdates => '检查更新';

  @override String get check => '检查';

  @override String get clearCache => '清除缓存';

  @override String get clearHistory => '清除历史记录';

  @override String get clearProgress => '清除进度';

  @override String get clearSearchHistory => '清除搜索历史';

  @override String get clearUnfavorited => '清除未收藏';

  @override String get clear => '清除';

  @override String get clickIfLoginExpired => '如果登录过期请点击';

  @override String get close => '关闭';

  @override String get comment => '评论';

  @override String get comments => '评论';

  @override String get confirm => '确认';

  @override String get continueText => '继续';

  @override String get copied => '已复制';

  @override String get analyze => '分析';

  @override String get analyzing => '分析中...';

  @override String get analysisResult => '分析结果';

  @override String get yourQuestion => '您的提问';

  @override String get pleaseEnterAPrompt => '请输入提示词';

  @override String get egWhatKindOfAnimeDoILike => '例如：我喜欢什么样的番剧？';

  @override String get aiSourceNotAvailable => 'AI 数据源不可用';

  @override String get copyId => '复制 ID';

  @override String get copyTitle => '复制标题';

  @override String get copyUrl => '复制 URL';

  @override String get copyToFolder => '复制到文件夹';

  @override String get copy => '复制';

  @override String get createAccount => '创建账户';

  @override String get createFolder => '创建文件夹';

  @override String get create => '创建';

  @override String currentlySeenEp({required Object ep}) =>
      '目前看到第 ${ep} 话';

  @override String get dnsOverrides => 'DNS 覆写';

  @override String get dark => '深色';

  @override String get dataSync => '数据同步';

  @override String get data => '数据';

  @override String get dateDesc => '按日期降序';

  @override String get date => '日期';

  @override String get defaultSearchTarget => '默认搜索目标';

  @override String deleteCAnimes({required Object c}) => '删除 ${c} 部番剧吗？';

  @override String get deleteAnime => '删除番剧';

  @override String get deleteFolder => '删除文件夹';

  @override String deleteAnimeSourceN({required Object n}) =>
      '确定要删除番剧源 \'${n}\' 吗？';

  @override String deleteFolderF({required Object f}) =>
      '确定要删除文件夹 \'${f}\' 吗？';

  @override String get deleteFolderPrompt => '删除文件夹？';

  @override String get delete => '删除';

  @override String get deleteRoom => '删除房间';

  @override String get description => '描述';

  @override String get deselect => '取消选择';

  @override String get detailed => '详细';

  @override String get details => '详情';

  @override String determineTheBindingA({required Object a}) =>
      '确定绑定：${a} 吗？';

  @override String get disable => '禁用';

  @override String get disabled => '已禁用';

  @override String discoverTheNewVersionV({required Object v}) =>
      '发现新版本 ${v}';

  @override String get displayModeOfAnimeTile => '番剧卡片显示模式';

  @override String get displayTimeAndBatteryInfoInReader =>
      '在阅读器中显示时间与电池信息';

  @override String get doNotReportAnyIssuesRelatedToSourcesToAppRepo =>
      '请勿将与源相关的问题反馈至本应用的仓库。';

  @override String get downloadAll => '下载全部';

  @override String get downloadSelected => '下载选中项';

  @override String get downloadThreads => '下载线程';

  @override String get download => '下载';

  @override String get downloading => '下载中';

  @override String get edit => '编辑';

  @override String get enableDnsOverrides => '启用 DNS 覆写';

  @override String get enable => '启用';

  @override String get end => '结束';

  @override String episodeEp({required Object ep}) => '第 ${ep} 话';

  @override String get error => '错误';

  @override String get exitMultiSelect => '退出多选';

  @override String get exit => '退出';

  @override String get explorePages => '探索页面';

  @override String get explore => '探索';

  @override String get exportAppData => '导出应用数据';

  @override String get export => '导出';

  @override String get failedToImport => '导入失败';

  @override String get fanyuan => '番源';

  @override String get favoriteActions => '收藏操作';

  @override String get favorite => '收藏';

  @override String get favorites => '收藏';

  @override String get finished => '已完结';

  @override String get folderName => '文件夹名称';

  @override String get folder => '文件夹';

  @override String get folders => '文件夹';

  @override String get following => '收藏';

  @override String get fullScreen => '全屏';

  @override String get fullscreen => '全屏';

  @override String get gitMirror => 'Git 镜像';

  @override String get green => '绿色';

  @override String get help => '帮助';

  @override String get history => '历史';

  @override String get historySource => '历史源';

  @override String get home => '首页';

  @override String get iconProducer => '图标制作';

  @override String get ignoreCertificateErrors => '忽略证书错误';

  @override String get importAnimes => '导入番剧';

  @override String get importAppData => '导入应用数据';

  @override String get importFromFile => '从文件导入';

  @override String get import => '导入';

  @override String importedAAnimes({required Object a}) => '已导入 ${a} 部番剧';

  @override String get information => '信息';

  @override String get myRating => '我的评分';

  @override String get initialPage => '初始页面';

  @override String get invertSelection => '反向选择';

  @override String get keywordBlocking => '关键字屏蔽';

  @override String get kostoriIsAFreeAndOpenSourceAppForAnimeWatching =>
      'Kostori 是一款免费开源的番剧观看应用。';

  @override String get language => '语言';

  @override String get later => '稍后';

  @override String get light => '浅色';

  @override String get limitImageWidth => '限制图片宽度';

  @override String get localFavorites => '本地收藏';

  @override String get local => '本地';

  @override String get logIn => '登录';

  @override String get logOut => '登出';

  @override String get log => '日志';

  @override String get manualTranslation => '手动翻译';

  @override String get manualTranslationHint => '输入文本，翻译为你偏好的语言';

  @override String get enterTextToTranslate => '输入要翻译的文字';

  @override String get translate => '翻译';

  @override String get translationFailed => '翻译失败';

  @override String get translating => '翻译中...';

  @override String get autoDetect => '自动检测';

  @override String get sourceLanguage => '源语言';

  @override String get targetLanguage => '目标语言';

  @override String get noTranslationYet =>
      '在上方输入文本，点击翻译即可在此查看结果';

  @override String get pluginModules => '插件模块';

  @override String get addPlugin => '添加插件';

  @override String get editPlugin => '编辑插件';

  @override String get noPluginsYet => '暂无插件模块，点击 + 添加';

  @override String get builtinPluginCannotDelete => '内置插件不可删除';

  @override String get pluginIcon => '图标（emoji）';

  @override String get pluginDescription => '描述';

  @override String get pluginPrompt => '提示词';

  @override String get pluginPromptHint =>
      '提示词定义该模块的功能，你输入的文本会作为输入发送；留空则使用通用提示词。';

  @override String get processing => '处理中...';

  @override String get run => '运行';

  @override String get output => '输出';

  @override String get translationResult => '翻译结果';

  @override String get selectTranslationLanguage => '选择翻译语言';

  @override String get pleaseEnterTextToTranslate => '请输入要翻译的文字';

  @override String get loginWithWebview => '使用 WebView 登录';

  @override String get login => '登录';

  @override String get longPressAndDragToReorder => '长按并拖动以重新排序。';

  @override String get longPressOnTheFavoriteButtonToQuicklyAddToThisFolder =>
      '长按收藏按钮可快速添加到此文件夹';

  @override String get longPressToZoom => '长按缩放';

  @override String get me => '个人';

  @override String get moveToFirst => '移至首位';

  @override String get moveFavoriteAfterReading => '观看完毕后移动收藏';

  @override String get moveToFolder => '移动到文件夹';

  @override String get move => '移动';

  @override String get multiSelect => '多选';

  @override String get multipleAnimes => '多部番剧';

  @override String get name => '名称';

  @override String get networkFavoritePages => '网络收藏页面';

  @override String get network => '网络';

  @override String get newFolder => '新文件夹';

  @override String get newVersion => '新版本';

  @override String get newVersionAvailable => '有新版本可用';

  @override String get next => '下一步';

  @override String get noExplorePages => '暂无浏览页面';

  @override String get noNewVersionAvailable => '暂无新版本';

  @override String get noSearchResultsFound => '找不到搜索结果';

  @override String get noLikedAnimeFound => '找不到喜欢的番剧';

  @override String get noUpdates => '暂无更新';

  @override String get ok => '确定';

  @override String get onceTheOperationIsSuccessfulAppWillAutomaticallySyncDataWithTheServer =>
      '一旦操作成功，应用将自动与服务器同步数据。';

  @override String get openLog => '打开日志';

  @override String get openAnime => '打开番剧';

  @override String get openHelp => '打开帮助';

  @override String get openInBrowser => '在浏览器中打开';

  @override String get openLink => '打开链接';

  @override String get open => '打开';

  @override String get operation => '操作';

  @override String get orange => '橙色';

  @override String get order => '排序';

  @override String get password => '密码';

  @override String get pause => '暂停';

  @override String get paused => '已暂停';

  @override String get pink => '粉色';

  @override String get playlist => '播放列表';

  @override String get pleaseCheckYourSettings => '请检查您的设置';

  @override String get preview => '预览';

  @override String get proxy => '代理';

  @override String get purple => '紫色';

  @override String get quickFavorite => '快速收藏';

  @override String get ranking => '排行';

  @override String get reLogin => '重新登录';

  @override String get read => '已读';

  @override String get reading => '阅读中';

  @override String get red => '红色';

  @override String get refresh => '刷新';

  @override String get related => '相关';

  @override String get removeAnimeFromFavorite => '将番剧从收藏中移除？';

  @override String get remove => '移除';

  @override String get rename => '重命名';

  @override String get reorder => '排序';

  @override String get resetBangumiData => '重置 Bangumi 数据';

  @override String get reset => '重置';

  @override String get retry => '重试';

  @override String get reviews => '评价';

  @override String get saveImage => '保存图片';

  @override String get savedFailed => '保存失败';

  @override String get saved => '已保存';

  @override String get searchAll => '搜索全部';

  @override String get searchHistory => '搜索历史';

  @override String get searchIn => '搜索';

  @override String get search => '搜索';

  @override String get selectAll => '全选';

  @override String get selectADirectoryWhichContainsTheAnimeFiles =>
      '选择包含番剧文件的目录。';

  @override String get selectAFolder => '选择一个文件夹';

  @override String get selectAnImageOnScreen => '在屏幕上选择一个图像';

  @override String get selectFile => '选择文件';

  @override String get selectInRange => '范围选择';

  @override String get select => '选择';

  @override String selectedAAnimes({required Object a}) => '已选择 ${a} 部番剧';

  @override String get newName => '新名称';

  @override String get setCacheLimit => '设置缓存限制';

  @override String get setNewStoragePath => '设置新存储路径';

  @override String get setSourceListUrl => '设置源列表地址';

  @override String get set => '设置';

  @override String get settings => '设置';

  @override String get share => '分享';

  @override String get showAll => '显示全部';

  @override String get showFavoriteStatusOnAnimeTile =>
      '在番剧卡片上显示收藏状态';

  @override String get showHistoryOnAnimeTile => '在番剧卡片上显示历史记录';

  @override String get singleAnime => '单部番剧';

  @override String get sizeInMb => '大小 (MB)';

  @override String get sizeOfAnimeTile => '番剧卡片大小';

  @override String get sort => '排序';

  @override String get sourceFolder => '源文件夹';

  @override String get sourceUrl => '源 URL';

  @override String get staffList => '演职人员表';

  @override String get start => '开始';

  @override String get storagePathForLocalAnimes => '本地番剧存储路径';

  @override String get submit => '提交';

  @override String get suggestions => '建议';

  @override String get syncData => '同步数据';

  @override String get sync => '同步';

  @override String get syncingData => '正在同步数据';

  @override String get system => '系统';

  @override String get tapToTurnPages => '点击翻页';

  @override String get theUrlShouldPointToAIndexJsonFile =>
      'URL 应指向 \'index.json\' 文件';

  @override String theFolderIsLinkedToSource({required Object source}) =>
      '该文件夹已链接至源 ${source}';

  @override String get themeColor => '主题颜色';

  @override String get themeMode => '主题模式';

  @override String get timetable => '时间表';

  @override String get topics => '话题';

  @override String get topicsLatest => '最新话题';

  @override String get topicsTrending => '热门话题';

  @override String get turnPageByVolumeKeys => '使用音量键翻页';

  @override String get unselected => '未选中';

  @override String get updateAnimesInfo => '更新番剧信息';

  @override String get updateTime => '更新时间';

  @override String get update => '更新';

  @override String get updatesAvailable => '有更新可用';

  @override String get updating => '更新中';

  @override String get uploadTime => '上传时间';

  @override String get upload => '上传';

  @override String get uploader => '上传者';

  @override String get useAConfigFile => '使用配置文件';

  @override String get user => '用户';

  @override String get username => '用户名';

  @override String get userProfileAnalysis => '用户画像分析';

  @override String get viewList => '查看列表';

  @override String get viewMore => '查看更多';

  @override String get view => '查看';

  @override String get webDavAutoSync => 'WebDAV 自动同步';

  @override String get kDefault => '默认';

  @override String lastWatchTimeTime({required Object time}) =>
      '上次观看时间：${time}';

  @override String minAppVersionRequired({required Object version}) =>
      '需要最低应用版本 ${version}';

  @override String get more => '更多';

  @override String get notYetAiring => '尚未播出';

  @override String fullBEpisodesReleased({required Object b}) => '全 ${b} 话';

  @override String upToEpSTotalEpsPlanned(
      {required Object s, required Object t}) =>
      '更新至第 ${s} 话 • 全 ${t} 话';

  @override String upToEpETotalEpsPlanned(
      {required Object e, required Object s, required Object t}) =>
      '更新至第 ${e} 话 (${s}) • 全 ${t} 话';

  @override String tReviewsR({required Object t, required Object r}) =>
      '${t} 条评价 | #${r}';

  @override String tReviews({required Object t}) => '${t} 条评价';

  @override String get showMore => '展开 +';

  @override String get showLess => '收起 -';

  @override String get tags => '标签';

  @override String get clearTags => '清除标签';

  @override String showingLResults({required Object l}) => '显示 ${l} 条结果';

  @override String get selectTime => '选择时间';

  @override String get switchLayout => '切换布局';

  @override String get enterKeywords => '输入关键字...';

  @override String get ratingChart => '评分图表';

  @override String get lineChart => '折线图';

  @override String get barChart => '柱状图';

  @override String standardDeviationS({required Object s}) => '标准差：${s}';

  @override String get nobodysPostedAnythingYet => '还没有人发布内容...';

  @override String get reload => '重新加载';

  @override String get mainContent => '正文';

  @override String get switchh => '切换';

  @override String get failedToLoadPleaseTryAgain => '加载失败，请重试。';

  @override String get doing => '在看';

  @override String get collect => '看过';

  @override String get wish => '想看';

  @override String get onHold => '搁置';

  @override String get dropped => '抛弃';

  @override String get todayRecommendation => '今日推荐';

  @override String tTotalCount({required Object t}) => '共 ${t} 项';

  @override String get introduction => '简介';

  @override String get latestComments => '最新评论';

  @override String get linkedItems => '关联项';

  @override String timeS({required Object s}) => '时间：${s}';

  @override String broadcastTimeA({required Object a}) => '播出时间：${a}';

  @override String get profileInformation => '个人资料';

  @override String get characterIntroduction => '角色介绍';

  @override String voiceActorC({required Object c}) => '声优：${c}';

  @override String episodeEN({required Object e, required Object n}) =>
      '第 ${e} 话：${n}';

  @override String get hotspot => '热点';

  @override String get completed => '已完成';

  @override String get mainCharacter => '主角';

  @override String get supportingCharacter => '配角';

  @override String get cameo => '客串';

  @override String get idleCorner => '闲角';

  @override String get unknown => '未知';

  @override String get debugInfo => '调试信息';

  @override String get install => '安装';

  @override String get viewOnGithub => '在 GitHub 上查看';

  @override String get noProxyOverrides => '无代理覆写';

  @override String get save => '保存';

  @override String get mirror => '镜像';

  @override String get result => '结果';

  @override String get all => '全部';

  @override String get cloudflareVerificationRequired => '需要 Cloudflare 验证';

  @override String get reloadConfigs => '重新加载配置';

  @override String get invalidUrlConfig => '无效的 URL 配置';

  @override String get inconsistentVersions => '版本不一致';

  @override String noUpdateAvailableForThisArchitectureA({required Object a}) =>
      '当前架构 (${a}) 暂无可用更新';

  @override String get checkUpdateFailed => '检查更新失败...';

  @override String get downloadFailed => '下载失败';

  @override String get failedToCheckTheHashValuePleaseTryAgain =>
      '哈希值检查失败，请重试';

  @override String get english => '英语';

  @override String get dynamicColor => '动态色彩';

  @override String get mondaySchedule => '周一时间表';

  @override String get tuesdaySchedule => '周二时间表';

  @override String get wednesdaySchedule => '周三时间表';

  @override String get thursdaySchedule => '周四时间表';

  @override String get fridaySchedule => '周五时间表';

  @override String get saturdaySchedule => '周六时间表';

  @override String get sundaySchedule => '周日时间表';

  @override String get popularityRanking => '人气排行';

  @override String get imageOperations => '图片操作';

  @override String get saveToAlbum => '保存到相册';

  @override String get stitchLongImage => '拼接长图';

  @override String get stitchHorizontalImage => '横向拼接';

  @override String get stitchSubtitles => '拼接字幕';

  @override String get saveLongImage => '保存长图';

  @override String get borderColor => '边框颜色';

  @override String get conversationTitle => '对话标题';

  @override String get aiConversation => 'AI 对话';

  @override String get topicList => '话题列表';

  @override String get startConversationWithAI => '开始与 AI 对话吧';

  @override String get newConversation => '新建对话';

  @override String get inputMessage => '输入消息...';

  @override String get noTopicsYet => '暂无话题';

  @override String get selectAiPersonality => '选择 AI 人格';

  @override String get apply => '应用';

  @override String get heightPx => '高度(px)';

  @override String get setUniformHeight => '设置统一高度';

  @override String get uniformHeight => '统一高度';

  @override String get cropImage => '裁剪图片';

  @override String get finishCropping => '完成裁剪';

  @override String get sortImages => '图片排序';

  @override String get finishSorting => '完成排序';

  @override String get noImages => '无图片';

  @override String cropHeightCPx({required Object c}) => '裁剪高度：${c} px';

  @override String get enterHexColorCode =>
      '输入十六进制颜色代码，例如 #FF000000';

  @override String get showImageBorders => '显示图片边框';

  @override String get outerBorderRadius => '外边框圆角';

  @override String get outerBorderWidth => '外边框宽度';

  @override String get outerBorderColor => '外边框颜色';

  @override String get showOuterBorder => '显示外边框';

  @override String get innerBorderWidth => '内边框宽度';

  @override String get innerBorderColor => '内边框颜色';

  @override String get borderSettings => '边框设置';

  @override String get saving => '保存中';

  @override String get saveSuccessful => '保存成功';

  @override String saveFailedE({required Object e}) => '保存失败：${e}';

  @override String get failedToLoadImagesOrNoImages => '加载图片失败或无图片';

  @override String get failedToPickImage => '选择图片失败';

  @override String get monday => '周一';

  @override String get tuesday => '周二';

  @override String get wednesday => '周三';

  @override String get thursday => '周四';

  @override String get friday => '周五';

  @override String get saturday => '周六';

  @override String get sunday => '周日';

  @override String get defaultOrder => '默认排序';

  @override String get byTime => '按时间';

  @override String get byName => '按名称';

  @override String get recentlyWatched => '最近观看';

  @override String get localFavoriteBinding => '本地收藏绑定';

  @override String get awful => '极差';

  @override String get terrible => '很差';

  @override String get bad => '差';

  @override String get poor => '较差';

  @override String get okay => '不过不失';

  @override String get fine => '还行';

  @override String get good => '推荐';

  @override String get great => '力荐';

  @override String get master => '神作';

  @override String get epic => '史诗';

  @override String get overview => '概览';

  @override String get discussion => '讨论';

  @override String get logs => '日志';

  @override String get playerDetails => '播放器详情';

  @override String get status => '状态';

  @override String get audioOptionLowLatency => '音频: 低延迟';

  @override String get audioOptionCompatibility => '音频: 兼容模式';

  @override String get switchSuccessful => '切换成功';

  @override String get switchFailed => '切换失败';

  @override String get remoteCast => '远程投屏';

  @override String get dlnaError => 'DLNA 异常';

  @override String get startSearching => '开始搜索';

  @override String get searchingDevices => '正在搜索设备…';

  @override String get noDevicesFound => '未找到设备';

  @override String get tryingToCast => '尝试投屏至';

  @override String get dlnaException => 'DLNA 异常';

  @override String get copyLink => '复制链接';

  @override String get superResolution => '超分辨率';

  @override String get superResolutionOff => '关闭';

  @override String get superResolutionEfficiency => '效率档';

  @override String get superResolutionQuality => '质量档';

  @override String get glimmerMode => '微光模式';

  @override String get glimmerModeOn => '开';

  @override String get glimmerModeOff => '关';

  @override String get aValidWebDavDirectoryUrl => '有效的 WebDAV 目录 URL';

  @override String get autoSyncData => '自动同步数据';

  @override String get screenshotShare => '截图分享';

  @override String get bestMatch => '最佳匹配';

  @override String get topRank => '排名靠前';

  @override String get mostFavorited => '最多收藏';

  @override String get highestRating => '最高评分';

  @override String get selectColor => '选择颜色';

  @override String get colorWheel => '色轮';

  @override String get primary => '主色';

  @override String get accent => '强调色';

  @override String get custom => '自定义';

  @override String confirmC({required Object c}) => '确认 (${c})';

  @override String selectC({required Object c}) => '选择 ${c}';

  @override String get selectDate => '选择日期';

  @override String get startDate => '开始日期';

  @override String get endDate => '结束日期';

  @override String get clearDate => '清除日期';

  @override String get pleaseSelectADate => '请选择日期';

  @override String get endDateCannotBeEarlierThanStartDate =>
      '结束日期不能早于开始日期';

  @override String get type => '类型';

  @override String get background => '背景';

  @override String get emotion => '情感';

  @override String get source => '来源';

  @override String get audience => '受众';

  @override String get category => '类别';

  @override String imageOperationsI({required Object i}) => '图片操作 (${i})';

  @override String sSelected({required Object s}) => '已选择 ${s}';

  @override String get simplifiedChinese => '简体中文';

  @override String get traditionalChinese => '繁体中文';
  @override late final Translations$colors$zh_CN colors = Translations$colors$zh_CN
      .internal(_root);

  @override String get secondary => '次要';

  @override String get tertiary => '三级';

  @override String get surface => '表面';

  @override String get jumpToPage => '跳转到页';

  @override String get page => '页';

  @override String pagePM({required Object p, required Object m}) =>
      '第 ${p} / ${m} 页';

  @override String get first => '首页';

  @override String get last => '末页';

  @override String get invalidPage => '无效页码';

  @override String get unknownError => '未知错误';

  @override String get disableLengthLimitation => '禁用长度限制';

  @override String get updateLog => '更新日志';

  @override String get liked => '喜欢';

  @override String get rating => '评分';

  @override String get pixelFormat => '像素格式';

  @override String get hwPixelFormat => '硬件像素格式';

  @override String get resolution => '分辨率';

  @override String get displayWidth => '显示宽度';

  @override String get displayHeight => '显示高度';

  @override String get aspect => '宽高比';

  @override String get pixelAspectRatio => '像素纵横比';

  @override String get colormatrix => '色彩矩阵';

  @override String get colorLevels => '色彩级别';

  @override String get primaries => '原色';

  @override String get gamma => '伽玛值';

  @override String get signalPeak => '信号峰值';

  @override String get lights => '光照';

  @override String get chromaLocation => '色度位置';

  @override String get rotate => '旋转';

  @override String get stereoIn => '立体声输入';

  @override String get averageBpp => '平均 Bpp';

  @override String get alpha => '透明度';

  @override String get trackId => '轨道 ID';

  @override String get trackTitle => '轨道标题';

  @override String get trackLanguage => '轨道语言';

  @override String get trackImage => '轨道图像';

  @override String get trackAlbumArt => '轨道专辑封面';

  @override String get trackCodec => '轨道解码器';

  @override String get trackDecoder => '轨道解码器';

  @override String get trackWidth => '轨道宽度';

  @override String get trackHeight => '轨道高度';

  @override String get trackChannelsCount => '轨道声道数';

  @override String get trackChannels => '轨道声道';

  @override String get trackSampleRate => '轨道采样率';

  @override String get trackFps => '轨道 FPS';

  @override String get trackBitrate => '轨道位元率';

  @override String get trackRotate => '轨道旋转';

  @override String get trackPar => '轨道 PAR';

  @override String get trackAudioChannels => '轨道音频声道';

  @override String get format => '格式';

  @override String get sampleRate => '采样率';

  @override String get channelCount => '声道数';

  @override String get hrChannels => 'HR 声道';

  @override String get uriTrack => 'URI 轨道';

  @override String get channelsCount => '声道数';

  @override String get channels => '声道';

  @override String get fps => 'FPS';

  @override String get bitrate => '位元率';

  @override String get par => 'PAR';

  @override String get audioChannels => '音频声道';

  @override String get audioBitrate => '音频位元率';

  @override String get audio => '音频';

  @override String get video => '视频';

  @override String get media => '媒体';

  @override String noLogsForL({required Object l}) => '暂无 ${l} 的日志';

  @override String get onlyValidForThisRun => '仅在此次运行中有效';

  @override String get nameField => '名称';

  @override String get brandField => '品牌';

  @override String get modelField => '型号';

  @override String get deviceField => '设备';

  @override String get productField => '产品';

  @override String get manufacturerField => '制造商';

  @override String get versionReleaseField => '版本发布';

  @override String get versionSdkIntField => 'SDK 版本';

  @override String get displayField => '显示';

  @override String get hardwareField => '硬件';

  @override String get physicalRamSizeField => '实体内存大小';

  @override String get availableRamSizeField => '可用内存大小';

  @override String get freeDiskSizeField => '可用磁盘空间';

  @override String get totalDiskSizeField => '磁盘总大小';

  @override String get isPhysicalDeviceField => '是否为实体设备';

  @override String get systemNameField => '系统名称';

  @override String get systemVersionField => '系统版本';

  @override String get modelNameField => '型号名称';

  @override String get identifierForVendorField => '供应商识别符';

  @override String get sysnameField => '系统名称';

  @override String get nodenameField => '节点名称';

  @override String get releaseField => '发布版本';

  @override String get versionField => '版本';

  @override String get machineField => '机器型号';

  @override String get computerNameField => '电脑名称';

  @override String get numberOfCoresField => '核心数';

  @override String get systemMemoryInMegabytesField => '系统内存 (MB)';

  @override String get userNameField => '用户名';

  @override String get majorVersionField => '主版本号';

  @override String get minorVersionField => '次版本号';

  @override String get buildNumberField => '编译号';

  @override String get displayVersionField => '显示版本';

  @override String get productNameField => '产品名称';

  @override String get registeredOwnerField => '注册所有者';

  @override String get releaseIdField => '发布 ID';

  @override String get packageNameField => '包名';

  @override String get appNameField => '应用名称';

  @override String get buildSignatureField => '编译签名';

  @override String get installerStoreField => '安装渠道';

  @override String get installTimeField => '安装时间';

  @override String get updateTimeField => '更新时间';

  @override String get january => '一月';

  @override String get february => '二月';

  @override String get march => '三月';

  @override String get april => '四月';

  @override String get may => '五月';

  @override String get june => '六月';

  @override String get july => '七月';

  @override String get august => '八月';

  @override String get september => '九月';

  @override String get october => '十月';

  @override String get november => '十一月';

  @override String get december => '十二月';

  @override String get today => '今天';

  @override String get yesterday => '昨天';

  @override String get last3Days => '最近 3 天';

  @override String get last7Days => '最近 7 天';

  @override String get last30Days => '最近 30 天';

  @override String get last3Months => '最近 3 个月';

  @override String get last6Months => '最近 6 个月';

  @override String get thisYear => '今年';

  @override String get older => '更久以前';

  @override String get markTheSelectedFavoritesAs => '将选中的收藏标记为';

  @override String get favoriteType => '收藏类型';

  @override String get doingStatus => '在看';

  @override String get wishStatus => '想看';

  @override String get collectStatus => '看过';

  @override String get onHoldStatus => '搁置';

  @override String get droppedStatus => '抛弃';

  @override String get player => '播放器';

  @override String get audioOption => '音频选项';

  @override String get hardwareDecoding => '硬件解码';

  @override String get hardwareDecoder => '硬件解码器';

  @override String get videoRenderer => '视频渲染器';

  @override String get videoSynchronizationMode => '视频同步模式';

  @override String get enableNoProxyOverrides => '启用无代理覆写';

  @override String get actor => '演员';

  @override String get cv => 'CV';

  @override String get dub => '配音';

  @override String get chineseDub => '中配';

  @override String get japaneseDub => '日配';

  @override String get englishDub => '英配';

  @override String get koreanDub => '韩配';

  @override String selectedACharacter({required Object a}) =>
      '已选择 ${a} 位角色';

  @override String get searchOptions => '搜索选项';

  @override String get searchSources => '搜索源';

  @override String get translation => '翻译';

  @override String get translationService => '翻译服务';

  @override String get apiKeyCannotBeEmpty => 'API Key 不能为空';

  @override String get pleaseConfigureApiKeyInAiSettingsFirst =>
      '请先在AI设置中配置API密钥';

  @override String get usage => '使用情况';

  @override String get editing => '编辑中';

  @override String get screenshotInProgress => '正在截图...';

  @override String get moveOperationTargetUnknown => '移动操作目标未知';

  @override String get operationUnknown => '操作未知';

  @override String pleaseEnterTranslationPrompt({required Object a}) =>
      '请输入翻译提示词，使用 ${a} 作为目标语言的占位符';

  @override String thePromptMustContainAPlaceholderForTarget(
      {required Object a}) => '提示词必须包含 ${a} 作为目标语言的占位符';

  @override String get thisFieldCannotBeEmpty => '此字段不能为空';

  @override String thePromptMustContainAPlaceholder({required Object a}) =>
      '提示词必须包含 ${a} 占位符';

  @override String get translationPrompt => '翻译提示词';

  @override String get modelName => '模型名称';

  @override String get apiConfiguration => 'API 配置';

  @override String get wordCloud => '词云';

  @override String get statsCalendar => '统计日历';

  @override String get todaysRecords => '当天的记录';

  @override String get dailyStats => '天统计';

  @override String get viewAll => '查看全部';

  @override String get kostoriChangelog => 'Kostori 更新日志';

  @override String get copyPath => '复制路径';

  @override String get properties => '属性';

  @override String get noEndpoint => '无端点';

  @override String get testAll => '测试全部';

  @override String get customEndpoint => '自定义端点';

  @override String get pingTest => '延迟测试';

  @override String get continuousPing => '持续延迟测试';

  @override String get service => '服务';

  @override String get serviceSettings => '服务设置';

  @override String get enableService => '启用服务';

  @override String get serviceIsStopped => '服务已停止';

  @override String runningOnH({required Object h}) => '运行在 ${h}';

  @override String get apiKey => 'API Key';

  @override String get activeKey => '当前 Key';

  @override String get usingFixedKey => '使用固定 Key';

  @override String get usingRandomKeyRegeneratedOnStartup =>
      '使用随机 Key (启动时重置)';

  @override String get useFixedKey => '使用固定 Key';

  @override String get keepTheSameKeyAfterRestart => '重启后保持相同 Key';

  @override String get fixedKey => '固定 Key';

  @override String get leaveEmptyToAutoGenerate => '留空以自动生成';

  @override String get enterFixedKey => '输入固定 Key';

  @override String get regenerateRandomKey => '重置随机 Key';

  @override String get generateANewRandomKeyImmediately =>
      '立即生成一个新的随机 Key';

  @override String get regenerate => '重置';

  @override String get port => '端口';

  @override String defaultP({required Object p}) => '默认：${p}';

  @override String get bindMode => '绑定模式';

  @override String get chooseIpVersionToListenOn => '选择监听的 IP 版本';

  @override String get hubServer => 'Hub 服务端';

  @override String get enableHub => '启用 Hub';

  @override String get hubServerIsStopped => 'Hub 服务端已停止';

  @override String get clientsCount => '位客户端';

  @override String get hubPort => 'Hub 端口';

  @override String get onlineClients => '在线客户端';

  @override String get connectedAt => '连接时间';

  @override String get messageHistory => '消息记录';

  @override String get hubClient => 'Hub 客户端';

  @override String get connectToHub => '连接到 Hub';

  @override String get connected => '已连接';

  @override String get notConnected => '未连接';

  @override String get hubAddress => 'Hub 地址';

  @override String get clientName => '客户端名称';

  @override String get displayNameInHub => '在 Hub 中的显示名称';

  @override String get myDevice => '我的设备';

  @override String get hubToken => 'Hub 令牌';

  @override String get tokenFromTheHubServer => '来自 Hub 服务端的令牌';

  @override String get pasteHubServerToken => '粘贴 Hub 服务端令牌';

  @override String get runningOn => '运行在';

  @override String get online => '在线';

  @override String get rooms => '房间';

  @override String get managing => '管理中';

  @override String get lobby => '大厅';

  @override String get noRooms => '暂无房间';

  @override String get current => '当前';

  @override String get join => '加入';

  @override String get leaveRoom => '离开房间';

  @override String get roomPassword => '房间密码';

  @override String get blacklist => '黑名单';

  @override String get bannedCount => '位已封锁';

  @override String get noBannedUsers => '暂无封锁用户';

  @override String get removeFromBlacklist => '移出黑名单';

  @override String get addToBlacklist => '加入黑名单';

  @override String get mute5min => '禁言 5 分钟';

  @override String get unmute => '解除禁言';

  @override String get removeGlobalAdmin => '撤销全局管理员';

  @override String get setGlobalAdmin => '设为全局管理员';

  @override String get kick => '剔出';

  @override String get poke => '戳一下';

  @override String get banned => '已封锁';

  @override String get joinedEvent => '加入了';

  @override String get leftEvent => '离开了';

  @override String get newRoom => '新房间';

  @override String get portAndBindMode => '端口与绑定模式';

  @override String get hubManagement => 'Hub 管理';

  @override String get chatRoom => '聊天室';

  @override String get openChatDialog => '打开聊天窗口';

  @override String get hubDetails => 'Hub 详情';

  @override String get connectionSettings => '连接设置';

  @override String get serverAddress => '服务器地址';

  @override String get host => '主机';

  @override String get authentication => '身份验证';

  @override String get paste => '粘贴';

  @override String get unblock => '取消封锁';

  @override String get profileAndRoom => '个人资料与房间';

  @override String get roomSettings => '房间设置';

  @override String get roomName => '房间名称';

  @override String get roomId => '房间ID';

  @override String get announcements => '公告';

  @override String get roomAdmins => '房间管理员';

  @override String get noAnnouncement => '暂无公告';

  @override String get setAnnouncement => '设置公告';

  @override String get enterAnnouncementPrompt => '输入公告内容...';

  @override String get removeAdmin => '撤销管理员';

  @override String get addRoomAdmin => '新增房间管理员';

  @override String get roomBans => '房间封锁';

  @override String get banMember => '封锁成员';

  @override String get unban => '解除封锁';

  @override String get server => '服务器';

  @override String get mute => '禁言';

  @override String get muteDuration => '禁言时长';

  @override String get secondsLabel => '秒';

  @override String get serverShutdown => '服务器已关闭';

  @override String get youAreNowAGlobalAdmin => '您现在是全局管理员';

  @override String get yourGlobalAdminHasBeenRevoked =>
      '您的全局管理员权限已被撤销';

  @override String get youAreNowARoomAdmin => '您现在是房间管理员';

  @override String get yourRoomAdminHasBeenRevoked =>
      '您的房间管理员权限已被撤销';

  @override String get youAreMutedFor => '您被禁言了';

  @override String get secondsUnit => '秒';

  @override String get youHaveBeenUnmuted => '您已被解除禁言';

  @override String get youAreBannedFromRoom => '您被该房间封锁了';

  @override String get youCanNowRejoinRoom => '您现在可以重新加入房间了';

  @override String get youHaveBeenKickedFromTheRoom => '您已被移出房间';

  @override String get roomDeletedMovedToLobby => '房间已删除，已回到大厅';

  @override String get eventLog => '事件日志';

  @override String get pingInterval => '心跳间隔';

  @override String get onlineStatus => '在线';

  @override String get noMessagesYet => '暂无消息';

  @override String get newMessages => '条新消息';

  @override String get reply => '回复';

  @override String get recall => '撤回';

  @override String get enterToSend => 'Enter 发送  ·  Ctrl+Enter 换行';

  @override String get messagePlaceholder => '发送消息...';

  @override String get connectionTimedOut => '连接超时';

  @override String get blockedUsers => '封锁用户';

  @override String get blockedCount => '位已封锁';

  @override String get blocked => '已屏蔽';

  @override String get blockedInvites => '屏蔽的邀请';

  @override String get noBlockedInvites => '暂无屏蔽的邀请者';

  @override String get members => '成员';

  @override String get notSet => '未设置';

  @override String get currentRoom => '当前房间';

  @override String get editProfile => '编辑资料';

  @override String get noBlockedUsers => '没有屏蔽的用户';

  @override String get createRoom => '创建房间';

  @override String get chat => '聊天';

  @override String get noOneOnline => '没有人在线';

  @override String get show => '显示';

  @override String get hide => '隐藏';

  @override String get serverBlacklist => '服务器黑名单';

  @override String get userKey => '用户 Key';

  @override String get adminKey => '管理员 Key';

  @override String get keepTheSameKeysAfterRestart => '重启后保持相同 Key';

  @override String get regeneratedOnEveryStartup => '每次启动时重新生成';

  @override String get noKeyRequired => '无需 Key';

  @override String get anyoneCanConnectWithoutApiKey =>
      '任何人无需 API Key 即可连接';

  @override String get clientsMustProvideAValidApiKey =>
      '客户端必须提供有效的 API Key';

  @override String get endpointMustBeAValidUrl =>
      '端点必须是有效的 http(s) URL';

  @override String get bucketCannotBeEmpty => '存储桶 (Bucket) 不能为空';

  @override String get accessKeyIdCannotBeEmpty => 'Access Key ID 不能为空';

  @override String get accessKeySecretCannotBeEmpty =>
      'Access Key Secret 不能为空';

  @override String get cdnDomainMustBeAValidUrl => 'CDN 域名必须是有效的 URL';

  @override String get maxSizeMustBe1to100Mb => '最大容量必须在 1–100 MB 之间';

  @override String get cleared => '已清除';

  @override String get imageUpload => '图片上传';

  @override String get clientImageUpload => '客户端图片上传';

  @override String get serverOss => '服务器 OSS';

  @override String get clientOss => '客户端 OSS';

  @override String get imagesStoredOnServerDisk =>
      '图片存储在服务器磁盘中，通过 /hub/files/ 提供服务';

  @override String get serverReceivesAndProxiesImageToOss =>
      '服务器接收并代理图片到 OSS。Key 仅保存在服务器。';

  @override String get clientUploadsDirectlyToOss =>
      '客户端直接上传到 OSS。服务器仅获取最终 URL。';

  @override String get maxSizeMb => '最大容量 (MB)';

  @override String get storePath => '存储路径';

  @override String get leaveEmptyForDefault => '留空以使用默认路径';

  @override String get notConfiguredWillUseServerOrBase64 =>
      '未配置 · 将使用服务器或 Base64';

  @override String get imageTooLargeToSend => '图片太大，无法发送';

  @override String get pleaseConfigureServerUploadOrClientOss =>
      '请配置服务器上传或客户端 OSS。';

  @override String get stopTheServerToChangeUploadMode =>
      '停止服务器以修改上传模式';

  @override String get enableClientOss => '启用客户端 OSS';

  @override String get uploadImagesDirectlyFromClientToOss =>
      '从客户端直接上传图片到 OSS';

  @override String get ossNotConfigured => 'OSS 未配置';

  @override String get dropToSendImage => '拖放以发送图片';

  @override String get longPressImageToSave => '长按图片以保存';

  @override String get pleaseEnterAValidUrl =>
      '请输入以 http:// 或 https:// 开头的有效 URL';

  @override String get setRoomPassword => '设置房间密码';

  @override String get adminPanel => '管理面板';

  @override String get enterRoomName => '输入房间名称';

  @override String get roomAnnouncement => '房间公告';

  @override String get leaveEmptyForPublicRoom => '留空以设为公开房间';

  @override String get maxParticipants => '最大人数';

  @override String get upTo => '最多';

  @override String get peopleLabel => '人';

  @override String get noLimit => '无限制';

  @override String get optional => '可选';

  @override String get enterDisplayName => '输入显示名称';

  @override String get enterBio => '输入简介';

  @override String get autoReconnect => '自动重连';

  @override String get directMessage => '私聊';

  @override String get noAnnouncementsYet => '暂无公告';

  @override String get enterAnnouncementText => '输入公告内容...';

  @override String get welcomeMessage => '欢迎消息';

  @override String get noWelcomeMessage => '暂无欢迎消息';

  @override String get enterWelcomeMessage =>
      '输入显示给新加入用户的欢迎消息...';

  @override String get security => '安全';

  @override String get changePassword => '修改密码';

  @override String get setPassword => '设置密码';

  @override String get protectedStatus => '受保护';

  @override String get removePassword => '移除密码';

  @override String get enterPasswordToChange => '输入密码 (留空以移除)';

  @override String get noAdminsYet => '暂无管理员';

  @override String get noBannedMembers => '暂无封锁成员';

  @override String get noMembersAvailable => '暂无可用成员';

  @override String get accessControl => '访问控制';

  @override String get broadcast => '广播';

  @override String get addAnnouncement => '发布公告';

  @override String areYouSureYouWantToDeleteR({required Object r}) =>
      '确定要删除 ${r} 吗？此操作不可撤销。';

  @override String get membersList => '成员列表';

  @override String get onlineUsersList => '在线成员列表';

  @override String get noUsersOnline => '无在线用户';

  @override String get room => '房间';

  @override String get noPasswordSet => '未设置密码';

  @override String get passwordProtected => '密码保护';

  @override String get imageLabel => '图片';

  @override String get stickersLabel => '贴纸';

  @override String get pokedYou => '戳了你一下';

  @override String kickedFromServerByP({required Object p}) =>
      '被 ${p} 移出了服务器';

  @override String kickedFromRoomByP({required Object p}) =>
      '被 ${p} 移出了房间';

  @override String get leftTheRoom => '离开了房间';

  @override String get joinedTheRoom => '加入了房间';

  @override String pWasKickedByO({required Object p, required Object o}) =>
      '${p} 被 ${o} 踢出了房间';

  @override String get youLabel => '您';

  @override String get leftTheServer => '离开了服务器';

  @override String get joinedTheServer => '加入了服务器';

  @override String get updatedTheAnnouncement => '更新了公告';

  @override String get recalledAMessage => '撤回了一条消息';

  @override String pReactedWithO({required Object p, required Object o}) =>
      '${p} 对消息做出了回应 ${o}';

  @override String pRemovedReactionO({required Object p, required Object o}) =>
      '${p} 取消了回应 ${o}';

  @override String get noUsersAvailableToInvite => '暂无可用邀请的用户';

  @override String get inviteToRoom => '邀请加入房间';

  @override String get invite => '邀请';

  @override String get invited => '已邀请';

  @override String get roomInvite => '房间邀请';

  @override String get invitedYouTo => '邀请你加入';

  @override String get acceptInvite => '接受';

  @override String get acceptedYourInvite => '接受了你的邀请';

  @override String get declinedYourInvite => '拒绝了你的邀请';

  @override String get blockedYourInvites => '屏蔽了你的邀请';

  @override String get blockedInvitesList => '邀请屏蔽列表';

  @override String get allowMemberInvites => '允许成员邀请';

  @override String get letAllMembersInviteOthers =>
      '允许所有成员邀请其他人加入房间';

  @override String get declineAndBlock => '拒绝并屏蔽';

  @override String get memes => '表情包';

  @override String get memeSaved => '已保存到表情包';

  @override String get networkInfo => '网络信息';

  @override String get hubInfo => 'Hub 信息';

  @override String get statsInfo => '统计信息';

  @override String get ratingDetails => '评分详情';

  @override String get sourceInfo => '源信息';

  @override String get playerInfo => '播放信息';

  @override String get hideLabel => '隐藏';

  @override String get showLabel => '显示';

  @override String get personaManagement => '角色管理';

  @override String get promptConfiguration => '提示配置';

  @override String get systemPrompt => '系统提示';

  @override String get temperature => '温度 (Temperature)';

  @override String get promptSaved => '提示词已保存';

  @override String get editSystemPrompt => '编辑系统提示词';

  @override String get noHistoryYet => '暂无历史';

  @override String get clearAll => '清空';

  @override String get configCopiedToClipboard => '配置已复制到剪贴板';

  @override String get importedAsNewConfig => '已作为新配置导入';

  @override String get imported => '已导入';

  @override String get invalidClipboardFormat => '剪贴板格式无效';

  @override String get cannotModifySystemPreset => '不能修改系统预设';

  @override String get animeCardUseBlur => '番剧卡片使用模糊背景';

  @override String get tileTitleMarquee => '卡片标题滚动';

  @override String get horizontalLayout => '水平布局';

  @override String get bangumiCardPerRow => '番剧卡片每行数量';

  @override String get bangumiCardPerRowAuto => '自动';

  @override String get calendarFetchEpisodes => '每日番剧表启动时搜寻集信息';

  @override String get addKeyword => '添加关键字';

  @override String get keyword => '关键字';

  @override String get keywordAlreadyExists => '关键字已存在';

  @override String get folderNameCannotBeEmpty => '文件夹名称不能为空';

  @override String get folderNameTooLong => '文件夹名称过长';

  @override String get folderAlreadyExists => '文件夹已存在';

  @override String get configKeyAlreadyExists => '配置 Key 已存在，请修改。';

  @override String get requiredField => '必填';

  @override String get configKey => '配置 Key';

  @override String get memoField => '备注';

  @override String get valueRange => '范围：0.0 - 1.0';

  @override String get readOnlySystemPreset => '只读系统预设';

  @override String get deleteConfig => '删除配置';

  @override String get areYouSureYouWantToDeleteGeneric => '确定要删除吗';

  @override String get baseUrl => '基础 URL';

  @override String get optionalField => '可选';

  @override String get model => '模型';

  @override String get tokens => 'tokens';

  @override String get addModel => '添加模型';

  @override String get modelId => '模型 ID';

  @override String get displayName => '显示名称';

  @override String get noModelsAddOneAbove => '暂无模型，请在上方添加。';

  @override String placeholdersDescription(
      {required Object animeCount, required Object animeNames, required Object topTags}) =>
      '占位符：${animeCount} ${animeNames} ${topTags}';

  @override String get aiHub => 'AI 工坊';

  @override String get selectYearAndMonth => '选择年月';

  @override String get enterYear => '输入年份';

  @override String get selectDay => '选择日期';

  @override String get fullYear => '全年';

  @override String get quickSelect => '快速选择';

  @override String get selectDateRange => '选择日期范围';

  @override String get subject => '条目';

  @override String get character => '角色';

  @override String get person => '人物';

  @override String get manualSelect => '手动选择';

  @override String get qrAndClipboard => '二维码与剪贴板';

  @override String get go => '前往';

  @override String get clipboard => '剪贴板';

  @override String get recognizeFromGallery => '从相册识别';

  @override String get scanQrCode => '扫码';

  @override String get scanToJump => '扫码跳转';

  @override String get qrCode => '二维码';

  @override String get shareMethodDescription =>
      '分享方式：在番剧详情页，点击“分享” → 生成口令或二维码';

  @override String get shareQrCode => '分享二维码';

  @override String get exporting => '导出中';

  @override String get tokenCopiedToClipboard => 'Token已复制到剪贴板';

  @override String get generateQrCodeShare => '生成二维码分享';

  @override String get aiSettings => 'AI 设置';

  @override String get aiConfigMissing => 'AI配置缺失';

  @override String get generating => '生成中...';

  @override String get generatedTags => '已生成 Tags';

  @override String get exportScreenshot => '导出截图';

  @override String get copyAll => '复制全部';

  @override String get timeRange => '时间范围';

  @override String get thisWeek => '本周';

  @override String get thisMonth => '本月';

  @override String get generateSummary => '生成总结';

  @override String get generateTag => '生成 Tag';

  @override String get summaryReport => '总结报告';

  @override String get noActivityInTimeRange => '该时间段内暂无活动记录';

  @override String get weeklySummary => '本周总结';

  @override String get monthlySummary => '本月总结';

  @override String get tagCopied => 'Tag 已复制';

  @override String get aiServiceConfig => 'AI 服务配置';

  @override String get auxModelSettings => '辅助任务模型';

  @override String get auxProviderSelection => '服务商';

  @override String get auxFollowSession => '跟随会话服务商';

  @override String get auxFollowSessionHint =>
      '该任务将使用当前对话会话中配置的服务商。';

  @override String get contextCompression => '上下文压缩';

  @override String get followUpSuggestions => '后续追问建议';

  @override String get autoTitle => '自动标题';

  @override String get connectionDisconnected => '连接已断开';

  @override String get enterServerAddress => '输入服务器地址';

  @override String get tapToShare => '点击分享';

  @override String get noConfigurationsFound => '未找到配置';

  @override String get noData => '没有数据';

  @override String get loginWithPasswordIsDisabled => '密码登录已禁用';

  @override String get cannotBeEmpty => '不能为空';

  @override String get invalidCookies => '无效的 Cookies';

  @override String get webviewIsNotAvailable => 'Webview 不可用';

  @override String get sources => '数据源';

  @override String get translationFailedPleaseTryAgainLater =>
      '翻译失败，请稍后重试';

  @override String get writeYourReview => '写下你的评价';

  @override String get draft => '草稿';

  @override String get content => '内容';

  @override String get toggle => '切换';

  @override String get roomBan => '房间封禁';

  @override String get pinnedMessages => '置顶消息';

  @override String get announcement => '公告';

  @override String get image => '图片';

  @override String get enterToSendCtrlEnterForNewline =>
      '回车发送，Ctrl+Enter 换行';

  @override String get message => '消息';

  @override String get stickers => '贴纸';

  @override String get noStickersYet => '还没有贴纸';

  @override String get removeSticker => '移除贴纸';

  @override String get noSearchSources => '没有搜索源';

  @override String get pleaseAddSomeSources => '请添加一些数据源';

  @override String get manage => '管理';

  @override String get importPersona => '导入角色配置';

  @override String get newPersona => '新建角色配置';

  @override String get notConfigured => '未配置';

  @override String get enabled => '已启用';

  @override String get required => '必填';

  @override String get invalidNumber => '无效数字';

  @override String get noCategoryPages => '无分类页面';

  @override String get linkFormatErrorCannotParseAnimeInfo =>
      '链接格式错误，无法解析番剧信息';

  @override String get sourceNotFoundPleaseConfirmSourceInstalled =>
      '未找到数据源，请确认数据源已安装';

  @override String get linkFormatErrorCannotParseBangumiId =>
      '链接格式错误，无法解析 Bangumi ID';

  @override String get fetchingBangumiInfo => '正在获取 Bangumi 信息...';

  @override String get bangumiEntryNotFound => '未找到 Bangumi 条目';

  @override String get failedToFetchBangumiInfo => '获取 Bangumi 信息失败';

  @override String get linkFormatErrorCannotParseCharacterId =>
      '链接格式错误，无法解析角色 ID';

  @override String get verifyingCharacterInfo => '正在验证角色信息...';

  @override String get characterNotFound => '未找到角色';

  @override String get failedToFetchCharacterInfo => '获取角色信息失败';

  @override String get linkFormatErrorCannotParsePersonId =>
      '链接格式错误，无法解析人物 ID';

  @override String get verifyingPersonInfo => '正在验证人物信息...';

  @override String get personNotFound => '未找到人物';

  @override String get failedToFetchPersonInfo => '获取人物信息失败';

  @override String get unrecognizedLink => '无法识别的链接';

  @override String get noKostoriLinkFoundInClipboard =>
      '剪贴板中未发现 Kostori 链接';

  @override String get qrCodeFeatureOnlyOnMobile => '扫码功能仅支持移动端';

  @override String get unrecognizedKostoriProtocol => '未识别到 Kostori 协议';

  @override String get pleaseDragImageFile => '请拖入图片文件';

  @override String get imageDownloadFailed => '图片下载失败';

  @override String get failedToFetchNetworkImage => '网络图片获取失败';

  @override String get imageDecodeFailed => '图片解码失败';

  @override String get noQrCodeFoundInImage => '未在图片中识别到二维码';

  @override String get copiedToClipboard => '已复制到剪贴板';

  @override String get likeSuccess => '点赞成功';

  @override String get unlikeSuccess => '取消点赞成功';

  @override String get operationSuccess => '操作成功';

  @override String get saveSuccess => '保存成功';

  @override String get saveFailed => '保存失败';

  @override String saveFailedWithError({required Object e}) => '保存失败：${e}';

  @override String get loadSuccess => '加载成功';

  @override String get addressAlreadyExists => '地址已存在';

  @override String get pleaseEnableAtLeastOneAddress => '请先开启至少一个地址';

  @override String get requestFailed => '请求失败';

  @override String get allCopiedSuccess => '全部复制成功';

  @override String get bindBangumiIdSuccess => '绑定Bangumi ID成功';

  @override String get applySuccess => '应用成功';

  @override String get noChanges => '没有更改';

  @override String get applyFailed => '应用失败';

  @override String get noResultsTryOtherKeywords => '没有结果，请尝试其他关键词';

  @override String get jumping => '正在跳转...';

  @override String get queryFailed => '查询失败';

  @override String get screenshotSuccess => '截图成功';

  @override String get screenshotFailed => '截图失败';

  @override String noRecordForMonth({required Object month}) =>
      '${month}暂无记录';

  @override String get screenshotFailedPleaseRetry => '截图失败，请重试';

  @override String get shareFailed => '分享失败';

  @override String get connectionFailed => '连接失败';

  @override String get copySuccess => '复制成功';

  @override String get addToFavoritesSuccess => '添加收藏成功';

  @override String get deleteFailed => '删除失败';

  @override String get savingImage => '正在保存图片...';

  @override String get saveFailedPermission => '保存失败：权限或目录异常';

  @override String get bangumiDataUpdateFailed => 'Bangumi数据更新失败';

  @override String get bangumiDataResetFailed => 'Bangumi数据重置失败';

  @override String get playingNextEpisode => '正在播放下一集';

  @override String get failedToLoadEpisode => '加载剧集失败';

  @override String get noMoreEpisodes => '没有更多剧集可播放';

  @override String get routeNotFound => '线路不存在';

  @override String get loadingDuplicateEpisode => '加载重复集数';

  @override String get getVideoUrlFailed => '获取视频链接异常';

  @override String get startSearch => '开始搜索';

  @override String get pleaseEnterEpisodeNumber => '请输入集数';

  @override String get pleaseEnterValidEpisodeNumber =>
      '请输入1-999之间的有效集数';

  @override String get imageTitle => '标题';

  @override String get imageSubtitle => '副标题';

  @override String get selectBackground => '选择背景';

  @override String get changeBackground => '更换背景';

  @override String get clearBackground => '清除背景';

  @override String charCount({required Object count}) => '${count} 字';

  @override String get m3u8AdFilter => 'M3u8 广告过滤';

  @override String get enableAdFilter => '启用广告过滤';

  @override String get filterRules => '过滤规则';

  @override String get adFilterRules => '广告过滤规则';

  @override String get addRule => '新建规则';

  @override String get ruleName => '规则名称';

  @override String get urlRegex => 'URL 正则';

  @override String get domainBlock => '域名屏蔽';

  @override String get durationFilter => '时长过滤';

  @override String get tagMark => 'Tag 标记';

  @override String get regexHint => '正则表达式，如 preroll|/ads?/';

  @override String get domainHint => '域名，多个用逗号分隔';

  @override String get durationHint => '秒数，如 4.0';

  @override String get tagHint => '如';

  @override String get cueAdTag => 'CUE 广告标记';

  @override String get ultraShortSegment => '极短分片';

  @override String get commonAdUrlPattern => '常见广告 URL 特征';

  @override String get videoDetails => '视频详情';

  @override String get synopsis => '简介';

  @override String get currentEpisode => '当前集数';

  @override String get playbackRoute => '播放线路';

  @override String get progress => '进度';

  @override String get playbackSpeed => '播放倍率';

  @override String get otherSettings => '其他设置';

  @override String get audioLowLatency => '音频: 低延迟';

  @override String get audioCompatibility => '音频: 兼容模式';

  @override String get videoClipEditor => '视频剪辑';

  @override String get clipStartTime => '开始时间';

  @override String get clipEndTime => '结束时间';

  @override String get clipDuration => '时长';

  @override String get previewClip => '预览';

  @override String get exportClip => '导出';

  @override String get exportFormat => '导出格式';

  @override String get exportQuality => '导出质量';

  @override String get exportSize => '导出尺寸';

  @override String get cropArea => '裁剪区域';

  @override String get selectCropArea => '选择裁剪区域';

  @override String get fullFrame => '完整画面';

  @override String get customCrop => '自定义裁剪';

  @override String get qualityLow => '低质量';

  @override String get qualityMedium => '中等质量';

  @override String get qualityHigh => '高质量';

  @override String get gifExport => 'GIF 导出';

  @override String get apngExport => 'APNG 导出';

  @override String get mp4Export => 'MP4 导出';

  @override String get exportSuccess => '导出成功';

  @override String get exportFailed => '导出失败';

  @override String get selectTimeRange => '选择时间范围';

  @override String get recordingFeature => '录制';

  @override String get tapToRecord => '点击录制';

  @override String get lanDiscovery => '局域网发现';

  @override String get lanAutoDiscovery => '进入页面自动发现';

  @override String get lanDiscoverDevices => '发现设备';

  @override String get lanRemoteControl => '远程控制';

  @override String get lanStartDiscovery => '开始发现';

  @override String get lanStopDiscovery => '停止发现';

  @override String get lanNoDevicesFound => '未发现设备';

  @override String get lanSearching => '搜索中...';

  @override String get lanPairingRequestReceived => '收到配对请求';

  @override String get lanDevice => '设备';

  @override String get lanAccept => '接受';

  @override String get lanScanQrCodeToConnect => '扫码连接';

  @override String get lanGeneratingQrCode => '正在生成二维码';

  @override String get lanRemoteControlDescription => '手机扫码即可远程控制';

  @override String get lanInvalidRemoteControlLink => '无效的远程控制链接';

  @override String get lanRemoteControlConnection => '远程控制连接';

  @override String get lanDeviceId => '设备 ID';

  @override String get lanConnect => '连接';

  @override String get lanExitControl => '退出控制';

  @override String get lanConnectingToRemoteDevice => '正在连接远程设备';

  @override String get lanRemoteControlConnected => '远程控制已连接';

  @override String get lanRemoteControlConnectionFailed => '远程控制连接失败';

  @override String get lanConnectedDevices => '已连接设备';

  @override String get lanNoDeviceConnected => '无设备连接';

  @override String get lanPlayerControl => '播放器控制';

  @override String get lanNavigationControl => '导航控制';

  @override String get lanNavHome => '首页';

  @override String get lanNavSearch => '搜索';

  @override String get lanNavSettings => '设置';

  @override String get lanSeekBack => '后退';

  @override String get lanSeekForward => '快进';

  @override String get lanNavigation => '导航';

  @override String get lanSearch => '搜索';

  @override String get lanPlaybackControl => '播放控制';

  @override String get lanPlay => '播放';

  @override String get lanPause => '暂停';

  @override String get lanSeekTo => '跳转到';

  @override String get lanVolume => '音量';

  @override String get lanPlaybackSpeed => '播放速度';

  @override String get lanSelectEpisode => '选择集数';

  @override String get lanNextEpisode => '下一集';

  @override String get lanPreviousEpisode => '上一集';

  @override String get lanToggleFullscreen => '切换全屏';

  @override String get lanSyncStatus => '同步状态';

  @override String get lanSyncing => '同步中...';

  @override String get lanLastSyncTime => '上次同步时间';

  @override String get lanPendingChanges => '待同步更改';

  @override String get lanConflictDetected => '检测到冲突';

  @override String get lanConflictResolution => '冲突解决';

  @override String get lanLocalWins => '保留本地';

  @override String get lanRemoteWins => '保留远程';

  @override String get lanKeepBoth => '保留两者';

  @override String get lanManualResolution => '手动解决';

  @override String get lanConflictField => '冲突字段';

  @override String get lanErrorOccurred => '发生错误';

  @override String get lanCommandExecuted => '命令已执行';

  @override String get lanCommandFailed => '命令执行失败';

  @override String get lanNoPermission => '无权限';

  @override String get lanOpenAnimeDetail => '打开动漫详情';

  @override String get lanSyncProgress => '同步进度';

  @override String get aggregationEntry => '聚合入口';

  @override String get aiLabel => 'AI';

  @override String get lanLabel => '局域网';

  @override String get ffmpegNotFound => 'FFmpeg 未找到';

  @override String get ffmpegNotFoundDesktop =>
      '桌面端导出功能需要 FFmpeg，但未找到 FFmpeg 可执行文件。请在设置中配置 FFmpeg 路径，或确保 FFmpeg 在系统 PATH 中。';

  @override String get stillOpenAnyway => '仍要打开';

  @override String get preparing => '准备中…';

  @override String get downloadingPreviewClip => '正在下载预览片段…';

  @override String get loadingPlayer => '加载播放器…';

  @override String get cancelExport => '取消导出?';

  @override String get exportInProgress => '导出正在进行中，关闭将中断导出。';

  @override String get confirmClose => '确认关闭';

  @override String get stopPreview => '停止预览';

  @override String get loadingPreview => '正在加载预览…';

  @override String get previewLoadFailed => '预览加载失败';

  @override String get reloadPreviewClip => '重新加载预览片段';

  @override String get startPoint => '起点';

  @override String get endPoint => '终点';

  @override String get jumpToStart => '跳到起点';

  @override String get setStartPoint => '设置起点';

  @override String get setEndPoint => '设置终点';

  @override String get editStartPoint => '修改起点';

  @override String get editEndPoint => '修改终点';

  @override String get durationFormatHint => '支持格式: 90, 01:30, 1.5...';

  @override String get secondsAsNumber => '输入纯数字视为秒数';

  @override String get exportSettings => '导出设置';

  @override String get h264CRF => 'H.264 · CRF';

  @override String get withAudio => '含音频';

  @override String get noAudio => '无音频';

  @override String get ditherOn => '抖动开';

  @override String get ditherOff => '抖动关';

  @override String get gifFormat => 'GIF';

  @override String get apngFormat => 'APNG';

  @override String get webpFormat => 'WebP';

  @override String get browserCompatible => '浏览器兼容好';

  @override String get smallestSize => '体积最小';

  @override String get videoFormat => '视频格式';

  @override String get encoding => '编码中…';

  @override String get downloadingVideoSegments => '下载视频分片…';

  @override String get editCropBox => '编辑裁剪框';

  @override String get loadPageAndLoadNextCantBeNull =>
      'loadPage 和 loadNext 不能同时为空';

  @override String get lanShowQrCode => '显示二维码';

  @override String get lanDeviceInfo => '设备信息';

  @override String get lanDeviceDoesNotSupportQrPairing =>
      '设备不支持二维码配对';

  @override String get lanQrCodeFor => '二维码用于';

  @override String get videoTimelineThumbnails => '视频时间轴缩略图';

  @override String get fixedBitrateOptional => '固定码率 (可选，将覆盖 CRF)';

  @override String get fixedBitrate => '固定码率';

  @override String get paletteColors => '调色板颜色';

  @override String get paletteColorsHint => '颜色越少 = 体积越小';

  @override String get enableDither => '启用抖动 (Dither)';

  @override String get ditherHint => '质量更好，体积略微增大';

  @override String get webpQuality => 'WebP 质量';

  @override String get aspectRatioPresets => '画面比例预设';

  @override String get hideCropBox => '隐藏裁剪框';

  @override String get showCropBox => '显示裁剪框 (可拖动)';

  @override String get dragToSelectExportArea => '开启后，拖动以选择导出区域';

  @override String get startPointMinus1s => '起点 -1s';

  @override String get endPointMinus1s => '终点 -1s';

  @override String get startPointMinus0_1s => '起点 -0.1s';

  @override String get endPointMinus0_1s => '终点 -0.1s';

  @override String get startPointPlus0_1s => '起点 +0.1s';

  @override String get endPointPlus0_1s => '终点 +0.1s';

  @override String get startPointPlus1s => '起点 +1s';

  @override String get endPointPlus1s => '终点 +1s';

  @override String get videoTestLabel => '视频测试';

  @override String get uploading => '上传中';

  @override String get addImage => '添加图片';

  @override String get removeImage => '移除图片';

  @override String get compressingImage => '图片压缩中...';

  @override String get skills => '技能';

  @override String get selectSkills => '选择技能';

  @override String get noSkillsAvailable => '暂无可用技能';

  @override String get usingTools => '调用工具中...';

  @override String toolCallingTool({required Object tool}) => '调用 ${tool}...';

  @override String toolCallLog({required Object count}) => '工具调用: ${count}';

  @override String get generatingReply => '生成回复中...';

  @override String get stopGenerating => '停止生成';

  @override String get thinking => '思考中';

  @override String get streamInterrupted => '生成已中断';

  @override String get showThinking => '查看思考过程';

  @override String get hideThinking => '收起思考过程';

  @override String get thinkingInProgress => '正在思考...';

  @override String get statsCached => '缓存';

  @override String get jumpToBottom => '回到底部';

  @override String get modelDoesNotSupportVision => '当前模型不支持图片理解';

  @override String get myMessage => '我的消息';

  @override String get aiMessage => 'AI 消息';

  @override String get resendFromHere => '从此处重新发送';

  @override String get regenerateReply => '重新生成此回复';

  @override String get noPersonality => '无人格';

  @override String get noSystemPromptUsed => '不使用系统提示词';

  @override String get queryBalance => '查询余额';

  @override String get balance => '余额';

  @override String get queryingBalance => '查询中...';

  @override String get balanceQueryUnsupported => '该服务商不支持查询余额';

  @override String get balanceQueryUrl => '余额查询地址';

  @override String get balanceKeyPath => '结果字段路径';

  @override String get balanceQueryUrlHint => '相对路径或完整 URL';

  @override String get balanceKeyPathHint => '点号路径，如 data.balance';

  @override String get balanceQueryConfig => '余额查询配置';

  @override String get customProviders => '自定义服务商';

  @override String get noCustomProviders => '暂无自定义服务商';

  @override String get newCustomProvider => '新建自定义服务商';

  @override String get newMcpServer => '新建 MCP 服务器';

  @override String get newSkill => '新建技能';

  @override String get invalidJson => 'JSON 格式无效';

  @override String get providerKey => '服务商 Key';

  @override String get providerKeyHint => '例如 my-provider';

  @override String get providerKeyExists => '服务商 Key 已存在，请更换';

  @override String get defaultModel => '默认模型';

  @override String get supportsVision => '支持图片理解';

  @override String get supportsTools => '支持工具调用';

  @override String get enableVision => '启用图片理解';

  @override String get disableVision => '禁用图片理解';

  @override String get enableTools => '启用工具调用';

  @override String get disableTools => '禁用工具调用';

  @override String get enterProviderKeyToAddModel =>
      '请先在上方填写服务商 Key 再添加模型';

  @override String get mcpServers => 'MCP 服务器';

  @override String get noMcpServers => '暂无 MCP 服务器';

  @override String get serverName => '服务器名称';

  @override String get transport => '传输方式';

  @override String get stdio => 'stdio';

  @override String get http => 'HTTP';

  @override String get sse => 'SSE';

  @override String get command => '命令';

  @override String get args => '参数（JSON）';

  @override String get env => '环境变量（JSON）';

  @override String get serverUrl => '服务器地址';

  @override String get headers => '请求头（JSON）';

  @override String get noSkillsYet => '暂无技能';

  @override String get skillName => '技能名称';

  @override String get skillKey => '技能 Key';

  @override String get builtin => '内置';

  @override String get skillMarkdownHint => '技能支持 Markdown 格式';

  @override String get sendMessage => '发送消息';

  @override String get contextAutoCompressed => '上下文过长，已自动压缩';

  @override String get chatGreeting => '今天有什么可以帮你？';

  @override String get chatStart1 => '总结这段文本';

  @override String get chatStart2 => '写一首诗';

  @override String get chatStart3 => '解释一个概念';

  @override String get chatStart4 => '翻译这段内容';

  @override String get importSkills => '导入技能';

  @override String get importSkillsFromFiles => 'Markdown 文件';

  @override String get importSkillsFromFilesHint =>
      '导入一个或多个带 YAML frontmatter 的 .md 技能文件';

  @override String get importSkillsFromFolder => '含 SKILL.md 的文件夹';

  @override String get importSkillsFromFolderHint =>
      '导入包含 SKILL.md 文件的文件夹';

  @override String get importingSkills => '正在导入技能...';

  @override String get noSkillFileFound => '所选文件夹中未找到 SKILL.md';

  @override String importedSkillCount({required Object count}) =>
      '已导入 ${count} 个技能';

  @override String importedSkillCountSkipped(
      {required Object imported, required Object skipped}) =>
      '已导入 ${imported} 个技能，跳过 ${skipped} 个无效文件';

  @override String get assistantProfiles => '助手档案';

  @override String get newProfile => '新建档案';

  @override String get editAssistantProfile => '编辑档案';

  @override String get profileName => '档案名称';

  @override String get profileIcon => '图标';

  @override String get profileIconHint => '一个 emoji，例如 🤖';

  @override String get profilePersona => '人设';

  @override String get profileTone => '语气';

  @override String get profilePromptFragments => '提示片段（每行一条）';

  @override String get profileKnowledge => '知识（每行一条）';

  @override String get profileParams => '生成参数';

  @override String get profileBehaviorPrefs => '行为偏好';

  @override String get customParamsHint => '留空表示跟随服务商默认值';

  @override String get previewSystemPrompt => '预览系统提示';

  @override String get tryChatting => '试聊';

  @override String get deleteProfile => '删除档案';

  @override String get confirmDeleteProfile => '确定要删除该档案吗？';

  @override String get noProfilesYet => '暂无档案';

  @override String get profileSaved => '档案已保存';

  @override String get profileCopiedToClipboard => '档案已复制到剪贴板';

  @override String switchedToProfile({required Object name}) =>
      '已切换到 ${name}';

  @override String get defaultAssistant => '默认';

  @override String get conciseReplies => '简洁回复';

  @override String get useMarkdownFormatting => '使用 Markdown 排版';

  @override String get codeFirst => '代码优先';

  @override String get actionableAdvice => '给出可执行建议';

  @override String get profileTabPersona => '人设';

  @override String get profileTabPrompt => '提示词';

  @override String get profileTabSkills => '技能';

  @override String get profileTabParams => '参数';

  @override String get profileTabBasic => '基础';

  @override String get profileTabExtensions => '扩展';

  @override String get profileTabMemory => '记忆';

  @override String get profileTabRequest => '请求';

  @override String get profileTabMcp => 'MCP';

  @override String get profileMcpHint =>
      '绑定本助手的 MCP 服务器（连接后自动导入工具）';

  @override String get profileTabLocalTools => '工具技能';

  @override String get templateVarHint => '可用变量：';

  @override String get profilePersonaRequired => '请先选择人格';

  @override String get defaultAssistantCannotDelete => '系统默认助手不可删除';

  @override String get imageUnderstandingDisabled => '该助手未启用图片理解';

  @override String get modelType => '模型类型';

  @override String get inputModality => '输入模态';

  @override String get outputModality => '输出模态';

  @override String get supportsReasoning => '支持推理';

  @override String get apiFormat => '接口格式';

  @override String get apiFormatOpenai => 'OpenAI（chat）';

  @override String get apiFormatOpenaiResponses => 'OpenAI Responses';

  @override String get apiFormatGemini => 'Google（Gemini）';

  @override String get apiFormatClaude => 'Claude（Anthropic）';

  @override String get testConnection => '测试连接';

  @override String get testApiKey => '检测 API Key';

  @override String get enabledByApiKey => '填写 API Key 后自动启用';

  @override String get endpointChatCompletions => 'Chat Completions';

  @override String get endpointResponses => 'Responses API';

  @override String get connectionOk => '连接成功';

  @override String get modelsUrl => '查询可用模型接口';

  @override String get fetchModels => '拉取可用模型';

  @override String get noModelsReturned => '未获取到模型';

  @override String get enableReasoning => '启用推理';

  @override String get disableReasoning => '禁用推理';

  @override String get thinkingLevel => '思考程度';

  @override String get thinkingLow => '简洁';

  @override String get thinkingStandard => '标准';

  @override String get thinkingDeep => '深度';

  @override String get assistantSettings => '助手设置';

  @override String get takePhoto => '拍照';

  @override String get pickImages => '图片';

  @override String get uploadFile => '上传文件';

  @override String get compressHistory => '压缩历史';

  @override String get compressHistoryConfirm =>
      '压缩当前会话历史以节省 token，确定继续？';

  @override String get compressed => '已压缩';

  @override String get profileLocalTools => '本地工具';

  @override String get profileLocalToolsHint => '内置工具链开关';

  @override String get profileSkills => '技能';

  @override String get profileSkillsHint => '勾选扩展管理中的技能进行绑定';

  @override String get profileRequest => '自定义请求';

  @override String get profileRequestSensitiveHint =>
      '敏感信息（如 API Key）会随档案持久化，请谨慎填写';

  @override String get profileRequestBaseUrl => 'Base URL 覆盖';

  @override String get profileRequestApiKey => 'API Key 覆盖';

  @override String get profileRequestHeaders => '自定义请求头（每行 Key: Value）';

  @override String get profileRequestExtraBody => '附加请求体字段（JSON）';

  @override String get profileRequestStop => '停止序列（每行一个）';

  @override String get profileRequestStopHint => '遇此序列停止生成';

  @override String get profileExtensionsHint => '应用级可选模块开关';

  @override String get profileMemoryEnabled => '启用长期记忆';

  @override String get profileMemoryHint =>
      '记录用户偏好/常问话题/关键结论，随助手切换';

  @override String get profileMemoryMaxEntries => '记忆条目上限';

  @override String get profileMemoryEntries => '记忆条目';

  @override String get profileMemoryClear => '清空';

  @override String get profileMemoryEmpty => '暂无记忆条目';

  @override String get profileMemoryAdd => '新增记忆';

  @override String get profileCopy => '复制';

  @override String get profileExport => '导出';

  @override String get profileImport => '导入';

  @override String get profileExported => '已导出到剪贴板';

  @override String get profileImportFailed => '导入失败';

  @override String get extensionManagement => '扩展管理设置';

  @override String get extensionManagementHint =>
      '辅助任务模型、角色管理、MCP 服务器与技能的统一入口';

  @override String get roleManagement => '角色管理';

  @override String get promptManagement => '提示词';

  @override String get promptInjection => '提示词注入';

  @override String get promptInjectionHint =>
      '注入位置决定片段在 System Prompt 中的插入点';

  @override String get worldBook => '世界书';

  @override String get worldBookEntries => '世界书条目';

  @override String get newPromptInjection => '新建注入';

  @override String get editPromptInjection => '编辑注入';

  @override String get injectionName => '名称';

  @override String get injectionContent => '内容';

  @override String get injectionPosition => '注入位置';

  @override String get injectionPositionAfterPersonality => '人格之后';

  @override String get injectionPositionAfterSystemPrompt => '自定义提示词之后';

  @override String get injectionPositionAfterKnowledge => '知识之后';

  @override String get injectionPositionAfterMemory => '记忆之后';

  @override String get injectionPositionBeforeTools => '工具清单之前';

  @override String get injectionSortOrder => '排序号';

  @override String get noInjectionsYet => '暂无提示词注入';

  @override String get worldBookName => '名称';

  @override String get worldBookTriggers => '触发词（每行一个）';

  @override String get worldBookTriggersHint =>
      '用户消息命中任一触发词时才注入';

  @override String get worldBookContent => '内容';

  @override String get worldBookPriority => '优先级（越大越靠前）';

  @override String get worldBookPriorityHint => '优先级高的条目先注入';

  @override String get newWorldBookEntry => '新建条目';

  @override String get worldBookHitTest => '命中测试';

  @override String get worldBookHitTestHint =>
      '输入一句话，查看哪些条目会被触发';

  @override String get worldBookHitTestPlaceholder => '输入一句话...';

  @override String get worldBookHitsResult => '命中条目';

  @override String get worldBookNoHits => '没有条目命中';

  @override String get noWorldBookEntriesYet => '暂无世界书条目';

  @override String get auxTemperature => 'Temperature';

  @override String get selectAssistantProfile => '选择助手档案';

  @override String get profilePersonalityTags => '性格标签';

  @override String get profilePersonalityTagsHint =>
      '多选标签，如 理性/幽默/毒舌/温柔';

  @override String get profileCatchphrases => '口头禅';

  @override String get profileCatchphrasesHint => '每行一个';

  @override String get profileExamples => '对话示例（few-shot）';

  @override String get profileExamplesHint =>
      '每行一组，格式：用户: xxx | 助手: xxx';

  @override String get profileReplyStyle => '回复风格';

  @override String get replyLength => '回复长度';

  @override String get replyLengthShort => '简短';

  @override String get replyLengthNormal => '适中';

  @override String get replyLengthDetailed => '详细';

  @override String get replyUseEmoji => '使用 emoji';

  @override String get replyUseMarkdown => '使用 Markdown 排版';

  @override String get replyAskBack => '结尾反问用户';

  @override String get mcpConnectionStatus => '连接状态';

  @override String get mcpConnected => '已连接';

  @override String get mcpDisconnected => '未连接';

  @override String get mcpToolsImported => '个工具';

  @override String get mcpReconnect => '重连';

  @override String get mcpTestConnection => '测试连接';

  @override String get mcpConnecting => '连接中...';

  @override String get mcpConnectionFailed => '连接失败';
}

// Path: colors
class Translations$colors$zh_CN extends Translations$colors$en {
  Translations$colors$zh_CN.internal(TranslationsZhCn root)
      : this._root = root,
        super.internal(root);

  final TranslationsZhCn _root; // ignore: unused_field

  // Translations
  @override String get teal => '鸭蛋蓝';

  @override String get deepPurple => '深紫色';

  @override String get yellow => '黄色';

  @override String get cyan => '青色';

  @override String get m3Default => 'M3 默认';

  @override String get deepOrange => '深橙色';

  @override String get indigo => '靛蓝色';

  @override String get cloudyBlue => '阴云蓝';

  @override String get darkPastelGreen => '暗粉绿';

  @override String get dust => '尘埃色';

  @override String get electricLime => '电光绿';

  @override String get freshGreen => '鲜绿色';

  @override String get lightEggplant => '浅茄紫';

  @override String get nastyGreen => '脏绿色';

  @override String get reallyLightBlue => '极浅蓝';

  @override String get tea => '茶色';

  @override String get warmPurple => '暖紫色';

  @override String get yellowishTan => '偏黄褐色';

  @override String get cement => '水泥色';

  @override String get darkGrassGreen => '深草绿';

  @override String get dustyTeal => '尘土青';

  @override String get greyTeal => '灰青色';

  @override String get macaroniAndCheese => '起司色';

  @override String get pinkishTan => '偏粉褐色';

  @override String get spruce => '杉绿色';

  @override String get strongBlue => '亮蓝色';

  @override String get toxicGreen => '毒液绿';

  @override String get windowsBlue => '视窗蓝';

  @override String get blueBlue => '纯蓝色';

  @override String get blueWithAHintOfPurple => '蓝紫色';

  @override String get booger => '鼻涕绿';

  @override String get brightSeaGreen => '亮海绿';

  @override String get greenTeal => '绿青色';

  @override String get brownish => '偏褐色';

  @override String get offGreen => '浅灰绿';

  @override String get tangerine => '橘黄色';

  @override String get uglyGreen => '丑绿色';

  @override String get orange => '橙色';

  @override String get blue => '蓝色';

  @override String get pink => '粉红色';

  @override String get green => '绿色';

  @override String get red => '红色';

  @override String get purple => '紫色';
}

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZhCn {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
      'aToAddBToRemoveCToMove' =>
          (
          {required Object a, required Object b, required Object c}) => '${a} 项添加 • ${b} 项删除 • ${c} 项移动',
      'aToAddBToRemove' =>
          (
          {required Object a, required Object b}) => '${a} 项添加 • ${b} 项删除',
      'cUpdates' => ({required Object c}) => '${c} 项更新',
      'aNewVersionIsAvailableDoYouWantToUpdateNow' => '发现新版本，是否立即更新？',
      'app' => '应用',
      'about' => '关于',
      'accounts' => '账户',
      'addAAnimeSourceInHomePage' => '在首页添加番剧源',
      'addAnimeSource' => '添加番剧源',
      'addNewFavoriteTo' => '添加新收藏到',
      'addToFavorites' => '添加到收藏',
      'addToDefault' => '添加到默认',
      'removeFromFavorites' => '取消收藏',
      'imageProperties' => '图片属性',
      'fileName' => '文件名',
      'fileSize' => '文件大小',
      'modifiedTime' => '修改时间',
      'path' => '路径',
      'titleCopied' => '标题已复制',
      'imageFormat' => '格式',
      'confirmDeleteImage' => '确认删除图片？',
      'bangumiPlan' => 'Bangumi 计划',
      'switchFavoriteUser' => '切换收藏用户',
      'add' => '添加',
      'addedCountAnimesToDownloadQueue' =>
          ({required Object count}) => '已将 ${count} 部番剧加入下载队列',
      'added' => '已添加',
      'aggregatedSearch' => '聚合搜索',
      'aggregated' => '聚合',
      'aiSource' => 'AI 数据源',
      'ai' => 'AI',
      'soulProfile' => '灵魂画像',
      'soulProfilerDescription' => '根据你的观看历史，分析你的动漫人格',
      'imageTag' => 'AI 图片标签',
      'imageTagDescription' => '根据你的偏好生成 AI 绘画风格标签',
      'aiChat' => 'AI 聊天',
      'aiChatDescription' => '多轮对话，AI 具有上下文记忆',
      'summary' => '总结',
      'summaryDescription' => '自动生成你的动漫观看周报/月报',
      'basicInfo' => '基本信息',
      'allEpisodes' => '全部剧集',
      'relatedEntries' => '相关条目',
      'alsoRemoveFilesOnDisk' => '同时删除本地文件',
      'animeSourceList' => '番剧源列表',
      'animeSource' => '番剧源',
      'appearance' => '外观',
      'areYouSureYouWantToClearYourHistory' => '确定要清除历史记录吗？',
      'areYouSureYouWantToClearYourProgress' => '确定要清除全部进度吗？',
      'authorizationRequired' => '需要身份验证',
      'autoPageTurning' => '自动翻页',
      'back' => '返回',
      'bangumi' => '番组计划',
      'block' => '封锁',
      'blue' => '蓝色',
      'brief' => '简介',
      'cacheLimit' => '缓存限制',
      'cacheSize' => '缓存大小',
      'cacheCleared' => '缓存已清除',
      'cancel' => '取消',
      'categories' => '分类',
      'categoryPages' => '分类页面',
      'characters' => '角色',
      'checkForUpdatesOnStartup' => '启动时检查更新',
      'checkForUpdates' => '检查更新',
      'checkUpdates' => '检查更新',
      'check' => '检查',
      'clearCache' => '清除缓存',
      'clearHistory' => '清除历史记录',
      'clearProgress' => '清除进度',
      'clearSearchHistory' => '清除搜索历史',
      'clearUnfavorited' => '清除未收藏',
      'clear' => '清除',
      'clickIfLoginExpired' => '如果登录过期请点击',
      'close' => '关闭',
      'comment' => '评论',
      'comments' => '评论',
      'confirm' => '确认',
      'continueText' => '继续',
      'copied' => '已复制',
      'analyze' => '分析',
      'analyzing' => '分析中...',
      'analysisResult' => '分析结果',
      'yourQuestion' => '您的提问',
      'pleaseEnterAPrompt' => '请输入提示词',
      'egWhatKindOfAnimeDoILike' => '例如：我喜欢什么样的番剧？',
      'aiSourceNotAvailable' => 'AI 数据源不可用',
      'copyId' => '复制 ID',
      'copyTitle' => '复制标题',
      'copyUrl' => '复制 URL',
      'copyToFolder' => '复制到文件夹',
      'copy' => '复制',
      'createAccount' => '创建账户',
      'createFolder' => '创建文件夹',
      'create' => '创建',
      'currentlySeenEp' => ({required Object ep}) => '目前看到第 ${ep} 话',
      'dnsOverrides' => 'DNS 覆写',
      'dark' => '深色',
      'dataSync' => '数据同步',
      'data' => '数据',
      'dateDesc' => '按日期降序',
      'date' => '日期',
      'defaultSearchTarget' => '默认搜索目标',
      'deleteCAnimes' => ({required Object c}) => '删除 ${c} 部番剧吗？',
      'deleteAnime' => '删除番剧',
      'deleteFolder' => '删除文件夹',
      'deleteAnimeSourceN' =>
          ({required Object n}) => '确定要删除番剧源 \'${n}\' 吗？',
      'deleteFolderF' =>
          ({required Object f}) => '确定要删除文件夹 \'${f}\' 吗？',
      'deleteFolderPrompt' => '删除文件夹？',
      'delete' => '删除',
      'deleteRoom' => '删除房间',
      'description' => '描述',
      'deselect' => '取消选择',
      'detailed' => '详细',
      'details' => '详情',
      'determineTheBindingA' => ({required Object a}) => '确定绑定：${a} 吗？',
      'disable' => '禁用',
      'disabled' => '已禁用',
      'discoverTheNewVersionV' => ({required Object v}) => '发现新版本 ${v}',
      'displayModeOfAnimeTile' => '番剧卡片显示模式',
      'displayTimeAndBatteryInfoInReader' => '在阅读器中显示时间与电池信息',
      'doNotReportAnyIssuesRelatedToSourcesToAppRepo' => '请勿将与源相关的问题反馈至本应用的仓库。',
      'downloadAll' => '下载全部',
      'downloadSelected' => '下载选中项',
      'downloadThreads' => '下载线程',
      'download' => '下载',
      'downloading' => '下载中',
      'edit' => '编辑',
      'enableDnsOverrides' => '启用 DNS 覆写',
      'enable' => '启用',
      'end' => '结束',
      'episodeEp' => ({required Object ep}) => '第 ${ep} 话',
      'error' => '错误',
      'exitMultiSelect' => '退出多选',
      'exit' => '退出',
      'explorePages' => '探索页面',
      'explore' => '探索',
      'exportAppData' => '导出应用数据',
      'export' => '导出',
      'failedToImport' => '导入失败',
      'fanyuan' => '番源',
      'favoriteActions' => '收藏操作',
      'favorite' => '收藏',
      'favorites' => '收藏',
      'finished' => '已完结',
      'folderName' => '文件夹名称',
      'folder' => '文件夹',
      'folders' => '文件夹',
      'following' => '收藏',
      'fullScreen' => '全屏',
      'fullscreen' => '全屏',
      'gitMirror' => 'Git 镜像',
      'green' => '绿色',
      'help' => '帮助',
      'history' => '历史',
      'historySource' => '历史源',
      'home' => '首页',
      'iconProducer' => '图标制作',
      'ignoreCertificateErrors' => '忽略证书错误',
      'importAnimes' => '导入番剧',
      'importAppData' => '导入应用数据',
      'importFromFile' => '从文件导入',
      'import' => '导入',
      'importedAAnimes' => ({required Object a}) => '已导入 ${a} 部番剧',
      'information' => '信息',
      'myRating' => '我的评分',
      'initialPage' => '初始页面',
      'invertSelection' => '反向选择',
      'keywordBlocking' => '关键字屏蔽',
      'kostoriIsAFreeAndOpenSourceAppForAnimeWatching' => 'Kostori 是一款免费开源的番剧观看应用。',
      'language' => '语言',
      'later' => '稍后',
      'light' => '浅色',
      'limitImageWidth' => '限制图片宽度',
      'localFavorites' => '本地收藏',
      'local' => '本地',
      'logIn' => '登录',
      'logOut' => '登出',
      'log' => '日志',
      'manualTranslation' => '手动翻译',
      'manualTranslationHint' => '输入文本，翻译为你偏好的语言',
      'enterTextToTranslate' => '输入要翻译的文字',
      'translate' => '翻译',
      'translationFailed' => '翻译失败',
      'translating' => '翻译中...',
      'autoDetect' => '自动检测',
      'sourceLanguage' => '源语言',
      'targetLanguage' => '目标语言',
      'noTranslationYet' => '在上方输入文本，点击翻译即可在此查看结果',
      'pluginModules' => '插件模块',
      'addPlugin' => '添加插件',
      'editPlugin' => '编辑插件',
      'noPluginsYet' => '暂无插件模块，点击 + 添加',
      'builtinPluginCannotDelete' => '内置插件不可删除',
      'pluginIcon' => '图标（emoji）',
      'pluginDescription' => '描述',
      'pluginPrompt' => '提示词',
      'pluginPromptHint' => '提示词定义该模块的功能，你输入的文本会作为输入发送；留空则使用通用提示词。',
      'processing' => '处理中...',
      'run' => '运行',
      'output' => '输出',
      'translationResult' => '翻译结果',
      'selectTranslationLanguage' => '选择翻译语言',
      'pleaseEnterTextToTranslate' => '请输入要翻译的文字',
      'loginWithWebview' => '使用 WebView 登录',
      'login' => '登录',
      'longPressAndDragToReorder' => '长按并拖动以重新排序。',
      'longPressOnTheFavoriteButtonToQuicklyAddToThisFolder' => '长按收藏按钮可快速添加到此文件夹',
      'longPressToZoom' => '长按缩放',
      'me' => '个人',
      'moveToFirst' => '移至首位',
      'moveFavoriteAfterReading' => '观看完毕后移动收藏',
      'moveToFolder' => '移动到文件夹',
      'move' => '移动',
      'multiSelect' => '多选',
      'multipleAnimes' => '多部番剧',
      'name' => '名称',
      'networkFavoritePages' => '网络收藏页面',
      'network' => '网络',
      'newFolder' => '新文件夹',
      'newVersion' => '新版本',
      'newVersionAvailable' => '有新版本可用',
      'next' => '下一步',
      'noExplorePages' => '暂无浏览页面',
      'noNewVersionAvailable' => '暂无新版本',
      'noSearchResultsFound' => '找不到搜索结果',
      'noLikedAnimeFound' => '找不到喜欢的番剧',
      'noUpdates' => '暂无更新',
      'ok' => '确定',
      'onceTheOperationIsSuccessfulAppWillAutomaticallySyncDataWithTheServer' => '一旦操作成功，应用将自动与服务器同步数据。',
      'openLog' => '打开日志',
      'openAnime' => '打开番剧',
      'openHelp' => '打开帮助',
      'openInBrowser' => '在浏览器中打开',
      'openLink' => '打开链接',
      'open' => '打开',
      'operation' => '操作',
      'orange' => '橙色',
      'order' => '排序',
      'password' => '密码',
      'pause' => '暂停',
      'paused' => '已暂停',
      'pink' => '粉色',
      'playlist' => '播放列表',
      'pleaseCheckYourSettings' => '请检查您的设置',
      'preview' => '预览',
      'proxy' => '代理',
      'purple' => '紫色',
      'quickFavorite' => '快速收藏',
      'ranking' => '排行',
      'reLogin' => '重新登录',
      'read' => '已读',
      'reading' => '阅读中',
      'red' => '红色',
      'refresh' => '刷新',
      'related' => '相关',
      'removeAnimeFromFavorite' => '将番剧从收藏中移除？',
      'remove' => '移除',
      'rename' => '重命名',
      'reorder' => '排序',
      'resetBangumiData' => '重置 Bangumi 数据',
      'reset' => '重置',
      'retry' => '重试',
      'reviews' => '评价',
      'saveImage' => '保存图片',
      'savedFailed' => '保存失败',
      'saved' => '已保存',
      'searchAll' => '搜索全部',
      'searchHistory' => '搜索历史',
      'searchIn' => '搜索',
      'search' => '搜索',
      'selectAll' => '全选',
      'selectADirectoryWhichContainsTheAnimeFiles' => '选择包含番剧文件的目录。',
      'selectAFolder' => '选择一个文件夹',
      'selectAnImageOnScreen' => '在屏幕上选择一个图像',
      'selectFile' => '选择文件',
      'selectInRange' => '范围选择',
      'select' => '选择',
      'selectedAAnimes' => ({required Object a}) => '已选择 ${a} 部番剧',
      'newName' => '新名称',
      'setCacheLimit' => '设置缓存限制',
      'setNewStoragePath' => '设置新存储路径',
      'setSourceListUrl' => '设置源列表地址',
      'set' => '设置',
      'settings' => '设置',
      'share' => '分享',
      'showAll' => '显示全部',
      'showFavoriteStatusOnAnimeTile' => '在番剧卡片上显示收藏状态',
      'showHistoryOnAnimeTile' => '在番剧卡片上显示历史记录',
      'singleAnime' => '单部番剧',
      'sizeInMb' => '大小 (MB)',
      'sizeOfAnimeTile' => '番剧卡片大小',
      'sort' => '排序',
      'sourceFolder' => '源文件夹',
      'sourceUrl' => '源 URL',
      'staffList' => '演职人员表',
      'start' => '开始',
      'storagePathForLocalAnimes' => '本地番剧存储路径',
      'submit' => '提交',
      'suggestions' => '建议',
      'syncData' => '同步数据',
      'sync' => '同步',
      'syncingData' => '正在同步数据',
      'system' => '系统',
      'tapToTurnPages' => '点击翻页',
      'theUrlShouldPointToAIndexJsonFile' => 'URL 应指向 \'index.json\' 文件',
      'theFolderIsLinkedToSource' =>
          ({required Object source}) => '该文件夹已链接至源 ${source}',
      'themeColor' => '主题颜色',
      'themeMode' => '主题模式',
      'timetable' => '时间表',
      'topics' => '话题',
      'topicsLatest' => '最新话题',
      'topicsTrending' => '热门话题',
      'turnPageByVolumeKeys' => '使用音量键翻页',
      'unselected' => '未选中',
      'updateAnimesInfo' => '更新番剧信息',
      'updateTime' => '更新时间',
      'update' => '更新',
      'updatesAvailable' => '有更新可用',
      'updating' => '更新中',
      'uploadTime' => '上传时间',
      'upload' => '上传',
      'uploader' => '上传者',
      'useAConfigFile' => '使用配置文件',
      'user' => '用户',
      'username' => '用户名',
      'userProfileAnalysis' => '用户画像分析',
      'viewList' => '查看列表',
      'viewMore' => '查看更多',
      'view' => '查看',
      'webDavAutoSync' => 'WebDAV 自动同步',
      'kDefault' => '默认',
      'lastWatchTimeTime' => ({required Object time}) => '上次观看时间：${time}',
      'minAppVersionRequired' =>
          ({required Object version}) => '需要最低应用版本 ${version}',
      'more' => '更多',
      'notYetAiring' => '尚未播出',
      'fullBEpisodesReleased' => ({required Object b}) => '全 ${b} 话',
      'upToEpSTotalEpsPlanned' =>
          (
          {required Object s, required Object t}) => '更新至第 ${s} 话 • 全 ${t} 话',
      'upToEpETotalEpsPlanned' =>
          (
          {required Object e, required Object s, required Object t}) => '更新至第 ${e} 话 (${s}) • 全 ${t} 话',
      'tReviewsR' =>
          ({required Object t, required Object r}) => '${t} 条评价 | #${r}',
      'tReviews' => ({required Object t}) => '${t} 条评价',
      'showMore' => '展开 +',
      'showLess' => '收起 -',
      'tags' => '标签',
      'clearTags' => '清除标签',
      'showingLResults' => ({required Object l}) => '显示 ${l} 条结果',
      'selectTime' => '选择时间',
      'switchLayout' => '切换布局',
      'enterKeywords' => '输入关键字...',
      'ratingChart' => '评分图表',
      'lineChart' => '折线图',
      'barChart' => '柱状图',
      'standardDeviationS' => ({required Object s}) => '标准差：${s}',
      'nobodysPostedAnythingYet' => '还没有人发布内容...',
      'reload' => '重新加载',
      'mainContent' => '正文',
      'switchh' => '切换',
      'failedToLoadPleaseTryAgain' => '加载失败，请重试。',
      'doing' => '在看',
      'collect' => '看过',
      'wish' => '想看',
      'onHold' => '搁置',
      'dropped' => '抛弃',
      'todayRecommendation' => '今日推荐',
      'tTotalCount' => ({required Object t}) => '共 ${t} 项',
      'introduction' => '简介',
      'latestComments' => '最新评论',
      'linkedItems' => '关联项',
      'timeS' => ({required Object s}) => '时间：${s}',
      'broadcastTimeA' => ({required Object a}) => '播出时间：${a}',
      'profileInformation' => '个人资料',
      'characterIntroduction' => '角色介绍',
      'voiceActorC' => ({required Object c}) => '声优：${c}',
      'episodeEN' =>
          ({required Object e, required Object n}) => '第 ${e} 话：${n}',
      'hotspot' => '热点',
      'completed' => '已完成',
      'mainCharacter' => '主角',
      'supportingCharacter' => '配角',
      'cameo' => '客串',
      'idleCorner' => '闲角',
      'unknown' => '未知',
      'debugInfo' => '调试信息',
      'install' => '安装',
      'viewOnGithub' => '在 GitHub 上查看',
      'noProxyOverrides' => '无代理覆写',
      'save' => '保存',
      'mirror' => '镜像',
      'result' => '结果',
      'all' => '全部',
      'cloudflareVerificationRequired' => '需要 Cloudflare 验证',
      'reloadConfigs' => '重新加载配置',
      'invalidUrlConfig' => '无效的 URL 配置',
      'inconsistentVersions' => '版本不一致',
      'noUpdateAvailableForThisArchitectureA' =>
          ({required Object a}) => '当前架构 (${a}) 暂无可用更新',
      'checkUpdateFailed' => '检查更新失败...',
      'downloadFailed' => '下载失败',
      'failedToCheckTheHashValuePleaseTryAgain' => '哈希值检查失败，请重试',
      'english' => '英语',
      'dynamicColor' => '动态色彩',
      'mondaySchedule' => '周一时间表',
      'tuesdaySchedule' => '周二时间表',
      'wednesdaySchedule' => '周三时间表',
      'thursdaySchedule' => '周四时间表',
      'fridaySchedule' => '周五时间表',
      'saturdaySchedule' => '周六时间表',
      'sundaySchedule' => '周日时间表',
      'popularityRanking' => '人气排行',
      'imageOperations' => '图片操作',
      'saveToAlbum' => '保存到相册',
      'stitchLongImage' => '拼接长图',
      'stitchHorizontalImage' => '横向拼接',
      'stitchSubtitles' => '拼接字幕',
      'saveLongImage' => '保存长图',
      'borderColor' => '边框颜色',
      'conversationTitle' => '对话标题',
      'aiConversation' => 'AI 对话',
      'topicList' => '话题列表',
      'startConversationWithAI' => '开始与 AI 对话吧',
      'newConversation' => '新建对话',
      'inputMessage' => '输入消息...',
      'noTopicsYet' => '暂无话题',
      'selectAiPersonality' => '选择 AI 人格',
      'apply' => '应用',
      'heightPx' => '高度(px)',
      'setUniformHeight' => '设置统一高度',
      'uniformHeight' => '统一高度',
      'cropImage' => '裁剪图片',
      'finishCropping' => '完成裁剪',
      'sortImages' => '图片排序',
      'finishSorting' => '完成排序',
      'noImages' => '无图片',
      'cropHeightCPx' => ({required Object c}) => '裁剪高度：${c} px',
      'enterHexColorCode' => '输入十六进制颜色代码，例如 #FF000000',
      'showImageBorders' => '显示图片边框',
      'outerBorderRadius' => '外边框圆角',
      'outerBorderWidth' => '外边框宽度',
      'outerBorderColor' => '外边框颜色',
      'showOuterBorder' => '显示外边框',
      'innerBorderWidth' => '内边框宽度',
      'innerBorderColor' => '内边框颜色',
      'borderSettings' => '边框设置',
      'saving' => '保存中',
      'saveSuccessful' => '保存成功',
      'saveFailedE' => ({required Object e}) => '保存失败：${e}',
      'failedToLoadImagesOrNoImages' => '加载图片失败或无图片',
      'failedToPickImage' => '选择图片失败',
      'monday' => '周一',
      'tuesday' => '周二',
      'wednesday' => '周三',
      'thursday' => '周四',
      'friday' => '周五',
      'saturday' => '周六',
      'sunday' => '周日',
      'defaultOrder' => '默认排序',
      'byTime' => '按时间',
      'byName' => '按名称',
      'recentlyWatched' => '最近观看',
      'localFavoriteBinding' => '本地收藏绑定',
      'awful' => '极差',
      'terrible' => '很差',
      'bad' => '差',
      'poor' => '较差',
      'okay' => '不过不失',
      'fine' => '还行',
      'good' => '推荐',
      'great' => '力荐',
      'master' => '神作',
      'epic' => '史诗',
      'overview' => '概览',
      'discussion' => '讨论',
      'logs' => '日志',
      'playerDetails' => '播放器详情',
      'status' => '状态',
      'audioOptionLowLatency' => '音频: 低延迟',
      'audioOptionCompatibility' => '音频: 兼容模式',
      'switchSuccessful' => '切换成功',
      'switchFailed' => '切换失败',
      'remoteCast' => '远程投屏',
      'dlnaError' => 'DLNA 异常',
      'startSearching' => '开始搜索',
      'searchingDevices' => '正在搜索设备…',
      'noDevicesFound' => '未找到设备',
      'tryingToCast' => '尝试投屏至',
      'dlnaException' => 'DLNA 异常',
      'copyLink' => '复制链接',
      'superResolution' => '超分辨率',
      'superResolutionOff' => '关闭',
      'superResolutionEfficiency' => '效率档',
      'superResolutionQuality' => '质量档',
      'glimmerMode' => '微光模式',
      'glimmerModeOn' => '开',
      'glimmerModeOff' => '关',
      'aValidWebDavDirectoryUrl' => '有效的 WebDAV 目录 URL',
      'autoSyncData' => '自动同步数据',
      'screenshotShare' => '截图分享',
      'bestMatch' => '最佳匹配',
      'topRank' => '排名靠前',
      'mostFavorited' => '最多收藏',
      'highestRating' => '最高评分',
      'selectColor' => '选择颜色',
      'colorWheel' => '色轮',
      'primary' => '主色',
      'accent' => '强调色',
      'custom' => '自定义',
      'confirmC' => ({required Object c}) => '确认 (${c})',
      'selectC' => ({required Object c}) => '选择 ${c}',
      'selectDate' => '选择日期',
      'startDate' => '开始日期',
      'endDate' => '结束日期',
      'clearDate' => '清除日期',
      'pleaseSelectADate' => '请选择日期',
      'endDateCannotBeEarlierThanStartDate' => '结束日期不能早于开始日期',
      'type' => '类型',
      'background' => '背景',
      _ => null,
    } ?? switch (path) {
      'emotion' => '情感',
      'source' => '来源',
      'audience' => '受众',
      'category' => '类别',
      'imageOperationsI' => ({required Object i}) => '图片操作 (${i})',
      'sSelected' => ({required Object s}) => '已选择 ${s}',
      'simplifiedChinese' => '简体中文',
      'traditionalChinese' => '繁体中文',
      'colors.teal' => '鸭蛋蓝',
      'colors.deepPurple' => '深紫色',
      'colors.yellow' => '黄色',
      'colors.cyan' => '青色',
      'colors.m3Default' => 'M3 默认',
      'colors.deepOrange' => '深橙色',
      'colors.indigo' => '靛蓝色',
      'colors.cloudyBlue' => '阴云蓝',
      'colors.darkPastelGreen' => '暗粉绿',
      'colors.dust' => '尘埃色',
      'colors.electricLime' => '电光绿',
      'colors.freshGreen' => '鲜绿色',
      'colors.lightEggplant' => '浅茄紫',
      'colors.nastyGreen' => '脏绿色',
      'colors.reallyLightBlue' => '极浅蓝',
      'colors.tea' => '茶色',
      'colors.warmPurple' => '暖紫色',
      'colors.yellowishTan' => '偏黄褐色',
      'colors.cement' => '水泥色',
      'colors.darkGrassGreen' => '深草绿',
      'colors.dustyTeal' => '尘土青',
      'colors.greyTeal' => '灰青色',
      'colors.macaroniAndCheese' => '起司色',
      'colors.pinkishTan' => '偏粉褐色',
      'colors.spruce' => '杉绿色',
      'colors.strongBlue' => '亮蓝色',
      'colors.toxicGreen' => '毒液绿',
      'colors.windowsBlue' => '视窗蓝',
      'colors.blueBlue' => '纯蓝色',
      'colors.blueWithAHintOfPurple' => '蓝紫色',
      'colors.booger' => '鼻涕绿',
      'colors.brightSeaGreen' => '亮海绿',
      'colors.greenTeal' => '绿青色',
      'colors.brownish' => '偏褐色',
      'colors.offGreen' => '浅灰绿',
      'colors.tangerine' => '橘黄色',
      'colors.uglyGreen' => '丑绿色',
      'colors.orange' => '橙色',
      'colors.blue' => '蓝色',
      'colors.pink' => '粉红色',
      'colors.green' => '绿色',
      'colors.red' => '红色',
      'colors.purple' => '紫色',
      'secondary' => '次要',
      'tertiary' => '三级',
      'surface' => '表面',
      'jumpToPage' => '跳转到页',
      'page' => '页',
      'pagePM' =>
          ({required Object p, required Object m}) => '第 ${p} / ${m} 页',
      'first' => '首页',
      'last' => '末页',
      'invalidPage' => '无效页码',
      'unknownError' => '未知错误',
      'disableLengthLimitation' => '禁用长度限制',
      'updateLog' => '更新日志',
      'liked' => '喜欢',
      'rating' => '评分',
      'pixelFormat' => '像素格式',
      'hwPixelFormat' => '硬件像素格式',
      'resolution' => '分辨率',
      'displayWidth' => '显示宽度',
      'displayHeight' => '显示高度',
      'aspect' => '宽高比',
      'pixelAspectRatio' => '像素纵横比',
      'colormatrix' => '色彩矩阵',
      'colorLevels' => '色彩级别',
      'primaries' => '原色',
      'gamma' => '伽玛值',
      'signalPeak' => '信号峰值',
      'lights' => '光照',
      'chromaLocation' => '色度位置',
      'rotate' => '旋转',
      'stereoIn' => '立体声输入',
      'averageBpp' => '平均 Bpp',
      'alpha' => '透明度',
      'trackId' => '轨道 ID',
      'trackTitle' => '轨道标题',
      'trackLanguage' => '轨道语言',
      'trackImage' => '轨道图像',
      'trackAlbumArt' => '轨道专辑封面',
      'trackCodec' => '轨道解码器',
      'trackDecoder' => '轨道解码器',
      'trackWidth' => '轨道宽度',
      'trackHeight' => '轨道高度',
      'trackChannelsCount' => '轨道声道数',
      'trackChannels' => '轨道声道',
      'trackSampleRate' => '轨道采样率',
      'trackFps' => '轨道 FPS',
      'trackBitrate' => '轨道位元率',
      'trackRotate' => '轨道旋转',
      'trackPar' => '轨道 PAR',
      'trackAudioChannels' => '轨道音频声道',
      'format' => '格式',
      'sampleRate' => '采样率',
      'channelCount' => '声道数',
      'hrChannels' => 'HR 声道',
      'uriTrack' => 'URI 轨道',
      'channelsCount' => '声道数',
      'channels' => '声道',
      'fps' => 'FPS',
      'bitrate' => '位元率',
      'par' => 'PAR',
      'audioChannels' => '音频声道',
      'audioBitrate' => '音频位元率',
      'audio' => '音频',
      'video' => '视频',
      'media' => '媒体',
      'noLogsForL' => ({required Object l}) => '暂无 ${l} 的日志',
      'onlyValidForThisRun' => '仅在此次运行中有效',
      'nameField' => '名称',
      'brandField' => '品牌',
      'modelField' => '型号',
      'deviceField' => '设备',
      'productField' => '产品',
      'manufacturerField' => '制造商',
      'versionReleaseField' => '版本发布',
      'versionSdkIntField' => 'SDK 版本',
      'displayField' => '显示',
      'hardwareField' => '硬件',
      'physicalRamSizeField' => '实体内存大小',
      'availableRamSizeField' => '可用内存大小',
      'freeDiskSizeField' => '可用磁盘空间',
      'totalDiskSizeField' => '磁盘总大小',
      'isPhysicalDeviceField' => '是否为实体设备',
      'systemNameField' => '系统名称',
      'systemVersionField' => '系统版本',
      'modelNameField' => '型号名称',
      'identifierForVendorField' => '供应商识别符',
      'sysnameField' => '系统名称',
      'nodenameField' => '节点名称',
      'releaseField' => '发布版本',
      'versionField' => '版本',
      'machineField' => '机器型号',
      'computerNameField' => '电脑名称',
      'numberOfCoresField' => '核心数',
      'systemMemoryInMegabytesField' => '系统内存 (MB)',
      'userNameField' => '用户名',
      'majorVersionField' => '主版本号',
      'minorVersionField' => '次版本号',
      'buildNumberField' => '编译号',
      'displayVersionField' => '显示版本',
      'productNameField' => '产品名称',
      'registeredOwnerField' => '注册所有者',
      'releaseIdField' => '发布 ID',
      'packageNameField' => '包名',
      'appNameField' => '应用名称',
      'buildSignatureField' => '编译签名',
      'installerStoreField' => '安装渠道',
      'installTimeField' => '安装时间',
      'updateTimeField' => '更新时间',
      'january' => '一月',
      'february' => '二月',
      'march' => '三月',
      'april' => '四月',
      'may' => '五月',
      'june' => '六月',
      'july' => '七月',
      'august' => '八月',
      'september' => '九月',
      'october' => '十月',
      'november' => '十一月',
      'december' => '十二月',
      'today' => '今天',
      'yesterday' => '昨天',
      'last3Days' => '最近 3 天',
      'last7Days' => '最近 7 天',
      'last30Days' => '最近 30 天',
      'last3Months' => '最近 3 个月',
      'last6Months' => '最近 6 个月',
      'thisYear' => '今年',
      'older' => '更久以前',
      'markTheSelectedFavoritesAs' => '将选中的收藏标记为',
      'favoriteType' => '收藏类型',
      'doingStatus' => '在看',
      'wishStatus' => '想看',
      'collectStatus' => '看过',
      'onHoldStatus' => '搁置',
      'droppedStatus' => '抛弃',
      'player' => '播放器',
      'audioOption' => '音频选项',
      'hardwareDecoding' => '硬件解码',
      'hardwareDecoder' => '硬件解码器',
      'videoRenderer' => '视频渲染器',
      'videoSynchronizationMode' => '视频同步模式',
      'enableNoProxyOverrides' => '启用无代理覆写',
      'actor' => '演员',
      'cv' => 'CV',
      'dub' => '配音',
      'chineseDub' => '中配',
      'japaneseDub' => '日配',
      'englishDub' => '英配',
      'koreanDub' => '韩配',
      'selectedACharacter' => ({required Object a}) => '已选择 ${a} 位角色',
      'searchOptions' => '搜索选项',
      'searchSources' => '搜索源',
      'translation' => '翻译',
      'translationService' => '翻译服务',
      'apiKeyCannotBeEmpty' => 'API Key 不能为空',
      'pleaseConfigureApiKeyInAiSettingsFirst' => '请先在AI设置中配置API密钥',
      'usage' => '使用情况',
      'editing' => '编辑中',
      'screenshotInProgress' => '正在截图...',
      'moveOperationTargetUnknown' => '移动操作目标未知',
      'operationUnknown' => '操作未知',
      'pleaseEnterTranslationPrompt' =>
          (
          {required Object a}) => '请输入翻译提示词，使用 ${a} 作为目标语言的占位符',
      'thePromptMustContainAPlaceholderForTarget' =>
          ({required Object a}) => '提示词必须包含 ${a} 作为目标语言的占位符',
      'thisFieldCannotBeEmpty' => '此字段不能为空',
      'thePromptMustContainAPlaceholder' =>
          ({required Object a}) => '提示词必须包含 ${a} 占位符',
      'translationPrompt' => '翻译提示词',
      'modelName' => '模型名称',
      'apiConfiguration' => 'API 配置',
      'wordCloud' => '词云',
      'statsCalendar' => '统计日历',
      'todaysRecords' => '当天的记录',
      'dailyStats' => '天统计',
      'viewAll' => '查看全部',
      'kostoriChangelog' => 'Kostori 更新日志',
      'copyPath' => '复制路径',
      'properties' => '属性',
      'noEndpoint' => '无端点',
      'testAll' => '测试全部',
      'customEndpoint' => '自定义端点',
      'pingTest' => '延迟测试',
      'continuousPing' => '持续延迟测试',
      'service' => '服务',
      'serviceSettings' => '服务设置',
      'enableService' => '启用服务',
      'serviceIsStopped' => '服务已停止',
      'runningOnH' => ({required Object h}) => '运行在 ${h}',
      'apiKey' => 'API Key',
      'activeKey' => '当前 Key',
      'usingFixedKey' => '使用固定 Key',
      'usingRandomKeyRegeneratedOnStartup' => '使用随机 Key (启动时重置)',
      'useFixedKey' => '使用固定 Key',
      'keepTheSameKeyAfterRestart' => '重启后保持相同 Key',
      'fixedKey' => '固定 Key',
      'leaveEmptyToAutoGenerate' => '留空以自动生成',
      'enterFixedKey' => '输入固定 Key',
      'regenerateRandomKey' => '重置随机 Key',
      'generateANewRandomKeyImmediately' => '立即生成一个新的随机 Key',
      'regenerate' => '重置',
      'port' => '端口',
      'defaultP' => ({required Object p}) => '默认：${p}',
      'bindMode' => '绑定模式',
      'chooseIpVersionToListenOn' => '选择监听的 IP 版本',
      'hubServer' => 'Hub 服务端',
      'enableHub' => '启用 Hub',
      'hubServerIsStopped' => 'Hub 服务端已停止',
      'clientsCount' => '位客户端',
      'hubPort' => 'Hub 端口',
      'onlineClients' => '在线客户端',
      'connectedAt' => '连接时间',
      'messageHistory' => '消息记录',
      'hubClient' => 'Hub 客户端',
      'connectToHub' => '连接到 Hub',
      'connected' => '已连接',
      'notConnected' => '未连接',
      'hubAddress' => 'Hub 地址',
      'clientName' => '客户端名称',
      'displayNameInHub' => '在 Hub 中的显示名称',
      'myDevice' => '我的设备',
      'hubToken' => 'Hub 令牌',
      'tokenFromTheHubServer' => '来自 Hub 服务端的令牌',
      'pasteHubServerToken' => '粘贴 Hub 服务端令牌',
      'runningOn' => '运行在',
      'online' => '在线',
      'rooms' => '房间',
      'managing' => '管理中',
      'lobby' => '大厅',
      'noRooms' => '暂无房间',
      'current' => '当前',
      'join' => '加入',
      'leaveRoom' => '离开房间',
      'roomPassword' => '房间密码',
      'blacklist' => '黑名单',
      'bannedCount' => '位已封锁',
      'noBannedUsers' => '暂无封锁用户',
      'removeFromBlacklist' => '移出黑名单',
      'addToBlacklist' => '加入黑名单',
      'mute5min' => '禁言 5 分钟',
      'unmute' => '解除禁言',
      'removeGlobalAdmin' => '撤销全局管理员',
      'setGlobalAdmin' => '设为全局管理员',
      'kick' => '剔出',
      'poke' => '戳一下',
      'banned' => '已封锁',
      'joinedEvent' => '加入了',
      'leftEvent' => '离开了',
      'newRoom' => '新房间',
      'portAndBindMode' => '端口与绑定模式',
      'hubManagement' => 'Hub 管理',
      'chatRoom' => '聊天室',
      'openChatDialog' => '打开聊天窗口',
      'hubDetails' => 'Hub 详情',
      'connectionSettings' => '连接设置',
      'serverAddress' => '服务器地址',
      'host' => '主机',
      'authentication' => '身份验证',
      'paste' => '粘贴',
      'unblock' => '取消封锁',
      'profileAndRoom' => '个人资料与房间',
      'roomSettings' => '房间设置',
      'roomName' => '房间名称',
      'roomId' => '房间ID',
      'announcements' => '公告',
      'roomAdmins' => '房间管理员',
      'noAnnouncement' => '暂无公告',
      'setAnnouncement' => '设置公告',
      'enterAnnouncementPrompt' => '输入公告内容...',
      'removeAdmin' => '撤销管理员',
      'addRoomAdmin' => '新增房间管理员',
      'roomBans' => '房间封锁',
      'banMember' => '封锁成员',
      'unban' => '解除封锁',
      'server' => '服务器',
      'mute' => '禁言',
      'muteDuration' => '禁言时长',
      'secondsLabel' => '秒',
      'serverShutdown' => '服务器已关闭',
      'youAreNowAGlobalAdmin' => '您现在是全局管理员',
      'yourGlobalAdminHasBeenRevoked' => '您的全局管理员权限已被撤销',
      'youAreNowARoomAdmin' => '您现在是房间管理员',
      'yourRoomAdminHasBeenRevoked' => '您的房间管理员权限已被撤销',
      'youAreMutedFor' => '您被禁言了',
      'secondsUnit' => '秒',
      'youHaveBeenUnmuted' => '您已被解除禁言',
      'youAreBannedFromRoom' => '您被该房间封锁了',
      'youCanNowRejoinRoom' => '您现在可以重新加入房间了',
      'youHaveBeenKickedFromTheRoom' => '您已被移出房间',
      'roomDeletedMovedToLobby' => '房间已删除，已回到大厅',
      'eventLog' => '事件日志',
      'pingInterval' => '心跳间隔',
      'onlineStatus' => '在线',
      'noMessagesYet' => '暂无消息',
      'newMessages' => '条新消息',
      'reply' => '回复',
      'recall' => '撤回',
      'enterToSend' => 'Enter 发送  ·  Ctrl+Enter 换行',
      'messagePlaceholder' => '发送消息...',
      'connectionTimedOut' => '连接超时',
      'blockedUsers' => '封锁用户',
      'blockedCount' => '位已封锁',
      'blocked' => '已屏蔽',
      'blockedInvites' => '屏蔽的邀请',
      'noBlockedInvites' => '暂无屏蔽的邀请者',
      'members' => '成员',
      'notSet' => '未设置',
      'currentRoom' => '当前房间',
      'editProfile' => '编辑资料',
      'noBlockedUsers' => '没有屏蔽的用户',
      'createRoom' => '创建房间',
      'chat' => '聊天',
      'noOneOnline' => '没有人在线',
      'show' => '显示',
      'hide' => '隐藏',
      'serverBlacklist' => '服务器黑名单',
      'userKey' => '用户 Key',
      'adminKey' => '管理员 Key',
      'keepTheSameKeysAfterRestart' => '重启后保持相同 Key',
      'regeneratedOnEveryStartup' => '每次启动时重新生成',
      'noKeyRequired' => '无需 Key',
      'anyoneCanConnectWithoutApiKey' => '任何人无需 API Key 即可连接',
      'clientsMustProvideAValidApiKey' => '客户端必须提供有效的 API Key',
      'endpointMustBeAValidUrl' => '端点必须是有效的 http(s) URL',
      'bucketCannotBeEmpty' => '存储桶 (Bucket) 不能为空',
      'accessKeyIdCannotBeEmpty' => 'Access Key ID 不能为空',
      'accessKeySecretCannotBeEmpty' => 'Access Key Secret 不能为空',
      'cdnDomainMustBeAValidUrl' => 'CDN 域名必须是有效的 URL',
      'maxSizeMustBe1to100Mb' => '最大容量必须在 1–100 MB 之间',
      'cleared' => '已清除',
      'imageUpload' => '图片上传',
      'clientImageUpload' => '客户端图片上传',
      'serverOss' => '服务器 OSS',
      'clientOss' => '客户端 OSS',
      'imagesStoredOnServerDisk' => '图片存储在服务器磁盘中，通过 /hub/files/ 提供服务',
      'serverReceivesAndProxiesImageToOss' => '服务器接收并代理图片到 OSS。Key 仅保存在服务器。',
      'clientUploadsDirectlyToOss' => '客户端直接上传到 OSS。服务器仅获取最终 URL。',
      'maxSizeMb' => '最大容量 (MB)',
      'storePath' => '存储路径',
      'leaveEmptyForDefault' => '留空以使用默认路径',
      'notConfiguredWillUseServerOrBase64' => '未配置 · 将使用服务器或 Base64',
      'imageTooLargeToSend' => '图片太大，无法发送',
      'pleaseConfigureServerUploadOrClientOss' => '请配置服务器上传或客户端 OSS。',
      'stopTheServerToChangeUploadMode' => '停止服务器以修改上传模式',
      'enableClientOss' => '启用客户端 OSS',
      'uploadImagesDirectlyFromClientToOss' => '从客户端直接上传图片到 OSS',
      'ossNotConfigured' => 'OSS 未配置',
      'dropToSendImage' => '拖放以发送图片',
      'longPressImageToSave' => '长按图片以保存',
      'pleaseEnterAValidUrl' => '请输入以 http:// 或 https:// 开头的有效 URL',
      'setRoomPassword' => '设置房间密码',
      'adminPanel' => '管理面板',
      'enterRoomName' => '输入房间名称',
      'roomAnnouncement' => '房间公告',
      'leaveEmptyForPublicRoom' => '留空以设为公开房间',
      'maxParticipants' => '最大人数',
      'upTo' => '最多',
      'peopleLabel' => '人',
      'noLimit' => '无限制',
      'optional' => '可选',
      'enterDisplayName' => '输入显示名称',
      'enterBio' => '输入简介',
      'autoReconnect' => '自动重连',
      'directMessage' => '私聊',
      'noAnnouncementsYet' => '暂无公告',
      'enterAnnouncementText' => '输入公告内容...',
      'welcomeMessage' => '欢迎消息',
      'noWelcomeMessage' => '暂无欢迎消息',
      'enterWelcomeMessage' => '输入显示给新加入用户的欢迎消息...',
      'security' => '安全',
      'changePassword' => '修改密码',
      'setPassword' => '设置密码',
      'protectedStatus' => '受保护',
      'removePassword' => '移除密码',
      'enterPasswordToChange' => '输入密码 (留空以移除)',
      'noAdminsYet' => '暂无管理员',
      'noBannedMembers' => '暂无封锁成员',
      'noMembersAvailable' => '暂无可用成员',
      'accessControl' => '访问控制',
      'broadcast' => '广播',
      'addAnnouncement' => '发布公告',
      'areYouSureYouWantToDeleteR' =>
          ({required Object r}) => '确定要删除 ${r} 吗？此操作不可撤销。',
      'membersList' => '成员列表',
      'onlineUsersList' => '在线成员列表',
      'noUsersOnline' => '无在线用户',
      'room' => '房间',
      'noPasswordSet' => '未设置密码',
      'passwordProtected' => '密码保护',
      'imageLabel' => '图片',
      'stickersLabel' => '贴纸',
      'pokedYou' => '戳了你一下',
      'kickedFromServerByP' => ({required Object p}) => '被 ${p} 移出了服务器',
      'kickedFromRoomByP' => ({required Object p}) => '被 ${p} 移出了房间',
      'leftTheRoom' => '离开了房间',
      'joinedTheRoom' => '加入了房间',
      'pWasKickedByO' =>
          ({required Object p, required Object o}) => '${p} 被 ${o} 踢出了房间',
      'youLabel' => '您',
      'leftTheServer' => '离开了服务器',
      'joinedTheServer' => '加入了服务器',
      'updatedTheAnnouncement' => '更新了公告',
      'recalledAMessage' => '撤回了一条消息',
      'pReactedWithO' =>
          (
          {required Object p, required Object o}) => '${p} 对消息做出了回应 ${o}',
      'pRemovedReactionO' =>
          ({required Object p, required Object o}) => '${p} 取消了回应 ${o}',
      'noUsersAvailableToInvite' => '暂无可用邀请的用户',
      'inviteToRoom' => '邀请加入房间',
      'invite' => '邀请',
      'invited' => '已邀请',
      'roomInvite' => '房间邀请',
      'invitedYouTo' => '邀请你加入',
      'acceptInvite' => '接受',
      'acceptedYourInvite' => '接受了你的邀请',
      'declinedYourInvite' => '拒绝了你的邀请',
      'blockedYourInvites' => '屏蔽了你的邀请',
      'blockedInvitesList' => '邀请屏蔽列表',
      'allowMemberInvites' => '允许成员邀请',
      'letAllMembersInviteOthers' => '允许所有成员邀请其他人加入房间',
      'declineAndBlock' => '拒绝并屏蔽',
      'memes' => '表情包',
      'memeSaved' => '已保存到表情包',
      'networkInfo' => '网络信息',
      'hubInfo' => 'Hub 信息',
      'statsInfo' => '统计信息',
      'ratingDetails' => '评分详情',
      'sourceInfo' => '源信息',
      'playerInfo' => '播放信息',
      'hideLabel' => '隐藏',
      'showLabel' => '显示',
      'personaManagement' => '角色管理',
      'promptConfiguration' => '提示配置',
      'systemPrompt' => '系统提示',
      'temperature' => '温度 (Temperature)',
      'promptSaved' => '提示词已保存',
      'editSystemPrompt' => '编辑系统提示词',
      'noHistoryYet' => '暂无历史',
      'clearAll' => '清空',
      'configCopiedToClipboard' => '配置已复制到剪贴板',
      'importedAsNewConfig' => '已作为新配置导入',
      'imported' => '已导入',
      'invalidClipboardFormat' => '剪贴板格式无效',
      'cannotModifySystemPreset' => '不能修改系统预设',
      'animeCardUseBlur' => '番剧卡片使用模糊背景',
      'tileTitleMarquee' => '卡片标题滚动',
      'horizontalLayout' => '水平布局',
      'bangumiCardPerRow' => '番剧卡片每行数量',
      'bangumiCardPerRowAuto' => '自动',
      'calendarFetchEpisodes' => '每日番剧表启动时搜寻集信息',
      'addKeyword' => '添加关键字',
      'keyword' => '关键字',
      'keywordAlreadyExists' => '关键字已存在',
      'folderNameCannotBeEmpty' => '文件夹名称不能为空',
      'folderNameTooLong' => '文件夹名称过长',
      'folderAlreadyExists' => '文件夹已存在',
      'configKeyAlreadyExists' => '配置 Key 已存在，请修改。',
      'requiredField' => '必填',
      'configKey' => '配置 Key',
      'memoField' => '备注',
      'valueRange' => '范围：0.0 - 1.0',
      'readOnlySystemPreset' => '只读系统预设',
      'deleteConfig' => '删除配置',
      'areYouSureYouWantToDeleteGeneric' => '确定要删除吗',
      'baseUrl' => '基础 URL',
      'optionalField' => '可选',
      'model' => '模型',
      'tokens' => 'tokens',
      _ => null,
    } ?? switch (path) {
      'addModel' => '添加模型',
      'modelId' => '模型 ID',
      'displayName' => '显示名称',
      'noModelsAddOneAbove' => '暂无模型，请在上方添加。',
      'placeholdersDescription' =>
          (
          {required Object animeCount, required Object animeNames, required Object topTags}) => '占位符：${animeCount} ${animeNames} ${topTags}',
      'aiHub' => 'AI 工坊',
      'selectYearAndMonth' => '选择年月',
      'enterYear' => '输入年份',
      'selectDay' => '选择日期',
      'fullYear' => '全年',
      'quickSelect' => '快速选择',
      'selectDateRange' => '选择日期范围',
      'subject' => '条目',
      'character' => '角色',
      'person' => '人物',
      'manualSelect' => '手动选择',
      'qrAndClipboard' => '二维码与剪贴板',
      'go' => '前往',
      'clipboard' => '剪贴板',
      'recognizeFromGallery' => '从相册识别',
      'scanQrCode' => '扫码',
      'scanToJump' => '扫码跳转',
      'qrCode' => '二维码',
      'shareMethodDescription' => '分享方式：在番剧详情页，点击“分享” → 生成口令或二维码',
      'shareQrCode' => '分享二维码',
      'exporting' => '导出中',
      'tokenCopiedToClipboard' => 'Token已复制到剪贴板',
      'generateQrCodeShare' => '生成二维码分享',
      'aiSettings' => 'AI 设置',
      'aiConfigMissing' => 'AI配置缺失',
      'generating' => '生成中...',
      'generatedTags' => '已生成 Tags',
      'exportScreenshot' => '导出截图',
      'copyAll' => '复制全部',
      'timeRange' => '时间范围',
      'thisWeek' => '本周',
      'thisMonth' => '本月',
      'generateSummary' => '生成总结',
      'generateTag' => '生成 Tag',
      'summaryReport' => '总结报告',
      'noActivityInTimeRange' => '该时间段内暂无活动记录',
      'weeklySummary' => '本周总结',
      'monthlySummary' => '本月总结',
      'tagCopied' => 'Tag 已复制',
      'aiServiceConfig' => 'AI 服务配置',
      'auxModelSettings' => '辅助任务模型',
      'auxProviderSelection' => '服务商',
      'auxFollowSession' => '跟随会话服务商',
      'auxFollowSessionHint' => '该任务将使用当前对话会话中配置的服务商。',
      'contextCompression' => '上下文压缩',
      'followUpSuggestions' => '后续追问建议',
      'autoTitle' => '自动标题',
      'connectionDisconnected' => '连接已断开',
      'enterServerAddress' => '输入服务器地址',
      'tapToShare' => '点击分享',
      'noConfigurationsFound' => '未找到配置',
      'noData' => '没有数据',
      'loginWithPasswordIsDisabled' => '密码登录已禁用',
      'cannotBeEmpty' => '不能为空',
      'invalidCookies' => '无效的 Cookies',
      'webviewIsNotAvailable' => 'Webview 不可用',
      'sources' => '数据源',
      'translationFailedPleaseTryAgainLater' => '翻译失败，请稍后重试',
      'writeYourReview' => '写下你的评价',
      'draft' => '草稿',
      'content' => '内容',
      'toggle' => '切换',
      'roomBan' => '房间封禁',
      'pinnedMessages' => '置顶消息',
      'announcement' => '公告',
      'image' => '图片',
      'enterToSendCtrlEnterForNewline' => '回车发送，Ctrl+Enter 换行',
      'message' => '消息',
      'stickers' => '贴纸',
      'noStickersYet' => '还没有贴纸',
      'removeSticker' => '移除贴纸',
      'noSearchSources' => '没有搜索源',
      'pleaseAddSomeSources' => '请添加一些数据源',
      'manage' => '管理',
      'importPersona' => '导入角色配置',
      'newPersona' => '新建角色配置',
      'notConfigured' => '未配置',
      'enabled' => '已启用',
      'required' => '必填',
      'invalidNumber' => '无效数字',
      'noCategoryPages' => '无分类页面',
      'linkFormatErrorCannotParseAnimeInfo' => '链接格式错误，无法解析番剧信息',
      'sourceNotFoundPleaseConfirmSourceInstalled' => '未找到数据源，请确认数据源已安装',
      'linkFormatErrorCannotParseBangumiId' => '链接格式错误，无法解析 Bangumi ID',
      'fetchingBangumiInfo' => '正在获取 Bangumi 信息...',
      'bangumiEntryNotFound' => '未找到 Bangumi 条目',
      'failedToFetchBangumiInfo' => '获取 Bangumi 信息失败',
      'linkFormatErrorCannotParseCharacterId' => '链接格式错误，无法解析角色 ID',
      'verifyingCharacterInfo' => '正在验证角色信息...',
      'characterNotFound' => '未找到角色',
      'failedToFetchCharacterInfo' => '获取角色信息失败',
      'linkFormatErrorCannotParsePersonId' => '链接格式错误，无法解析人物 ID',
      'verifyingPersonInfo' => '正在验证人物信息...',
      'personNotFound' => '未找到人物',
      'failedToFetchPersonInfo' => '获取人物信息失败',
      'unrecognizedLink' => '无法识别的链接',
      'noKostoriLinkFoundInClipboard' => '剪贴板中未发现 Kostori 链接',
      'qrCodeFeatureOnlyOnMobile' => '扫码功能仅支持移动端',
      'unrecognizedKostoriProtocol' => '未识别到 Kostori 协议',
      'pleaseDragImageFile' => '请拖入图片文件',
      'imageDownloadFailed' => '图片下载失败',
      'failedToFetchNetworkImage' => '网络图片获取失败',
      'imageDecodeFailed' => '图片解码失败',
      'noQrCodeFoundInImage' => '未在图片中识别到二维码',
      'copiedToClipboard' => '已复制到剪贴板',
      'likeSuccess' => '点赞成功',
      'unlikeSuccess' => '取消点赞成功',
      'operationSuccess' => '操作成功',
      'saveSuccess' => '保存成功',
      'saveFailed' => '保存失败',
      'saveFailedWithError' => ({required Object e}) => '保存失败：${e}',
      'loadSuccess' => '加载成功',
      'addressAlreadyExists' => '地址已存在',
      'pleaseEnableAtLeastOneAddress' => '请先开启至少一个地址',
      'requestFailed' => '请求失败',
      'allCopiedSuccess' => '全部复制成功',
      'bindBangumiIdSuccess' => '绑定Bangumi ID成功',
      'applySuccess' => '应用成功',
      'noChanges' => '没有更改',
      'applyFailed' => '应用失败',
      'noResultsTryOtherKeywords' => '没有结果，请尝试其他关键词',
      'jumping' => '正在跳转...',
      'queryFailed' => '查询失败',
      'screenshotSuccess' => '截图成功',
      'screenshotFailed' => '截图失败',
      'noRecordForMonth' => ({required Object month}) => '${month}暂无记录',
      'screenshotFailedPleaseRetry' => '截图失败，请重试',
      'shareFailed' => '分享失败',
      'connectionFailed' => '连接失败',
      'copySuccess' => '复制成功',
      'addToFavoritesSuccess' => '添加收藏成功',
      'deleteFailed' => '删除失败',
      'savingImage' => '正在保存图片...',
      'saveFailedPermission' => '保存失败：权限或目录异常',
      'bangumiDataUpdateFailed' => 'Bangumi数据更新失败',
      'bangumiDataResetFailed' => 'Bangumi数据重置失败',
      'playingNextEpisode' => '正在播放下一集',
      'failedToLoadEpisode' => '加载剧集失败',
      'noMoreEpisodes' => '没有更多剧集可播放',
      'routeNotFound' => '线路不存在',
      'loadingDuplicateEpisode' => '加载重复集数',
      'getVideoUrlFailed' => '获取视频链接异常',
      'startSearch' => '开始搜索',
      'pleaseEnterEpisodeNumber' => '请输入集数',
      'pleaseEnterValidEpisodeNumber' => '请输入1-999之间的有效集数',
      'imageTitle' => '标题',
      'imageSubtitle' => '副标题',
      'selectBackground' => '选择背景',
      'changeBackground' => '更换背景',
      'clearBackground' => '清除背景',
      'charCount' => ({required Object count}) => '${count} 字',
      'm3u8AdFilter' => 'M3u8 广告过滤',
      'enableAdFilter' => '启用广告过滤',
      'filterRules' => '过滤规则',
      'adFilterRules' => '广告过滤规则',
      'addRule' => '新建规则',
      'ruleName' => '规则名称',
      'urlRegex' => 'URL 正则',
      'domainBlock' => '域名屏蔽',
      'durationFilter' => '时长过滤',
      'tagMark' => 'Tag 标记',
      'regexHint' => '正则表达式，如 preroll|/ads?/',
      'domainHint' => '域名，多个用逗号分隔',
      'durationHint' => '秒数，如 4.0',
      'tagHint' => '如',
      'cueAdTag' => 'CUE 广告标记',
      'ultraShortSegment' => '极短分片',
      'commonAdUrlPattern' => '常见广告 URL 特征',
      'videoDetails' => '视频详情',
      'synopsis' => '简介',
      'currentEpisode' => '当前集数',
      'playbackRoute' => '播放线路',
      'progress' => '进度',
      'playbackSpeed' => '播放倍率',
      'otherSettings' => '其他设置',
      'audioLowLatency' => '音频: 低延迟',
      'audioCompatibility' => '音频: 兼容模式',
      'videoClipEditor' => '视频剪辑',
      'clipStartTime' => '开始时间',
      'clipEndTime' => '结束时间',
      'clipDuration' => '时长',
      'previewClip' => '预览',
      'exportClip' => '导出',
      'exportFormat' => '导出格式',
      'exportQuality' => '导出质量',
      'exportSize' => '导出尺寸',
      'cropArea' => '裁剪区域',
      'selectCropArea' => '选择裁剪区域',
      'fullFrame' => '完整画面',
      'customCrop' => '自定义裁剪',
      'qualityLow' => '低质量',
      'qualityMedium' => '中等质量',
      'qualityHigh' => '高质量',
      'gifExport' => 'GIF 导出',
      'apngExport' => 'APNG 导出',
      'mp4Export' => 'MP4 导出',
      'exportSuccess' => '导出成功',
      'exportFailed' => '导出失败',
      'selectTimeRange' => '选择时间范围',
      'recordingFeature' => '录制',
      'tapToRecord' => '点击录制',
      'lanDiscovery' => '局域网发现',
      'lanAutoDiscovery' => '进入页面自动发现',
      'lanDiscoverDevices' => '发现设备',
      'lanRemoteControl' => '远程控制',
      'lanStartDiscovery' => '开始发现',
      'lanStopDiscovery' => '停止发现',
      'lanNoDevicesFound' => '未发现设备',
      'lanSearching' => '搜索中...',
      'lanPairingRequestReceived' => '收到配对请求',
      'lanDevice' => '设备',
      'lanAccept' => '接受',
      'lanScanQrCodeToConnect' => '扫码连接',
      'lanGeneratingQrCode' => '正在生成二维码',
      'lanRemoteControlDescription' => '手机扫码即可远程控制',
      'lanInvalidRemoteControlLink' => '无效的远程控制链接',
      'lanRemoteControlConnection' => '远程控制连接',
      'lanDeviceId' => '设备 ID',
      'lanConnect' => '连接',
      'lanExitControl' => '退出控制',
      'lanConnectingToRemoteDevice' => '正在连接远程设备',
      'lanRemoteControlConnected' => '远程控制已连接',
      'lanRemoteControlConnectionFailed' => '远程控制连接失败',
      'lanConnectedDevices' => '已连接设备',
      'lanNoDeviceConnected' => '无设备连接',
      'lanPlayerControl' => '播放器控制',
      'lanNavigationControl' => '导航控制',
      'lanNavHome' => '首页',
      'lanNavSearch' => '搜索',
      'lanNavSettings' => '设置',
      'lanSeekBack' => '后退',
      'lanSeekForward' => '快进',
      'lanNavigation' => '导航',
      'lanSearch' => '搜索',
      'lanPlaybackControl' => '播放控制',
      'lanPlay' => '播放',
      'lanPause' => '暂停',
      'lanSeekTo' => '跳转到',
      'lanVolume' => '音量',
      'lanPlaybackSpeed' => '播放速度',
      'lanSelectEpisode' => '选择集数',
      'lanNextEpisode' => '下一集',
      'lanPreviousEpisode' => '上一集',
      'lanToggleFullscreen' => '切换全屏',
      'lanSyncStatus' => '同步状态',
      'lanSyncing' => '同步中...',
      'lanLastSyncTime' => '上次同步时间',
      'lanPendingChanges' => '待同步更改',
      'lanConflictDetected' => '检测到冲突',
      'lanConflictResolution' => '冲突解决',
      'lanLocalWins' => '保留本地',
      'lanRemoteWins' => '保留远程',
      'lanKeepBoth' => '保留两者',
      'lanManualResolution' => '手动解决',
      'lanConflictField' => '冲突字段',
      'lanErrorOccurred' => '发生错误',
      'lanCommandExecuted' => '命令已执行',
      'lanCommandFailed' => '命令执行失败',
      'lanNoPermission' => '无权限',
      'lanOpenAnimeDetail' => '打开动漫详情',
      'lanSyncProgress' => '同步进度',
      'aggregationEntry' => '聚合入口',
      'aiLabel' => 'AI',
      'lanLabel' => '局域网',
      'ffmpegNotFound' => 'FFmpeg 未找到',
      'ffmpegNotFoundDesktop' => '桌面端导出功能需要 FFmpeg，但未找到 FFmpeg 可执行文件。请在设置中配置 FFmpeg 路径，或确保 FFmpeg 在系统 PATH 中。',
      'stillOpenAnyway' => '仍要打开',
      'preparing' => '准备中…',
      'downloadingPreviewClip' => '正在下载预览片段…',
      'loadingPlayer' => '加载播放器…',
      'cancelExport' => '取消导出?',
      'exportInProgress' => '导出正在进行中，关闭将中断导出。',
      'confirmClose' => '确认关闭',
      'stopPreview' => '停止预览',
      'loadingPreview' => '正在加载预览…',
      'previewLoadFailed' => '预览加载失败',
      'reloadPreviewClip' => '重新加载预览片段',
      'startPoint' => '起点',
      'endPoint' => '终点',
      'jumpToStart' => '跳到起点',
      'setStartPoint' => '设置起点',
      'setEndPoint' => '设置终点',
      'editStartPoint' => '修改起点',
      'editEndPoint' => '修改终点',
      'durationFormatHint' => '支持格式: 90, 01:30, 1.5...',
      'secondsAsNumber' => '输入纯数字视为秒数',
      'exportSettings' => '导出设置',
      'h264CRF' => 'H.264 · CRF',
      'withAudio' => '含音频',
      'noAudio' => '无音频',
      'ditherOn' => '抖动开',
      'ditherOff' => '抖动关',
      'gifFormat' => 'GIF',
      'apngFormat' => 'APNG',
      'webpFormat' => 'WebP',
      'browserCompatible' => '浏览器兼容好',
      'smallestSize' => '体积最小',
      'videoFormat' => '视频格式',
      'encoding' => '编码中…',
      'downloadingVideoSegments' => '下载视频分片…',
      'editCropBox' => '编辑裁剪框',
      'loadPageAndLoadNextCantBeNull' => 'loadPage 和 loadNext 不能同时为空',
      'lanShowQrCode' => '显示二维码',
      'lanDeviceInfo' => '设备信息',
      'lanDeviceDoesNotSupportQrPairing' => '设备不支持二维码配对',
      'lanQrCodeFor' => '二维码用于',
      'videoTimelineThumbnails' => '视频时间轴缩略图',
      'fixedBitrateOptional' => '固定码率 (可选，将覆盖 CRF)',
      'fixedBitrate' => '固定码率',
      'paletteColors' => '调色板颜色',
      'paletteColorsHint' => '颜色越少 = 体积越小',
      'enableDither' => '启用抖动 (Dither)',
      'ditherHint' => '质量更好，体积略微增大',
      'webpQuality' => 'WebP 质量',
      'aspectRatioPresets' => '画面比例预设',
      'hideCropBox' => '隐藏裁剪框',
      'showCropBox' => '显示裁剪框 (可拖动)',
      'dragToSelectExportArea' => '开启后，拖动以选择导出区域',
      'startPointMinus1s' => '起点 -1s',
      'endPointMinus1s' => '终点 -1s',
      'startPointMinus0_1s' => '起点 -0.1s',
      'endPointMinus0_1s' => '终点 -0.1s',
      'startPointPlus0_1s' => '起点 +0.1s',
      'endPointPlus0_1s' => '终点 +0.1s',
      'startPointPlus1s' => '起点 +1s',
      'endPointPlus1s' => '终点 +1s',
      'videoTestLabel' => '视频测试',
      'uploading' => '上传中',
      'addImage' => '添加图片',
      'removeImage' => '移除图片',
      'compressingImage' => '图片压缩中...',
      'skills' => '技能',
      'selectSkills' => '选择技能',
      'noSkillsAvailable' => '暂无可用技能',
      'usingTools' => '调用工具中...',
      'toolCallingTool' => ({required Object tool}) => '调用 ${tool}...',
      'toolCallLog' => ({required Object count}) => '工具调用: ${count}',
      'generatingReply' => '生成回复中...',
      'stopGenerating' => '停止生成',
      'thinking' => '思考中',
      'streamInterrupted' => '生成已中断',
      'showThinking' => '查看思考过程',
      'hideThinking' => '收起思考过程',
      'thinkingInProgress' => '正在思考...',
      'statsCached' => '缓存',
      'jumpToBottom' => '回到底部',
      'modelDoesNotSupportVision' => '当前模型不支持图片理解',
      'myMessage' => '我的消息',
      'aiMessage' => 'AI 消息',
      'resendFromHere' => '从此处重新发送',
      'regenerateReply' => '重新生成此回复',
      'noPersonality' => '无人格',
      'noSystemPromptUsed' => '不使用系统提示词',
      'queryBalance' => '查询余额',
      'balance' => '余额',
      'queryingBalance' => '查询中...',
      'balanceQueryUnsupported' => '该服务商不支持查询余额',
      'balanceQueryUrl' => '余额查询地址',
      'balanceKeyPath' => '结果字段路径',
      'balanceQueryUrlHint' => '相对路径或完整 URL',
      'balanceKeyPathHint' => '点号路径，如 data.balance',
      'balanceQueryConfig' => '余额查询配置',
      'customProviders' => '自定义服务商',
      'noCustomProviders' => '暂无自定义服务商',
      'newCustomProvider' => '新建自定义服务商',
      'newMcpServer' => '新建 MCP 服务器',
      'newSkill' => '新建技能',
      'invalidJson' => 'JSON 格式无效',
      'providerKey' => '服务商 Key',
      'providerKeyHint' => '例如 my-provider',
      'providerKeyExists' => '服务商 Key 已存在，请更换',
      'defaultModel' => '默认模型',
      'supportsVision' => '支持图片理解',
      'supportsTools' => '支持工具调用',
      'enableVision' => '启用图片理解',
      'disableVision' => '禁用图片理解',
      'enableTools' => '启用工具调用',
      'disableTools' => '禁用工具调用',
      'enterProviderKeyToAddModel' => '请先在上方填写服务商 Key 再添加模型',
      'mcpServers' => 'MCP 服务器',
      'noMcpServers' => '暂无 MCP 服务器',
      'serverName' => '服务器名称',
      'transport' => '传输方式',
      'stdio' => 'stdio',
      'http' => 'HTTP',
      'sse' => 'SSE',
      'command' => '命令',
      'args' => '参数（JSON）',
      'env' => '环境变量（JSON）',
      'serverUrl' => '服务器地址',
      'headers' => '请求头（JSON）',
      'noSkillsYet' => '暂无技能',
      'skillName' => '技能名称',
      'skillKey' => '技能 Key',
      'builtin' => '内置',
      'skillMarkdownHint' => '技能支持 Markdown 格式',
      'sendMessage' => '发送消息',
      'contextAutoCompressed' => '上下文过长，已自动压缩',
      'chatGreeting' => '今天有什么可以帮你？',
      'chatStart1' => '总结这段文本',
      'chatStart2' => '写一首诗',
      'chatStart3' => '解释一个概念',
      'chatStart4' => '翻译这段内容',
      'importSkills' => '导入技能',
      'importSkillsFromFiles' => 'Markdown 文件',
      'importSkillsFromFilesHint' => '导入一个或多个带 YAML frontmatter 的 .md 技能文件',
      'importSkillsFromFolder' => '含 SKILL.md 的文件夹',
      'importSkillsFromFolderHint' => '导入包含 SKILL.md 文件的文件夹',
      'importingSkills' => '正在导入技能...',
      'noSkillFileFound' => '所选文件夹中未找到 SKILL.md',
      'importedSkillCount' =>
          ({required Object count}) => '已导入 ${count} 个技能',
      'importedSkillCountSkipped' =>
          (
          {required Object imported, required Object skipped}) => '已导入 ${imported} 个技能，跳过 ${skipped} 个无效文件',
      'assistantProfiles' => '助手档案',
      'newProfile' => '新建档案',
      'editAssistantProfile' => '编辑档案',
      'profileName' => '档案名称',
      'profileIcon' => '图标',
      'profileIconHint' => '一个 emoji，例如 🤖',
      'profilePersona' => '人设',
      'profileTone' => '语气',
      'profilePromptFragments' => '提示片段（每行一条）',
      'profileKnowledge' => '知识（每行一条）',
      'profileParams' => '生成参数',
      'profileBehaviorPrefs' => '行为偏好',
      'customParamsHint' => '留空表示跟随服务商默认值',
      'previewSystemPrompt' => '预览系统提示',
      'tryChatting' => '试聊',
      'deleteProfile' => '删除档案',
      'confirmDeleteProfile' => '确定要删除该档案吗？',
      'noProfilesYet' => '暂无档案',
      'profileSaved' => '档案已保存',
      'profileCopiedToClipboard' => '档案已复制到剪贴板',
      'switchedToProfile' => ({required Object name}) => '已切换到 ${name}',
      'defaultAssistant' => '默认',
      'conciseReplies' => '简洁回复',
      'useMarkdownFormatting' => '使用 Markdown 排版',
      'codeFirst' => '代码优先',
      'actionableAdvice' => '给出可执行建议',
      'profileTabPersona' => '人设',
      'profileTabPrompt' => '提示词',
      'profileTabSkills' => '技能',
      'profileTabParams' => '参数',
      'profileTabBasic' => '基础',
      'profileTabExtensions' => '扩展',
      'profileTabMemory' => '记忆',
      'profileTabRequest' => '请求',
      'profileTabMcp' => 'MCP',
      'profileMcpHint' => '绑定本助手的 MCP 服务器（连接后自动导入工具）',
      'profileTabLocalTools' => '工具技能',
      'templateVarHint' => '可用变量：',
      'profilePersonaRequired' => '请先选择人格',
      'defaultAssistantCannotDelete' => '系统默认助手不可删除',
      'imageUnderstandingDisabled' => '该助手未启用图片理解',
      'modelType' => '模型类型',
      'inputModality' => '输入模态',
      'outputModality' => '输出模态',
      'supportsReasoning' => '支持推理',
      'apiFormat' => '接口格式',
      'apiFormatOpenai' => 'OpenAI（chat）',
      'apiFormatOpenaiResponses' => 'OpenAI Responses',
      'apiFormatGemini' => 'Google（Gemini）',
      'apiFormatClaude' => 'Claude（Anthropic）',
      'testConnection' => '测试连接',
      'testApiKey' => '检测 API Key',
      'enabledByApiKey' => '填写 API Key 后自动启用',
      'endpointChatCompletions' => 'Chat Completions',
      'endpointResponses' => 'Responses API',
      'connectionOk' => '连接成功',
      'modelsUrl' => '查询可用模型接口',
      'fetchModels' => '拉取可用模型',
      'noModelsReturned' => '未获取到模型',
      'enableReasoning' => '启用推理',
      'disableReasoning' => '禁用推理',
      'thinkingLevel' => '思考程度',
      'thinkingLow' => '简洁',
      'thinkingStandard' => '标准',
      'thinkingDeep' => '深度',
      'assistantSettings' => '助手设置',
      'takePhoto' => '拍照',
      'pickImages' => '图片',
      'uploadFile' => '上传文件',
      'compressHistory' => '压缩历史',
      'compressHistoryConfirm' => '压缩当前会话历史以节省 token，确定继续？',
      'compressed' => '已压缩',
      'profileLocalTools' => '本地工具',
      'profileLocalToolsHint' => '内置工具链开关',
      'profileSkills' => '技能',
      'profileSkillsHint' => '勾选扩展管理中的技能进行绑定',
      'profileRequest' => '自定义请求',
      'profileRequestSensitiveHint' => '敏感信息（如 API Key）会随档案持久化，请谨慎填写',
      'profileRequestBaseUrl' => 'Base URL 覆盖',
      'profileRequestApiKey' => 'API Key 覆盖',
      'profileRequestHeaders' => '自定义请求头（每行 Key: Value）',
      'profileRequestExtraBody' => '附加请求体字段（JSON）',
      'profileRequestStop' => '停止序列（每行一个）',
      'profileRequestStopHint' => '遇此序列停止生成',
      'profileExtensionsHint' => '应用级可选模块开关',
      'profileMemoryEnabled' => '启用长期记忆',
      'profileMemoryHint' => '记录用户偏好/常问话题/关键结论，随助手切换',
      'profileMemoryMaxEntries' => '记忆条目上限',
      'profileMemoryEntries' => '记忆条目',
      'profileMemoryClear' => '清空',
      'profileMemoryEmpty' => '暂无记忆条目',
      'profileMemoryAdd' => '新增记忆',
      'profileCopy' => '复制',
      'profileExport' => '导出',
      'profileImport' => '导入',
      _ => null,
    } ?? switch (path) {
      'profileExported' => '已导出到剪贴板',
      'profileImportFailed' => '导入失败',
      'extensionManagement' => '扩展管理设置',
      'extensionManagementHint' => '辅助任务模型、角色管理、MCP 服务器与技能的统一入口',
      'roleManagement' => '角色管理',
      'promptManagement' => '提示词',
      'promptInjection' => '提示词注入',
      'promptInjectionHint' => '注入位置决定片段在 System Prompt 中的插入点',
      'worldBook' => '世界书',
      'worldBookEntries' => '世界书条目',
      'newPromptInjection' => '新建注入',
      'editPromptInjection' => '编辑注入',
      'injectionName' => '名称',
      'injectionContent' => '内容',
      'injectionPosition' => '注入位置',
      'injectionPositionAfterPersonality' => '人格之后',
      'injectionPositionAfterSystemPrompt' => '自定义提示词之后',
      'injectionPositionAfterKnowledge' => '知识之后',
      'injectionPositionAfterMemory' => '记忆之后',
      'injectionPositionBeforeTools' => '工具清单之前',
      'injectionSortOrder' => '排序号',
      'noInjectionsYet' => '暂无提示词注入',
      'worldBookName' => '名称',
      'worldBookTriggers' => '触发词（每行一个）',
      'worldBookTriggersHint' => '用户消息命中任一触发词时才注入',
      'worldBookContent' => '内容',
      'worldBookPriority' => '优先级（越大越靠前）',
      'worldBookPriorityHint' => '优先级高的条目先注入',
      'newWorldBookEntry' => '新建条目',
      'worldBookHitTest' => '命中测试',
      'worldBookHitTestHint' => '输入一句话，查看哪些条目会被触发',
      'worldBookHitTestPlaceholder' => '输入一句话...',
      'worldBookHitsResult' => '命中条目',
      'worldBookNoHits' => '没有条目命中',
      'noWorldBookEntriesYet' => '暂无世界书条目',
      'auxTemperature' => 'Temperature',
      'selectAssistantProfile' => '选择助手档案',
      'profilePersonalityTags' => '性格标签',
      'profilePersonalityTagsHint' => '多选标签，如 理性/幽默/毒舌/温柔',
      'profileCatchphrases' => '口头禅',
      'profileCatchphrasesHint' => '每行一个',
      'profileExamples' => '对话示例（few-shot）',
      'profileExamplesHint' => '每行一组，格式：用户: xxx | 助手: xxx',
      'profileReplyStyle' => '回复风格',
      'replyLength' => '回复长度',
      'replyLengthShort' => '简短',
      'replyLengthNormal' => '适中',
      'replyLengthDetailed' => '详细',
      'replyUseEmoji' => '使用 emoji',
      'replyUseMarkdown' => '使用 Markdown 排版',
      'replyAskBack' => '结尾反问用户',
      'mcpConnectionStatus' => '连接状态',
      'mcpConnected' => '已连接',
      'mcpDisconnected' => '未连接',
      'mcpToolsImported' => '个工具',
      'mcpReconnect' => '重连',
      'mcpTestConnection' => '测试连接',
      'mcpConnecting' => '连接中...',
      'mcpConnectionFailed' => '连接失败',
      _ => null,
    };
  }
}
