import 'dart:async';

import 'package:drift/drift.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_model_defaults.dart';
import 'package:kostori/foundation/ai_service/ai_provider_settings.dart';
import 'package:kostori/foundation/ai_service/balance_helper.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

class AiProviderSettingsRepository {
  AiProviderSettingsRepository({AiDatabase? database, Dio? dio})
    : database = database ?? AiDatabase.instance,
      _dio = dio ?? AppDio();

  final AiDatabase database;
  final Dio _dio;

  Stream<List<AiProviderSettings>> watchProviders() => Stream.multi((sink) {
    List<AiApiKey>? keys;
    List<AiCustomProvider>? customs;
    void emit() {
      if (keys == null || customs == null) return;
      final bySource = {for (final key in keys!) key.provider: key};
      sink.add([
        for (final entry in OpenAiProviderRegistry.builtinProviders.entries)
          builtinSettings(entry.key, bySource[entry.key]),
        for (final row in customs!) customSettings(row),
      ]);
    }

    final keySubscription = database.aiApiKeyDao.watchAll().listen((rows) {
      keys = rows;
      emit();
    }, onError: sink.addError);
    final customSubscription = database.aiCustomProviderDao.watchAll().listen((
      rows,
    ) {
      customs = rows;
      emit();
    }, onError: sink.addError);
    sink.onCancel = () async {
      await Future.wait([
        keySubscription.cancel(),
        customSubscription.cancel(),
      ]);
    };
  });

  AiProviderSettings builtinSettings(String source, AiApiKey? row) {
    final meta = OpenAiProviderRegistry.builtinProviders[source]!;
    final fixed = source == 'gemini' || source == 'openrouter';
    final balance = balanceDefaultConfig(source);
    return AiProviderSettings(
      source: source,
      name: meta.name,
      baseUrl: row?.baseUrl ?? meta.baseUrl,
      apiKey: row?.apiKey ?? '',
      model: row?.model ?? meta.defaultModel,
      apiFormat: fixed ? meta.apiFormat : (row?.apiFormat ?? meta.apiFormat),
      modelsUrl: row?.modelsUrl ?? '',
      balanceUrl: row?.balanceUrl ?? balance?.path ?? '',
      balanceKey: row?.balanceKey ?? balance?.key ?? '',
      isEnabled: row?.isEnabled ?? true,
      fixedApiFormat: fixed,
    );
  }

