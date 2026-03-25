// ignore_for_file: library_private_types_in_public_api

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
import 'package:kostori/init.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';
import 'package:mobx/mobx.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  late BangumiItem bangumiItem;
  late int bangumiId;
  late int episode;

  BangumiManager get manager => providerContainer.read(bangumiManagerProvider);

  EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();

  final List<String> tabs = <String>[
    t.overview,
    t.comments,
    t.topics,
    t.log,
    t.characters,
    t.staffList,
  ];

  List<History> bangumiHistory = [];

  bool showLineChart = false;

  @observable
  ObservableList<EpisodeInfo> allEpisodes = ObservableList();

  @observable
  bool isLoading = false;

  @observable
  var commentsList = ObservableList<CommentItem>();

  @observable
  var topicsList = ObservableList<TopicsItem>();

  @observable
  var topicsLatestList = ObservableList<TopicsInfoItem>();

  @observable
  var topicsTrendingList = ObservableList<TopicsInfoItem>();

  @observable
  var reviewsList = ObservableList<ReviewsItem>();

  @observable
  var characterList = ObservableList<CharacterItem>();

  @observable
  var staffList = ObservableList<StaffFullItem>();

  @observable
  var episodeCommentsList = ObservableList<EpisodeCommentItem>();

  @observable
  var bangumiSRI = ObservableList<BangumiSRI>();

  @observable
  Map<bool, EpisodeInfo?> currentWeekEp = {false: null};

  @action
  void setCurrentWeekEp(Map<bool, EpisodeInfo?> value) {
    currentWeekEp = value;
  }

  Future<void> queryBangumiInfoByID(int id, {bool defaultToDb = false}) async {
    isLoading = true;
    try {
      if (defaultToDb) {
        BangumiItem? bangumiBind = await Bangumi.instance.bindFind(id);
        if (bangumiBind != null) {
          bangumiItem = bangumiBind;
        } else {
          bangumiItem = (await Bangumi.instance.getBangumiInfoByID(id))!;
        }
      } else {
        bangumiItem = (await Bangumi.instance.getBangumiInfoByID(id))!;
      }
      bangumiSRI.clear();
      await Bangumi.instance.getBangumiSRIByID(id).then((v) {
        bangumiSRI.addAll(v);
      });
      isLoading = false;
    } catch (e) {
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

      allEpisodes
        ..clear()
        ..addAll(result);

      // 加载完直接计算
      if (allEpisodes.isNotEmpty) {
        currentWeekEp = await BangumiUtils.findCurrentWeekEpisode(
          allEpisodes,
          bangumiItem,
        );
      }
    } catch (e) {
      Log.error('queryBangumiEpisodeByID', e.toString());
    }
  }

  Future<void> queryBangumiCommentsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      commentsList.clear();
    }
    await Bangumi.instance.getBangumiCommentsByID(id, offset: offset).then((
      value,
    ) {
      commentsList.addAll(value.commentList);
    });
  }

  Future<void> queryBangumiTopicsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      topicsList.clear();
    }
    await Bangumi.instance.getTopicsByID(id, offset: offset).then((value) {
      topicsList.addAll(value.topicsList);
    });
  }

  Future<void> queryBangumiTopicsLatestByID({int offset = 0}) async {
    if (offset == 0) {
      topicsLatestList.clear();
    }
    await Bangumi.instance.getTopicsLatestByID(offset: offset).then((value) {
      final existingIds = topicsLatestList.map((e) => e.id).toSet();
      final newItems = value
          .where((item) => !existingIds.contains(item.id))
          .toList();
      topicsLatestList.addAll(newItems);
    });
  }

  Future<void> queryBangumiTopicsTrendingByID({int offset = 0}) async {
    if (offset == 0) {
      topicsTrendingList.clear();
    }
    await Bangumi.instance.getTopicsTrendingByID(offset: offset).then((value) {
      final existingIds = topicsTrendingList.map((e) => e.id).toSet();
      final newItems = value
          .where((item) => !existingIds.contains(item.id))
          .toList();
      topicsTrendingList.addAll(newItems);
    });
  }

  Future<void> queryBangumiReviewsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      reviewsList.clear();
    }
    await Bangumi.instance.getReviewsByID(id, offset: offset).then((value) {
      reviewsList.addAll(value.reviewsList);
    });
  }

  Future<void> queryBangumiCharactersByID(int id) async {
    characterList.clear();
    await Bangumi.instance.getCharatersByID(id).then((value) {
      characterList.addAll(value.characterList);
    });
    Map<String, int> relationValue = {
      '主角': 1,
      '配角': 2,
      '客串': 3,
      '闲角': 4,
      '未知': 5,
    };
    try {
      characterList.sort(
        (a, b) =>
            relationValue[a.relation]!.compareTo(relationValue[b.relation]!),
      );
    } catch (e, s) {
      Log.error('queryBangumiCharactersByID', '$e\n$s');
    }
  }

  Future<void> queryBangumiStaffsByID(int id) async {
    staffList.clear();
    await Bangumi.instance.getBangumiStaffByID(id).then((value) {
      staffList.addAll(value.data);
    });
  }

  Future<void> queryBangumiEpisodeCommentsByID(
    int id,
    int episode, {
    int offset = 0,
  }) async {
    if (offset == 0) {
      episodeCommentsList.clear();
    }

    episodeInfo = await Bangumi.instance.getBangumiEpisodeByID(id, episode);
    await Bangumi.instance.getEpisodeCommentsByEpisodeID(episodeInfo.id).then((
      value,
    ) {
      episodeCommentsList.addAll(value.commentList);
    });
  }

  Future<void> queryBangumiEpisodeCommentsByEpID(
    int id, {
    int offset = 0,
  }) async {
    if (offset == 0) {
      episodeCommentsList.clear();
    }
    await Bangumi.instance.getEpisodeCommentsByEpisodeID(id).then((value) {
      episodeCommentsList.addAll(value.commentList);
    });
  }
}
