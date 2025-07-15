// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerController on _PlayerController, Store {
  late final _$loadingAtom = Atom(
    name: '_PlayerController.loading',
    context: context,
  );

  @override
  bool get loading {
    _$loadingAtom.reportRead();
    return super.loading;
  }

  @override
  set loading(bool value) {
    _$loadingAtom.reportWrite(value, super.loading, () {
      super.loading = value;
    });
  }

  late final _$isFullScreenAtom = Atom(
    name: '_PlayerController.isFullScreen',
    context: context,
  );

  @override
  bool get isFullScreen {
    _$isFullScreenAtom.reportRead();
    return super.isFullScreen;
  }

  @override
  set isFullScreen(bool value) {
    _$isFullScreenAtom.reportWrite(value, super.isFullScreen, () {
      super.isFullScreen = value;
    });
  }

  late final _$superResolutionTypeAtom = Atom(
    name: '_PlayerController.superResolutionType',
    context: context,
  );

  @override
  int get superResolutionType {
    _$superResolutionTypeAtom.reportRead();
    return super.superResolutionType;
  }

  @override
  set superResolutionType(int value) {
    _$superResolutionTypeAtom.reportWrite(value, super.superResolutionType, () {
      super.superResolutionType = value;
    });
  }

  late final _$showPreviewImageAtom = Atom(
    name: '_PlayerController.showPreviewImage',
    context: context,
  );

  @override
  bool get showPreviewImage {
    _$showPreviewImageAtom.reportRead();
    return super.showPreviewImage;
  }

  @override
  set showPreviewImage(bool value) {
    _$showPreviewImageAtom.reportWrite(value, super.showPreviewImage, () {
      super.showPreviewImage = value;
    });
  }

  late final _$playingAtom = Atom(
    name: '_PlayerController.playing',
    context: context,
  );

  @override
  bool get playing {
    _$playingAtom.reportRead();
    return super.playing;
  }

  @override
  set playing(bool value) {
    _$playingAtom.reportWrite(value, super.playing, () {
      super.playing = value;
    });
  }

  late final _$currentPositionAtom = Atom(
    name: '_PlayerController.currentPosition',
    context: context,
  );

  @override
  Duration get currentPosition {
    _$currentPositionAtom.reportRead();
    return super.currentPosition;
  }

  @override
  set currentPosition(Duration value) {
    _$currentPositionAtom.reportWrite(value, super.currentPosition, () {
      super.currentPosition = value;
    });
  }

  late final _$isBufferingAtom = Atom(
    name: '_PlayerController.isBuffering',
    context: context,
  );

  @override
  bool get isBuffering {
    _$isBufferingAtom.reportRead();
    return super.isBuffering;
  }

  @override
  set isBuffering(bool value) {
    _$isBufferingAtom.reportWrite(value, super.isBuffering, () {
      super.isBuffering = value;
    });
  }

  late final _$completedAtom = Atom(
    name: '_PlayerController.completed',
    context: context,
  );

  @override
  bool get completed {
    _$completedAtom.reportRead();
    return super.completed;
  }

  @override
  set completed(bool value) {
    _$completedAtom.reportWrite(value, super.completed, () {
      super.completed = value;
    });
  }

  late final _$bufferAtom = Atom(
    name: '_PlayerController.buffer',
    context: context,
  );

  @override
  Duration get buffer {
    _$bufferAtom.reportRead();
    return super.buffer;
  }

  @override
  set buffer(Duration value) {
    _$bufferAtom.reportWrite(value, super.buffer, () {
      super.buffer = value;
    });
  }

  late final _$durationAtom = Atom(
    name: '_PlayerController.duration',
    context: context,
  );

  @override
  Duration get duration {
    _$durationAtom.reportRead();
    return super.duration;
  }

  @override
  set duration(Duration value) {
    _$durationAtom.reportWrite(value, super.duration, () {
      super.duration = value;
    });
  }

  late final _$previewImageAtom = Atom(
    name: '_PlayerController.previewImage',
    context: context,
  );

  @override
  Uint8List? get previewImage {
    _$previewImageAtom.reportRead();
    return super.previewImage;
  }

  @override
  set previewImage(Uint8List? value) {
    _$previewImageAtom.reportWrite(value, super.previewImage, () {
      super.previewImage = value;
    });
  }

  late final _$lastPreviewTimeAtom = Atom(
    name: '_PlayerController.lastPreviewTime',
    context: context,
  );

  @override
  Duration? get lastPreviewTime {
    _$lastPreviewTimeAtom.reportRead();
    return super.lastPreviewTime;
  }

  @override
  set lastPreviewTime(Duration? value) {
    _$lastPreviewTimeAtom.reportWrite(value, super.lastPreviewTime, () {
      super.lastPreviewTime = value;
    });
  }

  late final _$showTabBodyAtom = Atom(
    name: '_PlayerController.showTabBody',
    context: context,
  );

  @override
  bool get showTabBody {
    _$showTabBodyAtom.reportRead();
    return super.showTabBody;
  }

  @override
  set showTabBody(bool value) {
    _$showTabBodyAtom.reportWrite(value, super.showTabBody, () {
      super.showTabBody = value;
    });
  }

  late final _$volumeAtom = Atom(
    name: '_PlayerController.volume',
    context: context,
  );

  @override
  double get volume {
    _$volumeAtom.reportRead();
    return super.volume;
  }

  @override
  set volume(double value) {
    _$volumeAtom.reportWrite(value, super.volume, () {
      super.volume = value;
    });
  }

  late final _$brightnessAtom = Atom(
    name: '_PlayerController.brightness',
    context: context,
  );

  @override
  double get brightness {
    _$brightnessAtom.reportRead();
    return super.brightness;
  }

  @override
  set brightness(double value) {
    _$brightnessAtom.reportWrite(value, super.brightness, () {
      super.brightness = value;
    });
  }

  late final _$playerSpeedAtom = Atom(
    name: '_PlayerController.playerSpeed',
    context: context,
  );

  @override
  double get playerSpeed {
    _$playerSpeedAtom.reportRead();
    return super.playerSpeed;
  }

  @override
  set playerSpeed(double value) {
    _$playerSpeedAtom.reportWrite(value, super.playerSpeed, () {
      super.playerSpeed = value;
    });
  }

  late final _$showSeekTimeAtom = Atom(
    name: '_PlayerController.showSeekTime',
    context: context,
  );

  @override
  bool get showSeekTime {
    _$showSeekTimeAtom.reportRead();
    return super.showSeekTime;
  }

  @override
  set showSeekTime(bool value) {
    _$showSeekTimeAtom.reportWrite(value, super.showSeekTime, () {
      super.showSeekTime = value;
    });
  }

  late final _$showPlaySpeedAtom = Atom(
    name: '_PlayerController.showPlaySpeed',
    context: context,
  );

  @override
  bool get showPlaySpeed {
    _$showPlaySpeedAtom.reportRead();
    return super.showPlaySpeed;
  }

  @override
  set showPlaySpeed(bool value) {
    _$showPlaySpeedAtom.reportWrite(value, super.showPlaySpeed, () {
      super.showPlaySpeed = value;
    });
  }

  late final _$showBrightnessAtom = Atom(
    name: '_PlayerController.showBrightness',
    context: context,
  );

  @override
  bool get showBrightness {
    _$showBrightnessAtom.reportRead();
    return super.showBrightness;
  }

  @override
  set showBrightness(bool value) {
    _$showBrightnessAtom.reportWrite(value, super.showBrightness, () {
      super.showBrightness = value;
    });
  }

  late final _$showVolumeAtom = Atom(
    name: '_PlayerController.showVolume',
    context: context,
  );

  @override
  bool get showVolume {
    _$showVolumeAtom.reportRead();
    return super.showVolume;
  }

  @override
  set showVolume(bool value) {
    _$showVolumeAtom.reportWrite(value, super.showVolume, () {
      super.showVolume = value;
    });
  }

  late final _$showVideoControllerAtom = Atom(
    name: '_PlayerController.showVideoController',
    context: context,
  );

  @override
  bool get showVideoController {
    _$showVideoControllerAtom.reportRead();
    return super.showVideoController;
  }

  @override
  set showVideoController(bool value) {
    _$showVideoControllerAtom.reportWrite(value, super.showVideoController, () {
      super.showVideoController = value;
    });
  }

  late final _$volumeSeekingAtom = Atom(
    name: '_PlayerController.volumeSeeking',
    context: context,
  );

  @override
  bool get volumeSeeking {
    _$volumeSeekingAtom.reportRead();
    return super.volumeSeeking;
  }

  @override
  set volumeSeeking(bool value) {
    _$volumeSeekingAtom.reportWrite(value, super.volumeSeeking, () {
      super.volumeSeeking = value;
    });
  }

  late final _$brightnessSeekingAtom = Atom(
    name: '_PlayerController.brightnessSeeking',
    context: context,
  );

  @override
  bool get brightnessSeeking {
    _$brightnessSeekingAtom.reportRead();
    return super.brightnessSeeking;
  }

  @override
  set brightnessSeeking(bool value) {
    _$brightnessSeekingAtom.reportWrite(value, super.brightnessSeeking, () {
      super.brightnessSeeking = value;
    });
  }

  late final _$canHidePlayerPanelAtom = Atom(
    name: '_PlayerController.canHidePlayerPanel',
    context: context,
  );

  @override
  bool get canHidePlayerPanel {
    _$canHidePlayerPanelAtom.reportRead();
    return super.canHidePlayerPanel;
  }

  @override
  set canHidePlayerPanel(bool value) {
    _$canHidePlayerPanelAtom.reportWrite(value, super.canHidePlayerPanel, () {
      super.canHidePlayerPanel = value;
    });
  }

  @override
  String toString() {
    return '''
loading: ${loading},
isFullScreen: ${isFullScreen},
superResolutionType: ${superResolutionType},
showPreviewImage: ${showPreviewImage},
playing: ${playing},
currentPosition: ${currentPosition},
isBuffering: ${isBuffering},
completed: ${completed},
buffer: ${buffer},
duration: ${duration},
previewImage: ${previewImage},
lastPreviewTime: ${lastPreviewTime},
showTabBody: ${showTabBody},
volume: ${volume},
brightness: ${brightness},
playerSpeed: ${playerSpeed},
showSeekTime: ${showSeekTime},
showPlaySpeed: ${showPlaySpeed},
showBrightness: ${showBrightness},
showVolume: ${showVolume},
showVideoController: ${showVideoController},
volumeSeeking: ${volumeSeeking},
brightnessSeeking: ${brightnessSeeking},
canHidePlayerPanel: ${canHidePlayerPanel}
    ''';
  }
}
