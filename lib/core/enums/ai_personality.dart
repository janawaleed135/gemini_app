/// Defines the different AI personality types available
enum AIPersonality {
  /// Professional teacher mode - patient, encouraging, educational
  tutor,
  
  /// Friendly study buddy mode - casual, relatable, collaborative
  classmate,
}

/// Extension methods for AIPersonality enum
extension AIPersonalityExtension on AIPersonality {
  /// Returns display name for the personality
  String get displayName {
    switch (this) {
      case AIPersonality.tutor:
        return 'Tutor';
      case AIPersonality.classmate:
        return 'Classmate';
    }
  }
  
  /// Returns emoji icon for the personality
  String get icon {
    switch (this) {
      case AIPersonality.tutor:
        return '👨‍🏫';
      case AIPersonality.classmate:
        return '👥';
    }
  }
  
  /// Returns short description of the personality
  String get description {
    switch (this) {
      case AIPersonality.tutor:
        return 'Your patient AI teacher who guides you through learning with encouragement and expertise.';
      case AIPersonality.classmate:
        return 'Your friendly study buddy who learns alongside you in a casual, relatable way.';
    }
  }
  
  /// Returns welcome message for the personality
  String get welcomeMessage {
    switch (this) {
      case AIPersonality.tutor:
        return 'Hello! I\'m your AI Tutor. I\'m here to help you learn and grow. What would you like to explore today? 😊';
      case AIPersonality.classmate:
        return 'Hey! I\'m your study buddy! Let\'s learn together. What are we tackling today? 😄';
    }
  }
}