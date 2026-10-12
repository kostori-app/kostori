/// 根据模型 ID 和接口格式推断模型类型、输入输出模态及能力。
({
  String type,
  String input,
  String output,
  bool vision,
  bool tools,
  bool reasoning,
})
inferAiModelSettings(String id, String apiFormat) {
  final lower = id.toLowerCase();
  if (lower.contains('embedding')) {
    return (
      type: 'embedding',
      input: 'text',
      output: 'text',
      vision: false,
      tools: false,
      reasoning: false,
    );
  }
  if (lower.contains('whisper') ||
      lower.contains('audio') ||
      lower.contains('tts') ||
      lower.contains('speech')) {
    return (
      type: 'audio',
      input: 'audio',
      output: 'text',
      vision: false,
      tools: false,
      reasoning: false,
    );
  }
  if (lower.contains('dall') ||
      lower.contains('image') ||
      lower.contains('imagen') ||
      lower.contains('midjourney') ||
      lower.contains('flux') ||
      lower.contains('sora') ||
      lower.contains('video') ||
      lower.contains('generate')) {
    return (
      type: 'image',
      input: 'text',
      output: 'image',
      vision: false,
      tools: false,
      reasoning: false,
    );
  }
  return (
    type: 'chat',
    input: 'text,image',
    output: 'text',
    vision: true,
    tools: true,
    reasoning:
        apiFormat == 'gemini' || RegExp(r'^(o[1-9]|gpt-[56])').hasMatch(lower),
  );
}
