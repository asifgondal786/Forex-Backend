import 'dart:async';
import 'dart:html' as html;

import 'voice_assistant_service.dart';

class _WebVoiceAssistantService implements VoiceAssistantService {
  html.SpeechRecognition? _activeRecognition;
  Completer<String?>? _recognitionCompleter;
  Timer? _recognitionTimeoutTimer;
  StreamSubscription<html.SpeechRecognitionEvent>? _recognitionResultSub;
  StreamSubscription<html.SpeechRecognitionError>? _recognitionErrorSub;
  StreamSubscription<html.Event>? _recognitionEndSub;
  bool _isListening = false;

  @override
  bool get supported => html.window.speechSynthesis != null;

  @override
  bool get supportsSpeechRecognition {
    try {
      return html.SpeechRecognition.supported;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isListening => _isListening;

  @override
  Future<void> speak(
    String text, {
    String locale = 'en-US',
  }) async {
    final payload = text.trim();
    if (payload.isEmpty) {
      return;
    }

    final synth = html.window.speechSynthesis;
    if (synth == null) {
      return;
    }

    // Keep first speak attempt in the same user-gesture stack.
    _resumeSynth(synth);

    try {
      final initialVoice = _selectBestVoice(synth.getVoices(), locale);
      var started = await _speakAttempt(
        synth: synth,
        payload: payload,
        locale: locale,
        selectedVoice: initialVoice,
      );

      if (!started) {
        final voices = await _readVoicesWithWarmup(synth);
        final selectedVoice = _selectBestVoice(voices, locale);
        final selectedLang = selectedVoice?.lang?.trim() ?? '';
        final retryLocale = selectedLang.isNotEmpty ? selectedLang : locale;

        started = await _speakAttempt(
          synth: synth,
          payload: payload,
          locale: retryLocale,
          selectedVoice: selectedVoice,
        );
      }

      if (!started && locale.toLowerCase() != 'en-us') {
        await _speakAttempt(
          synth: synth,
          payload: payload,
          locale: 'en-US',
          selectedVoice: null,
        );
      }
    } catch (_) {
      // Best-effort speech output.
    }
  }

  @override
  Future<bool> unlockAudio() async {
    final synth = html.window.speechSynthesis;
    if (synth == null) {
      return false;
    }
    try {
      _resumeSynth(synth);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _resumeSynth(html.SpeechSynthesis synth) {
    try {
      synth.resume();
    } catch (_) {
      // Best-effort.
    }
  }

  Future<List<html.SpeechSynthesisVoice>> _readVoicesWithWarmup(
    html.SpeechSynthesis synth,
  ) async {
    var voices = synth.getVoices();
    if (voices.isNotEmpty) {
      return voices;
    }
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      _resumeSynth(synth);
      voices = synth.getVoices();
      if (voices.isNotEmpty) {
        return voices;
      }
    }
    return voices;
  }

  Future<bool> _speakAttempt({
    required html.SpeechSynthesis synth,
    required String payload,
    required String locale,
    html.SpeechSynthesisVoice? selectedVoice,
  }) async {
    bool started = false;
    final utterance = html.SpeechSynthesisUtterance(payload)
      ..lang = locale
      ..volume = 1.0
      ..rate = 0.95
      ..pitch = 1.0;

    if (selectedVoice != null) {
      utterance.voice = selectedVoice;
    }

    final done = Completer<void>();
    final fallback = Timer(
      Duration(
        milliseconds: (payload.length * 70).clamp(1200, 14000).toInt(),
      ),
      () {
        if (!done.isCompleted) {
          done.complete();
        }
      },
    );
    final speakingProbe = Timer(const Duration(milliseconds: 220), () {
      if (!started && synth.speaking == true) {
        started = true;
      }
    });

    final startSub = utterance.onStart.listen((_) {
      started = true;
    });
    final endSub = utterance.onEnd.listen((_) {
      if (!done.isCompleted) {
        done.complete();
      }
    });
    final errorSub = utterance.onError.listen((_) {
      if (!done.isCompleted) {
        done.complete();
      }
    });

    if (synth.pending == true || synth.speaking == true) {
      synth.cancel();
      _resumeSynth(synth);
    }

    synth.speak(utterance);

    try {
      await done.future;
    } finally {
      fallback.cancel();
      speakingProbe.cancel();
      await startSub.cancel();
      await endSub.cancel();
      await errorSub.cancel();
    }

    return started;
  }

  html.SpeechSynthesisVoice? _selectBestVoice(
    List<html.SpeechSynthesisVoice> voices,
    String locale,
  ) {
    if (voices.isEmpty) {
      return null;
    }

    final normalizedLocale = locale.toLowerCase();
    final languageCode = normalizedLocale.split('-').first;

    for (final voice in voices) {
      final lang = (voice.lang ?? '').toLowerCase();
      if (lang == normalizedLocale && (voice.localService ?? false)) {
        return voice;
      }
    }

    for (final voice in voices) {
      final lang = (voice.lang ?? '').toLowerCase();
      if (lang == normalizedLocale) {
        return voice;
      }
    }

    for (final voice in voices) {
      final lang = (voice.lang ?? '').toLowerCase();
      if (lang.startsWith(languageCode) && (voice.localService ?? false)) {
        return voice;
      }
    }

    for (final voice in voices) {
      final lang = (voice.lang ?? '').toLowerCase();
      if (lang.startsWith(languageCode)) {
        return voice;
      }
    }

    for (final voice in voices) {
      if (voice.defaultValue == true) {
        return voice;
      }
    }

    return voices.first;
  }

  @override
  Future<String?> listenOnce({
    String locale = 'en-US',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!supportsSpeechRecognition) {
      return null;
    }

    _stopRecognitionInternal();
    await _ensureMicPermission();

    final completer = Completer<String?>();
    _recognitionCompleter = completer;

    final recognition = html.SpeechRecognition();
    _activeRecognition = recognition;
    _isListening = true;

    recognition.lang = locale;
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;

    void completeAndCleanup(String? transcript) {
      if (!completer.isCompleted) {
        completer.complete(transcript);
      }
      _stopRecognitionInternal();
    }

    _recognitionResultSub = recognition.onResult.listen((event) {
      final results = event.results;
      if (results == null || results.isEmpty) {
        completeAndCleanup(null);
        return;
      }
      final firstResult = results.first;
      final alternativeCount = firstResult.length ?? 0;
      if (alternativeCount == 0) {
        completeAndCleanup(null);
        return;
      }
      final transcript = firstResult.item(0).transcript?.trim();
      completeAndCleanup(
        transcript != null && transcript.isNotEmpty ? transcript : null,
      );
    });
    _recognitionErrorSub = recognition.onError.listen((_) {
      completeAndCleanup(null);
    });
    _recognitionEndSub = recognition.onEnd.listen((_) {
      if (!completer.isCompleted) {
        completeAndCleanup(null);
      }
    });

    _recognitionTimeoutTimer = Timer(timeout, () {
      completeAndCleanup(null);
    });

    try {
      recognition.start();
    } catch (_) {
      _stopRecognitionInternal();
      return null;
    }

    return completer.future;
  }

  Future<void> _ensureMicPermission() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        return;
      }

      final stream = await mediaDevices.getUserMedia(
        <String, dynamic>{'audio': true},
      );
      for (final track in stream.getTracks()) {
        try {
          track.stop();
        } catch (_) {
          // Ignore if already stopped.
        }
      }
    } catch (_) {
      // Permission prime is best-effort.
    }
  }

  @override
  void stop() {
    _stopRecognitionInternal();
    final synth = html.window.speechSynthesis;
    if (synth != null) {
      synth.cancel();
    }
  }

  void _stopRecognitionInternal() {
    _recognitionTimeoutTimer?.cancel();
    _recognitionTimeoutTimer = null;

    final recognition = _activeRecognition;
    if (recognition != null) {
      try {
        recognition.stop();
      } catch (_) {
        // Ignore if already stopped.
      }
    }
    _activeRecognition = null;
    _isListening = false;

    final resultSub = _recognitionResultSub;
    _recognitionResultSub = null;
    if (resultSub != null) {
      unawaited(resultSub.cancel());
    }

    final errorSub = _recognitionErrorSub;
    _recognitionErrorSub = null;
    if (errorSub != null) {
      unawaited(errorSub.cancel());
    }

    final endSub = _recognitionEndSub;
    _recognitionEndSub = null;
    if (endSub != null) {
      unawaited(endSub.cancel());
    }

    final completer = _recognitionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _recognitionCompleter = null;
  }
}

VoiceAssistantService createVoiceAssistantServiceImpl() =>
    _WebVoiceAssistantService();
