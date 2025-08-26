// ignore_for_file: library_private_types_in_public_api

import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/bangumi_subject_relations_item.dart';
import 'package:kostori/foundation/bangumi/character/character_item.dart';
import 'package:kostori/foundation/bangumi/comment/comment_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/bangumi/staff/staff_item.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/utils/translations.dart';
import 'package:mobx/mobx.dart';

import '../../foundation/bangumi/reviews/reviews_item.dart';
import '../../foundation/bangumi/topics/topics_info_item.dart';
import '../../foundation/bangumi/topics/topics_item.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  late BangumiItem bangumiItem;
  late List<EpisodeInfo> allEpisodes;
  late int bangumiId;
  late int episode;

  EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();

  final List<String> tabs = <String>[
    'Overview'.tl,
    'Comments'.tl,
    'Topics'.tl,
    'Log'.tl,
    'Characters'.tl,
    'StaffList'.tl,
  ];

  List<History> bangumiHistory = [];

  bool showLineChart = false;

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

  Future<void> queryBangumiInfoByID(int id) async {
    isLoading = true;
    try {
      bangumiItem = (await Bangumi.getBangumiInfoByID(id))!;
      bangumiSRI.clear();
      await Bangumi.getBangumiSRIByID(id).then((v) {
        bangumiSRI.addAll(v);
      });
      isLoading = false;
    } catch (e) {
      Log.addLog(LogLevel.error, 'queryBangumiInfoByID', e.toString());
    }
  }

  Future<void> queryBangumiEpisodeByID(int id) async {
    try {
      allEpisodes = await Bangumi.getBangumiEpisodeAllByID(id);
    } catch (e) {
      Log.addLog(LogLevel.error, 'queryBangumiEpisodeByID', e.toString());
    }
  }

  Future<void> queryBangumiCommentsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      commentsList.clear();
    }
    await Bangumi.getBangumiCommentsByID(id, offset: offset).then((value) {
      commentsList.addAll(value.commentList);
    });
  }

  Future<void> queryBangumiTopicsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      topicsList.clear();
    }
    await Bangumi.getTopicsByID(id, offset: offset).then((value) {
      topicsList.addAll(value.topicsList);
    });
  }

  Future<void> queryBangumiTopicsLatestByID({int offset = 0}) async {
    if (offset == 0) {
      topicsLatestList.clear();
    }
    await Bangumi.getTopicsLatestByID(offset: offset).then((value) {
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
    await Bangumi.getTopicsTrendingByID(offset: offset).then((value) {
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
    await Bangumi.getReviewsByID(id, offset: offset).then((value) {
      reviewsList.addAll(value.reviewsList);
    });
  }

  Future<void> queryBangumiCharactersByID(int id) async {
    characterList.clear();
    await Bangumi.getCharatersByID(id).then((value) {
      characterList.addAll(value.characterList);
    });
    Map<String, int> relationValue = {'主角': 1, '配角': 2, '客串': 3, '未知': 4};
    try {
      characterList.sort(
        (a, b) =>
            relationValue[a.relation]!.compareTo(relationValue[b.relation]!),
      );
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'queryBangumiCharactersByID', '$e\n$s');
    }
  }

  Future<void> queryBangumiStaffsByID(int id) async {
    staffList.clear();
    await Bangumi.getBangumiStaffByID(id).then((value) {
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

    episodeInfo = await Bangumi.getBangumiEpisodeByID(id, episode);
    await Bangumi.getBangumiCommentsByEpisodeID(episodeInfo.id).then((value) {
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
    await Bangumi.getBangumiCommentsByEpisodeID(id).then((value) {
      episodeCommentsList.addAll(value.commentList);
    });
  }
}
