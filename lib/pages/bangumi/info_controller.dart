import 'package:mobx/mobx.dart';

import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/character/character_item.dart';
import 'package:kostori/foundation/bangumi/comment/comment_item.dart';
import 'package:kostori/foundation/bangumi/staff/staff_item.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/bangumi.dart';

import 'package:kostori/foundation/bangumi/episode/episode_item.dart';

import 'package:kostori/foundation/bangumi/bangumi_subject_relations_item.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  late BangumiItem bangumiItem;
  late List<EpisodeInfo> allEpisodes;
  late int bangumiId;
  late int episode;

  EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();

  final List<String> tabs = <String>['概览', '吐槽', '角色', '制作'];

  List<BangumiSRI> bangumiSRI = [];

  @observable
  bool isLoading = false;

  @observable
  var commentsList = ObservableList<CommentItem>();

  @observable
  var characterList = ObservableList<CharacterItem>();

  @observable
  var staffList = ObservableList<StaffFullItem>();

  @observable
  var episodeCommentsList = ObservableList<EpisodeCommentItem>();

  Future<void> queryBangumiInfoByID(int id) async {
    isLoading = true;
    try {
      bangumiItem = (await Bangumi.getBangumiInfoByID(id))!;
      bangumiSRI = [];
      bangumiSRI = await Bangumi.getBangumiSRIByID(id);
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

  Future<void> queryBangumiCharactersByID(int id) async {
    characterList.clear();
    await Bangumi.getCharatersByID(id).then((value) {
      characterList.addAll(value.characterList);
    });
    Map<String, int> relationValue = {
      '主角': 1,
      '配角': 2,
      '客串': 3,
      '未知': 4,
    };
    try {
      characterList.sort((a, b) =>
          relationValue[a.relation]!.compareTo(relationValue[b.relation]!));
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
  }

  Future<void> queryBangumiStaffsByID(int id) async {
    staffList.clear();
    await Bangumi.getBangumiStaffByID(id).then((value) {
      staffList.addAll(value.data);
    });
  }

  Future<void> queryBangumiEpisodeCommentsByID(int id, int episode,
      {int offset = 0}) async {
    if (offset == 0) {
      episodeCommentsList.clear();
    }

    episodeInfo = await Bangumi.getBangumiEpisodeByID(id, episode);
    await Bangumi.getBangumiCommentsByEpisodeID(episodeInfo.id).then((value) {
      episodeCommentsList.addAll(value.commentList);
    });
  }
}
