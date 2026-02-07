// lib/core/services/emotion_detection_service.dart

import 'package:flutter/foundation.dart';

/// Detects student emotions from their messages to provide appropriate support
class EmotionDetectionService {
  
  /// Current detected emotion state
  StudentEmotion _currentEmotion = StudentEmotion.neutral;
  
  /// History of emotions throughout the session
  final List<EmotionRecord> _emotionHistory = [];
  
  /// Emotion patterns that might indicate deeper issues
  int _consecutiveFrustrationCount = 0;
  int _consecutiveConfusionCount = 0;
  
  // ========== Getters ==========
  StudentEmotion get currentEmotion => _currentEmotion;
  List<EmotionRecord> get emotionHistory => List.unmodifiable(_emotionHistory);
  
  /// Detect emotion from a user message
  StudentEmotion detectEmotion(String message) {
    final lowerMessage = message.toLowerCase().trim();
    
    // Check for multiple emotions (priority order matters)
    StudentEmotion detectedEmotion = StudentEmotion.neutral;
    
    // 1. Check for frustration (high priority)
    if (_isFrustrated(lowerMessage)) {
      detectedEmotion = StudentEmotion.frustrated;
      _consecutiveFrustrationCount++;
      _consecutiveConfusionCount = 0;
    }
    // 2. Check for confusion
    else if (_isConfused(lowerMessage)) {
      detectedEmotion = StudentEmotion.confused;
      _consecutiveConfusionCount++;
      _consecutiveFrustrationCount = 0;
    }
    // 3. Check for excitement
    else if (_isExcited(lowerMessage)) {
      detectedEmotion = StudentEmotion.excited;
      _consecutiveFrustrationCount = 0;
      _consecutiveConfusionCount = 0;
    }
    // 4. Check for boredom
    else if (_isBored(lowerMessage)) {
      detectedEmotion = StudentEmotion.bored;
    }
    // 5. Check for anxiety
    else if (_isAnxious(lowerMessage)) {
      detectedEmotion = StudentEmotion.anxious;
    }
    // 6. Check for understanding/happiness
    else if (_isHappy(lowerMessage)) {
      detectedEmotion = StudentEmotion.happy;
      _consecutiveFrustrationCount = 0;
      _consecutiveConfusionCount = 0;
    }
    // 7. Default to neutral
    else {
      detectedEmotion = StudentEmotion.neutral;
    }
    
    // Update current emotion
    _currentEmotion = detectedEmotion;
    
    // Record in history
    _emotionHistory.add(EmotionRecord(
      emotion: detectedEmotion,
      message: message,
      timestamp: DateTime.now(),
    ));
    
    if (kDebugMode) {
      print('🎭 Detected emotion: ${detectedEmotion.name} - "$message"');
      if (_consecutiveFrustrationCount > 2) {
        print('⚠️ Student showing repeated frustration!');
      }
      if (_consecutiveConfusionCount > 2) {
        print('⚠️ Student showing repeated confusion!');
      }
    }
    
    return detectedEmotion;
  }
  
  // ========== Emotion Detection Methods ==========
  
  bool _isFrustrated(String message) {
    final frustrationIndicators = [
      'ugh',
      'this is hard',
      'i don\'t get it',
      'this doesn\'t make sense',
      'why doesn\'t this work',
      'i can\'t',
      'i\'m stuck',
      'this is impossible',
      'i give up',
      'this sucks',
      'frustrated',
      'annoying',
      'stupid',
      'still don\'t understand',
      'tried everything',
      'nothing works',
    ];
    
    return frustrationIndicators.any((indicator) => message.contains(indicator));
  }
  
  bool _isConfused(String message) {
    final confusionIndicators = [
      'what?',
      'what',
      'huh?',
      'huh',
      'i\'m lost',
      'i\'m confused',
      'confused',
      'don\'t understand',
      'what does this mean',
      'what is this',
      'unclear',
      'not sure',
      '???',
      '??',
      'wait',
      'hold on',
      'explain',
      'clarify',
    ];
    
    // Also check for excessive question marks
    final questionMarkCount = '?'.allMatches(message).length;
    if (questionMarkCount >= 2) return true;
    
    return confusionIndicators.any((indicator) => message.contains(indicator));
  }
  
