import 'chat_message.dart';

/// Represents a complete learning session
class SessionModel {
  final String id;
  final String topic;
  final DateTime startTime;
  final DateTime? endTime;
  final List<ChatMessage> transcript;
  final String userId;
  final String personalityUsed;

  SessionModel({
    required this.id,
    required this.topic,
    required this.startTime,
    this.endTime,
    required this.transcript,
    required this.userId,
    required this.personalityUsed,
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  int get messageCount => transcript.length;

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

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? '',
      topic: json['topic'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      transcript: (json['transcript'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
      userId: json['userId'] ?? '',
      personalityUsed: json['personalityUsed'] ?? '',
    );
  }

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
}