  AiProviderSettings customSettings(AiCustomProvider row) => AiProviderSettings(
    source: OpenAiProviderRegistry.customSourceKey(row.provider),
    name: row.name,
    baseUrl: row.baseUrl,
    apiKey: row.apiKey ?? '',
    model: row.defaultModel ?? '',
    apiFormat: row.apiFormat ?? 'openai',
    modelsUrl: row.modelsUrl ?? '',
    balanceUrl: row.balanceUrl ?? '',
    balanceKey: row.balanceKey ?? '',
    isEnabled: row.isEnabled,
  );

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> save(AiProviderSettings settings) async {
    await database.transaction(() async {
      final base = AiProviderApi.baseUrl(settings.baseUrl);
      if (settings.isCustom) {
        await database.aiCustomProviderDao.upsert(
          AiCustomProvidersCompanion.insert(
            provider: settings.provider,
            name: settings.name.trim(),
            baseUrl: base,
            // 用空串覆盖，保证清空 Key 也能真正保存。
            apiKey: Value(settings.apiKey.trim()),
            defaultModel: Value(_nullable(settings.model)),
            apiFormat: Value(settings.apiFormat),
            modelsUrl: Value(_nullable(settings.modelsUrl)),
            balanceUrl: Value(_nullable(settings.balanceUrl)),
            balanceKey: Value(_nullable(settings.balanceKey)),
            isEnabled: Value(settings.isEnabled),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await database.aiApiKeyDao.upsert(
          AiApiKeysCompanion.insert(
            provider: settings.source,
            apiKey: settings.apiKey.trim(),
            model: Value(_nullable(settings.model)),
            baseUrl: Value(base),
            apiFormat: Value(settings.apiFormat),
            modelsUrl: Value(_nullable(settings.modelsUrl)),
            balanceUrl: Value(_nullable(settings.balanceUrl)),
            balanceKey: Value(_nullable(settings.balanceKey)),
            isEnabled: Value(settings.isEnabled),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await ensureModel(
        settings.source,
        settings.model.trim(),
        settings.apiFormat,
      );
    });
    await _refresh();
  }

  Future<void> delete(AiProviderSettings settings) async {
    await database.transaction(() async {
      if (settings.isCustom) {
        await database.aiCustomProviderDao.deleteByProvider(settings.provider);
        await discardModels(settings.source);
      } else {
        await database.aiApiKeyDao.deleteByProvider(settings.source);
      }
    });
    await _refresh();
  }

  Future<void> _refresh() async {
    await OpenAiProviderRegistry.refreshKeyFormats(database: database);
    await OpenAiProviderRegistry.refreshCustomProviders(database: database);
  }

  Future<List<AiModel>> models(String source) =>
      database.aiModelDao.getModelsByProvider(source);

  Future<void> updateModel(String source, String model) async {
    if (OpenAiProviderRegistry.isCustomSource(source)) {
      await database.aiCustomProviderDao.updateModel(
        OpenAiProviderRegistry.customProviderOf(source),
        model,
      );
      await OpenAiProviderRegistry.refreshCustomProviders(database: database);
    } else {
      await database.aiApiKeyDao.updateModel(source, model);
    }
  }

  Future<void> ensureModel(String source, String id, String format) async {
    if (id.isEmpty || await database.aiModelDao.getModel(source, id) != null) {
      return;
    }
    final inferred = inferAiModelSettings(id, format);
    await database.aiModelDao.upsertModels([
      AiModelsCompanion.insert(
        provider: source,
        modelId: id,
        label: id,
        modelType: Value(inferred.type),
        inputModality: Value(inferred.input),
        outputModality: Value(inferred.output),
        supportsVision: Value(inferred.vision),
        supportsTools: Value(inferred.tools),
        supportsReasoning: Value(inferred.reasoning),
      ),
    ]);
  }

  Future<void> importModels(
    AiProviderSettings settings,
    List<String> ids,
  ) async {
    await database.transaction(() async {
      for (final id in ids) {
        await ensureModel(settings.source, id, settings.apiFormat);
      }
    });
  }

  Future<void> deleteModel(AiModel model) =>
      database.aiModelDao.deleteModel(model.provider, model.modelId);

  Future<void> discardModels(String source) async {
    await (database.delete(
      database.aiModels,
    )..where((row) => row.provider.equals(source))).go();
  }

  Future<Response<dynamic>> _getModels(AiProviderSettings settings) =>
      _dio.get<dynamic>(
        AiProviderApi.modelsEndpoint(settings),
        options: Options(
          headers: AiProviderApi.headers(
            settings.apiFormat,
            settings.apiKey.trim(),
          ),
          receiveTimeout: const Duration(seconds: 25),
          extra: const {'noLog': true},
        ),
      );

  Future<void> testConnection(AiProviderSettings settings) async {
    await _getModels(settings);
  }

  Future<List<String>> fetchModels(AiProviderSettings settings) async {
    final response = await _getModels(settings);
    final json = response.data;
    if (json is! Map) return [];
    final rows = json['data'] ?? json['models'];
    if (rows is! List) return [];
    final ids = <String>{};
    for (final row in rows.whereType<Map>()) {
      var id = row['id']?.toString().trim() ?? '';
      if (id.isEmpty) {
        id = (row['name'] ?? '')
            .toString()
            .replaceFirst(RegExp(r'^models/'), '')
            .trim();
      }
      if (settings.apiFormat == 'gemini') {
        id = id.replaceFirst(RegExp(r'^models/'), '');
      }
      if (id.isNotEmpty) ids.add(id);
    }
    return ids.toList();
  }

  Future<Res<String>> queryBalance(AiProviderSettings settings) =>
      queryBalanceByUrl(
        baseUrl: AiProviderApi.baseUrl(settings.baseUrl),
        apiKey: settings.apiKey.trim(),
        balanceUrl: settings.balanceUrl.trim(),
        balanceKey: settings.balanceKey.trim(),
      );
}
