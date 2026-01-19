import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../enums/voice_state.dart';

/// Service that handles Text-to-Speech and Speech-to-Text operations
/// Follows Clean Architecture - this is a domain service
class VoiceService extends ChangeNotifier {
  // ========== Dependencies ==========
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // ========== State ==========
  VoiceState _state = VoiceState.idle;
  String _lastRecognizedText = '';
  String _errorMessage = '';
  bool _isInitialized = false;

  // ========== Getters ==========
  VoiceState get state => _state;
  String get lastRecognizedText => _lastRecognizedText;
  String get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  bool get isListening => _state == VoiceState.listening;
  bool get isSpeaking => _state == VoiceState.speaking;

  // ========== Constructor ==========
  VoiceService() {
    _initializeTts();
  }

  // ========== TTS Initialization ==========
  /// Initialize Text-to-Speech with default settings
  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5); // Normal speed
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set up TTS callbacks to track state
      _flutterTts.setStartHandler(() {
        _state = VoiceState.speaking;
        notifyListeners();
      });

      _flutterTts.setCompletionHandler(() {
        _state = VoiceState.idle;
        notifyListeners();
      });

      _flutterTts.setErrorHandler((msg) {
        _errorMessage = 'TTS Error: $msg';
        _state = VoiceState.error;
        notifyListeners();
      });

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize TTS: $e';
      _state = VoiceState.error;
      notifyListeners();
    }
  }

  // ========== Permission Management ==========
  /// Request microphone permission for Speech-to-Text
  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    
    if (status.isDenied || status.isPermanentlyDenied) {
      _errorMessage = 'Microphone permission denied. Please enable it in settings.';
      _state = VoiceState.error;
      notifyListeners();
      return false;
    }
    
    return true;
  }

  // ========== STT Initialization ==========
  /// Initialize Speech-to-Text with permission handling
  Future<bool> _initializeSpeechToText() async {
    try {
      // Check and request permission
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) return false;

      // Initialize STT
      bool available = await _speechToText.initialize(
        onStatus: (status) {
          if (kDebugMode) {
            print('🎤 STT Status: $status');
          }
          
          if (status == 'done' || status == 'notListening') {
            if (_state == VoiceState.listening) {
              _state = VoiceState.idle;
              notifyListeners();
            }
          }
        },
        onError: (errorNotification) {
          _errorMessage = 'STT Error: ${errorNotification.errorMsg}';
          _state = VoiceState.error;
          notifyListeners();
        },
      );

      if (!available) {
        _errorMessage = 'Speech recognition not available on this device';
        _state = VoiceState.error;
        notifyListeners();
      }

      return available;
    } catch (e) {
      _errorMessage = 'Failed to initialize STT: $e';
      _state = VoiceState.error;
      notifyListeners();
      return false;
    }
  }

  // ========== Public API - STT ==========
  /// Start listening to user's speech
  /// [onResult] callback is triggered with recognized text
  Future<void> startListening({Function(String)? onResult}) async {
    // Prevent multiple listening sessions
    if (_state == VoiceState.listening) {
      if (kDebugMode) {
        print('⚠️ Already listening');
      }
      return;
    }

    // Stop speaking if currently active
    if (_state == VoiceState.speaking) {
      await stopSpeaking();
    }

    // Initialize STT if not already done
    if (!_speechToText.isAvailable) {
      final initialized = await _initializeSpeechToText();
      if (!initialized) return;
    }

    // Reset state
    _lastRecognizedText = '';
    _errorMessage = '';
    _state = VoiceState.listening;
    notifyListeners();

    // Start listening
    await _speechToText.listen(
      onResult: (result) {
        _lastRecognizedText = result.recognizedWords;
        
        // Trigger callback if provided
        if (onResult != null) {
          onResult(_lastRecognizedText);
        }
        
        notifyListeners();
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true, // Get real-time partial results
      ),
    );
  }

  /// Stop listening to speech input
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    
    if (_state == VoiceState.listening) {
      _state = VoiceState.idle;
      notifyListeners();
    }
  }

  // ========== Public API - TTS ==========
  /// Speak the given text using Text-to-Speech
  Future<void> speak(String text) async {
    if (text.isEmpty) {
      _errorMessage = 'Cannot speak empty text';
      return;
    }

    // Stop listening if currently active
    if (_state == VoiceState.listening) {
      await stopListening();
    }

    _errorMessage = '';
    _state = VoiceState.speaking;
    notifyListeners();

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      _errorMessage = 'Failed to speak: $e';
      _state = VoiceState.error;
      notifyListeners();
    }
  }

  /// Stop speaking immediately
  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    
    if (_state == VoiceState.speaking) {
      _state = VoiceState.idle;
      notifyListeners();
    }
  }

  // ========== Error Management ==========
  /// Clear error state
  void clearError() {
    _errorMessage = '';
    if (_state == VoiceState.error) {
      _state = VoiceState.idle;
    }
    notifyListeners();
  }

  // ========== Cleanup ==========
  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }
}