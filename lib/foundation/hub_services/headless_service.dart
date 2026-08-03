part of 'package:kostori/foundation/hub_services/services.dart';

class HeadlessService extends BaseHttpService {
  HeadlessService._internal();

  static final HeadlessService _instance = HeadlessService._internal();

  factory HeadlessService() => _instance;

  @override
  void registerRoutes() {
    // 版本信息（公开）
    addGet(
      '/api/version',
      (req) => sendJson(req, {
        'app': 'Kostori',
        'version': App.version,
        'headless': true,
        'timestamp': DateTime.now().toIso8601String(),
      }),
      doc: RouteDoc(
        summary: '版本信息',
        description: '返回应用版本与无头模式状态',
        response: 'JSON: app, version, headless, timestamp',
      ),
    );

    // 观看统计（需用户层鉴权，受 --no-auth 影响）
    addGet(
      '/api/stats',
      (req) async {
        final manager = StatsManager();
        if (!manager.isInitialized) await manager.init();
        final all = await manager.getStatsAll();
        var totalMs = 0;
        for (final s in all) {
          for (final d in s.totalWatchDurations) {
            for (final r in d.platformEventRecords) {
              totalMs += r.value;
            }
          }
        }
        final liked = all.where((s) => s.liked).length;
        await sendJson(req, {
          'count': all.length,
          'liked': liked,
          'watchMinutes': totalMs ~/ 60000,
          'watchDurationMs': totalMs,
        });
      },
      middlewares: _hubAuthMiddleware,
      doc: RouteDoc(
        summary: '观看统计',
        description: '返回观看统计：条目数、喜欢数、累计观看时长（需鉴权）',
        requiresAuth: true,
        response: 'JSON: count, liked, watchMinutes, watchDurationMs',
      ),
    );

    // 观看历史（需鉴权）
    addGet(
      '/api/history',
      (req) async {
        final limit =
            int.tryParse(req.uri.queryParameters['limit'] ?? '') ?? 50;
        final manager = HistoryManager();
        if (!manager.isInitialized) await manager.init();
        final all = await manager.getAll();
        final items = all
            .take(limit.clamp(1, 200))
            .map(
              (h) => {
                'title': h.title,
                'id': h.id,
                'sourceKey': h.sourceKey,
                'cover': h.cover,
                'bangumiId': h.bangumiId,
                'time': h.time.toIso8601String(),
                'lastWatchEpisode': h.lastWatchEpisode,
              },
            )
            .toList();
        await sendJson(req, {'total': all.length, 'items': items});
      },
      middlewares: _hubAuthMiddleware,
      doc: RouteDoc(
        summary: '观看历史',
        description: '返回最近的观看历史（需鉴权），?limit= 控制条数（默认 50，最大 200）',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'limit',
            type: 'query',
            description: '返回条数（1-200）',
            required: false,
          ),
        ],
        response: 'JSON: total, items[]',
      ),
    );

    // 收藏列表（需鉴权）
    addGet(
      '/api/favorites',
      (req) async {
        final name = req.uri.queryParameters['name'];
        var items = LocalFavoritesManager().allAnimes();
        if (name != null && name.isNotEmpty) {
          items = items.where((f) => f.name.contains(name)).toList();
        }
        final list = items
            .take(200)
            .map(
              (f) => {
                'name': f.name,
                'id': f.id,
                'sourceKey': f.sourceKey,
                'cover': f.coverPath,
                'folder': f.folder,
              },
            )
            .toList();
        await sendJson(req, {'count': items.length, 'items': list});
      },
      middlewares: _hubAuthMiddleware,
      doc: RouteDoc(
        summary: '收藏列表',
        description: '返回全部收藏（需鉴权），?name= 可按名称搜索',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'name',
            type: 'query',
            description: '按名称搜索',
            required: false,
          ),
        ],
        response: 'JSON: count, items[]',
      ),
    );

    // 最近日志（管理层鉴权）
    addGet(
      '/api/logs',
      (req) async {
        final limit =
            int.tryParse(req.uri.queryParameters['limit'] ?? '') ?? 50;
        final level = req.uri.queryParameters['level'];
        var logs = Log.logs;
        if (level != null && level.isNotEmpty) {
          logs = logs.where((l) => l.level.name == level).toList();
        }
        final recent = logs.length > limit.clamp(1, 200)
            ? logs.sublist(logs.length - limit.clamp(1, 200))
            : logs;
        final list = recent
            .map(
              (l) => {
                'level': l.level.name,
                'title': l.title,
                'content': l.content,
                'source': l.source.name,
                'time': l.time.toIso8601String(),
              },
            )
            .toList();
        await sendJson(req, {'count': recent.length, 'logs': list});
      },
      middlewares: [adminAuthMiddleware],
      doc: RouteDoc(
        summary: '最近日志',
        description: '返回最近的运行日志（需管理层鉴权），?level=error 等可筛选',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'level',
            type: 'query',
            description: '日志级别：error / warning / info',
            required: false,
          ),
        ],
        response: 'JSON: count, logs[]',
      ),
    );
  }

  @override
  Future<void> init({
    int preferredPort = 9001,
    BindMode mode = BindMode.ipv4,
  }) => startServer(preferredPort: preferredPort, mode: mode);

  @override
  Future<void> dispose() => stopServer();
}
