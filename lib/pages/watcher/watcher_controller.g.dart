// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watcher_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$WatcherController on _WatcherController, Store {
  late final _$historyAtom = Atom(
    name: '_WatcherController.history',
    context: context,
  );

  @override
  History? get history {
    _$historyAtom.reportRead();
    return super.history;
  }

  @override
  set history(History? value) {
    _$historyAtom.reportWrite(value, super.history, () {
      super.history = value;
    });
  }

  late final _$animeAtom = Atom(
    name: '_WatcherController.anime',
    context: context,
  );

  @override
  AnimeDetails? get anime {
    _$animeAtom.reportRead();
    return super.anime;
  }

  @override
  set anime(AnimeDetails? value) {
    _$animeAtom.reportWrite(value, super.anime, () {
      super.anime = value;
    });
  }

  late final _$_WatcherControllerActionController = ActionController(
    name: '_WatcherController',
    context: context,
  );

  @override
  void init() {
    final _$actionInfo = _$_WatcherControllerActionController.startAction(
      name: '_WatcherController.init',
    );
    try {
      return super.init();
    } finally {
      _$_WatcherControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
history: ${history},
anime: ${anime}
    ''';
  }
}
