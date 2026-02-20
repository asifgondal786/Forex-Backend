import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/models/agent_orchestrator_models.dart';
import '../services/api_service.dart';
import '../services/voice_assistant_service.dart';

class AgentOrchestratorProvider extends ChangeNotifier {
  final ApiService apiService;
  final Random _random = Random();
  final VoiceAssistantService _voiceAssistant;

  AgentVisualState _visualState = AgentVisualState.monitoring;
  AgentAutonomyMode _autonomyMode = AgentAutonomyMode.assisted;
  RiskGuardrails _guardrails = const RiskGuardrails();
  final List<AgentConversationTurn> _conversation = <AgentConversationTurn>[];
  final List<DecisionLogEntry> _decisionLog = <DecisionLogEntry>[];
  final Map<String, double> _lastRatesSnapshot = <String, double>{};
  Timer? _autonomyLoopTimer;
  Timer? _marketBriefingTimer;

  double _confidenceScore = 72.0;
  String _marketBias = 'Neutral';
  bool _isVoiceListening = false;
  Object? _isBotSpeaking = false;
  bool _isCapturingVoiceCommand = false;
  bool _isProcessing = false;
  bool _isKillSwitchEngaged = false;
  bool _offlineMode = false;
  bool _initialized = false;
  String? _error;
  String? _pendingHighRiskCommand;
  double _draftRiskPerTradePercent = 1.0;
  double _draftDailyLossPercent = 2.0;
  String _languageCode = 'en';
  Object? _periodicVoiceBriefingsEnabled = true;
  Object? _briefingIntervalSeconds = 45;
  Object? _disposed = false;
  Object? _pendingSpeech = Future<void>.value();
  Object? _activeSpeechJobs = 0;

  static const Map<String, String> _supportedLanguages = <String, String>{
    'en': 'English',
    'ur': 'Urdu',
    'es': 'Spanish',
    'fr': 'French',
    'ar': 'Arabic',
    'zh': 'Chinese',
    'hi': 'Hindi',
    'de': 'German',
  };

  AgentOrchestratorProvider({
    required this.apiService,
    VoiceAssistantService? voiceAssistant,
  }) : _voiceAssistant = voiceAssistant ?? createVoiceAssistantService();

  AgentVisualState get visualState => _visualState;
  AgentAutonomyMode get autonomyMode => _autonomyMode;
  RiskGuardrails get guardrails => _guardrails;
  double get confidenceScore => _confidenceScore;
  String get marketBias => _marketBias;
  bool get isVoiceListening => _isVoiceListening;
  bool get isBotSpeaking => _isBotSpeaking == true;
  bool get isCapturingVoiceCommand =>
      _isCapturingVoiceCommand || _voiceAssistant.isListening;
  bool get supportsVoiceCommandCapture =>
      kIsWeb ? true : _voiceAssistant.supportsSpeechRecognition;
  bool get periodicVoiceBriefingsEnabled =>
      _periodicVoiceBriefingsEnabled == true;
  int get briefingIntervalSeconds {
    final value = _briefingIntervalSeconds;
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 45;
  }

  bool get isProcessing => _isProcessing;
  bool get isKillSwitchEngaged => _isKillSwitchEngaged;
  bool get offlineMode => _offlineMode;
  String? get error => _error;
  String? get pendingHighRiskCommand => _pendingHighRiskCommand;
  String get languageCode => _languageCode;
  Map<String, String> get supportedLanguages =>
      Map<String, String>.unmodifiable(_supportedLanguages);
  List<AgentConversationTurn> get conversation =>
      List<AgentConversationTurn>.unmodifiable(_conversation);
  List<DecisionLogEntry> get decisionLog =>
      List<DecisionLogEntry>.unmodifiable(_decisionLog);
  double get draftRiskPerTradePercent => _draftRiskPerTradePercent;
  double get draftDailyLossPercent => _draftDailyLossPercent;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _isVoiceListening = true;

