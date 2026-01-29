// lib/data/models/session_model.dart

import 'chat_message.dart';

/// Represents a learning session
class SessionModel {
  final String id;
  final String topic;
  final DateTime startTime;
  final DateTime? endTime;
  final List<ChatMessage> transcript;
  final String userId;
  final String personalityUsed;
  final int messageCount;
  final Duration? duration;

  SessionModel({
    required this.id,
    required this.topic,
    required this.startTime,
    this.endTime,
    required this.transcript,
    required this.userId,
    required this.personalityUsed,
  })  : messageCount = transcript.length,
        duration = endTime != null ? endTime.difference(startTime) : null;

  /// Check if session is active
  bool get isActive => endTime == null;

  /// Get formatted duration
  String get formattedDuration {
    if (duration == null) return 'In progress...';
    
    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '$hours h $minutes min';
    }
    return '$minutes min';
  }

  /// Get formatted date
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(startTime.year, startTime.month, startTime.day);
    
    if (sessionDate == today) {
      return 'Today ${_formatTime(startTime)}';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${_formatTime(startTime)}';
    }
    return '${startTime.day}/${startTime.month}/${startTime.year} ${_formatTime(startTime)}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Create a copy with modifications
  SessionModel copyWith({
    String? id,
    String? topic,
    DateTime? startTime,
    DateTime? endTime,
    List<ChatMessage>? transcript,
    String? userId,
    String? personalityUsed,
  }) {
    return SessionModel(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      transcript: transcript ?? this.transcript,
      userId: userId ?? this.userId,
      personalityUsed: personalityUsed ?? this.personalityUsed,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'transcript': transcript.map((m) => m.toJson()).toList(),
      'userId': userId,
      'personalityUsed': personalityUsed,
    };
  }

  /// Create from JSON
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String,
      topic: json['topic'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      transcript: (json['transcript'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      userId: json['userId'] as String,
      personalityUsed: json['personalityUsed'] as String,
    );
  }
}