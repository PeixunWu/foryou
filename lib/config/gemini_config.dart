import 'ai_config.dart';

/// Back-compat alias for primary Gemini key.
class GeminiConfig {
  static String get apiKey => AiConfig.geminiApiKey;
}
