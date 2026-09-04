// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/bangumi.dart';

/// 收藏页状态（不可变数据）
class FavoritesState {
  final String bangumiUserName;
  final bool isLoading;
  final bool isRefreshEnabled;
  final int index;
  final String folder;
  final List<String> folders;
  final Map<String, List<FavoriteItem>> animes;
  final List<Tab> tabs;

  // Bangumi collection types:
  //   1 = 想看  2 = 看过  3 = 在看  4 = 搁置  5 = 抛弃
  final List<BangumiItem> wishList;
  final List<BangumiItem> doingList;
  final List<BangumiItem> collectList;
  final List<BangumiItem> onHoldList;
  final List<BangumiItem> droppedList;

  const FavoritesState({
    this.bangumiUserName = '',
    this.isLoading = false,
    this.isRefreshEnabled = false,
    this.index = 0,
    this.folder = '',
    this.folders = const [],
    this.animes = const {},
    this.tabs = const [],
    this.wishList = const [],
    this.doingList = const [],
    this.collectList = const [],
    this.onHoldList = const [],
    this.droppedList = const [],
  });

  FavoritesState copyWith({
    String? bangumiUserName,
    bool? isLoading,
    bool? isRefreshEnabled,
    int? index,
    String? folder,
    List<String>? folders,
    Map<String, List<FavoriteItem>>? animes,
    List<Tab>? tabs,
    List<BangumiItem>? wishList,
    List<BangumiItem>? doingList,
    List<BangumiItem>? collectList,
    List<BangumiItem>? onHoldList,
    List<BangumiItem>? droppedList,
  }) => FavoritesState(
    bangumiUserName: bangumiUserName ?? this.bangumiUserName,
    isLoading: isLoading ?? this.isLoading,
    isRefreshEnabled: isRefreshEnabled ?? this.isRefreshEnabled,
    index: index ?? this.index,
    folder: folder ?? this.folder,
    folders: folders ?? this.folders,
    animes: animes ?? this.animes,
    tabs: tabs ?? this.tabs,
    wishList: wishList ?? this.wishList,
    doingList: doingList ?? this.doingList,
    collectList: collectList ?? this.collectList,
    onHoldList: onHoldList ?? this.onHoldList,
    droppedList: droppedList ?? this.droppedList,
  );
}

/// 收藏页控制器（Riverpod Notifier）
class FavoritesController extends Notifier<FavoritesState> {
  /// TabController 生命周期由持有 TickerProvider 的页面负责，
  /// 这里仅保存引用供跨组件同步。不属于 [FavoritesState]。
  TabController? tabController;

  LocalFavoritesManager get manager => LocalFavoritesManager();

  @override
  FavoritesState build() {
    // provider 初始化阶段读取本地数据（widget 生命周期外执行，安全）。
    // LocalFavoritesManager 的 _db 可能在 app 启动早期尚未 init，
    // 此处加保护避免 provider 进入 error 状态导致页面异常。
    List<String> folders = const [];
    try {
      final mgr = LocalFavoritesManager();
      if (!mgr.folderNames.contains(kUnassignedFolder)) {
        mgr.createFolder(kUnassignedFolder);
      }
      // 空 default 分组不显示（与 Tab 列表保持一致）；
      // 若过滤后为空（完全无收藏），保留 default 作为可选中项
      final filtered = mgr.folderNames.where((name) {
        if (name == kUnassignedFolder) {
          return mgr.getAllAnimes(
            kUnassignedFolder,
            FavoriteSortType.nameAsc,
          ).isNotEmpty;
        }
        return true;
      }).toList();
      folders = filtered.isNotEmpty ? filtered : [kUnassignedFolder];
    } catch (e) {
      Log.error('FavoritesController.build', '$e');
      folders = [kUnassignedFolder];
    }

    final data = appdata.implicitData['favoriteFolder'];
    var index = 0;
    if (data != null) {
      final idx = folders.indexWhere((name) => name == data['name']);
      if (idx >= 0) index = idx;
    }
    final folder = folders.isNotEmpty ? folders[index] : '';

    return FavoritesState(
      bangumiUserName: appdata.settings.s.bangumiUserName,
      folders: folders,
      index: index,
      folder: folder,
    );
  }

