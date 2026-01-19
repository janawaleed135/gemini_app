import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../enums/ai_personality.dart';
import '../constants/ai_prompts.dart';
import '../../data/models/chat_message.dart';

/// Service that handles AI interactions with Google Gemini
class AIService extends ChangeNotifier {
  // ========== Dependencies ==========
  GenerativeModel? _model;
  ChatSession? _chatSession;
  
  // ========== State ==========
  AIPersonality _currentPersonality = AIPersonality.tutor;
  final List<ChatMessage> _conversationHistory = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isInitialized = false;
  
  // ========== Getters ==========
  AIPersonality get currentPersonality => _currentPersonality;
  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;
  bool get isInitialized => _isInitialized;
  
  // ========== Initialization ==========
  Future<void> initialize(String apiKey) async {
    try {
      // ✅ CORRECT: Use the model without 'latest' suffix
      _model = GenerativeModel(
        model: 'gemini-flash-latest',  // Simple model name
        apiKey: apiKey,
      );
      
      await _startNewSession();
      _isInitialized = true;
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ AI Service initialized successfully');
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize AI: $e';
      _isLoading = false;
      _isInitialized = false;
      notifyListeners();
      
      if (kDebugMode) {
        print('❌ AI Service initialization error: $e');
      }
      rethrow;
    }
  }
  
  // ========== Session Management ==========
  Future<void> _startNewSession() async {
    if (_model == null) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }
    
    final systemPrompt = AIPrompts.getSystemPrompt(_currentPersonality);
    
    // ✅ CORRECT: Start with system instruction in history
    _chatSession = _model!.startChat(
      history: [
        Content.text(systemPrompt),
        Content.model([
          TextPart('Understood! I will act as a ${_currentPersonality.displayName}.')
        ]),
      ],
    );
    
    if (kDebugMode) {
      print('🔄 New session started with ${_currentPersonality.displayName} personality');
    }
  }
  
  // ========== Personality Switching ==========
  Future<void> switchPersonality(AIPersonality newPersonality) async {
    if (_currentPersonality == newPersonality) return;
    
    _currentPersonality = newPersonality;
    _conversationHistory.clear();
    await _startNewSession();
    notifyListeners();
    
    if (kDebugMode) {
      print('🔄 Switched to ${newPersonality.displayName} mode');
    }
  }
  
  // ========== Core Messaging ==========
  Future<String> sendMessage(String userMessage) async {
    if (_model == null || _chatSession == null) {
      throw Exception('AI Service not initialized');
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
        print('📤 Sending message: $userMessage');
      }
      
      // Send to Gemini
      final response = await _chatSession!.sendMessage(
        Content.text(userMessage),
      );
      
      final aiResponse = response.text ?? 'Sorry, I could not generate a response.';
      
      if (kDebugMode) {
        print('📥 Received response: $aiResponse');
      }
      
      // Add AI response to history
      final aiChatMessage = ChatMessage.ai(
        aiResponse,
        _currentPersonality.displayName,
      );
      _conversationHistory.add(aiChatMessage);
      
      _isLoading = false;
      notifyListeners();
      
      return aiResponse;
      
    } catch (e) {
      _errorMessage = 'Failed to get AI response: $e';
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) {
        print('❌ AI Service Error: $e');
      }
      
      rethrow;
    }
  }
  
  // ========== Conversation Management ==========
  Future<void> clearConversation() async {
    _conversationHistory.clear();
    await _startNewSession();
    notifyListeners();
  }
  
  String getTranscript() {
    final buffer = StringBuffer();
    
    for (final message in _conversationHistory) {
      final speaker = message.isUser ? 'Student' : message.personality ?? 'AI';
      final time = _formatTime(message.timestamp);
      
      buffer.writeln('[$time] $speaker: ${message.content}');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  // ========== Error Management ==========
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
  
  // ========== Cleanup ==========
  @override
  void dispose() {
    _chatSession = null;
    _model = null;
    super.dispose();
  }
}