import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/voice_service.dart';
import '../../core/enums/voice_state.dart';

class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen({super.key});

  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎤 Voice Service Test'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Consumer<VoiceService>(
        builder: (context, voiceService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ========== Status Card ==========
                Card(
                  color: _getStatusColor(voiceService.state),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Status: ${voiceService.state.name.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (voiceService.state == VoiceState.listening) ...[
                          const SizedBox(height: 8),
                          const CircularProgressIndicator(color: Colors.white),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ========== Error Display ==========
                if (voiceService.errorMessage.isNotEmpty)
                  Card(
                    color: Colors.red.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              voiceService.errorMessage,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: voiceService.clearError,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // ========== STT Section ==========
                const Text(
                  '🎤 Speech-to-Text',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minHeight: 100),
                  child: Text(
                    voiceService.lastRecognizedText.isEmpty
                        ? 'Tap microphone to start...'
                        : voiceService.lastRecognizedText,
                    style: TextStyle(
                      fontSize: 16,
                      color: voiceService.lastRecognizedText.isEmpty
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: voiceService.isListening
                          ? null
                          : () => voiceService.startListening(),
                      icon: const Icon(Icons.mic),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: voiceService.isListening
                          ? () => voiceService.stopListening()
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ========== TTS Section ==========
                const Text(
                  '🔊 Text-to-Speech',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Enter text to speak...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: voiceService.isSpeaking
                          ? null
                          : () {
                              if (_textController.text.isNotEmpty) {
                                voiceService.speak(_textController.text);
                              }
                            },
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Speak'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: voiceService.isSpeaking
                          ? () => voiceService.stopSpeaking()
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ========== Quick Test ==========
                ElevatedButton(
                  onPressed: () => voiceService.speak(
                    'Hello! This is a test of the text to speech system.',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('Quick TTS Test'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(VoiceState state) {
    switch (state) {
      case VoiceState.idle:
        return Colors.grey;
      case VoiceState.listening:
        return Colors.green;
      case VoiceState.speaking:
        return Colors.blue;
      case VoiceState.error:
        return Colors.red;
    }
  }
}