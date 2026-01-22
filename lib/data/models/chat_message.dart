/// Represents a single chat message in the conversation
class ChatMessage {
  /// Unique identifier for the message
  final String id;
  
  /// The text content of the message
  final String content;
  
  /// Whether this message is from the user (true) or AI (false)
  final bool isUser;
  
  /// When the message was created
  final DateTime timestamp;
  
  /// Which AI personality was active (only for AI messages)
  final String? personality;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.personality,
  });

  // ==========================================
  // FACTORY CONSTRUCTORS
  // ==========================================

  /// Creates a user message
  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      personality: null,
    );
  }

  /// Creates an AI message with specified personality
  factory ChatMessage.ai(String content, String personality) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      personality: personality,
    );
  }

  // ==========================================
  // SERIALIZATION
  // ==========================================

  /// Converts message to JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'personality': personality,
    };
  }

  /// Creates message from JSON format
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      personality: json['personality'] as String?,
    );
  }

  // ==========================================
  // UTILITY METHODS
  // ==========================================

  /// Returns formatted timestamp (e.g., "2:30 PM")
  String get formattedTime {
    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Returns a copy of this message with updated fields
  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    String? personality,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      personality: personality ?? this.personality,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, isUser: $isUser, content: ${content.substring(0, content.length > 50 ? 50 : content.length)}...)';
  }
}