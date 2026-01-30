// lib/core/services/ai_service.dart

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_config.dart';
import '../constants/ai_prompts.dart';
import '../enums/ai_personality.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/session_model.dart';
import '../../data/models/slide_model.dart';
import 'context_memory_service.dart';
import 'conversation_state_service.dart';

/// AI Service - Manages all interactions with Google's Gemini AI
/// 
/// Features:
/// - Multi-personality AI (Tutor/Classmate)
/// - Context-aware conversations
/// - Slide analysis with Vision API
/// - Learning progress tracking
/// - Conversation state management
class AIService with ChangeNotifier {
  // ========== Core AI Components ==========
  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // ========== Personality & Session ==========
  AIPersonality _currentPersonality = AIPersonality.tutor;
  String _currentSessionId = '';
  
  // ========== Conversation Management ==========
  final List<ChatMessage> _conversationHistory = [];
  final List<String> _sessionTopics = [];
  
  // ========== Slide Context ==========
  List<SlideModel>? _loadedSlides;
  int? _currentSlideNumber;
  String? _currentSlideAnalysis;
  
  // ========== Enhanced Features ==========
  final ContextMemoryService _contextMemory = ContextMemoryService();
  ConversationStateService? _stateService;
  
  // ========== Getters ==========
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AIPersonality get currentPersonality => _currentPersonality;
  String get currentSessionId => _currentSessionId;
  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);
  List<String> get sessionTopics => List.unmodifiable(_sessionTopics);
  int? get currentSlideNumber => _currentSlideNumber;
  String? get currentSlideAnalysis => _currentSlideAnalysis;
  
  // Additional getters for UI
  bool get hasConversation => _conversationHistory.isNotEmpty;
  int get messageCount => _conversationHistory.length;
  bool get hasSlideContext => _currentSlideNumber != null && _loadedSlides != null;
  
  // Context Memory getters
  List<String> get weaknessAreas => _contextMemory.weaknessAreas;
  List<String> get suggestedTopics => _contextMemory.suggestedTopics;
  String get learningProgress => _contextMemory.getProgressSummary();

  // ========== INITIALIZATION ==========
  
  /// Initialize the AI service with API configuration
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) print('✅ AI Service already initialized');
      return;
    }

    try {
      if (kDebugMode) print('🤖 Initializing AI Service...');
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Validate API key
      if (!ApiConfig.isApiKeyConfigured) {
        throw Exception('API key not configured. ${ApiConfig.apiKeyErrorMessage}');
      }

      // Initialize the Gemini model
      _model = GenerativeModel(
        model: ApiConfig.geminiModel,
        apiKey: ApiConfig.geminiApiKey,
        generationConfig: GenerationConfig(
          temperature: ApiConfig.temperature,
          topK: ApiConfig.topK,
          topP: ApiConfig.topP,
          maxOutputTokens: ApiConfig.maxOutputTokens,
        ),
      );

      // Start a new chat session
      await _startNewSession();

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ AI Service initialized');
        print('📋 Model: ${ApiConfig.geminiModel}');
        print('🎭 Personality: ${_currentPersonality.displayName}');
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize: $e';
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) print('❌ Failed to initialize AI Service: $e');
      rethrow;
    }
  }

  /// Set the conversation state service for auto-save/resume
  void setStateService(ConversationStateService service) {
    _stateService = service;
    if (kDebugMode) print('✅ Conversation state service set');
  }

  /// Start a new chat session with the current personality
  Future<void> _startNewSession() async {
    if (_model == null) {
      throw Exception('Model not initialized');
    }

    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    // Build the system instruction based on personality
    final systemInstruction = _buildSystemInstruction();

    // Create new chat session
    _chat = _model!.startChat(
      history: [],
    );

    // Send system instruction as first message (invisible to user)
    try {
      await _chat!.sendMessage(Content.text(systemInstruction));
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ System instruction failed, continuing anyway: $e');
      }
    }

    _conversationHistory.clear();
    _sessionTopics.clear();

    // Add welcome message
    final welcomeMessage = ChatMessage.ai(
      _getWelcomeMessage(),
      _currentPersonality.displayName,
    );
    _conversationHistory.add(welcomeMessage);

    if (kDebugMode) {
      print('🆕 New session started: $_currentSessionId');
      print('🎭 Personality: ${_currentPersonality.displayName}');
    }
  }

  /// Build system instruction based on current personality
  String _buildSystemInstruction() {
    final baseInstruction = _currentPersonality == AIPersonality.tutor
        ? AIPrompts.tutorSystemPrompt
        : AIPrompts.classmateSystemPrompt;

    final contextInfo = _contextMemory.getContextForPrompt();
    
    return '$baseInstruction\n$contextInfo';
  }

  /// Get welcome message for current personality
  String _getWelcomeMessage() {
    if (_currentPersonality == AIPersonality.tutor) {
      return AIPrompts.tutorWelcomeMessage;
    } else {
      return AIPrompts.classmateWelcomeMessage;
    }
  }

  // ========== PERSONALITY MANAGEMENT ==========

  /// Switch between AI personalities with context preservation
  Future<void> switchPersonality(AIPersonality newPersonality) async {
    if (_currentPersonality == newPersonality) return;

    final oldPersonality = _currentPersonality;
    _currentPersonality = newPersonality;

    // PRESERVE conversation history instead of clearing
    final preservedHistory = List<ChatMessage>.from(_conversationHistory);
    final preservedTopics = List<String>.from(_sessionTopics);
    final preservedContext = _contextMemory.getProgressSummary();

    if (_isInitialized) {
      await _startNewSession();

      // Add transition message explaining the switch
      final transitionMessage = ChatMessage.ai(
        _buildTransitionMessage(oldPersonality, newPersonality, preservedContext),
        newPersonality.displayName,
      );

      _conversationHistory.clear();
      _conversationHistory.add(transitionMessage);

      // Re-add last few messages for context (keep last 4 exchanges)
      if (preservedHistory.length > 4) {
        _conversationHistory.addAll(
          preservedHistory.sublist(preservedHistory.length - 4),
        );
      } else {
        _conversationHistory.addAll(preservedHistory);
      }

      // Restore session topics
      _sessionTopics.clear();
      _sessionTopics.addAll(preservedTopics);
    }

    notifyListeners();

    if (kDebugMode) {
      print('🔄 Switched to ${newPersonality.displayName} (context preserved)');
      print('📚 Preserved ${preservedHistory.length} messages');
      print('🏷️ Preserved ${preservedTopics.length} topics');
    }
  }

  /// Build smooth transition message when switching personalities
  String _buildTransitionMessage(
    AIPersonality from,
    AIPersonality to,
    String progressSummary,
  ) {
    if (to == AIPersonality.tutor) {
      return '''Hey! I noticed you switched to Tutor mode. No worries - I remember everything we've discussed so far.

${progressSummary.isNotEmpty ? 'Here\'s what we\'ve covered:\n$progressSummary\n' : ''}Let's continue with a more structured approach. What would you like to explore next?''';
    } else {
      return '''Hey! Switched to Classmate mode! 😊

Don't worry, I haven't forgotten anything we talked about. ${progressSummary.isNotEmpty ? 'We\'ve been working on:\n$progressSummary\n' : ''}Let's keep it casual and figure things out together. What's next?''';
    }
  }

  // ========== CONVERSATION MANAGEMENT ==========

  /// Resume a saved conversation
  Future<bool> resumeConversation() async {
    if (_stateService == null || !_stateService!.hasSavedState()) {
      return false;
    }

    final state = await _stateService!.loadState();
    if (state == null) return false;

    try {
      // Restore messages
      final messages = (state['messages'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
      _conversationHistory.clear();
      _conversationHistory.addAll(messages);

      // Restore topics
      final topics = (state['topics'] as List).cast<String>();
      _sessionTopics.clear();
      _sessionTopics.addAll(topics);

      // Restore personality
      final personalityName = state['personality'] as String;
      _currentPersonality = personalityName.toLowerCase().contains('tutor')
          ? AIPersonality.tutor
          : AIPersonality.classmate;

      // Restore slide index
      if (state['currentSlideIndex'] != null) {
        _currentSlideNumber = state['currentSlideIndex'] as int;
      }

      // Restart chat session with restored context
      await _startNewSession();

      notifyListeners();

      if (kDebugMode) {
        print('🔄 Conversation resumed from saved state');
        print('📝 Restored ${messages.length} messages');
        print('🏷️ Restored ${topics.length} topics');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error resuming conversation: $e');
      }
      return false;
    }
  }

  /// Send a text message to the AI
  Future<String> sendMessage(String userMessage) async {
    if (!_isInitialized || _chat == null) {
      throw Exception('AI Service not initialized');
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      
      // Add user message to history
      final userMsg = ChatMessage.user(userMessage);
      _conversationHistory.add(userMsg);
      notifyListeners();

      if (kDebugMode) print('💬 User: $userMessage');

      // Build enhanced prompt with context
      final enhancedPrompt = _buildEnhancedPrompt(userMessage);

      // Send to AI
      final response = await _chat!.sendMessage(Content.text(enhancedPrompt));
      final aiResponse = response.text ?? 'Sorry, I could not generate a response.';

      // Add AI response to history
      final aiMsg = ChatMessage.ai(aiResponse, _currentPersonality.displayName);
      _conversationHistory.add(aiMsg);

      if (kDebugMode) print('🤖 AI: ${aiResponse.substring(0, aiResponse.length > 100 ? 100 : aiResponse.length)}...');

      // Detect confusion/understanding
      bool confused = _contextMemory.detectConfusion(userMessage);
      bool understood = _contextMemory.detectUnderstanding(userMessage);

      // Update session topics
      _updateSessionTopics(userMessage, aiResponse);

      // Track concepts and learning progress
      _trackLearningProgress(userMessage, aiResponse, understood, confused);

      // Auto-save conversation state
      if (_stateService != null) {
        await _stateService!.saveState(
          messages: _conversationHistory,
          personality: _currentPersonality.displayName,
          topics: _sessionTopics,
          currentSlideIndex: _currentSlideNumber,
        );
      }

      _isLoading = false;
      notifyListeners();
      return aiResponse;
    } catch (e) {
      _errorMessage = 'Error sending message: $e';
      _isLoading = false;
      
      if (kDebugMode) print('❌ Error sending message: $e');
      
      final errorMsg = ChatMessage.ai(
        'Sorry, I encountered an error: ${e.toString()}',
        _currentPersonality.displayName,
      );
      _conversationHistory.add(errorMsg);
      notifyListeners();
      
      rethrow;
    }
  }

  /// Build enhanced prompt with all available context
  String _buildEnhancedPrompt(String userMessage) {
    final buffer = StringBuffer();

    // Add slide context if available
    if (_currentSlideNumber != null && _loadedSlides != null) {
      final slideContext = _buildSlideContext();
      if (slideContext.isNotEmpty) {
        buffer.writeln(slideContext);
        buffer.writeln();
      }
    }

    // Add learning context from memory
    final memoryContext = _contextMemory.getContextForPrompt();
    if (memoryContext.isNotEmpty) {
      buffer.writeln(memoryContext);
      buffer.writeln();
    }

    // Add session topics context
    if (_sessionTopics.isNotEmpty) {
      buffer.writeln('[SESSION TOPICS]: ${_sessionTopics.join(", ")}');
      buffer.writeln();
    }

    // Add the actual user message
    buffer.write(userMessage);

    return buffer.toString();
  }

  /// Build slide context information
  String _buildSlideContext() {
    if (_currentSlideNumber == null || 
        _loadedSlides == null || 
        _currentSlideNumber! >= _loadedSlides!.length) {
      return '';
    }

    final slide = _loadedSlides![_currentSlideNumber!];
    final buffer = StringBuffer();

    buffer.writeln('[CURRENT SLIDE CONTEXT]:');
    buffer.writeln('Slide ${_currentSlideNumber! + 1} of ${_loadedSlides!.length}');

    if (slide.hasTitle) {
      buffer.writeln('Title: ${slide.title}');
    }

    if (_currentSlideAnalysis?.isNotEmpty ?? false) {
      buffer.writeln('Content Analysis:');
      buffer.writeln(_currentSlideAnalysis);
    }

    buffer.writeln('(Reference this slide content when answering)');

    return buffer.toString();
  }

  /// Track learning progress and concepts
  void _trackLearningProgress(
    String userMessage,
    String aiResponse,
    bool understood,
    bool confused,
  ) {
    // Extract and track concepts
    final concepts = _extractConcepts(userMessage, aiResponse);
    
    for (var concept in concepts) {
      // Count clarifications based on conversation history
      int clarificationCount = 0;
      if (confused) clarificationCount++;
      
      // Check previous messages for repeated questions about same concept
      for (var msg in _conversationHistory.reversed.take(5)) {
        if (msg.isUser && msg.message.toLowerCase().contains(concept.toLowerCase())) {
          clarificationCount++;
        }
      }

      _contextMemory.recordExplanation(
        concept,
        aiResponse,
        studentUnderstood: understood && !confused,
        clarificationCount: clarificationCount,
      );

      if (kDebugMode) {
        print('📚 Tracked concept: $concept (understood: ${understood && !confused})');
      }
    }

    // Suggest related topics
    final relatedTopics = _extractRelatedTopics(aiResponse);
    for (var topic in relatedTopics) {
      _contextMemory.addRelatedTopic(topic);
    }
  }

  /// Extract key concepts from conversation
  List<String> _extractConcepts(String userMsg, String aiMsg) {
    final keywords = <String>{};
    final combinedText = '$userMsg $aiMsg'.toLowerCase();

    // Look for educational patterns
    final conceptPatterns = [
      RegExp(r'concept of (\w+(?:\s+\w+){0,2})'),
      RegExp(r'(\w+(?:\s+\w+){0,2}) is (?:a|an|the)'),
      RegExp(r'(\w+(?:\s+\w+){0,2}) means'),
      RegExp(r'define (\w+(?:\s+\w+){0,2})'),
      RegExp(r'what is (\w+(?:\s+\w+){0,2})'),
      RegExp(r'explain (\w+(?:\s+\w+){0,2})'),
      RegExp(r'understand (\w+(?:\s+\w+){0,2})'),
    ];

    for (var pattern in conceptPatterns) {
      final matches = pattern.allMatches(combinedText);
      for (var match in matches) {
        final concept = match.group(1)?.trim();
        if (concept != null && 
            concept.isNotEmpty && 
            concept.length > 2 &&
            !_isCommonWord(concept)) {
          keywords.add(concept);
        }
      }
    }

    return keywords.toList();
  }

  /// Extract related topics mentioned in AI response
  List<String> _extractRelatedTopics(String aiResponse) {
    final topics = <String>{};
    final lowerResponse = aiResponse.toLowerCase();

    final topicPatterns = [
      RegExp(r'also learn about (\w+(?:\s+\w+){0,2})'),
      RegExp(r'related to (\w+(?:\s+\w+){0,2})'),
      RegExp(r'you might want to explore (\w+(?:\s+\w+){0,2})'),
      RegExp(r'next, we can discuss (\w+(?:\s+\w+){0,2})'),
    ];

    for (var pattern in topicPatterns) {
      final matches = pattern.allMatches(lowerResponse);
      for (var match in matches) {
        final topic = match.group(1)?.trim();
        if (topic != null && topic.isNotEmpty && topic.length > 2) {
          topics.add(topic);
        }
      }
    }

    return topics.toList();
  }

  /// Check if word is too common to be a concept
  bool _isCommonWord(String word) {
    const commonWords = {
      'this', 'that', 'these', 'those', 'what', 'where', 'when', 'why', 'how',
      'can', 'will', 'would', 'could', 'should', 'may', 'might', 'must',
      'the', 'a', 'an', 'and', 'or', 'but', 'if', 'then', 'because',
      'very', 'really', 'quite', 'just', 'only', 'also', 'even', 'still',
    };
    return commonWords.contains(word.toLowerCase());
  }

  /// Update session topics based on conversation
  void _updateSessionTopics(String userMessage, String aiResponse) {
    final combinedText = '$userMessage $aiResponse'.toLowerCase();
    
    // Extract key topics (simple keyword extraction)
    final words = combinedText.split(RegExp(r'[^\w]+'));
    final meaningfulWords = words.where((w) => 
      w.length > 4 && 
      !_isCommonWord(w) &&
      !RegExp(r'^\d+$').hasMatch(w)
    );

    // Count word frequency
    final wordCount = <String, int>{};
    for (var word in meaningfulWords) {
      wordCount[word] = (wordCount[word] ?? 0) + 1;
    }

    // Add words mentioned multiple times as topics
    for (var entry in wordCount.entries) {
      if (entry.value >= 2 && !_sessionTopics.contains(entry.key)) {
        _sessionTopics.add(entry.key);
        
        // Limit to 10 most recent topics
        if (_sessionTopics.length > 10) {
          _sessionTopics.removeAt(0);
        }
      }
    }
  }

  // ========== SLIDE MANAGEMENT ==========

  /// Load slides for analysis
  void loadSlides(List<SlideModel> slides) {
    _loadedSlides = slides;
    _currentSlideNumber = slides.isNotEmpty ? 0 : null;
    
    if (kDebugMode) {
      print('📊 Loaded ${slides.length} slides');
    }
    
    notifyListeners();
  }

  /// Set current slide being viewed
  void setCurrentSlide(int slideNumber) {
    if (_loadedSlides == null || slideNumber >= _loadedSlides!.length) {
      return;
    }
    
    _currentSlideNumber = slideNumber;
    _currentSlideAnalysis = null; // Clear old analysis
    
    if (kDebugMode) {
      print('📄 Current slide: ${slideNumber + 1}/${_loadedSlides!.length}');
    }
    
    notifyListeners();
  }

  /// Set slide context (for backward compatibility)
  void setSlideContext(int slideIndex, String? title) {
    setCurrentSlide(slideIndex);
  }

  /// Clear slide context
  void clearSlideContext() {
    _currentSlideNumber = null;
    _currentSlideAnalysis = null;
    notifyListeners();
  }

  /// Send slide-aware message (alias for sendMessage with context)
  Future<String> sendSlideAwareMessage(String message) async {
    return await sendMessage(message);
  }

  /// Analyze current slide using Gemini Vision
  Future<String> analyzeCurrentSlide() async {
    if (_currentSlideNumber == null || _loadedSlides == null) {
      throw Exception('No slide selected');
    }

    final slide = _loadedSlides![_currentSlideNumber!];
    return await analyzeSlide(slide);
  }

  /// Analyze a specific slide with Vision API
  Future<String> analyzeSlide(SlideModel slide) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized');
    }

    try {
      _isLoading = true;
      notifyListeners();

      if (kDebugMode) {
        print('🔍 Analyzing slide: ${slide.hasTitle ? slide.title : "Untitled"}');
      }

      // Create vision model
      final visionModel = GenerativeModel(
        model: 'gemini-2.0-flash-exp', // Vision-capable model
        apiKey: ApiConfig.geminiApiKey,
      );

      // Prepare the image
      final imageBytes = slide.imageBytes;
      if (imageBytes == null) {
        throw Exception('Slide image is not available for analysis');
      }

      // Build analysis prompt
      final prompt = _buildSlideAnalysisPrompt();

      // Create content with image and text
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      // Generate analysis
      final response = await visionModel.generateContent(content);
      final analysis = response.text ?? 'Could not analyze slide.';

      // Cache the analysis
      _currentSlideAnalysis = analysis;

      _isLoading = false;

      if (kDebugMode) {
        print('✅ Slide analyzed successfully');
        print('📝 Analysis preview: ${analysis.substring(0, analysis.length > 100 ? 100 : analysis.length)}...');
      }

      notifyListeners();
      return analysis;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) print('❌ Error analyzing slide: $e');
      rethrow;
    }
  }

  /// Build comprehensive slide analysis prompt
  String _buildSlideAnalysisPrompt() {
    return '''Analyze this educational slide image and provide:

1. **Main Topic**: What is this slide about?
2. **Key Concepts**: List the main concepts or ideas presented
3. **Visual Elements**: Describe any diagrams, charts, or images
4. **Text Content**: Summarize the text visible on the slide
5. **Formulas/Equations**: Extract and explain any mathematical formulas
6. **Learning Objectives**: What should a student learn from this?
7. **Suggested Questions**: 2-3 questions a teacher might ask about this content

Format your response clearly with headers for each section.
Be thorough but concise. Focus on educational value.''';
  }

  /// Analyze slide and explain a specific aspect
  Future<String> explainSlideAspect(
    SlideModel slide,
    String aspect, {
    String? specificQuestion,
  }) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized');
    }

    try {
      _isLoading = true;
      notifyListeners();

      if (kDebugMode) {
        print('🔍 Explaining slide aspect: $aspect');
      }

      final visionModel = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: ApiConfig.geminiApiKey,
      );

      final imageBytes = slide.imageBytes;
      if (imageBytes == null) {
        throw Exception('Slide image is not available for analysis');
      }

      // Build targeted prompt
      final prompt = specificQuestion != null
          ? '''Look at this slide and answer: $specificQuestion

Focus on: $aspect

Provide a clear, educational explanation.'''
          : '''Analyze this slide and explain: $aspect

Provide detailed educational explanation appropriate for a student.''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await visionModel.generateContent(content);
      final explanation = response.text ?? 'Could not generate explanation.';

      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ Aspect explained successfully');
      }

      return explanation;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) print('❌ Error explaining slide aspect: $e');
      rethrow;
    }
  }

  /// Ask a question about the current slide
  Future<String> askAboutSlide(String question) async {
    if (_currentSlideNumber == null || _loadedSlides == null) {
      throw Exception('No slide selected');
    }

    // First ensure we have analysis
    if (_currentSlideAnalysis == null) {
      await analyzeCurrentSlide();
    }

    // Now ask the question with full context
    final contextualQuestion = '''[Question about Slide ${_currentSlideNumber! + 1}]

