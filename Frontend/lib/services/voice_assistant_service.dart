import 'voice_assistant_service_impl.dart'
    if (dart.library.html) 'voice_assistant_service_web.dart';

abstract class VoiceAssistantService {
  bool get supported;
  bool get supportsSpeechRecognition;
  bool get isListening;

  Future<void> speak(
    String text, {
    String locale = 'en-US',
  });

  Future<String?> listenOnce({
    String locale = 'en-US',
    Duration timeout = const Duration(seconds: 10),
  });

  Future<bool> unlockAudio();

  void stop();
}

VoiceAssistantService createVoiceAssistantService() =>
    createVoiceAssistantServiceImpl();
