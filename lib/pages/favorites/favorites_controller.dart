// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../foundation/bangumi/bangumi_item.dart';
import '../../foundation/favorites.dart';
import '../../network/bangumi.dart';

part 'favorites_controller.g.dart';

class FavoritesController = _FavoritesController with _$FavoritesController;

abstract class _FavoritesController with Store {
  late TabController tabController;

  String bangumiUserName = '';

  LocalFavoritesManager get manager => LocalFavoritesManager();
  @observable
  bool isLoading = false;
  @observable
  List<Tab> tabs = [];
  @observable
  List<String> folders = [];
  @observable
  String folder = '';
  @observable
  int index = 0;
  @observable
  bool isRefreshEnabled = false;
  @observable
  var animes = ObservableMap<String, List<FavoriteItem>>();
  @observable
  var doingList = ObservableList<BangumiItem>();
  @observable
  var collectList = ObservableList<BangumiItem>();
  @observable
  var wishList = ObservableList<BangumiItem>();
  @observable
  var onHoldList = ObservableList<BangumiItem>();
  @observable
  var droppedList = ObservableList<BangumiItem>();

  //在看
  Future<void> queryBangumiFavoriteDoingByName({
    int offset = 0,
    required String name,
  }) async {
    if (offset == 0) {
      doingList.clear();
    }
    await Bangumi.getBangumiUseFavoritesByName(
      offset: offset,
      name: name,
      type: 3,
    ).then((value) {
      final existingIds = doingList.map((e) => e.id).toSet();
      final newItems = value
          .where((item) => !existingIds.contains(item.id))
          .toList();
      doingList.addAll(newItems);
    });
  }

  //想看
  Future<void> queryBangumiFavoriteWishByName({
    int offset = 0,
    required String name,
  }) async {
    if (offset == 0) {
      wishList.clear();
    }
    await Bangumi.getBangumiUseFavoritesByName(
      offset: offset,
      name: name,
      type: 1,
    ).then((value) {
      final existingIds = wishList.map((e) => e.id).toSet();
      final newItems = value
          .where((item) => !existingIds.contains(item.id))
          .toList();
      wishList.addAll(newItems);
    });
  }

  //看过
  Future<void> queryBangumiFavoriteCollectByName({
    int offset = 0,
    required String name,
  }) async {
    if (offset == 0) {
      collectList.clear();
    }
    await Bangumi.getBangumiUseFavoritesByName(
      offset: offset,
      name: name,
      type: 2,
    ).then((value) {
      final existingIds = collectList.map((e) => e.id).toSet();
      final newItems = value
          .where((item) => !existingIds.contains(item.id))
          .toList();
      collectList.addAll(newItems);
    });
  }

  //搁置
  Future<void> queryBangumiFavoriteOnHoldByName({
    int offset = 0,
    required String name,
  }) async {
    if (offset == 0) {
      onHoldList.clear();
    }
    await Bangumi.getBangumiUseFavoritesByName(
      offset: offset,
      name: name,
      type: 4,
    ).then((value) {
      final existingIds = onHoldList.map((e) => e.id).toSet();
      final newItems = value
          .where((item) => !existingIds.contains(item.id))
          .toList();
      onHoldList.addAll(newItems);
    });
  }

  //抛弃
  Future<void> queryBangumiFavoriteDroppedByName({
    int offset = 0,
    required String name,
  }) async {
    if (offset == 0) {
      droppedList.clear();
    }
    await Bangumi.getBangumiUseFavoritesByName(
      offset: offset,
      name: name,
      type: 5,
    ).then((value) {
      final existingIds = droppedList.map((e) => e.id).toSet();
      final newItems = value
          .where((item) => !existingIds.contains(item.id))
          .toList();
      droppedList.addAll(newItems);
    });
  }

  Future<void> updateAnimes() async {}
}