Previous Analysis:
$_currentSlideAnalysis

Student's Question: $question

Please answer based on the slide content and analysis above.''';

    return await sendMessage(contextualQuestion);
  }

  /// Get conversation transcript
  String getTranscript() {
    return _conversationHistory.map((msg) {
      return '${msg.sender}: ${msg.message}';
    }).join('\n\n');
  }

  // ========== SESSION MANAGEMENT ==========

  /// Get current session summary
  SessionModel getCurrentSession() {
    return SessionModel.fromAIService(
      id: _currentSessionId,
      startTime: DateTime.now().subtract(
        Duration(seconds: _conversationHistory.length * 30),
      ),
      endTime: DateTime.now(),
      personality: _currentPersonality,
      messages: _conversationHistory,
      topics: _sessionTopics,
      slideCount: _loadedSlides?.length ?? 0,
      userId: ApiConfig.defaultUserId,
    );
  }

  /// Clear current conversation but keep slides loaded
  Future<void> clearConversation() async {
    _conversationHistory.clear();
    _sessionTopics.clear();
    _contextMemory.clear();
    
    // Clear saved state
    if (_stateService != null) {
      await _stateService!.clearState();
    }
    
    await _startNewSession();
    
    if (kDebugMode) {
      print('🗑️ Conversation cleared');
    }
    
    notifyListeners();
  }

  /// Complete reset - clear everything including slides
  Future<void> reset() async {
    _conversationHistory.clear();
    _sessionTopics.clear();
    _loadedSlides = null;
    _currentSlideNumber = null;
    _currentSlideAnalysis = null;
    _contextMemory.clear();
    
    // Clear saved state
    if (_stateService != null) {
      await _stateService!.clearState();
    }
    
    await _startNewSession();
    
    if (kDebugMode) {
      print('🔄 AI Service reset');
    }
    
    notifyListeners();
  }

  /// Dispose and cleanup
  @override
  void dispose() {
    _chat = null;
    _model = null;
    _conversationHistory.clear();
    _sessionTopics.clear();
    super.dispose();
  }
}