import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'voice_assistant_service.dart';

class _WebVoiceAssistantService implements VoiceAssistantService {
  web.SpeechRecognition? _activeRecognition;
  Completer<String?>? _recognitionCompleter;
  Timer? _recognitionTimeoutTimer;
  JSFunction? _onResultJs;
  JSFunction? _onErrorJs;
  JSFunction? _onEndJs;
  bool _isListening = false;

  @override
  bool get supported => true;

  @override
  bool get supportsSpeechRecognition {
    try {
      web.SpeechRecognition();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isListening => _isListening;

  // ── Speak ──────────────────────────────────────────────────────────────────

  @override
  Future<void> speak(
    String text, {
    String locale = 'en-US',
  }) async {
    final payload = text.trim();
    if (payload.isEmpty) return;

    final synth = web.window.speechSynthesis;
    _resumeSynth(synth);

    try {
      final initialVoice = _selectBestVoice(
        _voiceList(synth.getVoices()),
        locale,
      );
      var started = await _speakAttempt(
        synth: synth,
        payload: payload,
        locale: locale,
        selectedVoice: initialVoice,
      );

      if (!started) {
        final voices = await _readVoicesWithWarmup(synth);
        final selectedVoice = _selectBestVoice(voices, locale);
        final retryLocale =
            (selectedVoice?.lang ?? '').trim().isNotEmpty
                ? selectedVoice!.lang.trim()
                : locale;
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
    try {
      _resumeSynth(web.window.speechSynthesis);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _resumeSynth(web.SpeechSynthesis synth) {
    try {
      synth.resume();
    } catch (_) {}
  }

  List<web.SpeechSynthesisVoice> _voiceList(
    JSArray<web.SpeechSynthesisVoice> jsVoices,
  ) =>
      jsVoices.toDart;

  Future<List<web.SpeechSynthesisVoice>> _readVoicesWithWarmup(
    web.SpeechSynthesis synth,
  ) async {
    var voices = _voiceList(synth.getVoices());
    if (voices.isNotEmpty) return voices;
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      _resumeSynth(synth);
      voices = _voiceList(synth.getVoices());
      if (voices.isNotEmpty) return voices;
    }
    return voices;
  }

  Future<bool> _speakAttempt({
    required web.SpeechSynthesis synth,
    required String payload,
    required String locale,
    web.SpeechSynthesisVoice? selectedVoice,
  }) async {
    bool started = false;

    final utterance = web.SpeechSynthesisUtterance(payload);
    utterance.lang = locale;
    utterance.volume = 1.0;
    utterance.rate = 0.95;
    utterance.pitch = 1.0;
    if (selectedVoice != null) utterance.voice = selectedVoice;

    final done = Completer<void>();
    final fallback = Timer(
      Duration(
        milliseconds: (payload.length * 70).clamp(1200, 14000).toInt(),
      ),
      () {
        if (!done.isCompleted) done.complete();
      },
    );
    final speakingProbe = Timer(const Duration(milliseconds: 220), () {
      if (!started && synth.speaking) started = true;
    });

    void onStart(web.Event _) => started = true;
    void onEnd(web.Event _) {
      if (!done.isCompleted) done.complete();
    }
    void onError(web.Event _) {
      if (!done.isCompleted) done.complete();
    }

    final onStartJs = onStart.toJS;
    final onEndJs = onEnd.toJS;
    final onErrorJs = onError.toJS;

    utterance.addEventListener('start', onStartJs);
    utterance.addEventListener('end', onEndJs);
    utterance.addEventListener('error', onErrorJs);

    if (synth.pending || synth.speaking) {
      synth.cancel();
      _resumeSynth(synth);
    }
    synth.speak(utterance);

    try {
      await done.future;
    } finally {
      fallback.cancel();
      speakingProbe.cancel();
      utterance.removeEventListener('start', onStartJs);
      utterance.removeEventListener('end', onEndJs);
      utterance.removeEventListener('error', onErrorJs);
    }

    return started;
  }

  web.SpeechSynthesisVoice? _selectBestVoice(
    List<web.SpeechSynthesisVoice> voices,
    String locale,
  ) {
    if (voices.isEmpty) return null;
    final normalizedLocale = locale.toLowerCase();
    final languageCode = normalizedLocale.split('-').first;

    for (final voice in voices) {
      if (voice.lang.toLowerCase() == normalizedLocale && voice.localService) {
        return voice;
      }
    }
    for (final voice in voices) {
      if (voice.lang.toLowerCase() == normalizedLocale) return voice;
    }
    for (final voice in voices) {
      if (voice.lang.toLowerCase().startsWith(languageCode) &&
          voice.localService) {
        return voice;
      }
    }
    for (final voice in voices) {
      if (voice.lang.toLowerCase().startsWith(languageCode)) return voice;
    }
    for (final voice in voices) {
      if (voice.default_) return voice;
    }
    return voices.first;
  }

  // ── Listen ─────────────────────────────────────────────────────────────────

  @override
  Future<String?> listenOnce({
    String locale = 'en-US',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!supportsSpeechRecognition) return null;

    _stopRecognitionInternal();
    await _ensureMicPermission();

    final completer = Completer<String?>();
    _recognitionCompleter = completer;

    final recognition = web.SpeechRecognition();
    _activeRecognition = recognition;
    _isListening = true;

    recognition.lang = locale;
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;

    void completeAndCleanup(String? transcript) {
      if (!completer.isCompleted) completer.complete(transcript);
      _stopRecognitionInternal();
    }

    void onResult(web.Event event) {
      final e = event as web.SpeechRecognitionEvent;
      final results = e.results;
      if (results.length == 0) {
        completeAndCleanup(null);
        return;
      }
      final firstResult = results.item(0)!;
      if (firstResult.length == 0) {
        completeAndCleanup(null);
        return;
      }
      final transcript = firstResult.item(0)!.transcript.trim();
      completeAndCleanup(transcript.isNotEmpty ? transcript : null);
    }

    void onError(web.Event _) => completeAndCleanup(null);

    void onEnd(web.Event _) {
      if (!completer.isCompleted) completeAndCleanup(null);
    }

    _onResultJs = onResult.toJS;
    _onErrorJs = onError.toJS;
    _onEndJs = onEnd.toJS;

    recognition.addEventListener('result', _onResultJs);
    recognition.addEventListener('error', _onErrorJs);
    recognition.addEventListener('end', _onEndJs);

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
      final constraints = web.MediaStreamConstraints(audio: true.toJS);
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      final tracks = stream.getTracks().toDart;
      for (final track in tracks) {
        try {
          track.stop();
        } catch (_) {}
      }
    } catch (_) {
      // Permission prime is best-effort.
    }
  }

  // ── Stop ───────────────────────────────────────────────────────────────────

  @override
  void stop() {
    _stopRecognitionInternal();
    try {
      web.window.speechSynthesis.cancel();
    } catch (_) {}
  }

  void _stopRecognitionInternal() {
    _recognitionTimeoutTimer?.cancel();
    _recognitionTimeoutTimer = null;

    final recognition = _activeRecognition;
    if (recognition != null) {
      try {
        if (_onResultJs != null) {
          recognition.removeEventListener('result', _onResultJs!);
        }
        if (_onErrorJs != null) {
          recognition.removeEventListener('error', _onErrorJs!);
        }
        if (_onEndJs != null) {
          recognition.removeEventListener('end', _onEndJs!);
        }
        recognition.stop();
      } catch (_) {}
    }
    _activeRecognition = null;
    _onResultJs = null;
    _onErrorJs = null;
    _onEndJs = null;
    _isListening = false;

    final completer = _recognitionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _recognitionCompleter = null;
  }
}

VoiceAssistantService createVoiceAssistantServiceImpl() =>
    _WebVoiceAssistantService();
