// ignore_for_file: library_private_types_in_public_api

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/bangumi_subject_relations_item.dart';
import 'package:kostori/foundation/bangumi/character/character_item.dart';
import 'package:kostori/foundation/bangumi/comment/comment_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_item.dart';
import 'package:kostori/foundation/bangumi/staff/staff_item.dart';
import 'package:kostori/foundation/bangumi/topics/topics_info_item.dart';
import 'package:kostori/foundation/bangumi/topics/topics_item.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';

/// Bangumi 详情页状态（不可变数据）
class InfoState {
  final BangumiItem? bangumiItem;
  final int bangumiId;
  final int episode;
  final EpisodeInfo episodeInfo;
  final List<History> bangumiHistory;
  final bool isLoading;
  final List<EpisodeInfo> allEpisodes;
  final List<CommentItem> commentsList;
  final List<TopicsItem> topicsList;
  final List<TopicsInfoItem> topicsLatestList;
  final List<TopicsInfoItem> topicsTrendingList;
  final List<ReviewsItem> reviewsList;
  final List<CharacterItem> characterList;
  final List<StaffFullItem> staffList;
  final List<EpisodeCommentItem> episodeCommentsList;
  final List<BangumiSRI> bangumiSRI;
  final Map<bool, EpisodeInfo?> currentWeekEp;

  InfoState({
    this.bangumiItem,
    this.bangumiId = 0,
    this.episode = 0,
    EpisodeInfo? episodeInfo,
    this.bangumiHistory = const [],
    this.isLoading = true,
    this.allEpisodes = const [],
    this.commentsList = const [],
    this.topicsList = const [],
    this.topicsLatestList = const [],
    this.topicsTrendingList = const [],
    this.reviewsList = const [],
    this.characterList = const [],
    this.staffList = const [],
    this.episodeCommentsList = const [],
    this.bangumiSRI = const [],
    this.currentWeekEp = const {},
  }) : episodeInfo = episodeInfo ?? EpisodeInfo.fromTemplate();

  InfoState copyWith({
    BangumiItem? bangumiItem,
    int? bangumiId,
    int? episode,
    EpisodeInfo? episodeInfo,
    List<History>? bangumiHistory,
    bool? isLoading,
    List<EpisodeInfo>? allEpisodes,
    List<CommentItem>? commentsList,
    List<TopicsItem>? topicsList,
    List<TopicsInfoItem>? topicsLatestList,
    List<TopicsInfoItem>? topicsTrendingList,
    List<ReviewsItem>? reviewsList,
    List<CharacterItem>? characterList,
    List<StaffFullItem>? staffList,
    List<EpisodeCommentItem>? episodeCommentsList,
    List<BangumiSRI>? bangumiSRI,
    Map<bool, EpisodeInfo?>? currentWeekEp,
  }) => InfoState(
    bangumiItem: bangumiItem ?? this.bangumiItem,
    bangumiId: bangumiId ?? this.bangumiId,
    episode: episode ?? this.episode,
    episodeInfo: episodeInfo ?? this.episodeInfo,
    bangumiHistory: bangumiHistory ?? this.bangumiHistory,
    isLoading: isLoading ?? this.isLoading,
    allEpisodes: allEpisodes ?? this.allEpisodes,
    commentsList: commentsList ?? this.commentsList,
    topicsList: topicsList ?? this.topicsList,
    topicsLatestList: topicsLatestList ?? this.topicsLatestList,
    topicsTrendingList: topicsTrendingList ?? this.topicsTrendingList,
    reviewsList: reviewsList ?? this.reviewsList,
    characterList: characterList ?? this.characterList,
    staffList: staffList ?? this.staffList,
    episodeCommentsList: episodeCommentsList ?? this.episodeCommentsList,
    bangumiSRI: bangumiSRI ?? this.bangumiSRI,
    currentWeekEp: currentWeekEp ?? this.currentWeekEp,
  );
}

/// Bangumi 详情页控制器（Riverpod Notifier）
class InfoController extends Notifier<InfoState> {
  @override
  InfoState build() => InfoState();

  BangumiManager get manager => ref.read(bangumiManagerProvider);

  void reset(BangumiItem item) {
    state = InfoState(bangumiItem: item, bangumiId: item.id);
  }

  // ── 兼容旧访问的 getter/setter 转发（消费者通过 ref.read(notifier) 获取实例） ──

  List<History> get bangumiHistory => state.bangumiHistory;