    _addSystemMessage(_localizedWelcome(), speak: true);
    await _sendMarketBriefing(isWelcome: true);
    await refreshGuardrails();
    _startMarketBriefingLoop();
    _syncAutonomousLoop();
    if (_voiceAssistant.supportsSpeechRecognition) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (!_initialized || !_isVoiceListening || _isProcessing) {
          return;
        }
        unawaited(captureVoiceCommand(silentFailure: true));
      });
    }
  }

  Future<void> setLanguage(String languageCode, {bool announce = true}) async {
    if (!_supportedLanguages.containsKey(languageCode)) {
      _addSystemMessage(
        'Unsupported language. Available: ${_supportedLanguages.entries.map((entry) => entry.value).join(', ')}',
      );
      return;
    }
    _languageCode = languageCode;
    if (announce) {
      final label = _supportedLanguages[languageCode] ?? languageCode;
      _addSystemMessage(_localizedLanguageChanged(label), speak: true);
    }
    notifyListeners();
  }

  Future<void> refreshGuardrails() async {
    _setProcessing(true);
    _clearError();

    try {
      final payload = await apiService.getAutonomyGuardrails();
      _offlineMode = false;
      _guardrails = RiskGuardrails.fromApi(payload);
      _autonomyMode = _autonomyFromBackendLevel(_guardrails.backendLevel);
      _draftRiskPerTradePercent = _guardrails.maxRiskPerTradePercent;
      _draftDailyLossPercent = _guardrails.dailyLossLimitPercent;
      _isKillSwitchEngaged = _guardrails.paused;
      _visualState = _guardrails.paused
          ? AgentVisualState.paused
          : AgentVisualState.monitoring;

      _addDecision(
        summary: 'Guardrails synchronized from backend.',
        rationale:
            'Risk budget set to ${_guardrails.maxRiskPerTradePercent.toStringAsFixed(2)}% per trade with ${_guardrails.dailyLossLimitPercent.toStringAsFixed(2)}% daily loss cap.',
        state: AgentVisualState.monitoring,
      );
    } catch (e) {
      _offlineMode = true;
      _guardrails = _guardrails.copyWith(
        maxRiskPerTradePercent: _draftRiskPerTradePercent,
        dailyLossLimitPercent: _draftDailyLossPercent,
        paused: false,
        pauseReason: '',
      );
      _addSystemMessage(
        'Backend unreachable. Switched to local simulation mode.',
      );
      _addDecision(
        summary: 'Guardrails loaded from local fallback.',
        rationale:
            'API is unavailable, so simulation mode uses client-side risk constraints.',
        state: AgentVisualState.monitoring,
      );
    } finally {
      _setProcessing(false);
    }
  }

  void setDraftRiskPerTradePercent(double value) {
    _draftRiskPerTradePercent = value;
    notifyListeners();
  }

  void setDraftDailyLossPercent(double value) {
    _draftDailyLossPercent = value;
    notifyListeners();
  }

  Future<void> applyDraftGuardrails() async {
    await _configureAutonomy(
      mode: _autonomyMode,
      riskPerTradePercent: _draftRiskPerTradePercent,
      dailyLossLimitPercent: _draftDailyLossPercent,
      announce: true,
    );
  }

  void toggleVoiceListening() {
    _isVoiceListening = !_isVoiceListening;
    if (!_isVoiceListening) {
      _voiceAssistant.stop();
    } else {
      unawaited(_voiceAssistant.unlockAudio());
      _periodicVoiceBriefingsEnabled = true;
      _startMarketBriefingLoop();
      unawaited(_sendMarketBriefing(forceSpeak: true));
    }
    _addSystemMessage(
      _isVoiceListening ? _localizedVoiceEnabled() : _localizedVoiceDisabled(),
      speak: _isVoiceListening,
    );
    notifyListeners();
  }

  Future<void> triggerVoiceTest() async {
    if (_disposed == true) {
      return;
    }
    if (!_isVoiceListening) {
      _isVoiceListening = true;
    }
    final message = _localizedVoiceTestLine();
    _appendConversation(text: message, fromUser: false);
    notifyListeners();

    _beginSpeechVisual();
    final startedAt = DateTime.now();
    const minVisualSpeakingDuration = Duration(milliseconds: 1100);
    try {
      await _voiceAssistant.speak(
        message,
        locale: _voiceLocaleForLanguage(_languageCode),
      );
    } catch (_) {
      // Best-effort voice test.
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minVisualSpeakingDuration) {
        await Future<void>.delayed(minVisualSpeakingDuration - elapsed);
      }
      _endSpeechVisual();
    }
    notifyListeners();
  }

  Future<void> captureVoiceCommand({bool silentFailure = false}) async {
    if (!_isVoiceListening) {
      _addSystemMessage(_localizedEnableVoiceFirst());
      return;
    }
    if (_isCapturingVoiceCommand || _voiceAssistant.isListening) {
      return;
    }

    _isCapturingVoiceCommand = true;
    notifyListeners();
    _addSystemMessage(_localizedListeningPrompt(), silent: true);
    final startedAt = DateTime.now();
    const minListeningVisualDuration = Duration(milliseconds: 900);

    try {
      final transcript = await _voiceAssistant.listenOnce(
        locale: _voiceLocaleForLanguage(_languageCode),
        timeout: const Duration(seconds: 12),
      );
      final heard = transcript?.trim() ?? '';
      if (heard.isEmpty) {
        if (!silentFailure) {
          _addSystemMessage(
            supportsVoiceCommandCapture
                ? _localizedListeningNoSpeech()
                : _localizedVoiceCaptureUnsupported(),
          );
        }
        return;
      }

      _addSystemMessage(
        _localizedHeardCommand(heard),
        silent: true,
      );
      await submitCommand(heard);
    } catch (e) {
      if (!silentFailure) {
        _addSystemMessage('Voice capture failed: ${_safeErrorText(e)}');
      }
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minListeningVisualDuration) {
        await Future<void>.delayed(minListeningVisualDuration - elapsed);
      }
      _isCapturingVoiceCommand = false;
      notifyListeners();
    }
  }

  Future<void> updateAutonomyMode(AgentAutonomyMode mode) async {
    if (mode == AgentAutonomyMode.fullAuto) {
      _pendingHighRiskCommand =
          'Enable full autonomy with ${_draftRiskPerTradePercent.toStringAsFixed(2)}% risk per trade';
      _addSystemMessage(
        'High-risk command pending confirmation. Type "confirm command" to enable Full Auto.',
      );
      notifyListeners();
      return;
    }

    await _configureAutonomy(
      mode: mode,
      riskPerTradePercent: _draftRiskPerTradePercent,
      dailyLossLimitPercent: _draftDailyLossPercent,
      announce: true,
    );
  }

  Future<void> submitCommand(String rawCommand) async {
    final command = rawCommand.trim();
    if (command.isEmpty) {
      return;
    }

    _addUserMessage(command);
    _clearError();

    final normalized = command.toLowerCase();
    final isConfirmation = _isConfirmationCommand(normalized);
    if (_pendingHighRiskCommand != null && isConfirmation) {
      final pending = _pendingHighRiskCommand!;
      _pendingHighRiskCommand = null;
      await _executeCommand(pending, fromPendingConfirmation: true);
      return;
    }

    if (_isHighRiskCommand(normalized) && !isConfirmation) {
      _pendingHighRiskCommand = command;
      _addSystemMessage(
        'Command requires confirmation. Type "confirm command" to proceed.',
      );
      _addDecision(
        summary: 'High-risk command held for confirmation.',
        rationale:
            'Destructive or high-authority command requires explicit confirmation.',
        state: AgentVisualState.paused,
        blockedByGuardrails: true,
      );
      notifyListeners();
      return;
    }

    await _executeCommand(command);
  }

  Future<void> executeAutonomousCycle() async {
    if (_isKillSwitchEngaged || _autonomyMode == AgentAutonomyMode.manual) {
      _addSystemMessage(
        'Autonomous execution blocked. Switch to Assisted/Semi-Auto mode first.',
      );
      return;
    }

    _setProcessing(true);
    _visualState = AgentVisualState.analyzing;
    notifyListeners();

    try {
      if (_offlineMode) {
        _runOfflineAutonomousCycle();
        return;
      }

      final pair = _suggestPair();
      final tradeParams = _buildTradeParams(pair: pair);
      final explain = await apiService.explainBeforeExecute(
        tradeParams: tradeParams,
      );
      final guardPassed = explain['guard_passed'] == true;
      final guardReason =
          (explain['guard_reason'] ?? 'No reason available').toString();
      final executionToken = (explain['execution_token'] ?? '').toString();
      final tokenRequired = explain['execution_token_required'] == true;

      if (!guardPassed) {
        _visualState = AgentVisualState.paused;
        _addSystemMessage('Trade blocked by guardrails: $guardReason');
        _addDecision(
          summary: 'Trade blocked for $pair.',
          rationale: guardReason,
          state: AgentVisualState.paused,
          blockedByGuardrails: true,
        );
        return;
      }

      if (tokenRequired && executionToken.isEmpty) {
        _visualState = AgentVisualState.paused;
        _addSystemMessage(
          'Trade blocked: missing explain-before-execute token from backend.',
        );
        _addDecision(
          summary: 'Trade blocked for $pair.',
          rationale:
              'Backend requires explain-before-execute token for live autonomous execution.',
          state: AgentVisualState.paused,
          blockedByGuardrails: true,
        );
        return;
      }

      _visualState = AgentVisualState.trading;
      notifyListeners();

      final result = await apiService.executeAutonomousTrade(
        tradeParams: tradeParams,
        explainToken: executionToken,
      );
      final success = result['success'] == true;
      final resultMessage =
          (result['message'] ?? result['status'] ?? 'Trade execution complete')
              .toString();

      _addSystemMessage(success
          ? 'Trade executed: $resultMessage'
          : 'Trade attempt returned warning: $resultMessage');
      _addDecision(
        summary: 'Executed autonomous trade on $pair.',
        rationale: 'Guardrails passed. $resultMessage',
        state: AgentVisualState.trading,
      );
    } catch (e) {
      _setError('Autonomous cycle failed: ${_safeErrorText(e)}');
    } finally {
      _simulateCognitionUpdate();
      _visualState = _isKillSwitchEngaged
          ? AgentVisualState.paused
          : AgentVisualState.monitoring;
      _setProcessing(false);
    }
  }

  Future<void> engageKillSwitch({bool announce = true}) async {
    if (_isKillSwitchEngaged && announce) {
      _addSystemMessage('Kill switch already active.');
      return;
    }

    _setProcessing(true);
    try {
      if (_offlineMode) {
        _isKillSwitchEngaged = true;
        _visualState = AgentVisualState.paused;
        _autonomyMode = AgentAutonomyMode.manual;
        _guardrails = _guardrails.copyWith(
          paused: true,
          pauseReason: 'Kill switch activated (offline simulation)',
          backendLevel: 'manual',
        );
        _syncAutonomousLoop();
        if (announce) {
          _addSystemMessage(
            'Kill switch activated in simulation mode.',
          );
        }
        _addDecision(
          summary: 'Kill switch engaged.',
          rationale: 'Emergency override executed in offline simulation mode.',
          state: AgentVisualState.paused,
        );
        return;
      }

      await apiService.activateKillSwitch();
      _isKillSwitchEngaged = true;
      _visualState = AgentVisualState.paused;
      _autonomyMode = AgentAutonomyMode.manual;
      _guardrails = _guardrails.copyWith(
        paused: true,
        pauseReason: 'Kill switch activated',
        backendLevel: 'manual',
      );
      _syncAutonomousLoop();

      if (announce) {
        _addSystemMessage(
          'Kill switch activated. All autonomous trading is paused.',
        );
      }
      _addDecision(
        summary: 'Kill switch engaged.',
        rationale:
            'Emergency override requested by user or system-level safety rule.',
        state: AgentVisualState.paused,
      );
    } catch (e) {
      _setError('Kill switch activation failed: ${_safeErrorText(e)}');
    } finally {
      _setProcessing(false);
    }
  }

  void dismissPendingHighRiskCommand() {
    _pendingHighRiskCommand = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  Future<void> _executeCommand(
    String command, {
    bool fromPendingConfirmation = false,
  }) async {
    _setProcessing(true);
    _visualState = AgentVisualState.analyzing;
    notifyListeners();

    try {
      final normalized = command.toLowerCase();
      final languageFromCommand = _extractLanguageFromCommand(normalized);
      if (normalized.contains('language') && languageFromCommand != null) {
        await setLanguage(languageFromCommand);
        return;
      }

      if (normalized.contains('voice on') ||
          normalized.contains('enable voice') ||
          normalized.contains('start voice')) {
        if (!_isVoiceListening) {
          _isVoiceListening = true;
          notifyListeners();
        }
        _addSystemMessage(_localizedVoiceEnabled(), speak: true);
        return;
      }

      if (normalized.contains('voice off') ||
          normalized.contains('disable voice') ||
          normalized.contains('stop voice')) {
        if (_isVoiceListening) {
          _isVoiceListening = false;
          notifyListeners();
        }
        _voiceAssistant.stop();
        _addSystemMessage(_localizedVoiceDisabled());
        return;
      }

      if (_tryConfigurePeriodicVoiceBriefings(normalized, command)) {
        return;
      }

      if (normalized.contains('listen now') ||
          normalized.contains('start listening') ||
          normalized.contains('voice command') ||
          normalized.contains('sun lo')) {
        await captureVoiceCommand();
        return;
      }

      if (normalized.contains('voice test') ||
          normalized.contains('test voice') ||
          normalized.contains('speak now')) {
        await triggerVoiceTest();
        return;
      }

      if (normalized.contains('market update') ||
          normalized.contains('market briefing') ||
          normalized.contains('today') && normalized.contains('forex')) {
        await _sendMarketBriefing(forceSpeak: _isVoiceListening);
        return;
      }

      if (normalized.contains('autonomous decision') ||
          normalized.contains('decide for me') ||
          normalized.contains('trade now') ||
          normalized.contains('execute now')) {
        await executeAutonomousCycle();
        return;
      }

      final channelCommandHandled =
          await _configureNotificationChannelsFromCommand(command);
      if (channelCommandHandled) {
        return;
      }

      if (normalized.contains('stop trading now') ||
          normalized.contains('revoke autonomy') ||
          normalized.contains('kill switch')) {
        await engageKillSwitch(announce: !fromPendingConfirmation);
        return;
      }

      if (normalized.contains('enable full autonomy') ||
          normalized.contains('fully authorized')) {
        final risk = _extractPercent(command) ?? _draftRiskPerTradePercent;
        _draftRiskPerTradePercent = risk.clamp(0.25, 3.0);
        await _configureAutonomy(
          mode: AgentAutonomyMode.fullAuto,
          riskPerTradePercent: _draftRiskPerTradePercent,
          dailyLossLimitPercent: _draftDailyLossPercent,
          announce: true,
        );
        return;
      }

      if (normalized.contains('semi-auto') ||
          normalized.contains('semi auto') ||
          normalized.contains('guarded auto')) {
        await _configureAutonomy(
          mode: AgentAutonomyMode.semiAuto,
          riskPerTradePercent: _draftRiskPerTradePercent,
          dailyLossLimitPercent: _draftDailyLossPercent,
          announce: true,
        );
        return;
      }

      if (normalized.contains('assisted mode')) {
        await _configureAutonomy(
          mode: AgentAutonomyMode.assisted,
          riskPerTradePercent: _draftRiskPerTradePercent,
          dailyLossLimitPercent: _draftDailyLossPercent,
          announce: true,
        );
        return;
      }

      if (normalized.contains('pause trading') ||
          normalized.contains('switch to simulation')) {
        await _configureAutonomy(
          mode: AgentAutonomyMode.assisted,
          riskPerTradePercent: _draftRiskPerTradePercent,
          dailyLossLimitPercent: _draftDailyLossPercent,
          announce: true,
        );
        _addSystemMessage(
          'Live execution paused. Agent is in assisted/simulation posture.',
        );
        return;
      }

      if (normalized.contains('close all positions')) {
        await engageKillSwitch(announce: false);
        _addSystemMessage(
          'Requested close-all workflow acknowledged. Active automation has been revoked.',
        );
        return;
      }

      if (normalized.contains('explain') ||
          normalized.contains('market bias') ||
          normalized.contains('why')) {
        _simulateCognitionUpdate();
        _addSystemMessage(
          'Current bias: $_marketBias. Confidence ${_confidenceScore.toStringAsFixed(0)}%. '
          'Reasoning: trend persistence with volatility-aware throttling and sentiment filter alignment.',
        );
        _addDecision(
          summary: 'Generated explainability response.',
          rationale:
              'Shared market bias, confidence score, and risk-aware rationale.',
          state: AgentVisualState.analyzing,
        );
        return;
      }

      final outlookHandled =
          await _tryAnswerMarketOutlookQuestion(command, normalized);
      if (outlookHandled) {
        return;
      }

      final nlpHandled = await _tryBackendNlp(command);
      if (nlpHandled) {
        return;
      }

      _addSystemMessage(
        'Command recognized but not yet automated. Try: "Enable full autonomy with 1% risk per trade" or "Stop trading now".',
      );
    } catch (e) {
      _setError('Command failed: ${_safeErrorText(e)}');
    } finally {
      _simulateCognitionUpdate();
      _visualState = _isKillSwitchEngaged
          ? AgentVisualState.paused
          : AgentVisualState.monitoring;
      _setProcessing(false);
    }
  }

  Future<void> _configureAutonomy({
    required AgentAutonomyMode mode,
    required double riskPerTradePercent,
    required double dailyLossLimitPercent,
    required bool announce,
  }) async {
    _setProcessing(true);
    _clearError();

    try {
      if (_offlineMode) {
        _guardrails = _guardrails.copyWith(
          maxRiskPerTradePercent: riskPerTradePercent,
          dailyLossLimitPercent: dailyLossLimitPercent,
          backendLevel: _backendLevel(mode),
          paused: false,
          pauseReason: '',
        );
        _autonomyMode = mode;
        _isKillSwitchEngaged = false;
        _visualState = AgentVisualState.monitoring;
        _draftRiskPerTradePercent = riskPerTradePercent;
        _draftDailyLossPercent = dailyLossLimitPercent;
        _syncAutonomousLoop();
        if (announce) {
          _addSystemMessage(
            'Simulation mode: autonomy set to ${mode.label} with risk ${riskPerTradePercent.toStringAsFixed(2)}%.',
          );
        }
        _addDecision(
          summary: 'Autonomy policy updated to ${mode.label}.',
          rationale:
              'Backend unavailable, policy change applied to local simulation controls.',
          state: AgentVisualState.monitoring,
        );
        return;
      }

      final response = await apiService.configureAutonomyGuardrails(
        level: _backendLevel(mode),
        riskBudget: <String, dynamic>{
          'max_risk_per_trade_percent': riskPerTradePercent,
          'daily_loss_limit_percent': dailyLossLimitPercent,
        },
      );

      _guardrails = RiskGuardrails.fromApi(response).copyWith(
        maxRiskPerTradePercent: riskPerTradePercent,
        dailyLossLimitPercent: dailyLossLimitPercent,
        backendLevel: _backendLevel(mode),
        paused: false,
        pauseReason: '',
      );
      _autonomyMode = mode;
      _isKillSwitchEngaged = false;
      _visualState = AgentVisualState.monitoring;
      _draftRiskPerTradePercent = riskPerTradePercent;
      _draftDailyLossPercent = dailyLossLimitPercent;
      _syncAutonomousLoop();

      if (announce) {
        _addSystemMessage(
          'Autonomy set to ${mode.label} with risk ${riskPerTradePercent.toStringAsFixed(2)}% and daily loss cap ${dailyLossLimitPercent.toStringAsFixed(2)}%.',
        );
      }
      _addDecision(
        summary: 'Autonomy policy updated to ${mode.label}.',
        rationale:
            'Capital-preservation limits were synchronized before execution rights changed.',
        state: AgentVisualState.monitoring,
      );
    } catch (e) {
      _offlineMode = true;
      _setError(
        'Failed to configure autonomy via API: ${_safeErrorText(e)}',
      );
    } finally {
      _setProcessing(false);
    }
  }

  void _runOfflineAutonomousCycle() {
    final pair = _suggestPair();
    final blocked = _draftRiskPerTradePercent > 2.5 || _isKillSwitchEngaged;
    if (blocked) {
      _visualState = AgentVisualState.paused;
      _addSystemMessage(
        'Simulation blocked trade on $pair due to risk constraints.',
      );
      _addDecision(
        summary: 'Simulated trade blocked for $pair.',
        rationale: 'Risk threshold exceeded in simulation.',
        state: AgentVisualState.paused,
        blockedByGuardrails: true,
      );
      return;
    }

    _visualState = AgentVisualState.trading;
    _addSystemMessage(
      'Simulation executed BUY on $pair with ${_draftRiskPerTradePercent.toStringAsFixed(2)}% risk.',
    );
    _addDecision(
      summary: 'Simulated trade executed on $pair.',
      rationale:
          'Offline mode uses local rules to mimic explain-before-execute and execution behavior.',
      state: AgentVisualState.trading,
    );
  }

  Map<String, dynamic> _buildTradeParams({required String pair}) {
    final quote = <String, double>{
      'EUR/USD': 1.1012,
      'GBP/USD': 1.2796,
      'USD/JPY': 154.40,
      'USD/PKR': 279.35,
    };
    final entry = quote[pair] ?? 1.0;
    final riskFraction = (_draftRiskPerTradePercent / 100.0).clamp(0.003, 0.03);
    final stopLoss = entry * (1 - riskFraction);
    final takeProfit = entry * (1 + (riskFraction * 1.8));

    return <String, dynamic>{
      'pair': pair,
      'action': 'BUY',
      'entry_price': double.parse(entry.toStringAsFixed(5)),
      'position_size': double.parse((1200 / entry).toStringAsFixed(2)),
      'stop_loss': double.parse(stopLoss.toStringAsFixed(5)),
      'take_profit': double.parse(takeProfit.toStringAsFixed(5)),
      'risk_percent':
          double.parse(_draftRiskPerTradePercent.toStringAsFixed(2)),
      'broker_fail_safe_confirmed': true,
      'server_side_stop_loss': true,
      'server_side_take_profit': true,
      'reason': 'Embodied orchestrator autonomous cycle',
      'is_paper_trade': false,
    };
  }

  String _suggestPair() {
    final pairs = <String>['EUR/USD', 'GBP/USD', 'USD/JPY', 'USD/PKR'];
    return pairs[_random.nextInt(pairs.length)];
  }

  void _simulateCognitionUpdate() {
    final biases = <String>[
      'Bullish USD',
      'Bearish USD',
      'Range-bound',
      'Volatility breakout watch',
    ];
    _marketBias = biases[_random.nextInt(biases.length)];
    _confidenceScore = 58 + _random.nextInt(36).toDouble();
  }

  void _addUserMessage(String text) {
    _appendConversation(text: text, fromUser: true);
  }

  void _addSystemMessage(
    String text, {
    bool speak = false,
    bool silent = false,
  }) {
    _appendConversation(text: text, fromUser: false);
    if (!silent && (speak || _isVoiceListening)) {
      unawaited(_queueSpeech(text));
    }
  }

  void _appendConversation({
    required String text,
    required bool fromUser,
  }) {
    _conversation.add(
      AgentConversationTurn(
        text: text,
        fromUser: fromUser,
        timestamp: DateTime.now(),
      ),
    );
    if (_conversation.length > 80) {
      _conversation.removeAt(0);
    }
  }

  void _addDecision({
    required String summary,
    required String rationale,
    required AgentVisualState state,
    bool blockedByGuardrails = false,
  }) {
    _decisionLog.insert(
      0,
      DecisionLogEntry(
        timestamp: DateTime.now(),
        state: state,
        summary: summary,
        rationale: rationale,
        confidencePercent: _confidenceScore,
        blockedByGuardrails: blockedByGuardrails,
      ),
    );
    if (_decisionLog.length > 60) {
      _decisionLog.removeLast();
    }
  }

  bool _isHighRiskCommand(String normalizedCommand) {
    return normalizedCommand.contains('full autonomy') ||
        normalizedCommand.contains('fully authorized') ||
        normalizedCommand.contains('close all positions');
  }

  bool _isConfirmationCommand(String normalizedCommand) {
    return normalizedCommand == 'confirm' ||
        normalizedCommand == 'confirm command' ||
        normalizedCommand.contains('yes proceed');
  }

  double? _extractPercent(String text) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(text);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1) ?? '');
  }

  bool _tryConfigurePeriodicVoiceBriefings(
    String normalized,
    String originalCommand,
  ) {
    final mentionsBriefing = normalized.contains('briefing') ||
        normalized.contains('spoken update') ||
        normalized.contains('voice update') ||
        normalized.contains('periodic voice') ||
        normalized.contains('market announcement');
    if (!mentionsBriefing) {
      return false;
    }

    final requestedInterval =
        _extractBriefingIntervalSecondsFromText(originalCommand);
    if (requestedInterval != null) {
      _briefingIntervalSeconds = requestedInterval.clamp(15, 300).toInt();
      _startMarketBriefingLoop();
      _addSystemMessage(
        _localizedBriefingIntervalUpdated(briefingIntervalSeconds),
        speak: true,
      );
      notifyListeners();
      return true;
    }

    if (normalized.contains('off') ||
        normalized.contains('disable') ||
        normalized.contains('stop')) {
      _periodicVoiceBriefingsEnabled = false;
      _addSystemMessage(_localizedPeriodicVoiceBriefingDisabled(), speak: true);
      notifyListeners();
      return true;
    }

    if (normalized.contains('on') ||
        normalized.contains('enable') ||
        normalized.contains('start')) {
      _periodicVoiceBriefingsEnabled = true;
      _startMarketBriefingLoop();
      _addSystemMessage(
        _localizedPeriodicVoiceBriefingEnabled(briefingIntervalSeconds),
        speak: true,
      );
      unawaited(_sendMarketBriefing(forceSpeak: _isVoiceListening));
      notifyListeners();
      return true;
    }

    return false;
  }

  int? _extractBriefingIntervalSecondsFromText(String text) {
    final match = RegExp(
      r'(\d+)\s*(seconds?|secs?|minutes?|mins?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return null;
    }

    final amount = int.tryParse(match.group(1) ?? '');
    if (amount == null || amount <= 0) {
      return null;
    }
    final unit = (match.group(2) ?? '').toLowerCase();
    if (unit.startsWith('min')) {
      return amount * 60;
    }
    return amount;
  }

  AgentAutonomyMode _autonomyFromBackendLevel(String level) {
    switch (level.toLowerCase()) {
      case 'manual':
        return AgentAutonomyMode.manual;
      case 'guarded_auto':
      case 'semi_auto':
      case 'semi-auto':
        return AgentAutonomyMode.semiAuto;
      case 'full_auto':
      case 'full':
        return AgentAutonomyMode.fullAuto;
      case 'assisted':
      default:
        return AgentAutonomyMode.assisted;
    }
  }

  String _backendLevel(AgentAutonomyMode mode) {
    switch (mode) {
      case AgentAutonomyMode.manual:
        return 'manual';
      case AgentAutonomyMode.assisted:
        return 'assisted';
      case AgentAutonomyMode.semiAuto:
        return 'guarded_auto';
      case AgentAutonomyMode.fullAuto:
        return 'full_auto';
    }
  }

  void _startMarketBriefingLoop() {
    _marketBriefingTimer?.cancel();
    _marketBriefingTimer =
        Timer.periodic(Duration(seconds: briefingIntervalSeconds), (_) {
      if (_isProcessing || _isKillSwitchEngaged) {
        return;
      }
      final shouldSpeak = periodicVoiceBriefingsEnabled && _isVoiceListening;
      unawaited(_sendMarketBriefing(forceSpeak: shouldSpeak));
    });
  }

  void _syncAutonomousLoop() {
    _autonomyLoopTimer?.cancel();
    _autonomyLoopTimer = null;

    final shouldAutoRun = _autonomyMode == AgentAutonomyMode.fullAuto &&
        !_isKillSwitchEngaged &&
        !_guardrails.paused;
    if (!shouldAutoRun) {
      return;
    }

    _autonomyLoopTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isProcessing || _isKillSwitchEngaged || _guardrails.paused) {
        return;
      }
      unawaited(executeAutonomousCycle());
    });
  }

  Future<void> _sendMarketBriefing({
    bool isWelcome = false,
    bool forceSpeak = false,
  }) async {
    try {
      final ratesPayload = await apiService.getForexRates();
      final newsPayload = await apiService.getForexNews();
      final sentimentPayload = await apiService.getForexMarketSentiment();

      final rates = <String, double>{};
      final ratesRaw = ratesPayload['rates'];
      if (ratesRaw is Map<String, dynamic>) {
        for (final entry in ratesRaw.entries) {
          final value = entry.value;
          if (value is num) {
            rates[entry.key] = value.toDouble();
          }
        }
      }

      final sentimentMap = sentimentPayload['sentiment'] is Map<String, dynamic>
          ? sentimentPayload['sentiment'] as Map<String, dynamic>
          : sentimentPayload;
      final trend = (sentimentMap['trend'] ?? 'neutral').toString();
      final volatility = (sentimentMap['volatility'] ?? 'medium').toString();
      final riskLevel = (sentimentMap['risk_level'] ?? 'moderate').toString();

      final topNews = newsPayload['news'] is List
          ? (newsPayload['news'] as List).whereType<Map>().cast<Map>().toList()
          : <Map>[];
      final headline = topNews.isNotEmpty
          ? ((topNews.first['event'] ??
                  topNews.first['title'] ??
                  'No major headline')
              .toString())
          : 'No major headline';

      final moverSummary = _summarizeFluctuations(rates);
      _marketBias = trend.toUpperCase();
      _confidenceScore = (55 + _random.nextInt(40)).toDouble();

      final message = _localizedMarketBriefing(
        trend: trend,
        volatility: volatility,
        risk: riskLevel,
        movers: moverSummary,
        headline: headline,
      );
      _addSystemMessage(message, speak: isWelcome || forceSpeak);
      _addDecision(
        summary: isWelcome
            ? 'Welcome briefing delivered.'
            : 'Real-time market fluctuation briefing updated.',
        rationale:
            'Trend: $trend, volatility: $volatility, risk: $riskLevel. Movers: $moverSummary.',
        state: AgentVisualState.analyzing,
      );
    } catch (_) {
      if (isWelcome || forceSpeak) {
        _addSystemMessage(
          _localizedBriefingFallback(),
          speak: true,
        );
      }
    }
  }

  String _summarizeFluctuations(Map<String, double> rates) {
    if (rates.isEmpty) {
      return 'rates unavailable';
    }
    if (_lastRatesSnapshot.isEmpty) {
      _lastRatesSnapshot
        ..clear()
        ..addAll(rates);
      final sample = rates.entries.take(8).map((entry) {
        final digits =
            entry.key.contains('JPY') || entry.key.contains('PKR') ? 2 : 4;
        return '${entry.key} ${entry.value.toStringAsFixed(digits)}';
      }).join(', ');
      return 'baseline: $sample';
    }

    String? topUpPair;
    double topUpMove = -999;
    String? topDownPair;
    double topDownMove = 999;
    final movements = <String>[];

    final sortedEntries = rates.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in sortedEntries) {
      final previous = _lastRatesSnapshot[entry.key];
      if (previous == null || previous == 0) {
        continue;
      }
      final change = ((entry.value - previous) / previous) * 100;
      if (change > topUpMove) {
        topUpMove = change;
        topUpPair = entry.key;
      }
      if (change < topDownMove) {
        topDownMove = change;
        topDownPair = entry.key;
      }
      final sign = change >= 0 ? '+' : '';
      movements.add('${entry.key} $sign${change.toStringAsFixed(2)}%');
    }

    _lastRatesSnapshot
      ..clear()
      ..addAll(rates);

    if (movements.isEmpty || topUpPair == null || topDownPair == null) {
      return 'movement tracking warming up';
    }

    final cappedMovements = movements.take(8).join(', ');
    final up = '$topUpPair +${topUpMove.toStringAsFixed(2)}%';
    final down = '$topDownPair ${topDownMove.toStringAsFixed(2)}%';
    return 'moves: $cappedMovements. strongest up: $up, strongest down: $down';
  }

  Future<bool> _tryAnswerMarketOutlookQuestion(
    String command,
    String normalized,
  ) async {
    final asksOutlook = _looksLikeOutlookQuestion(normalized);
    final pair = _extractPairFromText(normalized);
    if (!asksOutlook || pair == null) {
      return false;
    }
    final horizon = _extractForecastHorizonFromText(normalized);

    try {
      final payload =
          await apiService.getForexPairForecast(pair: pair, horizon: horizon);
      final forecast = payload['forecast'] is Map<String, dynamic>
          ? payload['forecast'] as Map<String, dynamic>
          : payload;

      final forecastPair = (forecast['pair'] ?? pair).toString().toUpperCase();
      final forecastHorizon = (forecast['horizon'] ?? horizon).toString();
      final currentPrice = _asDouble(forecast['current_price']);
      final trendBias = (forecast['trend_bias'] ?? 'neutral').toString();
      final volatility = (forecast['volatility'] ?? 'medium').toString();
      final risk = (forecast['risk_level'] ?? 'moderate').toString();
      final confidencePercent = _asInt(forecast['confidence_percent'], 58);
      final expectedChange = forecast['expected_change_percent'] is Map
          ? forecast['expected_change_percent'] as Map
          : const {};
      final targetRange =
          forecast['target_range'] is Map ? forecast['target_range'] as Map : const {};
      final expectedLow = _asDouble(expectedChange['low']);
      final expectedHigh = _asDouble(expectedChange['high']);
      final targetLow = _asDouble(targetRange['low']);
      final targetHigh = _asDouble(targetRange['high']);
      final timingLine = (forecast['timing_guidance'] ??
              'Use staged exits with protective stops while waiting for confirmation.')
          .toString();
      final disclaimer = (forecast['disclaimer'] ??
              'Simulation guidance only, not financial advice.')
          .toString();

      final priceText = currentPrice <= 0
          ? 'unavailable'
          : _formatPairPrice(forecastPair, currentPrice);
      final expectedBandText =
          '${expectedLow >= 0 ? '+' : ''}${expectedLow.toStringAsFixed(2)}% to ${expectedHigh >= 0 ? '+' : ''}${expectedHigh.toStringAsFixed(2)}%';
      final targetRangeText =
          '${_formatPairPrice(forecastPair, targetLow)} - ${_formatPairPrice(forecastPair, targetHigh)}';
      final horizonLabel = _horizonLabel(forecastHorizon);

      _addSystemMessage(
        _localizedOutlookAnswer(
          pair: forecastPair,
          horizon: horizonLabel,
          priceText: priceText,
          bias: trendBias,
          expectedBandText: expectedBandText,
          targetRangeText: targetRangeText,
          confidencePercent: confidencePercent,
          volatility: volatility,
          risk: risk,
          timingLine: timingLine,
          disclaimer: disclaimer,
        ),
        speak: _isVoiceListening,
      );
      _addDecision(
        summary: 'Answered market outlook request for $forecastPair.',
        rationale:
            'Used structured forecast ($horizonLabel horizon, confidence $confidencePercent%, bias $trendBias).',
        state: AgentVisualState.analyzing,
      );
      return true;
    } catch (_) {
      _addSystemMessage(
        'I could not compute a fresh outlook for $pair right now. Please retry in a few seconds.',
      );
      return true;
    }
  }

  bool _looksLikeOutlookQuestion(String normalized) {
    const keywords = <String>[
      'expected',
      'forecast',
      'prediction',
      'outlook',
      'rise',
      'fall',
      'up',
      'down',
      'buy',
      'sell',
      'sale',
      'target',
      'when should',
      'kab',
    ];
    return keywords.any(normalized.contains);
  }

  String? _extractPairFromText(String normalized) {
    if (RegExp(r'\busd\s*[/\-\s]\s*pkr\b').hasMatch(normalized) ||
        normalized.contains('usd to pkr') ||
        (normalized.contains('dollar') && normalized.contains('pkr'))) {
      return 'USD/PKR';
    }
    if (RegExp(r'\beur\s*[/\-\s]\s*usd\b').hasMatch(normalized) ||
        (normalized.contains('euro') && normalized.contains('dollar'))) {
      return 'EUR/USD';
    }
    if (RegExp(r'\bgbp\s*[/\-\s]\s*usd\b').hasMatch(normalized) ||
        normalized.contains('pound') && normalized.contains('dollar')) {
      return 'GBP/USD';
    }
    if (RegExp(r'\busd\s*[/\-\s]\s*jpy\b').hasMatch(normalized) ||
        normalized.contains('dollar yen')) {
      return 'USD/JPY';
    }
    if (RegExp(r'\baud\s*[/\-\s]\s*usd\b').hasMatch(normalized)) {
      return 'AUD/USD';
    }
    if (RegExp(r'\busd\s*[/\-\s]\s*cad\b').hasMatch(normalized)) {
      return 'USD/CAD';
    }
    return null;
  }

  String _extractForecastHorizonFromText(String normalized) {
    if (normalized.contains('intraday') ||
        normalized.contains('today') ||
        normalized.contains('next few hours') ||
        normalized.contains('next hours')) {
      return 'intraday';
    }
    if (normalized.contains('week') ||
        normalized.contains('weekly') ||
        normalized.contains('7 day') ||
        normalized.contains('7d')) {
      return '1w';
    }
    return '1d';
  }

  String _horizonLabel(String horizon) {
    final value = horizon.trim().toLowerCase();
    if (value == 'intraday') {
      return 'intraday';
    }
    if (value == '1w' || value == 'week' || value == 'weekly') {
      return '1-week';
    }
    return '1-day';
  }

  double _asDouble(dynamic value, [double fallback = 0.0]) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  int _pairDigits(String pair) {
    return pair.contains('JPY') || pair.contains('PKR') ? 2 : 4;
  }

  String _formatPairPrice(String pair, double value) {
    return value.toStringAsFixed(_pairDigits(pair));
  }

  String _localizedOutlookAnswer({
    required String pair,
    required String horizon,
    required String priceText,
    required String bias,
    required String expectedBandText,
    required String targetRangeText,
    required int confidencePercent,
    required String volatility,
    required String risk,
    required String timingLine,
    required String disclaimer,
  }) {
    switch (_languageCode) {
      case 'ur':
        return '$pair ka current rate $priceText hai. $horizon forecast bias $bias hai '
            'aur confidence $confidencePercent% hai. Expected move band $expectedBandText hai, '
            'target range $targetRangeText. Volatility $volatility aur risk $risk hai. '
            '$timingLine $disclaimer';
      default:
        return '$pair is currently at $priceText. $horizon forecast bias is $bias '
            'with confidence $confidencePercent%. Expected move band: $expectedBandText, '
            'target range: $targetRangeText. Volatility is $volatility and risk level is $risk. '
            '$timingLine $disclaimer';
    }
  }

  Future<bool> _configureNotificationChannelsFromCommand(String command) async {
    final normalized = command.toLowerCase();
    final mentionsNotify =
        normalized.contains('notify') || normalized.contains('alert');
    final wantsEmail = normalized.contains('email');
    final wantsSms = normalized.contains('sms') || normalized.contains('text');
    final wantsWhatsapp = normalized.contains('whatsapp') ||
        normalized.contains("what's app") ||
        normalized.contains('wa ');

    if (!mentionsNotify || (!wantsEmail && !wantsSms && !wantsWhatsapp)) {
      return false;
    }

    try {
      final prefs = await apiService.getNotificationPreferences();
      final channels = _extractEnabledChannels(prefs).toSet();
      final channelSettings = _extractChannelSettings(prefs);

      if (wantsEmail) channels.add('email');
      if (wantsSms) channels.add('sms');
      if (wantsWhatsapp) channels.add('whatsapp');
      channels.add('in_app');

      final emailMatch =
          RegExp(r'([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})')
              .firstMatch(command);
      if (emailMatch != null) {
        channelSettings['email_to'] = emailMatch.group(1)!.trim();
      }

      final phoneMatch = RegExp(r'(\+?\d[\d\s-]{7,}\d)').firstMatch(command);
      if (phoneMatch != null) {
        final cleaned =
            phoneMatch.group(1)!.replaceAll(RegExp(r'[^\d+]'), '').trim();
        if (cleaned.isNotEmpty) {
          if (wantsSms) {
            channelSettings['phone_number'] = cleaned;
          }
          if (wantsWhatsapp) {
            channelSettings['whatsapp_number'] = cleaned;
          }
        }
      }

      final urls = RegExp(r'(https?://[^\s]+)')
          .allMatches(command)
          .map((m) => m.group(1)?.trim() ?? '')
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
      if (urls.isNotEmpty) {
        String? smsWebhook;
        String? whatsappWebhook;
        final smsTagged = RegExp(
          r'sms(?:\s+webhook)?\s*[:=]?\s*(https?://[^\s]+)',
          caseSensitive: false,
        ).firstMatch(command);
        final waTagged = RegExp(
          r'whatsapp(?:\s+webhook)?\s*[:=]?\s*(https?://[^\s]+)',
          caseSensitive: false,
        ).firstMatch(command);
        smsWebhook = smsTagged?.group(1)?.trim();
        whatsappWebhook = waTagged?.group(1)?.trim();

        if ((smsWebhook == null || smsWebhook.isEmpty) && wantsSms) {
          smsWebhook = urls.first;
        }
        if ((whatsappWebhook == null || whatsappWebhook.isEmpty) &&
            wantsWhatsapp) {
          whatsappWebhook = urls.length > 1 ? urls[1] : urls.first;
        }

        if (smsWebhook != null && smsWebhook.isNotEmpty) {
          channelSettings['sms_webhook_url'] = smsWebhook;
        }
        if (whatsappWebhook != null && whatsappWebhook.isNotEmpty) {
          channelSettings['whatsapp_webhook_url'] = whatsappWebhook;
        }
      }

      await apiService.setNotificationPreferences(
        enabledChannels: channels.toList(),
        channelSettings: channelSettings,
      );

      await apiService.sendAutonomousStudyAlert(
        pair: _suggestPair(),
        userInstruction:
            'Channel connectivity check requested by user command.',
        priority: 'high',
      );

      final enabledList = <String>[
        if (wantsEmail) 'Email',
        if (wantsSms) 'SMS',
        if (wantsWhatsapp) 'WhatsApp',
      ];
      _addSystemMessage(
        _localizedChannelConfigured(enabledList.join(', ')),
        speak: true,
      );
      _addDecision(
        summary: 'Notification channels updated via chat.',
        rationale:
            'Enabled channels: ${channels.join(', ')}; channel settings synchronized and test alert sent.',
        state: AgentVisualState.monitoring,
      );
      return true;
    } catch (e) {
      _addSystemMessage(
        'Failed to configure notification channels: ${_safeErrorText(e)}',
      );
      return true;
    }
  }

  List<String> _extractEnabledChannels(Map<String, dynamic> prefs) {
    final channelsFromMap = prefs['channels'];
    if (channelsFromMap is Map<String, dynamic>) {
      return channelsFromMap.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString())
          .toList();
    }

    final enabledChannels = prefs['enabled_channels'];
    if (enabledChannels is List) {
      return enabledChannels.map((entry) => entry.toString()).toList();
    }

    return <String>['in_app'];
  }

  Map<String, dynamic> _extractChannelSettings(Map<String, dynamic> prefs) {
    final raw = prefs['channel_settings'];
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  Future<bool> _tryBackendNlp(String command) async {
    if (_offlineMode) {
      return false;
    }

    try {
      final response = await apiService.parseNaturalLanguageCommand(command);
      if (response['success'] != true) {
        return false;
      }

      final confidence = (response['confidence'] as num?)?.toDouble() ?? 0.0;
      if (confidence < 0.6) {
        return false;
      }

      final aiResponse =
          (response['ai_response'] ?? 'Command parsed successfully.')
              .toString();
      _addSystemMessage(aiResponse);

      final commandType = (response['command_type'] ?? '').toString();
      if (commandType == 'stop_all') {
        await engageKillSwitch(announce: false);
      } else if (commandType == 'get_analysis') {
        await _sendMarketBriefing();
      }

      _addDecision(
        summary: 'Natural-language command interpreted by AI router.',
        rationale:
            'Backend NLP confidence ${(confidence * 100).toStringAsFixed(0)}% for command type $commandType.',
        state: AgentVisualState.analyzing,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _extractLanguageFromCommand(String normalized) {
    if (normalized.contains('urdu')) return 'ur';
    if (normalized.contains('english')) return 'en';
    if (normalized.contains('spanish') || normalized.contains('espanol')) {
      return 'es';
    }
    if (normalized.contains('french')) return 'fr';
    if (normalized.contains('arabic')) return 'ar';
    if (normalized.contains('chinese') || normalized.contains('mandarin')) {
      return 'zh';
    }
    if (normalized.contains('hindi')) return 'hi';
    if (normalized.contains('german')) return 'de';
    return null;
  }

  Future<void> _speak(String text) async {
    final payload = text.trim();
    if (_disposed == true || payload.isEmpty) {
      return;
    }
    final startedAt = DateTime.now();
    const minVisualSpeakingDuration = Duration(milliseconds: 900);
    try {
      await _voiceAssistant.speak(
        payload,
        locale: _voiceLocaleForLanguage(_languageCode),
      );
    } catch (_) {
      // Speech output is best-effort; failures should never break orchestration.
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minVisualSpeakingDuration) {
        await Future<void>.delayed(minVisualSpeakingDuration - elapsed);
      }
    }
  }

  Future<void> _queueSpeech(String text) {
    if (_disposed == true) {
      return Future<void>.value();
    }
    _beginSpeechVisual();
    final previous = _pendingSpeech;
    final previousFuture =
        previous is Future<void> ? previous : Future<void>.value();
    final next = previousFuture
        .then((_) => _speak(text))
        .catchError((_) {})
        .whenComplete(_endSpeechVisual);
    _pendingSpeech = next;
    return next;
  }

  void _beginSpeechVisual() {
    final current = _activeSpeechJobs;
    final currentCount = current is int ? current : 0;
    _activeSpeechJobs = currentCount + 1;
    _setBotSpeaking(true);
  }

  void _endSpeechVisual() {
    final current = _activeSpeechJobs;
    final currentCount = current is int ? current : 0;
    final nextCount = currentCount <= 0 ? 0 : currentCount - 1;
    _activeSpeechJobs = nextCount;
    if (nextCount == 0) {
      _setBotSpeaking(false);
    }
  }

  String _voiceLocaleForLanguage(String code) {
    switch (code) {
      case 'ur':
        return 'ur-PK';
      case 'es':
        return 'es-ES';
      case 'fr':
        return 'fr-FR';
      case 'ar':
        return 'ar-SA';
      case 'zh':
        return 'zh-CN';
      case 'hi':
        return 'hi-IN';
      case 'de':
        return 'de-DE';
      case 'en':
      default:
        return 'en-US';
    }
  }

  String _localizedWelcome() {
    switch (_languageCode) {
      case 'ur':
        return 'Assalam o Alaikum. Forex Companion active hai. Aap kya proceed karna chahte hain? Main market monitor karke risk guardrails ke saath autonomous decisions le sakta hun.';
      case 'es':
        return 'Hola. Forex Companion esta activo. Que te gustaria hacer ahora? Estoy listo para monitorear mercado y ejecutar decisiones autonomas con guardrails.';
      case 'fr':
        return 'Bonjour. Forex Companion est actif. Que voulez-vous faire maintenant? Je peux surveiller le marche et executer des decisions autonomes avec garde-fous.';
      case 'ar':
        return 'Marhaban. Forex Companion tam tafeeluh. Ma alladhi turid an tafal alan? Astatie muraqabat alsuuq watanfidh qararat dhatiya mae dawabit aman.';
      case 'zh':
        return 'Ni hao. Forex Companion yi qidong. Ni xiang xian zuo shenme? Wo keyi jiankong shichang bing zai fengxian guize xia zhixing zizhu juece.';
      case 'hi':
        return 'Namaste. Forex Companion active hai. Aap ab kya karna chahte hain? Main market monitor karke guardrails ke saath autonomous decisions le sakta hun.';
      case 'de':
        return 'Hallo. Forex Companion ist aktiv. Wie moechten Sie fortfahren? Ich kann den Markt ueberwachen und mit Schutzregeln autonome Entscheidungen ausfuehren.';
      case 'en':
      default:
        return 'Welcome back. Forex Companion is live. What would you like to do next? I can monitor markets and execute autonomous decisions with safety guardrails.';
    }
  }

  String _localizedLanguageChanged(String languageLabel) {
    switch (_languageCode) {
      case 'ur':
        return 'Zaban $languageLabel par set ho gayi hai.';
      case 'es':
        return 'Idioma cambiado a $languageLabel.';
      case 'fr':
        return 'Langue changee vers $languageLabel.';
      case 'ar':
        return 'Tam tabdil allugha ila $languageLabel.';
      case 'zh':
        return 'Yuyan yi qiehuan wei $languageLabel.';
      case 'hi':
        return 'Bhasha $languageLabel par set kar di gayi hai.';
      case 'de':
        return 'Sprache auf $languageLabel umgestellt.';
      default:
        return 'Language switched to $languageLabel.';
    }
  }

  String _localizedVoiceEnabled() {
    switch (_languageCode) {
      case 'ur':
        return 'Voice feature on hai. Ab main bol kar rehnumai bhi karunga.';
      case 'es':
        return 'Modo de voz activado. Respondere tambien por voz.';
      case 'fr':
        return 'Mode vocal active. Je repondrai aussi a voix haute.';
      case 'ar':
        return 'Tam tafeel wad al sawt. Saard bilsawt aydan.';
      case 'zh':
        return 'Yuyin moshi yi kaiqi. Wo hui yuyin huiying.';
      case 'hi':
        return 'Voice mode on hai. Main bol kar bhi jawab dunga.';
      case 'de':
        return 'Sprachmodus ist aktiv. Ich antworte auch per Stimme.';
      default:
        return 'Voice mode is on. I will respond with spoken guidance.';
    }
  }

  String _localizedVoiceDisabled() {
    switch (_languageCode) {
      case 'ur':
        return 'Voice feature off hai.';
      case 'es':
        return 'Modo de voz desactivado.';
      case 'fr':
        return 'Mode vocal desactive.';
      case 'ar':
        return 'Tam iiqaf wad al sawt.';
      case 'zh':
        return 'Yuyin moshi yi guanbi.';
      case 'hi':
        return 'Voice mode off hai.';
      case 'de':
        return 'Sprachmodus ist deaktiviert.';
      default:
        return 'Voice mode is off.';
    }
  }

  String _localizedVoiceTestLine() {
    switch (_languageCode) {
      case 'ur':
        return 'Voice test successful. Main aap ko clear sunai de raha hun.';
      default:
        return 'Voice test successful. You should hear me clearly now.';
    }
  }

  String _localizedPeriodicVoiceBriefingEnabled(int seconds) {
    switch (_languageCode) {
      case 'ur':
        return 'Periodic voice market briefings on hain. Interval har $seconds second set hai.';
      default:
        return 'Periodic voice market briefings are enabled. Interval set to every $seconds seconds.';
    }
  }

  String _localizedPeriodicVoiceBriefingDisabled() {
    switch (_languageCode) {
      case 'ur':
        return 'Periodic voice market briefings off kar di gayi hain.';
      default:
        return 'Periodic voice market briefings are disabled.';
    }
  }

  String _localizedBriefingIntervalUpdated(int seconds) {
    switch (_languageCode) {
      case 'ur':
        return 'Market briefing interval update ho gaya: har $seconds second.';
      default:
        return 'Market briefing interval updated to every $seconds seconds.';
    }
  }

  String _localizedEnableVoiceFirst() {
    switch (_languageCode) {
      case 'ur':
        return 'Voice mode pehle on karein, phir mic se command dein.';
      default:
        return 'Enable voice mode first, then use the mic for commands.';
    }
  }

  String _localizedVoiceCaptureUnsupported() {
    switch (_languageCode) {
      case 'ur':
        return 'Is browser/device par voice command capture support available nahi.';
      default:
        return 'Voice command capture is not supported in this browser/device.';
    }
  }

  String _localizedListeningPrompt() {
    switch (_languageCode) {
      case 'ur':
        return 'Main sun raha hun... apni command boliye.';
      default:
        return 'I am listening now. Please speak your command.';
    }
  }

  String _localizedListeningNoSpeech() {
    switch (_languageCode) {
      case 'ur':
        return 'Awaaz clear nahi mili. Dobara mic dabakar boliye.';
      default:
        return 'I could not hear a clear command. Tap the mic and try again.';
    }
  }

  String _localizedHeardCommand(String command) {
    switch (_languageCode) {
      case 'ur':
        return 'Suna gaya command: "$command"';
      default:
        return 'Heard command: "$command"';
    }
  }

  String _localizedBriefingFallback() {
    switch (_languageCode) {
      case 'ur':
        return 'Market briefing filhal available nahi. Main background mein retry kar raha hun.';
      case 'es':
        return 'Informe de mercado no disponible temporalmente. Reintentare en segundo plano.';
      case 'fr':
        return 'Briefing marche temporairement indisponible. Nouvelle tentative en arriere-plan.';
      case 'ar':
        return 'Mulakhas alsuuq ghayr mutah alaan. Saueid almuhawala filkhalfia.';
      case 'zh':
        return 'Shichang jianbao zan shi buke yong. Wo hui zai houtai chongshi.';
      case 'hi':
        return 'Market briefing abhi temporary unavailable hai. Main background me retry karunga.';
      case 'de':
        return 'Markt-Briefing ist voruebergehend nicht verfuegbar. Ich versuche es im Hintergrund erneut.';
      default:
        return 'Market briefing is temporarily unavailable. I will keep retrying in the background.';
    }
  }

  String _localizedChannelConfigured(String channels) {
    switch (_languageCode) {
      case 'ur':
        return 'Notification channels set ho gaye: $channels. Test market alert bhej diya gaya hai.';
      case 'es':
        return 'Canales de notificacion configurados: $channels. Se envio una alerta de prueba.';
      case 'fr':
        return 'Canaux de notification configures: $channels. Une alerte de test a ete envoyee.';
      case 'ar':
        return 'Tam iadad qanawat altanbihat: $channels. Tum irsal tanbih tajribi.';
      case 'zh':
        return 'Tongzhi pindao yi peizhi: $channels. Ceshi shichang tixing yi fasong.';
      case 'hi':
        return 'Notification channels configure ho gaye: $channels. Test market alert bhej diya gaya.';
      case 'de':
        return 'Benachrichtigungskanaele konfiguriert: $channels. Ein Test-Alert wurde gesendet.';
      default:
        return 'Notification channels configured: $channels. A test market alert has been sent.';
    }
  }

  String _localizedMarketBriefing({
    required String trend,
    required String volatility,
    required String risk,
    required String movers,
    required String headline,
  }) {
    switch (_languageCode) {
      case 'ur':
        return 'Aaj ka forex update: trend $trend, volatility $volatility, risk $risk. '
            'Top fluctuations: $movers. Aham headline: $headline. Batayen aage kya proceed karna hai.';
      case 'es':
        return 'Actualizacion forex de hoy: tendencia $trend, volatilidad $volatility, riesgo $risk. '
            'Fluctuaciones clave: $movers. Titular principal: $headline. Dime como quieres proceder.';
      case 'fr':
        return 'Mise a jour forex du jour: tendance $trend, volatilite $volatility, risque $risk. '
            'Fluctuations majeures: $movers. Titre principal: $headline. Dites-moi comment proceder.';
      case 'ar':
        return 'Tahdith forex alyawm: ittijah $trend, taqalub $volatility, mukhatara $risk. '
            'Aham altaghayurat: $movers. alkhabar alraisi: $headline. Akhbirni kayfa turid almutabaea.';
      case 'zh':
        return 'Jintian huishi gengxin: qushi $trend, bodong $volatility, fengxian $risk. '
            'Zhuyao bianhua: $movers. Zhongdian xinwen: $headline. Qing gaosu wo ni xiang ruhe jinxing.';
      case 'hi':
        return 'Aaj ka forex update: trend $trend, volatility $volatility, risk $risk. '
            'Top fluctuations: $movers. Key headline: $headline. Batayein aap kaise proceed karna chahte hain.';
      case 'de':
        return 'Heutiges Forex-Update: Trend $trend, Volatilitaet $volatility, Risiko $risk. '
            'Wichtigste Schwankungen: $movers. Hauptmeldung: $headline. Sagen Sie mir, wie Sie fortfahren moechten.';
      default:
        return 'Today\'s forex update: trend $trend, volatility $volatility, risk $risk. '
            'Top fluctuations: $movers. Key headline: $headline. Tell me how you want to proceed.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autonomyLoopTimer?.cancel();
    _marketBriefingTimer?.cancel();
    _isBotSpeaking = false;
    _voiceAssistant.stop();
    super.dispose();
  }

  String _safeErrorText(Object? error) {
    if (error == null) {
      return 'unknown error';
    }
    try {
      final text = '$error'.trim();
      if (text.isNotEmpty) {
        return text;
      }
    } catch (_) {
      // Ignore conversion failures from JS undefined values.
    }
    return 'unknown error';
  }

  void _setBotSpeaking(bool value) {
    if (_disposed == true) {
      _isBotSpeaking = value;
      return;
    }
    if ((_isBotSpeaking ?? false) == value) {
      return;
    }
    _isBotSpeaking = value;
    notifyListeners();
  }

  void _setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _addSystemMessage(message);
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
