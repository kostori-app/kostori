class GmGenerateContentModel {
  final List<GmCandidate> candidates;
  final GmUsageMetadata usageMetadata;
  final String modelVersion;
  final String responseId;

  GmGenerateContentModel({
    required this.candidates,
    required this.usageMetadata,
    required this.modelVersion,
    required this.responseId,
  });

  factory GmGenerateContentModel.fromJson(Map<String, dynamic> json) {
    return GmGenerateContentModel(
      candidates: (json['candidates'] as List)
          .map((e) => GmCandidate.fromJson(e))
          .toList(),
      usageMetadata: GmUsageMetadata.fromJson(json['usageMetadata']),
      modelVersion: json['modelVersion'],
      responseId: json['responseId'],
    );
  }
}

class GmCandidate {
  final int index;
  final String finishReason;
  final GmContent content;

  GmCandidate({
    required this.index,
    required this.finishReason,
    required this.content,
  });

  factory GmCandidate.fromJson(Map<String, dynamic> json) {
    return GmCandidate(
      index: json['index'],
      finishReason: json['finishReason'],
      content: GmContent.fromJson(json['content']),
    );
  }
}

class GmContent {
  final String role;
  final List<GmPart> parts;

  GmContent({required this.role, required this.parts});

  factory GmContent.fromJson(Map<String, dynamic> json) {
    return GmContent(
      role: json['role'],
      parts: (json['parts'] as List).map((e) => GmPart.fromJson(e)).toList(),
    );
  }
}

class GmPart {
  final String text;

  GmPart({required this.text});

  factory GmPart.fromJson(Map<String, dynamic> json) {
    return GmPart(text: json['text']);
  }
}

class GmUsageMetadata {
  final int promptTokenCount;
  final int candidatesTokenCount;
  final int totalTokenCount;

  GmUsageMetadata({
    required this.promptTokenCount,
    required this.candidatesTokenCount,
    required this.totalTokenCount,
  });

  factory GmUsageMetadata.fromJson(Map<String, dynamic> json) {
    return GmUsageMetadata(
      promptTokenCount: json['promptTokenCount'],
      candidatesTokenCount: json['candidatesTokenCount'],
      totalTokenCount: json['totalTokenCount'],
    );
  }
}

extension GmGenerateContentExt on GmGenerateContentModel {
  String get content => candidates.first.content.parts.first.text;
}
