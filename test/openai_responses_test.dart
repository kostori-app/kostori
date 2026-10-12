import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/ai_service/claude_responses_ai.dart';

Map<String, dynamic> _reply(String text) => {
  'output': [
    {
      'type': 'message',
      'role': 'assistant',
      'content': [
        {'type': 'output_text', 'text': text},
      ],
    },
  ],
  'usage': {
    'input_tokens': 12,
    'output_tokens': 4,
    'input_tokens_details': {'cached_tokens': 3},
  },
};

void main() {
  late HttpServer server;
  late Dio dio;
  late ResponsesAi ai;
  late String base;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}/v1/';
    dio = Dio();
    ai = ResponsesAi(
      providerKey: 'openai',
      sourceName: 'OpenAI',
      defaultModel: 'gpt-4.1-mini',
      defaultBaseUrl: base,
      dio: dio,
      keyLoader: () async => AiApiKey(
        provider: 'openai',
        apiKey: 'sk-test',
        baseUrl: base,
        model: 'gpt-4.1-mini',
        isEnabled: true,
        updatedAt: DateTime(2026, 10, 9),
      ),
    );
  });
  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
  });

  test('官方 Responses 请求包含认证、正确路径、图片与自定义参数', () async {
    late String path;
    late String? authorization;
    late String? customHeader;
    late Map<String, dynamic> body;
    server.listen((request) async {
      path = request.uri.path;
      authorization = request.headers.value('authorization');
      customHeader = request.headers.value('x-custom');
      body = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_reply('Hello')));
      await request.response.close();
    });
    final result = await ai.chat(
      [
        const AiUserMessage(
          content: 'Describe',
          parts: [AiImagePart('data:image/png;base64,AQID')],
        ),
      ],
      configOverride: OpenAiCompatibleConfig(
        source: 'openai',
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
        baseUrl: base,
        customHeaders: const {'x-custom': 'configured'},
        extraBodyFields: const {'max_output_tokens': 50},
      ),
    );
    expect(result.error, isFalse);
    expect(result.data, 'Hello');
    expect(path, '/v1/responses');
    expect(authorization, 'Bearer sk-test');
    expect(customHeader, 'configured');
    expect(body['store'], isFalse);
    expect(body['max_output_tokens'], 50);
    final content = (body['input'] as List).first['content'] as List;
    expect(content[0]['type'], 'input_text');
    expect(content[1]['type'], 'input_image');
    expect(content[1]['image_url'], 'data:image/png;base64,AQID');
    final usage = result.subData as AiUsage;
    expect(usage.promptTokens, 12);
    expect(usage.completionTokens, 4);
    expect(usage.cachedTokens, 3);
  });

  test('并行工具调用下一轮保留原始推理项与每个调用 ID', () async {
    final requests = <Map<String, dynamic>>[];
    const rawOutput = [
      {
        'type': 'reasoning',
        'id': 'rs-test',
        'summary': <Object>[],
        'encrypted_content': 'opaque-state',
      },
      {
        'type': 'function_call',
        'id': 'fc-first',
        'call_id': 'call-first',
        'name': 'first',
        'arguments': '{"value":1}',
      },
      {
        'type': 'function_call',
        'id': 'fc-second',
        'call_id': 'call-second',
        'name': 'second',
        'arguments': '{"value":2}',
      },
    ];
    server.listen((request) async {
      requests.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          requests.length == 1 ? {'output': rawOutput} : _reply('Finished'),
        ),
      );
      await request.response.close();
    });
    final executed = <String>[];
    final result = await ai.chatWithTools(
      messages: [const AiUserMessage(content: 'Run both')],
      tools: [
        const AiToolDefinition(name: 'first', description: 'First'),
        const AiToolDefinition(name: 'second', description: 'Second'),
      ],
      onToolCall: (name, arguments) async {
        executed.add(name);
        return arguments['value'].toString();
      },
    );
    expect(result.error, isFalse);
    expect(result.data, 'Finished');
    expect(executed, ['first', 'second']);
    expect(requests, hasLength(2));
    expect(
      requests.every(
        (body) =>
            (body['include'] as List).contains('reasoning.encrypted_content'),
      ),
      isTrue,
    );
    final history = requests[1]['input'] as List;
    expect(history.skip(1).take(3), rawOutput);
    final results = history
        .whereType<Map>()
        .where((item) => item['type'] == 'function_call_output')
        .toList();
    expect(results.map((item) => item['call_id']), [
      'call-first',
      'call-second',
    ]);
    expect(results.map((item) => item['output']), ['1', '2']);
  });

  test('SSE 文本逐段累积，完成事件携带 token 统计', () async {
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      final events = [
        {'type': 'response.output_text.delta', 'delta': '你'},
        {'type': 'response.output_text.delta', 'delta': '好'},
        {'type': 'response.completed', 'response': _reply('你好')},
      ];
      final bytes = utf8.encode(
        events.map((event) => 'data: ${jsonEncode(event)}\n\n').join(),
      );
      for (var offset = 0; offset < bytes.length; offset += 3) {
        final end = (offset + 3).clamp(0, bytes.length);
        request.response.add(bytes.sublist(offset, end));
      }
      await request.response.close();
    });
    final chunks = await ai.chatStream([
      const AiUserMessage(content: 'Hi'),
    ]).toList();
    expect(chunks.where((chunk) => !chunk.done).map((chunk) => chunk.text), [
      '你',
      '你好',
    ]);
    expect(chunks.last.done, isTrue);
    expect(chunks.last.text, '你好');
    expect(chunks.last.usage!.cachedTokens, 3);
  });

  test('流式工具结果可供实际聊天循环执行，并保留下一轮的供应商上下文', () async {
    late Map<String, dynamic> requestBody;
    final output = [
      {
        'type': 'reasoning',
        'id': 'rs-stream',
        'summary': <Object>[],
        'encrypted_content': 'opaque-stream-state',
      },
      {
        'type': 'function_call',
        'id': 'fc-stream',
        'call_id': 'call-stream',
        'name': 'lookup',
        'arguments': '{"id":7}',
      },
    ];
    server.listen((request) async {
      requestBody = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'type': 'response.completed',
          'response': {'output': output},
        })}\n\n',
      );
      await request.response.close();
    });
    final chunks = await ai
        .chatStream(
          [const AiUserMessage(content: 'Lookup')],
          tools: [
            const AiToolDefinition(name: 'lookup', description: 'Lookup'),
          ],
        )
        .toList();
    expect(ai.supportsStreamingTools, isTrue);
    expect(requestBody['tools'], hasLength(1));
    expect(requestBody['include'], contains('reasoning.encrypted_content'));
    expect(chunks.last.finishReason, 'tool_calls');
    expect(chunks.last.toolCalls.single.id, 'call-stream');
    expect(chunks.last.toolCalls.single.arguments, {'id': 7});
    final assistant = AiAssistantMessage(
      content: chunks.last.text,
      toolCalls: chunks.last.toolCalls,
      responseItems: chunks.last.responseItems,
    );
    final nextBody = ai.buildRequest(
      [
        assistant,
        const AiToolResultMessage(
          toolCallId: 'call-stream',
          toolName: 'lookup',
          result: 'found',
        ),
      ],
      config: OpenAiCompatibleConfig(
        source: 'openai',
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
        baseUrl: base,
      ),
    );
    expect((nextBody['input'] as List).take(2), output);
    expect((nextBody['input'] as List).last['call_id'], 'call-stream');
    expect(assistant.toJson().containsKey('responseItems'), isFalse);
  });

  test('鉴权失败返回服务端原因，而不是空文本成功', () async {
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.statusCode = 401;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error': {'message': 'wrong API key'},
        }),
      );
      await request.response.close();
    });
    final result = await ai.chat([const AiUserMessage(content: 'Hi')]);
    expect(result.error, isTrue);
    expect(result.errorMessage, contains('wrong API key'));
  });

  test('HTTP 成功但响应为失败或空内容时不会误报成功', () async {
    var requests = 0;
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          requests++ < 2
              ? {
                  'status': 'failed',
                  'error': {'message': 'model unavailable'},
                  'output': <Object>[],
                }
              : {'status': 'completed', 'output': <Object>[]},
        ),
      );
      await request.response.close();
    });
    final failed = await ai.chat([const AiUserMessage(content: 'Hi')]);
    expect(failed.error, isTrue);
    expect(failed.errorMessage, contains('model unavailable'));
    var called = false;
    final toolFailed = await ai.chatWithTools(
      messages: [const AiUserMessage(content: 'Hi')],
      tools: [const AiToolDefinition(name: 'lookup', description: 'Lookup')],
      onToolCall: (_, _) async {
        called = true;
        return 'unexpected';
      },
    );
    expect(toolFailed.error, isTrue);
    expect(toolFailed.errorMessage, contains('model unavailable'));
    expect(called, isFalse);
    final empty = await ai.chat([const AiUserMessage(content: 'Hi')]);
    expect(empty.error, isTrue);
    expect(empty.errorMessage, isNotEmpty);
  });

  test('流式完成事件没有正文或工具调用时返回空响应错误', () async {
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'type': 'response.completed',
          'response': {'status': 'completed', 'output': <Object>[]},
        })}\n\n',
      );
      await request.response.close();
    });
    final chunks = await ai.chatStream([
      const AiUserMessage(content: 'Hi'),
    ]).toList();
    expect(chunks.last.errorMessage, isNotEmpty);
    expect(chunks.last.done, isFalse);
  });
}
