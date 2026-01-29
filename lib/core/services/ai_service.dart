// lib/core/services/ai_service.dart

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../enums/ai_personality.dart';
import '../constants/ai_prompts.dart';
import '../config/api_config.dart';
import '../../data/models/chat_message.dart';

/// Service for managing AI chat interactions with Gemini
/// Enhanced with context memory and conversation tracking
class AIService extends ChangeNotifier {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  
  AIPersonality _currentPersonality = AIPersonality.tutor;
  final List<ChatMessage> _conversationHistory = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isInitialized = false;
  
  // Context memory - tracks the current session's topics and concepts
  final List<String> _sessionTopics = [];
  String _currentSessionContext = '';
  
  // ========== Getters ==========
  AIPersonality get currentPersonality => _currentPersonality;
  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;
  bool get isInitialized => _isInitialized;
  List<String> get sessionTopics => List.unmodifiable(_sessionTopics);
  
  // ========== Auto-Initialize ==========
  /// Automatically initialize with built-in API key
  Future<void> autoInitialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('✅ Already initialized');
      }
      return;
    }

    // Validate API key configuration
    if (!ApiConfig.isApiKeyConfigured) {
      _errorMessage = ApiConfig.apiKeyErrorMessage;
      _isInitialized = false;
      notifyListeners();
      throw Exception('Invalid API key configuration');
    }

    await initialize(ApiConfig.geminiApiKey);
  }

  // ========== Initialize ==========
  /// Initialize AI service with optional `apiKey`.
  /// If `apiKey` is omitted, `ApiConfig.geminiApiKey` will be used.
  Future<void> initialize([String? apiKey]) async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠️ Service already initialized');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔧 Initializing AI Service...');
        final displayKey = (apiKey ?? ApiConfig.geminiApiKey);
        final keyPreview = displayKey.length > 10 ? '${displayKey.substring(0, 10)}...' : displayKey;
        print('🔑 API Key: $keyPreview');
        print('🤖 Model: ${ApiConfig.geminiModel}');
      }

      final usedKey = apiKey ?? ApiConfig.geminiApiKey;

      if (usedKey.isEmpty) {
        throw Exception('API key cannot be empty');
      }

      _model = GenerativeModel(
        model: ApiConfig.geminiModel,
        apiKey: usedKey,
        generationConfig: GenerationConfig(
          temperature: ApiConfig.temperature,
          topK: ApiConfig.topK,
          topP: ApiConfig.topP,
          maxOutputTokens: ApiConfig.maxOutputTokens,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
        ],
      );
      
      await _startNewSession();
      _isInitialized = true;
      _errorMessage = '';
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ AI Service initialized successfully!');
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize AI: $e';
      _isLoading = false;
      _isInitialized = false;
      notifyListeners();
      
      if (kDebugMode) {
        print('❌ Initialization Error: $e');
      }
      rethrow;
    }
  }
  
  // ========== Start New Session ==========
  Future<void> _startNewSession() async {
    if (_model == null) {
      throw Exception('AI model not initialized');
    }
    
    final systemPrompt = AIPrompts.getSystemPrompt(_currentPersonality);
    
    try {
      _chatSession = _model!.startChat(
        history: [],
      );
      
      // Send system prompt as first message
      await _chatSession!.sendMessage(Content.text(systemPrompt));
      
      // Reset session context
      _sessionTopics.clear();
      _currentSessionContext = '';
      
      if (kDebugMode) {
        print('🔄 New chat session started: ${_currentPersonality.displayName} mode');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting session: $e');
      }
      rethrow;
    }
  }
  
  // ========== Switch Personality ==========
  /// Switch between Tutor and Classmate modes
  Future<void> switchPersonality(AIPersonality newPersonality) async {
    if (_currentPersonality == newPersonality) return;
    
    _currentPersonality = newPersonality;
    _conversationHistory.clear();
    _sessionTopics.clear();
    _currentSessionContext = '';
    
    if (_isInitialized) {
      await _startNewSession();
    }
    
    notifyListeners();
    
    if (kDebugMode) {
      print('🔄 Switched to ${newPersonality.displayName}');
    }
  }
  
  // ========== Context Building ==========
  /// Build context summary from conversation history
  String _buildContextSummary() {
    if (_conversationHistory.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('\n[SESSION CONTEXT - Remember this information]:');
    
    if (_sessionTopics.isNotEmpty) {
      buffer.writeln('Topics discussed: ${_sessionTopics.join(", ")}');
    }
    
    // Include last few exchanges for immediate context
    final recentMessages = _conversationHistory.length > 6 
        ? _conversationHistory.sublist(_conversationHistory.length - 6)
        : _conversationHistory;
    
    buffer.writeln('Recent conversation:');
    for (var msg in recentMessages) {
      final speaker = msg.isUser ? 'Student' : 'You';
      buffer.writeln('$speaker: ${msg.content}');
    }
    
    buffer.writeln('[Continue the conversation naturally, referencing previous topics when relevant]');
    return buffer.toString();
  }
  
  /// Extract and track topics from conversation
  void _updateSessionTopics(String userMessage, String aiResponse) {
    // Simple topic extraction - in production, you might use more sophisticated methods
    final keywords = ['slide', 'diagram', 'concept', 'formula', 'equation', 
                     'theory', 'problem', 'question', 'example', 'topic'];
    
    for (var keyword in keywords) {
      if (userMessage.toLowerCase().contains(keyword) || 
          aiResponse.toLowerCase().contains(keyword)) {
        if (!_sessionTopics.contains(keyword)) {
          _sessionTopics.add(keyword);
        }
      }
    }
  }
  
  // ========== Send Message ==========
  /// Send a message and get AI response with context awareness
  Future<String> sendMessage(String userMessage) async {
    // Auto-initialize if not done
    if (!_isInitialized) {
      await autoInitialize();
    }

    if (_model == null || _chatSession == null) {
      throw Exception('AI Service not initialized properly');
    }
    
    if (userMessage.trim().isEmpty) {
      throw Exception('Cannot send empty message');
    }
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      // Add user message to history
      final userChatMessage = ChatMessage.user(userMessage);
      _conversationHistory.add(userChatMessage);
      notifyListeners();
      
      if (kDebugMode) {
        print('📤 User: $userMessage');
      }
      
      // Build context-aware message
      String contextualMessage = userMessage;
      if (_conversationHistory.length > 1) {
        contextualMessage = _buildContextSummary() + '\n\nStudent: ' + userMessage;
      }
      
      // Send to Gemini and get response
      final response = await _chatSession!.sendMessage(
        Content.text(contextualMessage),
      );
      
      final aiResponse = response.text ?? 
        'I apologize, I couldn\'t generate a response. Could you try asking that again?';
      
      if (kDebugMode) {
        print('📥 AI (${_currentPersonality.displayName}): $aiResponse');
      }
      
      // Update session topics
      _updateSessionTopics(userMessage, aiResponse);
      
      // Add AI message to history
      final aiChatMessage = ChatMessage.ai(
        aiResponse,
        _currentPersonality.displayName,
      );
      _conversationHistory.add(aiChatMessage);
      
      _isLoading = false;
      notifyListeners();
      
      return aiResponse;
      
    } catch (e) {
      _errorMessage = 'Failed to get response: $e';
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) {
        print('❌ Send Message Error: $e');
      }
      
      // Add error message to help user
      final errorChatMessage = ChatMessage.ai(
        'Sorry, I encountered an error. Please check your internet connection and try again.',
        _currentPersonality.displayName,
      );
      _conversationHistory.add(errorChatMessage);
      notifyListeners();
      
      rethrow;
    }
  }
  
  // ========== Clear Conversation ==========
  /// Clear all messages and start fresh
  Future<void> clearConversation() async {
    _conversationHistory.clear();
    _sessionTopics.clear();
    _currentSessionContext = '';
    
    if (_isInitialized) {
      await _startNewSession();
    }
    
    notifyListeners();
    
    if (kDebugMode) {
      print('🗑️ Conversation cleared');
    }
  }
  
  // ========== Get Transcript ==========
  /// Get formatted transcript of conversation
  String getTranscript() {
    final buffer = StringBuffer();
    buffer.writeln('=== Chat Transcript ===');
    buffer.writeln('Mode: ${_currentPersonality.displayName}');
    buffer.writeln('Messages: ${_conversationHistory.length}');
    if (_sessionTopics.isNotEmpty) {
      buffer.writeln('Topics: ${_sessionTopics.join(", ")}');
    }
    buffer.writeln(''.padLeft(50, '='));
    buffer.writeln();
    
    for (final message in _conversationHistory) {
      final speaker = message.isUser ? 'Student' : message.personality ?? 'AI';
      final time = _formatTime(message.timestamp);
      
      buffer.writeln('[$time] $speaker:');
      buffer.writeln(message.content);
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Whether there is any conversation history
  bool get hasConversation => _conversationHistory.isNotEmpty;

  /// Count of messages in the current conversation
  int get messageCount => _conversationHistory.length;
  
  // ========== Error Management ==========
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
  
  // ========== Dispose ==========
  @override
  void dispose() {
    _chatSession = null;
    _model = null;
    super.dispose();
  }
}