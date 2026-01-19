import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/ai_service.dart';
import '../../core/enums/ai_personality.dart';
import '../../data/models/chat_message.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

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

  Future<void> _initializeAI() async {
    final aiService = context.read<AIService>();
    
    if (!aiService.isInitialized) {
      try {
        // 🔑 REPLACE WITH YOUR ACTUAL GEMINI API KEY
        // Get it from: https://ai.google.dev/
        await aiService.initialize('AIzaSyBraEU-pRu1A8fdmwvW1rH5bbP_QnV3K9E');
        
        setState(() {
          _isInitialized = true;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to initialize AI: $e')),
          );
        }
      }
    } else {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final aiService = context.read<AIService>();

    try {
      await aiService.sendMessage(text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<AIService>(
          builder: (context, aiService, _) {
            return Text(
              '${aiService.currentPersonality.icon} ${aiService.currentPersonality.displayName} Mode',
            );
          },
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Personality switch button
          Consumer<AIService>(
            builder: (context, aiService, _) {
              return PopupMenuButton<AIPersonality>(
                icon: const Icon(Icons.swap_horiz),
                onSelected: (personality) {
                  aiService.switchPersonality(personality);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: AIPersonality.tutor,
                    child: Text('${AIPersonality.tutor.icon} Tutor'),
                  ),
                  PopupMenuItem(
                    value: AIPersonality.classmate,
                    child: Text('${AIPersonality.classmate.icon} Classmate'),
                  ),
                ],
              );
            },
          ),
          // Clear conversation
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<AIService>().clearConversation();
            },
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: Consumer<AIService>(
                    builder: (context, aiService, _) {
                      if (aiService.conversationHistory.isEmpty) {
                        return Center(
                          child: Text(
                            'Start a conversation with your ${aiService.currentPersonality.displayName}!',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: aiService.conversationHistory.length,
                        itemBuilder: (context, index) {
                          final message = aiService.conversationHistory[index];
                          return _MessageBubble(message: message);
                        },
                      );
                    },
                  ),
                ),

                // Loading indicator
                Consumer<AIService>(
                  builder: (context, aiService, _) {
                    if (aiService.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Input field
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type your message...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.deepPurple : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: message.isUser ? Colors.white70 : Colors.black54,
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