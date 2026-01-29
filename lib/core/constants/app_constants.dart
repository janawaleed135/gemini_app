// lib/core/constants/app_constants.dart

import 'package:flutter/material.dart';

/// Application-wide constants
class AppConstants {
  AppConstants._(); // Private constructor

  // ========== APP INFO ==========
  static const String appName = 'AI Tutor';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Your Personal AI Study Companion';

  // ========== THEME COLORS ==========
  static const Color primaryColor = Color(0xFF6200EA); // Deep Purple
  static const Color secondaryColor = Color(0xFF03DAC6); // Teal
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFB00020);

  // ========== TUTOR COLORS ==========
  static const Color tutorColor = Color(0xFF1976D2); // Blue
  static const Color tutorLightColor = Color(0xFFBBDEFB);

  // ========== CLASSMATE COLORS ==========
  static const Color classmateColor = Color(0xFF388E3C); // Green
  static const Color classmateLightColor = Color(0xFFC8E6C9);

  // ========== MESSAGE COLORS ==========
  static const Color userMessageColor = Color(0xFF6200EA);
  static const Color aiMessageColor = Color(0xFFE0E0E0);

  // ========== TEXT STYLES ==========
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: Colors.black87,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: Colors.black54,
  );

  // ========== SPACING ==========
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  // ========== BORDER RADIUS ==========
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;

  // ========== ANIMATION DURATIONS ==========
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // ========== CONVERSATION LIMITS ==========
  static const int maxMessageLength = 500;
  static const int maxConversationHistory = 100;

  // ========== STORAGE KEYS ==========
  static const String storageKeyPrefix = 'ai_tutor_';
  static const String sessionsKey = '${storageKeyPrefix}sessions';
  static const String settingsKey = '${storageKeyPrefix}settings';
}