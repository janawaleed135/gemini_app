// lib/core/services/conversation_state_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/chat_message.dart';

/// Service for saving and resuming conversation states
class ConversationStateService {
  final SharedPreferences _prefs;
  
  ConversationStateService(this._prefs);

  static const String _stateKey = 'ai_tutor_conversation_state';

  /// Save current conversation state
  Future<void> saveState({
    required List<ChatMessage> messages,
    required String personality,
    required List<String> topics,
    required int? currentSlideIndex,
  }) async {
    final state = {
      'messages': messages.map((m) => m.toJson()).toList(),
      'personality': personality,
      'topics': topics,
      'currentSlideIndex': currentSlideIndex,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await _prefs.setString(_stateKey, jsonEncode(state));
  }

  /// Load saved conversation state
  Future<Map<String, dynamic>?> loadState() async {
    final stateJson = _prefs.getString(_stateKey);
    if (stateJson == null) return null;
    
    try {
      return jsonDecode(stateJson) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Clear saved state
  Future<void> clearState() async {
    await _prefs.remove(_stateKey);
  }

  /// Check if there's a saved state
  bool hasSavedState() {
    return _prefs.containsKey(_stateKey);
  }

  /// Get time of last saved state
  DateTime? getLastSaveTime() {
    final stateJson = _prefs.getString(_stateKey);
    if (stateJson == null) return null;
    
    try {
      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      return DateTime.parse(state['timestamp'] as String);
    } catch (e) {
      return null;
    }
  }
}