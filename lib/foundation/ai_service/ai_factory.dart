import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/ai_configs.dart';
import 'package:kostori/foundation/ai_service/gemini_ai.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';

class AiFactory {
  static AiBase? create(String source) =>
      OpenAiProviderRegistry.createAi(source);

  static AiBase? createFromConfig(AiProviderConfig config) {
    if (config is OpenAiCompatibleConfig) {
      return OpenAiProviderRegistry.createAi(config.source);
    }
    if (config is GeminiConfig) return GeminiAi();
    return null;
  }
}
