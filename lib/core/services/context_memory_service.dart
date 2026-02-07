// lib/core/services/context_memory_service.dart

import 'package:flutter/foundation.dart';

/// Tracks learned concepts, student weaknesses, and suggests related topics
class ContextMemoryService {
  // Concepts explained in this session
  final Map<String, ConceptRecord> _explainedConcepts = {};
  
  // Topics the student struggled with
  final List<String> _weaknessAreas = [];
  
  // Related topics that could be explored
  final List<String> _suggestedTopics = [];

  /// Record that a concept was explained
  void recordExplanation(String concept, String explanation, {
    required bool studentUnderstood,
    int clarificationCount = 0,
  }) {
    _explainedConcepts[concept] = ConceptRecord(
      concept: concept,
      explanation: explanation,
      timestamp: DateTime.now(),
      understood: studentUnderstood,
      clarificationCount: clarificationCount,
    );
    
    // Track as weakness if multiple clarifications needed
    if (clarificationCount > 2 && !studentUnderstood) {
      if (!_weaknessAreas.contains(concept)) {
        _weaknessAreas.add(concept);
      }
    }
    
    if (kDebugMode) {
      print('📝 Recorded concept: $concept (understood: $studentUnderstood)');
    }
  }

  /// Analyze message for confusion indicators
  bool detectConfusion(String userMessage) {
    final confusionIndicators = [
      'i don\'t understand',
      'confused',
      'what does this mean',
      'can you explain',
      'i\'m lost',
      'help',
      'unclear',
      'don\'t get it',
      'what',
      'huh',
      '?',
    ];
    
    final lowerMessage = userMessage.toLowerCase();
    return confusionIndicators.any((indicator) => lowerMessage.contains(indicator));
  }

  /// Analyze message for understanding indicators
  bool detectUnderstanding(String userMessage) {
    final understandingIndicators = [
      'i get it',
      'understood',
      'makes sense',
      'clear',
      'got it',
      'i see',
      'ah okay',
      'thanks',
      'thank you',
      'perfect',
      'great',
    ];
    
    final lowerMessage = userMessage.toLowerCase();
    return understandingIndicators.any((indicator) => lowerMessage.contains(indicator));
  }

  /// Add related topic suggestions
  void addRelatedTopic(String topic) {
    if (!_suggestedTopics.contains(topic)) {
      _suggestedTopics.add(topic);
    }
  }

  /// Get summary of student's learning progress
  String getProgressSummary() {
    final buffer = StringBuffer();
    
    buffer.writeln('LEARNING PROGRESS:');
    buffer.writeln('Concepts explored: ${_explainedConcepts.length}');
    
    final understood = _explainedConcepts.values
        .where((c) => c.understood)
        .length;
    buffer.writeln('Concepts understood: $understood/${_explainedConcepts.length}');
    
    if (_weaknessAreas.isNotEmpty) {
      buffer.writeln('Areas needing review: ${_weaknessAreas.join(", ")}');
    }
    
    if (_suggestedTopics.isNotEmpty) {
      buffer.writeln('Related topics to explore: ${_suggestedTopics.take(3).join(", ")}');
    }
    
    return buffer.toString();
  }

  /// Get context for AI prompts
  String getContextForPrompt() {
    if (_explainedConcepts.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('\n[LEARNING CONTEXT]:');
    
    // Recently explained concepts
    final recent = _explainedConcepts.values
        .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    if (recent.isNotEmpty) {
      buffer.writeln('Recently explained: ${recent.take(3).map((c) => c.concept).join(", ")}');
    }
    
    // Weakness areas
    if (_weaknessAreas.isNotEmpty) {
      buffer.writeln('Student struggling with: ${_weaknessAreas.join(", ")}');
      buffer.writeln('(Provide extra support on these topics)');
    }
    
    return buffer.toString();
  }

  /// Clear all memory
  void clear() {
    _explainedConcepts.clear();
    _weaknessAreas.clear();
    _suggestedTopics.clear();
  }

  // Getters
  List<String> get weaknessAreas => List.unmodifiable(_weaknessAreas);
  List<String> get suggestedTopics => List.unmodifiable(_suggestedTopics);
  Map<String, ConceptRecord> get explainedConcepts => Map.unmodifiable(_explainedConcepts);
}

/// Record of a concept that was explained
class ConceptRecord {
  final String concept;
  final String explanation;
  final DateTime timestamp;
  final bool understood;
  final int clarificationCount;

  ConceptRecord({
    required this.concept,
    required this.explanation,
    required this.timestamp,
    required this.understood,
    required this.clarificationCount,
  });
}