  bool _isExcited(String message) {
    final excitementIndicators = [
      'wow',
      'cool',
      'awesome',
      'amazing',
      'fantastic',
      'love this',
      'this is great',
      'omg',
      'oh my god',
      'that\'s so cool',
      'interesting',
      'fascinating',
      'incredible',
      'brilliant',
    ];
    
    // Check for excessive exclamation marks
    final exclamationCount = '!'.allMatches(message).length;
    if (exclamationCount >= 2) return true;
    
    return excitementIndicators.any((indicator) => message.contains(indicator));
  }
  
  bool _isBored(String message) {
    // Short, disengaged responses
    if (message.length <= 5) {
      final boringResponses = ['ok', 'okay', 'yeah', 'sure', 'meh', 'k', 'fine'];
      if (boringResponses.contains(message)) return true;
    }
    
    final boredomIndicators = [
      'boring',
      'not interested',
      'don\'t care',
      'whatever',
      'this is dry',
    ];
    
    return boredomIndicators.any((indicator) => message.contains(indicator));
  }
  
  bool _isAnxious(String message) {
    final anxietyIndicators = [
      'am i doing this right',
      'is this correct',
      'did i mess up',
      'am i wrong',
      'i don\'t know if',
      'not sure if i',
      'worried',
      'nervous',
      'anxious',
      'scared',
      'afraid',
      'i hope this is right',
      'please tell me if',
      'sorry if',
    ];
    
    return anxietyIndicators.any((indicator) => message.contains(indicator));
  }
  
  bool _isHappy(String message) {
    final happyIndicators = [
      'i get it',
      'i understand',
      'got it',
      'makes sense',
      'clear',
      'thanks',
      'thank you',
      'perfect',
      'great',
      'awesome',
      'i see',
      'ah okay',
      'oh i see',
      'that helps',
      'helpful',
      'yes',
    ];
    
    return happyIndicators.any((indicator) => message.contains(indicator));
  }
  
  // ========== Emotional State Analysis ==========
  
  /// Check if student is showing signs of struggling
  bool isStruggling() {
    return _consecutiveFrustrationCount >= 3 || 
           _consecutiveConfusionCount >= 3;
  }
  
  /// Get encouragement level needed (0-3)
  int getEncouragementLevel() {
    if (_consecutiveFrustrationCount >= 3) return 3;
    if (_consecutiveFrustrationCount >= 2) return 2;
    if (_consecutiveConfusionCount >= 3) return 2;
    if (_currentEmotion == StudentEmotion.anxious) return 2;
    if (_currentEmotion == StudentEmotion.frustrated) return 1;
    if (_currentEmotion == StudentEmotion.confused) return 1;
    return 0;
  }
  
  /// Get suggested teaching approach based on emotion
  String getSuggestedApproach() {
    if (_consecutiveFrustrationCount >= 3) {
      return 'HIGHLY_SIMPLIFIED - Break into smallest steps, use analogies, take a break';
    }
    if (_consecutiveConfusionCount >= 3) {
      return 'ALTERNATIVE_APPROACH - Try different explanation method, use visuals';
    }
    
    switch (_currentEmotion) {
      case StudentEmotion.frustrated:
        return 'PATIENT_SIMPLIFIED - Simplify, encourage, show it\'s okay to struggle';
      case StudentEmotion.confused:
        return 'CLARIFY_SLOW - Ask what\'s unclear, break down further, check understanding';
      case StudentEmotion.excited:
        return 'BUILD_MOMENTUM - Dive deeper, explore related topics, challenge appropriately';
      case StudentEmotion.bored:
        return 'ENGAGE_INTERACTIVE - Make it relevant, use examples, ask questions';
      case StudentEmotion.anxious:
        return 'REASSURE_GUIDE - Show mistakes are okay, be gentle, build confidence';
      case StudentEmotion.happy:
        return 'REINFORCE_PROGRESS - Acknowledge progress, continue building';
      case StudentEmotion.neutral:
        return 'STANDARD - Normal teaching pace';
    }
  }
  
