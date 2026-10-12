import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_factory.dart';
import 'package:kostori/foundation/ai_service/ai_provider_credentials.dart';
import 'package:kostori/foundation/ai_service/ai_provider_settings.dart';
import 'package:kostori/foundation/ai_service/claude_responses_ai.dart';
import 'package:kostori/foundation/ai_service/gemini_ai.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/secret_vault.dart';
import 'package:kostori/repositories/ai_provider_settings_repository.dart';

AiProviderSettings _settings({
  String source = 'openai',
  String format = 'openai_responses',
}) => AiProviderSettings(
  source: source,
  name: 'Test provider',
  baseUrl: 'https://example.com/v1/',
  apiKey: 'sk-test',
  model: 'chat-test',
  apiFormat: format,
);

void main() {
  test('API 根地址、版本路径和完整接口地址都只拼接一次', () {
    for (final base in [
      'https://api.openai.com',
      'https://api.openai.com/v1/',
      'https://api.openai.com/v1/responses',
      'https://api.openai.com/v1/chat/completions',
    ]) {
      expect(
        AiProviderApi.endpoint(base, 'responses', versioned: true),
        'https://api.openai.com/v1/responses',
      );
      expect(
        AiProviderApi.modelsEndpoint(_settings().copyWith(baseUrl: base)),
        'https://api.openai.com/v1/models',
      );
    }
    expect(
      AiProviderApi.endpoint(
        'https://relay.test/api/v1',
        'responses',
        versioned: true,
      ),
      'https://relay.test/api/v1/responses',
    );
    expect(
      AiProviderApi.endpoint('https://api.deepseek.com', 'chat/completions'),
      'https://api.deepseek.com/chat/completions',
    );
  });

  test('模型接口覆盖保留完整地址，也能相对于 API 根地址解析', () {
    expect(
      AiProviderApi.modelsEndpoint(_settings().copyWith(modelsUrl: 'catalog')),
      'https://example.com/v1/catalog',
    );
    expect(
      AiProviderApi.modelsEndpoint(
        _settings().copyWith(modelsUrl: 'https://models.test/list?limit=20'),
      ),
      'https://models.test/list?limit=20',
    );
    expect(
      AiProviderApi.baseUrl(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent',
      ),
      'https://generativelanguage.googleapis.com/v1beta',
    );
  });

  test('协议使用对应认证头，模型查询地址不附加 Key', () {
    expect(
      AiProviderApi.headers('openai_responses', 'secret')['Authorization'],
      'Bearer secret',
    );
    expect(
      AiProviderApi.headers('gemini', 'secret')['x-goog-api-key'],
      'secret',
    );
    expect(AiProviderApi.headers('claude', 'secret')['x-api-key'], 'secret');
    expect(
      AiProviderApi.headers('claude', 'secret')['anthropic-version'],
      '2023-06-01',
    );
    expect(
      AiProviderApi.headers('openai', '').containsKey('Authorization'),
      isFalse,
    );
    expect(
      AiProviderApi.modelsEndpoint(_settings().copyWith(apiKey: 'secret')),
      isNot(contains('secret')),
    );
  });

  group('统一服务商保存与兼容', () {
    late AiDatabase database;
    late AiProviderSettingsRepository repository;
    late Directory temp;
    late Dio dio;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('kostori_ai_settings_');
      App.dataPath = temp.path;
      database = AiDatabase.forTesting(NativeDatabase.memory());
      dio = Dio();
      repository = AiProviderSettingsRepository(database: database, dio: dio);
      await OpenAiProviderRegistry.refreshCustomProviders(database: database);
      await OpenAiProviderRegistry.refreshKeyFormats(database: database);
    });
    tearDown(() async {
      dio.close(force: true);
      await database.close();
      final key = File('${temp.path}${Platform.pathSeparator}hub_secret.key');
      if (await key.exists()) await key.delete();
      await temp.delete();
    });

    test('内置 OpenAI 默认创建 Responses 实现', () {
      final ai = AiFactory.create('openai');
      expect(ai, isA<ResponsesAi>());
      expect(
        OpenAiProviderRegistry.builtinProviders['openai']!.baseUrl,
        'https://api.openai.com/v1',
      );
    });

    test('内置和自定义保存相同字段，并使用同一个默认模型归属规则', () async {
      for (final source in ['openai', 'custom_my-provider']) {
        await repository.save(
          _settings(source: source).copyWith(
            modelsUrl: '/v1/catalog',
            balanceUrl: '/balance',
            balanceKey: 'balance.amount',
          ),
        );
        final key = await loadAiProviderKey(source, database: database);
        expect(key!.apiKey, 'sk-test');
        expect(key.model, 'chat-test');
        expect(key.baseUrl, 'https://example.com/v1');
        expect(key.apiFormat, 'openai_responses');
        expect(key.modelsUrl, '/v1/catalog');
        expect(key.balanceUrl, '/balance');
        expect(key.balanceKey, 'balance.amount');
        expect(
          await database.aiModelDao.getModel(source, 'chat-test'),
          isNotNull,
        );
      }
      final rawKey = await database
          .customSelect(
            'SELECT api_key FROM ai_api_keys WHERE provider = ?',
            variables: [Variable.withString('openai')],
          )
          .getSingle();
      expect(SecretVault.isEncrypted(rawKey.read<String>('api_key')), isTrue);
      final rawCustom = await database
          .customSelect(
            'SELECT api_key FROM ai_custom_providers WHERE provider = ?',
            variables: [Variable.withString('my-provider')],
          )
          .getSingle();
      expect(
        SecretVault.isEncrypted(rawCustom.read<String>('api_key')),
        isTrue,
      );
    });

    test('清空 Key 和停用状态对两类服务商都能真正保存', () async {
      for (final source in ['openai', 'custom_my-provider']) {
        await repository.save(_settings(source: source));
        await repository.save(
          _settings(source: source).copyWith(apiKey: '', isEnabled: false),
        );
        final key = await loadAiProviderKey(source, database: database);
        expect(key!.apiKey, '');
        expect(key.isEnabled, isFalse);
        expect(key.model, 'chat-test');
      }
      expect(OpenAiProviderRegistry.contains('custom_my-provider'), isFalse);
    });

    test('自定义的 Gemini、Claude 和 Responses 都从自定义表读取凭据', () async {
      for (final format in ['gemini', 'claude', 'openai_responses', 'openai']) {
        final settings = _settings(source: 'custom_$format', format: format);
        await repository.save(settings);
        final ai = AiFactory.create(settings.source)!;
        final key = await loadAiProviderKey(ai.providerKey, database: database);
        expect(key!.apiKey, 'sk-test');
        expect(key.apiFormat, format);
        expect(
          await database.aiApiKeyDao.getByProvider(settings.source),
          isNull,
        );
        if (format == 'gemini') expect(ai, isA<GeminiAi>());
        if (format == 'claude') expect(ai, isA<ClaudeAi>());
        if (format == 'openai_responses') expect(ai, isA<ResponsesAi>());
      }
    });

    test('修改 OpenAI 协议后立即更新实际请求实现', () async {
      await repository.save(_settings(format: 'openai'));
      expect(AiFactory.create('openai'), isA<OpenAiCompatibleAi>());
      await repository.save(_settings(format: 'openai_responses'));
      expect(AiFactory.create('openai'), isA<ResponsesAi>());
    });

    test('聊天模型切换更新正确配置表，凭据监听与注册表同步生效', () async {
      for (final source in ['openai', 'custom_local']) {
        await repository.save(_settings(source: source));
        final changes = watchAiProviderKey(
          source,
          database: database,
        ).asBroadcastStream();
        expect((await changes.first)!.model, 'chat-test');
        final updated = changes.firstWhere(
          (row) => row?.model == 'other-model',
        );
        await repository.updateModel(source, 'other-model');
        final row = await updated;
        expect(row!.apiKey, 'sk-test');
        expect(row.baseUrl, 'https://example.com/v1');
        expect(row.apiFormat, 'openai_responses');
        expect(row.isEnabled, isTrue);
        expect(
          (await loadAiProviderKey(source, database: database))!.model,
          'other-model',
        );
      }
      expect(await database.aiApiKeyDao.getByProvider('custom_local'), isNull);
      expect(
        OpenAiProviderRegistry.allProviders['custom_local']!.defaultModel,
        'other-model',
      );
    });

    test('导入与设为默认不会覆盖已有模型的自定义能力和名称', () async {
      await database.aiModelDao.upsertModels([
        AiModelsCompanion.insert(
          provider: 'custom_local',
          modelId: 'chat-test',
          label: 'My label',
          supportsVision: const Value(false),
          supportsTools: const Value(false),
          supportsReasoning: const Value(true),
          isActive: const Value(false),
        ),
      ]);
      final settings = _settings(source: 'custom_local');
      await repository.importModels(settings, ['chat-test', 'gpt-5-test']);
      await repository.save(settings);
      final model = await database.aiModelDao.getModel(
        settings.source,
        'chat-test',
      );
      expect(model!.label, 'My label');
      expect(model.supportsVision, isFalse);
      expect(model.supportsTools, isFalse);
      expect(model.supportsReasoning, isTrue);
      expect(model.isActive, isFalse);
      expect(
        (await database.aiModelDao.getModel(
          settings.source,
          'gpt-5-test',
        ))!.supportsReasoning,
        isTrue,
      );
    });

    test('旧版 Gemini 配置显示实际使用的原生协议', () {
      final row = AiApiKey(
        provider: 'gemini',
        apiKey: 'key',
        apiFormat: 'openai',
        isEnabled: true,
        updatedAt: DateTime(2026, 10, 9),
      );
      final settings = repository.builtinSettings('gemini', row);
      expect(settings.apiFormat, 'gemini');
      expect(settings.fixedApiFormat, isTrue);
    });

    test('列表同时读取内置和自定义状态，包括已停用配置', () async {
      await repository.save(_settings());
      await repository.save(
        _settings(source: 'custom_local').copyWith(isEnabled: false),
      );
      final providers = await repository.watchProviders().first;
      expect(
        providers.singleWhere((row) => row.source == 'openai').isEnabled,
        isTrue,
      );
      expect(
        providers.singleWhere((row) => row.source == 'custom_local').isEnabled,
        isFalse,
      );
    });
  });
}
