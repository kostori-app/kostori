// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$InfoController on _InfoController, Store {
  late final _$isLoadingAtom = Atom(
    name: '_InfoController.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$commentsListAtom = Atom(
    name: '_InfoController.commentsList',
    context: context,
  );

  @override
  ObservableList<CommentItem> get commentsList {
    _$commentsListAtom.reportRead();
    return super.commentsList;
  }

  @override
  set commentsList(ObservableList<CommentItem> value) {
    _$commentsListAtom.reportWrite(value, super.commentsList, () {
      super.commentsList = value;
    });
  }

  late final _$topicsListAtom = Atom(
    name: '_InfoController.topicsList',
    context: context,
  );

  @override
  ObservableList<TopicsItem> get topicsList {
    _$topicsListAtom.reportRead();
    return super.topicsList;
  }

  @override
  set topicsList(ObservableList<TopicsItem> value) {
    _$topicsListAtom.reportWrite(value, super.topicsList, () {
      super.topicsList = value;
    });
  }

  late final _$topicsLatestListAtom = Atom(
    name: '_InfoController.topicsLatestList',
    context: context,
  );

  @override
  ObservableList<TopicsInfoItem> get topicsLatestList {
    _$topicsLatestListAtom.reportRead();
    return super.topicsLatestList;
  }

  @override
  set topicsLatestList(ObservableList<TopicsInfoItem> value) {
    _$topicsLatestListAtom.reportWrite(value, super.topicsLatestList, () {
      super.topicsLatestList = value;
    });
  }

  late final _$topicsTrendingListAtom = Atom(
    name: '_InfoController.topicsTrendingList',
    context: context,
  );

  @override
  ObservableList<TopicsInfoItem> get topicsTrendingList {
    _$topicsTrendingListAtom.reportRead();
    return super.topicsTrendingList;
  }

  @override
  set topicsTrendingList(ObservableList<TopicsInfoItem> value) {
    _$topicsTrendingListAtom.reportWrite(value, super.topicsTrendingList, () {
      super.topicsTrendingList = value;
    });
  }

  late final _$reviewsListAtom = Atom(
    name: '_InfoController.reviewsList',
    context: context,
  );

  @override
  ObservableList<ReviewsItem> get reviewsList {
    _$reviewsListAtom.reportRead();
    return super.reviewsList;
  }

  @override
  set reviewsList(ObservableList<ReviewsItem> value) {
    _$reviewsListAtom.reportWrite(value, super.reviewsList, () {
      super.reviewsList = value;
    });
  }

  late final _$characterListAtom = Atom(
    name: '_InfoController.characterList',
    context: context,
  );

  @override
  ObservableList<CharacterItem> get characterList {
    _$characterListAtom.reportRead();
    return super.characterList;
  }

  @override
  set characterList(ObservableList<CharacterItem> value) {
    _$characterListAtom.reportWrite(value, super.characterList, () {
      super.characterList = value;
    });
  }

  late final _$staffListAtom = Atom(
    name: '_InfoController.staffList',
    context: context,
  );

  @override
  ObservableList<StaffFullItem> get staffList {
    _$staffListAtom.reportRead();
    return super.staffList;
  }

  @override
  set staffList(ObservableList<StaffFullItem> value) {
    _$staffListAtom.reportWrite(value, super.staffList, () {
      super.staffList = value;
    });
  }

  late final _$episodeCommentsListAtom = Atom(
    name: '_InfoController.episodeCommentsList',
    context: context,
  );

  @override
  ObservableList<EpisodeCommentItem> get episodeCommentsList {
    _$episodeCommentsListAtom.reportRead();
    return super.episodeCommentsList;
  }

  @override
  set episodeCommentsList(ObservableList<EpisodeCommentItem> value) {
    _$episodeCommentsListAtom.reportWrite(value, super.episodeCommentsList, () {
      super.episodeCommentsList = value;
    });
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
commentsList: ${commentsList},
topicsList: ${topicsList},
topicsLatestList: ${topicsLatestList},
topicsTrendingList: ${topicsTrendingList},
reviewsList: ${reviewsList},
characterList: ${characterList},
staffList: ${staffList},
episodeCommentsList: ${episodeCommentsList}
    ''';
  }
}
