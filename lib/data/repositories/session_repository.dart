// lib/data/repositories/session_repository.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';
import '../../core/constants/app_constants.dart';

/// Repository for managing session persistence
class SessionRepository {
  final SharedPreferences _prefs;

  SessionRepository(this._prefs);

  /// Save a session
  Future<void> saveSession(SessionModel session) async {
    final sessions = await getAllSessions();
    
    // Remove existing session with same ID if exists
    sessions.removeWhere((s) => s.id == session.id);
    
    // Add new session
    sessions.add(session);
    
    // Sort by date (newest first)
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    
    // Limit to max history
    if (sessions.length > AppConstants.maxConversationHistory) {
      sessions.removeRange(AppConstants.maxConversationHistory, sessions.length);
    }
    
    // Save to preferences
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await _prefs.setString(AppConstants.sessionsKey, jsonEncode(jsonList));
  }

  /// Get all sessions
  Future<List<SessionModel>> getAllSessions() async {
    final jsonString = _prefs.getString(AppConstants.sessionsKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => SessionModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading sessions: $e');
      return [];
    }
  }

  /// Get a specific session by ID
  Future<SessionModel?> getSession(String id) async {
    final sessions = await getAllSessions();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete a session
  Future<void> deleteSession(String id) async {
    final sessions = await getAllSessions();
    sessions.removeWhere((s) => s.id == id);
    
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await _prefs.setString(AppConstants.sessionsKey, jsonEncode(jsonList));
  }

  /// Clear all sessions
  Future<void> clearAllSessions() async {
    await _prefs.remove(AppConstants.sessionsKey);
  }

  /// Get sessions by personality
  Future<List<SessionModel>> getSessionsByPersonality(String personality) async {
    final sessions = await getAllSessions();
    return sessions.where((s) => s.personalityUsed == personality).toList();
  }

  /// Get recent sessions (last N)
  Future<List<SessionModel>> getRecentSessions(int count) async {
    final sessions = await getAllSessions();
    return sessions.take(count).toList();
  }
}