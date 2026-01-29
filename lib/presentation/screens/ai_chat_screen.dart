// lib/presentation/screens/ai_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/ai_service.dart';
import '../../core/enums/ai_personality.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/chat_message.dart';
import '../providers/session_provider.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isInitialized = false;
  bool _hasStartedSession = false;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    final aiService = context.read<AIService>();
    
    if (!aiService.isInitialized) {
      try {
        await aiService.initialize();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          
          // Show welcome message
          _showWelcomeMessage();
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog(
            'Initialization Error',
            aiService.errorMessage.isNotEmpty 
              ? aiService.errorMessage 
              : 'Failed to initialize AI: $e',
          );
        }
      }
    } else {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _showWelcomeMessage() {
    final aiService = context.read<AIService>();
    final welcomeMessage = aiService.currentPersonality == AIPersonality.tutor
        ? "Hello! 👋 I'm your AI Tutor. I'm here to help you learn and understand any topic. What would you like to explore today?"
        : "Hey there! 👋 Ready to learn something cool together? What should we study?";
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(welcomeMessage),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Start session if this is the first message
    if (!_hasStartedSession) {
      final sessionProvider = context.read<SessionProvider>();
      sessionProvider.startNewSession(
        'Chat Session - ${DateTime.now().toString().split(' ')[0]}',
        'user_001', // You can replace this with actual user ID
      );
      _hasStartedSession = true;
    }

    _messageController.clear();
    _focusNode.requestFocus();

    final aiService = context.read<AIService>();
    final sessionProvider = context.read<SessionProvider>();

    try {
      await aiService.sendMessage(text);
      
      // Update session transcript
      sessionProvider.updateSessionTranscript(aiService.conversationHistory);
      
      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppConstants.animationNormal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPersonalityDialog() {
    final aiService = context.read<AIService>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose AI Personality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PersonalityOption(
              personality: AIPersonality.tutor,
              isSelected: aiService.currentPersonality == AIPersonality.tutor,
              onTap: () {
                Navigator.pop(context);
                _switchPersonality(AIPersonality.tutor);
              },
            ),
            const SizedBox(height: AppConstants.spacingM),
            _PersonalityOption(
              personality: AIPersonality.classmate,
              isSelected: aiService.currentPersonality == AIPersonality.classmate,
              onTap: () {
                Navigator.pop(context);
                _switchPersonality(AIPersonality.classmate);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchPersonality(AIPersonality personality) async {
    final aiService = context.read<AIService>();
    
    if (aiService.currentPersonality == personality) return;
    
    // Confirm if there's an active conversation
    if (aiService.hasConversation) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Switch Personality?'),
          content: const Text(
            'Switching personality will clear the current conversation. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
    }
    
    await aiService.switchPersonality(personality);
    _hasStartedSession = false;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${personality.displayName} mode'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearConversation() async {
    final aiService = context.read<AIService>();
    
    if (!aiService.hasConversation) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation?'),
        content: const Text('This will delete all messages in the current conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await aiService.clearConversation();
      _hasStartedSession = false;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation cleared')),
        );
      }
    }
  }

  void _copyTranscript() {
    final aiService = context.read<AIService>();
    final transcript = aiService.getTranscript();
    
    Clipboard.setData(ClipboardData(text: transcript));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcript copied to clipboard')),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<AIService>(
          builder: (context, aiService, _) {
            return Row(
              children: [
                Text(aiService.currentPersonality.icon),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${aiService.currentPersonality.displayName} Mode',
                      style: const TextStyle(fontSize: 18),
                    ),
                    if (aiService.messageCount > 0)
                      Text(
                        '${aiService.messageCount} messages',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Personality switch
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _showPersonalityDialog,
            tooltip: 'Switch Personality',
          ),
          // Copy transcript
          Consumer<AIService>(
            builder: (context, aiService, _) {
              return IconButton(
                icon: const Icon(Icons.copy),
                onPressed: aiService.hasConversation ? _copyTranscript : null,
                tooltip: 'Copy Transcript',
              );
            },
          ),
          // Clear conversation
          Consumer<AIService>(
            builder: (context, aiService, _) {
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: aiService.hasConversation ? _clearConversation : null,
                tooltip: 'Clear Conversation',
              );
            },
          ),
          // More options
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('View History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'history') {
                Navigator.pushNamed(context, '/history');
              } else if (value == 'settings') {
                // Navigate to settings (implement if needed)
              }
            },
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing AI...'),
                ],
              ),
            )
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: Consumer<AIService>(
                    builder: (context, aiService, _) {
                      if (aiService.conversationHistory.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  aiService.currentPersonality.icon,
                                  style: const TextStyle(fontSize: 64),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Welcome to ${aiService.currentPersonality.displayName} Mode!',
                                  style: AppConstants.headingStyle,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  aiService.currentPersonality.description,
                                  style: AppConstants.bodyStyle.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Start by saying Hi or ask me anything!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppConstants.spacingM),
                        itemCount: aiService.conversationHistory.length,
                        itemBuilder: (context, index) {
                          final message = aiService.conversationHistory[index];
                          return _MessageBubble(
                            message: message,
                            personality: aiService.currentPersonality,
                          );
                        },
                      );
                    },
                  ),
                ),

                // Loading indicator
                Consumer<AIService>(
                  builder: (context, aiService, _) {
                    if (aiService.isLoading) {
                      return Container(
                        padding: const EdgeInsets.all(AppConstants.spacingS),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${aiService.currentPersonality.displayName} is thinking...',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Input field
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingM,
                                vertical: AppConstants.spacingS,
                              ),
                            ),
                            maxLines: null,
                            maxLength: AppConstants.maxMessageLength,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Consumer<AIService>(
                          builder: (context, aiService, _) {
                            return FloatingActionButton(
                              onPressed: aiService.isLoading ? null : _sendMessage,
                              backgroundColor: aiService.isLoading 
                                  ? Colors.grey 
                                  : AppConstants.primaryColor,
                              mini: true,
                              child: const Icon(Icons.send, color: Colors.white),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ========== Message Bubble Widget ==========
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final AIPersonality personality;

  const _MessageBubble({
    required this.message,
    required this.personality,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isError = message.isError;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
        padding: const EdgeInsets.all(AppConstants.spacingM),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isError
              ? AppConstants.errorColor.withOpacity(0.1)
              : isUser
                  ? AppConstants.primaryColor
                  : personality == AIPersonality.tutor
                      ? AppConstants.tutorLightColor
                      : AppConstants.classmateLightColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: isError
              ? Border.all(color: AppConstants.errorColor, width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isError)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      'Error',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isUser ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ========== Personality Option Widget ==========
class _PersonalityOption extends StatelessWidget {
  final AIPersonality personality;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonalityOption({
    required this.personality,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusM),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppConstants.primaryColor : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          color: isSelected ? AppConstants.primaryColor.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Text(
              personality.icon,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personality.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    personality.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppConstants.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}