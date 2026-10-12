import 'package:kostori/database/ai_database.dart';

/// 统一读取服务商凭据；自定义服务商的数据存储在自定义服务商表中。
Future<AiApiKey?> loadAiProviderKey(
  String source, {
  AiDatabase? database,
}) async {
  final db = database ?? AiDatabase.instance;
  if (!source.startsWith('custom_')) {
    return db.aiApiKeyDao.getByProvider(source);
  }
  final row = await db.aiCustomProviderDao.getByProvider(source.substring(7));
  return row == null ? null : _customKey(source, row);
}

Stream<AiApiKey?> watchAiProviderKey(String source, {AiDatabase? database}) {
  final db = database ?? AiDatabase.instance;
  if (!source.startsWith('custom_')) {
    return db.aiApiKeyDao.watchByProvider(source);
  }
  return db.aiCustomProviderDao
      .watchByProvider(source.substring(7))
      .map((row) => row == null ? null : _customKey(source, row));
}

AiApiKey _customKey(String source, AiCustomProvider row) {
  return AiApiKey(
    provider: source,
    apiKey: row.apiKey ?? '',
    model: row.defaultModel,
    baseUrl: row.baseUrl,
    apiFormat: row.apiFormat ?? 'openai',
    modelsUrl: row.modelsUrl,
    balanceUrl: row.balanceUrl,
    balanceKey: row.balanceKey,
    isEnabled: row.isEnabled,
    updatedAt: row.updatedAt,
  );
}
