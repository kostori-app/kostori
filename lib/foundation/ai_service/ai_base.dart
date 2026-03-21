import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/res.dart';

abstract class AiMessage {
  final String role;
  final String content;

  const AiMessage({required this.role, required this.content});

  Map<String, dynamic> toJson();
}

class AiUserMessage extends AiMessage {
  const AiUserMessage({required super.content}) : super(role: 'user');

  @override
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiSystemMessage extends AiMessage {
  const AiSystemMessage({required super.content}) : super(role: 'system');

  @override
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiAssistantMessage extends AiMessage {
  const AiAssistantMessage({required super.content}) : super(role: 'assistant');

  @override
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

abstract class AiBase {
  String get sourceName;

  String get providerKey;

  Future<Res<String>> chat(List<AiMessage> messages, {String? systemPrompt});

  Future<Res<String>> generate(String prompt, {String? systemPrompt}) =>
      chat([AiUserMessage(content: prompt)], systemPrompt: systemPrompt);

  Map<String, dynamic> buildRequest(
    List<AiMessage> messages, {
    required AiProviderConfig config,
    String? systemPrompt,
  });

  String parseContent(dynamic responseData);

  Map<String, String> buildHeaders(AiProviderConfig config);

  String buildUrl(AiProviderConfig config);

  AiProviderConfig buildConfig(AiApiKey row);

  Future<AiApiKey?> getKeyRow() =>
      AiDatabase.instance.aiApiKeyDao.getByProvider(providerKey);
}
