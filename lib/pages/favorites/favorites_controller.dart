// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../foundation/favorites.dart';

part 'favorites_controller.g.dart';

class FavoritesController = _FavoritesController with _$FavoritesController;

abstract class _FavoritesController with Store {
  late TabController tabController;
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
  Map<String, List<FavoriteItem>> animes = {};
}
