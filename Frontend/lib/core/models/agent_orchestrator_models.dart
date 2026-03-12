enum AgentVisualState {
  monitoring,
  analyzing,
  trading,
  paused,
}

enum AgentAutonomyMode {
  manual,
  assisted,
  semiAuto,
  fullAuto,
}

extension AgentVisualStateLabel on AgentVisualState {
  String get label {
    switch (this) {
      case AgentVisualState.monitoring:
        return 'Monitoring';
      case AgentVisualState.analyzing:
        return 'Analyzing';
      case AgentVisualState.trading:
        return 'Trading';
      case AgentVisualState.paused:
        return 'Paused';
    }
  }
}

extension AgentAutonomyModeLabel on AgentAutonomyMode {
  String get label {
    switch (this) {
      case AgentAutonomyMode.manual:
        return 'Manual';
      case AgentAutonomyMode.assisted:
        return 'Assisted';
      case AgentAutonomyMode.semiAuto:
        return 'Semi-Auto';
      case AgentAutonomyMode.fullAuto:
        return 'Full Auto';
    }
  }
}

class RiskGuardrails {
  final double maxRiskPerTradePercent;
  final double dailyLossLimitPercent;
  final double weeklyLossLimitPercent;
  final double hardMaxDrawdownPercent;
  // Backend-governed autonomy profile (beginner, intermediate, pro, custom).
  final String profile;
  // Coarse-grained guardian state for UI: stable / near_limit / paused.
  final String riskGuardianStatus;
  final String riskGuardianReason;
  final bool probationPassed;
  final bool paused;
  final String pauseReason;
  final String backendLevel;

  const RiskGuardrails({
    this.maxRiskPerTradePercent = 1.0,
    this.dailyLossLimitPercent = 2.0,
    this.weeklyLossLimitPercent = 6.0,
    this.hardMaxDrawdownPercent = 12.0,
    this.profile = 'custom',
    this.riskGuardianStatus = 'stable',
    this.riskGuardianReason = '',
    this.probationPassed = false,
    this.paused = false,
    this.pauseReason = '',
    this.backendLevel = 'assisted',
  });

  RiskGuardrails copyWith({
    double? maxRiskPerTradePercent,
    double? dailyLossLimitPercent,
    double? weeklyLossLimitPercent,
    double? hardMaxDrawdownPercent,
    String? profile,
    String? riskGuardianStatus,
    String? riskGuardianReason,
    bool? probationPassed,
    bool? paused,
    String? pauseReason,
    String? backendLevel,
  }) {
    return RiskGuardrails(
      maxRiskPerTradePercent:
          maxRiskPerTradePercent ?? this.maxRiskPerTradePercent,
      dailyLossLimitPercent:
          dailyLossLimitPercent ?? this.dailyLossLimitPercent,
      weeklyLossLimitPercent:
          weeklyLossLimitPercent ?? this.weeklyLossLimitPercent,
      hardMaxDrawdownPercent:
          hardMaxDrawdownPercent ?? this.hardMaxDrawdownPercent,
      profile: profile ?? this.profile,
      riskGuardianStatus: riskGuardianStatus ?? this.riskGuardianStatus,
      riskGuardianReason: riskGuardianReason ?? this.riskGuardianReason,
      probationPassed: probationPassed ?? this.probationPassed,
      paused: paused ?? this.paused,
      pauseReason: pauseReason ?? this.pauseReason,
      backendLevel: backendLevel ?? this.backendLevel,
    );
  }

  factory RiskGuardrails.fromApi(Map<String, dynamic> payload) {
    final state = payload['autonomy_state'] is Map<String, dynamic>
        ? payload['autonomy_state'] as Map<String, dynamic>
        : <String, dynamic>{};
    final budget = payload['risk_budget'] is Map<String, dynamic>
        ? payload['risk_budget'] as Map<String, dynamic>
        : <String, dynamic>{};
    final guardian = payload['risk_guardian'] is Map<String, dynamic>
        ? payload['risk_guardian'] as Map<String, dynamic>
        : <String, dynamic>{};

    return RiskGuardrails(
      maxRiskPerTradePercent:
          _toDouble(budget['max_risk_per_trade_percent'], 1.0),
      dailyLossLimitPercent: _toDouble(budget['daily_loss_limit_percent'], 2.0),
      weeklyLossLimitPercent:
          _toDouble(budget['weekly_loss_limit_percent'], 6.0),
      hardMaxDrawdownPercent:
          _toDouble(budget['hard_max_drawdown_percent'], 12.0),
      profile: (state['profile'] ?? 'custom').toString(),
      riskGuardianStatus: (guardian['status'] ?? 'stable').toString(),
      riskGuardianReason: (guardian['reason'] ?? '').toString(),
      probationPassed: state['probation_passed'] == true,
      paused: state['paused'] == true,
      pauseReason: (state['pause_reason'] ?? '').toString(),
      backendLevel: (state['level'] ?? 'assisted').toString().toLowerCase(),
    );
  }
}

class AgentConversationTurn {
  final String text;
  final bool fromUser;
  final DateTime timestamp;

  const AgentConversationTurn({
    required this.text,
    required this.fromUser,
    required this.timestamp,
  });
}

class DecisionLogEntry {
  final DateTime timestamp;
  final AgentVisualState state;
  final String summary;
  final String rationale;
  final double confidencePercent;
  final bool blockedByGuardrails;

  const DecisionLogEntry({
    required this.timestamp,
    required this.state,
    required this.summary,
    required this.rationale,
    required this.confidencePercent,
    this.blockedByGuardrails = false,
  });
}

double _toDouble(dynamic value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}
