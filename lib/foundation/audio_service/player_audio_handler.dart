import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:media_kit/media_kit.dart';

class PlayerAudioHandler extends BaseAudioHandler {
  PlayerController? _controller;

  int _headsetClicksCount = 0;
  Timer? _headsetButtonClickTimer;
  bool _willPlayWhenReady = true;

  Timer? _throttleTimer;
  bool _pendingBroadcast = false;

  final List<StreamSubscription> _subscriptions = [];

  Timer _createHeadsetClicksTimer(FutureOr<void> Function() callback) {
    return Timer(const Duration(milliseconds: 250), () async {
      try {
        await callback();
      } finally {
        _headsetButtonClickTimer?.cancel();
        _headsetButtonClickTimer = null;
        _headsetClicksCount = 0;
      }
    });
  }

  void setController(PlayerController controller) {
    try {
      _clearListeners();

      _controller = controller;
      _willPlayWhenReady = true;

      final player = controller.player;

      final streams = [
        player.stream.playing,
        player.stream.completed,
        player.stream.buffering,
        player.stream.position,
      ];

      for (final stream in streams) {
        _subscriptions.add(
          stream.listen((_) {
            if (_throttleTimer == null) {
              _broadcastState();
              _throttleTimer = Timer(const Duration(seconds: 1), () {
                _throttleTimer = null;
                if (_pendingBroadcast) {
                  _pendingBroadcast = false;
                  _broadcastState();
                }
              });
            } else {
              _pendingBroadcast = true;
            }
          }),
        );
      }

      _broadcastState();
    } catch (e) {
      Log.error("setController", e.toString());
    }
  }

  Future<void> clearController() async {
    await stop();
  }

  void _clearListeners() {
    final copy = List<StreamSubscription>.from(_subscriptions);
    for (final sub in copy) {
      try {
        sub.cancel();
      } catch (e) {
        Log.error("_clearListeners", e.toString());
      }
    }
    _subscriptions.clear();

    _throttleTimer?.cancel();
    _throttleTimer = null;
    _pendingBroadcast = false;

    _headsetButtonClickTimer?.cancel();
    _headsetButtonClickTimer = null;
    _headsetClicksCount = 0;
  }

  void _broadcastState() {
    if (_controller == null) return;

    final player = _controller!.player;
    final title = _controller!.currentSetName;
    final artUri = _controller!.animeImg;

mediaItem.add(
  MediaItem(
    id: _controller!.videoUrl,
    title: _controller!.animeTitle,
    artUri: artUri.isNotEmpty ? Uri.parse(artUri) : null,
        artist: title,
        duration: _controller!.duration,
        album: '',
        genre: '',
      ),
    );

    playbackState.add(
      playbackState.value.copyWith(
        playing: player.state.playing,
        updatePosition: player.state.position,
        bufferedPosition: player.state.buffer,
        controls: [
          player.state.playing
              ? MediaControl(
                  androidIcon: 'drawable/audio_service_pause',
                  label: 'Pause',
                  action: MediaAction.pause,
                )
              : MediaControl(
                  androidIcon: 'drawable/audio_service_play_arrow',
                  label: 'Play',
                  action: MediaAction.play,
                ),
          MediaControl(
            androidIcon: 'drawable/audio_service_skip_next',
            label: 'SkipToNext',
            action: MediaAction.skipToNext,
          ),
          MediaControl(
            androidIcon: 'drawable/audio_service_stop',
            label: 'Stop',
            action: MediaAction.stop,
          ),
        ],
        processingState: _getProcessingState(player.state),
        queueIndex: 0,
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
      ),
    );
  }

  AudioProcessingState _getProcessingState(PlayerState playerState) {
    if (playerState.buffering) return AudioProcessingState.buffering;
    if (playerState.completed) return AudioProcessingState.completed;
    return AudioProcessingState.ready;
  }

  @override
  Future<void> play() {
    Log.info("AudioService.play", "${_controller?.playing}");
    _willPlayWhenReady = true;
    return _controller?.play(isAudioHandler: false) ?? Future.value();
  }

  @override
  Future<void> pause() {
    Log.info("AudioService.pause", "${_controller?.playing}");
    _willPlayWhenReady = false;
    return _controller?.pause() ?? Future.value();
  }

  @override
  Future<void> skipToNext() {
    Log.info("AudioService.skipToNext", "${_controller?.playing}");
    return _controller?.playNextEpisode() ?? Future.value();
  }

  @override
  Future<void> stop() async {
    try {
      _clearListeners();

      try {
        await _controller?.pause();
      } catch (_) {}

      playbackState.add(
        PlaybackState(
          playing: false,
          processingState: AudioProcessingState.idle,
        ),
      );
      mediaItem.add(null);

      _controller = null;

      await super.stop();

      Log.info("AudioService.stop", "通知栏已清除");
    } catch (e) {
      Log.error("AudioService.stop", e.toString());
    }
  }

  @override
  Future<void> seek(Duration position) =>
      _controller?.player.seek(position) ?? Future.value();

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button == MediaButton.next) {
      await skipToNext();
      return;
    }

    _headsetClicksCount++;
    _headsetButtonClickTimer?.cancel();

    if (_headsetClicksCount == 1) {
      _headsetButtonClickTimer = _createHeadsetClicksTimer(
        _willPlayWhenReady ? pause : play,
      );
    } else if (_headsetClicksCount == 2) {
      _headsetButtonClickTimer = _createHeadsetClicksTimer(skipToNext);
    }
  }

  @override
  Future<void> fastForward() async {
    final player = _controller?.player;
    if (player == null) return;

    final target = player.state.position + const Duration(seconds: 10);
    await player.seek(target);
  }

  @override
  Future<void> rewind() async {
    final player = _controller?.player;
    if (player == null) return;

    var target = player.state.position - const Duration(seconds: 10);
    if (target < Duration.zero) target = Duration.zero;
    await player.seek(target);
  }
}
