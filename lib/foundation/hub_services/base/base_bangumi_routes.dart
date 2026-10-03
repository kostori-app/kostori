part of 'package:kostori/foundation/hub_services/services.dart';

/// 番剧条目的对外接口：条目检索 + 条目详情分享截图。
///
/// 两个接口都是公开接口（不挂鉴权中间件），供分享卡片生成、外部集成与
/// 局域网控制直接调用。截图走 [ImageExporter] 框架，GUI 与无头模式共用
/// 同一份卡片组件（[renderShareWidgetPng]）。
///
/// 公开意味着任何能访问端口的设备都能触发，因此两个接口都挂了限流：
/// 检索较轻、截图很重（4~6 次 bgm.tv 请求 + 一次离屏渲染），额度分开设置。
extension BaseBangumiRoutes on BaseHttpService {
  /// 注册番剧条目相关路由。由 `_registerCommonRoutes` 调用。
  void registerBangumiRoutes() {
    addGet(
      '/bangumi/search',
      (req, params) async {
        final query = req.requestedUri.queryParameters;
        final keyword = (query['q'] ?? query['keyword'] ?? '').trim();
        if (keyword.isEmpty) {
          return sendError(
            req,
            HttpStatus.badRequest,
            'MISSING_KEYWORD',
            'Query parameter "q" is required',
          );
        }

        final limit = _parseLimit(query['limit'], fallback: 20, max: 50);
        final found = await Bangumi.instance.combinedBangumiSearch(keyword);
        final exact = found.where((e) => _isExactMatch(e, keyword));
        // 完全匹配（中文名/原名/别名完全一致）排最前，调用方可直接取用
        final matches = [
          ...exact,
          ...found.where((e) => !_isExactMatch(e, keyword)),
        ].take(limit).map(_bangumiBrief).toList();

        return sendJson(req, {
          'keyword': keyword,
          'count': matches.length,
          'exact': _exactCountOf(found, keyword),
          'matches': matches,
        });
      },
      middlewares: [Middleware.rateLimit(maxRequests: 30)],
      doc: RouteDoc(
        summary: '番剧条目检索',
        description:
            '按关键词检索番剧条目，返回 bangumiid / name / animezh。'
            '完全匹配的条目排在最前（exact 为完全匹配条数），'
            '把 matches[0].bangumiid 传给 /bangumi/screenshot 即可生成详情分享截图。',
        response:
            'JSON: keyword, count, exact, matches[{bangumiid, name, animezh}]',
        params: [
          DocParam(
            name: 'q',
            type: 'query',
            description: '检索关键词，支持中文名 / 原名 / 别名',
            required: true,
            example: '葬送的芙莉莲',
          ),
          DocParam(
            name: 'limit',
            type: 'query',
            description: '返回条数上限，默认 20，最大 50',
            required: false,
            example: '10',
          ),
        ],
      ),
    );

    addGet(
      '/bangumi/screenshot',
      (req, params) async {
        final query = req.requestedUri.queryParameters;
        final rawId = (query['bangumiid'] ?? query['id'] ?? '').trim();
        final keyword = (query['q'] ?? query['keyword'] ?? '').trim();
        final theme = themeOverrideFromQuery(query);
        final width = _parseWidth(query['width']) ?? ImageExporter.defaultWidth;

        if (rawId.isEmpty && keyword.isEmpty) {
          return sendError(
            req,
            HttpStatus.badRequest,
            'MISSING_PARAM',
            'Query parameter "bangumiid" or "q" is required',
          );
        }

        // 1) 给了 id：跳过检索与匹配判定，直接按 id 渲染
        if (rawId.isNotEmpty) {
          final id = int.tryParse(rawId);
          if (id == null || id <= 0) {
            return sendError(
              req,
              HttpStatus.badRequest,
              'INVALID_ID',
              'Invalid bangumiid: $rawId',
            );
          }
          return await sendBangumiScreenshot(
            req,
            id,
            themeOverride: theme,
            width: width,
          );
        }

        // 2) 只给关键词：先检索，唯一完全匹配才出图
        final found = await Bangumi.instance.combinedBangumiSearch(keyword);
        final exact = found.where((e) => _isExactMatch(e, keyword)).toList();

        if (exact.isEmpty) {
          // 没有完全匹配：带上候选条目，调用方改用 bangumiid 重试即可
          return sendJson(req, {
            'keyword': keyword,
            'matched': false,
            'reason': '没有完全匹配的条目，请从 candidates 中选一个用 bangumiid 重试',
            'candidates': found.take(10).map(_bangumiBrief).toList(),
          }, status: HttpStatus.notFound);
        }

        if (exact.length > 1) {
          return sendJson(req, {
            'keyword': keyword,
            'matched': false,
            'reason': '存在多个完全匹配的条目，请用 bangumiid 指定其中一个',
            'candidates': exact.map(_bangumiBrief).toList(),
          }, status: HttpStatus.conflict);
        }

        return await sendBangumiScreenshot(
          req,
          exact.first.id,
          themeOverride: theme,
          width: width,
          matchedKeyword: keyword,
        );
      },
      // 截图很重：一次请求会打 4~6 次 bgm.tv 并做一次离屏渲染
      middlewares: [Middleware.rateLimit(maxRequests: 10)],
      doc: RouteDoc(
        summary: '番剧条目详情分享截图',
        description:
            '返回番剧条目详情分享截图（与 App 内分享卡片一致）。'
            '给 ?bangumiid=<id> 时跳过检索直接渲染；'
            '给 ?q=<关键词> 时先检索，只有唯一完全匹配才返回 200，'
            '无匹配返回 404、多重匹配返回 409，后两种都会带上 candidates。',
        response:
            '图片 PNG（响应头附带 x-bangumiid / x-bangumi-name / x-bangumi-animezh）',
        params: [
          DocParam(
            name: 'bangumiid',
            type: 'query',
            description: 'bgm 条目 id，与 q 二选一；给出后跳过检索',
            required: false,
            example: '400602',
          ),
          DocParam(
            name: 'q',
            type: 'query',
            description: '检索关键词，与 bangumiid 二选一；需唯一完全匹配',
            required: false,
            example: '葬送的芙莉莲',
          ),
          DocParam(
            name: 'width',
            type: 'query',
            description: '截图逻辑宽度，默认 800，可选 240~2000',
            required: false,
            example: '800',
          ),
          DocParam(
            name: 'theme',
            type: 'query',
            description: '配色明暗：light 或 dark，缺省沿用应用主题',
            required: false,
          ),
          DocParam(
            name: 'seed',
            type: 'query',
            description: '主题色：teal / pink / green 等名称，或 #RRGGBB',
            required: false,
          ),
        ],
      ),
    );
  }

