// lib/core/config/api_config.dart

import '../services/firebase_service.dart';

/// Central configuration for API keys and app settings
class ApiConfig {
  ApiConfig._(); 

  // ========== API Keys ==========
  /// Get Gemini API Key from Firebase Remote Config
  static String get geminiApiKey {
    return FirebaseService.instance.apiKey;
  }

  // ========== Model Configuration ==========
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
    final key = geminiApiKey;
    return key.isNotEmpty && 
           key.length > 20 &&
           key.startsWith('AIza');
  }

  static String get apiKeyErrorMessage => 
    '''
API key not available!

The app is trying to load the API key from Firebase Remote Config.
Please check your internet connection and try again.

If the problem persists, contact support.
''';
}