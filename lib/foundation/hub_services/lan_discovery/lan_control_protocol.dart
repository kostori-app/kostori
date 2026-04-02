part of 'package:kostori/foundation/hub_services/services.dart';

enum LanControlMessageType {
  playerControl,
  episodeSelect,
  navigate,
  animeAction,
  syncStatus,
  disconnect,
  controlResponse,
  statusSync,
  error,
  ping,
  pong;

  String get name => switch (this) {
    LanControlMessageType.playerControl => 'player_control',
    LanControlMessageType.episodeSelect => 'episode_select',
    LanControlMessageType.navigate => 'navigate',
    LanControlMessageType.animeAction => 'anime_action',
    LanControlMessageType.syncStatus => 'sync_status',
    LanControlMessageType.disconnect => 'disconnect',
    LanControlMessageType.controlResponse => 'control_response',
    LanControlMessageType.statusSync => 'status_sync',
    LanControlMessageType.error => 'error',
    LanControlMessageType.ping => 'ping',
    LanControlMessageType.pong => 'pong',
  };

  static LanControlMessageType? fromString(String name) {
    return LanControlMessageType.values
        .cast<LanControlMessageType?>()
        .firstWhere((t) => t?.name == name, orElse: () => null);
  }
}

enum AnimeActionType {
  play,
  openDetail,
  syncProgress;

  String get name => switch (this) {
    AnimeActionType.play => 'play',
    AnimeActionType.openDetail => 'open_detail',
    AnimeActionType.syncProgress => 'sync_progress',
  };

  static AnimeActionType? fromString(String name) {
    return AnimeActionType.values.cast<AnimeActionType?>().firstWhere(
      (t) => t?.name == name,
      orElse: () => null,
    );
  }
}

enum PlayerControlAction {
  play,
  pause,
  toggle,
  seek,
  seekForward,
  seekBackward,
  setVolume,
  setSpeed,
  setQuality,
  nextEpisode,
  previousEpisode;

  String get name => switch (this) {
    PlayerControlAction.play => 'play',
    PlayerControlAction.pause => 'pause',
    PlayerControlAction.toggle => 'toggle',
    PlayerControlAction.seek => 'seek',
    PlayerControlAction.seekForward => 'seek_forward',
    PlayerControlAction.seekBackward => 'seek_backward',
    PlayerControlAction.setVolume => 'set_volume',
    PlayerControlAction.setSpeed => 'set_speed',
    PlayerControlAction.setQuality => 'set_quality',
    PlayerControlAction.nextEpisode => 'next_episode',
    PlayerControlAction.previousEpisode => 'previous_episode',
  };

  static PlayerControlAction? fromString(String name) {
    return PlayerControlAction.values.cast<PlayerControlAction?>().firstWhere(
      (a) => a?.name == name,
      orElse: () => null,
    );
  }
}

enum NavigateTarget {
  animeDetail,
  search,
  bangumi,
  settings,
  exitPlayer;

  String get name => switch (this) {
    NavigateTarget.animeDetail => 'anime_detail',
    NavigateTarget.search => 'search',
    NavigateTarget.bangumi => 'bangumi',
    NavigateTarget.settings => 'settings',
    NavigateTarget.exitPlayer => 'exit_player',
  };

  static NavigateTarget? fromString(String name) {
    return NavigateTarget.values.cast<NavigateTarget?>().firstWhere(
      (t) => t?.name == name,
      orElse: () => null,
    );
  }
}

class LanControlMessage {
  final LanControlMessageType type;
  final String requestId;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  LanControlMessage({
    required this.type,
    required this.requestId,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LanControlMessage.fromJson(Map<String, dynamic> json) {
    final type = LanControlMessageType.fromString(
      json['type'] as String? ?? '',
    );

    if (type == null) {
      return LanControlMessage(
        type: LanControlMessageType.error,
        requestId: json['requestId'] as String? ?? '',
        data: {'error': 'unknown_type', 'raw': json['type']},
      );
    }

    switch (type) {
      case LanControlMessageType.playerControl:
        return LanPlayerControlMessage.fromJson(json);
      case LanControlMessageType.episodeSelect:
        return LanEpisodeSelectMessage.fromJson(json);
      case LanControlMessageType.navigate:
        return LanNavigateMessage.fromJson(json);
      case LanControlMessageType.animeAction:
        return LanAnimeActionMessage.fromJson(json);
      case LanControlMessageType.controlResponse:
        return LanControlResponseMessage.fromJson(json);
      case LanControlMessageType.statusSync:
        return LanStatusSyncMessage.fromJson(json);
      default:
        return LanControlMessage(
          type: type,
          requestId: json['requestId'] as String? ?? '',
          timestamp: json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
              : DateTime.now(),
          data: json['data'] as Map<String, dynamic>?,
        );
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'requestId': requestId,
    'timestamp': timestamp.toIso8601String(),
    if (data != null) 'data': data,
  };

  static String generateRequestId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_randomId()}';
  }

  static String _randomId() {
    final random = Random.secure();
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }
}

class LanPlayerControlMessage extends LanControlMessage {
  final PlayerControlAction action;
  final dynamic value;

