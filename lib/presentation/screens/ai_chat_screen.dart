// lib/presentation/screens/ai_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/slide_service.dart';
import '../../core/services/notes_service.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/chat_message.dart';
import '../../core/enums/ai_personality.dart';
import '../providers/session_provider.dart'; // Ensure this is imported

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  
  bool _showAiNotes = false;

  @override
  void initState() {
    super.initState();
    // Initialize AI Service on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AIService>().initialize();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _noteController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // --- Helper Methods ---

  Future<void> _handleFileUpload() async {
    final slideService = context.read<SlideService>();
    final aiService = context.read<AIService>();
    final notesService = context.read<NotesService>();

    final success = await slideService.pickFile();

    if (success && slideService.rawFileBytes != null) {
      notesService.setCurrentDocument(slideService.currentSlideModel!.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📚 AI is analyzing the full document...')),
      );

      await aiService.loadDocument(
        slideService.currentSlideModel?.fileName ?? "Document.pdf",
        slideService.rawFileBytes!,
        'application/pdf',
      );
      
      setState(() => _showAiNotes = true);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final slideService = context.read<SlideService>();
    context.read<AIService>().sendMessage(
      text, 
      currentPage: slideService.hasSlides ? slideService.currentSlideIndex : null
    );
    
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showStartSessionDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Study Session"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "What are we studying today?"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              context.read<SessionProvider>().startNewSession(controller.text, "StudentUser");
              Navigator.pop(context);
            },
            child: const Text("Start"),
          ),
        ],
      ),
    );
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final slideService = context.watch<SlideService>();
    final aiService = context.watch<AIService>();
    final notesService = context.watch<NotesService>();
    final sessionProvider = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Study Workspace'),
        backgroundColor: AppConstants.primaryColor,
        actions: [
          // Session Controls
          if (!sessionProvider.hasActiveSession)
            TextButton.icon(
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text("Start Session", style: TextStyle(color: Colors.white)),
              onPressed: () => _showStartSessionDialog(context),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.stop, color: Colors.redAccent),
              label: const Text("End Session", style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await sessionProvider.endSession();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Session saved to history!"))
                );
              },
            ),
          // Personality Switch
          IconButton(
            tooltip: "Switch Personality",
            icon: Icon(aiService.currentPersonality == AIPersonality.tutor ? Icons.school : Icons.face),
            onPressed: () {
              final newP = aiService.currentPersonality == AIPersonality.tutor 
                  ? AIPersonality.classmate : AIPersonality.tutor;
              aiService.switchPersonality(newP);
            },
          ),
          IconButton(
            icon: Icon(_showAiNotes ? Icons.auto_stories : Icons.auto_stories_outlined),
            onPressed: () => setState(() => _showAiNotes = !_showAiNotes),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => aiService.clearConversation(),
          )
        ],
      ),
      body: Row(
        children: [
          if (_showAiNotes) _buildAiNotesSidebar(aiService),
          Expanded(
            flex: 3,
            child: slideService.hasSlides 
                ? _buildDocumentWorkspace(slideService, notesService) 
                : _buildUploadPlaceholder(),
          ),
          _buildChatSidebar(aiService),
        ],
      ),
    );
  }

  Widget _buildAiNotesSidebar(AIService ai) {
    return Container(
      width: 250,
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AI SUMMARY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Divider(),
            Text(ai.documentNotes.isEmpty ? "No notes yet." : ai.documentNotes),
            const SizedBox(height: 20),
            const Text("DEFINITIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Divider(),
            ...ai.definitions.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text("• ${e.key}: ${e.value}", style: const TextStyle(fontSize: 12)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentWorkspace(SlideService ss, NotesService ns) {
    _noteController.text = ns.getNoteForSlide(ss.currentSlideIndex) ?? '';
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            child: Image.memory(ss.currentSlide!.imageBytes!, fit: BoxFit.contain),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.amber.shade50,
          child: TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: "My notes for page ${ss.currentSlideIndex + 1}...",
              suffixIcon: IconButton(
                icon: const Icon(Icons.save), 
                onPressed: () => ns.saveNoteForSlide(ss.currentSlideIndex, _noteController.text)
              ),
            ),
          ),
        ),
        _buildThumbnailBar(ss),
      ],
    );
  }

  Widget _buildThumbnailBar(SlideService ss) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ss.totalSlides,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => ss.goToSlide(index),
          child: Container(
            width: 40,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(border: Border.all(color: ss.currentSlideIndex == index ? Colors.blue : Colors.grey)),
            child: Image.memory(ss.currentSlideModel!.slides[index].imageBytes!, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _buildChatSidebar(AIService ai) {
    return Container(
      width: 300,
      decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade300))),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              itemCount: ai.conversationHistory.length,
              itemBuilder: (context, index) => _ChatBubble(message: ai.conversationHistory[index]),
            ),
          ),
          if (ai.isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.attach_file), onPressed: _handleFileUpload),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(hintText: "Ask anything about the PDF..."),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Center(
      child: ElevatedButton(onPressed: _handleFileUpload, child: const Text("Upload PDF to Start")),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepPurple.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
        ),
        child: MarkdownBody(
          data: message.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            // High-visibility bold and formatted tables
            strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 15),
            tableBorder: TableBorder.all(color: Colors.grey.shade400, width: 1),
            tableCellsPadding: const EdgeInsets.all(8),
            tableHead: const TextStyle(fontWeight: FontWeight.bold),
            p: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            h1: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            code: TextStyle(backgroundColor: Colors.grey.shade100, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}