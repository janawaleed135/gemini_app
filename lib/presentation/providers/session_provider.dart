// lib/presentation/providers/session_provider.dart

import 'package:flutter/foundation.dart';
import 'dart:convert'; // ADDED: Required for jsonEncode/jsonDecode
import '../../core/services/ai_service.dart';
import '../../data/models/session_model.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/conversation_state_service.dart';
// FIXED: Import AIPersonality so displayName is found
import '../../core/enums/ai_personality.dart'; 

class SessionProvider extends ChangeNotifier {
  final SessionRepository _repository;
  final AIService _aiService;
  final SharedPreferences _prefs; // ADDED: Stored as a field to be accessible in methods
  late ConversationStateService _stateService;

  SessionModel? _currentSession;
  List<SessionModel> _savedSessions = [];
  bool _isLoading = false;

  SessionProvider({
    required SessionRepository repository,
    required AIService aiService,
    required SharedPreferences prefs,
  })  : _repository = repository,
        _aiService = aiService,
        _prefs = prefs { // INITIALIZED: Setting the local _prefs field
    _stateService = ConversationStateService(prefs); 
    // FIXED: setStateService method now exists in AIService
    _aiService.setStateService(_stateService); 
    _loadSessions();
  }

  SessionModel? get currentSession => _currentSession;
  List<SessionModel> get savedSessions => List.unmodifiable(_savedSessions);
  bool get isLoading => _isLoading;
  bool get hasActiveSession => _currentSession != null;

  // MERGED: Combined both definitions into one cohesive logic
  Future<void> _loadSessions() async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Load from the Repository (Database/Primary storage)
      _savedSessions = await _repository.getAllSessions();
      
      // 2. Fallback/Sync from custom 'saved_sessions' key if present
      final data = _prefs.getString('saved_sessions');
      if (data != null && _savedSessions.isEmpty) {
        final List decoded = jsonDecode(data);
        _savedSessions = decoded.map((s) => SessionModel.fromJson(s)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('Error loading sessions: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  void startNewSession(String topic, String userId) {
    _currentSession = SessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      topic: topic,
      startTime: DateTime.now(),
      transcript: [],
      userId: userId,
      // FIXED: displayName comes from AIPersonality extension
      personalityUsed: _aiService.currentPersonality.displayName,
    );
    notifyListeners();
  }

  void updateSessionTranscript(List<ChatMessage> messages) {
    if (_currentSession == null) return;
    _currentSession = _currentSession!.copyWith(transcript: messages);
    notifyListeners();
  }

  Future<void> endSession() async {
    if (_currentSession == null) return;
    _currentSession = _currentSession!.copyWith(endTime: DateTime.now());
    try {
      await _repository.saveSession(_currentSession!);
      await _loadSessions();
      _currentSession = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      await _repository.deleteSession(id);
      await _loadSessions();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearAllSessions() async {
    try {
      await _repository.clearAllSessions();
      await _loadSessions();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    await _loadSessions();
  }

  Map<String, dynamic> getSessionStatistics() {
    final totalSessions = _savedSessions.length;
    final tutorSessions = _savedSessions.where((s) => s.personalityUsed == 'Tutor').length;
    final classmateSessions = _savedSessions.where((s) => s.personalityUsed == 'Classmate').length;
    final totalMessages = _savedSessions.fold<int>(0, (sum, session) => sum + session.messageCount);

    return {
      'total_sessions': totalSessions,
      'tutor_sessions': tutorSessions,
      'classmate_sessions': classmateSessions,
      'total_messages': totalMessages,
      'has_active_session': hasActiveSession,
    };
  }

  // FIXED: resumeConversation now exists in AIService
  Future<bool> checkAndResumeConversation() async {
    if (_stateService.hasSavedState()) {
      final lastSave = _stateService.getLastSaveTime();
      if (lastSave != null) {
        final hoursSinceLastSave = DateTime.now().difference(lastSave).inHours;
        if (hoursSinceLastSave < 24) {
          return await _aiService.resumeConversation();
        }
      }
    }
    return false;
  }

  Future<void> saveCurrentSessionToHistory() async {
    if (_currentSession == null) return;
    
    // Add to local list
    _savedSessions.insert(0, _currentSession!);
    
    // Persist to SharedPreferences using the local _prefs field
    final jsonList = _savedSessions.map((s) => s.toJson()).toList();
    await _prefs.setString('saved_sessions', jsonEncode(jsonList));
    
    notifyListeners();
  }

  Future<void> clearSavedState() async {
    await _stateService.clearState();
  }
}