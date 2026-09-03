/// Sarvam AI API configuration constants.
///
/// API reference:
/// - Chat completions: POST /v1/chat/completions (sarvam-105b)
/// - Open-source chat (vision): POST /v2/chat/completions (gemma4)
/// - Document AI: POST /doc-ai/v1/digitise (sarvam-vision)

class ApiConfig {
  ApiConfig._();

  /// Base URL for all Sarvam AI endpoints.
  static const String baseUrl = 'https://api.sarvam.ai';

  /// Chat completions endpoint (Sarvam-105B — text chat).
  static const String chatEndpoint = '/v1/chat/completions';

  /// Open-source chat endpoint (Gemma 4 31B — supports image input).
  static const String visionChatEndpoint = '/v2/chat/completions';

  /// Document AI digitise endpoint (Sarvam Vision — PDF/image OCR).
  static const String docAiEndpoint = '/doc-ai/v1/digitise';

  /// Default chat model.
  static const String defaultChatModel = 'sarvam-105b';

  /// Vision-capable model (image input).
  static const String defaultVisionModel = 'gemma4';

  /// Default document AI language code.
  static const String defaultDocLanguage = 'en-IN';

  /// Available chat models for the settings picker.
  static const List<String> chatModels = [
    'sarvam-105b',
    'sarvam-105b-conversations',
    'gemma4',
    'glm5.2',
    'deepseek-v4-flash',
  ];

  /// Indian language codes supported by Sarvam (for the language picker).
  static const Map<String, String> languages = {
    'English': 'en-IN',
    'Hindi': 'hi-IN',
    'Bengali': 'bn-IN',
    'Tamil': 'ta-IN',
    'Telugu': 'te-IN',
    'Marathi': 'mr-IN',
    'Gujarati': 'gu-IN',
    'Kannada': 'kn-IN',
    'Malayalam': 'ml-IN',
    'Punjabi': 'pa-IN',
    'Odia': 'or-IN',
    'Assamese': 'as-IN',
    'Urdu': 'ur-IN',
  };

  /// Request timeout.
  static const int requestTimeoutSeconds = 120;
}
