/// Defines the AI personality modes available in the app
enum AIPersonality {
  /// Professional teacher mode - patient, pedagogical, structured
  tutor,
  
  /// Friendly peer mode - casual, collaborative, encouraging
  classmate,
}

extension AIPersonalityExtension on AIPersonality {
  /// Get user-friendly name
  String get displayName {
    switch (this) {
      case AIPersonality.tutor:
        return 'Tutor';
      case AIPersonality.classmate:
        return 'Classmate';
    }
  }
  
  /// Get emoji icon
  String get icon {
    switch (this) {
      case AIPersonality.tutor:
        return '👨‍🏫';
      case AIPersonality.classmate:
        return '👥';
    }
  }
  
  /// Get description
  String get description {
    switch (this) {
      case AIPersonality.tutor:
        return 'Professional guidance and structured learning';
      case AIPersonality.classmate:
        return 'Casual conversation and peer collaboration';
    }
  }
}