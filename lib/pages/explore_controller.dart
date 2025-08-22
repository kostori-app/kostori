import 'package:mobx/mobx.dart';

part 'explore_controller.g.dart';

// ignore: library_private_types_in_public_api
class ExploreController = _ExploreController with _$ExploreController;

abstract class _ExploreController with Store {
  @observable
  bool showFB = false;
}
