// lib/presentation/providers/session_provider.dart

import 'package:flutter/foundation.dart';
import '../../core/services/ai_service.dart';
import '../../core/enums/ai_personality.dart';
import '../../data/models/session_model.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/session_repository.dart';

/// Provider that manages the current session and history
class SessionProvider extends ChangeNotifier {
  final SessionRepository _repository;
  final AIService _aiService;

  SessionModel? _currentSession;
  List<SessionModel> _savedSessions = [];
  bool _isLoading = false;

  SessionProvider({
    required SessionRepository repository,
    required AIService aiService,
  })  : _repository = repository,
        _aiService = aiService {
    _loadSessions();
  }

  // ========== Getters ==========
  SessionModel? get currentSession => _currentSession;
  List<SessionModel> get savedSessions => List.unmodifiable(_savedSessions);
  bool get isLoading => _isLoading;
  bool get hasActiveSession => _currentSession != null;

  // ========== Load Saved Sessions ==========
  Future<void> _loadSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _savedSessions = await _repository.getAllSessions();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading sessions: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // ========== Start New Session ==========
  void startNewSession(String topic, String userId) {
    _currentSession = SessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      topic: topic,
      startTime: DateTime.now(),
      transcript: [],
      userId: userId,
      personalityUsed: _aiService.currentPersonality.displayName,
    );

    if (kDebugMode) {
      print('📝 New session started: ${_currentSession!.topic}');
    }

    notifyListeners();
  }

  // ========== Update Session ==========
  void updateSessionTranscript(List<ChatMessage> messages) {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      transcript: messages,
    );

    notifyListeners();
  }

  // ========== End Session ==========
  Future<void> endSession() async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      endTime: DateTime.now(),
    );

    try {
      await _repository.saveSession(_currentSession!);
      await _loadSessions();
      
      if (kDebugMode) {
        print('💾 Session saved: ${_currentSession!.topic}');
      }
      
      _currentSession = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving session: $e');
      }
      rethrow;
    }
  }

  // ========== Delete Session ==========
  Future<void> deleteSession(String id) async {
    try {
      await _repository.deleteSession(id);
      await _loadSessions();
      
      if (kDebugMode) {
        print('🗑️ Session deleted: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting session: $e');
      }
      rethrow;
    }
  }

  // ========== Clear All Sessions ==========
  Future<void> clearAllSessions() async {
    try {
      await _repository.clearAllSessions();
      await _loadSessions();
      
      if (kDebugMode) {
        print('🗑️ All sessions cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing sessions: $e');
      }
      rethrow;
    }
  }

  // ========== Get Transcript ==========
  String getCurrentTranscript() {
    if (_currentSession == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('Topic: ${_currentSession!.topic}');
    buffer.writeln('Started: ${_formatDateTime(_currentSession!.startTime)}');
    buffer.writeln('Personality: ${_currentSession!.personalityUsed}');
    buffer.writeln(''.padLeft(50, '='));
    buffer.writeln();

    for (final message in _currentSession!.transcript) {
      if (message.isError) continue;
      
      final speaker = message.isUser ? 'Student' : message.personality ?? 'AI';
      final time = _formatTime(message.timestamp);

      buffer.writeln('[$time] $speaker:');
      buffer.writeln(message.content);
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime time) {
    return '${time.day}/${time.month}/${time.year} ${_formatTime(time)}';
  }

  // ========== Refresh ==========
  Future<void> refresh() async {
    await _loadSessions();
  }

  // ========== Get Session Statistics ==========
  Map<String, dynamic> getSessionStatistics() {
    final totalSessions = _savedSessions.length;
    final tutorSessions = _savedSessions.where((s) => s.personalityUsed == 'Tutor').length;
    final classmateSessions = _savedSessions.where((s) => s.personalityUsed == 'Classmate').length;
    
    final totalMessages = _savedSessions.fold<int>(
      0, 
      (sum, session) => sum + session.messageCount,
    );

    return {
      'total_sessions': totalSessions,
      'tutor_sessions': tutorSessions,
      'classmate_sessions': classmateSessions,
      'total_messages': totalMessages,
      'has_active_session': hasActiveSession,
    };
  }
}