  /// Get context string for AI prompt
  String getEmotionalContext() {
    final buffer = StringBuffer();
    
    if (_currentEmotion != StudentEmotion.neutral) {
      buffer.writeln('\n[STUDENT EMOTIONAL STATE]:');
      buffer.writeln('Current emotion: ${_currentEmotion.displayName}');
      
      if (_consecutiveFrustrationCount > 0) {
        buffer.writeln('⚠️ Frustration count: $_consecutiveFrustrationCount');
      }
      if (_consecutiveConfusionCount > 0) {
        buffer.writeln('⚠️ Confusion count: $_consecutiveConfusionCount');
      }
      
      buffer.writeln('Suggested approach: ${getSuggestedApproach()}');
      buffer.writeln('Encouragement needed: ${getEncouragementLevel()}/3');
      
      // Add specific guidance
      switch (_currentEmotion) {
        case StudentEmotion.frustrated:
          buffer.writeln('💡 Be extra patient, simplify your explanation, offer encouragement');
          break;
        case StudentEmotion.confused:
          buffer.writeln('💡 Break things down more, use different approach, ask what\'s unclear');
          break;
        case StudentEmotion.excited:
          buffer.writeln('💡 Match their energy, explore deeper, build on enthusiasm');
          break;
        case StudentEmotion.bored:
          buffer.writeln('💡 Make it interactive, relate to interests, change approach');
          break;
        case StudentEmotion.anxious:
          buffer.writeln('💡 Be reassuring, show mistakes are okay, build confidence');
          break;
        case StudentEmotion.happy:
          buffer.writeln('💡 Acknowledge their progress, keep building momentum');
          break;
        default:
          break;
      }
    }
    
    return buffer.toString();
  }
  
  /// Get emotion summary for session
  String getSessionEmotionSummary() {
    if (_emotionHistory.isEmpty) return 'No emotional data';
    
    final emotionCounts = <StudentEmotion, int>{};
    for (final record in _emotionHistory) {
      emotionCounts[record.emotion] = (emotionCounts[record.emotion] ?? 0) + 1;
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Session Emotional Journey:');
    emotionCounts.forEach((emotion, count) {
      buffer.writeln('${emotion.displayName}: $count times');
    });
    
    if (_consecutiveFrustrationCount > 2 || _consecutiveConfusionCount > 2) {
      buffer.writeln('\n⚠️ Student showed sustained difficulty');
    }
    
    return buffer.toString();
  }
  
  /// Clear emotion history
  void clear() {
    _emotionHistory.clear();
    _consecutiveFrustrationCount = 0;
    _consecutiveConfusionCount = 0;
    _currentEmotion = StudentEmotion.neutral;
  }
}

/// Student emotion states
enum StudentEmotion {
  neutral,
  happy,
  excited,
  confused,
  frustrated,
  bored,
  anxious,
}

extension StudentEmotionExtension on StudentEmotion {
  String get displayName {
    switch (this) {
      case StudentEmotion.neutral:
        return 'Neutral';
      case StudentEmotion.happy:
        return 'Happy/Understanding';
      case StudentEmotion.excited:
        return 'Excited';
      case StudentEmotion.confused:
        return 'Confused';
      case StudentEmotion.frustrated:
        return 'Frustrated';
      case StudentEmotion.bored:
        return 'Bored';
      case StudentEmotion.anxious:
        return 'Anxious';
    }
  }
  
  String get emoji {
    switch (this) {
      case StudentEmotion.neutral:
        return '😐';
      case StudentEmotion.happy:
        return '😊';
      case StudentEmotion.excited:
        return '🤩';
      case StudentEmotion.confused:
        return '😕';
      case StudentEmotion.frustrated:
        return '😤';
      case StudentEmotion.bored:
        return '😑';
      case StudentEmotion.anxious:
        return '😰';
    }
  }
}

/// Record of a detected emotion
class EmotionRecord {
  final StudentEmotion emotion;
  final String message;
  final DateTime timestamp;
  
  EmotionRecord({
    required this.emotion,
    required this.message,
    required this.timestamp,
  });
}