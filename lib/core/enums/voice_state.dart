/// Enum representing the current state of the voice service
enum VoiceState {
  /// Service is idle and not performing any action
  idle,
  
  /// Service is actively listening to user speech
  listening,
  
  /// Service is speaking (Text-to-Speech is active)
  speaking,
  
  /// Service encountered an error
  error,
}