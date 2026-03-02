class SfChatModel {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<SfChatChoice> choices;
  final SfUsage usage;
  final String? systemFingerprint;

  SfChatModel({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
    this.systemFingerprint,
  });

  factory SfChatModel.fromJson(Map<String, dynamic> json) {
    return SfChatModel(
      id: json['id'],
      object: json['object'],
      created: json['created'],
      model: json['model'],
      choices: (json['choices'] as List)
          .map((e) => SfChatChoice.fromJson(e))
          .toList(),
      usage: SfUsage.fromJson(json['usage']),
      systemFingerprint: json['system_fingerprint'],
    );
  }
}

class SfChatChoice {
  final int index;
  final SfChatMessage message;
  final String finishReason;

  SfChatChoice({
    required this.index,
    required this.message,
    required this.finishReason,
  });

  factory SfChatChoice.fromJson(Map<String, dynamic> json) {
    return SfChatChoice(
      index: json['index'],
      message: SfChatMessage.fromJson(json['message']),
      finishReason: json['finish_reason'],
    );
  }
}

class SfChatMessage {
  final String role;
  final String content;

  SfChatMessage({required this.role, required this.content});

  factory SfChatMessage.fromJson(Map<String, dynamic> json) {
    return SfChatMessage(role: json['role'], content: json['content']);
  }
}

class SfUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  SfUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory SfUsage.fromJson(Map<String, dynamic> json) {
    return SfUsage(
      promptTokens: json['prompt_tokens'],
      completionTokens: json['completion_tokens'],
      totalTokens: json['total_tokens'],
    );
  }
}

extension SfChatCompletionExt on SfChatModel {
  String get content => choices.first.message.content;
}
