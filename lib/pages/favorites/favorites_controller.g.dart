// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FavoritesController on _FavoritesController, Store {
  late final _$isLoadingAtom = Atom(
    name: '_FavoritesController.isLoading',
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

  late final _$tabsAtom = Atom(
    name: '_FavoritesController.tabs',
    context: context,
  );

  @override
  List<Tab> get tabs {
    _$tabsAtom.reportRead();
    return super.tabs;
  }

  @override
  set tabs(List<Tab> value) {
    _$tabsAtom.reportWrite(value, super.tabs, () {
      super.tabs = value;
    });
  }

  late final _$foldersAtom = Atom(
    name: '_FavoritesController.folders',
    context: context,
  );

  @override
  List<String> get folders {
    _$foldersAtom.reportRead();
    return super.folders;
  }

  @override
  set folders(List<String> value) {
    _$foldersAtom.reportWrite(value, super.folders, () {
      super.folders = value;
    });
  }

  late final _$folderAtom = Atom(
    name: '_FavoritesController.folder',
    context: context,
  );

  @override
  String get folder {
    _$folderAtom.reportRead();
    return super.folder;
  }

  @override
  set folder(String value) {
    _$folderAtom.reportWrite(value, super.folder, () {
      super.folder = value;
    });
  }

  late final _$indexAtom = Atom(
    name: '_FavoritesController.index',
    context: context,
  );

  @override
  int get index {
    _$indexAtom.reportRead();
    return super.index;
  }

  @override
  set index(int value) {
    _$indexAtom.reportWrite(value, super.index, () {
      super.index = value;
    });
  }

  late final _$isRefreshEnabledAtom = Atom(
    name: '_FavoritesController.isRefreshEnabled',
    context: context,
  );

  @override
  bool get isRefreshEnabled {
    _$isRefreshEnabledAtom.reportRead();
    return super.isRefreshEnabled;
  }

  @override
  set isRefreshEnabled(bool value) {
    _$isRefreshEnabledAtom.reportWrite(value, super.isRefreshEnabled, () {
      super.isRefreshEnabled = value;
    });
  }

  late final _$animesAtom = Atom(
    name: '_FavoritesController.animes',
    context: context,
  );

  @override
  ObservableMap<String, List<FavoriteItem>> get animes {
    _$animesAtom.reportRead();
    return super.animes;
  }

  @override
  set animes(ObservableMap<String, List<FavoriteItem>> value) {
    _$animesAtom.reportWrite(value, super.animes, () {
      super.animes = value;
    });
  }

  late final _$doingListAtom = Atom(
    name: '_FavoritesController.doingList',
    context: context,
  );

  @override
  ObservableList<BangumiItem> get doingList {
    _$doingListAtom.reportRead();
    return super.doingList;
  }

  @override
  set doingList(ObservableList<BangumiItem> value) {
    _$doingListAtom.reportWrite(value, super.doingList, () {
      super.doingList = value;
    });
  }

  late final _$collectListAtom = Atom(
    name: '_FavoritesController.collectList',
    context: context,
  );

  @override
  ObservableList<BangumiItem> get collectList {
    _$collectListAtom.reportRead();
    return super.collectList;
  }

  @override
  set collectList(ObservableList<BangumiItem> value) {
    _$collectListAtom.reportWrite(value, super.collectList, () {
      super.collectList = value;
    });
  }

  late final _$wishListAtom = Atom(
    name: '_FavoritesController.wishList',
    context: context,
  );

  @override
  ObservableList<BangumiItem> get wishList {
    _$wishListAtom.reportRead();
    return super.wishList;
  }

  @override
  set wishList(ObservableList<BangumiItem> value) {
    _$wishListAtom.reportWrite(value, super.wishList, () {
      super.wishList = value;
    });
  }

  late final _$onHoldListAtom = Atom(
    name: '_FavoritesController.onHoldList',
    context: context,
  );

  @override
  ObservableList<BangumiItem> get onHoldList {
    _$onHoldListAtom.reportRead();
    return super.onHoldList;
  }

  @override
  set onHoldList(ObservableList<BangumiItem> value) {
    _$onHoldListAtom.reportWrite(value, super.onHoldList, () {
      super.onHoldList = value;
    });
  }

  late final _$droppedListAtom = Atom(
    name: '_FavoritesController.droppedList',
    context: context,
  );

  @override
  ObservableList<BangumiItem> get droppedList {
    _$droppedListAtom.reportRead();
    return super.droppedList;
  }

  @override
  set droppedList(ObservableList<BangumiItem> value) {
    _$droppedListAtom.reportWrite(value, super.droppedList, () {
      super.droppedList = value;
    });
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
tabs: ${tabs},
folders: ${folders},
folder: ${folder},
index: ${index},
isRefreshEnabled: ${isRefreshEnabled},
animes: ${animes},
doingList: ${doingList},
collectList: ${collectList},
wishList: ${wishList},
onHoldList: ${onHoldList},
droppedList: ${droppedList}
    ''';
  }
}
