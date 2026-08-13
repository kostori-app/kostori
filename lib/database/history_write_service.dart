import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';

/// 数据库后台写入服务：在独立 isolate 执行历史/进度写入，
/// 避免每秒写入阻塞主线程（导致视频/UI 卡顿）。
/// 不使用 WAL（只在 history.db 单文件），靠 busy_timeout 处理偶发锁等待。
class HistoryWriteService {
  static SendPort? _send;
  static bool _started = false;
  static bool _paused = false;

  /// 暂停写入（导出/备份前调用，避免复制文件时写入导致不一致）
  static void pause() {
    _paused = true;
  }

  static void resume() {
    _paused = false;
  }

  static void _ensure() {
    if (_started) return;
    _started = true;
    final rp = ReceivePort();
    Isolate.spawn(_entry, [rp.sendPort, App.dataPath]);
    rp.listen((msg) {
      if (msg is SendPort) {
        _send = msg;
      } else if (msg is List) {
        if (msg.isNotEmpty && msg[0] == 'err') {
          debugPrint(
            'HistoryWriteService 后台写失败: ${msg.length > 2 ? msg[2] : msg}',
          );
        }
      }
    });
  }

  static void addHistory(History h) {
    _ensure();
    if (_paused) return;
    _send?.send(<String, dynamic>{'op': 'addHistory', 'h': _historyToMap(h)});
  }

  static void updateProgress({
    required String historyId,
    required AnimeType type,
    required int episode,
    required int road,
    int? progressInMilli,
    bool? isCompleted,
  }) {
    _ensure();
    if (_paused) return;
    _send?.send(<String, dynamic>{
      'op': 'updateProgress',
      'historyId': historyId,
      'type': type.value,
      'episode': episode,
      'road': road,
      'progressInMilli': progressInMilli,
      'isCompleted': isCompleted,
    });
  }

  /// 关闭后台数据库连接（WebDAV 导入/删除 history.db 前调用，释放文件占用）
  static void closeConnection() {
    _ensure();
    _send?.send(<String, dynamic>{'op': 'close'});
  }

  static Map<String, dynamic> _historyToMap(History h) => {
    'id': h.id,
    'type': h.type.value,
    'time': h.time.toIso8601String(),
    'title': h.title,
    'subtitle': h.subtitle,
    'cover': h.cover,
    'lastWatchEpisode': h.lastWatchEpisode,
    'lastWatchTime': h.lastWatchTime,
    'lastRoad': h.lastRoad,
    'allEpisode': h.allEpisode,
    'bangumiId': h.bangumiId,
    'watchEpisode': h.watchEpisode.toList(),
  };

  static History _mapToHistory(Map<String, dynamic> m) => History(
    id: m['id'] as String,
    type: HistoryType(m['type'] as int),
    time: DateTime.parse(m['time'] as String),
    title: m['title'] as String,
    subtitle: m['subtitle'] as String,
    cover: m['cover'] as String,
    lastWatchEpisode: m['lastWatchEpisode'] as int?,
    lastWatchTime: m['lastWatchTime'] as int?,
    lastRoad: m['lastRoad'] as int?,
    allEpisode: m['allEpisode'] as int?,
    bangumiId: m['bangumiId'] as int?,
    watchEpisode: (m['watchEpisode'] as List).cast<int>().toSet(),
  );

  static void _entry(List<Object?> args) async {
    final mainSend = args[0] as SendPort;
    App.dataPath = args[1] as String;
    final rp = ReceivePort();
    mainSend.send(rp.sendPort);
    final manager = HistoryManager();
    try {
      await manager.init();
    } catch (e) {
      mainSend.send(['err', 'init', e.toString()]);
      return;
    }
    rp.listen((msg) async {
      if (msg is! Map) return;
      final m = msg as Map<String, dynamic>;
      try {
        switch (m['op']) {
          case 'addHistory':
            if (!manager.isInitialized) await manager.init();
            await manager.addHistory(
              _mapToHistory(m['h'] as Map<String, dynamic>),
            );
            mainSend.send(['ok', 'addHistory']);
          case 'updateProgress':
            if (!manager.isInitialized) await manager.init();
            await manager.updateProgress(
              historyId: m['historyId'] as String,
              type: AnimeType(m['type'] as int),
              episode: m['episode'] as int,
              road: m['road'] as int,
              progressInMilli: m['progressInMilli'] as int?,
              isCompleted: m['isCompleted'] as bool?,
            );
            mainSend.send(['ok', 'updateProgress']);
          case 'close':
            // 释放 history.db 占用（WebDAV 导入前调用）
            await manager.close();
        }
      } catch (e) {
        mainSend.send(['err', m['op'], e.toString()]);
      }
    });
  }
}
