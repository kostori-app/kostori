class DbChatModel {
  final String id;
  final String object;
  final int created;
  final String model;
  final String serviceTier;
  final List<DbChatChoice> choices;
  final DbUsage usage;

  DbChatModel({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.serviceTier,
    required this.choices,
    required this.usage,
  });

  factory DbChatModel.fromJson(Map<String, dynamic> json) {
    return DbChatModel(
      id: json['id'],
      object: json['object'],
      created: json['created'],
      model: json['model'],
      serviceTier: json['service_tier'],
      choices: (json['choices'] as List)
          .map((e) => DbChatChoice.fromJson(e))
          .toList(),
      usage: DbUsage.fromJson(json['usage']),
    );
  }
}

class DbChatChoice {
  final int index;
  final String finishReason;
  final DbChatMessage message;

  DbChatChoice({
    required this.index,
    required this.finishReason,
    required this.message,
  });

  factory DbChatChoice.fromJson(Map<String, dynamic> json) {
    return DbChatChoice(
      index: json['index'],
      finishReason: json['finish_reason'],
      message: DbChatMessage.fromJson(json['message']),
    );
  }
}

class DbChatMessage {
  final String role;
  final String content;

  DbChatMessage({required this.role, required this.content});

  factory DbChatMessage.fromJson(Map<String, dynamic> json) {
    return DbChatMessage(role: json['role'], content: json['content']);
  }
}

class DbUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  DbUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory DbUsage.fromJson(Map<String, dynamic> json) {
    return DbUsage(
      promptTokens: json['prompt_tokens'],
      completionTokens: json['completion_tokens'],
      totalTokens: json['total_tokens'],
    );
  }
}

extension DbChatCompletionExt on DbChatModel {
  String get content => choices.first.message.content;
}
