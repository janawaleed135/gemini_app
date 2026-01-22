import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/ai_service.dart';
import '../../core/enums/ai_personality.dart';
import '../../data/models/chat_message.dart';

/// Main chat interface for interacting with AI Tutor/Classmate
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==========================================
  // INITIALIZATION
  // ==========================================

  Future<void> _initializeAI() async {
    final aiService = Provider.of<AIService>(context, listen: false);

    try {
      await aiService.initialize('YOUR_NEW_API_KEY_HERE');
      setState(() {
        _isInitialized = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI ${aiService.currentPersonality.displayName} ready! 🎉'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize AI: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ==========================================
  // MESSAGE HANDLING
  // ==========================================

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final aiService = Provider.of<AIService>(context, listen: false);

    // Clear input field immediately
    _messageController.clear();

    try {
      await aiService.sendMessage(text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================
  // PERSONALITY SWITCHING
  // ==========================================

  Future<void> _showPersonalityMenu() async {
    final aiService = Provider.of<AIService>(context, listen: false);
    final currentPersonality = aiService.currentPersonality;

    final result = await showDialog<AIPersonality>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose AI Personality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AIPersonality.values.map((personality) {
            final isSelected = personality == currentPersonality;
            return ListTile(
              leading: Text(personality.icon, style: const TextStyle(fontSize: 24)),
              title: Text(personality.displayName),
              subtitle: Text(personality.description),
              selected: isSelected,
              selectedTileColor: Colors.purple.withOpacity(0.1),
              onTap: () => Navigator.pop(context, personality),
            );
          }).toList(),
        ),
      ),
    );

    if (result != null && result != currentPersonality) {
      await aiService.switchPersonality(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${result.displayName} mode! ${result.icon}'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    }
  }

  // ==========================================
  // CLEAR CONVERSATION
  // ==========================================

  Future<void> _showClearConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation?'),
        content: const Text('This will delete all messages in this chat. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final aiService = Provider.of<AIService>(context, listen: false);
      await aiService.clearConversation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation cleared'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // ==========================================
  // UI BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Consumer<AIService>(
        builder: (context, aiService, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(aiService.currentPersonality.icon),
              const SizedBox(width: 8),
              Text('AI ${aiService.currentPersonality.displayName}'),
            ],
          );
        },
      ),
      backgroundColor: Colors.purple,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.swap_horiz),
          onPressed: _showPersonalityMenu,
          tooltip: 'Switch Personality',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _showClearConfirmation,
          tooltip: 'Clear Chat',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing AI...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Consumer<AIService>(
            builder: (context, aiService, child) {
              if (aiService.conversationHistory.isEmpty) {
                return _buildWelcomeScreen(aiService);
              }
              return _buildMessageList(aiService);
            },
          ),
        ),
        _buildLoadingIndicator(),
        _buildInputField(),
      ],
    );
  }

  Widget _buildWelcomeScreen(AIService aiService) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              aiService.currentPersonality.icon,
              style: const TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 24),
            Text(
              'AI ${aiService.currentPersonality.displayName}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              aiService.currentPersonality.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              aiService.currentPersonality.welcomeMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'Type a message below to start! 👇',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(AIService aiService) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: aiService.conversationHistory.length,
      itemBuilder: (context, index) {
        final message = aiService.conversationHistory[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.purple : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && message.personality != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.personality!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
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
              message.formattedTime,
              style: TextStyle(
                fontSize: 10,
                color: isUser ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Consumer<AIService>(
      builder: (context, aiService, child) {
        if (!aiService.isLoading) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                '${aiService.currentPersonality.displayName} is typing...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Consumer<AIService>(
            builder: (context, aiService, child) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.purple,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: aiService.isLoading ? null : _sendMessage,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}