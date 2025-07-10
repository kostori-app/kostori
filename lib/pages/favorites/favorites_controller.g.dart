// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FavoritesController on _FavoritesController, Store {
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
  Map<String, List<FavoriteItem>> get animes {
    _$animesAtom.reportRead();
    return super.animes;
  }

  @override
  set animes(Map<String, List<FavoriteItem>> value) {
    _$animesAtom.reportWrite(value, super.animes, () {
      super.animes = value;
    });
  }

  @override
  String toString() {
    return '''
tabs: ${tabs},
folders: ${folders},
folder: ${folder},
index: ${index},
isRefreshEnabled: ${isRefreshEnabled},
animes: ${animes}
    ''';
  }
}
