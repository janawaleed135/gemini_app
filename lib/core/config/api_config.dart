/// API Configuration for Gemini AI
/// Contains API keys and model settings
class ApiConfig {
  // ==========================================
  // API KEY - HARDCODED (DO NOT CHANGE)
  // ==========================================
  static const String apiKey = 'AIzaSyA_cEYmfI-53sCTIKp3yPQbqs7DCKRLtZE';
  
  // ==========================================
  // MODEL CONFIGURATION
  // ==========================================
  static const String modelName = 'gemini-1.5-flash';
  
  // ==========================================
  // GENERATION SETTINGS
  // ==========================================
  static const double temperature = 0.9; // Creative and natural (0.0 - 1.0)
  static const int topK = 40; // Diversity of token selection
  static const double topP = 0.95; // Nucleus sampling threshold
  static const int maxOutputTokens = 2048; // Maximum response length
  
  // ==========================================
  // VALIDATION
  // ==========================================
  
  /// Validates if API key is properly configured
  static bool isApiKeyValid() {
    return apiKey.isNotEmpty && apiKey.startsWith('AIza');
  }
  
  /// Gets validation error message if API key is invalid
  static String? getValidationError() {
    if (apiKey.isEmpty) {
      return 'API key is not configured. Please contact support.';
    }
    if (!apiKey.startsWith('AIza')) {
      return 'API key format is invalid. Please contact support.';
    }
    return null;
  }
  
  /// Returns configured API key
  static String getApiKey() {
    if (!isApiKeyValid()) {
      throw Exception(getValidationError());
    }
    return apiKey;
  }
}