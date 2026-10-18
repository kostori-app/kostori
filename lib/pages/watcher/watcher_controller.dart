import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/database/history.dart';

/// 播放页（watcher）的状态控制器，使用 Riverpod 管理实例。
@immutable
class WatcherState {
  const WatcherState({this.history, this.anime});

  final History? history;
  final AnimeDetails? anime;

  WatcherState copyWith({Object? history = _unset, Object? anime = _unset}) {
    return WatcherState(
      history: identical(history, _unset) ? this.history : history as History?,
      anime: identical(anime, _unset) ? this.anime : anime as AnimeDetails?,
    );
  }
}

const _unset = Object();

class WatcherController extends Notifier<WatcherState> {
  History? get history => state.history;
  set history(History? value) {
    state = state.copyWith(history: value);
  }

  AnimeDetails? get anime => state.anime;
  set anime(AnimeDetails? value) {
    state = state.copyWith(anime: value);
  }

  @override
  WatcherState build() => const WatcherState();

  void init() {}
}

/// 播放页控制器（全局单例，同一时间只打开一个播放页）
final watcherControllerProvider =
    NotifierProvider<WatcherController, WatcherState>(WatcherController.new);
