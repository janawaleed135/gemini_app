// lib/presentation/screens/slide_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/services/slide_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/notes_service.dart';

class SlideViewerScreen extends StatefulWidget {
  const SlideViewerScreen({super.key});

  @override
  State<SlideViewerScreen> createState() => _SlideViewerScreenState();
}

class _SlideViewerScreenState extends State<SlideViewerScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();
  
  bool _showChat = true;
  bool _showNotesPanel = false;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AIService>().initialize();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _noteController.dispose();
    _chatScrollController.dispose();
    _messageFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAndLoadFile() async {
    final slideService = context.read<SlideService>();
    final aiService = context.read<AIService>();
    final notesService = context.read<NotesService>();
    
    // 1. Pick File
    final success = await slideService.pickFile();
    
    // 2. Load into AI if successful
    if (success && slideService.rawFileBytes != null) {
      // Set current document for notes
      final docId = slideService.currentSlideModel!.id;
      notesService.setCurrentDocument(docId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📚 Analyzing document... This may take a moment.'),
            backgroundColor: Colors.deepPurple,
            duration: Duration(seconds: 3),
          ),
        );
      }

      await aiService.loadDocument(
        slideService.currentSlideModel!.fileName,
        slideService.rawFileBytes!,
        'application/pdf', 
      );
      
      // Show notes panel after loading
      setState(() {
        _showNotesPanel = true;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    
    final aiService = context.read<AIService>();
    final slideService = context.read<SlideService>();
    
    await aiService.sendMessage(
      text, 
      currentPage: slideService.currentSlideIndex
    );
    
    _scrollChatToBottom();
  }

  void _scrollChatToBottom() {
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

  void _loadNoteForCurrentSlide() {
    final slideService = context.read<SlideService>();
    final notesService = context.read<NotesService>();
    
    final note = notesService.getNoteForSlide(slideService.currentSlideIndex);
    _noteController.text = note ?? '';
  }

  Future<void> _saveNoteForCurrentSlide() async {
    final slideService = context.read<SlideService>();
    final notesService = context.read<NotesService>();
    
    await notesService.saveNoteForSlide(
      slideService.currentSlideIndex,
      _noteController.text,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Note saved!'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<SlideService>(
          builder: (context, slideService, _) {
            if (slideService.hasSlides) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slideService.currentSlideModel!.fileName, style: const TextStyle(fontSize: 16)),
                  Text(
                    'Page ${slideService.currentSlideIndex + 1} of ${slideService.totalSlides}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              );
            }
            return const Text('Slide Learning');
          },
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Notes panel toggle
          Consumer<NotesService>(
            builder: (context, notesService, _) {
              final notesCount = notesService.getNotesCount();
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(_showNotesPanel ? Icons.note : Icons.note_outlined),
                    onPressed: () => setState(() => _showNotesPanel = !_showNotesPanel),
                  ),
                  if (notesCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          notesCount.toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(_showChat ? Icons.chat_bubble : Icons.chat_bubble_outline),
            onPressed: () => setState(() => _showChat = !_showChat),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
               context.read<SlideService>().clearSlides();
               context.read<AIService>().clearConversation();
            },
          ),
        ],
      ),
      body: Consumer<SlideService>(
        builder: (context, slideService, _) {
          if (slideService.isLoading) return _buildLoading();
          if (!slideService.hasSlides) return _buildUploadView();
          return _buildMainView(slideService);
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Processing document..."),
        ],
      ),
    );
  }

  Widget _buildUploadView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload_file, size: 80, color: Colors.deepPurple.shade200),
          const SizedBox(height: 20),
          const Text("Upload a PDF to start learning", style: TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickAndLoadFile,
            icon: const Icon(Icons.folder_open),
            label: const Text("Select PDF File"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMainView(SlideService slideService) {
    // Update note controller when slide changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNoteForCurrentSlide();
    });
    
    return Row(
      children: [
        // LEFT: Notes Panel (if shown)
        if (_showNotesPanel) _buildNotesPanel(),
        
        // CENTER: Slides
        Expanded(
          flex: _showChat ? 3 : 5,
          child: _buildSlideViewer(slideService),
        ),
        
        // RIGHT: Chat
        if (_showChat) _buildChatPanel(),
      ],
    );
  }

  Widget _buildNotesPanel() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.book, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Notes & Definitions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showNotesPanel = false),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: Consumer<AIService>(
              builder: (context, aiService, _) {
                if (!aiService.hasDocumentLoaded) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Upload a document to see AI-generated notes and definitions',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI Notes Section
                      if (aiService.documentNotes.isNotEmpty) ...[
                        const Row(
                          children: [
                            Icon(Icons.notes, size: 18, color: Colors.deepPurple),
                            SizedBox(width: 8),
                            Text(
                              'Comprehensive Notes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SelectableText(
                            aiService.documentNotes,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Definitions Section
                      if (aiService.definitions.isNotEmpty) ...[
                        const Row(
                          children: [
                            Icon(Icons.auto_stories, size: 18, color: Colors.deepPurple),
                            SizedBox(width: 8),
                            Text(
                              'Key Definitions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...aiService.definitions.entries.map((entry) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  entry.value,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideViewer(SlideService slideService) {
    return Column(
      children: [
        // Main slide view
        Expanded(
          child: GestureDetector(
            onDoubleTap: () => setState(() => _zoomLevel = _zoomLevel == 1.0 ? 2.0 : 1.0),
            child: InteractiveViewer(
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Transform.scale(
                  scale: _zoomLevel,
                  child: Image.memory(
                    slideService.currentSlide!.imageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Student Notes for current slide
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Consumer<SlideService>(
                    builder: (context, ss, _) {
                      return Text(
                        'My Notes - Slide ${ss.currentSlideIndex + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      );
                    },
                  ),
                  const Spacer(),
                  Consumer<NotesService>(
                    builder: (context, notesService, _) {
                      return notesService.hasNoteForSlide(slideService.currentSlideIndex)
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                          : const Icon(Icons.circle_outlined, color: Colors.grey, size: 18);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                focusNode: _noteFocusNode,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add your notes for this slide...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(8),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save, color: Colors.deepPurple),
                    onPressed: _saveNoteForCurrentSlide,
                  ),
                ),
                onChanged: (_) {
                  // Auto-save after 2 seconds of inactivity
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && _noteFocusNode.hasFocus) {
                      _saveNoteForCurrentSlide();
                    }
                  });
                },
              ),
            ],
          ),
        ),
        
        // Thumbnails
        SizedBox(
          height: 80,
          child: Consumer<NotesService>(
            builder: (context, notesService, _) {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: slideService.totalSlides,
                itemBuilder: (context, index) {
                  final isSelected = index == slideService.currentSlideIndex;
                  final hasNote = notesService.hasNoteForSlide(index);
                  
                  return GestureDetector(
                    onTap: () => slideService.goToSlide(index),
                    child: Stack(
                      children: [
                        Container(
                          width: 60,
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: isSelected 
                                ? Border.all(color: Colors.deepPurple, width: 2)
                                : null,
                          ),
                          child: Image.memory(
                            slideService.currentSlideModel!.slides[index].imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (hasNote)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.note,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel() {
    return Container(
      width: 350,
      decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade300))),
      child: Column(
        children: [
          Expanded(
            child: Consumer<AIService>(
              builder: (context, ai, _) {
                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: ai.conversationHistory.length,
                  itemBuilder: (context, index) {
                    final msg = ai.conversationHistory[index];
                    final isUser = msg.isUser;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.deepPurple.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUser ? "You" : (msg.personality ?? "AI"),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          MarkdownBody(
                            data: msg.content,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                              tableBorder: TableBorder.all(color: Colors.grey),
                              tableHeadAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input with Enter key support
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _sendMessage();
                      }
                    },
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: "Ask about this page... (Enter to send)",
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}