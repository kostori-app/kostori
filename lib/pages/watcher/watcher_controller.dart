import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/database/history.dart';

/// 播放页（watcher）的状态控制器，已从 mobx 迁移为 Riverpod + ChangeNotifier。
class WatcherController extends ChangeNotifier {
  History? _history;
  History? get history => _history;
  set history(History? value) {
    _history = value;
    notifyListeners();
  }

  AnimeDetails? _anime;
  AnimeDetails? get anime => _anime;
  set anime(AnimeDetails? value) {
    _anime = value;
    notifyListeners();
  }

  void init() {}
}

/// 播放页控制器（全局单例，同一时间只打开一个播放页）
final watcherControllerProvider = Provider<WatcherController>(
  (ref) => WatcherController(),
);
