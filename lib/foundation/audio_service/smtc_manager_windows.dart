import 'dart:async';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:smtc_windows/smtc_windows.dart';

class SMTCManagerWindows {
  SMTCManagerWindows._privateConstructor();

  static final SMTCManagerWindows instance =
      SMTCManagerWindows._privateConstructor();

  SMTCWindows? _smtc;
  bool _isEnabled = false;

  PlayerController? _controller;

  final List<StreamSubscription> _subscriptions = [];

  // Cache last metadata to avoid redundant native calls
  String? _lastTitle;
  String? _lastArtist;
  String? _lastThumbnail;

  Future<void> init() async {
    try {
      await SMTCWindows.initialize();
      _smtc = SMTCWindows(
        enabled: true,
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: false,
          stopEnabled: false,
          fastForwardEnabled: false,
          rewindEnabled: false,
        ),
      );
      _isEnabled = true;
    } catch (e, st) {
      Log.error('Failed to initialize SMTCWindows', '$e\n$st');
    }
  }

  void setController(PlayerController controller) {
    try {
      _clearListeners();
      _ensureEnabled();
      _controller = controller;
      final player = controller.player;

      // 1. Playback status
      _subscriptions.add(
        player.stream.playing.listen((isPlaying) {
          _ensureEnabled();
          _smtc?.setPlaybackStatus(
            isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
          );
        }),
      );

      // 2. Metadata — update only when the episode/anime actually changes,
      //    not on every position tick.
      _subscriptions.add(
        player.stream.playlist.listen((_) {
          _pushMetadataIfChanged();
        }),
      );

      // 3. Timeline — still driven by position, but separated from metadata.
      _subscriptions.add(
        player.stream.position.listen((pos) {
          final duration = player.state.duration.inMilliseconds;
          updateTimeline(pos.inMilliseconds, duration);
        }),
      );

      // 4. Button events — guard against null smtc
      final buttonStream = _smtc?.buttonPressStream;
      if (buttonStream != null) {
        _subscriptions.add(
          buttonStream.listen(
            (event) {
              switch (event) {
                case PressedButton.play:
                  _controller?.playOrPause();
                  break;
                case PressedButton.pause:
                  _controller?.pause();
                  break;
                case PressedButton.next:
                  _controller?.playNextEpisode();
                  break;
                default:
                  break;
              }
            },
            // 流被取消（隐藏 SMTC / 应用退出）时 Rust 侧会上报取消错误，属正常现象，
            // 忽略 STREAM_CANCEL_ERROR，避免未处理异常。
            onError: (Object error, StackTrace st) {
              final msg = error.toString();
              if (msg.contains('STREAM_CANCEL_ERROR') ||
                  msg.contains('stream cancel') ||
                  msg.contains('channel is closed')) {
                return;
              }
              Log.error('SMTC button stream error', '$error\n$st');
            },
          ),
        );
      }

      // Push metadata immediately when the controller is first attached.
      _pushMetadataIfChanged();
    } catch (e, st) {
      Log.error('SMTC setController error', '$e\n$st');
    }
  }

  /// Only calls the native API when something actually changed,
  /// and guards every nullable field before touching SMTC.
  void _pushMetadataIfChanged() {
try {
  if (_controller == null) return;

  final title = _controller!.animeTitle;
  final artist = _controller!.currentSetName;

      // Sanitise thumbnail: empty string → null so SMTC gets no URI
      // rather than an empty one, which is what triggers the panic.
      final rawImg = _controller!.animeImg;
      final thumbnail = (rawImg.isNotEmpty) ? rawImg : null;

      // Skip the native call if nothing changed.
      if (title == _lastTitle &&
          artist == _lastArtist &&
          thumbnail == _lastThumbnail) {
        return;
      }

      _lastTitle = title;
      _lastArtist = artist;
      _lastThumbnail = thumbnail;

      updateMetadata(
        MusicMetadata(
          title: title,
          artist: artist,
          album: '',
          thumbnail: thumbnail,
        ),
      );
    } catch (e) {
      Log.error('SMTC _pushMetadataIfChanged error', '$e');
    }
  }

  void hideSmtcButKeepSession() {
    if (_smtc == null || !_isEnabled) return;
    _isEnabled = false;
    _clearListeners();
    _smtc!.setPlaybackStatus(PlaybackStatus.stopped);
    _smtc!.disableSmtc();
  }

  void _clearListeners() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    // Reset metadata cache so it is re-sent on next attach.
    _lastTitle = null;
    _lastArtist = null;
    _lastThumbnail = null;
  }

  void _ensureEnabled() {
    if (!_isEnabled && _smtc != null) {
      _smtc!.enableSmtc();
      _isEnabled = true;
    }
  }

  void onPlay() {
    _ensureEnabled();
    _smtc?.setPlaybackStatus(PlaybackStatus.playing);
  }

  void onPause() {
    _ensureEnabled();
    _smtc?.setPlaybackStatus(PlaybackStatus.paused);
  }

  void updateMetadata(MusicMetadata metadata) {
    _ensureEnabled();
    _smtc?.updateMetadata(metadata);
  }

  void updateTimeline(int positionMS, int? durationMS) {
    _ensureEnabled();
    _smtc?.updateTimeline(
      PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: durationMS ?? 0,
        positionMs: positionMS,
      ),
    );
  }
}
