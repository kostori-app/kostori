// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:mobx/mobx.dart';

part 'favorites_controller.g.dart';

class FavoritesController = _FavoritesController with _$FavoritesController;

abstract class _FavoritesController with Store {
  late TabController tabController;
  String bangumiUserName = '';

  LocalFavoritesManager get manager => LocalFavoritesManager();

  @observable
  bool isLoading = false;
  @observable
  bool isRefreshEnabled = false;
  @observable
  int index = 0;
  @observable
  String folder = '';

  @observable
  List<Tab> tabs = [];
  @observable
  List<String> folders = [];

  @observable
  var animes = ObservableMap<String, List<FavoriteItem>>();

  @observable
  var wishList = ObservableList<BangumiItem>(); // 想看
  @observable
  var doingList = ObservableList<BangumiItem>(); // 在看
  @observable
  var collectList = ObservableList<BangumiItem>(); // 看过
  @observable
  var onHoldList = ObservableList<BangumiItem>(); // 搁置
  @observable
  var droppedList = ObservableList<BangumiItem>(); // 抛弃

  // Bangumi collection types:
  //   1 = 想看  2 = 看过  3 = 在看  4 = 搁置  5 = 抛弃

  Future<void> queryBangumiWish({int offset = 0, required String name}) =>
      _queryBangumiList(list: wishList, offset: offset, name: name, type: 1);

  Future<void> queryBangumiCollect({int offset = 0, required String name}) =>
      _queryBangumiList(list: collectList, offset: offset, name: name, type: 2);

  Future<void> queryBangumiDoing({int offset = 0, required String name}) =>
      _queryBangumiList(list: doingList, offset: offset, name: name, type: 3);

  Future<void> queryBangumiOnHold({int offset = 0, required String name}) =>
      _queryBangumiList(list: onHoldList, offset: offset, name: name, type: 4);

  Future<void> queryBangumiDropped({int offset = 0, required String name}) =>
      _queryBangumiList(list: droppedList, offset: offset, name: name, type: 5);

  Future<void> _queryBangumiList({
    required ObservableList<BangumiItem> list,
    required int offset,
    required String name,
    required int type,
  }) async {
    if (offset == 0) list.clear();
    final items = await Bangumi.instance.getBangumiUseFavoritesByName(
      offset: offset,
      name: name,
      type: type,
    );
    final existingIds = list.map((e) => e.id).toSet();
    list.addAll(items.where((item) => !existingIds.contains(item.id)));
  }
}
