import 'dart:convert';

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/network/app_dio.dart';

/// MCP 工具定义
class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const McpTool({
    required this.name,
    this.description = '',
    this.inputSchema = const {},
  });

  AiToolDefinition toAiTool() => AiToolDefinition(
    name: name,
    description: description,
    parameters: inputSchema,
  );

  static McpTool? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name == null) return null;
    return McpTool(
      name: name.toString(),
      description: json['description']?.toString() ?? '',
      inputSchema: json['inputSchema'] is Map<String, dynamic>
          ? (json['inputSchema'] as Map<String, dynamic>)
          : const {},
    );
  }
}

/// 解析 MCP 响应体：支持 `application/json` 与 SSE（`data:` 行）两种格式
Map<String, dynamic> decodeMcpResponse(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return const {};
  if (trimmed.startsWith('{')) {
    return jsonDecode(trimmed) as Map<String, dynamic>;
  }
  for (final line in const LineSplitter().convert(trimmed)) {
    if (line.startsWith('data:')) {
      final data = line.substring(5).trim();
      if (data.isNotEmpty) {
        return jsonDecode(data) as Map<String, dynamic>;
      }
    }
  }
  return jsonDecode(trimmed) as Map<String, dynamic>;
}

/// 基于 JSON-RPC 2.0 的 MCP HTTP/SSE 客户端
class McpHttpClient {
  final int id;
  final String name;
  final String url;
  final Map<String, String> headers;

  String? _sessionId;

  McpHttpClient({
    required this.id,
    required this.name,
    required this.url,
    this.headers = const {},
  });

  Map<String, String> get _requestHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/event-stream',
    ...headers,
    if (_sessionId != null) 'Mcp-Session-Id': _sessionId!,
  };

  Future<Map<String, dynamic>> _request(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final response = await AppDio().request(
      url,
      data: {
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        if (params != null) 'params': params,
      },
      options: Options(
        method: 'POST',
        headers: _requestHeaders,
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final sessionId = response.headers.value('mcp-session-id');
    if (sessionId != null && sessionId.isNotEmpty) _sessionId = sessionId;
    final json = decodeMcpResponse(response.data as String);
    if (json['error'] != null) {
      final err = json['error'] as Map<String, dynamic>;
      throw Exception('$name MCP 错误: ${err['message']}');
    }
    return (json['result'] as Map<String, dynamic>?) ?? const {};
  }

  /// 握手初始化（协议版本可随服务端要求调整）
  Future<void> initialize() async {
    await _request('initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': {},
      'clientInfo': {'name': 'kostori', 'version': '1.0.0'},
    });
  }

  /// 拉取全部工具（处理分页）
  Future<List<McpTool>> listTools() async {
    final tools = <McpTool>[];
    String? cursor;
    do {
      final result = await _request(
        'tools/list',
        cursor == null ? <String, dynamic>{} : {'cursor': cursor},
      );
      for (final t in (result['tools'] as List? ?? const [])) {
        final tool = McpTool.fromJson(t as Map<String, dynamic>);
        if (tool != null) tools.add(tool);
      }
      cursor = result['nextCursor'] as String?;
    } while (cursor != null && cursor.isNotEmpty);
    return tools;
  }

  /// 调用工具，返回文本结果
  Future<String> callTool(String name, Map<String, dynamic> arguments) async {
    final result = await _request('tools/call', {
      'name': name,
      'arguments': arguments,
    });
    final content = result['content'] as List? ?? const [];
    final sb = StringBuffer();
    for (final c in content) {
      final cMap = c as Map<String, dynamic>;
      if (cMap['type'] == 'text' || cMap['text'] != null) {
        sb.writeln(cMap['text']);
      }
    }
    final text = sb.toString().trim();
    if (result['isError'] == true) {
      throw Exception(text.isEmpty ? '工具 $name 执行失败' : text);
    }
    return text.isEmpty ? '(空结果)' : text;
  }
}

/// 聚合已启用 MCP 服务器，输出给模型使用的工具定义与回调
class McpManager {
  static ({List<AiToolDefinition> tools, AiToolHandler handler})? _cached;
  static DateTime _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 清除工具缓存，使下次 [loadTools] 重新拉取（设置页改动后调用）
  static void invalidateCache() {
    _cached = null;
    _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Map<String, String> _parseHeaders(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {
      //
    }
    return const {};
  }

  /// 探测单个 MCP 服务器：握手 + 拉取工具，返回连接状态与工具数。
  /// stdio 传输暂不支持在线探测。
  static Future<({bool ok, int toolCount, String error})> probeServer(
    AiMcpServer server,
  ) async {
    if (server.transport == 'stdio') {
      return (ok: false, toolCount: 0, error: 'stdio 暂不支持在线探测');
    }
    final url = server.url;
    if (url == null || url.isEmpty) {
      return (ok: false, toolCount: 0, error: '缺少服务器地址');
    }
    final client = McpHttpClient(
      id: server.id,
      name: server.name,
      url: url,
      headers: _parseHeaders(server.headers),
    );
    try {
      await client.initialize();
      final tools = await client.listTools();
      return (ok: true, toolCount: tools.length, error: '');
    } catch (e) {
      return (ok: false, toolCount: 0, error: aiErrorMessageOf(e));
    }
  }

  /// 加载所有启用 MCP 服务器暴露的工具（带 60s 缓存）。
  /// 某个服务器连不上时自动跳过，不阻塞整体。
  static Future<({List<AiToolDefinition> tools, AiToolHandler handler})?>
  loadTools() async {
    if (_cached != null &&
        DateTime.now().difference(_cachedAt) < const Duration(seconds: 60)) {
      return _cached;
    }
    final servers = await AiDatabase.instance.aiMcpServerDao.getEnabled();
    final definitions = <AiToolDefinition>[];
    final owners = <String, McpHttpClient>{};
    for (final s in servers) {
      if (s.transport != 'http' && s.transport != 'sse') continue;
      final url = s.url;
      if (url == null || url.isEmpty) continue;
      final client = McpHttpClient(
        id: s.id,
        name: s.name,
        url: url,
        headers: _parseHeaders(s.headers),
      );
      try {
        await client.initialize();
        final tools = await client.listTools();
        for (final t in tools) {
          owners[t.name] = client;
          definitions.add(t.toAiTool());
        }
      } catch (e) {
        // 跳过连不上的服务器
      }
    }
    if (definitions.isEmpty) return null;
    final result = (
      tools: definitions,
      handler: (name, args) async {
        final client = owners[name];
        if (client == null) throw Exception('未找到工具: $name');
        return client.callTool(name, args);
      },
    );
    _cached = result;
    _cachedAt = DateTime.now();
    return result;
  }
}
