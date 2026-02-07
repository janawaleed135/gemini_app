// lib/core/services/api_key_manager.dart

import 'package:flutter/foundation.dart';

class ApiKeyManager {
  static ApiKeyManager? _instance;
  static ApiKeyManager get instance => _instance ??= ApiKeyManager._();
  
  ApiKeyManager._();

  // 1. LOCAL BACKUP KEYS (Used if Firebase fails)
  // PASTE YOUR 5 REAL KEYS HERE AS BACKUP
  List<String> _apiKeys = [
    'AIzaSyCwa6owl__wKII8KhfRGrBKB0y8FFO5oQ0',
    'AIzaSyAQIWS2E0_mdHQ8L5U8MdnJbknBAhVuWWw',
    'AIzaSyCxVDHF7pxxSw15F40mHQ80_gpw2aVAv3M',
    'AIzaSyAuQC9IMUqVK2VtQ5ZuEqrmcXAMJYzfpyM',
    'AIzaSyAkp2AUIpEfo6zwvH33RiQjR7ojfkK7Q2s',
  ];

  int _currentKeyIndex = 0;
  final Map<String, int> _keyUsageCount = {};

  // 2. NEW METHOD: Update keys from Firebase
  void setKeys(List<String> newKeys) {
    if (newKeys.isNotEmpty) {
      _apiKeys = newKeys;
      _currentKeyIndex = 0; // Reset to start
      if (kDebugMode) print('✅ ApiKeyManager: Loaded ${newKeys.length} keys from Firebase');
    }
  }

  int get totalKeys => _apiKeys.length;

  String getCurrentKey() {
    if (_apiKeys.isEmpty) return '';
    return _apiKeys[_currentKeyIndex];
  }

  void rotateToNextKey() {
    if (_apiKeys.length <= 1) return;
    final oldIndex = _currentKeyIndex;
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
    if (kDebugMode) print('🔄 ApiKeyManager: Rotated Key #$oldIndex -> #$_currentKeyIndex');
  }

  void recordUsage(String key) {
    _keyUsageCount[key] = (_keyUsageCount[key] ?? 0) + 1;
  }
  
  Map<String, dynamic> getStats() => {
    'total_keys': _apiKeys.length,
    'current_index': _currentKeyIndex,
    'source': _apiKeys.first.startsWith('AIzaSy') ? 'Loaded' : 'Empty',
  };
}