  // ── 基础字段 ──

  void setBangumiUserName(String name) {
    state = state.copyWith(bangumiUserName: name);
  }

  void setIsLoading(bool v) => state = state.copyWith(isLoading: v);

  void setIsRefreshEnabled(bool v) {
    state = state.copyWith(isRefreshEnabled: v);
  }

  void setIndex(int v) => state = state.copyWith(index: v);

  void setFolder(String v) => state = state.copyWith(folder: v);

  void setFolders(List<String> v) => state = state.copyWith(folders: v);

  void setTabs(List<Tab> v) => state = state.copyWith(tabs: v);

  void setAnimes(Map<String, List<FavoriteItem>> v) =>
      state = state.copyWith(animes: v);

  // ── Bangumi 收藏列表 ──

  Future<void> queryBangumiWish({int offset = 0, required String name}) =>
      _queryBangumiList(
        list: _listOf('wish'),
        offset: offset,
        name: name,
        type: 1,
      );

  Future<void> queryBangumiCollect({int offset = 0, required String name}) =>
      _queryBangumiList(
        list: _listOf('collect'),
        offset: offset,
        name: name,
        type: 2,
      );

  Future<void> queryBangumiDoing({int offset = 0, required String name}) =>
      _queryBangumiList(
        list: _listOf('doing'),
        offset: offset,
        name: name,
        type: 3,
      );

  Future<void> queryBangumiOnHold({int offset = 0, required String name}) =>
      _queryBangumiList(
        list: _listOf('onHold'),
        offset: offset,
        name: name,
        type: 4,
      );

  Future<void> queryBangumiDropped({int offset = 0, required String name}) =>
      _queryBangumiList(
        list: _listOf('dropped'),
        offset: offset,
        name: name,
        type: 5,
      );

  List<BangumiItem> _listOf(String key) => switch (key) {
    'wish' => state.wishList,
    'doing' => state.doingList,
    'collect' => state.collectList,
    'onHold' => state.onHoldList,
    'dropped' => state.droppedList,
    _ => const [],
  };

  void _setList(String key, List<BangumiItem> v) {
    switch (key) {
      case 'wish':
        state = state.copyWith(wishList: v);
      case 'doing':
        state = state.copyWith(doingList: v);
      case 'collect':
        state = state.copyWith(collectList: v);
      case 'onHold':
        state = state.copyWith(onHoldList: v);
      case 'dropped':
        state = state.copyWith(droppedList: v);
    }
  }

  Future<void> _queryBangumiList({
    required List<BangumiItem> list,
    required int offset,
    required String name,
    required int type,
  }) async {
    final items = await Bangumi.instance.getBangumiUseFavoritesByName(
      offset: offset,
      name: name,
      type: type,
    );
    final existingIds = list.map((e) => e.id).toSet();
    final merged = [
      if (offset == 0) ...items.where((i) => !existingIds.contains(i.id)),
      if (offset != 0) ...list,
      if (offset != 0) ...items.where((i) => !existingIds.contains(i.id)),
    ];
    _setList(_keyOf(type), merged);
  }

  String _keyOf(int type) => switch (type) {
    1 => 'wish',
    2 => 'collect',
    3 => 'doing',
    4 => 'onHold',
    5 => 'dropped',
    _ => 'doing',
  };

  /// 清空全部 Bangumi 收藏列表
  void clearBangumiLists() {
    state = state.copyWith(
      wishList: const [],
      doingList: const [],
      collectList: const [],
      onHoldList: const [],
      droppedList: const [],
    );
  }
}

/// 收藏页控制器提供者
final favoritesControllerProvider =
    NotifierProvider<FavoritesController, FavoritesState>(
      FavoritesController.new,
    );
