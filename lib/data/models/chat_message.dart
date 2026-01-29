// lib/data/models/chat_message.dart

/// Represents a single chat message in the conversation
class ChatMessage {
  final String id;
  final String content;
  final bool isUser; // true = user, false = AI
  final DateTime timestamp;
  final String? personality; // Which AI personality (if AI message)
  final bool isError; // Is this an error message?

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.personality,
    this.isError = false,
  });

  /// Create a user message
  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  /// Create an AI message
  factory ChatMessage.ai(String content, String personality) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      personality: personality,
    );
  }

  /// Create an error message
  factory ChatMessage.error(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      isError: true,
    );
  }

  /// Create a copy with modifications
  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    String? personality,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      personality: personality ?? this.personality,
      isError: isError ?? this.isError,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'personality': personality,
      'isError': isError,
    };
  }

  /// Create from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      personality: json['personality'] as String?,
      isError: json['isError'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    final speaker = isUser ? 'User' : (personality ?? 'AI');
    return '[$speaker]: $content';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}