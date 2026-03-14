import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'voice_assistant_service.dart';

class _WebVoiceAssistantService implements VoiceAssistantService {
  web.SpeechRecognition? _activeRecognition;
  Completer<String?>? _recognitionCompleter;
  Timer? _recognitionTimeoutTimer;
  StreamSubscription<web.SpeechRecognitionEvent>? _recognitionResultSub;
  StreamSubscription<web.SpeechRecognitionErrorEvent>? _recognitionErrorSub;
  StreamSubscription<web.Event>? _recognitionEndSub;
  bool _isListening = false;

  @override
  bool get supported => web.window.speechSynthesis != null;

  @override
  bool get supportsSpeechRecognition {
    try {
      // package:web exposes the constructor directly; if it throws the
      // browser does not support the API.
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
            selectedVoice?.lang.trim().isNotEmpty == true
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
    } catch (_) {
      // Best-effort.
    }
  }

  // Convert JSArray<SpeechSynthesisVoice> → Dart List
  List<web.SpeechSynthesisVoice> _voiceList(
    JSArray<web.SpeechSynthesisVoice> jsVoices,
  ) {
    final list = <web.SpeechSynthesisVoice>[];
    for (var i = 0; i < jsVoices.length; i++) {
      list.add(jsVoices.item(i)!);
    }
    return list;
  }

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

    if (selectedVoice != null) {
      utterance.voice = selectedVoice;
    }

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

    utterance.addEventListener('start', onStart.toJS);
    utterance.addEventListener('end', onEnd.toJS);
    utterance.addEventListener('error', onError.toJS);

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
      utterance.removeEventListener('start', onStart.toJS);
      utterance.removeEventListener('end', onEnd.toJS);
      utterance.removeEventListener('error', onError.toJS);
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
      final lang = voice.lang.toLowerCase();
      if (lang == normalizedLocale && voice.localService) return voice;
    }
    for (final voice in voices) {
      final lang = voice.lang.toLowerCase();
      if (lang == normalizedLocale) return voice;
    }
    for (final voice in voices) {
      final lang = voice.lang.toLowerCase();
      if (lang.startsWith(languageCode) && voice.localService) return voice;
    }
    for (final voice in voices) {
      final lang = voice.lang.toLowerCase();
      if (lang.startsWith(languageCode)) return voice;
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

    _recognitionResultSub = recognition.onresult.listen((event) {
      final results = event.results;
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
    });

    _recognitionErrorSub = recognition.onspeechrecognitionerror.listen((_) {
      completeAndCleanup(null);
    });

    _recognitionEndSub = recognition.onend.listen((_) {
      if (!completer.isCompleted) completeAndCleanup(null);
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
      final mediaDevices = web.window.navigator.mediaDevices;
      final constraints = web.MediaStreamConstraints(audio: true.toJS);
      final stream = await mediaDevices.getUserMedia(constraints).toDart;
      final tracks = stream.getTracks();
      for (var i = 0; i < tracks.length; i++) {
        try {
          tracks.item(i)!.stop();
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
        recognition.stop();
      } catch (_) {}
    }
    _activeRecognition = null;
    _isListening = false;

    final resultSub = _recognitionResultSub;
    _recognitionResultSub = null;
    if (resultSub != null) unawaited(resultSub.cancel());

    final errorSub = _recognitionErrorSub;
    _recognitionErrorSub = null;
    if (errorSub != null) unawaited(errorSub.cancel());

    final endSub = _recognitionEndSub;
    _recognitionEndSub = null;
    if (endSub != null) unawaited(endSub.cancel());

    final completer = _recognitionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _recognitionCompleter = null;
  }
}

VoiceAssistantService createVoiceAssistantServiceImpl() =>
    _WebVoiceAssistantService();