  LanPlayerControlMessage({
    required super.requestId,
    required this.action,
    this.value,
    super.timestamp,
  }) : super(type: LanControlMessageType.playerControl);

  factory LanPlayerControlMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return LanPlayerControlMessage(
      requestId: json['requestId'] as String? ?? '',
      action:
          PlayerControlAction.fromString(data['action'] as String? ?? '') ??
          PlayerControlAction.toggle,
      value: data['value'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'data': {'action': action.name, if (value != null) 'value': value},
  };
}

class LanEpisodeSelectMessage extends LanControlMessage {
  final int animeId;
  final String source;
  final int episode;
  final String? episodeId;
  final bool autoPlay;

  LanEpisodeSelectMessage({
    required super.requestId,
    required this.animeId,
    required this.source,
    required this.episode,
    this.episodeId,
    this.autoPlay = true,
    super.timestamp,
  }) : super(type: LanControlMessageType.episodeSelect);

  factory LanEpisodeSelectMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return LanEpisodeSelectMessage(
      requestId: json['requestId'] as String? ?? '',
      animeId: data['animeId'] as int? ?? 0,
      source: data['source'] as String? ?? 'bangumi',
      episode: data['episode'] as int? ?? 1,
      episodeId: data['episodeId'] as String?,
      autoPlay: data['autoPlay'] as bool? ?? true,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'data': {
      'animeId': animeId,
      'source': source,
      'episode': episode,
      if (episodeId != null) 'episodeId': episodeId,
      'autoPlay': autoPlay,
    },
  };
}

class LanNavigateMessage extends LanControlMessage {
  final NavigateTarget target;
  final Map<String, dynamic>? params;

  LanNavigateMessage({
    required super.requestId,
    required this.target,
    this.params,
    super.timestamp,
  }) : super(type: LanControlMessageType.navigate);

  factory LanNavigateMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return LanNavigateMessage(
      requestId: json['requestId'] as String? ?? '',
      target:
          NavigateTarget.fromString(data['target'] as String? ?? '') ??
          NavigateTarget.animeDetail,
      params: data['params'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'data': {'target': target.name, if (params != null) 'params': params},
  };
}

class LanAnimeActionMessage extends LanControlMessage {
  final String animeId;
  final String source;
  final AnimeActionType action;

  LanAnimeActionMessage({
    required super.requestId,
    required this.animeId,
    required this.source,
    required this.action,
    super.timestamp,
  }) : super(type: LanControlMessageType.animeAction);

  factory LanAnimeActionMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return LanAnimeActionMessage(
      requestId: json['requestId'] as String? ?? '',
      animeId: data['animeId'] as String? ?? '',
      source: data['source'] as String? ?? 'bangumi',
      action:
          AnimeActionType.fromString(data['action'] as String? ?? '') ??
          AnimeActionType.openDetail,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'data': {'animeId': animeId, 'source': source, 'action': action.name},
  };
}

class LanControlResponseMessage extends LanControlMessage {
  final bool success;
  final String? error;
  final Map<String, dynamic>? result;

  LanControlResponseMessage({
    required super.requestId,
    required this.success,
    this.error,
    this.result,
    super.timestamp,
  }) : super(type: LanControlMessageType.controlResponse);

  factory LanControlResponseMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return LanControlResponseMessage(
      requestId: json['requestId'] as String? ?? '',
      success: data['success'] as bool? ?? false,
      error: data['error'] as String?,
      result: data['result'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'data': {
      'success': success,
      if (error != null) 'error': error,
      if (result != null) 'result': result,
    },
  };

  factory LanControlResponseMessage.success(
    String requestId, {
    Map<String, dynamic>? result,
  }) => LanControlResponseMessage(
    requestId: requestId,
    success: true,
    result: result,
  );

  factory LanControlResponseMessage.failure(String requestId, String error) =>
      LanControlResponseMessage(
        requestId: requestId,
        success: false,
        error: error,
      );
}

class LanStatusSyncMessage extends LanControlMessage {
  final PlayerStatus? playerStatus;
  final CurrentAnime? currentAnime;
  final SyncStatus? syncStatus;

