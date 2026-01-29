// lib/core/config/api_config.dart

/// Central configuration for API keys and app settings
class ApiConfig {
  ApiConfig._(); // Private constructor to prevent instantiation

  // ========== API Keys ==========
  /// Gemini AI API Key
  static const String geminiApiKey = 'AIzaSyBF6f5CFVuAvviKurs9pDd-vdewQyEnZac';

  // ========== Model Configuration ==========
  /// Use gemini-pro - works 100% with any valid API key
  static const String geminiModel = 'gemini-2.5-flash';

  // ========== Generation Settings ==========
  static const double temperature = 0.9;
  static const int topK = 40;
  static const double topP = 0.95;
  static const int maxOutputTokens = 2048;

  // ========== App Settings ==========
  static const String appName = 'AI Tutor';
  static const String defaultUserId = 'student_001';

  // ========== Voice Settings ==========
  static const String ttsLanguage = 'en-US';
  static const double ttsSpeechRate = 0.5;
  static const double ttsVolume = 1.0;
  static const double ttsPitch = 1.0;

  // ========== Validation ==========
  static bool get isApiKeyConfigured {
    return geminiApiKey.isNotEmpty && 
           geminiApiKey.length > 20 &&
           geminiApiKey.startsWith('AIza');
  }

  static String get apiKeyErrorMessage => 
    '''
API key not configured properly!

Steps to fix:
1. Go to https://aistudio.google.com/app/apikey
2. Create a new API key
3. Copy the key
4. Open lib/core/config/api_config.dart
5. Replace the geminiApiKey value with your key
6. Restart the app
''';
}