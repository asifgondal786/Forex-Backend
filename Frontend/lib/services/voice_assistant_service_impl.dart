import 'voice_assistant_service.dart';

class _NoopVoiceAssistantService implements VoiceAssistantService {
  @override
  bool get supported => false;

  @override
  bool get supportsSpeechRecognition => false;

  @override
  bool get isListening => false;

  @override
  Future<void> speak(
    String text, {
    String locale = 'en-US',
  }) async {}

  @override
  Future<String?> listenOnce({
    String locale = 'en-US',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return null;
  }

  @override
  Future<bool> unlockAudio() async {
    return false;
  }

  @override
  void stop() {}
}

VoiceAssistantService createVoiceAssistantServiceImpl() =>
    _NoopVoiceAssistantService();
