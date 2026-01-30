// lib/presentation/screens/slide_viewer_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/slide_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/slide_model.dart';
import '../providers/session_provider.dart';

class SlideViewerScreen extends StatefulWidget {
  const SlideViewerScreen({super.key});

  @override
  State<SlideViewerScreen> createState() => _SlideViewerScreenState();
}

class _SlideViewerScreenState extends State<SlideViewerScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showChat = true;
  bool _isAnalyzing = false;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final aiService = context.read<AIService>();
    if (!aiService.isInitialized) {
      await aiService.initialize();
    }
  }

  Future<void> _pickAndLoadFile() async {
    final slideService = context.read<SlideService>();
    
    final file = await slideService.pickFile();
    if (file != null) {
      final success = await slideService.loadSlideFile(file);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${slideService.totalSlides} slides'),
            backgroundColor: Colors.green,
          ),
        );
        // Analyze the first slide automatically
        _analyzeCurrentSlide();
      } else if (!success && slideService.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(slideService.errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _analyzeCurrentSlide() async {
    final slideService = context.read<SlideService>();
    final aiService = context.read<AIService>();
    
    if (!slideService.hasSlides) return;
    
    final currentSlide = slideService.currentSlide;
    if (currentSlide == null || currentSlide.imageBytes == null) return;
    
    // Skip if already analyzed
    if (currentSlide.isAnalyzed) {
      _updateAIContext();
      return;
    }
    
    setState(() => _isAnalyzing = true);
    
    try {
      final metadata = await aiService.analyzeSlide(
        currentSlide.imageBytes!,
        slideService.currentSlideIndex,
      );
      
      slideService.updateSlideMetadata(slideService.currentSlideIndex, metadata);
      _updateAIContext();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slide analyzed successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _updateAIContext() {
    final slideService = context.read<SlideService>();
    final aiService = context.read<AIService>();
    
    if (slideService.hasSlides) {
      aiService.setSlideContext(
        slideService.currentSlide,
        slideService.currentSlideIndex,
        slideService.totalSlides,
      );
    }
  }

  void _onSlideChanged(int newIndex) {
    final slideService = context.read<SlideService>();
    slideService.goToSlide(newIndex);
    _analyzeCurrentSlide();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    _focusNode.requestFocus();
    
    final aiService = context.read<AIService>();
    final slideService = context.read<SlideService>();
    
    try {
      // Get current slide image for Vision API
      Uint8List? slideImage;
      if (slideService.hasSlides && slideService.currentSlide?.imageBytes != null) {
        slideImage = slideService.currentSlide!.imageBytes;
      }
      
      await aiService.sendSlideAwareMessage(text, slideImage);
      _scrollChatToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  void _sendQuickAction(String action) {
    _messageController.text = action;
    _sendMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Consumer<SlideService>(
        builder: (context, slideService, _) {
          if (slideService.hasSlides) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slideService.currentSlideModel!.fileName,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Slide ${slideService.currentSlideIndex + 1} of ${slideService.totalSlides}',
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
        // Toggle chat panel
        IconButton(
          icon: Icon(_showChat ? Icons.chat_bubble : Icons.chat_bubble_outline),
          onPressed: () => setState(() => _showChat = !_showChat),
          tooltip: 'Toggle Chat',
        ),
        // Analyze current slide
        Consumer<SlideService>(
          builder: (context, slideService, _) {
            return IconButton(
              icon: _isAnalyzing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              onPressed: slideService.hasSlides && !_isAnalyzing 
                  ? _analyzeCurrentSlide 
                  : null,
              tooltip: 'Analyze Slide',
            );
          },
        ),
        // Clear slides
        Consumer<SlideService>(
          builder: (context, slideService, _) {
            return IconButton(
              icon: const Icon(Icons.close),
              onPressed: slideService.hasSlides 
                  ? () {
                      slideService.clearSlides();
                      context.read<AIService>().clearSlideContext();
                    }
                  : null,
              tooltip: 'Close Slides',
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<SlideService>(
      builder: (context, slideService, _) {
        if (slideService.isLoading || slideService.isProcessing) {
          return _buildLoadingView(slideService);
        }
        
        if (!slideService.hasSlides) {
          return _buildUploadView();
        }
        
        return _buildSlideViewerWithChat(slideService);
      },
    );
  }

  Widget _buildLoadingView(SlideService slideService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Processing slides...',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (slideService.processingProgress > 0)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: LinearProgressIndicator(
                value: slideService.processingProgress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.upload_file,
                size: 80,
                color: Colors.deepPurple.shade300,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload Your Slides',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Support for PDF files up to 50MB',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndLoadFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 48),
            _buildFeaturesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Column(
      children: [
        _buildFeatureRow(Icons.visibility, 'AI analyzes slide content'),
        const SizedBox(height: 12),
        _buildFeatureRow(Icons.chat, 'Ask questions about any slide'),
        const SizedBox(height: 12),
        _buildFeatureRow(Icons.lightbulb, 'Get smart explanations'),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.deepPurple.shade300, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildSlideViewerWithChat(SlideService slideService) {
    return Row(
      children: [
        // Slide Viewer Panel
        Expanded(
          flex: _showChat ? 3 : 5,
          child: Column(
            children: [
              // Main slide display
              Expanded(
                child: _buildSlideDisplay(slideService),
              ),
              // Thumbnail strip
              _buildThumbnailStrip(slideService),
              // Navigation controls
              _buildNavigationControls(slideService),
            ],
          ),
        ),
        // Chat Panel
        if (_showChat)
          Container(
            width: 400,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: _buildChatPanel(),
          ),
      ],
    );
  }

  Widget _buildSlideDisplay(SlideService slideService) {
    final currentSlide = slideService.currentSlide;
    
    if (currentSlide == null || currentSlide.imageBytes == null) {
      return const Center(child: Text('No slide to display'));
    }
    
    return GestureDetector(
      onDoubleTap: () {
        setState(() {
          _zoomLevel = _zoomLevel == 1.0 ? 2.0 : 1.0;
        });
      },
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Transform.scale(
            scale: _zoomLevel,
            child: Image.memory(
              currentSlide.imageBytes!,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip(SlideService slideService) {
    return Container(
      height: 100,
      color: Colors.grey.shade100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: slideService.totalSlides,
        itemBuilder: (context, index) {
          final isSelected = index == slideService.currentSlideIndex;
          final slide = slideService.currentSlideModel!.slides[index];
          
          return GestureDetector(
            onTap: () => _onSlideChanged(index),
            child: Container(
              width: 80,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                  width: isSelected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  if (slide.imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.memory(
                        slide.imageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  else
                    const Center(child: Icon(Icons.image, color: Colors.grey)),
                  // Slide number badge
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                  // Analyzed indicator
                  if (slide.isAnalyzed)
                    const Positioned(
                      left: 4,
                      top: 4,
                      child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavigationControls(SlideService slideService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: slideService.currentSlideIndex > 0
                ? () => _onSlideChanged(0)
                : null,
            tooltip: 'First Slide',
          ),
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: slideService.currentSlideIndex > 0
                ? () => _onSlideChanged(slideService.currentSlideIndex - 1)
                : null,
            tooltip: 'Previous Slide',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${slideService.currentSlideIndex + 1} / ${slideService.totalSlides}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: slideService.currentSlideIndex < slideService.totalSlides - 1
                ? () => _onSlideChanged(slideService.currentSlideIndex + 1)
                : null,
            tooltip: 'Next Slide',
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: slideService.currentSlideIndex < slideService.totalSlides - 1
                ? () => _onSlideChanged(slideService.totalSlides - 1)
                : null,
            tooltip: 'Last Slide',
          ),
          const SizedBox(width: 16),
          // Zoom controls
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomLevel > 0.5
                ? () => setState(() => _zoomLevel -= 0.25)
                : null,
            tooltip: 'Zoom Out',
          ),
          Text('${(_zoomLevel * 100).toInt()}%'),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomLevel < 4.0
                ? () => setState(() => _zoomLevel += 0.25)
                : null,
            tooltip: 'Zoom In',
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.deepPurple.shade50,
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Tutor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Ask about this slide',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Consumer<AIService>(
                builder: (context, aiService, _) {
                  if (aiService.hasSlideContext) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '✓ Slide Context',
                        style: TextStyle(fontSize: 10, color: Colors.green),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        // Quick actions
        _buildQuickActions(),
        // Chat messages
        Expanded(
          child: Consumer<AIService>(
            builder: (context, aiService, _) {
              if (aiService.conversationHistory.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ask me anything about this slide!',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(8),
                itemCount: aiService.conversationHistory.length,
                itemBuilder: (context, index) {
                  final message = aiService.conversationHistory[index];
                  return _buildMessageBubble(message);
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
                padding: const EdgeInsets.all(8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Thinking...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        // Input field
        _buildChatInput(),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: [
          _buildQuickActionChip('Explain this slide'),
          _buildQuickActionChip('What does this mean?'),
          _buildQuickActionChip('Give me examples'),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => _sendQuickAction(label),
      backgroundColor: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepPurple : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(8),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Ask about this slide...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Consumer<AIService>(
            builder: (context, aiService, _) {
              return FloatingActionButton.small(
                onPressed: aiService.isLoading ? null : _sendMessage,
                backgroundColor: Colors.deepPurple,
                child: const Icon(Icons.send, color: Colors.white),
              );
            },
          ),
        ],
      ),
    );
  }
}
