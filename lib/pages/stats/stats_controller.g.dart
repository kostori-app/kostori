// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$StatsController on _StatsController, Store {
  Computed<List<StatsDataImpl>>? _$entriesForSelectedDayComputed;

  @override
  List<StatsDataImpl> get entriesForSelectedDay =>
      (_$entriesForSelectedDayComputed ??= Computed<List<StatsDataImpl>>(
        () => super.entriesForSelectedDay,
        name: '_StatsController.entriesForSelectedDay',
      )).value;
  Computed<int>? _$totalEventCountComputed;

  @override
  int get totalEventCount => (_$totalEventCountComputed ??= Computed<int>(
    () => super.totalEventCount,
    name: '_StatsController.totalEventCount',
  )).value;

  late final _$focusedDayAtom = Atom(
    name: '_StatsController.focusedDay',
    context: context,
  );

  @override
  DateTime get focusedDay {
    _$focusedDayAtom.reportRead();
    return super.focusedDay;
  }

  @override
  set focusedDay(DateTime value) {
    _$focusedDayAtom.reportWrite(value, super.focusedDay, () {
      super.focusedDay = value;
    });
  }

  late final _$selectedDayAtom = Atom(
    name: '_StatsController.selectedDay',
    context: context,
  );

  @override
  DateTime? get selectedDay {
    _$selectedDayAtom.reportRead();
    return super.selectedDay;
  }

  @override
  set selectedDay(DateTime? value) {
    _$selectedDayAtom.reportWrite(value, super.selectedDay, () {
      super.selectedDay = value;
    });
  }

  late final _$calendarFormatAtom = Atom(
    name: '_StatsController.calendarFormat',
    context: context,
  );

  @override
  CalendarFormat get calendarFormat {
    _$calendarFormatAtom.reportRead();
    return super.calendarFormat;
  }

  @override
  set calendarFormat(CalendarFormat value) {
    _$calendarFormatAtom.reportWrite(value, super.calendarFormat, () {
      super.calendarFormat = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_StatsController.isLoading',
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

  late final _$eventMapAtom = Atom(
    name: '_StatsController.eventMap',
    context: context,
  );

  @override
  ObservableMap<DateTime, List<StatsDataImpl>> get eventMap {
    _$eventMapAtom.reportRead();
    return super.eventMap;
  }

  @override
  set eventMap(ObservableMap<DateTime, List<StatsDataImpl>> value) {
    _$eventMapAtom.reportWrite(value, super.eventMap, () {
      super.eventMap = value;
    });
  }

  late final _$loadEventsAsyncAction = AsyncAction(
    '_StatsController.loadEvents',
    context: context,
  );

  @override
  Future<void> loadEvents() {
    return _$loadEventsAsyncAction.run(() => super.loadEvents());
  }

  late final _$_StatsControllerActionController = ActionController(
    name: '_StatsController',
    context: context,
  );

  @override
  void onDaySelected(DateTime newSelectedDay, DateTime newFocusedDay) {
    final _$actionInfo = _$_StatsControllerActionController.startAction(
      name: '_StatsController.onDaySelected',
    );
    try {
      return super.onDaySelected(newSelectedDay, newFocusedDay);
    } finally {
      _$_StatsControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onPageChanged(DateTime newFocusedDay) {
    final _$actionInfo = _$_StatsControllerActionController.startAction(
      name: '_StatsController.onPageChanged',
    );
    try {
      return super.onPageChanged(newFocusedDay);
    } finally {
      _$_StatsControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void onFormatChanged(CalendarFormat format) {
    final _$actionInfo = _$_StatsControllerActionController.startAction(
      name: '_StatsController.onFormatChanged',
    );
    try {
      return super.onFormatChanged(format);
    } finally {
      _$_StatsControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void jumpToDate(DateTime targetDate) {
    final _$actionInfo = _$_StatsControllerActionController.startAction(
      name: '_StatsController.jumpToDate',
    );
    try {
      return super.jumpToDate(targetDate);
    } finally {
      _$_StatsControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
focusedDay: ${focusedDay},
selectedDay: ${selectedDay},
calendarFormat: ${calendarFormat},
isLoading: ${isLoading},
eventMap: ${eventMap},
entriesForSelectedDay: ${entriesForSelectedDay},
totalEventCount: ${totalEventCount}
    ''';
  }
}
