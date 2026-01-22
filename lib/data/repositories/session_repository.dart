import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_model.dart';

/// Simple repository for persisting SessionModel using SharedPreferences
class SessionRepository {
  static const _kSessionsKey = 'saved_sessions';

  // ==========================================
  // SAVE SESSIONS
  // ==========================================

  Future<void> saveSession(SessionModel session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getAllSessions();

    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }

    final encoded = json.encode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_kSessionsKey, encoded);
  }

  // ==========================================
  // RETRIEVE SESSIONS
  // ==========================================

  Future<List<SessionModel>> getAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSessionsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => SessionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<SessionModel?> getSessionById(String sessionId) async {
    final sessions = await getAllSessions();
    for (final s in sessions) {
      if (s.id == sessionId) return s;
    }
    return null;
  }

  // ==========================================
  // DELETE SESSIONS
  // ==========================================

  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getAllSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    final encoded = json.encode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_kSessionsKey, encoded);
  }

}