  LanStatusSyncMessage({
    String? requestId,
    this.playerStatus,
    this.currentAnime,
    this.syncStatus,
    super.timestamp,
  }) : super(
         type: LanControlMessageType.statusSync,
         requestId: requestId ?? '',
       );

  factory LanStatusSyncMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return LanStatusSyncMessage(
      requestId: json['requestId'] as String? ?? '',
      playerStatus: data['playerStatus'] != null
          ? PlayerStatus.fromJson(data['playerStatus'] as Map<String, dynamic>)
          : null,
      currentAnime: data['currentAnime'] != null
          ? CurrentAnime.fromJson(data['currentAnime'] as Map<String, dynamic>)
          : null,
      syncStatus: data['syncStatus'] != null
          ? SyncStatus.fromJson(data['syncStatus'] as Map<String, dynamic>)
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'data': {
      if (playerStatus != null) 'playerStatus': playerStatus!.toJson(),
      if (currentAnime != null) 'currentAnime': currentAnime!.toJson(),
      if (syncStatus != null) 'syncStatus': syncStatus!.toJson(),
    },
  };
}

class PlayerStatus {
  final bool isPlaying;
  final double position;
  final double duration;
  final double volume;
  final double speed;
  final String? quality;

  const PlayerStatus({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.volume,
    required this.speed,
    this.quality,
  });

  factory PlayerStatus.fromJson(Map<String, dynamic> json) => PlayerStatus(
    isPlaying: json['isPlaying'] as bool? ?? false,
    position: (json['position'] as num?)?.toDouble() ?? 0,
    duration: (json['duration'] as num?)?.toDouble() ?? 0,
    volume: (json['volume'] as num?)?.toDouble() ?? 1,
    speed: (json['speed'] as num?)?.toDouble() ?? 1,
    quality: json['quality'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'isPlaying': isPlaying,
    'position': position,
    'duration': duration,
    'volume': volume,
    'speed': speed,
    if (quality != null) 'quality': quality,
  };
}

class CurrentAnime {
  final int animeId;
  final String source;
  final String title;
  final int currentEpisode;
  final String? coverUrl;
  final Map<String, Map<String, String>>? episodes;
  final Set<int>? watchedEpisodes;

  const CurrentAnime({
    required this.animeId,
    required this.source,
    required this.title,
    required this.currentEpisode,
    this.coverUrl,
    this.episodes,
    this.watchedEpisodes,
  });

  factory CurrentAnime.fromJson(Map<String, dynamic> json) => CurrentAnime(
    animeId: json['animeId'] as int? ?? 0,
    source: json['source'] as String? ?? 'bangumi',
    title: json['title'] as String? ?? '',
    currentEpisode: json['currentEpisode'] as int? ?? 1,
    coverUrl: json['coverUrl'] as String?,
    episodes: json['episodes'] != null
        ? (json['episodes'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(
              key,
              (value as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, v.toString()),
              ),
            ),
          )
        : null,
    watchedEpisodes: json['watchedEpisodes'] != null
        ? (json['watchedEpisodes'] as List<dynamic>)
              .map((e) => e as int)
              .toSet()
        : null,
  );

  Map<String, dynamic> toJson() => {
    'animeId': animeId,
    'source': source,
    'title': title,
    'currentEpisode': currentEpisode,
    if (coverUrl != null) 'coverUrl': coverUrl,
    if (episodes != null) 'episodes': episodes,
    if (watchedEpisodes != null) 'watchedEpisodes': watchedEpisodes!.toList(),
  };
}

class SyncStatus {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final int pendingChanges;
  final String? conflictInfo;

  const SyncStatus({
    required this.isSyncing,
    this.lastSyncTime,
    this.pendingChanges = 0,
    this.conflictInfo,
  });

  factory SyncStatus.fromJson(Map<String, dynamic> json) => SyncStatus(
    isSyncing: json['isSyncing'] as bool? ?? false,
    lastSyncTime: json['lastSyncTime'] != null
        ? DateTime.tryParse(json['lastSyncTime'] as String)
        : null,
    pendingChanges: json['pendingChanges'] as int? ?? 0,
    conflictInfo: json['conflictInfo'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'isSyncing': isSyncing,
    'lastSyncTime': lastSyncTime?.toIso8601String(),
    'pendingChanges': pendingChanges,
    if (conflictInfo != null) 'conflictInfo': conflictInfo,
  };
}
