import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/res.dart';

/// 消息内容片段：文本或图片
sealed class AiContentPart {
  const AiContentPart();

  Map<String, dynamic> toJson();
}

class AiTextPart extends AiContentPart {
  final String text;

  const AiTextPart(this.text);

  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'text': text};
}

/// 图片片段：`dataUrl` 为图片 URL 或 `data:<mime>;base64,<...>` 字符串
class AiImagePart extends AiContentPart {
  final String dataUrl;

  const AiImagePart(this.dataUrl);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'image_url',
    'image_url': {'url': dataUrl},
  };
}

abstract class AiMessage {
  final String role;
  final String content;

  const AiMessage({required this.role, this.content = ''});

  Map<String, dynamic> toJson();
}

class AiUserMessage extends AiMessage {
  final List<AiContentPart>? parts;

  const AiUserMessage({super.content = '', this.parts}) : super(role: 'user');

  @override
  Map<String, dynamic> toJson() {
    if (parts == null || parts!.isEmpty) {
      return {'role': role, 'content': content};
    }
    return {
      'role': role,
      'content': [
        if (content.isNotEmpty) AiTextPart(content).toJson(),
        ...parts!.map((p) => p.toJson()),
      ],
    };
  }
}

class AiSystemMessage extends AiMessage {
  const AiSystemMessage({required super.content}) : super(role: 'system');

  @override
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AiToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
  });
}

class AiAssistantMessage extends AiMessage {
  final List<AiToolCall>? toolCalls;

  const AiAssistantMessage({super.content = '', this.toolCalls})
    : super(role: 'assistant');

  @override
  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (toolCalls != null)
      'tool_calls': [
        for (final tc in toolCalls!)
          {
            'id': tc.id,
            'type': 'function',
            'function': {
              'name': tc.name,
              'arguments': jsonEncode(tc.arguments),
            },
          },
      ],
  };
}

/// 工具执行结果消息（role: tool）
class AiToolResultMessage extends AiMessage {
  final String toolCallId;
  final String toolName;

  const AiToolResultMessage({
    required this.toolCallId,
    required this.toolName,
    required String result,
  }) : super(role: 'tool', content: result);

  @override
  Map<String, dynamic> toJson() => {
    'role': 'tool',
    'tool_call_id': toolCallId,
    'name': toolName,
    'content': content,
  };
}

/// 工具定义（OpenAI function schema）
class AiToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const AiToolDefinition({
    required this.name,
    required this.description,
    this.parameters = const {},
  });

  Map<String, dynamic> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      if (parameters.isNotEmpty) 'parameters': parameters,
    },
  };
}

/// 工具调用回调，返回工具执行结果字符串
typedef AiToolHandler =
    Future<String> Function(String name, Map<String, dynamic> arguments);

/// 生成参数（可空字段表示跟随服务商默认值）
class AiGenerationParams {
  final double? temperature;
  final double? topP;
  final int? maxTokens;

  const AiGenerationParams({this.temperature, this.topP, this.maxTokens});

  const AiGenerationParams.none()
    : temperature = null,
      topP = null,
      maxTokens = null;

  bool get isEmpty => temperature == null && topP == null && maxTokens == null;
}

/// 单次请求的 token 消耗统计，随 [Res.subData] 返回
class AiUsage {
  final int? promptTokens;
  final int? completionTokens;

  /// 本次请求中被缓存命中的输入 token 数；提供方有返回才填入，无则 null
  final int? cachedTokens;

  /// 本次实际使用的模型名
  final String? modelName;

  const AiUsage({
    this.promptTokens,
    this.completionTokens,
    this.cachedTokens,
    this.modelName,
  });

  int get total => (promptTokens ?? 0) + (completionTokens ?? 0);

  Map<String, dynamic> toJson() => {
    if (promptTokens != null) 'prompt': promptTokens,
    if (completionTokens != null) 'completion': completionTokens,
    if (cachedTokens != null) 'cached': cachedTokens,
  };
}

/// 解析 `data:<mime>;base64,<data>` 字符串；非 data URL 返回 null。
({String mime, String data})? parseDataUrl(String dataUrl) {
  if (!dataUrl.startsWith('data:')) return null;
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  final header = dataUrl.substring(5, comma);
  return (mime: header.split(';').first, data: dataUrl.substring(comma + 1));
}

/// 解析 SSE 字节流，逐条产出 `data:` 载荷（去除前缀，忽略注释与空行）。
Stream<String> sseDataLines(Stream<Uint8List> stream) async* {
  var buffer = '';
  await for (final chunk in utf8.decoder.bind(stream)) {
    buffer += chunk;
    final lines = buffer.split('\n');
    buffer = lines.removeLast();
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('data:')) {
        yield trimmed.substring(5).trim();
      }
    }
  }
  if (buffer.isNotEmpty) {
    final trimmed = buffer.trim();
    if (trimmed.startsWith('data:')) {
      yield trimmed.substring(5).trim();
    }
  }
}

