import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/history.dart';
import 'package:mobx/mobx.dart';

part 'watcher_controller.g.dart';

class WatcherController = _WatcherController with _$WatcherController;

abstract class _WatcherController with Store {
  @observable
  History? history;

  @observable
  AnimeDetails? anime;

  @action
  void init() {}
}