  set bangumiHistory(List<History> value) =>
      state = state.copyWith(bangumiHistory: value);

  List<EpisodeInfo> get allEpisodes => state.allEpisodes;

  List<CommentItem> get commentsList => state.commentsList;

  List<TopicsItem> get topicsList => state.topicsList;

  List<TopicsInfoItem> get topicsLatestList => state.topicsLatestList;

  List<TopicsInfoItem> get topicsTrendingList => state.topicsTrendingList;

  List<ReviewsItem> get reviewsList => state.reviewsList;

  List<CharacterItem> get characterList => state.characterList;

  List<StaffFullItem> get staffList => state.staffList;

  List<EpisodeCommentItem> get episodeCommentsList => state.episodeCommentsList;

  List<BangumiSRI> get bangumiSRI => state.bangumiSRI;

  set bangumiSRI(List<BangumiSRI> value) =>
      state = state.copyWith(bangumiSRI: value);

  BangumiItem get bangumiItem => state.bangumiItem!;

  /// 可空版本：未初始化时返回 null（外部回退 widget 传入）
  BangumiItem? get bangumiItemOrNull => state.bangumiItem;

  set bangumiItem(BangumiItem value) =>
      state = state.copyWith(bangumiItem: value, bangumiId: value.id);

  int get bangumiId => state.bangumiId;

  set bangumiId(int value) => state = state.copyWith(bangumiId: value);

  int get episode => state.episode;

  set episode(int value) => state = state.copyWith(episode: value);

  EpisodeInfo get episodeInfo => state.episodeInfo;

  bool get isLoading => state.isLoading;

  Map<bool, EpisodeInfo?> get currentWeekEp => state.currentWeekEp;

  List<String> get tabs => <String>[
    t.overview,
    t.comments,
    t.topics,
    t.log,
    t.characters,
    t.staffList,
  ];

  /// 清空详情页各列表（进入/离开页面时调用）
  void clearBangumiLists() {
    state = state.copyWith(
      bangumiHistory: const [],
      allEpisodes: const [],
      commentsList: const [],
      topicsList: const [],
      topicsLatestList: const [],
      topicsTrendingList: const [],
      reviewsList: const [],
      characterList: const [],
      staffList: const [],
      episodeCommentsList: const [],
      bangumiSRI: const [],
    );
  }

  void setBangumiHistory(List<History> value) {
    state = state.copyWith(bangumiHistory: value);
  }

  void setBangumiItem(BangumiItem value) {
    state = state.copyWith(bangumiItem: value, bangumiId: value.id);
  }

  void setCurrentWeekEp(Map<bool, EpisodeInfo?> value) {
    state = state.copyWith(currentWeekEp: value);
  }

  void setIsLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  Future<void> queryBangumiInfoByID(int id, {bool defaultToDb = false}) async {
    state = state.copyWith(isLoading: true);
    try {
      if (defaultToDb) {
        BangumiItem? bangumiBind = await Bangumi.instance.bindFind(id);
        if (bangumiBind != null) {
          state = state.copyWith(bangumiItem: bangumiBind, isLoading: false);
        } else {
          final item = (await Bangumi.instance.getBangumiInfoByID(id))!;
          state = state.copyWith(bangumiItem: item, isLoading: false);
        }
      } else {
        final item = (await Bangumi.instance.getBangumiInfoByID(id))!;
        state = state.copyWith(bangumiItem: item, isLoading: false);
      }
      final sri = await Bangumi.instance.getBangumiSRIByID(id);
      state = state.copyWith(bangumiSRI: List<BangumiSRI>.of(sri));
    } catch (e) {
      state = state.copyWith(isLoading: false);
      Log.error('queryBangumiInfoByID', e.toString());
    }
  }

  Future<void> queryBangumiEpisodeByID(
    int id, {
    bool defaultToDb = false,
  }) async {
    try {
      final result = defaultToDb
          ? await manager
                .allEpInfoFind(id)
                .then(
                  (db) async => db.isNotEmpty
                      ? db
                      : await Bangumi.instance.getBangumiEpisodeAllByID(id),
                )
          : await Bangumi.instance.getBangumiEpisodeAllByID(id);

      state = state.copyWith(allEpisodes: List<EpisodeInfo>.of(result));

      // 加载完直接计算
      if (result.isNotEmpty) {
        final week = await BangumiUtils.findCurrentWeekEpisode(
          result,
          bangumiItem,
        );
        state = state.copyWith(currentWeekEp: week);
      }
    } catch (e) {
      Log.error('queryBangumiEpisodeByID', e.toString());
    }
  }

