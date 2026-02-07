// lib/core/config/api_config.dart

import '../services/api_key_manager.dart';

class ApiConfig {
  ApiConfig._(); 

  // ========== API Keys ==========
  static String get geminiApiKey {
    // Simply ask the manager. It has either the Firebase keys (if loaded)
    // or the Local keys (as backup).
    return ApiKeyManager.instance.getCurrentKey();
  }

  // ========== Configuration ==========
  static const String geminiModel = 'gemini-2.5-flash-lite';
  static const double temperature = 0.7;
  static const int maxOutputTokens = 8192;
  static const int requestsPerMinute = 15; 
  static const Duration rateLimitWindow = Duration(minutes: 1);

  static void rotateApiKey() {
    ApiKeyManager.instance.rotateToNextKey();
  }

  static Map<String, dynamic> getUsageStats() {
    return ApiKeyManager.instance.getStats();
  }
}