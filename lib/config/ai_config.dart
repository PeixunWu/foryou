/// Compile-time AI provider keys (never hardcode secrets in source).
///
/// Pass at build/run time, e.g.:
/// ```bash
/// flutter run \
///   --dart-define=GEMINI_API_KEY=... \
///   --dart-define=GEMINI_OLD_KEY=... \
///   --dart-define=GROQ_API_KEY=... \
///   --dart-define=OPENROUTER_API_KEY=...
/// ```
class AiConfig {
  AiConfig._();

  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Used for Gemini 1.5 Flash fallback when Gemini 3 is rate-limited or fails.
  static const String geminiOldKey =
      String.fromEnvironment('GEMINI_OLD_KEY', defaultValue: '');

  static const String groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');

  /// OpenRouter attribution (required by their API).
  static const String openRouterReferer =
      String.fromEnvironment('OPENROUTER_HTTP_REFERER', defaultValue: 'https://foryou.app');

  static const String openRouterTitle =
      String.fromEnvironment('OPENROUTER_X_TITLE', defaultValue: 'Foru AI');

  static bool get hasPrimaryGemini => geminiApiKey.isNotEmpty;
  static bool get hasLegacyGemini => geminiOldKey.isNotEmpty;
  static bool get hasGroq => groqApiKey.isNotEmpty;
  static bool get hasOpenRouter => openRouterApiKey.isNotEmpty;
}