  Future<void> queryBangumiCommentsByID(int id, {int offset = 0}) async {
    final value = await Bangumi.instance.getBangumiCommentsByID(
      id,
      offset: offset,
    );
    final existing = state.commentsList;
    state = state.copyWith(
      commentsList: offset == 0
          ? List<CommentItem>.of(value.commentList)
          : [...existing, ...value.commentList],
    );
  }

  Future<void> queryBangumiTopicsByID(int id, {int offset = 0}) async {
    final value = await Bangumi.instance.getTopicsByID(id, offset: offset);
    final existing = state.topicsList;
    state = state.copyWith(
      topicsList: offset == 0
          ? List<TopicsItem>.of(value.topicsList)
          : [...existing, ...value.topicsList],
    );
  }

  Future<void> queryBangumiTopicsLatestByID({int offset = 0}) async {
    final value = await Bangumi.instance.getTopicsLatestByID(offset: offset);
    final existing = state.topicsLatestList;
    final existingIds = existing.map((e) => e.id).toSet();
    final newItems = value
        .where((item) => !existingIds.contains(item.id))
        .toList();
    state = state.copyWith(
      topicsLatestList: offset == 0
          ? List<TopicsInfoItem>.of(value)
          : [...existing, ...newItems],
    );
  }

  Future<void> queryBangumiTopicsTrendingByID({int offset = 0}) async {
    final value = await Bangumi.instance.getTopicsTrendingByID(offset: offset);
    final existing = state.topicsTrendingList;
    final existingIds = existing.map((e) => e.id).toSet();
    final newItems = value
        .where((item) => !existingIds.contains(item.id))
        .toList();
    state = state.copyWith(
      topicsTrendingList: offset == 0
          ? List<TopicsInfoItem>.of(value)
          : [...existing, ...newItems],
    );
  }

  Future<void> queryBangumiReviewsByID(int id, {int offset = 0}) async {
    final value = await Bangumi.instance.getReviewsByID(id, offset: offset);
    final existing = state.reviewsList;
    state = state.copyWith(
      reviewsList: offset == 0
          ? List<ReviewsItem>.of(value.reviewsList)
          : [...existing, ...value.reviewsList],
    );
  }

  Future<void> queryBangumiCharactersByID(int id) async {
    final value = await Bangumi.instance.getCharatersByID(id);
    final list = List<CharacterItem>.of(value.characterList);
    Map<String, int> relationValue = {
      '主角': 1,
      '配角': 2,
      '客串': 3,
      '闲角': 4,
      '未知': 5,
    };
    try {
      list.sort(
        (a, b) =>
            relationValue[a.relation]!.compareTo(relationValue[b.relation]!),
      );
    } catch (e, s) {
      Log.error('queryBangumiCharactersByID', '$e\n$s');
    }
    state = state.copyWith(characterList: list);
  }

  Future<void> queryBangumiStaffsByID(int id) async {
    final value = await Bangumi.instance.getBangumiStaffByID(id);
    state = state.copyWith(staffList: List<StaffFullItem>.of(value.data));
  }

  Future<void> queryBangumiEpisodeCommentsByID(
    int id,
    int episode, {
    int offset = 0,
  }) async {
    final info = await Bangumi.instance.getBangumiEpisodeByID(id, episode);
    final value = await Bangumi.instance.getEpisodeCommentsByEpisodeID(info.id);
    final existing = state.episodeCommentsList;
    state = state.copyWith(
      episodeInfo: info,
      episodeCommentsList: offset == 0
          ? List<EpisodeCommentItem>.of(value.commentList)
          : [...existing, ...value.commentList],
    );
  }

  Future<void> queryBangumiEpisodeCommentsByEpID(
    int id, {
    int offset = 0,
  }) async {
    final value = await Bangumi.instance.getEpisodeCommentsByEpisodeID(id);
    final existing = state.episodeCommentsList;
    state = state.copyWith(
      episodeCommentsList: offset == 0
          ? List<EpisodeCommentItem>.of(value.commentList)
          : [...existing, ...value.commentList],
    );
  }
}

/// Bangumi 详情页控制器提供者
final infoControllerProvider = NotifierProvider<InfoController, InfoState>(
  InfoController.new,
);