/// 将工具调用参数 JSON 字符串解析为 Map；空串或非法时返回空 Map。
Map<String, dynamic> parseToolArguments(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const {};
  try {
    final decoded = jsonDecode(trimmed);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// 从各服务商的错误结构中提取可读信息
String aiErrorMessageOf(Object? error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? msg;
    if (data is Map) {
      final top = data['message'];
      if (top is String && top.isNotEmpty) msg = top;
      final err = data['error'];
      if (err is Map) {
        final em = err['message'];
        if (em is String && em.isNotEmpty) msg = em;
      }
    }
    msg ??= error.message ?? 'HTTP ${status ?? '?'}';
    return status != null ? 'HTTP $status: $msg' : msg;
  }
  if (error is Map) {
    final msg = error['message'];
    if (msg is String && msg.isNotEmpty) return msg;
    return error.toString();
  }
  return error?.toString() ?? 'Unknown error';
}

/// 流式对话增量片段：各字段为当前轮次的累计值。
class AiStreamChunk {
  /// 已累计的回复文本
  final String text;

  /// 已累计的思考内容（如 DeepSeek 推理 / Gemini thinking）
  final String reasoning;

  /// 已累计的工具调用
  final List<AiToolCall> toolCalls;

  /// 最终 token 统计（通常仅最后一个片段携带）
  final AiUsage? usage;

  /// 本轮是否已结束
  final bool done;

  /// 结束原因（如 stop / tool_calls / STOP）
  final String? finishReason;

  /// 出错信息（出错时携带，流提前结束）
  final String? errorMessage;

  const AiStreamChunk({
    this.text = '',
    this.reasoning = '',
    this.toolCalls = const [],
    this.usage,
    this.done = false,
    this.finishReason,
    this.errorMessage,
  });
}

/// 查询余额不支持的标记错误信息
const String kBalanceQueryUnsupported = '__balance_unsupported__';

abstract class AiBase {
  String get sourceName;

  String get providerKey;

  /// 是否支持多模态（图片）
  bool get supportsVision => true;

  /// 是否支持工具调用（function calling）
  bool get supportsTools => true;

  /// 是否支持流式工具调用（增量 function calling）
  bool get supportsStreamingTools => true;

  /// 按模型查询是否支持图片（优先读 AiModels 的按模型标记，缺省回退到服务商级）
  Future<bool> modelSupportsVision([String? modelId]) async {
    if (modelId == null) return supportsVision;
    final model = await AiDatabase.instance.aiModelDao.getModel(
      providerKey,
      modelId,
    );
    return model?.supportsVision ?? supportsVision;
  }

  /// 按模型查询是否支持工具调用（优先读 AiModels 的按模型标记，缺省回退到服务商级）
  Future<bool> modelSupportsTools([String? modelId]) async {
    if (modelId == null) return supportsTools;
    final model = await AiDatabase.instance.aiModelDao.getModel(
      providerKey,
      modelId,
    );
    return model?.supportsTools ?? supportsTools;
  }

  Future<Res<String>> chat(
    List<AiMessage> messages, {
    String? systemPrompt,
    String? modelOverride,
    AiGenerationParams? params,
    AiProviderConfig? configOverride,
  });

  Future<Res<String>> generate(
    String prompt, {
    String? systemPrompt,
    String? modelOverride,
    AiGenerationParams? params,
    AiProviderConfig? configOverride,
  }) => chat(
    [AiUserMessage(content: prompt)],
    systemPrompt: systemPrompt,
    modelOverride: modelOverride,
    params: params,
    configOverride: configOverride,
  );

  /// 带工具调用的对话。默认实现忽略工具，仅做普通对话。
  Future<Res<String>> chatWithTools({
    required List<AiMessage> messages,
    String? systemPrompt,
    List<AiToolDefinition>? tools,
    AiToolHandler? onToolCall,
    String? modelOverride,
    AiGenerationParams? params,
    AiProviderConfig? configOverride,
  }) => chat(
    messages,
    systemPrompt: systemPrompt,
    modelOverride: modelOverride,
    params: params,
    configOverride: configOverride,
  );

  /// 流式对话。默认实现退化为一次性 [chat] / [chatWithTools]。
  /// 实现应逐段产出累计文本 / 思考 / 工具调用，
  /// 并在结束时携带 [AiStreamChunk.done]；主动取消时静默结束（不视为错误）。
  Stream<AiStreamChunk> chatStream(
    List<AiMessage> messages, {
    String? systemPrompt,
    List<AiToolDefinition>? tools,
    CancelToken? cancelToken,
    String? modelOverride,
    AiGenerationParams? params,
    AiProviderConfig? configOverride,
  }) async* {
    final res = (tools == null || tools.isEmpty)
        ? await chat(
            messages,
            systemPrompt: systemPrompt,
            modelOverride: modelOverride,
            params: params,
            configOverride: configOverride,
          )
        : await chatWithTools(
            messages: messages,
            systemPrompt: systemPrompt,
            tools: tools,
            modelOverride: modelOverride,
            params: params,
            configOverride: configOverride,
          );
    if (res.error) {
      yield AiStreamChunk(errorMessage: res.errorMessage);
    } else {
      yield AiStreamChunk(
        text: res.data,
        usage: res.subData,
        done: true,
        finishReason: 'stop',
      );
    }
  }

  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    required AiProviderConfig config,
    String? systemPrompt,
    List<AiToolDefinition>? tools,
    AiGenerationParams? params,
  });

  String parseContent(dynamic responseData);

  Map<String, String> buildHeaders(AiProviderConfig config);

  String buildUrl(AiProviderConfig config);

  AiProviderConfig buildConfig(AiApiKey row, {String? modelOverride});

  Future<AiApiKey?> getKeyRow() =>
      AiDatabase.instance.aiApiKeyDao.getByProvider(providerKey);

  /// 查询账户余额。不支持的返回 [Res.error]，
  /// 其 [Res.errorMessage] 为 [kBalanceQueryUnsupported]。
  Future<Res<String>> queryBalance() =>
      Future.value(const Res.error(kBalanceQueryUnsupported));
}