  /// 渲染条目详情分享卡片并回传 PNG。
  ///
  /// 命中条目会写进响应头（percent-encoded），调用方无需 OCR 即可知道
  /// 渲染的是哪一条；按关键词请求时额外回写 `x-matched-keyword`。
  Future<shelf.Response> sendBangumiScreenshot(
    shelf.Request req,
    int bangumiId, {
    ThemeData? themeOverride,
    double width = ImageExporter.defaultWidth,
    String? matchedKeyword,
  }) async {
    // 先确认条目存在，避免渲染出一张只有占位内容的图
    final item = await Bangumi.instance.bindFind(bangumiId);
    if (item == null) {
      return sendError(
        req,
        HttpStatus.notFound,
        'NOT_FOUND',
        'Bangumi subject not found: $bangumiId',
      );
    }

    try {
      final bytes = await renderShareWidgetPng(
        id: bangumiId,
        themeOverride: themeOverride,
        width: width,
        // GUI 下复用 navigator 上下文；无头模式传 null，由框架回退离屏宿主
        context: App.mainNavigatorKey?.currentContext,
      );

      if (bytes == null) {
        return sendError(
          req,
          HttpStatus.internalServerError,
          'CAPTURE_FAILED',
          'Failed to generate screenshot for $bangumiId',
        );
      }

      return sendImage(
        req,
        bytes,
        extraHeaders: {
          'x-bangumiid': '$bangumiId',
          'x-bangumi-name': _encodeHeaderValue(item.name),
          'x-bangumi-animezh': _encodeHeaderValue(item.nameCn),
          if (matchedKeyword != null)
            'x-matched-keyword': _encodeHeaderValue(matchedKeyword),
        },
      );
    } catch (e, s) {
      HubLog.error('$runtimeType', '生成番剧详情截图失败: $e\n$s');
      return sendError(
        req,
        HttpStatus.internalServerError,
        'SERVER_ERROR',
        e.toString(),
      );
    }
  }
}

/// 条目摘要字段：`bangumiid` / `name` / `animezh`。
///
/// `name` 为原名（一般日文），`animezh` 为中文名。注意 bgm 没有中文名时
/// [BangumiItem.fromJson] 会让 nameCn 回退成 name，两者会相同。
Map<String, dynamic> _bangumiBrief(BangumiItem item) => {
  'bangumiid': item.id,
  'name': item.name,
  'animezh': item.nameCn.isNotEmpty ? item.nameCn : item.name,
};

/// 条目是否与关键词「完全匹配」。
///
/// 比对原名、中文名与全部别名，忽略首尾空白与大小写；不做包含匹配，
/// 避免「咒术回战」命中「咒术回战 0」这类条目。
bool _isExactMatch(BangumiItem item, String keyword) {
  final target = keyword.trim().toLowerCase();
  if (target.isEmpty) return false;
  return [
    item.name,
    item.nameCn,
    ...?item.alias,
  ].any((title) => title.trim().toLowerCase() == target);
}

int _exactCountOf(List<BangumiItem> items, String keyword) =>
    items.where((e) => _isExactMatch(e, keyword)).length;

int _parseLimit(String? raw, {required int fallback, required int max}) {
  final value = int.tryParse(raw ?? '');
  if (value == null || value <= 0) return fallback;
  return min(value, max);
}

/// 解析截图逻辑宽度，非法或超范围时返回 null 交由调用方取默认值。
double? _parseWidth(String? raw) {
  final value = double.tryParse(raw ?? '');
  if (value == null || value < 240 || value > 2000) return null;
  return value;
}

/// HTTP 头只能放 latin-1，日文 / 中文标题统一 percent-encode，
/// 客户端用 decodeURIComponent 还原。
String _encodeHeaderValue(String value) => Uri.encodeComponent(value);
